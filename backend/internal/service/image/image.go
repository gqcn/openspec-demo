// Package image provides business logic for reading available images from config.
package image

import (
	"context"

	"github.com/gogf/gf/v2/frame/g"
)

// ImageConfig matches the structure in manifest/config/config.yaml under "images".
type ImageConfig struct {
	Key         string `yaml:"key"`
	Name        string `yaml:"name"`
	Image       string `yaml:"image"`
	Description string `yaml:"description"`
	Enabled     bool   `yaml:"enabled"`
}

// List returns all enabled images from the application config file.
func List(ctx context.Context) (list []ImageConfig, err error) {
	var all []ImageConfig
	err = g.Cfg().MustGet(ctx, "images").Scan(&all)
	if err != nil {
		return nil, err
	}
	for _, img := range all {
		if img.Enabled {
			list = append(list, img)
		}
	}
	return
}

// GetByKey returns a single image config by key, or nil if not found.
func GetByKey(ctx context.Context, key string) (*ImageConfig, error) {
	all, err := List(ctx)
	if err != nil {
		return nil, err
	}
	for _, img := range all {
		if img.Key == key {
			c := img
			return &c, nil
		}
	}
	return nil, nil
}
