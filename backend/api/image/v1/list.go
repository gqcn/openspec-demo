// Package image provides image-related API definitions.
package image

import "github.com/gogf/gf/v2/frame/g"

// ListReq defines the image list request.
type ListReq struct {
	g.Meta `path:"/image" method:"get" tags:"Image" summary:"获取可用镜像列表"`
}

// ImageItem represents a single image config entry.
type ImageItem struct {
	Key         string `json:"key"         description:"镜像唯一标识"`
	Name        string `json:"name"        description:"显示名称"`
	Image       string `json:"image"       description:"完整镜像地址"`
	Description string `json:"description" description:"镜像描述"`
}

// ListRes defines the image list response.
type ListRes struct {
	List []ImageItem `json:"list"`
}
