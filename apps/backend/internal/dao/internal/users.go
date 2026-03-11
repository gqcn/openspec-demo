// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package internal

import (
	"context"

	"github.com/gogf/gf/v2/database/gdb"
	"github.com/gogf/gf/v2/frame/g"
)

// UsersDao is the data access object for the table users.
type UsersDao struct {
	table   string
	group   string
	columns UsersColumns
}

// UsersColumns defines and stores column names for the table users.
type UsersColumns struct {
	Id           string
	Username     string
	PasswordHash string
	Uid          string
	Email        string
	IsAdmin      string
	Status       string
	CreatedAt    string
	UpdatedAt    string
}

// usersColumns holds the columns for table users.
var usersColumns = UsersColumns{
	Id:           "id",
	Username:     "username",
	PasswordHash: "password_hash",
	Uid:          "uid",
	Email:        "email",
	IsAdmin:      "is_admin",
	Status:       "status",
	CreatedAt:    "created_at",
	UpdatedAt:    "updated_at",
}

// NewUsersDao creates and returns a new DAO object for table users.
func NewUsersDao() *UsersDao {
	return &UsersDao{
		group:   "default",
		table:   "users",
		columns: usersColumns,
	}
}

// DB retrieves and returns the underlying raw database management object of the current DAO.
func (dao *UsersDao) DB() gdb.DB {
	return g.DB(dao.group)
}

// Table returns the table name of the current dao.
func (dao *UsersDao) Table() string {
	return dao.table
}

// Columns returns all column names of the current dao.
func (dao *UsersDao) Columns() UsersColumns {
	return dao.columns
}

// Group returns the configuration group name of the database of the current dao.
func (dao *UsersDao) Group() string {
	return dao.group
}

// Ctx creates and returns a Model for the current DAO. It automatically sets the context for the current operation.
func (dao *UsersDao) Ctx(ctx context.Context) *gdb.Model {
	return dao.DB().Model(dao.table).Safe().Ctx(ctx)
}

// Transaction wraps the transaction logic using function f.
func (dao *UsersDao) Transaction(ctx context.Context, f func(ctx context.Context, tx gdb.TX) error) (err error) {
	return dao.Ctx(ctx).Transaction(ctx, f)
}
