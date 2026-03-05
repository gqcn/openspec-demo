// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package entity

import "github.com/gogf/gf/v2/os/gtime"

// User is the golang structure for table users.
type User struct {
	Id           uint        `json:"id"           orm:"id"            description:"用户 ID"`
	Username     string      `json:"username"     orm:"username"      description:"用户名（登录账号）"`
	PasswordHash string      `json:"-"            orm:"password_hash" description:"bcrypt 哈希密码"`
	Uid          uint        `json:"uid"          orm:"uid"           description:"容器内 UID，= 10000 + id"`
	Email        string      `json:"email"        orm:"email"         description:"邮箱"`
	IsAdmin      uint        `json:"isAdmin"      orm:"is_admin"      description:"是否管理员：0=否 1=是"`
	Status       uint        `json:"status"       orm:"status"        description:"账号状态：1=正常 0=禁用"`
	CreatedAt    *gtime.Time `json:"createdAt"    orm:"created_at"`
	UpdatedAt    *gtime.Time `json:"updatedAt"    orm:"updated_at"`
}
