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
			Containers: []corev1.Container{
				{
					Name:  "jupyterlab",
					Image: opts.Image,
					// Use start-notebook.sh without inline args; pass config via env vars
					// (compatible with jupyter/base-notebook 4.x / jupyter_server 2.x)
					SecurityContext: &corev1.SecurityContext{
						RunAsUser: ptrInt64(0),
					},
					Env: []corev1.EnvVar{
						{Name: "NB_UID", Value: fmt.Sprintf("%d", opts.Uid)},
						{Name: "NB_GID", Value: fmt.Sprintf("%d", opts.Uid)},
						{Name: "NB_USER", Value: opts.Username},
						{Name: "JUPYTER_TOKEN", Value: opts.Token},
						// Pass ServerApp.base_url via NOTEBOOK_ARGS (correct for JupyterLab 4.x)
						{Name: "NOTEBOOK_ARGS", Value: fmt.Sprintf("--ServerApp.base_url=%s", baseURL)},
						{Name: "CHOWN_HOME", Value: "yes"},
						{Name: "CHOWN_HOME_OPTS", Value: "-R"},
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
						InitialDelaySeconds: 30,
						PeriodSeconds:       20,
						FailureThreshold:    5,
					},
					ReadinessProbe: &corev1.Probe{
						ProbeHandler: corev1.ProbeHandler{
							HTTPGet: &corev1.HTTPGetAction{
								Path: probePath,
								Port: probePortVal,
							},
						},
						InitialDelaySeconds: 10,
						PeriodSeconds:       10,
						FailureThreshold:    3,
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
func GetPodStatus(ctx context.Context, username string) (phase string, podIP string, nodeName string, err error) {
	ns := Namespace(ctx)
	podName := consts.PodNamePrefix + username
	pod, err := Client(ctx).CoreV1().Pods(ns).Get(ctx, podName, metav1.GetOptions{})
	if err != nil {
		return "", "", "", err
	}
	return string(pod.Status.Phase), pod.Status.PodIP, pod.Spec.NodeName, nil
}

// probePort converts an int32 to the IntOrString type used by K8S probes.
func probePort(port int32) intstr.IntOrString {
	return intstr.FromInt32(port)
}

func ptrInt64(v int64) *int64 { return &v }
