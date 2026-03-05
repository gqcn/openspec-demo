package spec

import "github.com/gogf/gf/v2/frame/g"

// CreateReq defines the create spec request.
type CreateReq struct {
	g.Meta       `path:"/spec" method:"post" tags:"Spec" summary:"新建规格套餐（管理员）"`
	Name         string `json:"name"        v:"required#套餐名称不能为空"`
	Description  string `json:"description"`
	Cpu          string `json:"cpu"         v:"required#CPU 规格不能为空"`
	Memory       string `json:"memory"      v:"required#内存规格不能为空"`
	Gpu          string `json:"gpu"`
	GpuType      string `json:"gpuType"`
	NodeSelector string `json:"nodeSelector"`
	Tolerations  string `json:"tolerations"`
	Enabled      uint   `json:"enabled"     d:"1"`
	SortOrder    int    `json:"sortOrder"`
}

// CreateRes defines the create spec response.
type CreateRes struct {
	Id uint `json:"id"`
}
