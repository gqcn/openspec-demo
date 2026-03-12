// Package cron provides scheduled tasks for the platform, including idle instance detection.
package cron

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"github.com/gogf/gf/v2/frame/g"
	"github.com/gogf/gf/v2/os/gcron"
	"github.com/gogf/gf/v2/os/gtime"
	"github.com/gqcn/platform/backend/internal/consts"
	"github.com/gqcn/platform/backend/internal/dao"
	"github.com/gqcn/platform/backend/internal/model/do"
	"github.com/gqcn/platform/backend/internal/model/entity"
	svcK8s "github.com/gqcn/platform/backend/internal/service/k8s"
)

// Service provides scheduled task management.
type Service struct {
	k8sSvc *svcK8s.Service
}

// New creates and returns a new Service instance.
func New(k8sSvc *svcK8s.Service) *Service {
	return &Service{k8sSvc: k8sSvc}
}

// StartIdleChecker registers the cron job that checks for idle JupyterLab instances.
func (s *Service) StartIdleChecker(ctx context.Context) {
	interval := g.Cfg().MustGet(ctx, "notebook.checkIntervalMin", 60).Int()
	spec := fmt.Sprintf("@every %dm", interval)
	_, err := gcron.Add(ctx, spec, func(ctx context.Context) {
		s.checkIdleInstances(ctx)
	}, "idle-checker")
	if err != nil {
		g.Log().Errorf(ctx, "cron: failed to register idle-checker: %v", err)
		return
	}
	g.Log().Infof(ctx, "cron: idle-checker registered, interval=%dm", interval)
}

func (s *Service) checkIdleInstances(ctx context.Context) {
	g.Log().Info(ctx, "cron: idle-checker started")
	cols := dao.Instances.Columns()
	var instances []*entity.Instance
	err := dao.Instances.Ctx(ctx).Where(cols.Status, consts.StatusRunning).Scan(&instances)
	if err != nil {
		g.Log().Errorf(ctx, "cron: query running instances error: %v", err)
		return
	}

	idleTimeout := g.Cfg().MustGet(ctx, "notebook.idleTimeoutHours", 48).Int()

	for _, ins := range instances {
		s.processInstance(ctx, ins, idleTimeout)
	}
	g.Log().Info(ctx, "cron: idle-checker finished")
}

// kernelInfo represents a JupyterLab kernel API response item.
type kernelInfo struct {
	Id             string `json:"id"`
	ExecutionState string `json:"execution_state"`
	LastActivity   string `json:"last_activity"`
}

func (s *Service) processInstance(ctx context.Context, ins *entity.Instance, idleTimeoutHours int) {
	if ins.PodIp == "" {
		return
	}
	url := fmt.Sprintf("http://%s:%d/api/kernels?token=%s", ins.PodIp, consts.JupyterPort, ins.Token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		// Record failure; after 3 consecutive failures mark as failed
		s.handleFailure(ctx, ins)
		return
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		s.handleFailure(ctx, ins)
		return
	}

	var kernels []kernelInfo
	if err = json.Unmarshal(body, &kernels); err != nil {
		s.handleFailure(ctx, ins)
		return
	}

	// Reset idle_since if any kernel is busy or recently active
	allIdle := true
	for _, k := range kernels {
		if k.ExecutionState == "busy" {
			allIdle = false
			break
		}
		t, err := time.Parse(time.RFC3339Nano, k.LastActivity)
		if err != nil {
			continue
		}
		if time.Since(t) < time.Duration(idleTimeoutHours)*time.Hour {
			allIdle = false
			break
		}
	}

	// Update last_active_at on successful check
	cols := dao.Instances.Columns()
	now := gtime.Now()
	_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, ins.Id).Data(do.Instance{LastActiveAt: now}).Update()

	if len(kernels) == 0 || allIdle {
		if ins.IdleSince == nil {
			// Start counting idle time
			_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, ins.Id).Data(do.Instance{IdleSince: now}).Update()
			return
		}
		// Check if idle timeout exceeded
		if time.Since(ins.IdleSince.Time) >= time.Duration(idleTimeoutHours)*time.Hour {
			g.Log().Infof(ctx, "cron: instance %d (%s) idle for >%dh, reclaiming", ins.Id, ins.Username, idleTimeoutHours)
			s.reclaimInstance(ctx, ins)
		}
	} else {
		// Active – reset idle_since
		if ins.IdleSince != nil {
			_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, ins.Id).Data(g.Map{cols.IdleSince: nil}).Update()
		}
	}
}

func (s *Service) handleFailure(ctx context.Context, ins *entity.Instance) {
	// Use idle_since as a consecutive-failure counter (simplification)
	cols := dao.Instances.Columns()
	now := gtime.Now()
	if ins.IdleSince == nil {
		_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, ins.Id).Data(do.Instance{IdleSince: now}).Update()
		return
	}
	// If 3+ failure periods (checkInterval * 3) have elapsed, mark as failed
	checkInterval := g.Cfg().MustGet(ctx, "notebook.checkIntervalMin", 60).Int()
	failThreshold := time.Duration(checkInterval*3) * time.Minute
	if time.Since(ins.IdleSince.Time) >= failThreshold {
		g.Log().Warningf(ctx, "cron: instance %d (%s) unreachable for 3+ checks, marking failed", ins.Id, ins.Username)
		_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, ins.Id).Data(do.Instance{Status: consts.StatusFailed}).Update()
	}
}

func (s *Service) reclaimInstance(ctx context.Context, ins *entity.Instance) {
	// Delete K8S resources
	_ = s.k8sSvc.DeleteIngress(ctx, ins.Token)
	_ = s.k8sSvc.DeleteService(ctx, ins.Username)
	_ = s.k8sSvc.DeletePod(ctx, ins.Username)

	cols := dao.Instances.Columns()
	now := gtime.Now()
	_, _ = dao.Instances.Ctx(ctx).Where(cols.Id, ins.Id).Data(do.Instance{
		Status:    consts.StatusStopped,
		StoppedAt: now,
	}).Update()
	g.Log().Infof(ctx, "cron: instance %d (%s) reclaimed", ins.Id, ins.Username)
}
