package k8s

import (
	"context"
	"fmt"

	"github.com/gogf/gf/v2/frame/g"
	"github.com/gqcn/platform/backend/internal/consts"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/intstr"
)

// CreateService creates a ClusterIP Service for the given username's JupyterLab Pod.
func (s *Service) CreateService(ctx context.Context, username string) error {
	ns := s.Namespace(ctx)
	svcName := consts.ServiceNamePrefix + username
	port := int32(consts.JupyterPort)

	svc := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      svcName,
			Namespace: ns,
			Labels: map[string]string{
				"app":      "jupyterlab",
				"username": username,
			},
		},
		Spec: corev1.ServiceSpec{
			Selector: map[string]string{
				"app":      "jupyterlab",
				"username": username,
			},
			Ports: []corev1.ServicePort{
				{
					Name:       "http",
					Port:       port,
					TargetPort: intstr.FromInt(int(port)),
					Protocol:   corev1.ProtocolTCP,
				},
			},
			Type: corev1.ServiceTypeClusterIP,
		},
	}

	_, err := s.Client(ctx).CoreV1().Services(ns).Create(ctx, svc, metav1.CreateOptions{})
	if err != nil {
		g.Log().Errorf(ctx, "k8s CreateService %s error: %v", svcName, err)
	}
	return err
}

// DeleteService deletes the ClusterIP Service for the given username.
func (s *Service) DeleteService(ctx context.Context, username string) error {
	ns := s.Namespace(ctx)
	svcName := consts.ServiceNamePrefix + username
	return s.Client(ctx).CoreV1().Services(ns).Delete(ctx, svcName, metav1.DeleteOptions{})
}

// ServiceBackendName returns the K8S service name for the user.
func (s *Service) ServiceBackendName(username string) string {
	return fmt.Sprintf("%s%s", consts.ServiceNamePrefix, username)
}
