// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package entity

import "github.com/gogf/gf/v2/os/gtime"

// Spec is the golang structure for table specs.
type Spec struct {
	Id           uint        `json:"id"           orm:"id"            description:"套餐 ID"`
	Name         string      `json:"name"         orm:"name"          description:"套餐名称"`
	Description  string      `json:"description"  orm:"description"   description:"套餐描述"`
	Cpu          string      `json:"cpu"          orm:"cpu"           description:"CPU 规格（K8S 格式）"`
	Memory       string      `json:"memory"       orm:"memory"        description:"内存规格（K8S 格式）"`
	Gpu          string      `json:"gpu"          orm:"gpu"           description:"GPU 数量"`
	GpuType      string      `json:"gpuType"      orm:"gpu_type"      description:"GPU 资源类型"`
	NodeSelector string      `json:"nodeSelector" orm:"node_selector" description:"K8S nodeSelector JSON"`
	Tolerations  string      `json:"tolerations"  orm:"tolerations"   description:"K8S tolerations JSON"`
	Enabled      uint        `json:"enabled"      orm:"enabled"       description:"是否启用"`
	SortOrder    int         `json:"sortOrder"    orm:"sort_order"    description:"排序权重"`
	CreatedAt    *gtime.Time `json:"createdAt"    orm:"created_at"`
	UpdatedAt    *gtime.Time `json:"updatedAt"    orm:"updated_at"`
}
