// Package spec implements the spec HTTP controller.
package spec

import (
	svcBizctx "github.com/gqcn/platform/backend/internal/service/bizctx"
	svcSpec "github.com/gqcn/platform/backend/internal/service/spec"
)

// ControllerV1 implements the spec API v1 handlers.
type ControllerV1 struct {
	specSvc   *svcSpec.Service
	bizCtxSvc *svcBizctx.Service
}

// NewV1 returns a new ControllerV1 instance.
func NewV1(specSvc *svcSpec.Service, bizCtxSvc *svcBizctx.Service) *ControllerV1 {
	return &ControllerV1{specSvc: specSvc, bizCtxSvc: bizCtxSvc}
}
