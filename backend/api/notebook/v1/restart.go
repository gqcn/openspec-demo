package notebook

import "github.com/gogf/gf/v2/frame/g"

// RestartReq defines the restart notebook request.
type RestartReq struct {
	g.Meta `path:"/notebook/{id}/restart" method:"post" tags:"Notebook" summary:"重启开发机实例"`
	Id     uint `json:"id" in:"path" v:"required"`
}

// RestartRes defines the restart notebook response.
type RestartRes struct{}
