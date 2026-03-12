// Package user provides business logic for user management.
package user

import (
	"context"
	"regexp"

	"github.com/gogf/gf/v2/database/gdb"
	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gogf/gf/v2/frame/g"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	"github.com/gqcn/platform/backend/internal/service/auth"
)

// linuxUsernameRe enforces Linux username rules required by K8S pod startup scripts:
// must start with a lowercase letter or underscore, followed by at most 31
// characters of lowercase letters, digits, underscores, or hyphens.
var linuxUsernameRe = regexp.MustCompile(`^[a-z_][a-z0-9_-]{0,31}$`)

// Service provides user management business logic.
type Service struct {
	authSvc *auth.Service
}

// New creates and returns a new Service instance.
func New(authSvc *auth.Service) *Service {
	return &Service{authSvc: authSvc}
}

// Create creates a new user with an automatically computed UID.
func (s *Service) Create(ctx context.Context, username, password, email string, isAdmin uint) (id, uid uint, err error) {
	// Validate Linux username format
	if !linuxUsernameRe.MatchString(username) {
		return 0, 0, gerror.NewCode(gcode.CodeBusinessValidationFailed,
			"用户名格式不合法，须以小写字母或下划线开头，只能包含小写字母、数字、下划线、连字符，且不超过 32 个字符")
	}

	cols := dao.Users.Columns()
	err = dao.Users.Transaction(ctx, func(ctx context.Context, tx gdb.TX) error {
		// Check for duplicate username including soft-deleted users (MySQL UNIQUE constraint
		// covers all rows regardless of deleted_at, so we must use Unscoped).
		count, e := dao.Users.Ctx(ctx).TX(tx).Unscoped().Where(cols.Username, username).Count()
		if e != nil {
			return e
		}
		if count > 0 {
			return gerror.NewCode(gcode.CodeBusinessValidationFailed, "用户名已存在（含已删除用户），请使用其他用户名")
		}

		hash, e := s.authSvc.HashPassword(password)
		if e != nil {
			return e
		}

		res, e := dao.Users.Ctx(ctx).TX(tx).Data(&do.User{
			Username:     username,
			PasswordHash: hash,
			Email:        email,
			IsAdmin:      isAdmin,
			Uid:          uint(0), // placeholder; updated below to id+UIDOffset
			Status:       1,
		}).Insert()
		if e != nil {
			return e
		}
		lastId, e := res.LastInsertId()
		if e != nil {
			return e
		}
		id = uint(lastId)
		uid = id + consts.UIDOffset

		// Update uid field (uid = 10000 + id) in the same transaction
		_, e = dao.Users.Ctx(ctx).TX(tx).Where(cols.Id, id).Data(g.Map{cols.Uid: uid}).Update()
		return e
	})
	return
}

// List returns paginated user list (excluding soft-deleted users).
func (s *Service) List(ctx context.Context, page, size int) (list []*entity.User, total int, err error) {
	m := dao.Users.Ctx(ctx)
	total, err = m.Count()
	if err != nil {
		return
	}
	cols := dao.Users.Columns()
	err = m.Page(page, size).OrderAsc(cols.Id).Scan(&list)
	return
}

// UpdateStatus enables or disables a user.
func (s *Service) UpdateStatus(ctx context.Context, id, status uint) error {
	cols := dao.Users.Columns()
	_, err := dao.Users.Ctx(ctx).Where(cols.Id, id).Data(do.User{Status: status}).Update()
	return err
}

// Update modifies a user's role and/or password.
func (s *Service) Update(ctx context.Context, id uint, password string, isAdmin *uint) error {
	cols := dao.Users.Columns()
	data := g.Map{}
	if password != "" {
		hash, err := s.authSvc.HashPassword(password)
		if err != nil {
			return err
		}
		data[cols.PasswordHash] = hash
	}
	if isAdmin != nil {
		data[cols.IsAdmin] = *isAdmin
	}
	if len(data) == 0 {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "未提供任何修改字段")
	}
	_, err := dao.Users.Ctx(ctx).Where(cols.Id, id).Data(data).Update()
	return err
}

// GetById returns a user by ID (excluding soft-deleted users).
func (s *Service) GetById(ctx context.Context, id uint) (user *entity.User, err error) {
	cols := dao.Users.Columns()
	err = dao.Users.Ctx(ctx).Where(cols.Id, id).Scan(&user)
	if err != nil {
		return nil, err
	}
	if user == nil {
		return nil, gerror.NewCode(gcode.CodeNotFound, "用户不存在")
	}
	return
}

// Delete soft-deletes a user. The admin account (id=1) cannot be deleted to prevent lockout.
// GoFrame ORM automatically sets deleted_at when the entity struct contains that field.
func (s *Service) Delete(ctx context.Context, id uint) error {
	u, err := s.GetById(ctx, id)
	if err != nil {
		return err
	}
	if u.Id == 1 {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "不能删除主管理员账号")
	}
	cols := dao.Users.Columns()
	_, err = dao.Users.Ctx(ctx).Where(cols.Id, id).Delete()
	return err
}

// UpdateProfile updates the current user's email and/or password.
func (s *Service) UpdateProfile(ctx context.Context, userId uint, email, password string) error {
	cols := dao.Users.Columns()
	data := g.Map{}
	if email != "" {
		data[cols.Email] = email
	}
	if password != "" {
		hash, err := s.authSvc.HashPassword(password)
		if err != nil {
			return err
		}
		data[cols.PasswordHash] = hash
	}
	if len(data) == 0 {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "未提供任何修改字段")
	}
	_, err := dao.Users.Ctx(ctx).Where(cols.Id, userId).Data(data).Update()
	return err
}

