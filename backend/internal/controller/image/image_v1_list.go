package image

import (
	"context"

	v1 "github.com/gqcn/platform/backend/api/image/v1"
	svcImage "github.com/gqcn/platform/backend/internal/service/image"
)

// List handles GET /api/image.
func (c *ControllerV1) List(ctx context.Context, req *v1.ListReq) (res *v1.ListRes, err error) {
	list, err := svcImage.List(ctx)
	if err != nil {
		return nil, err
	}
	items := make([]v1.ImageItem, 0, len(list))
	for _, img := range list {
		items = append(items, v1.ImageItem{
			Key:         img.Key,
			Name:        img.Name,
			Image:       img.Image,
			Description: img.Description,
		})
	}
	return &v1.ListRes{List: items}, nil
}
