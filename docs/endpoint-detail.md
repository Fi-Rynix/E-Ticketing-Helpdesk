# Endpoint Detail — Request & Response Specification

> **Status:** Final, siap masuk laporan
> **Tanggal:** 2026-06-03
> **Tujuan:** Detail request body, response body, status code, dan error response untuk setiap endpoint
> **Base URL:** `https://brkylvdfffjmfaiebgcf.supabase.co`
> **Dokumen Terkait:** [`API.md`](./API.md) (kontrak), [`erd.md`](./erd.md) (schema), [`flow.md`](./flow.md) (use case)

---

## Daftar Isi

1. [Konvensi](#1-konvensi)
2. [Auth Endpoints](#2-auth-endpoints)
3. [Users](#3-users)
4. [Helpdesks](#4-helpdesks)
5. [Tickets — List & Detail](#5-tickets--list--detail)
6. [Tickets — Create](#6-tickets--create)
7. [Tickets — User Actions](#7-tickets--user-actions)
8. [Tickets — Admin Actions](#8-tickets--admin-actions)
9. [Tickets — Helpdesk Actions](#9-tickets--helpdesk-actions)
10. [Comments](#10-comments)
11. [Notifications](#11-notifications)
12. [Ticket Logs](#12-ticket-logs)
13. [Storage](#13-storage)
14. [Error Responses](#14-error-responses)

---

## 1. Konvensi

### 1.1. HTTP Method

| Method | Fungsi |
|--------|--------|
| `GET` | Read data |
| `POST` | Create baru |
| `PATCH` | Update sebagian field |
| `DELETE` | Hapus |

### 1.2. Header Wajib

Semua request ke `/rest/v1/*` (kecuali public read) butuh:

```
Headers:
  apikey: <SUPABASE_ANON_KEY>          ← dari .env
  Authorization: Bearer <jwt>          ← dari login response
  Content-Type: application/json       ← untuk POST/PATCH dengan body JSON
  Prefer: return=representation         ← (opsional) supaya return full row
```

### 1.3. Status Code

| Code | Arti | Kapan Terjadi |
|------|------|---------------|
| `200 OK` | Sukses | GET, PATCH, DELETE berhasil |
| `201 Created` | Resource dibuat | POST berhasil (dengan `Prefer: return=representation`) |
| `204 No Content` | Sukses tanpa body | POST/DELETE tanpa representation |
| `400 Bad Request` | Input invalid | Body JSON salah, enum invalid |
| `401 Unauthorized` | JWT invalid/expired | Token salah atau kadaluarsa |
| `403 Forbidden` | RLS deny | User coba akses data yang bukan miliknya |
| `404 Not Found` | Data tidak ada | Query dengan id yang tidak exist |
| `409 Conflict` | Conflict | Duplicate key |
| `500 Internal Server Error` | Server error | Trigger function error, dll |

### 1.4. Konvensi Penamaan

| Item | Format | Contoh |
|------|--------|--------|
| Tabel | `lowercase_plural` | `users`, `tickets`, `comments` |
| Primary key | `id_{table_singular}` | `id_user`, `id_ticket`, `id_comment` |
| Foreign key | `id_{ref_table_singular}` | `id_user`, `id_helpdesk`, `id_ticket` |
| Timestamp | `{event}_at` atau `created_at`/`updated_at` | `created_at`, `cancelled_at`, `started_at` |
| Boolean | `is_*` | `is_available`, `is_read`, `is_edited` |

### 1.5. Format Response

**Sukses (GET single):**
```json
{
  "id_ticket": 1,
  "title": "Laptop rusak",
  "status": "open",
  ...
}
```

**Sukses (GET list):**
```json
[
  { "id_ticket": 1, ... },
  { "id_ticket": 2, ... }
]
```

**Error (PostgREST):**
```json
{
  "code": "42501",
  "details": null,
  "hint": null,
  "message": "new row violates row-level security policy for table \"tickets\""
}
```

**Error (Supabase Auth):**
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid login credentials"
}
```

---

## 2. Auth Endpoints

### 2.1. Login

**Request:**
```http
POST /auth/v1/token?grant_type=password
Content-Type: application/json
apikey: <SUPABASE_ANON_KEY>

{
  "email": "budi@uts.id",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJhdXRoZW5...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "v1.MmYxYjAz...",
  "user": {
    "id": "abc-123-def-456",
    "aud": "authenticated",
    "role": "authenticated",
    "email": "budi@uts.id",
    "email_confirmed_at": "2026-06-03T08:00:00.000Z",
    "phone": "",
    "confirmed_at": "2026-06-03T08:00:00.000Z",
    "last_sign_in_at": "2026-06-03T08:00:00.000Z",
    "app_metadata": {
      "provider": "email",
      "providers": ["email"]
    },
    "user_metadata": {
      "username": "budi"
    },
    "identities": [...],
    "created_at": "2026-06-01T10:00:00.000Z",
    "updated_at": "2026-06-03T08:00:00.000Z"
  }
}
```

**Error Responses:**
| Status | Code | Message |
|--------|------|---------|
| 400 | `invalid_grant` | Invalid login credentials |
| 400 | `email_not_confirmed` | Email not confirmed (kalau confirmation on) |
| 422 | - | Missing field: email / password |

---

### 2.2. Register

**Request:**
```http
POST /auth/v1/signup
Content-Type: application/json
apikey: <SUPABASE_ANON_KEY>

{
  "email": "newuser@uts.id",
  "password": "password123",
  "options": {
    "data": {
      "username": "newuser"
    }
  }
}
```

**Response (200 OK):**
```json
{
  "user": {
    "id": "xyz-789-abc-123",
    "email": "newuser@uts.id",
    "email_confirmed_at": null,
    "aud": "authenticated",
    "role": "authenticated",
    "user_metadata": {
      "username": "newuser"
    },
    ...
  },
  "session": {
    "access_token": "eyJhbGci...",
    "token_type": "bearer",
    "expires_in": 3600,
    "refresh_token": "v1.MmYxYjAz..."
  }
}
```

> **Note:** Trigger `handle_new_user()` otomatis insert ke `users` dengan `auth_user_id = user.id` dan `username = user.email`.

---

### 2.3. Logout

**Request:**
```http
POST /auth/v1/logout
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (204 No Content):** (empty body)

---

### 2.4. Get Current User

**Request:**
```http
GET /auth/v1/user
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
{
  "id": "abc-123-def-456",
  "email": "budi@uts.id",
  "phone": "",
  "role": "authenticated",
  "email_confirmed_at": "2026-06-03T08:00:00.000Z",
  "user_metadata": { "username": "budi" },
  "app_metadata": { "provider": "email" }
}
```

---

### 2.5. Get Profile (Bridge to Business Table)

**Request:**
```http
GET /rest/v1/users?auth_user_id=eq.abc-123-def-456&select=*
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_user": 1,
    "auth_user_id": "abc-123-def-456",
    "username": "budi",
    "role": "user",
    "avatar_url": null,
    "created_at": "2026-06-01T10:00:00.000Z"
  }
]
```

---

## 3. Users

### 3.1. Get User by ID

**Request:**
```http
GET /rest/v1/users?id_user=eq.1&select=*
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_user": 1,
    "auth_user_id": "abc-123-def-456",
    "username": "budi",
    "role": "user",
    "avatar_url": null,
    "created_at": "2026-06-01T10:00:00.000Z"
  }
]
```

**Empty Response (200 OK):**
```json
[]
```

---

### 3.2. Get User by Username

**Request:**
```http
GET /rest/v1/users?username=eq.budi&select=*
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response:** (sama dengan 3.1)

---

### 3.3. Get Users by Role

**Request:**
```http
GET /rest/v1/users?role=eq.admin&select=*&order=username.asc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_user": 5,
    "auth_user_id": "admin-uuid",
    "username": "eko",
    "role": "admin",
    "avatar_url": "avatars/5.jpg",
    "created_at": "2026-06-01T10:00:00.000Z"
  }
]
```

---

### 3.4. Update User (Sendiri / Admin)

**Request:**
```http
PATCH /rest/v1/users?id_user=eq.1
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "username": "budi_updated",
  "avatar_url": "avatars/1.jpg"
}
```

**Response (200 OK):**
```json
{
  "id_user": 1,
  "auth_user_id": "abc-123-def-456",
  "username": "budi_updated",
  "role": "user",
  "avatar_url": "avatars/1.jpg",
  "created_at": "2026-06-01T10:00:00.000Z"
}
```

**Validation Rules:**
- `username` harus UNIQUE — kalau sudah dipakai user lain, dapat error
- `role` hanya bisa diubah oleh admin (RLS policy)
- User hanya bisa update record sendiri (cek `auth_user_id = auth.uid()`)

---

## 4. Helpdesks

### 4.1. List All Helpdesks

**Request:**
```http
GET /rest/v1/helpdesks?select=*,id_user&order=name.asc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_helpdesk": 1,
    "id_user": 2,
    "name": "Alan Udin",
    "phone": "08123456789",
    "is_available": true,
    "created_at": "2026-06-01T10:00:00.000Z"
  },
  {
    "id_helpdesk": 2,
    "id_user": 3,
    "name": "Vikibara Can",
    "phone": null,
    "is_available": false,
    "created_at": "2026-06-01T10:00:00.000Z"
  }
]
```

---

### 4.2. List Available Helpdesks + Active Ticket Count (untuk Assignment Picker)

**Request:**
```http
GET /rest/v1/helpdesks?is_available=eq.true&select=id_helpdesk,name,is_available,active_tickets:tickets(count)
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_helpdesk": 1,
    "name": "Alan Udin",
    "is_available": true,
    "active_tickets": [{ "count": 3 }]
  },
  {
    "id_helpdesk": 3,
    "name": "Rizkimok",
    "is_available": true,
    "active_tickets": [{ "count": 1 }]
  }
]
```

> Admin pilih helpdesk dengan `active_tickets.count` paling kecil (workload terendah).

---

### 4.3. Update Availability (Helpdesk Sendiri)

**Request:**
```http
PATCH /rest/v1/helpdesks?id_helpdesk=eq.1
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "is_available": false
}
```

**Response (200 OK):**
```json
{
  "id_helpdesk": 1,
  "id_user": 2,
  "name": "Alan Udin",
  "phone": "08123456789",
  "is_available": false,
  "created_at": "2026-06-01T10:00:00.000Z"
}
```

**Trigger:** `log_helpdesk.availability_changed` otomatis insert ke `ticket_logs`.

---

## 5. Tickets — List & Detail

### 5.1. List All Tickets (Cursor Pagination)

**Request:**
```http
GET /rest/v1/tickets?select=*,id_user,id_helpdesk&order=created_at.desc&limit=20
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Query Params:**
| Param | Type | Default | Keterangan |
|-------|------|---------|------------|
| `limit` | int | 20 | Max 100 |
| `offset` | int | 0 | Offset (kalau pakai offset) |
| `order` | string | - | Format: `column.direction`, contoh `created_at.desc` |

**Response (200 OK):**
```json
[
  {
    "id_ticket": 5,
    "title": "Network problem",
    "description": "Wifi di kantor sering putus-putus",
    "status": "done",
    "id_user": 1,
    "id_helpdesk": 1,
    "photo_path": "5/1717392000.jpg",
    "cancelled_reason": null,
    "cancelled_at": null,
    "unassign_id_helpdesk": null,
    "unassign_requested_at": null,
    "unassign_reason": null,
    "unassign_id_user": null,
    "unassign_decided_at": null,
    "unassign_reject_reason": null,
    "started_at": "2026-05-25T10:00:00.000Z",
    "completed_at": "2026-05-28T14:30:00.000Z",
    "created_at": "2026-05-23T09:00:00.000Z",
    "updated_at": "2026-05-28T14:30:00.000Z"
  }
]
```

**Response Range Header (untuk cursor):**
```
Content-Range: 0-19/47
```
Artinya: 20 dari 47 total. Kalau 20 = limit dan total > 20, ada data lagi.

---

### 5.2. Filter Tiket by User (My Tickets)

**Request:**
```http
GET /rest/v1/tickets?id_user=eq.1&order=created_at.desc&limit=20
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response:** (sama dengan 5.1, filtered by `id_user=1`)

---

### 5.3. Filter Tiket by Status

**Request:**
```http
GET /rest/v1/tickets?status=eq.open&order=created_at.desc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Status values:** `open` | `assigned` | `in_progress` | `pending_unassign` | `done` | `cancelled`

---

### 5.4. Filter Tiket by Helpdesk (My Tasks)

**Request:**
```http
GET /rest/v1/tickets?id_helpdesk=eq.1&status=in.(assigned,in_progress)&order=created_at.desc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

---

### 5.5. Get Detail Tiket + Comments

**Request:**
```http
GET /rest/v1/tickets?id_ticket=eq.1&select=*,comments(id_comment,id_user,message,is_edited,created_at,updated_at,id_user),ticket_attachments(*)
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_ticket": 1,
    "title": "Laptop tidak nyala",
    "description": "Laptop mati total, tidak bisa di-charge",
    "status": "in_progress",
    "id_user": 1,
    "id_helpdesk": 1,
    "photo_path": "1/1717392000.jpg",
    "cancelled_reason": null,
    "cancelled_at": null,
    "started_at": "2026-06-02T10:00:00.000Z",
    "completed_at": null,
    "created_at": "2026-06-01T10:00:00.000Z",
    "updated_at": "2026-06-02T10:00:00.000Z",
    "comments": [
      {
        "id_comment": 1,
        "id_user": 1,
        "message": "Tolong bantu, urgent banget",
        "is_edited": false,
        "created_at": "2026-06-01T10:05:00.000Z",
        "updated_at": "2026-06-01T10:05:00.000Z"
      },
      {
        "id_comment": 2,
        "id_user": 2,
        "message": "Siap, saya cek dulu ya",
        "is_edited": true,
        "created_at": "2026-06-01T10:10:00.000Z",
        "updated_at": "2026-06-01T10:15:00.000Z"
      }
    ],
    "ticket_attachments": [
      {
        "id_ticket_attachment": 1,
        "id_ticket": 1,
        "storage_path": "1/1717392000.jpg",
        "mime_type": "image/jpeg",
        "file_size": 524288,
        "uploaded_at": "2026-06-01T10:00:00.000Z"
      }
    ]
  }
]
```

---

## 6. Tickets — Create

### 6.1. Create Ticket (User)

**Request:**
```http
POST /rest/v1/tickets
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "title": "Monitor berkedip",
  "description": "Monitor saya berkedip terus, tidak nyaman untuk kerja",
  "id_user": 1,
  "photo_path": "1/1717395000.jpg"
}
```

**Request Body Schema:**
| Field | Type | Required | Keterangan |
|-------|------|----------|------------|
| `title` | string | ✅ | Judul tiket |
| `description` | string | ✅ | Isi laporan |
| `id_user` | int | ✅ | ID user (INT, dari currentUser.idUser) |
| `photo_path` | string | ❌ | Path foto di Storage (kalau ada) |

> **Note:** `status` auto-set ke `'open'` (default). Tidak perlu dikirim.

**Response (201 Created):**
```json
{
  "id_ticket": 10,
  "title": "Monitor berkedip",
  "description": "Monitor saya berkedip terus, tidak nyaman untuk kerja",
  "status": "open",
  "id_user": 1,
  "id_helpdesk": null,
  "photo_path": "1/1717395000.jpg",
  "cancelled_reason": null,
  "cancelled_at": null,
  "unassign_id_helpdesk": null,
  "unassign_requested_at": null,
  "unassign_reason": null,
  "unassign_id_user": null,
  "unassign_decided_at": null,
  "unassign_reject_reason": null,
  "started_at": null,
  "completed_at": null,
  "created_at": "2026-06-03T08:00:00.000Z",
  "updated_at": "2026-06-03T08:00:00.000Z"
}
```

**Trigger Effects (otomatis):**
- Insert ke `ticket_logs` event `ticket.created` (actor = user yang create)
- Insert ke `notifications` untuk SEMUA admin (type=`ticket_created`)

**Error Responses:**
| Status | Code | Message | Penyebab |
|--------|------|---------|----------|
| 401 | - | JWT invalid | Token expired/salah |
| 403 | 42501 | new row violates row-level security policy | id_user bukan milik user yang login |
| 400 | 22023 | invalid input value for enum | title kosong, description kosong |
| 401 | 23502 | null value in column "title" | Field required kosong |

---

### 6.2. Add Ticket Attachment (Foto)

**Request:**
```http
POST /rest/v1/ticket_attachments
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id_ticket": 10,
  "storage_path": "10/1717395000.jpg",
  "mime_type": "image/jpeg",
  "file_size": 524288
}
```

> **Note:** Upload file binary-nya dilakukan di endpoint Storage (lihat section 13). Endpoint ini hanya menyimpan metadata-nya.

**Response (201 Created):**
```json
{
  "id_ticket_attachment": 5,
  "id_ticket": 10,
  "storage_path": "10/1717395000.jpg",
  "mime_type": "image/jpeg",
  "file_size": 524288,
  "uploaded_at": "2026-06-03T08:00:00.000Z"
}
```

---

## 7. Tickets — User Actions

### 7.1. Edit Ticket (User, hanya saat status=open)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=eq.open
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "title": "Monitor berkedip terus (updated)",
  "description": "Update: sudah coba ganti kabel VGA tetap berkedip",
  "photo_path": "10/1717396000.jpg"
}
```

**Request Body (opsional, minimal 1 field):**
| Field | Type | Keterangan |
|-------|------|------------|
| `title` | string | Judul baru |
| `description` | string | Deskripsi baru |
| `photo_path` | string | Path foto baru |

**Response (200 OK):** (same shape as Create Response, dengan field updated)

**Trigger:** Insert ke `ticket_logs` event `ticket.updated` dengan before/after snapshot.

**Error Responses:**
| Status | Code | Message | Penyebab |
|--------|------|---------|----------|
| 403 | 42501 | row-level security policy | Bukan owner, atau status bukan 'open' |
| 404 | PGRST116 | Result contains 0 rows | id_ticket tidak ada |

---

### 7.2. Cancel Ticket (User, hanya saat status=open, wajib alasan)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=eq.open
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "status": "cancelled",
  "cancelled_reason": "Sudah tidak perlu, sudah saya beli monitor baru sendiri",
  "cancelled_at": "2026-06-03T08:30:00.000Z"
}
```

**Request Body (semua required):**
| Field | Type | Required | Keterangan |
|-------|------|----------|------------|
| `status` | string | ✅ | Harus `'cancelled'` |
| `cancelled_reason` | string | ✅ | Alasan, min 5 char (validasi di client) |
| `cancelled_at` | timestamptz | ✅ | ISO 8601 timestamp |

**Response (200 OK):**
```json
{
  "id_ticket": 10,
  "status": "cancelled",
  "cancelled_reason": "Sudah tidak perlu, sudah saya beli monitor baru sendiri",
  "cancelled_at": "2026-06-03T08:30:00.000Z",
  ...
}
```

**Trigger:**
- Insert ke `ticket_logs` event `ticket.cancelled`
- Insert ke `notifications` untuk SEMUA admin (type=`ticket_cancelled`)

---

## 8. Tickets — Admin Actions

### 8.1. Assign Ticket (Open → Assigned)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=eq.open
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id_helpdesk": 1,
  "status": "assigned"
}
```

**Response (200 OK):**
```json
{
  "id_ticket": 10,
  "status": "assigned",
  "id_helpdesk": 1,
  "id_user": 1,
  ...
}
```

**Trigger Effects:**
- Insert ke `ticket_logs` event `ticket.assigned` (actor = admin)
- Insert ke `notifications`:
  - Untuk user (type=`ticket_assigned`, body="Tiket Anda telah ditugaskan ke helpdesk")
  - Untuk helpdesk (type=`ticket_assigned`, body="Anda mendapat tiket baru")

---

### 8.2. Un-assign Ticket (Kembali ke Open)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=in.(assigned,in_progress)
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id_helpdesk": null,
  "status": "open"
}
```

**Response (200 OK):**
```json
{
  "id_ticket": 10,
  "status": "open",
  "id_helpdesk": null,
  ...
}
```

**Trigger:**
- Insert ke `ticket_logs` event `ticket.unassigned` (dengan from_helpdesk)
- Insert ke `notifications` untuk helpdesk lama (type=`ticket_unassigned`)

---

### 8.3. Re-assign Ticket (Ganti Helpdesk)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=in.(assigned,in_progress)
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id_helpdesk": 2
}
```

> `id_helpdesk` berubah dari 1 ke 2, `status` tetap `assigned`.

**Response (200 OK):** (same shape, dengan id_helpdesk=2)

**Trigger Effects:**
- Insert ke `ticket_logs` event `ticket.reassigned` (from_helpdesk=1, to_helpdesk=2)
- Insert ke `notifications`:
  - Helpdesk lama (type=`ticket_unassigned`, "Tiket dilepas")
  - Helpdesk baru (type=`ticket_assigned`, "Tiket ditugaskan ke Anda")
  - User (type=`ticket_assigned`, "Tiket Anda ditugaskan ulang")

---

### 8.4. Approve Un-assign Request

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=eq.pending_unassign
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "status": "open",
  "unassign_id_user": 5,
  "unassign_decided_at": "2026-06-03T09:00:00.000Z"
}
```

**Request Body:**
| Field | Type | Required | Keterangan |
|-------|------|----------|------------|
| `status` | string | ✅ | `'open'` (kembalikan ke antrian) |
| `unassign_id_user` | int | ✅ | ID admin yang approve |
| `unassign_decided_at` | timestamptz | ✅ | ISO 8601 timestamp |

**Response (200 OK):** (ticket kembali ke `status=open`, `id_helpdesk=null`)

**Trigger:** Insert notif ke helpdesk (type=`ticket_unassign_approved`)

---

### 8.5. Reject Un-assign Request

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=eq.pending_unassign
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "status": "assigned",
  "unassign_id_user": 5,
  "unassign_decided_at": "2026-06-03T09:00:00.000Z",
  "unassign_reject_reason": "Tolong selesaikan dulu, handover ke UDIN"
}
```

**Response (200 OK):** (ticket kembali ke `status=assigned`)

**Trigger:** Insert notif ke helpdesk (type=`ticket_unassign_rejected`)

---

## 9. Tickets — Helpdesk Actions

### 9.1. Start Progress (Auto saat Buka Tiket Assigned)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&id_helpdesk=eq.1&status=eq.assigned
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "status": "in_progress",
  "started_at": "2026-06-03T10:00:00.000Z"
}
```

**Response (200 OK):** (status=`in_progress`, `started_at` terisi)

**Trigger:** Insert notif ke user (type=`ticket_in_progress`)

---

### 9.2. Mark as Done

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=in.(assigned,in_progress)
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "status": "done",
  "completed_at": "2026-06-03T14:00:00.000Z"
}
```

**Response (200 OK):**
```json
{
  "id_ticket": 10,
  "status": "done",
  "completed_at": "2026-06-03T14:00:00.000Z",
  "started_at": "2026-06-03T10:00:00.000Z",
  ...
}
```

**Trigger Effects:**
- Insert ke `ticket_logs` event `ticket.status_changed` (in_progress → done)
- Insert ke `notifications`:
  - User (type=`ticket_done`, "Tiket Anda selesai")
  - SEMUA admin (type=`ticket_done`, "Helpdesk menyelesaikan tiket")

---

### 9.3. Request Un-assign (dengan Alasan)

**Request:**
```http
PATCH /rest/v1/tickets?id_ticket=eq.10&status=in.(assigned,in_progress)
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "status": "pending_unassign",
  "unassign_id_helpdesk": 1,
  "unassign_requested_at": "2026-06-03T11:00:00.000Z",
  "unassign_reason": "Sibuk dengan tiket lain, butuh 2 hari lagi"
}
```

**Request Body:**
| Field | Type | Required | Keterangan |
|-------|------|----------|------------|
| `status` | string | ✅ | `'pending_unassign'` |
| `unassign_id_helpdesk` | int | ✅ | ID helpdesk yang request |
| `unassign_requested_at` | timestamptz | ✅ | ISO 8601 timestamp |
| `unassign_reason` | string | ✅ | Alasan, min 5 char (validasi di client) |

**Response (200 OK):**
```json
{
  "id_ticket": 10,
  "status": "pending_unassign",
  "unassign_id_helpdesk": 1,
  "unassign_reason": "Sibuk dengan tiket lain, butuh 2 hari lagi",
  ...
}
```

**Trigger:** Insert ke `notifications` untuk SEMUA admin (type=`ticket_unassign_requested`)

---

## 10. Comments

### 10.1. List Comments per Tiket

**Request:**
```http
GET /rest/v1/comments?id_ticket=eq.10&select=*,id_user&order=created_at.asc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_comment": 1,
    "id_ticket": 10,
    "id_user": 1,
    "message": "Tolong bantu urgent",
    "is_edited": false,
    "created_at": "2026-06-01T10:05:00.000Z",
    "updated_at": "2026-06-01T10:05:00.000Z"
  }
]
```

---

### 10.2. Add Comment

**Request:**
```http
POST /rest/v1/comments
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id_ticket": 10,
  "id_user": 2,
  "message": "Saya cek dulu, 5 menit lagi ya"
}
```

**Request Body:**
| Field | Type | Required | Keterangan |
|-------|------|----------|------------|
| `id_ticket` | int | ✅ | Tiket yang dikomentari |
| `id_user` | int | ✅ | Author (dari currentUser.idUser) |
| `message` | string | ✅ | Isi komentar |

**Response (201 Created):**
```json
{
  "id_comment": 3,
  "id_ticket": 10,
  "id_user": 2,
  "message": "Saya cek dulu, 5 menit lagi ya",
  "is_edited": false,
  "created_at": "2026-06-01T10:10:00.000Z",
  "updated_at": "2026-06-01T10:10:00.000Z"
}
```

**Trigger Effects:**
- Insert ke `ticket_logs` event `comment.added` (dengan snippet 100 char)
- Insert ke `notifications`:
  - User ticket (type=`comment_added`)
  - Helpdesk assigned ke tiket (type=`comment_added`)
  - ❌ Admin TIDAK dapat notif

---

### 10.3. Add Comment Attachment (Max 3 per Comment)

**Request:**
```http
POST /rest/v1/comment_attachments
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "id_comment": 3,
  "storage_path": "3/1717397000-1.jpg",
  "mime_type": "image/jpeg",
  "file_size": 245678
}
```

**Response (201 Created):**
```json
{
  "id_comment_attachment": 1,
  "id_comment": 3,
  "storage_path": "3/1717397000-1.jpg",
  "mime_type": "image/jpeg",
  "file_size": 245678,
  "uploaded_at": "2026-06-01T10:10:00.000Z"
}
```

**Error (kalau sudah 3):**
```json
{
  "code": "P0001",
  "message": "Maximum 3 attachments per comment"
}
```

> Trigger `check_max_attachments()` reject kalau insert ke-4.

---

### 10.4. Edit Comment (Author Only, Unlimited Window)

**Request:**
```http
PATCH /rest/v1/comments?id_comment=eq.3&id_user=eq.2
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json
Prefer: return=representation

{
  "message": "Saya cek dulu, 5-10 menit lagi ya (koreksi)",
  "is_edited": true
}
```

**Response (200 OK):**
```json
{
  "id_comment": 3,
  "id_ticket": 10,
  "id_user": 2,
  "message": "Saya cek dulu, 5-10 menit lagi ya (koreksi)",
  "is_edited": true,
  "created_at": "2026-06-01T10:10:00.000Z",
  "updated_at": "2026-06-01T10:15:00.000Z"
}
```

**Trigger:** Insert ke `ticket_logs` event `comment.edited` (dengan before/after content)

---

### 10.5. Delete Comment (Author Only, Hard Delete)

**Request:**
```http
DELETE /rest/v1/comments?id_comment=eq.3&id_user=eq.2
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Prefer: return=representation
```

**Response (200 OK):**
```json
{
  "id_comment": 3,
  "id_ticket": 10,
  "id_user": 2,
  "message": "...",
  ...
}
```

**Trigger:** Insert ke `ticket_logs` event `comment.deleted` (dengan snapshot content)

---

## 11. Notifications

### 11.1. List Notifications (Cursor Pagination)

**Request:**
```http
GET /rest/v1/notifications?id_user=eq.1&order=created_at.desc&limit=20
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_notification": 5,
    "id_user": 1,
    "type": "ticket_done",
    "title": "Tiket selesai",
    "body": "Tiket #abc Anda telah selesai.",
    "id_ticket": 10,
    "is_read": false,
    "created_at": "2026-06-03T14:00:00.000Z"
  }
]
```

---

### 11.2. List Unread Notifications

**Request:**
```http
GET /rest/v1/notifications?id_user=eq.1&is_read=eq.false&order=created_at.desc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

---

### 11.3. Count Unread (untuk Badge)

**Request:**
```http
GET /rest/v1/notifications?id_user=eq.1&is_read=eq.false&select=id_notification
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Prefer: count=exact
```

**Response Headers:**
```
Content-Range: 0-4/5
```

Response body: array of `{id_notification: ...}` (5 items).

---

### 11.4. Mark as Read (Single)

**Request:**
```http
PATCH /rest/v1/notifications?id_notification=eq.5&id_user=eq.1
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "is_read": true
}
```

**Response (200 OK):**
```json
{
  "id_notification": 5,
  "is_read": true,
  ...
}
```

---

### 11.5. Mark as Read (Bulk)

**Request:**
```http
PATCH /rest/v1/notifications?id_notification=in.(5,6,7)&id_user=eq.1
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "is_read": true
}
```

**Response (200 OK):** (array of 3 updated notifications)

---

### 11.6. Mark All as Read

**Request:**
```http
PATCH /rest/v1/notifications?id_user=eq.1&is_read=eq.false
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: application/json

{
  "is_read": true
}
```

**Response (200 OK):** (array of all unread notifications, sekarang is_read=true)

---

### 11.7. Dismiss Notification (Hard Delete)

**Request:**
```http
DELETE /rest/v1/notifications?id_notification=eq.5&id_user=eq.1
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (204 No Content):** (empty body)

---

## 12. Ticket Logs

### 12.1. List Logs per Tiket (All)

**Request:**
```http
GET /rest/v1/ticket_logs?id_ticket=eq.10&order=created_at.desc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "id_ticket_log": 25,
    "id_ticket": 10,
    "id_user": 1,
    "actor_role": "user",
    "event_type": "ticket.created",
    "payload": {
      "title": "Monitor berkedip",
      "description": "Monitor saya berkedip terus"
    },
    "created_at": "2026-06-03T08:00:00.000Z"
  },
  {
    "id_ticket_log": 26,
    "id_ticket": 10,
    "id_user": 5,
    "actor_role": "admin",
    "event_type": "ticket.assigned",
    "payload": {
      "id_helpdesk": 1
    },
    "created_at": "2026-06-03T08:15:00.000Z"
  },
  {
    "id_ticket_log": 27,
    "id_ticket": 10,
    "id_user": 2,
    "actor_role": "helpdesk",
    "event_type": "comment.added",
    "payload": {
      "id_comment": 1,
      "snippet": "Saya cek dulu ya"
    },
    "created_at": "2026-06-03T08:20:00.000Z"
  }
]
```

**Event Type Reference (lihat di `erd.md` section 7.2 untuk lengkap):**
| Event | Payload |
|-------|---------|
| `ticket.created` | `{title, description}` |
| `ticket.assigned` | `{id_helpdesk}` |
| `ticket.reassigned` | `{from, to}` |
| `ticket.unassigned` | `{from}` |
| `ticket.unassign_requested` | `{requested_by, reason}` |
| `ticket.unassign_approved` | `{decided_by}` |
| `ticket.unassign_rejected` | `{decided_by, reject_reason}` |
| `ticket.status_changed` | `{from, to, id_helpdesk}` |
| `ticket.cancelled` | `{reason, cancelled_at}` |
| `ticket.updated` | `{before: {...}, after: {...}}` |
| `comment.added` | `{id_comment, snippet}` |
| `comment.edited` | `{id_comment, before, after}` |
| `comment.deleted` | `{id_comment, message}` |
| `helpdesk.availability_changed` | `{from, to}` |

---

### 12.2. Filter Log by Date (Hari Ini)

**Request:**
```http
GET /rest/v1/ticket_logs?id_ticket=eq.10&created_at=gte.2026-06-03T00:00:00.000Z&order=created_at.desc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

> Client hitung `today_start` = `DateTime.now().copyWith(hour: 0, minute: 0, second: 0)`.

---

### 12.3. Filter Log by Date (7 Hari Terakhir)

**Request:**
```http
GET /rest/v1/ticket_logs?id_ticket=eq.10&created_at=gte.2026-05-28T00:00:00.000Z&order=created_at.desc
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

> Client hitung `sevenDaysAgo` = `DateTime.now().subtract(Duration(days: 7))`.

---

### 12.4. List Log Agregat per User (Activity Feed)

**Request:**
```http
GET /rest/v1/ticket_logs?id_user=eq.1&order=created_at.desc&limit=20
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

---

## 13. Storage

### 13.1. Upload Foto Tiket

**Request:**
```http
POST /storage/v1/object/ticket-photos/{id_ticket}/{timestamp}.jpg
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: image/jpeg

<binary image data>
```

**Path Format:** `tickets/{id_ticket}/{timestamp}.jpg`
Contoh: `tickets/10/1717395000.jpg`

**Response (200 OK):**
```json
{
  "Key": "ticket-photos/10/1717395000.jpg",
  "Id": "abc-123"
}
```

**Validation:**
- Max 5 MB
- MIME: `image/jpeg` atau `image/png`
- Path: `ticket-photos/{...}` (RLS enforce)

---

### 13.2. Get Public URL Foto

**Request:**
```http
GET /storage/v1/object/ticket-photos/{id_ticket}/{timestamp}.jpg
```

**Response (200 OK):** (binary image, atau 404 kalau gak ada)

Atau kalau public bucket: langsung akses via URL:
```
https://brkylvdfffjmfaiebgcf.supabase.co/storage/v1/object/public/ticket-photos/10/1717395000.jpg
```

---

### 13.3. Upload Foto Avatar

**Request:**
```http
POST /storage/v1/object/avatars/{id_user}.jpg
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: image/jpeg

<binary image data>
```

**Path Format:** `avatars/{id_user}.jpg`

---

### 13.4. Upload Comment Attachment

**Request:**
```http
POST /storage/v1/object/comment-attachments/{id_comment}/{timestamp}-{n}.jpg
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
Content-Type: image/jpeg

<binary image data>
```

**Path Format:** `comments/{id_comment}/{timestamp}-{n}.jpg`
Contoh: `comments/3/1717397000-1.jpg` (timestamp-nomor urut)

---

### 13.5. Delete File

**Request:**
```http
DELETE /storage/v1/object/ticket-photos/{path}
Authorization: Bearer <jwt>
apikey: <SUPABASE_ANON_KEY>
```

**Response (200 OK):**
```json
[
  {
    "Key": "ticket-photos/10/1717395000.jpg"
  }
]
```

---

## 14. Error Responses

### 14.1. Format Error

**PostgREST Error:**
```json
{
  "code": "42501",
  "details": null,
  "hint": null,
  "message": "new row violates row-level security policy for table \"tickets\""
}
```

**Supabase Auth Error:**
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid login credentials",
  "code": 400
}
```

**Postgres Error (raw):**
```json
{
  "code": "23505",
  "details": "Key (username)=(budi) already exists.",
  "hint": null,
  "message": "duplicate key value violates unique constraint \"users_username_key\""
}
```

### 14.2. Tabel Error Code

| Code | Name | Penyebab |
|------|------|----------|
| `400` | Bad Request | Input invalid, JSON malformed |
| `401` | Unauthorized | JWT invalid/expired, belum login |
| `403` | Forbidden (42501) | RLS policy violation |
| `404` | Not Found (PGRST116) | Data tidak ada |
| `409` | Conflict (23505) | Duplicate key |
| `422` | Unprocessable Entity (23502) | Field required kosong |
| `500` | Internal Server Error (P0001) | Trigger function error |
| `P0001` | Raise Exception | Trigger raise (misal: max attachments) |

### 14.3. Common Errors & Cara Handle

| Error Message | Cause | Fix |
|--------------|-------|-----|
| `Invalid login credentials` | Email/password salah | Cek input user, atau reset password |
| `JWT expired` | Token kadaluarsa | Auto-refresh pakai refresh_token |
| `new row violates row-level security policy` | RLS deny | Cek apakah user punya akses (admin, owner, dll) |
| `duplicate key value violates unique constraint` | Username sudah ada | Tambah suffix atau pakai username lain |
| `Maximum 3 attachments per comment` | Trigger reject | Hapus attachment lama dulu |
| `null value in column "title"` | Field required kosong | Validasi di client sebelum submit |
| `invalid input value for enum` | Status bukan enum valid | Validasi di client |

---

## Lampiran: Postman Collection Setup

Untuk testing cepat, berikut environment variables Postman yang perlu di-set:

```json
{
  "baseUrl": "https://brkylvdfffjmfaiebgcf.supabase.co",
  "anonKey": "<SUPABASE_ANON_KEY dari .env>",
  "accessToken": "<set setelah login>",
  "refreshToken": "<set setelah login>",
  "currentUserId": "<id_user dari currentUser setelah login>"
}
```

**Helper Pre-request Script (auto-attach header):**
```javascript
pm.request.headers.add({
  key: "apikey",
  value: pm.environment.get("anonKey")
});
pm.request.headers.add({
  key: "Authorization",
  value: "Bearer " + pm.environment.get("accessToken")
});
```

**Test Script (simpan token setelah login):**
```javascript
if (pm.response.code === 200) {
  const json = pm.response.json();
  pm.environment.set("accessToken", json.access_token);
  pm.environment.set("refreshToken", json.refresh_token);
}
```

---

**Dokumen ini bagian dari [rancangan lengkap](./API.md), [flow](./flow.md), dan [ERD](./erd.md).**
