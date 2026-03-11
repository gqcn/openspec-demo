package notebook

import "github.com/gogf/gf/v2/frame/g"

// CreateReq defines the create notebook request.
type CreateReq struct {
	g.Meta   `path:"/notebook" method:"post" tags:"Notebook" summary:"创建开发机实例"`
	SpecId   uint   `json:"specId"   v:"required#规格不能为空"`
	ImageKey string `json:"imageKey" v:"required#镜像不能为空"`
}

// CreateRes defines the create notebook response.
type CreateRes struct {
	Id        uint   `json:"id"`
	Token     string `json:"token"`
	AccessUrl string `json:"accessUrl"`
}
