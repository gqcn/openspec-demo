// =================================================================================
// Code generated and maintained by GoFrame CLI tool. DO NOT EDIT.
// =================================================================================

package image

import (
	"context"

	v1 "github.com/gqcn/platform/backend/api/image/v1"
)

type IImageV1 interface {
	List(ctx context.Context, req *v1.ListReq) (res *v1.ListRes, err error)
}
