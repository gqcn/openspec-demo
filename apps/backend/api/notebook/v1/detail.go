package notebook

import (
	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/os/gtime"
)

// DetailReq defines the notebook detail request.
type DetailReq struct {
	g.Meta `path:"/notebook/{id}" method:"get" tags:"Notebook" summary:"获取开发机实例详情"`
	Id     uint `json:"id" in:"path" v:"required"`
}

// DetailRes defines the notebook detail response.
type DetailRes struct {
	Id           uint        `json:"id"`
	UserId       uint        `json:"userId"`
	Username     string      `json:"username"`
	SpecId       uint        `json:"specId"`
	SpecName     string      `json:"specName"`
	ImageKey     string      `json:"imageKey"`
	Image        string      `json:"image"`
	Token        string      `json:"token"`
	Status       string      `json:"status"`
	PodName      string      `json:"podName"`
	PodIp        string      `json:"podIp"`
	NodeName     string      `json:"nodeName"`
	AccessUrl    string      `json:"accessUrl"`
	LastActiveAt *gtime.Time `json:"lastActiveAt"`
	IdleSince    *gtime.Time `json:"idleSince"`
	CreatedAt    *gtime.Time `json:"createdAt"`
}
