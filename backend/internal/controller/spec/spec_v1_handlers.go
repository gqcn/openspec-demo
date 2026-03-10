package spec

import (
	"context"

	v1 "github.com/gqcn/platform/backend/api/spec/v1"
	"github.com/gqcn/platform/backend/internal/model"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	svcSpec "github.com/gqcn/platform/backend/internal/service/spec"
)

// List handles GET /api/spec — returns all specs for admin, enabled-only for regular users.
func (c *ControllerV1) List(ctx context.Context, req *v1.ListReq) (res *v1.ListRes, err error) {
	// Admin sees all specs (including disabled); regular users see only enabled ones.
	ctxUser := model.GetContextUser(ctx)
	isAdmin := ctxUser != nil && ctxUser.IsAdmin == 1

	var list []*entity.Spec
	if isAdmin {
		list, err = svcSpec.ListAll(ctx)
	} else {
		list, err = svcSpec.List(ctx)
	}
	if err != nil {
		return nil, err
	}
	items := make([]v1.SpecItem, 0, len(list))
	for _, s := range list {
		items = append(items, v1.SpecItem{
			Id:          s.Id,
			Name:        s.Name,
			Description: s.Description,
			Cpu:         s.Cpu,
			Memory:      s.Memory,
			Gpu:         s.Gpu,
			GpuType:     s.GpuType,
			Enabled:     s.Enabled,
			SortOrder:   s.SortOrder,
		})
	}
	return &v1.ListRes{List: items}, nil
}

// Create handles POST /api/spec.
func (c *ControllerV1) Create(ctx context.Context, req *v1.CreateReq) (res *v1.CreateRes, err error) {
	id, err := svcSpec.Create(ctx, &do.Spec{
		Name:         req.Name,
		Description:  req.Description,
		Cpu:          req.Cpu,
		Memory:       req.Memory,
		Gpu:          req.Gpu,
		GpuType:      req.GpuType,
		NodeSelector: req.NodeSelector,
		Tolerations:  req.Tolerations,
		Enabled:      req.Enabled,
		SortOrder:    req.SortOrder,
	})
	if err != nil {
		return nil, err
	}
	return &v1.CreateRes{Id: id}, nil
}

// Update handles PUT /api/spec/{id}.
func (c *ControllerV1) Update(ctx context.Context, req *v1.UpdateReq) (res *v1.UpdateRes, err error) {
	err = svcSpec.Update(ctx, req.Id, &do.Spec{
		Name:         req.Name,
		Description:  req.Description,
		Cpu:          req.Cpu,
		Memory:       req.Memory,
		Gpu:          req.Gpu,
		GpuType:      req.GpuType,
		NodeSelector: req.NodeSelector,
		Tolerations:  req.Tolerations,
		Enabled:      req.Enabled,
		SortOrder:    req.SortOrder,
	})
	return &v1.UpdateRes{}, err
}

// Delete handles DELETE /api/spec/{id}.
func (c *ControllerV1) Delete(ctx context.Context, req *v1.DeleteReq) (res *v1.DeleteRes, err error) {
	return &v1.DeleteRes{}, svcSpec.Delete(ctx, req.Id)
}
