package auth

import (
	"context"

	v1 "github.com/gqcn/platform/backend/api/auth/v1"
)

// Login handles POST /api/auth/login.
func (c *ControllerV1) Login(ctx context.Context, req *v1.LoginReq) (res *v1.LoginRes, err error) {
	token, claims, err := c.authSvc.Login(ctx, req.Username, req.Password)
	if err != nil {
		return nil, err
	}
	return &v1.LoginRes{
		Token:    token,
		UserId:   claims.UserId,
		Username: claims.Username,
		IsAdmin:  claims.IsAdmin,
		Uid:      claims.Uid,
	}, nil
}
