// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package do

import "github.com/gogf/gf/v2/frame/g"

// Instance is the golang structure of table instances for DAO operations like Where/Data.
type Instance struct {
	g.Meta       `orm:"table:instances, do:true"`
	Id           interface{}
	UserId       interface{}
	Username     interface{}
	PodName      interface{}
	SpecId       interface{}
	ImageKey     interface{}
	Image        interface{}
	Token        interface{}
	Status       interface{}
	PodIp        interface{}
	NodeName     interface{}
	LastActiveAt interface{}
	IdleSince    interface{}
	StoppedAt    interface{}
}
