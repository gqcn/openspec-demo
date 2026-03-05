// Package auth provides auth-related API definitions.
package auth

import "github.com/gogf/gf/v2/frame/g"

// LoginReq defines the login request.
type LoginReq struct {
	g.Meta   `path:"/auth/login" method:"post" tags:"Auth" summary:"用户登录"`
	Username string `json:"username" v:"required#用户名不能为空"`
	Password string `json:"password" v:"required#密码不能为空"`
}

// LoginRes defines the login response.
type LoginRes struct {
	Token string `json:"token" description:"JWT token"`
}
