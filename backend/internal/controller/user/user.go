// Package user implements the user HTTP controller.
package user

// ControllerV1 implements the user API v1 handlers.
type ControllerV1 struct{}

// NewV1 returns a new ControllerV1 instance.
func NewV1() *ControllerV1 {
	return &ControllerV1{}
}
