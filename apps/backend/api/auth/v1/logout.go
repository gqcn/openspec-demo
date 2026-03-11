package auth

import "github.com/gogf/gf/v2/frame/g"

// LogoutReq defines the logout request.
type LogoutReq struct {
	g.Meta `path:"/auth/logout" method:"post" tags:"Auth" summary:"退出登录"`
}

// LogoutRes defines the logout response.
type LogoutRes struct{}
