// Package user provides user-related API definitions.
package user

import "github.com/gogf/gf/v2/frame/g"

// CreateReq defines the create user request (admin only).
type CreateReq struct {
	g.Meta   `path:"/user" method:"post" tags:"User" summary:"创建用户（管理员）"`
	Username string `json:"username" v:"required#用户名不能为空|min-length:3#用户名至少3个字符"`
	Password string `json:"password" v:"required#密码不能为空|min-length:8#密码至少8位"`
	Email    string `json:"email"    v:"email#邮箱格式不正确"`
	IsAdmin  uint   `json:"isAdmin"  d:"0"`
}

// CreateRes defines the create user response.
type CreateRes struct {
	Id  uint `json:"id"`
	Uid uint `json:"uid"`
}

// ListReq defines the user list request (admin only).
type ListReq struct {
	g.Meta `path:"/user" method:"get" tags:"User" summary:"用户列表（管理员）"`
	Page   int `json:"page" d:"1"`
	Size   int `json:"size" d:"20"`
}

// UserItem represents a single user in list.
type UserItem struct {
	Id        uint   `json:"id"`
	Username  string `json:"username"`
	Uid       uint   `json:"uid"`
	Email     string `json:"email"`
	IsAdmin   uint   `json:"isAdmin"`
	Status    uint   `json:"status"`
	CreatedAt string `json:"createdAt"`
}

// ListRes defines the user list response.
type ListRes struct {
	List  []UserItem `json:"list"`
	Total int        `json:"total"`
}

// UpdateStatusReq defines the update user status request (admin only).
type UpdateStatusReq struct {
	g.Meta `path:"/user/{id}/status" method:"put" tags:"User" summary:"启用/禁用用户（管理员）"`
	Id     uint `json:"id"     in:"path" v:"required"`
	Status uint `json:"status" v:"required|in:0,1#状态值只能为 0 或 1"`
}

// UpdateStatusRes defines the update user status response.
type UpdateStatusRes struct{}

// UpdateReq defines the update user request (admin only) — role and/or password.
type UpdateReq struct {
	g.Meta   `path:"/user/{id}" method:"put" tags:"User" summary:"修改用户信息（管理员）"`
	Id       uint   `json:"id"       in:"path" v:"required"`
	IsAdmin  *uint  `json:"isAdmin"`
	Password string `json:"password"`
}

// UpdateRes defines the update user response.
type UpdateRes struct{}

// DeleteReq defines the delete user request (admin only) — soft delete.
type DeleteReq struct {
	g.Meta `path:"/user/{id}" method:"delete" tags:"User" summary:"软删除用户（管理员）"`
	Id     uint `json:"id" in:"path" v:"required"`
}

// DeleteRes defines the delete user response.
type DeleteRes struct{}
