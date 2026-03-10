// Package notebook implements the notebook HTTP controller.
package notebook

import (
	svcBizctx "github.com/gqcn/platform/backend/internal/service/bizctx"
	svcImage "github.com/gqcn/platform/backend/internal/service/image"
	svcNotebook "github.com/gqcn/platform/backend/internal/service/notebook"
	svcSpec "github.com/gqcn/platform/backend/internal/service/spec"
)

// ControllerV1 implements the notebook API v1 handlers.
type ControllerV1 struct {
	notebookSvc *svcNotebook.Service
	specSvc     *svcSpec.Service
	imageSvc    *svcImage.Service
	bizCtxSvc   *svcBizctx.Service
}

// NewV1 returns a new ControllerV1 instance.
func NewV1(notebookSvc *svcNotebook.Service, specSvc *svcSpec.Service, imageSvc *svcImage.Service, bizCtxSvc *svcBizctx.Service) *ControllerV1 {
	return &ControllerV1{
		notebookSvc: notebookSvc,
		specSvc:     specSvc,
		imageSvc:    imageSvc,
		bizCtxSvc:   bizCtxSvc,
	}
}
