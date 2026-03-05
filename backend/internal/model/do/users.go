// =================================================================================
// Code generated and maintained by GoFrame CLI tools. DO NOT EDIT.
// =================================================================================

package do

import "github.com/gogf/gf/v2/frame/g"

// User is the golang structure of table users for DAO operations like Where/Data.
type User struct {
	g.Meta       `orm:"table:users, do:true"`
	Id           interface{}
	Username     interface{}
	PasswordHash interface{}
	Uid          interface{}
	Email        interface{}
	IsAdmin      interface{}
	Status       interface{}
}
