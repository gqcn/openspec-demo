package spec

import "github.com/gogf/gf/v2/frame/g"

// UpdateReq defines the update spec request.
type UpdateReq struct {
	g.Meta       `path:"/spec/{id}" method:"put" tags:"Spec" summary:"修改规格套餐（管理员）"`
	Id           uint   `json:"id"    in:"path" v:"required"`
	Name         string `json:"name"`
	Description  string `json:"description"`
	Cpu          string `json:"cpu"`
	Memory       string `json:"memory"`
	Gpu          string `json:"gpu"`
	GpuType      string `json:"gpuType"`
	NodeSelector string `json:"nodeSelector"`
	Tolerations  string `json:"tolerations"`
	Enabled      *uint  `json:"enabled"`
	SortOrder    *int   `json:"sortOrder"`
}

// UpdateRes defines the update spec response.
type UpdateRes struct{}
