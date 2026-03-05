// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package entity

import "github.com/gogf/gf/v2/os/gtime"

// Instance is the golang structure for table instances.
type Instance struct {
	Id           uint        `json:"id"           orm:"id"             description:"实例 ID"`
	UserId       uint        `json:"userId"       orm:"user_id"        description:"所属用户 ID"`
	Username     string      `json:"username"     orm:"username"       description:"冗余用户名"`
	PodName      string      `json:"podName"      orm:"pod_name"       description:"K8S Pod 名称"`
	SpecId       uint        `json:"specId"       orm:"spec_id"        description:"规格套餐 ID"`
	ImageKey     string      `json:"imageKey"     orm:"image_key"      description:"镜像配置 key"`
	Image        string      `json:"image"        orm:"image"          description:"完整镜像地址（快照）"`
	Token        string      `json:"token"        orm:"token"          description:"JupyterLab token / 路由 key"`
	Status       string      `json:"status"       orm:"status"         description:"实例状态"`
	PodIp        string      `json:"podIp"        orm:"pod_ip"         description:"Pod IP"`
	NodeName     string      `json:"nodeName"     orm:"node_name"      description:"调度节点名"`
	LastActiveAt *gtime.Time `json:"lastActiveAt" orm:"last_active_at" description:"最近活跃时间"`
	IdleSince    *gtime.Time `json:"idleSince"    orm:"idle_since"     description:"首次闲置时间"`
	StoppedAt    *gtime.Time `json:"stoppedAt"    orm:"stopped_at"     description:"停止时间"`
	CreatedAt    *gtime.Time `json:"createdAt"    orm:"created_at"`
	UpdatedAt    *gtime.Time `json:"updatedAt"    orm:"updated_at"`
}
