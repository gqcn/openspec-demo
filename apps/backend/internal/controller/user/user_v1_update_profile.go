package user

import (
	"context"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"

	v1 "github.com/gqcn/platform/backend/api/user/v1"
)

func (c *ControllerV1) UpdateProfile(ctx context.Context, req *v1.UpdateProfileReq) (res *v1.UpdateProfileRes, err error) {
	// Get current user from context
	u := c.bizCtxSvc.GetContextUser(ctx)
	if u == nil {
		return nil, gerror.NewCode(gcode.CodeNotAuthorized, "未登录")
	}

	// Update profile
	err = c.userSvc.UpdateProfile(ctx, u.Id, req.Email, req.Password)
	if err != nil {
		return nil, err
	}

	return &v1.UpdateProfileRes{}, nil
}


