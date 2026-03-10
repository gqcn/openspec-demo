package notebook

import (
	"context"

	v1 "github.com/gqcn/platform/backend/api/notebook/v1"
)

// List handles GET /api/notebook.
func (c *ControllerV1) List(ctx context.Context, req *v1.ListReq) (res *v1.ListRes, err error) {
	u := c.bizCtxSvc.GetContextUser(ctx)
	list, err := c.notebookSvc.List(ctx, u.Id, u.IsAdmin)
	if err != nil {
		return nil, err
	}

	// Build spec/image name lookup maps
	specs, _ := c.specSvc.ListAllUnpaged(ctx)
	specMap := map[uint]string{}
	for _, s := range specs {
		specMap[s.Id] = s.Name
	}
	images, _ := c.imageSvc.List(ctx)
	imageMap := map[string]string{}
	for _, img := range images {
		imageMap[img.Key] = img.Name
	}

	items := make([]v1.NotebookItem, 0, len(list))
	for _, ins := range list {
		items = append(items, v1.NotebookItem{
			Id:           ins.Id,
			Username:     ins.Username,
			SpecId:       ins.SpecId,
			SpecName:     specMap[ins.SpecId],
			ImageKey:     ins.ImageKey,
			ImageName:    imageMap[ins.ImageKey],
			Token:        ins.Token,
			Status:       ins.Status,
			PodIp:        ins.PodIp,
			NodeName:     ins.NodeName,
			AccessUrl:    c.notebookSvc.AccessURL(ctx, ins.Token),
			LastActiveAt: ins.LastActiveAt,
			CreatedAt:    ins.CreatedAt,
		})
	}
	return &v1.ListRes{List: items}, nil
}

// Detail handles GET /api/notebook/{id}.
func (c *ControllerV1) Detail(ctx context.Context, req *v1.DetailReq) (res *v1.DetailRes, err error) {
	u := c.bizCtxSvc.GetContextUser(ctx)
	ins, err := c.notebookSvc.GetById(ctx, req.Id, u.Id, u.IsAdmin)
	if err != nil {
		return nil, err
	}

	specs, _ := c.specSvc.ListAllUnpaged(ctx)
	specMap := map[uint]string{}
	for _, s := range specs {
		specMap[s.Id] = s.Name
	}

	return &v1.DetailRes{
		Id:           ins.Id,
		UserId:       ins.UserId,
		Username:     ins.Username,
		SpecId:       ins.SpecId,
		SpecName:     specMap[ins.SpecId],
		ImageKey:     ins.ImageKey,
		Image:        ins.Image,
		Token:        ins.Token,
		Status:       ins.Status,
		PodName:      ins.PodName,
		PodIp:        ins.PodIp,
		NodeName:     ins.NodeName,
		AccessUrl:    c.notebookSvc.AccessURL(ctx, ins.Token),
		LastActiveAt: ins.LastActiveAt,
		IdleSince:    ins.IdleSince,
		CreatedAt:    ins.CreatedAt,
	}, nil
}

// Create handles POST /api/notebook.
func (c *ControllerV1) Create(ctx context.Context, req *v1.CreateReq) (res *v1.CreateRes, err error) {
	u := c.bizCtxSvc.GetContextUser(ctx)
	ins, err := c.notebookSvc.Create(ctx, u.Id, u.Username, u.Uid, req.SpecId, req.ImageKey)
	if err != nil {
		return nil, err
	}
	return &v1.CreateRes{
		Id:        ins.Id,
		Token:     ins.Token,
		AccessUrl: c.notebookSvc.AccessURL(ctx, ins.Token),
	}, nil
}

// Delete handles DELETE /api/notebook/{id}.
func (c *ControllerV1) Delete(ctx context.Context, req *v1.DeleteReq) (res *v1.DeleteRes, err error) {
	u := c.bizCtxSvc.GetContextUser(ctx)
	return &v1.DeleteRes{}, c.notebookSvc.Delete(ctx, req.Id, u.Id, u.IsAdmin)
}

// Restart handles POST /api/notebook/{id}/restart.
func (c *ControllerV1) Restart(ctx context.Context, req *v1.RestartReq) (res *v1.RestartRes, err error) {
	u := c.bizCtxSvc.GetContextUser(ctx)
	return &v1.RestartRes{}, c.notebookSvc.Restart(ctx, req.Id, u.Id, u.IsAdmin)
}
