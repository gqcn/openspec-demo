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

// Service provides spec management business logic.
type Service struct{}

// New creates and returns a new Service instance.
func New() *Service {
	return &Service{}
}

// List returns paginated enabled specs ordered by sort_order.
func (s *Service) List(ctx context.Context, page, size int) (list []*entity.Spec, total int, err error) {
	cols := dao.Specs.Columns()
	m := dao.Specs.Ctx(ctx).Where(cols.Enabled, 1)
	total, err = m.Count()
	if err != nil {
		return
	}
	err = m.Page(page, size).OrderAsc(cols.SortOrder).Scan(&list)
	return
}

// ListAll returns paginated specs including disabled ones (admin use).
func (s *Service) ListAll(ctx context.Context, page, size int) (list []*entity.Spec, total int, err error) {
	cols := dao.Specs.Columns()
	m := dao.Specs.Ctx(ctx)
	total, err = m.Count()
	if err != nil {
		return
	}
	err = m.Page(page, size).OrderAsc(cols.SortOrder).Scan(&list)
	return
}

// ListAllUnpaged returns all specs without pagination (for internal lookups like spec name maps).
func (s *Service) ListAllUnpaged(ctx context.Context) (list []*entity.Spec, err error) {
	cols := dao.Specs.Columns()
	err = dao.Specs.Ctx(ctx).OrderAsc(cols.SortOrder).Scan(&list)
	return
}

// GetById returns a spec by ID.
func (s *Service) GetById(ctx context.Context, id uint) (spec *entity.Spec, err error) {
	cols := dao.Specs.Columns()
	err = dao.Specs.Ctx(ctx).Where(cols.Id, id).Scan(&spec)
	if err != nil {
		return nil, err
	}
	if spec == nil {
		return nil, gerror.NewCode(gcode.CodeNotFound, "规格套餐不存在")
	}
	return
}

// Create inserts a new spec record.
func (s *Service) Create(ctx context.Context, in *do.Spec) (id uint, err error) {
	res, err := dao.Specs.Ctx(ctx).Data(in).OmitEmpty().Insert()
	if err != nil {
		return 0, err
	}
	lastId, err := res.LastInsertId()
	return uint(lastId), err
}

// Update modifies a spec record.
func (s *Service) Update(ctx context.Context, id uint, in *do.Spec) error {
	cols := dao.Specs.Columns()
	_, err := dao.Specs.Ctx(ctx).Where(cols.Id, id).Data(in).OmitEmpty().Update()
	return err
}

// Delete removes a spec by ID.
// It refuses to delete a spec that is still referenced by any instance to prevent dangling spec_id references.
func (s *Service) Delete(ctx context.Context, id uint) error {
	instCols := dao.Instances.Columns()
	count, err := dao.Instances.Ctx(ctx).Where(instCols.SpecId, id).Count()
	if err != nil {
		return err
	}
	if count > 0 {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "该规格套餐下存在开发机实例，无法删除")
	}
	cols := dao.Specs.Columns()
	_, err = dao.Specs.Ctx(ctx).Where(cols.Id, id).Delete()
	return err
}
