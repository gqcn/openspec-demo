package k8s

import (
	"context"
	"fmt"

	"github.com/gogf/gf/v2/frame/g"
	"github.com/gqcn/platform/backend/internal/consts"
	networkingv1 "k8s.io/api/networking/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// CreateIngress creates a nginx Ingress for the JupyterLab instance identified by token.
// Path: /jupyter/{token}/(.*)  →  svc-jupyterlab-{username}:8888
func CreateIngress(ctx context.Context, username, token string) error {
	ns := Namespace(ctx)
	ingressName := consts.IngressNamePrefix + token
	host := g.Cfg().MustGet(ctx, "notebook.ingressHost", "platform.internal").String()
	pathPrefix := fmt.Sprintf("/jupyter/%s(/|$)(.*)", token)
	svcName := ServiceBackendName(username)
	port := int32(consts.JupyterPort)
	pathType := networkingv1.PathTypeImplementationSpecific
	ingressClass := "nginx"

	ing := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:      ingressName,
			Namespace: ns,
			Annotations: map[string]string{
				"nginx.ingress.kubernetes.io/rewrite-target":     "/$2",
				"nginx.ingress.kubernetes.io/proxy-read-timeout": "3600",
				"nginx.ingress.kubernetes.io/proxy-send-timeout": "3600",
				"nginx.ingress.kubernetes.io/proxy-body-size":    "0",
				"nginx.ingress.kubernetes.io/websocket-services": svcName,
				"nginx.ingress.kubernetes.io/upstream-hash-by":   "$remote_addr",
			},
			Labels: map[string]string{
				"app":      "jupyterlab",
				"username": username,
				"token":    token,
			},
		},
		Spec: networkingv1.IngressSpec{
			IngressClassName: &ingressClass,
			Rules: []networkingv1.IngressRule{
				{
					Host: host,
					IngressRuleValue: networkingv1.IngressRuleValue{
						HTTP: &networkingv1.HTTPIngressRuleValue{
							Paths: []networkingv1.HTTPIngressPath{
								{
									Path:     pathPrefix,
									PathType: &pathType,
									Backend: networkingv1.IngressBackend{
										Service: &networkingv1.IngressServiceBackend{
											Name: svcName,
											Port: networkingv1.ServiceBackendPort{
												Number: port,
											},
										},
									},
								},
							},
						},
					},
				},
			},
		},
	}

	_, err := Client(ctx).NetworkingV1().Ingresses(ns).Create(ctx, ing, metav1.CreateOptions{})
	if err != nil {
		g.Log().Errorf(ctx, "k8s CreateIngress %s error: %v", ingressName, err)
	}
	return err
}

// DeleteIngress deletes the Ingress for the given token.
func DeleteIngress(ctx context.Context, token string) error {
	ns := Namespace(ctx)
	ingressName := consts.IngressNamePrefix + token
	return Client(ctx).NetworkingV1().Ingresses(ns).Delete(ctx, ingressName, metav1.DeleteOptions{})
}
