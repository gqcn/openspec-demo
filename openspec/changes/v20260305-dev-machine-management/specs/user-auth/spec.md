## ADDED Requirements

### Requirement: User can login with username and password
The system SHALL provide a `POST /api/auth/login` endpoint that authenticates a user by username and password (bcrypt-verified) and returns a JWT token on success. The JWT token SHALL be stored in `localStorage` by the frontend and sent as `Authorization: Bearer {token}` header on subsequent requests.

#### Scenario: Successful login
- **WHEN** user submits correct username and password
- **THEN** system returns a JWT token, and the frontend stores it in `localStorage` and redirects to `/notebooks`

#### Scenario: Failed login with wrong password
- **WHEN** user submits an incorrect password
- **THEN** system returns a non-zero error code with an error message, the frontend displays the error, and the user remains on the login page without a crash

#### Scenario: Failed login with non-existent username
- **WHEN** user submits a username that does not exist
- **THEN** system returns a non-zero error code and the frontend displays an appropriate error message

### Requirement: User can logout
The system SHALL provide a `POST /api/auth/logout` endpoint. Logout is handled client-side by discarding the JWT token from `localStorage` and redirecting to the login page.

#### Scenario: Successful logout
- **WHEN** user clicks the logout trigger in the header
- **THEN** the frontend removes the JWT from `localStorage`, shows a "已退出登录" message, and redirects to `/login`

### Requirement: JWT authentication middleware
The system SHALL protect all API endpoints (except `/api/auth/login`) with a JWT authentication middleware. Requests without a valid JWT SHALL be rejected. The middleware SHALL extract the user identity from the JWT and inject it into the request context for downstream handlers.

#### Scenario: Unauthenticated request rejected
- **WHEN** a request is made to a protected endpoint without a JWT
- **THEN** the middleware returns an error response and the frontend redirects to `/login`

#### Scenario: Expired JWT rejected
- **WHEN** a request is made with an expired JWT
- **THEN** the middleware returns an error response and the frontend redirects to `/login`

### Requirement: Admin-only middleware for management endpoints
The system SHALL provide an admin-only middleware that restricts access to management endpoints (spec CRUD, user CRUD) to admin users only. Non-admin users SHALL be denied access.

#### Scenario: Non-admin access to admin endpoint
- **WHEN** a regular user sends a request to `POST /api/spec`
- **THEN** the middleware returns a forbidden error response

#### Scenario: Admin access to admin endpoint
- **WHEN** an admin user sends a request to `POST /api/spec`
- **THEN** the request is allowed through to the handler

### Requirement: Unified error response format
The system SHALL return all API responses (including errors) as HTTP 200 with a JSON body `{ code: <int>, message: <string>, data: <any> }`. A `code` of 0 indicates success; non-zero indicates an error. The frontend Axios interceptor SHALL check `response.data.code` and reject non-zero responses so that `.catch()` blocks handle errors correctly.

#### Scenario: Business error returned as HTTP 200
- **WHEN** a login attempt fails due to wrong password
- **THEN** HTTP status is 200, response body has `code != 0` and a descriptive `message`, and the frontend interceptor converts it to a rejected promise

#### Scenario: Middleware error responses are valid JSON
- **WHEN** the auth middleware rejects a request
- **THEN** the response body is valid JSON matching `{ code, message, data }` format (no status text prefix in the body)

### Requirement: Admin can create users
The system SHALL provide an admin endpoint to create new users. The user record SHALL include username, bcrypt-hashed password, email, and status. The system SHALL auto-assign UID = `10000 + users.id` after insertion.

#### Scenario: Successful user creation
- **WHEN** admin creates a user with username "zhangsan" and a password
- **THEN** the user record is created with a bcrypt-hashed password and UID = 10000 + assigned ID

#### Scenario: Duplicate username rejected
- **WHEN** admin creates a user with a username that already exists
- **THEN** the system returns an error due to the unique constraint on `username`

### Requirement: Username format validation
Because usernames are used as Linux usernames inside Kubernetes Pod containers (via `NB_USER` environment variable, which drives `useradd`/`groupadd` inside JupyterLab startup scripts), the system SHALL enforce that usernames match Linux username naming rules. The system SHALL reject any username that does not match the pattern `^[a-z_][a-z0-9_-]{0,31}$`. Both the backend API and the frontend form SHALL enforce this rule.

The pattern enforces:
- Starts with a lowercase letter or underscore
- Contains only lowercase letters, digits, underscores, or hyphens
- Maximum 32 characters total

#### Scenario: Invalid username rejected at API level
- **WHEN** admin submits `POST /api/user` with a username that does not match `^[a-z_][a-z0-9_-]{0,31}$` (e.g., `"123"`, `"User@Name"`, `"a b"`)
- **THEN** the system returns a non-zero error code with a descriptive message; no user record is created

#### Scenario: Invalid username rejected at frontend level
- **WHEN** admin types an invalid username in the create-user dialog and submits
- **THEN** the frontend form displays a validation error message and does not call the API

#### Scenario: Valid username accepted
- **WHEN** admin submits a username matching `^[a-z_][a-z0-9_-]{0,31}$` (e.g., `"zhangsan"`, `"user_01"`, `"_admin"`)
- **THEN** the user is created successfully

### Requirement: Admin can list and manage users
The system SHALL provide `GET /api/user` to list all users and allow admin to enable/disable users by updating their status field.

#### Scenario: User list displays all users
- **WHEN** admin navigates to the user management page
- **THEN** a table shows all users with username, UID, email, status, and creation time

#### Scenario: Disable a user
- **WHEN** admin disables a user
- **THEN** the user's status changes to `0` (disabled) and they can no longer log in

### Requirement: Frontend route protection
The frontend Vue Router SHALL redirect unauthenticated users to `/login` when they attempt to access protected routes (e.g., `/notebooks`, `/specs`, `/users`). The guard SHALL check for a valid JWT token in `localStorage`.

#### Scenario: Unauthenticated access to protected route
- **WHEN** a user without a JWT navigates to `/notebooks`
- **THEN** the frontend redirects to `/login`

#### Scenario: Authenticated user accesses protected route
- **WHEN** a user with a valid JWT navigates to `/notebooks`
- **THEN** the page loads normally

### Requirement: Dynamic page titles
The frontend SHALL set the browser's `document.title` dynamically based on the current route, so users can identify the page from the browser tab or window title. The format SHALL be `{页面名称} — AI 训练平台`. When no page-specific title is defined, the fallback is `AI 训练平台`.

| 路由 | document.title |
|------|---------------|
| `/login` | 登录 — AI 训练平台 |
| `/notebooks` | 我的开发机 — AI 训练平台 |
| `/specs` | 规格管理 — AI 训练平台 |
| `/users` | 用户管理 — AI 训练平台 |

#### Scenario: Login page title
- **WHEN** user navigates to `/login`
- **THEN** the browser page title is "登录 — AI 训练平台"

#### Scenario: Notebook page title
- **WHEN** authenticated user navigates to `/notebooks`
- **THEN** the browser page title is "我的开发机 — AI 训练平台"

### Requirement: Login page UI
The system SHALL provide a login page with username and password input fields and a submit button. The page SHALL display error messages from the backend when login fails.

#### Scenario: Login form visible
- **WHEN** user navigates to `/login`
- **THEN** username field, password field, and login button are displayed

#### Scenario: Error message displayed on login failure
- **WHEN** user submits wrong credentials
- **THEN** an error message is shown on the login page and the page does not crash

### Requirement: Admin can edit users
The admin SHALL be able to modify an existing user's role (isAdmin) and password via `PUT /api/user/{id}`. At least one of the two fields MUST be provided. If password is provided, it SHALL be bcrypt-hashed before storage. The username and UID SHALL NOT be modifiable after creation.

#### Scenario: Admin changes user role to admin
- **WHEN** admin submits `PUT /api/user/{id}` with `{"isAdmin": 1}`
- **THEN** the user record is updated and subsequent logins reflect the new role

#### Scenario: Admin changes user password
- **WHEN** admin submits `PUT /api/user/{id}` with `{"password": "<newpass>"}`
- **THEN** the user's password hash is updated and the user can log in with the new password

### Requirement: Admin can soft-delete users
The admin SHALL be able to delete a user via `DELETE /api/user/{id}`. Deletion is soft — the record is retained in the database with a `deleted_at` timestamp set to the current time. Soft-deleted users SHALL NOT appear in `GET /api/user` list responses and SHALL NOT be able to log in. The admin user (id=1 or `is_admin=1`) SHALL be protected from deletion to prevent lockout.

#### Scenario: Admin deletes a user
- **WHEN** admin performs `DELETE /api/user/{id}` on a regular user
- **THEN** `deleted_at` is set on the record; the user no longer appears in the list

#### Scenario: Deleted user cannot log in
- **WHEN** a soft-deleted user attempts to log in
- **THEN** the system returns an error (user not found or account disabled)
