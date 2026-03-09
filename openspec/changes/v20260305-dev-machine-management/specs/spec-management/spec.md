## ADDED Requirements

### Requirement: Admin can create a resource spec
The system SHALL allow an admin user to create a new resource spec (套餐) via `POST /api/spec`. The spec record SHALL include name, CPU, memory, GPU count, GPU type, nodeSelector, tolerations, description, enabled flag, and sort order.

#### Scenario: Successful spec creation
- **WHEN** admin submits a valid spec with name, cpu, memory, and gpu fields
- **THEN** system creates the spec record in the `specs` table and returns the new spec ID

#### Scenario: JSON fields omitted gracefully
- **WHEN** admin creates a spec without providing `node_selector` or `tolerations`
- **THEN** system stores NULL for those JSON columns (not empty string), and the creation succeeds without MySQL JSON validation errors

### Requirement: Admin can update a resource spec
The system SHALL allow an admin user to update an existing spec via `PUT /api/spec/{id}`. The update SHALL use `OmitEmpty()` to prevent unspecified fields from being overwritten with zero values.

#### Scenario: Partial update preserves unspecified fields
- **WHEN** admin updates only the `cpu` field of a spec
- **THEN** other fields (name, memory, gpu, nodeSelector, tolerations, description) remain unchanged

#### Scenario: Update all fields
- **WHEN** admin updates all fields of a spec
- **THEN** all specified fields are persisted correctly

### Requirement: Admin can delete a resource spec
The system SHALL allow an admin user to delete a spec via `DELETE /api/spec/{id}`.

#### Scenario: Successful deletion
- **WHEN** admin deletes a spec by ID
- **THEN** the spec record is removed from the `specs` table and no longer appears in the list

### Requirement: Admin can list all specs including disabled
The system SHALL return all specs (both enabled and disabled) when the requesting user is an admin via `GET /api/spec`. This allows admins to manage disabled specs in the spec management page.

#### Scenario: Admin sees all specs
- **WHEN** admin requests the spec list
- **THEN** system returns all specs including those with `enabled=0`

### Requirement: Regular user can only list enabled specs
The system SHALL return only specs with `enabled=1` when the requesting user is a non-admin via `GET /api/spec`. This is used in the notebook creation dialog for spec selection.

#### Scenario: Non-admin sees only enabled specs
- **WHEN** a regular user requests the spec list
- **THEN** system returns only specs where `enabled=1`, ordered by `sort_order`

### Requirement: Admin can toggle spec enabled status
The system SHALL allow an admin to enable or disable a spec by updating the `enabled` field via `PUT /api/spec/{id}`.

#### Scenario: Disable a spec
- **WHEN** admin sets `enabled=0` on a spec
- **THEN** the spec no longer appears in regular user's spec list but remains visible in admin's management page

#### Scenario: Frontend filters disabled specs in creation dialog
- **WHEN** admin opens the notebook creation dialog
- **THEN** the spec selection only shows specs with `enabled=1`, preventing accidental selection of disabled specs

### Requirement: Spec management frontend page
The system SHALL provide an admin-only frontend page for managing resource specs. The page SHALL display a table of all specs with CRUD operations and an enable/disable toggle.

#### Scenario: Spec management table displays all specs
- **WHEN** admin navigates to the spec management page
- **THEN** a table is shown with columns for name, CPU, memory, GPU, GPU type, status (enabled/disabled), and action buttons (edit, delete)

#### Scenario: Create spec via dialog
- **WHEN** admin clicks the "Create" button and fills in the form
- **THEN** the new spec appears in the table after submission

#### Scenario: Edit spec via dialog
- **WHEN** admin clicks "Edit" on a spec row and modifies fields
- **THEN** the changes are persisted and reflected in the table
