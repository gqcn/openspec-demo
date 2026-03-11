package cmd

import (
	"context"

	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/net/ghttp"
	"github.com/gogf/gf/v2/os/gcmd"

	controllerAuth "github.com/gqcn/platform/backend/internal/controller/auth"
	controllerImage "github.com/gqcn/platform/backend/internal/controller/image"
	controllerNotebook "github.com/gqcn/platform/backend/internal/controller/notebook"
	controllerSpec "github.com/gqcn/platform/backend/internal/controller/spec"
	controllerUser "github.com/gqcn/platform/backend/internal/controller/user"
	"github.com/gqcn/platform/backend/internal/service/auth"
	"github.com/gqcn/platform/backend/internal/service/bizctx"
	"github.com/gqcn/platform/backend/internal/service/cron"
	"github.com/gqcn/platform/backend/internal/service/image"
	"github.com/gqcn/platform/backend/internal/service/middleware"
	"github.com/gqcn/platform/backend/internal/service/notebook"
	"github.com/gqcn/platform/backend/internal/service/spec"
	"github.com/gqcn/platform/backend/internal/service/user"
)

var Main = gcmd.Command{
	Name:  "main",
	Usage: "main",
	Brief: "start platform API server",
	Func:  run,
}

func run(ctx context.Context, _ *gcmd.Parser) error {
	// Wire up services (dependency injection)
	authSvc := auth.New()
	bizCtxSvc := bizctx.New()
	imageSvc := image.New()
	specSvc := spec.New()
	userSvc := user.New(authSvc)
	notebookSvc := notebook.New(specSvc, imageSvc)
	middlewareSvc := middleware.New(authSvc, bizCtxSvc)
	cronSvc := cron.New()

	s := g.Server()

	s.Group("/api", func(grp *ghttp.RouterGroup) {
		grp.Middleware(middlewareSvc.CORS, middlewareSvc.HandlerResponse)

		// 公开接口（无需登录）
		grp.Bind(controllerAuth.NewV1(authSvc))

		// 需要登录的接口
		grp.Group("/", func(authed *ghttp.RouterGroup) {
			authed.Middleware(middlewareSvc.Auth)
			authed.Bind(
				controllerNotebook.NewV1(notebookSvc, specSvc, imageSvc, bizCtxSvc),
				controllerImage.NewV1(imageSvc),
				controllerSpec.NewV1(specSvc, bizCtxSvc),
				controllerUser.NewV1(userSvc, bizCtxSvc),
			)
		})
	})

	// 启动闲置检测定时任务
	cronSvc.StartIdleChecker(ctx)

	s.Run()
	return nil
}
