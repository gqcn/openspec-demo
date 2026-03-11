package consts

const (
	// ContextKeyUser is the key in request context holding the current user.
	ContextKeyUser = "CtxUser"

	// JWT signing algorithm
	JWTIssuer = "platform"

	// Instance statuses
	StatusCreating = "creating"
	StatusRunning  = "running"
	StatusStopping = "stopping"
	StatusStopped  = "stopped"
	StatusFailed   = "failed"

	// K8S namespace for JupyterLab pods
	K8SNamespace = "jupyter"

	// Pod name prefix
	PodNamePrefix = "jupyterlab-"

	// Service name prefix
	ServiceNamePrefix = "svc-jupyterlab-"

	// Ingress name prefix
	IngressNamePrefix = "jupyter-"

	// NFS home path prefix inside the PVC
	NFSHomeSubPath  = "data/home"
	NFSShareSubPath = "share"

	// Container port for JupyterLab
	JupyterPort = 8888

	// UID offset for container users
	UIDOffset = 10000
)

// ErrCode defines unified error codes.
const (
	ErrCodeOK            = 0
	ErrCodeUnauthorized  = 401
	ErrCodeForbidden     = 403
	ErrCodeNotFound      = 404
	ErrCodeBadRequest    = 400
	ErrCodeInternalError = 500
)
