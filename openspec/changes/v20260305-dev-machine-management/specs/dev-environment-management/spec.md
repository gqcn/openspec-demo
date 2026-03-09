## ADDED Requirements

### Requirement: User can create a JupyterLab instance
The system SHALL allow an authenticated user to create a JupyterLab development instance by selecting a resource spec and a container image. The system SHALL create the corresponding K8S Pod, Service, and Ingress resources in the `jupyter` namespace. The instance record SHALL be persisted in the `instances` table with status `creating`, a unique token generated via `guid.S()`, and the snapshot of the selected image address.

#### Scenario: Successful creation with valid spec and image
- **WHEN** user submits a creation request with a valid `spec_id` (enabled spec) and a valid `image_key`
- **THEN** system creates an instance record with status `creating`, generates a unique token, creates K8S Pod + Service + Ingress, and transitions status to `running` once Pod is Ready

#### Scenario: Reject creation when user already has an active instance
- **WHEN** user submits a creation request but already has an instance with status IN (`creating`, `running`, `stopping`)
- **THEN** system rejects the request with a non-zero error code and the existing instance is unaffected

#### Scenario: Old stopped/failed records are cleaned before creation
- **WHEN** user creates a new instance and has prior records with status `stopped` or `failed`
- **THEN** system deletes all stopped/failed records for that user before creating the new instance

### Requirement: Each user is limited to one active instance
The system SHALL enforce a constraint that each user can have at most one instance with status IN (`creating`, `running`, `stopping`) at any time. This constraint SHALL be enforced at the application layer (not via DB unique index) to preserve historical stopped records.

#### Scenario: Application-layer uniqueness check
- **WHEN** a second creation request arrives for a user who already has a `running` instance
- **THEN** system returns an error indicating the user already has an active instance

### Requirement: User can stop an instance
The system SHALL allow the instance owner to stop a running instance. Stopping SHALL delete the K8S Pod, Service, and Ingress resources and update the instance status to `stopped`.

#### Scenario: Successful stop of a running instance
- **WHEN** user requests to stop an instance with status `running`
- **THEN** system deletes K8S Pod + Service + Ingress, updates instance status to `stopped` and sets `stopped_at`

#### Scenario: Stop confirmation required
- **WHEN** user clicks the stop button on the frontend
- **THEN** a confirmation dialog is shown before the stop API call is made

### Requirement: User can restart an instance
The system SHALL allow the instance owner to restart a running instance. Restarting SHALL delete the existing Pod and recreate it with the same token and configuration. Data on NFS SHALL be preserved.

#### Scenario: Successful restart preserves token and data
- **WHEN** user restarts a running instance
- **THEN** system deletes and recreates the K8S Pod (same token, same PVC mounts), and instance data in `/data/home/{username}` is preserved

#### Scenario: Restart confirmation required
- **WHEN** user clicks the restart button on the frontend
- **THEN** a confirmation dialog is shown before the restart API call is made

### Requirement: User can delete a stopped instance record
The system SHALL allow a user to delete an instance record that has status `stopped` or `failed`. Deleting SHALL remove the database row permanently.

#### Scenario: Delete a stopped instance record
- **WHEN** user requests deletion of an instance with status `stopped`
- **THEN** system physically deletes the row from the `instances` table and the instance disappears from the list

#### Scenario: Delete button only shown for stopped/failed instances
- **WHEN** the instance list is rendered
- **THEN** the "delete record" button is visible only for instances with status `stopped` or `failed`

### Requirement: User can list their instances
The system SHALL provide an API `GET /api/notebook` that returns the current user's instance list with real-time status merged from K8S Pod state.

#### Scenario: Instance list with real-time status
- **WHEN** user requests the instance list
- **THEN** system queries the database and K8S Pod status, merges them, and returns instance records with current status, spec info, image info, creation time, and access URL

### Requirement: User can view instance details
The system SHALL provide an API `GET /api/notebook/{id}` that returns the full details of a specific instance belonging to the current user.

#### Scenario: View detail of own instance
- **WHEN** user requests detail of an instance they own
- **THEN** system returns the instance's full information including status, spec, image, token, pod_ip, node_name, and timestamps

### Requirement: Instance access via shareable URL
Each instance SHALL have a fixed access URL in the format `https://platform.internal/jupyter/{token}`. The token serves as both the routing key and JupyterLab authentication credential. Sharing this URL grants access to the instance without additional authorization.

#### Scenario: Access JupyterLab via token URL
- **WHEN** a browser navigates to `/jupyter/{token}/lab`
- **THEN** the Ingress routes the request to the correct JupyterLab Pod, and JupyterLab authenticates via the token and loads the IDE

#### Scenario: Sharing link enables collaboration
- **WHEN** another person opens the same `/jupyter/{token}` URL
- **THEN** they can access the same JupyterLab instance without separate login

### Requirement: Workspace data persistence across restarts
User workspace data SHALL be stored on NFS via a shared PVC (`pvc-jupyter-shared`). Each user's home directory (`/data/home/{username}`) SHALL be mounted into the Pod. Data SHALL survive Pod restarts, stops, and recreations.

#### Scenario: Data survives instance restart
- **WHEN** user creates a file in JupyterLab, restarts the instance, and reopens JupyterLab
- **THEN** the file is still present in the user's workspace

#### Scenario: Data survives instance stop and recreate
- **WHEN** user stops an instance, creates a new one, and opens JupyterLab
- **THEN** previous workspace files are still present under `/home/{username}`

### Requirement: User directory initialization on first creation
The system SHALL initialize the user's NFS home directory (`/data/home/{username}`) on first instance creation via a K8S Job running as root. The directory SHALL be owned by the user's UID (`10000 + users.id`) with permissions `chmod 700`.

#### Scenario: First-time directory creation
- **WHEN** a user creates their first instance
- **THEN** the system creates `/data/home/{username}` on NFS, sets ownership to UID/GID = `10000 + users.id`, and sets permissions to 700

### Requirement: User directory permission isolation
Each user's home directory SHALL be accessible only to that user (chmod 700). NFS UID-based permission SHALL prevent other users from reading or writing to another user's home directory.

#### Scenario: User cannot access another user's directory
- **WHEN** user A's JupyterLab process (running as UID A) tries to access `/data/home/userB`
- **THEN** the filesystem denies access due to chmod 700 ownership by UID B

### Requirement: Shared directory for all users
The system SHALL mount a shared directory `/share` (PVC subPath `share`) into every instance. All users SHALL be able to read and write to `/share`. The directory uses sticky bit (chmod 1777) so users cannot delete each other's files.

#### Scenario: User can write to shared directory
- **WHEN** user creates a file in `/share/datasets/myfile.csv`
- **THEN** the file is accessible by all other JupyterLab instances

#### Scenario: User cannot delete another user's file in shared directory
- **WHEN** user A tries to delete a file created by user B in `/share`
- **THEN** the operation is denied by the sticky bit permission

### Requirement: Pod specification follows Jupyter official image conventions
The K8S Pod SHALL be created with `runAsUser: 0` (root startup), using Jupyter official image's `start.sh` to switch to the non-root user via `NB_UID`/`NB_GID`/`NB_USER` environment variables. The Pod SHALL set `JUPYTER_TOKEN`, `JUPYTER_BASE_URL`, and `JUPYTER_ENABLE_LAB` environment variables. The startup command SHALL create a symlink from `/data/home/{username}` to `/home/{username}`.

#### Scenario: Pod starts with correct environment variables
- **WHEN** a Pod is created for a user with UID 10001 and token `abc123`
- **THEN** the Pod has env vars `NB_UID=10001`, `NB_GID=10001`, `NB_USER={username}`, `JUPYTER_TOKEN=abc123`, `JUPYTER_BASE_URL=/jupyter/abc123/`, `JUPYTER_ENABLE_LAB=yes`

#### Scenario: GPU resources applied when spec includes GPU
- **WHEN** instance is created with a spec that has `gpu > 0`
- **THEN** the Pod spec includes `nvidia.com/gpu` resource request/limit and the spec's `nodeSelector` and `tolerations`

### Requirement: Frontend status polling for instance state
The frontend SHALL poll `GET /api/notebook` every 5 seconds when instances are in transitional states (`creating`, `stopping`). The frontend SHALL display status badges: creating=blue, running=green, stopping=orange, stopped=gray, failed=red.

#### Scenario: Polling during creation
- **WHEN** an instance is in `creating` status
- **THEN** the frontend polls every 5 seconds until the status changes to `running` or `failed`

#### Scenario: Status badge display
- **WHEN** the instance list renders
- **THEN** each instance shows a color-coded status badge matching its current state

### Requirement: Frontend disables create button when active instance exists
The frontend SHALL compute whether the current user has an active instance (status IN `creating`, `running`, `stopping`) and disable the "Create" button with a tooltip when true.

#### Scenario: Create button disabled with active instance
- **WHEN** user has a running instance and visits the instance list page
- **THEN** the "Create" button is disabled and shows a tooltip indicating an active instance already exists

#### Scenario: Create button enabled after deletion
- **WHEN** user stops and deletes their instance record
- **THEN** the "Create" button becomes enabled again

### Requirement: Idle detection and auto-recycle
The system SHALL run a cron job every 1 hour to detect idle running instances. An instance is considered idle when all JupyterLab kernels have `execution_state != busy` and `last_activity` older than 48 hours. After `idle_since` exceeds 48 hours, the system SHALL automatically recycle the instance (delete K8S resources, update status to `stopped`). Only a system log is recorded; no user notification is sent.

#### Scenario: Instance recycled after 48h idle
- **WHEN** an instance has no active kernels for more than 48 continuous hours
- **THEN** the system deletes Pod + Service + Ingress, sets status to `stopped`, records `stopped_at`, and logs the recycle event

#### Scenario: Activity resets idle timer
- **WHEN** a kernel becomes active during the idle period
- **THEN** the system updates `last_active_at` to now and resets `idle_since` to NULL

#### Scenario: Consecutive request failures mark instance as failed
- **WHEN** the cron job fails to reach the Jupyter kernel API for 3 consecutive attempts
- **THEN** the system marks the instance status as `failed` and logs the error

### Requirement: K8S Ingress supports WebSocket for JupyterLab
The Ingress resource created for each instance SHALL include annotations for WebSocket support (`proxy-read-timeout: 3600`, `proxy-send-timeout: 3600`, `configuration-snippet` for Upgrade headers). This ensures JupyterLab kernel communication and Terminal sessions work correctly.

#### Scenario: WebSocket connection through Ingress
- **WHEN** JupyterLab establishes a WebSocket connection for kernel communication
- **THEN** the Ingress proxies the connection correctly with proper Upgrade headers, and the connection remains stable
