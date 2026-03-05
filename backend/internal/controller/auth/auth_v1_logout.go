package auth

import (
	"context"

	v1 "github.com/gqcn/platform/backend/api/auth/v1"
)

// Logout handles POST /api/auth/logout.
// JWT is stateless; the client discards the token.
func (c *ControllerV1) Logout(ctx context.Context, req *v1.LogoutReq) (res *v1.LogoutRes, err error) {
	return &v1.LogoutRes{}, nil
}
