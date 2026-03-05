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
	"github.com/google/uuid"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	"github.com/gqcn/platform/backend/internal/service/image"
	svcK8s "github.com/gqcn/platform/backend/internal/service/k8s"
	"github.com/gqcn/platform/backend/internal/service/spec"
)

// List returns all instances for the requesting user (or all if admin).
func List(ctx context.Context, userId uint, isAdmin uint) (list []*entity.Instance, err error) {
	m := dao.Instances.Ctx(ctx)
	if isAdmin != 1 {
		m = m.Where("user_id", userId)
	}
	err = m.OrderDesc("created_at").Scan(&list)
	return
}

// GetById returns a single instance; non-admin can only see their own.
func GetById(ctx context.Context, id, userId uint, isAdmin uint) (ins *entity.Instance, err error) {
	m := dao.Instances.Ctx(ctx).Where("id", id)
	if isAdmin != 1 {
		m = m.Where("user_id", userId)
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
func Create(ctx context.Context, userId uint, username string, uid uint, specId uint, imageKey string) (ins *entity.Instance, err error) {
	// 1. Verify user has no active instance
	count, err := dao.Instances.Ctx(ctx).
		Where("user_id", userId).
		WhereIn("status", []string{consts.StatusCreating, consts.StatusRunning, consts.StatusStopping}).
		Count()
	if err != nil {
		return nil, err
	}
	if count > 0 {
		return nil, gerror.NewCode(gcode.CodeBusinessValidationFailed, "您已有活跃的开发机实例，请先停止后再创建")
	}

	// 2. Validate spec
	sp, err := spec.GetById(ctx, specId)
	if err != nil {
		return nil, err
	}

	// 3. Validate image
	imgCfg, err := image.GetByKey(ctx, imageKey)
	if err != nil {
		return nil, err
	}
	if imgCfg == nil {
		return nil, gerror.NewCode(gcode.CodeNotFound, "镜像不存在")
	}

	// 4. Generate token (UUID without hyphens, 32 chars — fits k8s label 63-char limit)
	token := strings.ReplaceAll(uuid.New().String(), "-", "")

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

	// 7. Init NFS home dir (async – best effort)
	pvcName := g.Cfg().MustGet(ctx, "notebook.pvcName", "pvc-jupyter-shared").String()
	go func() {
		bgCtx := context.Background()
		if e := svcK8s.InitUserHomeDir(bgCtx, username, uid, pvcName); e != nil {
			g.Log().Warningf(bgCtx, "InitUserHomeDir for %s failed: %v", username, e)
		}
	}()

	// 8. Create K8S resources (Pod + Service + Ingress) in background
	go func() {
		bgCtx := context.Background()
		if e := svcK8s.CreatePod(bgCtx, svcK8s.PodOptions{
			Username:     username,
			Uid:          uid,
			Token:        token,
			Image:        imgCfg.Image,
			Cpu:          sp.Cpu,
			Memory:       sp.Memory,
			Gpu:          sp.Gpu,
			GpuType:      sp.GpuType,
			NodeSelector: sp.NodeSelector,
			Tolerations:  sp.Tolerations,
			PVCName:      pvcName,
		}); e != nil {
			g.Log().Errorf(bgCtx, "CreatePod failed for %s: %v", username, e)
			_, _ = dao.Instances.Ctx(bgCtx).Where("id", instanceId).Data(do.Instance{Status: consts.StatusFailed}).Update()
			return
		}
		_ = svcK8s.CreateService(bgCtx, username)
		_ = svcK8s.CreateIngress(bgCtx, username, token)

		// Poll until Pod is Running (max 5 min)
		deadline := time.Now().Add(5 * time.Minute)
		for time.Now().Before(deadline) {
			time.Sleep(5 * time.Second)
			phase, podIP, nodeName, e := svcK8s.GetPodStatus(bgCtx, username)
			if e != nil {
				continue
			}
			if phase == "Running" {
				_, _ = dao.Instances.Ctx(bgCtx).Where("id", instanceId).Data(do.Instance{
					Status:   consts.StatusRunning,
					PodIp:    podIP,
					NodeName: nodeName,
				}).Update()
				return
			}
			if phase == "Failed" {
				_, _ = dao.Instances.Ctx(bgCtx).Where("id", instanceId).Data(do.Instance{Status: consts.StatusFailed}).Update()
				return
			}
		}
		// Timed out
		_, _ = dao.Instances.Ctx(context.Background()).Where("id", instanceId).Data(do.Instance{Status: consts.StatusFailed}).Update()
	}()

	// Return immediately with the record
	var created entity.Instance
	_ = dao.Instances.Ctx(ctx).Where("id", instanceId).Scan(&created)
	return &created, nil
}

// Delete stops and removes the JupyterLab instance.
func Delete(ctx context.Context, id, userId uint, isAdmin uint) error {
	ins, err := GetById(ctx, id, userId, isAdmin)
	if err != nil {
		return err
	}

	// Mark as stopping in DB
	_, err = dao.Instances.Ctx(ctx).Where("id", id).Data(do.Instance{Status: consts.StatusStopping}).Update()
	if err != nil {
		return err
	}

	// Delete K8S resources
	_ = svcK8s.DeleteIngress(ctx, ins.Token)
	_ = svcK8s.DeleteService(ctx, ins.Username)
	_ = svcK8s.DeletePod(ctx, ins.Username)

	// Mark as stopped
	now := gtime.Now()
	_, err = dao.Instances.Ctx(ctx).Where("id", id).Data(do.Instance{
		Status:    consts.StatusStopped,
		StoppedAt: now,
	}).Update()
	return err
}

// Restart deletes the Pod and recreates it keeping the same token and DB record.
func Restart(ctx context.Context, id, userId uint, isAdmin uint) error {
	ins, err := GetById(ctx, id, userId, isAdmin)
	if err != nil {
		return err
	}
	if ins.Status != consts.StatusRunning && ins.Status != consts.StatusFailed {
		return gerror.NewCode(gcode.CodeBusinessValidationFailed, "只有运行中或失败的实例才可重启")
	}

	// Delete old Pod (Service + Ingress stay)
	_ = svcK8s.DeletePod(ctx, ins.Username)

	// Mark creating
	_, err = dao.Instances.Ctx(ctx).Where("id", id).Data(do.Instance{
		Status: consts.StatusCreating,
		PodIp:  "",
	}).Update()
	if err != nil {
		return err
	}

	// Reload spec + image
	sp, err := spec.GetById(ctx, ins.SpecId)
	if err != nil {
		return err
	}
	imgCfg, err := image.GetByKey(ctx, ins.ImageKey)
	if err != nil || imgCfg == nil {
		return gerror.New("镜像配置丢失")
	}
	pvcName := g.Cfg().MustGet(ctx, "notebook.pvcName", "pvc-jupyter-shared").String()

	// Fetch user uid
	uid := ins.UserId + consts.UIDOffset

	go func() {
		bgCtx := context.Background()
		if e := svcK8s.CreatePod(bgCtx, svcK8s.PodOptions{
			Username:     ins.Username,
			Uid:          uid,
			Token:        ins.Token,
			Image:        imgCfg.Image,
			Cpu:          sp.Cpu,
			Memory:       sp.Memory,
			Gpu:          sp.Gpu,
			GpuType:      sp.GpuType,
			NodeSelector: sp.NodeSelector,
			Tolerations:  sp.Tolerations,
			PVCName:      pvcName,
		}); e != nil {
			_, _ = dao.Instances.Ctx(bgCtx).Where("id", id).Data(do.Instance{Status: consts.StatusFailed}).Update()
			return
		}
		deadline := time.Now().Add(5 * time.Minute)
		for time.Now().Before(deadline) {
			time.Sleep(5 * time.Second)
			phase, podIP, nodeName, e := svcK8s.GetPodStatus(bgCtx, ins.Username)
			if e != nil {
				continue
			}
			if phase == "Running" {
				_, _ = dao.Instances.Ctx(bgCtx).Where("id", id).Data(do.Instance{
					Status:   consts.StatusRunning,
					PodIp:    podIP,
					NodeName: nodeName,
				}).Update()
				return
			}
			if phase == "Failed" {
				_, _ = dao.Instances.Ctx(bgCtx).Where("id", id).Data(do.Instance{Status: consts.StatusFailed}).Update()
				return
			}
		}
		_, _ = dao.Instances.Ctx(context.Background()).Where("id", id).Data(do.Instance{Status: consts.StatusFailed}).Update()
	}()
	return nil
}

// AccessURL builds the full public URL for an instance.
func AccessURL(ctx context.Context, token string) string {
	base := g.Cfg().MustGet(ctx, "notebook.accessBaseURL", "https://platform.internal").String()
	return fmt.Sprintf("%s/jupyter/%s/", base, token)
}
