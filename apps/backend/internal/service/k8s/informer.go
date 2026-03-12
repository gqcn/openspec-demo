package k8s

import (
	"context"
	"time"

	"github.com/gogf/gf/v2/frame/g"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/tools/cache"
)

// StartPodInformer starts a K8S Informer to watch Pod events in the jupyter namespace
// and automatically sync Pod status changes to the database.
func (s *Service) StartPodInformer(ctx context.Context) {
	ns := s.Namespace(ctx)
	client := s.Client(ctx)

	// Create informer factory for the jupyter namespace with label selector
	factory := informers.NewSharedInformerFactoryWithOptions(
		client,
		30*time.Second, // resync period
		informers.WithNamespace(ns),
	)

	podInformer := factory.Core().V1().Pods().Informer()

	// Register event handlers
	podInformer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			pod := obj.(*corev1.Pod)
			// Only process pods with app=jupyterlab label
			if pod.Labels["app"] == "jupyterlab" {
				s.handlePodEvent(ctx, pod, "Add")
			}
		},
		UpdateFunc: func(oldObj, newObj interface{}) {
			pod := newObj.(*corev1.Pod)
			if pod.Labels["app"] == "jupyterlab" {
				s.handlePodEvent(ctx, pod, "Update")
			}
		},
		DeleteFunc: func(obj interface{}) {
			pod := obj.(*corev1.Pod)
			if pod.Labels["app"] == "jupyterlab" {
				s.handlePodEvent(ctx, pod, "Delete")
			}
		},
	})

	// Start informer
	stopCh := make(chan struct{})
	go factory.Start(stopCh)

	// Wait for cache sync
	if !cache.WaitForCacheSync(stopCh, podInformer.HasSynced) {
		g.Log().Error(ctx, "k8s informer: failed to sync cache")
		return
	}

	g.Log().Info(ctx, "k8s informer: Pod informer started successfully")
}

// handlePodEvent processes Pod events and updates the database
func (s *Service) handlePodEvent(ctx context.Context, pod *corev1.Pod, eventType string) {
	// Extract username from pod name (format: jupyterlab-{username})
	podName := pod.Name
	if len(podName) <= len(consts.PodNamePrefix) {
		return
	}
	username := podName[len(consts.PodNamePrefix):]

	// Query instance by username
	cols := dao.Instances.Columns()
	var instance *entity.Instance
	err := dao.Instances.Ctx(ctx).Where(cols.Username, username).Scan(&instance)
	if err != nil || instance == nil {
		// No matching instance in DB, skip
		return
	}

	// Handle Delete event
	if eventType == "Delete" {
		// Pod deleted - mark as failed if instance was creating/running
		if instance.Status == consts.StatusCreating || instance.Status == consts.StatusRunning {
			g.Log().Infof(ctx, "k8s informer: Pod %s deleted, marking instance %d as failed", podName, instance.Id)
			_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, instance.Id).Data(do.Instance{
				Status: consts.StatusFailed,
			}).Update()
		}
		return
	}

	// Calculate status from Pod phase and container readiness
	status := s.calculatePodStatus(pod)
	podIP := pod.Status.PodIP
	nodeName := pod.Spec.NodeName

	// Update DB if status changed
	if status != instance.Status || podIP != instance.PodIp || nodeName != instance.NodeName {
		g.Log().Infof(ctx, "k8s informer: Pod %s status changed to %s (was %s), updating instance %d",
			podName, status, instance.Status, instance.Id)

		updateData := do.Instance{
			Status:   status,
			PodIp:    podIP,
			NodeName: nodeName,
		}

		_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, instance.Id).Data(updateData).Update()
	}
}

// calculatePodStatus determines the instance status based on Pod phase and container readiness
func (s *Service) calculatePodStatus(pod *corev1.Pod) string {
	phase := string(pod.Status.Phase)

	switch phase {
	case "Running":
		// Check if all containers are ready
		statuses := pod.Status.ContainerStatuses
		if len(statuses) == 0 {
			return consts.StatusCreating
		}
		for _, cs := range statuses {
			if !cs.Ready {
				return consts.StatusCreating
			}
		}
		return consts.StatusRunning

	case "Pending":
		return consts.StatusCreating

	case "Failed":
		return consts.StatusFailed

	case "Succeeded":
		// JupyterLab pods should not succeed (they run indefinitely)
		return consts.StatusStopped

	default:
		return consts.StatusCreating
	}
}
