// Package spec implements the spec HTTP controller.
package spec

// ControllerV1 implements the spec API v1 handlers.
type ControllerV1 struct{}

// NewV1 returns a new ControllerV1 instance.
func NewV1() *ControllerV1 {
	return &ControllerV1{}
}
