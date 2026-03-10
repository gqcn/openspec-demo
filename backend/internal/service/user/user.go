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

// Create creates a new user with an automatically computed UID.
func Create(ctx context.Context, username, password, email string, isAdmin uint) (id, uid uint, err error) {
	// Validate Linux username format
	if !linuxUsernameRe.MatchString(username) {
		return 0, 0, gerror.NewCode(gcode.CodeBusinessValidationFailed,
			"用户名格式不合法，须以小写字母或下划线开头，只能包含小写字母、数字、下划线、连字符，且不超过 32 个字符")
	}

	err = dao.Users.Transaction(ctx, func(ctx context.Context, tx gdb.TX) error {
		// Check for duplicate username (only among active/non-deleted users)
		// GoFrame ORM automatically excludes soft-deleted rows (deleted_at IS NULL) when the entity has the deleted_at field.
		count, e := dao.Users.Ctx(ctx).TX(tx).Where("username", username).Count()
		if e != nil {
			return e
		}
		if count > 0 {
			return gerror.NewCode(gcode.CodeBusinessValidationFailed, "用户名已存在")
		}

		hash, e := auth.HashPassword(password)
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
		_, e = dao.Users.Ctx(ctx).TX(tx).Where("id", id).Data(g.Map{"uid": uid}).Update()
		return e
	})
	return
}

// List returns paginated user list (excluding soft-deleted users).
func List(ctx context.Context, page, size int) (list []*entity.User, total int, err error) {
	m := dao.Users.Ctx(ctx)
	total, err = m.Count()
	if err != nil {
		return
	}
	err = m.Page(page, size).OrderAsc("id").Scan(&list)
	return
}

// UpdateStatus enables or disables a user.
func UpdateStatus(ctx context.Context, id, status uint) error {
	_, err := dao.Users.Ctx(ctx).Where("id", id).Data(do.User{Status: status}).Update()
	return err
}

// Update modifies a user's role and/or password.
func Update(ctx context.Context, id uint, password string, isAdmin *uint) error {
	data := g.Map{}
	if password != "" {
		hash, err := auth.HashPassword(password)
		if err != nil {
			return err
		}
		data["password_hash"] = hash
	}
	if isAdmin != nil {
		data["is_admin"] = *isAdmin
	}
	if len(data) == 0 {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "未提供任何修改字段")
	}
	_, err := dao.Users.Ctx(ctx).Where("id", id).Data(data).Update()
	return err
}

// GetById returns a user by ID (excluding soft-deleted users).
func GetById(ctx context.Context, id uint) (user *entity.User, err error) {
	err = dao.Users.Ctx(ctx).Where("id", id).Scan(&user)
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
func Delete(ctx context.Context, id uint) error {
	u, err := GetById(ctx, id)
	if err != nil {
		return err
	}
	if u.Id == 1 {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "不能删除主管理员账号")
	}
	_, err = dao.Users.Ctx(ctx).Where("id", id).Delete()
	return err
}
