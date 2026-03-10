// Package model provides application-level common data structures.
package model

// ContextUser stores authenticated user info in request context.
type ContextUser struct {
	Id       uint
	Username string
	IsAdmin  uint
	Uid      uint
}
