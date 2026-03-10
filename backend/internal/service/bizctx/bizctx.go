// Package bizctx provides business context extraction from the request context.
// It owns the HTTP-layer knowledge of how the authenticated user is stored and retrieved,
// keeping the model package free of transport-layer dependencies.
package bizctx

import (
	"context"

	"github.com/gogf/gf/v2/net/ghttp"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/model"
)

// Service provides business context extraction logic.
type Service struct{}

// New creates and returns a new Service instance.
func New() *Service {
	return &Service{}
}

// GetContextUser extracts the current authenticated user from the request context.
// Returns nil if no user is stored (e.g. unauthenticated request).
func (s *Service) GetContextUser(ctx context.Context) *model.ContextUser {
	r := ghttp.RequestFromCtx(ctx)
	if r == nil {
		return nil
	}
	v := r.GetCtxVar(consts.ContextKeyUser).Val()
	if v == nil {
		return nil
	}
	u, _ := v.(*model.ContextUser)
	return u
}
