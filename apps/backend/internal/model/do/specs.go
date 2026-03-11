// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package do

import "github.com/gogf/gf/v2/frame/g"

// Spec is the golang structure of table specs for DAO operations like Where/Data.
type Spec struct {
	g.Meta       `orm:"table:specs, do:true"`
	Id           interface{}
	Name         interface{}
	Description  interface{}
	Cpu          interface{}
	Memory       interface{}
	Gpu          interface{}
	GpuType      interface{}
	NodeSelector interface{}
	Tolerations  interface{}
	Enabled      interface{}
	SortOrder    interface{}
}
