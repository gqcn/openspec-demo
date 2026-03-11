// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package internal

import (
	"context"

	"github.com/gogf/gf/v2/database/gdb"
	"github.com/gogf/gf/v2/frame/g"
)

// InstancesDao is the data access object for the table instances.
type InstancesDao struct {
	table   string
	group   string
	columns InstancesColumns
}

// InstancesColumns defines and stores column names for the table instances.
type InstancesColumns struct {
	Id           string
	UserId       string
	Username     string
	PodName      string
	SpecId       string
	ImageKey     string
	Image        string
	Token        string
	Status       string
	PodIp        string
	NodeName     string
	LastActiveAt string
	IdleSince    string
	StoppedAt    string
	CreatedAt    string
	UpdatedAt    string
}

// instancesColumns holds the columns for table instances.
var instancesColumns = InstancesColumns{
	Id:           "id",
	UserId:       "user_id",
	Username:     "username",
	PodName:      "pod_name",
	SpecId:       "spec_id",
	ImageKey:     "image_key",
	Image:        "image",
	Token:        "token",
	Status:       "status",
	PodIp:        "pod_ip",
	NodeName:     "node_name",
	LastActiveAt: "last_active_at",
	IdleSince:    "idle_since",
	StoppedAt:    "stopped_at",
	CreatedAt:    "created_at",
	UpdatedAt:    "updated_at",
}

// NewInstancesDao creates and returns a new DAO object for table instances.
func NewInstancesDao() *InstancesDao {
	return &InstancesDao{
		group:   "default",
		table:   "instances",
		columns: instancesColumns,
	}
}

// DB retrieves and returns the underlying raw database management object of the current DAO.
func (dao *InstancesDao) DB() gdb.DB {
	return g.DB(dao.group)
}

// Table returns the table name of the current dao.
func (dao *InstancesDao) Table() string {
	return dao.table
}

// Columns returns all column names of the current dao.
func (dao *InstancesDao) Columns() InstancesColumns {
	return dao.columns
}

// Group returns the configuration group name of the database of the current dao.
func (dao *InstancesDao) Group() string {
	return dao.group
}

// Ctx creates and returns a Model for the current DAO. It automatically sets the context for the current operation.
func (dao *InstancesDao) Ctx(ctx context.Context) *gdb.Model {
	return dao.DB().Model(dao.table).Safe().Ctx(ctx)
}

// Transaction wraps the transaction logic using function f.
func (dao *InstancesDao) Transaction(ctx context.Context, f func(ctx context.Context, tx gdb.TX) error) (err error) {
	return dao.Ctx(ctx).Transaction(ctx, f)
}
