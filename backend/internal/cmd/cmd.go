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
	"github.com/gqcn/platform/backend/internal/service/cron"
	"github.com/gqcn/platform/backend/internal/service/middleware"
)

var Main = gcmd.Command{
	Name:  "main",
	Usage: "main",
	Brief: "start platform API server",
	Func:  run,
}

func run(ctx context.Context, _ *gcmd.Parser) error {
	s := g.Server()

	s.Group("/api", func(grp *ghttp.RouterGroup) {
		grp.Middleware(middleware.CORS, middleware.HandlerResponse)

		// 公开接口（无需登录）
		grp.Bind(controllerAuth.NewV1())

		// 需要登录的接口
		grp.Group("/", func(authed *ghttp.RouterGroup) {
			authed.Middleware(middleware.Auth)
			authed.Bind(
				controllerNotebook.NewV1(),
				controllerImage.NewV1(),
				controllerSpec.NewV1(),
				controllerUser.NewV1(),
			)
		})
	})

	// 启动闲置检测定时任务
	cron.StartIdleChecker(ctx)

	s.Run()
	return nil
}
