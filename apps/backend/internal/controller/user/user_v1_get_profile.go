package user

import (
	"context"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"

	v1 "github.com/gqcn/platform/backend/api/user/v1"
)

// GetProfile handles GET /api/profile — get current user's profile.
func (c *ControllerV1) GetProfile(ctx context.Context, req *v1.GetProfileReq) (res *v1.GetProfileRes, err error) {
	// Get current user from context
	u := c.bizCtxSvc.GetContextUser(ctx)
	if u == nil {
		return nil, gerror.NewCode(gcode.CodeNotAuthorized, "未登录")
	}

	// Get full user info from database
	user, err := c.userSvc.GetById(ctx, u.Id)
	if err != nil {
		return nil, err
	}

	return &v1.GetProfileRes{
		Id:       user.Id,
		Username: user.Username,
		Email:    user.Email,
		IsAdmin:  user.IsAdmin,
		Uid:      user.Uid,
	}, nil
}