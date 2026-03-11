package k8s

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/gogf/gf/v2/frame/g"
	"github.com/gqcn/platform/backend/internal/consts"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

// PodOptions holds all parameters required to create a JupyterLab Pod.
type PodOptions struct {
	Username     string
	Uid          uint
	Token        string
	Image        string
	Cpu          string
	Memory       string
	Gpu          string
	GpuType      string
	NodeSelector string // JSON string
	Tolerations  string // JSON string
	PVCName      string
}

// CreatePod creates a JupyterLab Pod in the configured namespace.
func CreatePod(ctx context.Context, opts PodOptions) error {
	ns := Namespace(ctx)
	podName := consts.PodNamePrefix + opts.Username
	baseURL := fmt.Sprintf("/jupyter/%s/", opts.Token)

	// Resource requirements
	resReq := corev1.ResourceRequirements{
		Requests: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse(opts.Cpu),
			corev1.ResourceMemory: resource.MustParse(opts.Memory),
		},
		Limits: corev1.ResourceList{
			corev1.ResourceCPU:    resource.MustParse(opts.Cpu),
			corev1.ResourceMemory: resource.MustParse(opts.Memory),
		},
	}
	if opts.Gpu != "" && opts.Gpu != "0" {
		gpuKey := corev1.ResourceName(opts.GpuType)
		if gpuKey == "" {
			gpuKey = "nvidia.com/gpu"
		}
		resReq.Limits[gpuKey] = resource.MustParse(opts.Gpu)
		resReq.Requests[gpuKey] = resource.MustParse(opts.Gpu)
	}

	// NodeSelector
	nodeSelector := map[string]string{}
	if opts.NodeSelector != "" {
		_ = json.Unmarshal([]byte(opts.NodeSelector), &nodeSelector)
	}

	// Tolerations
	var tolerations []corev1.Toleration
	if opts.Tolerations != "" {
		_ = json.Unmarshal([]byte(opts.Tolerations), &tolerations)
	}

	// Probe path
	probePath := fmt.Sprintf("/jupyter/%s/lab", opts.Token)
	probePortVal := probePort(consts.JupyterPort)

	// Init command: create home dir, set ownership and permissions (idempotent)
	homeDir := fmt.Sprintf("/data/home/%s", opts.Username)
	initCmd := fmt.Sprintf(
		"mkdir -p %s && chown -R %d:%d %s && chmod 700 %s && mkdir -p /share && chmod 2777 /share",
		homeDir, opts.Uid, opts.Uid, homeDir, homeDir,
	)

	// Main container startup command: symlink NFS user home to /home/{username},
	// then hand over to start.sh which reads NB_USER/NB_UID/NB_GID for user switching.
	mainCmd := fmt.Sprintf(
		"set -e; ln -sfn /data/home/%s /home/%s; exec /usr/local/bin/start.sh start-notebook.sh",
		opts.Username, opts.Username,
	)

	pod := &corev1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Name:      podName,
			Namespace: ns,
			Labels: map[string]string{
				"app":      "jupyterlab",
				"username": opts.Username,
				"token":    opts.Token,
			},
		},
		Spec: corev1.PodSpec{
			SecurityContext: &corev1.PodSecurityContext{},
			NodeSelector:    nodeSelector,
			Tolerations:     tolerations,
			InitContainers: []corev1.Container{
				{
					Name:            "init-home",
					Image:           "busybox:1.36",
					ImagePullPolicy: corev1.PullIfNotPresent,
					Command:         []string{"sh", "-c", initCmd},
					SecurityContext: &corev1.SecurityContext{
						RunAsUser: ptrInt64(0),
					},
					VolumeMounts: []corev1.VolumeMount{
						{
							Name:      "jupyter-shared",
							MountPath: "/data/home",
							SubPath:   consts.NFSHomeSubPath,
						},
						{
							Name:      "jupyter-shared",
							MountPath: "/share",
							SubPath:   consts.NFSShareSubPath,
						},
					},
				},
			},
			Containers: []corev1.Container{
				{
					Name:            "jupyterlab",
					Image:           opts.Image,
					ImagePullPolicy: corev1.PullIfNotPresent,
					Command:         []string{"/bin/bash", "-c", mainCmd},
					SecurityContext: &corev1.SecurityContext{
						RunAsUser: ptrInt64(0),
					},
					Env: []corev1.EnvVar{
						{Name: "NB_UID", Value: fmt.Sprintf("%d", opts.Uid)},
						{Name: "NB_GID", Value: fmt.Sprintf("%d", opts.Uid)},
						{Name: "NB_USER", Value: opts.Username},
						// Disable token auth: routing token in URL path is the security boundary.
						{Name: "NOTEBOOK_ARGS", Value: fmt.Sprintf("--ServerApp.base_url=%s --ServerApp.token= --ServerApp.password='' --ServerApp.allow_origin='*'", baseURL)},
					},
					Ports: []corev1.ContainerPort{
						{ContainerPort: consts.JupyterPort, Protocol: corev1.ProtocolTCP},
					},
					Resources: resReq,
					VolumeMounts: []corev1.VolumeMount{
						{
							Name:      "jupyter-shared",
							MountPath: "/data/home",
							SubPath:   consts.NFSHomeSubPath,
						},
						{
							Name:      "jupyter-shared",
							MountPath: "/share",
							SubPath:   consts.NFSShareSubPath,
						},
					},
					LivenessProbe: &corev1.Probe{
						ProbeHandler: corev1.ProbeHandler{
							HTTPGet: &corev1.HTTPGetAction{
								Path: probePath,
								Port: probePortVal,
							},
						},
						PeriodSeconds:    5,
						FailureThreshold: 5,
					},
					ReadinessProbe: &corev1.Probe{
						ProbeHandler: corev1.ProbeHandler{
							HTTPGet: &corev1.HTTPGetAction{
								Path: probePath,
								Port: probePortVal,
							},
						},
						PeriodSeconds:    5,
						FailureThreshold: 3,
					},
				},
			},
			Volumes: []corev1.Volume{
				{
					Name: "jupyter-shared",
					VolumeSource: corev1.VolumeSource{
						PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
							ClaimName: opts.PVCName,
						},
					},
				},
			},
		},
	}

	_, err := Client(ctx).CoreV1().Pods(ns).Create(ctx, pod, metav1.CreateOptions{})
	if err != nil {
		g.Log().Errorf(ctx, "k8s CreatePod %s error: %v", podName, err)
	}
	return err
}

// DeletePod deletes the JupyterLab Pod for the given username.
func DeletePod(ctx context.Context, username string) error {
	ns := Namespace(ctx)
	podName := consts.PodNamePrefix + username
	gracePeriod := int64(0)
	return Client(ctx).CoreV1().Pods(ns).Delete(ctx, podName, metav1.DeleteOptions{
		GracePeriodSeconds: &gracePeriod,
	})
}

// GetPodStatus returns the current phase and pod IP.
// The phase is reported as "Running" only when all containers have passed their
// readiness probes (i.e., the pod is fully available, not just in Running phase).
func GetPodStatus(ctx context.Context, username string) (phase string, podIP string, nodeName string, err error) {
	ns := Namespace(ctx)
	podName := consts.PodNamePrefix + username
	pod, err := Client(ctx).CoreV1().Pods(ns).Get(ctx, podName, metav1.GetOptions{})
	if err != nil {
		return "", "", "", err
	}
	p := string(pod.Status.Phase)
	// A pod may be in Running phase while containers are still starting (0/1 Ready).
	// Only propagate Running once every container reports Ready=true.
	if p == "Running" {
		statuses := pod.Status.ContainerStatuses
		if len(statuses) == 0 {
			return "Pending", pod.Status.PodIP, pod.Spec.NodeName, nil
		}
		for _, cs := range statuses {
			if !cs.Ready {
				return "Pending", pod.Status.PodIP, pod.Spec.NodeName, nil
			}
		}
	}
	return p, pod.Status.PodIP, pod.Spec.NodeName, nil
}

// probePort converts an int32 to the IntOrString type used by K8S probes.
func probePort(port int32) intstr.IntOrString {
	return intstr.FromInt32(port)
}

func ptrInt64(v int64) *int64 { return &v }
