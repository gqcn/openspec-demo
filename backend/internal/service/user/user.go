// Package user provides business logic for user management.
package user

import (
	"context"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	"github.com/gqcn/platform/backend/internal/service/auth"
)

// Create creates a new user with an automatically computed UID.
func Create(ctx context.Context, username, password, email string, isAdmin uint) (id, uid uint, err error) {
	// Check for duplicate username
	count, err := dao.Users.Ctx(ctx).Where("username", username).Count()
	if err != nil {
		return 0, 0, err
	}
	if count > 0 {
		return 0, 0, gerror.NewCode(gcode.CodeBusinessValidationFailed, "用户名已存在")
	}

	hash, err := auth.HashPassword(password)
	if err != nil {
		return 0, 0, err
	}

	res, err := dao.Users.Ctx(ctx).Data(&do.User{
		Username:     username,
		PasswordHash: hash,
		Email:        email,
		IsAdmin:      isAdmin,
		Status:       1,
	}).Insert()
	if err != nil {
		return 0, 0, err
	}
	lastId, err := res.LastInsertId()
	if err != nil {
		return 0, 0, err
	}
	id = uint(lastId)
	uid = uint(lastId) + consts.UIDOffset

	// Update uid field (uid = 10000 + id)
	_, err = dao.Users.Ctx(ctx).Where("id", id).Data(do.User{Uid: uid}).Update()
	return
}

// List returns paginated user list.
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

// GetById returns a user by ID.
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
