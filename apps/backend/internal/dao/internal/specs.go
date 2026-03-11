// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package internal

import (
	"context"

	"github.com/gogf/gf/v2/database/gdb"
	"github.com/gogf/gf/v2/frame/g"
)

// SpecsDao is the data access object for the table specs.
type SpecsDao struct {
	table   string
	group   string
	columns SpecsColumns
}

// SpecsColumns defines and stores column names for the table specs.
type SpecsColumns struct {
	Id           string
	Name         string
	Description  string
	Cpu          string
	Memory       string
	Gpu          string
	GpuType      string
	NodeSelector string
	Tolerations  string
	Enabled      string
	SortOrder    string
	CreatedAt    string
	UpdatedAt    string
}

// specsColumns holds the columns for table specs.
var specsColumns = SpecsColumns{
	Id:           "id",
	Name:         "name",
	Description:  "description",
	Cpu:          "cpu",
	Memory:       "memory",
	Gpu:          "gpu",
	GpuType:      "gpu_type",
	NodeSelector: "node_selector",
	Tolerations:  "tolerations",
	Enabled:      "enabled",
	SortOrder:    "sort_order",
	CreatedAt:    "created_at",
	UpdatedAt:    "updated_at",
}

// NewSpecsDao creates and returns a new DAO object for table specs.
func NewSpecsDao() *SpecsDao {
	return &SpecsDao{
		group:   "default",
		table:   "specs",
		columns: specsColumns,
	}
}

// DB retrieves and returns the underlying raw database management object of the current DAO.
func (dao *SpecsDao) DB() gdb.DB {
	return g.DB(dao.group)
}

// Table returns the table name of the current dao.
func (dao *SpecsDao) Table() string {
	return dao.table
}

// Columns returns all column names of the current dao.
func (dao *SpecsDao) Columns() SpecsColumns {
	return dao.columns
}

// Group returns the configuration group name of the database of the current dao.
func (dao *SpecsDao) Group() string {
	return dao.group
}

// Ctx creates and returns a Model for the current DAO. It automatically sets the context for the current operation.
func (dao *SpecsDao) Ctx(ctx context.Context) *gdb.Model {
	return dao.DB().Model(dao.table).Safe().Ctx(ctx)
}

// Transaction wraps the transaction logic using function f.
func (dao *SpecsDao) Transaction(ctx context.Context, f func(ctx context.Context, tx gdb.TX) error) (err error) {
	return dao.Ctx(ctx).Transaction(ctx, f)
}
