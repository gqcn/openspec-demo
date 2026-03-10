// Package user implements the user HTTP controller.
package user

import svcUser "github.com/gqcn/platform/backend/internal/service/user"

// ControllerV1 implements the user API v1 handlers.
type ControllerV1 struct {
	userSvc *svcUser.Service
}

// NewV1 returns a new ControllerV1 instance.
func NewV1(userSvc *svcUser.Service) *ControllerV1 {
	return &ControllerV1{userSvc: userSvc}
}
