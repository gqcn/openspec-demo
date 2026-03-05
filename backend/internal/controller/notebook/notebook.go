// Package notebook implements the notebook HTTP controller.
package notebook

// ControllerV1 implements the notebook API v1 handlers.
type ControllerV1 struct{}

// NewV1 returns a new ControllerV1 instance.
func NewV1() *ControllerV1 {
	return &ControllerV1{}
}
