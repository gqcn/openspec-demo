package k8s

import (
	"context"
	"fmt"

	"github.com/gogf/gf/v2/frame/g"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	k8serrors "k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// InitUserHomeDir creates a one-shot K8S Job that:
//  1. Creates /data/home/{username} directory inside the shared PVC.
//  2. chown it to uid:uid so the JupyterLab container can write to it.
func InitUserHomeDir(ctx context.Context, username string, uid uint, pvcName string) error {
	ns := Namespace(ctx)
	jobName := fmt.Sprintf("init-home-%s", username)
	homeDir := fmt.Sprintf("/data/home/%s", username)
	cmd := fmt.Sprintf(
		"mkdir -p %s && chown -R %d:%d %s && chmod 700 %s && mkdir -p /share && chmod 2777 /share",
		homeDir, uid, uid, homeDir, homeDir,
	)
	ttl := int32(300) // clean up after 5 min
	backoff := int32(2)

	job := &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name:      jobName,
			Namespace: ns,
		},
		Spec: batchv1.JobSpec{
			TTLSecondsAfterFinished: &ttl,
			BackoffLimit:            &backoff,
			Template: corev1.PodTemplateSpec{
				Spec: corev1.PodSpec{
					RestartPolicy: corev1.RestartPolicyOnFailure,
					Containers: []corev1.Container{
						{
							Name:    "init",
							Image:   "busybox:1.36",
							Command: []string{"sh", "-c", cmd},
							VolumeMounts: []corev1.VolumeMount{
								{Name: "jupyter-shared", MountPath: "/data/home", SubPath: "data/home"},
								{Name: "jupyter-shared", MountPath: "/share", SubPath: "share"},
							},
						},
					},
					Volumes: []corev1.Volume{
						{
							Name: "jupyter-shared",
							VolumeSource: corev1.VolumeSource{
								PersistentVolumeClaim: &corev1.PersistentVolumeClaimVolumeSource{
									ClaimName: pvcName,
								},
							},
						},
					},
				},
			},
		},
	}

	_, err := Client(ctx).BatchV1().Jobs(ns).Create(ctx, job, metav1.CreateOptions{})
	if err != nil {
		if k8serrors.IsAlreadyExists(err) {
			// Job already completed from a prior run — home dir already initialized.
			g.Log().Infof(ctx, "k8s InitUserHomeDir job %s already exists, skipping", jobName)
			return nil
		}
		g.Log().Errorf(ctx, "k8s InitUserHomeDir job %s error: %v", jobName, err)
	}
	return err
}
