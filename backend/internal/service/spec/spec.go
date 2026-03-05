// Package spec provides business logic for spec (resource quota) management.
package spec

import (
	"context"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
)

// List returns all enabled specs ordered by sort_order.
func List(ctx context.Context) (list []*entity.Spec, err error) {
	err = dao.Specs.Ctx(ctx).Where("enabled", 1).OrderAsc("sort_order").Scan(&list)
	return
}

// ListAll returns all specs including disabled ones (admin use).
func ListAll(ctx context.Context) (list []*entity.Spec, err error) {
	err = dao.Specs.Ctx(ctx).OrderAsc("sort_order").Scan(&list)
	return
}

// GetById returns a spec by ID.
func GetById(ctx context.Context, id uint) (spec *entity.Spec, err error) {
	err = dao.Specs.Ctx(ctx).Where("id", id).Scan(&spec)
	if err != nil {
		return nil, err
	}
	if spec == nil {
		return nil, gerror.NewCode(gcode.CodeNotFound, "规格套餐不存在")
	}
	return
}

// Create inserts a new spec record.
func Create(ctx context.Context, in *do.Spec) (id uint, err error) {
	res, err := dao.Specs.Ctx(ctx).Data(in).Insert()
	if err != nil {
		return 0, err
	}
	lastId, err := res.LastInsertId()
	return uint(lastId), err
}

// Update modifies a spec record.
func Update(ctx context.Context, id uint, in *do.Spec) error {
	_, err := dao.Specs.Ctx(ctx).Where("id", id).Data(in).Update()
	return err
}

// Delete removes a spec by ID.
func Delete(ctx context.Context, id uint) error {
	_, err := dao.Specs.Ctx(ctx).Where("id", id).Delete()
	return err
}
