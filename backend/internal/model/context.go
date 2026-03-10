// Package model provides application-level common data structures.
package model

import (
	"context"

	"github.com/gogf/gf/v2/net/ghttp"
	"github.com/gqcn/platform/backend/internal/consts"
)

// ContextUser stores authenticated user info in request context.
type ContextUser struct {
	Id       uint
	Username string
	IsAdmin  uint
	Uid      uint
}

// GetContextUser extracts the current authenticated user from the request context.
// Returns nil if no user is stored (e.g. unauthenticated request).
func GetContextUser(ctx context.Context) *ContextUser {
	v := ghttp.RequestFromCtx(ctx).GetCtxVar(consts.ContextKeyUser).Val()
	if v == nil {
		return nil
	}
	u, _ := v.(*ContextUser)
	return u
}
