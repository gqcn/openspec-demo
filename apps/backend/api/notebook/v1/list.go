// Package notebook provides notebook-related API definitions.
package notebook

import (
	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/os/gtime"
)

// ListReq defines the notebook list request.
type ListReq struct {
	g.Meta `path:"/notebook" method:"get" tags:"Notebook" summary:"获取开发机实例列表"`
}

// NotebookItem represents a single instance in list.
type NotebookItem struct {
	Id           uint        `json:"id"`
	Username     string      `json:"username"`
	SpecId       uint        `json:"specId"`
	SpecName     string      `json:"specName"`
	ImageKey     string      `json:"imageKey"`
	ImageName    string      `json:"imageName"`
	Token        string      `json:"token"`
	Status       string      `json:"status"`
	PodIp        string      `json:"podIp"`
	NodeName     string      `json:"nodeName"`
	AccessUrl    string      `json:"accessUrl"`
	LastActiveAt *gtime.Time `json:"lastActiveAt"`
	CreatedAt    *gtime.Time `json:"createdAt"`
}

// ListRes defines the notebook list response.
type ListRes struct {
	List []NotebookItem `json:"list"`
}
