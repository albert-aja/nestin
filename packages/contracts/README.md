# Nestin Shared Contracts (`packages/contracts`)

Language-neutral and TypeScript definitions documenting shared request, response, error, pagination, and P1 synchronization contracts between `apps/mobile` (Flutter) and `apps/backend` (NestJS).

## Conventions

1. **API Versioning:** All REST endpoints live under `/api/v1`.
2. **Envelope Format:**
   - Single resource or payload: `{ "success": true, "data": ..., "meta": { "timestamp": "...", "requestId": "..." } }`
   - Paginated list: `{ "success": true, "data": [...], "meta": { "page": 1, "limit": 20, "total": 42, "totalPages": 3 } }`
   - Error response: `{ "success": false, "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [...] }, "meta": { "timestamp": "...", "path": "/api/v1/...", "requestId": "..." } }`
3. **Sync-Ready Record Convention (P1 Extension Point):**
   - `id`: UUID v4 string
   - `createdAt`: ISO-8601 UTC timestamp
   - `updatedAt`: ISO-8601 UTC timestamp
   - `deletedAt`: nullable ISO-8601 UTC timestamp (soft delete tombstone)
   - `syncStatus` (mobile local state): `'local_only' | 'pending_push' | 'synced' | 'conflict'`

## Files

- `api.types.ts`: Strict TypeScript interfaces mirrored by `apps/backend` DTOs and `apps/mobile/lib/core/config/api_contracts.dart`.
