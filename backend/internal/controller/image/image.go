// Package image implements the image HTTP controller.
package image

// ControllerV1 implements the image API v1 handlers.
type ControllerV1 struct{}

// NewV1 returns a new ControllerV1 instance.
func NewV1() *ControllerV1 {
	return &ControllerV1{}
}
