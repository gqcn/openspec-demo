package notebook

import "github.com/gogf/gf/v2/frame/g"

// DeleteReq defines the delete (stop) notebook request.
type DeleteReq struct {
	g.Meta `path:"/notebook/{id}" method:"delete" tags:"Notebook" summary:"停止并删除开发机实例"`
	Id     uint `json:"id" in:"path" v:"required"`
}

// DeleteRes defines the delete notebook response.
type DeleteRes struct{}
