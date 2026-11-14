# Nestin Backend REST API (`/api/v1`)

**Base Prefix:** `/api/v1` (URI Versioning)  
**Interactive OpenAPI / Swagger UI:** `/api/docs`  
**Security:** Helmet headers, strict DTO `ValidationPipe`, Throttler rate limiting (`THROTTLE_LIMIT` req / `THROTTLE_TTL_SECONDS`s), CORS allow-list, Supabase JWT authentication (`SupabaseAuthGuard`), role guard extension (`@Roles`), and `AllExceptionsFilter`.

## 1. Standard Response & Error Envelopes

### Success Envelope
```json
{
  "success": true,
  "data": {},
  "meta": {
    "timestamp": "2026-11-14T08:00:00.000Z",
    "requestId": "uuid"
  }
}
```
Paginated list endpoints add `page`, `limit`, `total`, and `totalPages` inside `meta`.

### Error Envelope
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED | VALIDATION_ERROR | NOT_FOUND | FORBIDDEN | RATE_LIMITED | HTTP_503",
    "message": "Human-readable error description",
    "details": []
  },
  "meta": {
    "timestamp": "2026-11-14T08:00:00.000Z",
    "path": "/api/v1/...",
    "requestId": "uuid"
  }
}
```

---

## 2. P0 Endpoint Catalog

| Module | Method & Path | Auth | Purpose |
| :--- | :--- | :--- | :--- |
| **System** | `GET /api/v1/system/health` | Public | Liveness probe, version, uptime, Supabase verifier readiness |
| **System** | `GET /api/v1/system/status` | Public | Database connectivity diagnostics & local-first mode state |
| **Auth** | `GET /api/v1/auth/policy` | Public | Declares guest-first local operation and opt-in sync policy |
| **Auth** | `GET /api/v1/auth/session` | Bearer JWT | Validates Supabase token and returns user identity (`userId`, `email`, `role`) |
| **Auth** | `POST /api/v1/auth/guest-migration/prepare` | Bearer JWT | Links on-device `guestLocalId` UUID to registered account without uploading personal data |
| **Users** | `GET /api/v1/users/me` | Bearer JWT | Fetches authenticated profile metadata (under Supabase RLS) |
| **Users** | `PATCH /api/v1/users/me` | Bearer JWT | Updates `displayName`, `preferredLanguage`, `timezone`, `cloudSyncOptIn`, or `preferencesSnapshot` |
| **Users** | `DELETE /api/v1/users/me` | Bearer JWT | Soft-deletes cloud profile (`deleted_at`) while preserving local device data |
| **Devices** | `GET /api/v1/devices` | Bearer JWT | Lists active registered devices for user |
| **Devices** | `POST /api/v1/devices/register` | Bearer JWT | Upserts device identity & push token (`fcm` / `apns` / `none`) |
| **Devices** | `DELETE /api/v1/devices/:id` | Bearer JWT | Revokes & soft-deletes a registered device |
| **Content** | `GET /api/v1/content` | Public | Lists published educational guides & templates (`locale`, `category`, `tag`, `mascotDomain`, pagination) |
| **Content** | `GET /api/v1/content/:slug` | Public | Retrieves published article by `slug` |
| **Quotes** | `GET /api/v1/quotes` | Public | Lists published motivation quotes (`locale`, `category`, `mascotDomain`, `featured`, pagination) |
| **Quotes** | `GET /api/v1/quotes/featured` | Public | Retrieves featured quote for `?locale=en|id` |
| **Media** | `GET /api/v1/media` | Public | Lists wallpapers, inspiration cards, and downloadable pack metadata (`assetType`, `mascotDomain`, pagination) |
| **Media** | `GET /api/v1/media/:slug` | Public | Retrieves single media metadata & resolved public storage URL |
| **Remote Config** | `GET /api/v1/config` | Public | Returns `minSupportedVersion`, `latestVersion`, `maintenanceMode`, and `featureFlags` |

---

## 3. Inspiration & Daily Quote Endpoints (`/api/v1/inspiration`)

| Scope | Method & Path | Auth / Permission | Purpose |
| :--- | :--- | :--- | :--- |
| **Public** | `GET /api/v1/inspiration/featured` | Public (`?locale=en\|id`) | Backend-scheduled daily featured quote (fallback to active locale pool) |
| **Public** | `GET /api/v1/inspiration/quotes` | Public (`?category&author&locale&search&page&limit`) | Paginated published quote library with localization & category filters |
| **Public** | `GET /api/v1/inspiration/quotes/:id` | Public (`?locale=en\|id`) | Single published quote (resolving translation when available) |
| **Public** | `GET /api/v1/inspiration/categories` | Public (`?locale=en\|id`) | Admin-managed categories sorted by `sortOrder` |
| **Public** | `GET /api/v1/inspiration/authors` | Public (`?search`) | Active author catalog including anonymous contributor pool |
| **Public** | `GET /api/v1/inspiration/wallpapers` | Public (`?layoutType&mascotDomain`) | Published quote card & wallpaper preset definitions |
| **User** | `GET/POST/PUT/DELETE /api/v1/inspiration/me/quotes` | Bearer JWT (non-guest) | Manage personal quotes; editing a `PENDING` quote moves submission back to `DRAFT` |
| **User** | `GET/POST /api/v1/inspiration/me/submissions` | Bearer JWT (non-guest) | View or submit personal quotes with `rightsConfirmed` & duplicate check |
| **User** | `POST /api/v1/inspiration/me/submissions/:id/withdraw` | Bearer JWT (non-guest) | Withdraw a `PENDING` submission |
| **User** | `GET/POST/DELETE /api/v1/inspiration/me/favorites` | Bearer JWT (non-guest) | Optional cloud sync of favorite quotes |
| **User** | `GET/PUT /api/v1/inspiration/me/notification-preferences` | Bearer JWT (non-guest) | Daily Inspiration opt-in (`dailyEnabled = false` by default), time, timezone, frequency |
| **User** | `POST /api/v1/inspiration/quotes/:id/report` | Bearer JWT (non-guest) | Report inappropriate or misattributed published quote |
| **Admin CMS** | `GET/POST/PUT/DELETE /api/v1/admin/inspiration/quotes` & `publish/unpublish/archive` | `admin` / `moderator` + granular permissions | Curate editorial library; regular users receive `403 Forbidden` |
| **Admin CMS** | `GET/POST/PUT /api/v1/admin/inspiration/categories` & `/authors` & `/wallpapers` & `/translations` | `admin` + `inspiration.*.manage` | Manage categories (`en`/`id`), authors, wallpaper presets, translations |
| **Moderation** | `GET /api/v1/admin/inspiration/submissions`, `POST .../approve\|reject`, `GET .../history` | `admin` / `moderator` + `inspiration.submission.*` | Review queue with duplicate alerts, mandatory rejection reason, self-approval blocked (`403`), immutable audit log |
| **Scheduling** | `GET/POST/DELETE /api/v1/admin/inspiration/featured` | `admin` + `inspiration.featured.manage` | Schedule daily featured quote windows; overlapping locale windows return `409 Conflict` |
| **Notifications** | `GET /api/v1/admin/inspiration/notifications/logs`, `POST .../dispatch-due\|retry-failed` | `admin` | Audit push dispatch logs and trigger/retry timezone-aware daily dispatches |
