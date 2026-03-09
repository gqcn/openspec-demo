## ADDED Requirements

### Requirement: System provides a list of available images
The system SHALL provide an API `GET /api/image` that returns the list of available container images for notebook creation. The image list SHALL be maintained in the backend configuration file (not in the database for this phase). Each image entry includes key, name, image address, description, and enabled flag.

#### Scenario: Retrieve image list
- **WHEN** an authenticated user requests `GET /api/image`
- **THEN** system reads the image configuration and returns all enabled images with their key, name, image address, and description

### Requirement: Image configuration structure
The backend configuration file SHALL define images as a list with fields: `key` (unique identifier), `name` (display name), `image` (full Docker image address), `description`, and `enabled` (boolean). The GoFrame server SHALL read and cache this configuration at startup.

#### Scenario: Configuration file parsed correctly
- **WHEN** the backend starts with a valid image configuration containing two images (base-notebook, pytorch-cuda121)
- **THEN** `GET /api/image` returns both images with correct keys, names, and image addresses

### Requirement: User selects image during notebook creation
The frontend notebook creation dialog SHALL display a dropdown list of available images retrieved from `GET /api/image`. The user MUST select one image before submitting the creation request. The selected `image_key` is sent to the backend, which resolves it to the full image address and snapshots it into the `instances` record.

#### Scenario: Image dropdown populated from API
- **WHEN** user opens the create notebook dialog
- **THEN** the image dropdown shows all enabled images with their display names

#### Scenario: Image address snapshot on creation
- **WHEN** user creates a notebook with `image_key=pytorch-cuda121`
- **THEN** the instance record stores both the `image_key` and the full `image` address at creation time, so future config changes do not affect the running instance

### Requirement: No image management UI in this phase
The system SHALL NOT provide a frontend UI for adding, editing, or deleting images in this phase. Image management is done exclusively through the backend configuration file.

#### Scenario: Image management page does not exist
- **WHEN** a user or admin navigates the frontend
- **THEN** there is no menu item or page for image management
