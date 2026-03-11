// Package spec provides spec-related API definitions.
package spec

import "github.com/gogf/gf/v2/frame/g"

// ListReq defines the spec list request.
type ListReq struct {
	g.Meta `path:"/spec" method:"get" tags:"Spec" summary:"获取规格套餐列表"`
	Page   int `json:"page" d:"1"`
	Size   int `json:"size" d:"20"`
}

// SpecItem represents a single spec entry.
type SpecItem struct {
	Id          uint   `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Cpu         string `json:"cpu"`
	Memory      string `json:"memory"`
	Gpu         string `json:"gpu"`
	GpuType     string `json:"gpuType"`
	Enabled     uint   `json:"enabled"`
	SortOrder   int    `json:"sortOrder"`
	CreatedAt   string `json:"createdAt"`
}

// ListRes defines the spec list response.
type ListRes struct {
	List  []SpecItem `json:"list"`
	Total int        `json:"total"`
}
