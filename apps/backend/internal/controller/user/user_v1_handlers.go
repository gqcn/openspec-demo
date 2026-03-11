package user

import (
	"context"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	v1 "github.com/gqcn/platform/backend/api/user/v1"
)

// Create handles POST /api/user — admin creates a new user.
func (c *ControllerV1) Create(ctx context.Context, req *v1.CreateReq) (res *v1.CreateRes, err error) {
	id, uid, err := c.userSvc.Create(ctx, req.Username, req.Password, req.Email, req.IsAdmin)
	if err != nil {
		return nil, err
	}
	return &v1.CreateRes{Id: id, Uid: uid}, nil
}

// List handles GET /api/user — admin lists all users.
func (c *ControllerV1) List(ctx context.Context, req *v1.ListReq) (res *v1.ListRes, err error) {
	list, total, err := c.userSvc.List(ctx, req.Page, req.Size)
	if err != nil {
		return nil, err
	}
	items := make([]v1.UserItem, 0, len(list))
	for _, u := range list {
		createdAt := ""
		if u.CreatedAt != nil {
			createdAt = u.CreatedAt.Format("Y-m-d H:i:s")
		}
		items = append(items, v1.UserItem{
			Id:        u.Id,
			Username:  u.Username,
			Uid:       u.Uid,
			Email:     u.Email,
			IsAdmin:   u.IsAdmin,
			Status:    u.Status,
			CreatedAt: createdAt,
		})
	}
	return &v1.ListRes{List: items, Total: total}, nil
}

// UpdateStatus handles PUT /api/user/{id}/status — admin enable/disable user.
func (c *ControllerV1) UpdateStatus(ctx context.Context, req *v1.UpdateStatusReq) (res *v1.UpdateStatusRes, err error) {
	if u := c.bizCtxSvc.GetContextUser(ctx); u != nil && u.Id == req.Id {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "不能禁用或启用自己的账号")
	}
	return &v1.UpdateStatusRes{}, c.userSvc.UpdateStatus(ctx, req.Id, req.Status)
}

// Update handles PUT /api/user/{id} — admin edits user role and/or password.
func (c *ControllerV1) Update(ctx context.Context, req *v1.UpdateReq) (res *v1.UpdateRes, err error) {
	return &v1.UpdateRes{}, c.userSvc.Update(ctx, req.Id, req.Password, req.IsAdmin)
}

// Delete handles DELETE /api/user/{id} — admin soft-deletes a user.
func (c *ControllerV1) Delete(ctx context.Context, req *v1.DeleteReq) (res *v1.DeleteRes, err error) {
	if u := c.bizCtxSvc.GetContextUser(ctx); u != nil && u.Id == req.Id {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "不能删除自己的账号")
	}
	return &v1.DeleteRes{}, c.userSvc.Delete(ctx, req.Id)
}
