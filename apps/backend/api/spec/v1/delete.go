package spec

import "github.com/gogf/gf/v2/frame/g"

// DeleteReq defines the delete spec request.
type DeleteReq struct {
	g.Meta `path:"/spec/{id}" method:"delete" tags:"Spec" summary:"删除规格套餐（管理员）"`
	Id     uint `json:"id" in:"path" v:"required"`
}

// DeleteRes defines the delete spec response.
type DeleteRes struct{}
