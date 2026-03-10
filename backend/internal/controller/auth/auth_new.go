package auth

import svcAuth "github.com/gqcn/platform/backend/internal/service/auth"

// NewV1 returns a new ControllerV1 instance.
func NewV1(authSvc *svcAuth.Service) *ControllerV1 {
	return &ControllerV1{authSvc: authSvc}
}
