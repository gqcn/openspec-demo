// Package middleware provides HTTP middleware implementations.
package middleware

import (
	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/net/ghttp"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/model"
	"github.com/gqcn/platform/backend/internal/service/auth"
	"github.com/gqcn/platform/backend/internal/service/bizctx"
)

// Service provides HTTP middleware logic.
type Service struct {
	authSvc   *auth.Service
	bizCtxSvc *bizctx.Service
}

// New creates and returns a new Service instance.
func New(authSvc *auth.Service, bizCtxSvc *bizctx.Service) *Service {
	return &Service{authSvc: authSvc, bizCtxSvc: bizCtxSvc}
}

// HandlerResponse is a middleware that wraps all handler responses into a unified JSON structure.
func (s *Service) HandlerResponse(r *ghttp.Request) {
	r.Middleware.Next()

	// If a middleware (e.g. Auth) already wrote its own response, skip wrapping.
	if len(r.Response.Buffer()) > 0 {
		return
	}

	var (
		msg  string
		err             = r.GetError()
		res             = r.GetHandlerResponse()
		code gcode.Code = gcode.CodeOK
	)
	if err != nil {
		code = gcode.CodeInternalError
		msg = err.Error()
		errCode := gerror.Code(err)
		if errCode.Code() > 0 {
			code = errCode
		}
		r.Response.WriteJson(g.Map{
			"code":    code.Code(),
			"message": msg,
			"data":    nil,
		})
		return
	}
	r.Response.WriteJson(g.Map{
		"code":    0,
		"message": "success",
		"data":    res,
	})
}

// CORS sets permissive CORS headers.
func (s *Service) CORS(r *ghttp.Request) {
	r.Response.CORSDefault()
	r.Middleware.Next()
}

// Auth validates the JWT Bearer token and injects ContextUser into the request context.
func (s *Service) Auth(r *ghttp.Request) {
	token := r.GetHeader("Authorization")
	if len(token) > 7 && token[:7] == "Bearer " {
		token = token[7:]
	}
	claims, err := s.authSvc.ParseToken(r.GetCtx(), token)
	if err != nil {
		r.Response.WriteJson(g.Map{
			"code":    401,
			"message": "未授权，请先登录",
			"data":    nil,
		})
		r.ExitAll()
		return
	}
	r.SetCtxVar(consts.ContextKeyUser, &model.ContextUser{
		Id:       claims.UserId,
		Username: claims.Username,
		IsAdmin:  claims.IsAdmin,
		Uid:      claims.Uid,
	})
	r.Middleware.Next()
}

// AdminOnly allows only admin users (must be used after Auth middleware).
func (s *Service) AdminOnly(r *ghttp.Request) {
	u := s.bizCtxSvc.GetContextUser(r.GetCtx())
	if u == nil {
		r.Response.WriteJson(g.Map{"code": 403, "message": "无权限", "data": nil})
		r.ExitAll()
		return
	}
	if u.IsAdmin != 1 {
		r.Response.WriteJson(g.Map{"code": 403, "message": "仅管理员可操作", "data": nil})
		r.ExitAll()
		return
	}
	r.Middleware.Next()
}
