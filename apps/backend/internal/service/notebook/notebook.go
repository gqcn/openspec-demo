// Package notebook provides business logic for JupyterLab instance lifecycle management.
package notebook

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/gogf/gf/v2/errors/gcode"
	"github.com/gogf/gf/v2/errors/gerror"
	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/os/gtime"
	"github.com/gogf/gf/v2/util/guid"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	"github.com/gqcn/platform/backend/internal/service/image"
	svcK8s "github.com/gqcn/platform/backend/internal/service/k8s"
	"github.com/gqcn/platform/backend/internal/service/spec"
)

// Service provides JupyterLab instance lifecycle management business logic.
type Service struct {
	specSvc  *spec.Service
	imageSvc *image.Service
	k8sSvc   *svcK8s.Service
}

// New creates and returns a new Service instance.
func New(specSvc *spec.Service, imageSvc *image.Service, k8sSvc *svcK8s.Service) *Service {
	return &Service{
		specSvc:  specSvc,
		imageSvc: imageSvc,
		k8sSvc:   k8sSvc,
	}
}

// List returns all instances for the requesting user (or all if admin).
func (s *Service) List(ctx context.Context, userId uint, isAdmin uint) (list []*entity.Instance, err error) {
	cols := dao.Instances.Columns()
	m := dao.Instances.Ctx(ctx)
	if isAdmin != 1 {
		m = m.Where(cols.UserId, userId)
	}
	err = m.OrderDesc(cols.CreatedAt).Scan(&list)
	return
}

// GetById returns a single instance; non-admin can only see their own.
func (s *Service) GetById(ctx context.Context, id, userId uint, isAdmin uint) (ins *entity.Instance, err error) {
	cols := dao.Instances.Columns()
	m := dao.Instances.Ctx(ctx).Where(cols.Id, id)
	if isAdmin != 1 {
		m = m.Where(cols.UserId, userId)
	}
	err = m.Scan(&ins)
	if err != nil {
		return nil, err
	}
	if ins == nil {
		return nil, gerror.NewCode(gcode.CodeNotFound, "实例不存在")
	}
	return
}

// Create provisions a new JupyterLab instance for the user.
func (s *Service) Create(ctx context.Context, userId uint, username string, uid uint, specId uint, imageKey string) (ins *entity.Instance, err error) {
	cols := dao.Instances.Columns()
	// 1. Verify user has no active instance
	count, err := dao.Instances.Ctx(ctx).
		Where(cols.UserId, userId).
		WhereIn(cols.Status, []string{consts.StatusCreating, consts.StatusRunning, consts.StatusStopping}).
		Count()
	if err != nil {
		return nil, err
	}
	if count > 0 {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "您已有活跃的开发机实例，请先停止后再创建")
	}

	// 1b. Clean up stale stopped/failed records for this user before creating a new one.
	_, _ = dao.Instances.Ctx(ctx).
		Where(cols.UserId, userId).
		WhereIn(cols.Status, []string{consts.StatusStopped, consts.StatusFailed}).
		Delete()

	// 2. Validate spec
	sp, err := s.specSvc.GetById(ctx, specId)
	if err != nil {
		return nil, err
	}

	// 3. Validate image
	imgCfg, err := s.imageSvc.GetByKey(ctx, imageKey)
	if err != nil {
		return nil, err
	}
	if imgCfg == nil {
		return nil, gerror.NewCode(gcode.CodeNotFound, "镜像不存在")
	}

	// 4. Generate token via guid.S() — 32 hex chars, fits k8s label 63-char limit
	token := guid.S()

	// 5. Pod name
	podName := consts.PodNamePrefix + username

	// 6. Insert DB record
	res, err := dao.Instances.Ctx(ctx).Data(&do.Instance{
		UserId:   userId,
		Username: username,
		PodName:  podName,
		SpecId:   specId,
		ImageKey: imageKey,
		Image:    imgCfg.Image,
		Token:    token,
		Status:   consts.StatusCreating,
	}).Insert()
	if err != nil {
		return nil, err
	}
	lastId, _ := res.LastInsertId()
	instanceId := uint(lastId)

	// 7. Create K8S resources (Pod + Service + Ingress) in background
	// Note: home dir initialization is handled by the Pod's initContainer.
	pvcName := g.Cfg().MustGet(ctx, "notebook.pvcName", "pvc-jupyter-shared").String()
	go func() {
		// context.WithoutCancel inherits trace/metadata from the request context without
		// being cancelled when the HTTP request completes, satisfying GoFrame observability best practices.
		bgCtx := context.WithoutCancel(ctx)
		// markFailed cleans up any K8S resources that may have been created, then marks
		// the instance as failed in the DB. Called on all failure paths in this goroutine.
		markFailed := func(reason string) {
			g.Log().Errorf(bgCtx, "instance %d (%s) failed: %s — cleaning up K8S resources", instanceId, username, reason)
			_ = s.k8sSvc.DeleteIngress(bgCtx, token)
			_ = s.k8sSvc.DeleteService(bgCtx, username)
			_ = s.k8sSvc.DeletePod(bgCtx, username)
			_, _ = dao.Instances.Ctx(bgCtx).Where(cols.Id, instanceId).Data(do.Instance{Status: consts.StatusFailed}).Update()
		}

		if e := s.k8sSvc.CreatePod(bgCtx, svcK8s.PodOptions{
			Username:     username,
			Uid:          uid,
			Token:        token,
			Image:        imgCfg.Image,
			Cpu:          sp.Cpu,
			Memory:       memoryWithUnit(sp.Memory),
			Gpu:          sp.Gpu,
			GpuType:      sp.GpuType,
			NodeSelector: sp.NodeSelector,
			Tolerations:  sp.Tolerations,
			PVCName:      pvcName,
		}); e != nil {
			markFailed(fmt.Sprintf("CreatePod error: %v", e))
			return
		}
		_ = s.k8sSvc.CreateService(bgCtx, username)
		_ = s.k8sSvc.CreateIngress(bgCtx, username, token)

		// Poll until Pod is Running (max 5 min)
		deadline := time.Now().Add(5 * time.Minute)
		for time.Now().Before(deadline) {
			time.Sleep(5 * time.Second)
			phase, podIP, nodeName, e := s.k8sSvc.GetPodStatus(bgCtx, username)
			if e != nil {
				continue
			}
			if phase == "Running" {
				_, _ = dao.Instances.Ctx(bgCtx).Where(cols.Id, instanceId).Data(do.Instance{
					Status:   consts.StatusRunning,
					PodIp:    podIP,
					NodeName: nodeName,
				}).Update()
				return
			}
			if phase == "Failed" {
				markFailed("Pod entered Failed phase")
				return
			}
		}
		// Timed out waiting for Pod to become Running
		markFailed("provisioning timeout (5 min)")
	}()

	// Return immediately with the record
	var created entity.Instance
	_ = dao.Instances.Ctx(ctx).Where(cols.Id, instanceId).Scan(&created)
	return &created, nil
}

// Delete stops and removes the JupyterLab instance.
func (s *Service) Delete(ctx context.Context, id, userId uint, isAdmin uint) error {
	ins, err := s.GetById(ctx, id, userId, isAdmin)
	if err != nil {
		return err
	}

	cols := dao.Instances.Columns()
	// For stopped instances, K8S resources were already cleaned up during the stop operation.
	if ins.Status == consts.StatusStopped {
		_, err = dao.Instances.Ctx(ctx).Where(cols.Id, id).Delete()
		return err
	}

	// For failed instances, K8S resources may still exist (Pod in Failed/Pending state,
	// or Service/Ingress created before the failure). Attempt best-effort cleanup to
	// prevent orphaned resources from persisting in the cluster.
	if ins.Status == consts.StatusFailed {
		_ = s.k8sSvc.DeleteIngress(ctx, ins.Token)
		_ = s.k8sSvc.DeleteService(ctx, ins.Username)
		_ = s.k8sSvc.DeletePod(ctx, ins.Username)
		_, err = dao.Instances.Ctx(ctx).Where(cols.Id, id).Delete()
		return err
	}

	// Mark as stopping in DB
	_, err = dao.Instances.Ctx(ctx).Where(cols.Id, id).Data(do.Instance{Status: consts.StatusStopping}).Update()
	if err != nil {
		return err
	}

	// Delete K8S resources
	_ = s.k8sSvc.DeleteIngress(ctx, ins.Token)
	_ = s.k8sSvc.DeleteService(ctx, ins.Username)
	_ = s.k8sSvc.DeletePod(ctx, ins.Username)

	// Mark as stopped
	now := gtime.Now()
	_, err = dao.Instances.Ctx(ctx).Where(cols.Id, id).Data(do.Instance{
		Status:    consts.StatusStopped,
		StoppedAt: now,
	}).Update()
	return err
}

// Restart deletes the Pod and recreates it keeping the same token and DB record.
func (s *Service) Restart(ctx context.Context, id, userId uint, isAdmin uint) error {
	ins, err := s.GetById(ctx, id, userId, isAdmin)
	if err != nil {
		return err
	}
	if ins.Status != consts.StatusRunning && ins.Status != consts.StatusFailed {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "只有运行中或失败的实例才可重启")
	}

	cols := dao.Instances.Columns()
	// Delete old Pod (Service + Ingress stay)
	_ = s.k8sSvc.DeletePod(ctx, ins.Username)

	// Mark creating
	_, err = dao.Instances.Ctx(ctx).Where(cols.Id, id).Data(do.Instance{
		Status: consts.StatusCreating,
		PodIp:  "",
	}).Update()
	if err != nil {
		return err
	}

	// Reload spec + image
	sp, err := s.specSvc.GetById(ctx, ins.SpecId)
	if err != nil {
		return err
	}
	imgCfg, err := s.imageSvc.GetByKey(ctx, ins.ImageKey)
	if err != nil || imgCfg == nil {
		return gerror.New("镜像配置丢失")
	}
	pvcName := g.Cfg().MustGet(ctx, "notebook.pvcName", "pvc-jupyter-shared").String()

	// Fetch user uid
	uid := ins.UserId + consts.UIDOffset

	go func() {
		bgCtx := context.Background()
		if e := s.k8sSvc.CreatePod(bgCtx, svcK8s.PodOptions{
			Username:     ins.Username,
			Uid:          uid,
			Token:        ins.Token,
			Image:        imgCfg.Image,
			Cpu:          sp.Cpu,
			Memory:       memoryWithUnit(sp.Memory),
			Gpu:          sp.Gpu,
			GpuType:      sp.GpuType,
			NodeSelector: sp.NodeSelector,
			Tolerations:  sp.Tolerations,
			PVCName:      pvcName,
		}); e != nil {
			_, _ = dao.Instances.Ctx(bgCtx).Where(cols.Id, id).Data(do.Instance{Status: consts.StatusFailed}).Update()
			return
		}
		deadline := time.Now().Add(5 * time.Minute)
		for time.Now().Before(deadline) {
			time.Sleep(5 * time.Second)
			phase, podIP, nodeName, e := s.k8sSvc.GetPodStatus(bgCtx, ins.Username)
			if e != nil {
				continue
			}
			if phase == "Running" {
				_, _ = dao.Instances.Ctx(bgCtx).Where(cols.Id, id).Data(do.Instance{
					Status:   consts.StatusRunning,
					PodIp:    podIP,
					NodeName: nodeName,
				}).Update()
				return
			}
			if phase == "Failed" {
				_, _ = dao.Instances.Ctx(bgCtx).Where(cols.Id, id).Data(do.Instance{Status: consts.StatusFailed}).Update()
				return
			}
		}
		_, _ = dao.Instances.Ctx(context.Background()).Where(cols.Id, id).Data(do.Instance{Status: consts.StatusFailed}).Update()
	}()
	return nil
}

// memoryWithUnit ensures the memory value has a "Gi" suffix for K8S resource parsing.
// If the value already ends with "Gi", it is returned as-is (backward compatibility).
func memoryWithUnit(mem string) string {
	if strings.HasSuffix(mem, "Gi") {
		return mem
	}
	return mem + "Gi"
}

// AccessURL builds the full public URL for an instance.
func (s *Service) AccessURL(ctx context.Context, token string) string {
	base := g.Cfg().MustGet(ctx, "notebook.accessBaseURL", "https://platform.internal").String()
	return fmt.Sprintf("%s/jupyter/%s/", base, token)
}
