// Package image implements the image HTTP controller.
package image

import svcImage "github.com/gqcn/platform/backend/internal/service/image"

// ControllerV1 implements the image API v1 handlers.
type ControllerV1 struct {
	imageSvc *svcImage.Service
}

// NewV1 returns a new ControllerV1 instance.
func NewV1(imageSvc *svcImage.Service) *ControllerV1 {
	return &ControllerV1{imageSvc: imageSvc}
}
