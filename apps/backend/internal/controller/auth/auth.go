// Package auth implements the auth HTTP controller.
package auth

import svcAuth "github.com/gqcn/platform/backend/internal/service/auth"

// ControllerV1 implements the auth API v1 handlers.
type ControllerV1 struct {
	authSvc *svcAuth.Service
}
