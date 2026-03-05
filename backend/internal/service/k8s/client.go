// Package k8s provides a singleton Kubernetes client and wraps common operations.
package k8s

import (
	"context"
	"sync"

	"github.com/gogf/gf/v2/frame/g"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

var (
	clientOnce sync.Once
	clientset  *kubernetes.Clientset
)

// Client returns a shared kubernetes.Clientset, initialised on first call.
// It first tries in-cluster config, then falls back to the kubeconfig path in config.yaml.
func Client(ctx context.Context) *kubernetes.Clientset {
	clientOnce.Do(func() {
		var cfg *rest.Config
		var err error

		// Try in-cluster first
		cfg, err = rest.InClusterConfig()
		if err != nil {
			// Fallback to kubeconfig file
			kubeconfig := g.Cfg().MustGet(ctx, "kubernetes.kubeconfig", "").String()
			cfg, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
			if err != nil {
				g.Log().Fatalf(ctx, "k8s: failed to build client config: %v", err)
			}
		}

		clientset, err = kubernetes.NewForConfig(cfg)
		if err != nil {
			g.Log().Fatalf(ctx, "k8s: failed to create clientset: %v", err)
		}
		g.Log().Info(ctx, "k8s: client initialized")
	})
	return clientset
}

// Namespace returns the configured K8S namespace.
func Namespace(ctx context.Context) string {
	return g.Cfg().MustGet(ctx, "kubernetes.namespace", "jupyter").String()
}
