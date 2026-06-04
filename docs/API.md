# API Documentation — UTS Mobile (Supabase Backend)

> **Status:** Final, siap masuk laporan
> **Tanggal:** 2026-06-03
> **Versi:** 3.0
> **Backend Target:** Supabase (Postgres + Auth + Storage)
> **Dokumen Terkait:** [`flow.md`](./flow.md) (rancangan alur), [`erd.md`](./erd.md) (diagram ER)

---

## Changelog

| Versi | Tanggal      | Perubahan                                                                              |
| ----- | ------------ | -------------------------------------------------------------------------------------- |
| 0.1   | 2026-06-03   | Initial draft                                                                         |
| 1.0   | 2026-06-03   | Tambah endpoint log history, notifikasi, pending_unassign                             |
| 3.0   | 2026-06-03   | Final: complete use-case mapping, attachment upload, self-un-assign, edit/cancel/helpdesk workflow |

---

## Daftar Isi

1. [Arsitektur & Prinsip Desain](#1-arsitektur--prinsip-desain)
2. [Autentikasi](#2-autentikasi)
3. [Skema Database](#3-skema-database)
4. [Row Level Security (RLS)](#4-row-level-security-rls--policy-lengkap)
5. [Storage](#5-storage)
6. [REST API Endpoints](#6-rest-api-endpoints-postgrest)
7. [(Future Work) Realtime Subscriptions](#7-future-work-realtime-subscriptions)
8. [Trigger Functions](#8-trigger-functions-postgres)
9. [Use Case → Endpoint Mapping](#9-use-case--endpoint-mapping)
10. [Flutter Repository Layer](#10-flutter-repository-layer-final)
11. [Model Flutter](#11-model-flutter-final-skeleton)
12. [State Management (Riverpod)](#12-state-management-riverpod)
13. [Ringkasan Keputusan Final](#13-ringkasan-keputusan-final)

---

## 1. Arsitektur & Prinsip Desain

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  Flutter Client │ ───> │  Supabase Client │ ───> │  Postgres DB    │
│  (Riverpod)     │ <─── │  (REST)         │ <─── │  (PostgREST)    │
└─────────────────┘      └──────────────────┘      └─────────────────┘
                                  │
                                  ├──> Supabase Auth (JWT)
                                  └──> Storage (foto tiket & comment)
```

**Prinsip desain:**
- Semua data diakses lewat **Supabase PostgREST** (REST API auto-generated dari Postgres)
- Autentikasi via **Supabase Auth** (email + password, JWT)
- Authorization via **Row Level Security (RLS)** di level database
- File foto disimpan di **Supabase Storage**, path disimpan di tabel
- (Future) Realtime via **Postgres Changes channel** untuk update live multi-user
- Pagination **cursor-based** dengan "Load More" UX
- Log history **permanent** (tidak pernah dihapus, audit trail)
- Notifications **dismissable** (user bisa hapus)

---

## 2. Autentikasi

### 2.1. Model

| Field   | Tipe   | Sumber                                       |
| ------- | ------ | -------------------------------------------- |
| `id`    | uuid   | `auth.users.id` (otomatis)                   |
| `email` | string | `auth.users.email`                           |
| `role`  | enum   | `users.role` (`user`/`admin`/`helpdesk`)  |

### 2.2. Endpoint Supabase Auth

| Method | Path                                       | Deskripsi              | Auth |
| ------ | ------------------------------------------ | ---@------------------- | ---- |
| POST   | `/auth/v1/signup`                          | Register user baru     | -    |
| POST   | `/auth/v1/token?grant_type=password`       | Login (email+password) | -    |
| POST   | `/auth/v1/logout`                          | Logout                 | ✅   |
| GET    | `/auth/v1/user`                            | Get current session    | ✅   |
| PUT    | `/auth/v1/user`                            | Update email/password  | ✅   |
| POST   | `/auth/v1/recover`                         | Reset password (email) | -    |

### 2.3. Flutter → Repository

```dart
class AuthRepository {
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, String username);
  Future<void> logout();
  User? getCurrentUser();
  Future<User?> getUser(int idUser);
  Future<void> changePassword(String newPassword);
  Future<void> updateProfile({String? username, String? avatarUrl});
  Future<void> resetPassword(String email);
  Stream<AuthState> get authStateChanges;
}
```

---

## 3. Skema Database

### 3.1. Enum

```sql
create type user_role as enum ('user', 'admin', 'helpdesk');

create type ticket_status as enum (
  'open',
  'assigned',
  'in_progress',
  'pending_unassign',
  'done',
  'cancelled'
);

create type notif_type as enum (
  'ticket_created',
  'ticket_assigned',
  'ticket_reassigned',
  'ticket_unassigned',
  'ticket_unassign_requested',
  'ticket_unassign_approved',
  'ticket_unassign_rejected',
  'ticket_in_progress',
  'ticket_done',
  'ticket_cancelled',
  'ticket_edited',
  'comment_added',
  'helpdesk_availability_changed'
);
```

### 3.2. Tabel `users`

Extend `auth.users`, menyimpan data tambahan. (Sebelumnya bernama `profiles`, di-rename untuk konsistensi domain.)

| Kolom           | Tipe        | Constraint                                                | Keterangan                                |
| --------------- | ----------- | --------------------------------------------------------- | ----------------------------------------- |
| `id_user`       | int         | PK, GENERATED ALWAYS AS IDENTITY                          | Auto-increment                            |
| `auth_user_id`  | uuid        | UNIQUE, FK → `auth.users.id` ON DELETE CASCADE            | UUID dari Supabase Auth, untuk login check |
| `username`      | text        | UNIQUE, NOT NULL                                          | Display name                              |
| `role`          | user_role   | NOT NULL, DEFAULT 'user'                                  | user/admin/helpdesk                       |
| `avatar_url`    | text        | NULL                                                      | Public URL dari Storage                   |
| `created_at`    | timestamptz | DEFAULT now()                                             |                                           |

**Catatan ID:** Supabase Auth mengelola `auth.users.id` sebagai UUID. Tabel `users` kita pakai INT (auto-increment). Bridge antara keduanya adalah kolom `auth_user_id` (UUID). Foreign key dari tabel bisnis merujuk ke `users.id_user` (INT), bukan `auth.users.id`.

**Trigger:** `handle_new_user()` — auto-insert ke `users` saat ada user baru di `auth.users`.

### 3.3. Tabel `helpdesks`

| Kolom           | Tipe        | Constraint                                                | Keterangan              |
| --------------- | ----------- | --------------------------------------------------------- | ----------------------- |
| `id_helpdesk`   | int         | PK, GENERATED ALWAYS AS IDENTITY                          |                         |
| `id_user`       | int         | UNIQUE, FK → `users.id_user` ON DELETE CASCADE            | 1-to-1 dengan users    |
| `name`          | text        | NOT NULL                                                  | Nama lengkap            |
| `phone`         | text        | NULL                                                      | Kontak                  |
| `is_available`  | bool        | NOT NULL, DEFAULT true                                    | Bisa terima assignment  |
| `created_at`    | timestamptz | DEFAULT now()                                             |                         |

> Setiap helpdesk punya entri di `users` (untuk login) dan di `helpdesks` (untuk profil teknisi).

### 3.4. Tabel `tickets`

| Kolom                     | Tipe           | Constraint                                                  | Keterangan                              |
| ------------------------- | -------------- | ----------------------------------------------------------- | --------------------------------------- |
| `id_ticket`               | int            | PK, GENERATED ALWAYS AS IDENTITY                            |                                         |
| `title`                   | text           | NOT NULL                                                    |                                         |
| `description`             | text           | NOT NULL                                                    |                                         |
| `status`                  | ticket_status  | NOT NULL, DEFAULT 'open'                                    |                                         |
| `id_user`                 | int            | FK → `users.id_user` ON DELETE SET NULL                     | Creator (user yang buat)                |
| `id_helpdesk`             | int            | FK → `helpdesks.id_helpdesk` ON DELETE SET NULL             | Helpdesk yang ditugaskan                |
| `photo_path`              | text           | NULL                                                        | Path file di Storage bucket `ticket-photos` |
| `cancelled_reason`        | text           | NULL                                                        | Wajib saat `status = 'cancelled'`       |
| `cancelled_at`            | timestamptz    | NULL                                                        |                                         |
| `unassign_id_helpdesk`    | int            | FK → `helpdesks.id_helpdesk` ON DELETE SET NULL             | Helpdesk yang request un-assign         |
| `unassign_requested_at`   | timestamptz    | NULL                                                        |                                         |
| `unassign_reason`         | text           | NULL                                                        | Alasan dari helpdesk                    |
| `unassign_id_user`        | int            | FK → `users.id_user` ON DELETE SET NULL                     | Admin yang approve/reject               |
| `unassign_decided_at`     | timestamptz    | NULL                                                        |                                         |
| `unassign_reject_reason`  | text           | NULL                                                        | Alasan reject dari admin (opsional)     |
| `started_at`              | timestamptz    | NULL                                                        | Pertama kali helpdesk buka (auto)       |
| `completed_at`            | timestamptz    | NULL                                                        | Saat helpdesk mark as done              |
| `created_at`              | timestamptz    | DEFAULT now()                                               |                                         |
| `updated_at`              | timestamptz    | DEFAULT now()                                               | Auto-update via trigger                 |

**Index:**
- `idx_tickets_status` on `status`
- `idx_tickets_id_user` on `id_user`
- `idx_tickets_id_helpdesk` on `id_helpdesk`
- `idx_tickets_created_at_desc` on `created_at DESC` (untuk cursor pagination)

### 3.5. Tabel `comments`

| Kolom        | Tipe        | Constraint                                                | Keterangan                          |
| ------------ | ----------- | --------------------------------------------------------- | ----------------------------------- |
| `id_comment` | int         | PK, GENERATED ALWAYS AS IDENTITY                          |                                     |
| `id_ticket`  | int         | FK → `tickets.id_ticket` ON DELETE CASCADE, NOT NULL      |                                     |
| `id_user`    | int         | FK → `users.id_user` ON DELETE SET NULL                    | Author                              |
| `message`    | text        | NOT NULL                                                  | Isi komentar (sebelumnya `content`) |
| `is_edited`  | bool        | NOT NULL, DEFAULT false                                   | Indikator "(diedit)"                |
| `created_at` | timestamptz | DEFAULT now()                                             |                                     |
| `updated_at` | timestamptz | DEFAULT now()                                             | Auto-update saat edit               |

**Index:**
- `idx_comments_id_ticket_created_at` on `(id_ticket, created_at ASC)`

### 3.6. Tabel `comment_attachments`

| Kolom                   | Tipe        | Constraint                                                  | Keterangan                |
| ----------------------- | ----------- | ----------------------------------------------------------- | ------------------------- |
| `id_comment_attachment` | int         | PK, GENERATED ALWAYS AS IDENTITY                            |                           |
| `id_comment`            | int         | FK → `comments.id_comment` ON DELETE CASCADE, NOT NULL      |                           |
| `storage_path`          | text        | NOT NULL                                                   | Path di Storage           |
| `mime_type`             | text        | NOT NULL                                                   | image/jpeg atau image/png |
| `file_size`             | int         | NOT NULL                                                   | Bytes, max 5MB            |
| `uploaded_at`           | timestamptz | DEFAULT now()                                              |                           |

**Index:**
- `idx_comment_attachments_id_comment` on `id_comment`

**Constraint:**
- `max 3 attachments per comment` — enforced via trigger `check_max_attachments()`

### 3.7. Tabel `ticket_attachments` (foto utama tiket)

| Kolom                   | Tipe        | Constraint                                                  | Keterangan                |
| ----------------------- | ----------- | ----------------------------------------------------------- | ------------------------- |
| `id_ticket_attachment`  | int         | PK, GENERATED ALWAYS AS IDENTITY                            |                           |
| `id_ticket`             | int         | FK → `tickets.id_ticket` ON DELETE CASCADE, NOT NULL        |                           |
| `storage_path`          | text        | NOT NULL                                                   | Path di Storage           |
| `mime_type`             | text        | NOT NULL                                                   |                           |
| `file_size`             | int         | NOT NULL                                                   |                           |
| `uploaded_at`           | timestamptz | DEFAULT now()                                              |                           |

### 3.8. Tabel `notifications`

| Kolom              | Tipe        | Constraint                                          | Keterangan                          |
| ------------------ | ----------- | --------------------------------------------------- | ----------------------------------- |
| `id_notification`  | int         | PK, GENERATED ALWAYS AS IDENTITY                    |                                     |
| `id_user`          | int         | FK → `users.id_user` ON DELETE CASCADE, NOT NULL    | Penerima notif                      |
| `type`             | notif_type  | NOT NULL                                            |                                     |
| `title`            | text        | NOT NULL                                            | Short title                         |
| `body`             | text        | NOT NULL                                            | Description                         |
| `id_ticket`        | int         | NULL                                                | FK ke ticket terkait (opsional)     |
| `is_read`          | bool        | NOT NULL, DEFAULT false                             |                                     |
| `created_at`       | timestamptz | DEFAULT now()                                       |                                     |

**Index:**
- `idx_notifications_id_user_created_at` on `(id_user, created_at DESC)` (untuk pagination)
- `idx_notifications_id_user_unread` on `(id_user)` WHERE `is_read = false` (partial)

### 3.9. Tabel `ticket_logs`

| Kolom           | Tipe        | Constraint                                            | Keterangan                          |
| --------------- | ----------- | ----------------------------------------------------- | ----------------------------------- |
| `id_ticket_log` | int         | PK, GENERATED ALWAYS AS IDENTITY                      |                                     |
| `id_ticket`     | int         | FK → `tickets.id_ticket` ON DELETE CASCADE, NOT NULL  |                                     |
| `id_user`       | int         | FK → `users.id_user` ON DELETE SET NULL               | Siapa yang melakukan                |
| `actor_role`    | user_role   | NOT NULL                                              | Snapshot role saat event            |
| `event_type`    | text        | NOT NULL                                              | Lihat event list                    |
| `payload`       | jsonb       | NOT NULL                                              | Detail event (before/after, dll)    |
| `created_at`    | timestamptz | DEFAULT now()                                         |                                     |

**Index:**
- `idx_ticket_logs_id_ticket_created_at` on `(id_ticket, created_at DESC)`
- `idx_ticket_logs_id_user` on `id_user`

**Permanent:** tidak boleh di-delete (audit trail).

---

## 4. Row Level Security (RLS) — Policy Lengkap

> Prinsip: default `deny all`, allow via policy. RLS adalah **satunya** satpam data.

### 4.1. `users`

| Policy                              | Operation | Rule                                                                       |
| ----------------------------------- | --------- | -------------------------------------------------------------------------- |
| Viewable by authenticated users     | SELECT    | `auth.role() = 'authenticated'`                                            |
| Update own record                   | UPDATE    | `auth.uid() = auth_user_id`                                                |
| Admin update any user               | UPDATE    | `EXISTS (SELECT 1 FROM users WHERE auth_user_id = auth.uid() AND role = 'admin')` |

### 4.2. `helpdesks`

| Policy                          | Operation | Rule                                                       |
| ------------------------------- | --------- | ---------------------------------------------------------- |
| Viewable by authenticated       | SELECT    | `auth.role() = 'authenticated'`                            |
| Helpdesk update own record      | UPDATE    | `EXISTS (SELECT 1 FROM users WHERE id_user = helpdesks.id_user AND auth_user_id = auth.uid())` |
| Admin manage helpdesks          | ALL       | `EXISTS (SELECT 1 FROM users WHERE auth_user_id = auth.uid() AND role = 'admin')` |

### 4.3. `tickets`

| Policy                                  | Operation | Rule                                                                              |
| --------------------------------------- | --------- | --------------------------------------------------------------------------------- |
| Viewable by authenticated users         | SELECT    | `auth.role() = 'authenticated'`                                                   |
| User create own ticket                  | INSERT    | `EXISTS (SELECT 1 FROM users WHERE id_user = tickets.id_user AND auth_user_id = auth.uid()) AND status = 'open'` |
| User update own open ticket             | UPDATE    | `EXISTS (SELECT 1 FROM users WHERE id_user = tickets.id_user AND auth_user_id = auth.uid()) AND status = 'open'` |
| Helpdesk update assigned ticket         | UPDATE    | `EXISTS (SELECT 1 FROM helpdesks h JOIN users u ON u.id_user = h.id_user WHERE h.id_helpdesk = tickets.id_helpdesk AND u.auth_user_id = auth.uid())` |
| Admin full update                       | UPDATE    | `EXISTS (SELECT 1 FROM users WHERE auth_user_id = auth.uid() AND role = 'admin')` |
| Delete                                  | DELETE    | ❌ Tidak diizinkan                                                                |

### 4.4. `comments`

| Policy                              | Operation | Rule                                                       |
| ----------------------------------- | --------- | ---------------------------------------------------------- |
| Viewable by authenticated           | SELECT    | `auth.role() = 'authenticated'`                            |
| Authenticated add comment           | INSERT    | `EXISTS (SELECT 1 FROM users WHERE id_user = comments.id_user AND auth_user_id = auth.uid())` |
| Author update own comment           | UPDATE    | `EXISTS (SELECT 1 FROM users WHERE id_user = comments.id_user AND auth_user_id = auth.uid())` |
| Author delete own comment           | DELETE    | `EXISTS (SELECT 1 FROM users WHERE id_user = comments.id_user AND auth_user_id = auth.uid())` |
| Admin delete any comment            | DELETE    | ❌ Tidak diizinkan (admin tidak manage comment)             |

### 4.5. `comment_attachments` & `ticket_attachments`

| Policy                              | Operation | Rule                                                       |
| ----------------------------------- | --------- | ---------------------------------------------------------- |
| Viewable by authenticated           | SELECT    | `auth.role() = 'authenticated'`                            |
| Author add attachment               | INSERT    | `EXISTS (SELECT 1 FROM comments c JOIN users u ON u.id_user = c.id_user WHERE c.id_comment = comment_attachments.id_comment AND u.auth_user_id = auth.uid())` |
| Author delete own attachment        | DELETE    | `EXISTS (SELECT 1 FROM comments c JOIN users u ON u.id_user = c.id_user WHERE c.id_comment = comment_attachments.id_comment AND u.auth_user_id = auth.uid())` |

### 4.6. `notifications`

| Policy                              | Operation | Rule                                                       |
| ----------------------------------- | --------- | ---------------------------------------------------------- |
| User view own notifications         | SELECT    | `EXISTS (SELECT 1 FROM users WHERE id_user = notifications.id_user AND auth_user_id = auth.uid())` |
| System insert (via trigger)         | INSERT    | `auth.role() = 'service_role'`                             |
| User mark as read                   | UPDATE    | `EXISTS (SELECT 1 FROM users WHERE id_user = notifications.id_user AND auth_user_id = auth.uid())` |
| User delete own notification        | DELETE    | `EXISTS (SELECT 1 FROM users WHERE id_user = notifications.id_user AND auth_user_id = auth.uid())` |

### 4.7. `ticket_logs`

| Policy                              | Operation | Rule                                                       |
| ----------------------------------- | --------- | ---------------------------------------------------------- |
| Viewable by authenticated           | SELECT    | `auth.role() = 'authenticated'`                            |
| System insert (via trigger)         | INSERT    | `auth.role() = 'service_role' OR auth.uid() IS NOT NULL`  |
| Update                              | UPDATE    | ❌ Tidak diizinkan (permanent)                              |
| Delete                              | DELETE    | ❌ Tidak diizinkan (permanent)                              |

---

## 5. Storage

### 5.1. Bucket: `ticket-photos`

| Konfigurasi | Nilai                                          |
| ----------- | ---------------------------------------------- |
| Public      | ✅ Yes                                         |
| Max size    | 5 MB                                           |
| MIME types  | image/jpeg, image/png                          |
| Path format | `tickets/{id_ticket}/{timestamp}.jpg`          |

### 5.2. Bucket: `comment-attachments`

| Konfigurasi | Nilai                                          |
| ----------- | ---------------------------------------------- |
| Public      | ✅ Yes                                         |
| Max size    | 5 MB per file                                  |
| MIME types  | image/jpeg, image/png                          |
| Max files   | 3 per comment (enforced di app)                |
| Path format | `comments/{id_comment}/{timestamp}-{n}.jpg`    |

### 5.3. Bucket: `avatars`

| Konfigurasi | Nilai                                          |
| ----------- | ---------------------------------------------- |
| Public      | ✅ Yes                                         |
| Max size    | 2 MB                                           |
| MIME types  | image/jpeg, image/png                          |
| Path format | `avatars/{id_user}.jpg`                        |

### 5.4. Storage Policy

| Policy                                       | Operation | Rule                                                       |
| -------------------------------------------- | --------- | ---------------------------------------------------------- |
| Public view all buckets                      | SELECT    | `bucket_id IN ('ticket-photos', 'comment-attachments', 'avatars')` |
| Authenticated upload to ticket-photos        | INSERT    | `bucket_id = 'ticket-photos' AND auth.role() = 'authenticated'` |
| Authenticated upload to comment-attachments  | INSERT    | `bucket_id = 'comment-attachments' AND auth.role() = 'authenticated'` |
| Authenticated upload own avatar              | INSERT    | `bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]` |
| Owner can delete                              | DELETE    | `auth.uid()::text = (storage.foldername(name))[1]`        |

### 5.5. Helper Functions (StorageRepository)

```dart
class StorageRepository {
  // Ticket photo
  Future<String> uploadTicketPhoto(String ticketId, XFile file);
  Future<String> getTicketPhotoUrl(String path);
  Future<void> deleteTicketPhoto(String path);

  // Comment attachment
  Future<String> uploadCommentAttachment(String commentId, XFile file, int index);
  Future<String> getCommentAttachmentUrl(String path);
  Future<void> deleteCommentAttachment(String path);

  // Avatar
  Future<String> uploadAvatar(String userId, XFile file);
  Future<String> getAvatarUrl(String userId);

  // Validation
  Future<bool> validateFileSize(XFile file, {int maxMb = 5});
  Future<bool> validateMimeType(XFile file, {List<String> allowed = const ['image/jpeg', 'image/png']});
}
```

**Storage path convention:**
- Ticket: `tickets/{id_ticket}/{timestamp}.jpg`
- Comment: `comments/{id_comment}/{timestamp}-{n}.jpg`
- Avatar: `avatars/{id_user}.jpg`

---

## 6. REST API Endpoints (PostgREST)

### 6.1. Pagination Convention

Semua endpoint list support cursor-based pagination:

```
GET /rest/v1/{table}?order=created_at.desc&limit=20&created_at=lt.{cursor}
```

**Query params:**
- `limit` (default 20, max 100)
- `created_at=lt.{iso_timestamp}` — cursor
- `order=created_at.desc` — sorting

**Response:** array biasa. Untuk detect "ada lagi", client bandingkan `response.length == limit`.

### 6.2. Auth (via Supabase Client SDK)

| Method | Path                                  | Tujuan            |
| ------ | ------------------------------------- | ----------------- |
| POST   | `/auth/v1/token?grant_type=password`  | Login             |
| POST   | `/auth/v1/signup`                     | Register          |
| POST   | `/auth/v1/logout`                     | Logout            |
| GET    | `/auth/v1/user`                       | Get current user  |
| PUT    | `/auth/v1/user`                       | Update user       |
| POST   | `/auth/v1/recover`                    | Reset password    |

### 6.3. Profiles

| Method | Endpoint                                  | Tujuan                              |
| ------ | ----------------------------------------- | ----------------------------------- |
| GET    | `/rest/v1/users?id=eq.{uuid}`          | Get profile by id                   |
| GET    | `/rest/v1/users?username=eq.{username}`| Get profile by username             |
| GET    | `/rest/v1/users?role=eq.{role}`        | Filter by role (admin dashboard)    |
| PATCH  | `/rest/v1/users?id=eq.{uuid}`          | Update profil sendiri / admin update |

### 6.4. Helpdesks

| Method | Endpoint                                                                              | Tujuan                                          |
| ------ | ------------------------------------------------------------------------------------- | ----------------------------------------------- |
| GET    | `/rest/v1/helpdesks?select=*,profile:profiles(*)&order=name.asc`                      | List semua helpdesk + profile                   |
| GET    | `/rest/v1/helpdesks?is_available=eq.true&select=*,profile:profiles(*)`                | List helpdesk yang tersedia                     |
| GET    | `/rest/v1/helpdesks?is_available=eq.true&select=*,profile:profiles(*)&order=name.asc` | List available (untuk assignment picker)         |
| GET    | `/rest/v1/helpdesks?id=eq.{uuid}&select=*,profile:profiles(*)`                        | Detail helpdesk                                 |
| GET    | `/rest/v1/helpdesks?id=eq.{uuid}&select=*,active_tickets:tickets(count)`              | Detail + count tiket aktif                      |
| PATCH  | `/rest/v1/helpdesks?id=eq.{uuid}`                                                     | Update profile (nama, phone)                    |
| PATCH  | `/rest/v1/helpdesks?id=eq.{uuid}&is_available=...`                                    | Toggle is_available                              |

**Trigger behavior:**
- PATCH `is_available` → log `helpdesk.availability_changed`

### 6.5. Tickets

#### 6.5.1. List & Detail

| Method | Endpoint                                                                              | Tujuan                                       |
| ------ | ------------------------------------------------------------------------------------- | -------------------------------------------- |
| GET    | `/rest/v1/tickets?select=*,id_user,id_helpdesk&order=created_at.desc&limit=20`        | List tiket + relasi (cursor pagination)      |
| GET    | `/rest/v1/tickets?id_user=eq.{id}&order=created_at.desc&limit=20`                     | Tiket milik user tertentu                    |
| GET    | `/rest/v1/tickets?id_helpdesk=eq.{id}&order=created_at.desc&limit=20`                 | Tiket yang di-assign ke helpdesk             |
| GET    | `/rest/v1/tickets?status=eq.{status}`                                                 | Filter by status                             |
| GET    | `/rest/v1/tickets?status=in.(open,assigned,in_progress)`                             | Multiple status (untuk dashboard user)      |
| GET    | `/rest/v1/tickets?id_user=eq.{id}&order=created_at.desc&limit=20&created_at=lt.{cursor}` | List + cursor pagination (user)              |
| GET    | `/rest/v1/tickets?id_ticket=eq.{id}&select=*`                                         | Detail 1 tiket                               |
| GET    | `/rest/v1/tickets?id_ticket=eq.{id}&select=*,comments(*,id_user,comment_attachments(*)),ticket_attachments(*)` | Detail tiket + comments + attachments         |

#### 6.5.2. Create

| Method | Endpoint                              | Body                                                                                              | Tujuan                |
| ------ | ------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------- |
| POST   | `/rest/v1/tickets`                    | `{title, description, id_user, photo_path?}`                                                     | Create tiket (auto: status='open') |
| POST   | `/rest/v1/ticket_attachments`         | `{id_ticket, storage_path, mime_type, file_size}`                                                 | Simpan foto tiket     |

**Trigger:** `POST tickets` → insert log `ticket_created`, insert notif ke semua admin.

#### 6.5.3. Update (User — Edit & Cancel, saat status=open)

| Method | Endpoint                                                              | Body                                                                  | Tujuan                |
| ------ | --------------------------------------------------------------------- | --------------------------------------------------------------------- | --------------------- |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.open`                   | `{title?, description?, photo_path?}`                                 | Edit tiket            |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.open`                   | `{status: 'cancelled', cancelled_reason, cancelled_at: now()}`         | Cancel tiket (wajib alasan) |

#### 6.5.4. Update (Admin — Assign, Un-assign, Re-assign)

| Method | Endpoint                                                                      | Body                                                                              | Tujuan                       |
| ------ | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ---------------------------- |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.open`                           | `{id_helpdesk, status: 'assigned'}`                                               | Assign tiket ke helpdesk     |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`         | `{id_helpdesk: null, status: 'open'}`                                             | Un-assign (kembali ke open)  |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`         | `{id_helpdesk: '{new_id}'}`                                                       | Re-assign (helpdesk ganti)   |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.pending_unassign`               | `{status: 'open', unassign_id_user, unassign_decided_at: now()}`                   | Approve un-assign request    |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.pending_unassign`               | `{status: '{prev_status}', unassign_id_user, unassign_decided_at, unassign_reject_reason}` | Reject un-assign request |

#### 6.5.5. Update (Helpdesk)

| Method | Endpoint                                                                      | Body                                                                                | Tujuan                          |
| ------ | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------- |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&id_helpdesk=eq.{id}&status=eq.assigned`   | `{status: 'in_progress', started_at: now()}`                                        | Auto: in_progress saat buka     |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`         | `{status: 'done', completed_at: now()}`                                              | Mark as done                    |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`         | `{status: 'pending_unassign', unassign_id_helpdesk, unassign_requested_at: now(), unassign_reason}` | Request un-assign (wajib alasan)|

**Trigger behavior (semua PATCH tickets):**
- Status `→ assigned` → notif user & helpdesk, log
- Status `→ in_progress` → set `started_at`, notif user, log
- Status `→ done` → set `completed_at`, notif user & admin, log
- Status `→ cancelled` → set `cancelled_at`, notif admin, log
- Status `→ pending_unassign` → notif admin, log
- Status `pending_unassign → open` → notif helpdesk (approved), log
- Status `pending_unassign → assigned/in_progress` → notif helpdesk (rejected), log
- `id_helpdesk` berubah (re-assign) → notif helpdesk lama + baru + user, log
- Field `title/description` berubah (saat open) → log `ticket.updated`

### 6.6. Comments

| Method | Endpoint                                                                                          | Tujuan                                  |
| ------ | ------------------------------------------------------------------------------------------------- | --------------------------------------- |
| GET    | `/rest/v1/comments?id_ticket=eq.{id}&select=*,id_user,comment_attachments(*)&order=created_at.asc` | List comment per tiket + attachments    |
| GET    | `/rest/v1/comments?id_comment=eq.{id}`                                                            | Detail comment (untuk edit)             |
| POST   | `/rest/v1/comments`                                                                               | Tambah comment                          |
| POST   | `/rest/v1/comment_attachments`                                                                    | Upload attachment (max 3 per comment)   |
| PATCH  | `/rest/v1/comments?id_comment=eq.{id}&id_user=eq.{id_user}`                                       | Edit message (set `is_edited=true`)     |
| DELETE | `/rest/v1/comments?id_comment=eq.{id}&id_user=eq.{id_user}`                                       | Hard delete comment (author only)       |

**Body untuk POST comments:**
```json
{ "id_ticket": "{int}", "id_user": "{int}", "message": "..." }
```

**Trigger behavior:**
- `POST` → insert notif ke user + helpdesk (TIDAK ke admin), log `comment.added`
- `POST comment_attachments` → trigger `check_max_attachments()` reject kalau >= 3
- `PATCH` → set `is_edited=true`, log `comment.edited` dengan before/after
- `DELETE` → log `comment.deleted` dengan snapshot message

### 6.7. Notifications

| Method | Endpoint                                                              | Tujuan                       |
| ------ | --------------------------------------------------------------------- | ---------------------------- |
| GET    | `/rest/v1/notifications?id_user=eq.{id}&order=created_at.desc&limit=20` | List notif user (cursor)     |
| GET    | `/rest/v1/notifications?id_user=eq.{id}&is_read=eq.false`             | Notif belum dibaca           |
| GET    | `/rest/v1/notifications?id_user=eq.{id}&is_read=eq.false&select=id_notification` | List id unread (untuk bulk)  |
| PATCH  | `/rest/v1/notifications?id_notification=eq.{id}&id_user=eq.{id_user}`  | Mark as read (single)        |
| PATCH  | `/rest/v1/notifications?id_notification=in.({ids})&id_user=eq.{id_user}` | Bulk mark as read            |
| PATCH  | `/rest/v1/notifications?id_user=eq.{id}&is_read=eq.false`             | Mark all as read (bulk)      |
| DELETE | `/rest/v1/notifications?id_notification=eq.{id}&id_user=eq.{id_user}` | Dismiss (delete) notif       |

### 6.8. Ticket Logs

| Method | Endpoint                                                                              | Tujuan                                |
| ------ | ------------------------------------------------------------------------------------- | ------------------------------------- |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&order=created_at.desc`                        | Log per tiket (all)                   |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&order=created_at.desc&limit=50&created_at=lt.{cursor}` | Log per tiket + cursor (kalau banyak) |
| GET    | `/rest/v1/ticket_logs?id_user=eq.{id}&order=created_at.desc&limit=20`                 | Log agregat per user                  |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&created_at=gte.{date}`                         | Filter by tanggal (Hari Ini)         |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&created_at=gte.{date-7days}`                  | Filter 7 hari terakhir                |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&event_type=eq.{type}`                         | Filter by event type                  |

**Filter UI mapping:**
- "Hari Ini" → `created_at=gte.{today_start}`
- "7 Hari" → `created_at=gte.{now - 7 days}`
- "Semua" → no filter

---

## 7. (Future Work) Realtime Subscriptions

> **Catatan:** Realtime channel TIDAK dipakai di versi demo 1-device. Detail di laporan.md section "Future Work".

Untuk production multi-user, Supabase Realtime memungkinkan push data dari server ke client via WebSocket. Channel yang akan digunakan:

| Channel                                    | Event                        | Tujuan                                  |
| ------------------------------------------ | ---------------------------- | --------------------------------------- |
| `tickets`                                  | INSERT, UPDATE               | Dashboard update otomatis (semua role) |
| `tickets:id_ticket=eq.{id}`                | UPDATE                       | Detail tiket update real-time           |
| `comments:id_ticket=eq.{id}`               | INSERT, UPDATE, DELETE       | Comment baru/edit/delete real-time     |
| `notifications:id_user=eq.{id}`            | INSERT, UPDATE               | Notifikasi masuk real-time              |
| `ticket_logs:id_ticket=eq.{id}`            | INSERT                       | Log history update real-time            |

Endpoint: `wss://{project-ref}.supabase.co/realtime/v1/websocket`

**Alasan tidak dipakai di demo 1-device:**
- Demo 1 device, user logout-login pindah role → setiap navigasi fetch data fresh
- Realtime baru relevan untuk multi-user di device berbeda yang dipakai bersamaan

---

## 8. Trigger Functions (Postgres)

> Logika bisnis ini di-enforce di level database, **bukan** di Flutter client.

### 8.1. `handle_new_user()`

```sql
create or replace function handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, role)
  values (new.id, new.email, 'user');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();
```

### 8.2. `update_updated_at()`

```sql
create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_tickets_updated_at
  before update on tickets
  for each row execute procedure update_updated_at();

create trigger trg_comments_updated_at
  before update on comments
  for each row execute procedure update_updated_at();
```

### 8.3. `check_max_attachments()`

```sql
create or replace function check_max_attachments()
returns trigger as $$
declare
  attachment_count int;
begin
  select count(*) into attachment_count
  from comment_attachments
  where comment_id = NEW.comment_id;

  if attachment_count >= 3 then
    raise exception 'Maximum 3 attachments per comment';
  end if;

  return NEW;
end;
$$ language plpgsql;

create trigger trg_check_max_attachments
  before insert on comment_attachments
  for each row execute procedure check_max_attachments();
```

### 8.4. `log_ticket_changes()`

```sql
create or replace function log_ticket_changes()
returns trigger as $$
declare
  v_event_type text;
  v_payload jsonb;
  v_actor_role user_role;
begin
  select role into v_actor_role from users where auth_user_id = auth.uid();
  if v_actor_role is null then v_actor_role := 'user'; end if;

  if (TG_OP = 'INSERT') then
    v_event_type := 'ticket.created';
    v_payload := jsonb_build_object('title', NEW.title, 'description', NEW.description);
  elsif (TG_OP = 'UPDATE') then
    if NEW.status != OLD.status then
      v_event_type := 'ticket.status_changed';
      v_payload := jsonb_build_object('from', OLD.status, 'to', NEW.status, 'id_helpdesk', NEW.id_helpdesk);
    elsif NEW.id_helpdesk IS DISTINCT FROM OLD.id_helpdesk then
      v_event_type := case when OLD.id_helpdesk is null then 'ticket.assigned' else 'ticket.reassigned' end;
      v_payload := jsonb_build_object('from', OLD.id_helpdesk, 'to', NEW.id_helpdesk);
    elsif NEW.title IS DISTINCT FROM OLD.title or NEW.description IS DISTINCT FROM OLD.description then
      v_event_type := 'ticket.updated';
      v_payload := jsonb_build_object('before', jsonb_build_object('title', OLD.title, 'description', OLD.description), 'after', jsonb_build_object('title', NEW.title, 'description', NEW.description));
    elsif NEW.cancelled_reason IS DISTINCT FROM OLD.cancelled_reason or (NEW.status = 'cancelled' and OLD.status != 'cancelled') then
      v_event_type := 'ticket.cancelled';
      v_payload := jsonb_build_object('reason', NEW.cancelled_reason, 'cancelled_at', NEW.cancelled_at);
    elsif NEW.unassign_id_helpdesk IS DISTINCT FROM OLD.unassign_id_helpdesk then
      v_event_type := 'ticket.unassign_requested';
      v_payload := jsonb_build_object('requested_by', NEW.unassign_id_helpdesk, 'reason', NEW.unassign_reason);
    elsif NEW.unassign_id_user IS DISTINCT FROM OLD.unassign_id_user then
      v_event_type := case when NEW.status = 'open' then 'ticket.unassign_approved' else 'ticket.unassign_rejected' end;
      v_payload := jsonb_build_object('decided_by', NEW.unassign_id_user, 'reject_reason', NEW.unassign_reject_reason);
    else
      v_event_type := 'ticket.updated';
      v_payload := jsonb_build_object('changes', to_jsonb(NEW) - to_jsonb(OLD));
    end if;
  end if;

  insert into ticket_logs (id_ticket, id_user, actor_role, event_type, payload)
  values (NEW.id_ticket, auth.uid(), v_actor_role, v_event_type, v_payload);

  return NEW;
end;
$$ language plpgsql security definer;

create trigger trg_log_ticket_changes
  after insert or update on tickets
  for each row execute procedure log_ticket_changes();
```

### 8.5. `log_comment_changes()`

```sql
create or replace function log_comment_changes()
returns trigger as $$
declare
  v_actor_role user_role;
begin
  select role into v_actor_role from users where auth_user_id = auth.uid();
  if v_actor_role is null then v_actor_role := 'user'; end if;

  if (TG_OP = 'INSERT') then
    insert into ticket_logs (id_ticket, id_user, actor_role, event_type, payload)
    values (NEW.id_ticket, auth.uid(), v_actor_role, 'comment.added',
            jsonb_build_object('id_comment', NEW.id_comment, 'snippet', left(NEW.message, 100)));
  elsif (TG_OP = 'UPDATE') then
    insert into ticket_logs (id_ticket, id_user, actor_role, event_type, payload)
    values (NEW.id_ticket, auth.uid(), v_actor_role, 'comment.edited',
            jsonb_build_object('id_comment', NEW.id_comment, 'before', OLD.message, 'after', NEW.message));
  elsif (TG_OP = 'DELETE') then
    insert into ticket_logs (id_ticket, id_user, actor_role, event_type, payload)
    values (OLD.id_ticket, auth.uid(), v_actor_role, 'comment.deleted',
            jsonb_build_object('id_comment', OLD.id_comment, 'message', OLD.message));
  end if;

  return coalesce(NEW, OLD);
end;
$$ language plpgsql security definer;

create trigger trg_log_comment_changes
  after insert or update or delete on comments
  for each row execute procedure log_comment_changes();
```

### 8.6. `create_ticket_notifications()`

```sql
create or replace function create_ticket_notifications()
returns trigger as $$
begin
  -- INSERT → notify all admin
  if TG_OP = 'INSERT' then
    insert into notifications (id_user, type, title, body, id_ticket)
    select id_user, 'ticket_created', 'Tiket baru',
           'User membuat tiket baru: ' || NEW.title, NEW.id_ticket
    from users where role = 'admin';
  end if;

  -- Assigned → notify user & helpdesk
  if TG_OP = 'UPDATE' and NEW.status = 'assigned' and OLD.status = 'open' then
    insert into notifications (id_user, type, title, body, id_ticket)
    values (NEW.id_user, 'ticket_assigned', 'Tiket di-assign',
            'Tiket Anda telah ditugaskan ke helpdesk.', NEW.id_ticket);
    insert into notifications (id_user, type, title, body, id_ticket)
    values ((select id_user from helpdesks where id_helpdesk = NEW.id_helpdesk),
            'ticket_assigned', 'Tiket baru ditugaskan',
            'Admin menugaskan tiket kepada Anda.', NEW.id_ticket);
  end if;

  -- Reassigned → notify old helpdesk, new helpdesk, user
  if TG_OP = 'UPDATE' and NEW.id_helpdesk IS DISTINCT FROM OLD.id_helpdesk
     and NEW.status in ('assigned', 'in_progress') and OLD.id_helpdesk is not null then
    if OLD.id_helpdesk is not null then
      insert into notifications (id_user, type, title, body, id_ticket)
      values ((select id_user from helpdesks where id_helpdesk = OLD.id_helpdesk),
              'ticket_unassigned', 'Tiket dilepas',
              'Tiket dilepas dari Anda.', NEW.id_ticket);
    end if;
    insert into notifications (id_user, type, title, body, id_ticket)
    values ((select id_user from helpdesks where id_helpdesk = NEW.id_helpdesk),
            'ticket_assigned', 'Tiket ditugaskan ke Anda',
            'Admin menugaskan tiket kepada Anda.', NEW.id_ticket);
  end if;

  -- In progress → notify user
  if TG_OP = 'UPDATE' and NEW.status = 'in_progress' and OLD.status = 'assigned' then
    insert into notifications (id_user, type, title, body, id_ticket)
    values (NEW.id_user, 'ticket_in_progress', 'Tiket sedang dikerjakan',
            'Helpdesk mulai mengerjakan tiket Anda.', NEW.id_ticket);
  end if;

  -- Done → notify user & all admin
  if TG_OP = 'UPDATE' and NEW.status = 'done' and OLD.status != 'done' then
    insert into notifications (id_user, type, title, body, id_ticket)
    values (NEW.id_user, 'ticket_done', 'Tiket selesai',
            'Tiket Anda telah selesai.', NEW.id_ticket);
    insert into notifications (id_user, type, title, body, id_ticket)
    select id_user, 'ticket_done', 'Tiket selesai',
           'Helpdesk menyelesaikan tiket.', NEW.id_ticket
    from users where role = 'admin';
  end if;

  -- Cancelled → notify all admin
  if TG_OP = 'UPDATE' and NEW.status = 'cancelled' and OLD.status != 'cancelled' then
    insert into notifications (id_user, type, title, body, id_ticket)
    select id_user, 'ticket_cancelled', 'Tiket dibatalkan',
           'User membatalkan tiket. Alasan: ' || coalesce(NEW.cancelled_reason, '-'),
           NEW.id_ticket
    from users where role = 'admin';
  end if;

  -- Pending unassign → notify all admin
  if TG_OP = 'UPDATE' and NEW.status = 'pending_unassign' and OLD.status in ('assigned', 'in_progress') then
    insert into notifications (id_user, type, title, body, id_ticket)
    select id_user, 'ticket_unassign_requested', 'Request un-assign',
           'Helpdesk request un-assign. Alasan: ' || coalesce(NEW.unassign_reason, '-'),
           NEW.id_ticket
    from users where role = 'admin';
  end if;

  -- Unassign approved → notify helpdesk
  if TG_OP = 'UPDATE' and NEW.status = 'open' and OLD.status = 'pending_unassign' and NEW.unassign_id_user is not null then
    insert into notifications (id_user, type, title, body, id_ticket)
    values ((select id_user from helpdesks where id_helpdesk = NEW.unassign_id_helpdesk),
            'ticket_unassign_approved', 'Un-assign disetujui',
            'Admin menyetujui request un-assign Anda.', NEW.id_ticket);
  end if;

  -- Unassign rejected → notify helpdesk
  if TG_OP = 'UPDATE' and NEW.status in ('assigned', 'in_progress') and OLD.status = 'pending_unassign' and NEW.unassign_reject_reason is not null then
    insert into notifications (id_user, type, title, body, id_ticket)
    values ((select id_user from helpdesks where id_helpdesk = NEW.unassign_id_helpdesk),
            'ticket_unassign_rejected', 'Un-assign ditolak',
            'Admin menolak request un-assign Anda.', NEW.id_ticket);
  end if;

  return NEW;
end;
$$ language plpgsql security definer;

create trigger trg_create_ticket_notifications
  after insert or update on tickets
  for each row execute procedure create_ticket_notifications();
```

### 8.7. `create_comment_notifications()`

```sql
create or replace function create_comment_notifications()
returns trigger as $$
begin
  insert into notifications (id_user, type, title, body, id_ticket)
  select distinct u.id_user, 'comment_added', 'Komentar baru',
         left(NEW.message, 100), NEW.id_ticket
  from tickets t
  cross join users u
  where t.id_ticket = NEW.id_ticket
    and u.id_user != NEW.id_user
    and u.role != 'admin'  -- admin TIDAK dapat notif dari comment
    and (
      u.id_user = t.id_user
      or u.id_user = (select id_user from helpdesks where id_helpdesk = t.id_helpdesk)
    );

  return NEW;
end;
$$ language plpgsql security definer;

create trigger trg_create_comment_notifications
  after insert on comments
  for each row execute procedure create_comment_notifications();
```

---

## 9. Use Case → Endpoint Mapping

> Tabel ini memetakan **setiap aksi di flow** ke **endpoint/repository method** yang dipakai. Bisa langsung disalin ke laporan.

### 9.1. Auth Flow

| Aksi UI                            | Endpoint / Method                                                |
| ---------------------------------- | ---------------------------------------------------------------- |
| Splash auto-check session          | `auth.getCurrentUser()`                                          |
| Login                              | `auth.signInWithPassword(email, password)`                       |
| Register                           | `auth.signUp(email, password, {data: {username}})`              |
| Logout                             | `auth.signOut()`                                                 |
| Reset password                     | `auth.resetPasswordForEmail(email)`                              |
| Change password (di profile)       | `auth.updateUser(password: newPassword)`                         |
| Update user (avatar, username)     | `PATCH /rest/v1/users?id_user=eq.{id}`                           |

### 9.2. User Flow

| Aksi UI                                | Endpoint / Method                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Lihat daftar tiket saya                | `GET /rest/v1/tickets?id_user=eq.{id}&order=created_at.desc&limit=20`                                  |
| Filter tiket by status                 | `GET /rest/v1/tickets?id_user=eq.{id}&status=eq.{status}`                                                |
| Lihat detail tiket                     | `GET /rest/v1/tickets?id_ticket=eq.{id}&select=*,comments(*,id_user,comment_attachments(*)),ticket_attachments(*)` |
| Buat tiket                             | `POST /rest/v1/tickets` + (opsional) `POST /rest/v1/ticket_attachments` + `uploadTicketPhoto()`        |
| Edit tiket (status=open)               | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=eq.open` dengan `{title?, description?, photo_path?}`  |
| Cancel tiket (status=open)             | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=eq.open` dengan `{status: 'cancelled', cancelled_reason, cancelled_at}` |
| Kirim comment                          | `POST /rest/v1/comments` + (opsional) `POST /rest/v1/comment_attachments` + `uploadCommentAttachment()` |
| Edit comment sendiri                   | `PATCH /rest/v1/comments?id_comment=eq.{id}&id_user=eq.{id_user}` dengan `{message, is_edited: true}`     |
| Hapus comment sendiri                  | `DELETE /rest/v1/comments?id_comment=eq.{id}&id_user=eq.{id_user}`                                       |
| Toggle is_available (helpdesk)         | `PATCH /rest/v1/helpdesks?id_helpdesk=eq.{id}` dengan `{is_available: bool}`                            |
| Lihat statistik user                   | `GET /rest/v1/tickets?id_user=eq.{id}&select=*` lalu hitung client-side                                |
| Lihat notifikasi                       | `GET /rest/v1/notifications?id_user=eq.{id}&order=created_at.desc&limit=20`                            |
| Mark notif as read                     | `PATCH /rest/v1/notifications?id_notification=eq.{id}&id_user=eq.{id_user}`                              |
| Mark all as read                       | `PATCH /rest/v1/notifications?id_user=eq.{id}&is_read=eq.false` (bulk update)                          |
| Dismiss notif                          | `DELETE /rest/v1/notifications?id_notification=eq.{id}&id_user=eq.{id_user}`                            |
| Lihat log history (agregat per user)   | `GET /rest/v1/ticket_logs?id_user=eq.{id}&order=created_at.desc&limit=20`                              |
| Lihat log history per tiket            | `GET /rest/v1/ticket_logs?id_ticket=eq.{id}&order=created_at.desc`                                      |

### 9.3. Admin Flow

| Aksi UI                                | Endpoint / Method                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Lihat semua tiket                      | `GET /rest/v1/tickets?order=created_at.desc&limit=20`                                                    |
| Filter tiket by status                 | `GET /rest/v1/tickets?status=eq.{status}`                                                                |
| Filter tiket by helpdesk               | `GET /rest/v1/tickets?id_helpdesk=eq.{id}`                                                               |
| Lihat statistik admin                  | `GET /rest/v1/tickets?select=*` lalu factory `TicketStats.fromAllTickets`                               |
| Lihat workload per helpdesk            | `GET /rest/v1/helpdesks?select=*,id_user,active_tickets:tickets(count)`                                 |
| Lihat list helpdesk available          | `GET /rest/v1/helpdesks?is_available=eq.true&select=*,id_user`                                          |
| Assign tiket (open → assigned)        | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=eq.open` dengan `{id_helpdesk, status: 'assigned'}`    |
| Un-assign tiket (kembali ke open)      | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)` dengan `{id_helpdesk: null, status: 'open'}` |
| Re-assign tiket (ganti helpdesk)       | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)` dengan `{id_helpdesk: '{new_id}'}` |
| Approve un-assign request              | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=eq.pending_unassign` dengan `{status: 'open', unassign_id_user, unassign_decided_at}` |
| Reject un-assign request               | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=eq.pending_unassign` dengan `{status: '{prev}', unassign_id_user, unassign_decided_at, unassign_reject_reason}` |
| Kirim comment (admin nimbrung)         | Sama seperti user — `POST /rest/v1/comments`                                                            |
| Toggle theme                           | `SharedPreferences` (existing, sudah persist)                                                          |

### 9.4. Helpdesk Flow

| Aksi UI                                | Endpoint / Method                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Lihat tiket assigned ke saya           | `GET /rest/v1/tickets?id_helpdesk=eq.{id}&order=created_at.desc&limit=20`                               |
| Buka tiket → auto in_progress         | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&id_helpdesk=eq.{helpdesk_id}&status=eq.assigned` dengan `{status: 'in_progress', started_at: now()}` |
| Mark as done                           | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)` dengan `{status: 'done', completed_at: now()}` |
| Request un-assign (dengan alasan)     | `PATCH /rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)` dengan `{status: 'pending_unassign', unassign_id_helpdesk, unassign_requested_at, unassign_reason}` |
| Toggle is_available                    | `PATCH /rest/v1/helpdesks?id_helpdesk=eq.{id}` dengan `{is_available: bool}`                            |
| Kirim comment                          | Sama seperti user — `POST /rest/v1/comments`                                                            |
| Edit/hapus comment sendiri             | Sama seperti user                                                                                      |
| Lihat statistik helpdesk               | `GET /rest/v1/tickets?id_helpdesk=eq.{id}&select=*` lalu hitung client-side                             |

### 9.5. Cross-cutting

| Aksi UI                                | Endpoint / Method                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Refresh data (pull-to-refresh / navigasi) | Re-fetch via `ref.invalidate(provider)` (Riverpod)                                                |
| Upload foto tiket                      | `StorageRepository.uploadTicketPhoto(idTicket, file)` → path disimpan di `tickets.photo_path`           |
| Upload foto avatar                     | `StorageRepository.uploadAvatar(idUser, file)` → URL disimpan di `users.avatar_url`                    |

---

## 10. Flutter Repository Layer (Final)

### 10.1. `AuthRepository`

```dart
class AuthRepository {
  final _supabase = Supabase.instance.client;

  // Login & register
  Future<AuthResponse> login(String email, String password);
  Future<AuthResponse> register(String email, String password, String username);
  Future<void> logout();

  // Session
  User? getCurrentUser();
  Stream<AuthState> get authStateChanges;

  // User lookup
  Future<User?> getUser(int idUser);
  Future<User?> getUserByAuthId(String authUserId);

  // Update
  Future<void> changePassword(String newPassword);
  Future<void> updateUser({String? username, String? avatarUrl});
  Future<void> resetPassword(String email);
}
```

### 10.2. `TicketRepository`

```dart
class TicketRepository {
  final _supabase = Supabase.instance.client;

  // ===== List =====
  Future<List<Ticket>> getTickets({int limit = 20, DateTime? cursor});
  Future<List<Ticket>> getTicketsByUser(int idUser, {int limit = 20, DateTime? cursor});
  Future<List<Ticket>> getTicketsByHelpdesk(int idHelpdesk, {int limit = 20, DateTime? cursor});
  Future<List<Ticket>> getTicketsByStatus(TicketStatus status, {int limit = 20, DateTime? cursor});

  // ===== Detail =====
  Future<Ticket?> getTicketById(int idTicket);

  // ===== Create =====
  Future<Ticket> createTicket({
    required String title,
    required String description,
    required int idUser,
    XFile? photo,
  });

  // ===== User Actions (saat status=open) =====
  Future<Ticket> updateTicket(int idTicket, {String? title, String? description, XFile? photo});
  Future<Ticket> cancelTicket(int idTicket, required String reason);

  // ===== Admin Actions =====
  Future<Ticket> assignToHelpdesk(int idTicket, int idHelpdesk);
  Future<Ticket> unassignTicket(int idTicket);
  Future<Ticket> reassignTicket(int idTicket, int newIdHelpdesk);
  Future<Ticket> approveUnassign(int idTicket);
  Future<Ticket> rejectUnassign(int idTicket, {String? reason});

  // ===== Helpdesk Actions =====
  Future<Ticket> startProgress(int idTicket);
  Future<Ticket> markAsDone(int idTicket);
  Future<Ticket> requestUnassign(int idTicket, required String reason);

  // ===== Stats =====
  Future<TicketStats> getStats({required UserRole role, required int idUser});
}
```

### 10.3. `CommentRepository`

```dart
class CommentRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Comment>> getComments(int idTicket);
  Future<Comment> addComment({
    required int idTicket,
    required int idUser,
    required String message,
    List<XFile> attachments = const [],
  });
  Future<Comment> editComment(int idComment, String newMessage);
  Future<void> deleteComment(int idComment);

  Stream<List<Comment>> watchComments(int idTicket);
}
```

### 10.4. `HelpdeskRepository`

```dart
class HelpdeskRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Helpdesk>> getHelpdesks({bool? onlyAvailable});
  Future<Helpdesk?> getHelpdeskById(int idHelpdesk);
  Future<Helpdesk?> getHelpdeskByUserId(int idUser);
  Future<Helpdesk> updateAvailability(int idHelpdesk, bool isAvailable);

  Stream<List<Helpdesk>> watchHelpdesks();
}
```

### 10.5. `NotificationRepository`

```dart
class NotificationRepository {
  final _supabase = Supabase.instance.client;

  Future<List<AppNotification>> getNotifications({
    int limit = 20,
    DateTime? cursor,
    bool? unreadOnly,
  });
  Future<int> getUnreadCount(int idUser);
  Future<void> markAsRead(int idNotification);
  Future<void> markAllAsRead(int idUser);
  Future<void> markManyAsRead(List<int> ids, int idUser);
  Future<void> dismiss(int idNotification);
}
```

### 10.6. `LogRepository`

```dart
class LogRepository {
  final _supabase = Supabase.instance.client;

  Future<List<TicketLog>> getLogsForTicket(int idTicket);
  Future<List<TicketLog>> getLogsForUser(int idUser, {int limit = 20, DateTime? cursor});
  Future<List<TicketLog>> getLogsByFilter({
    required int idTicket,
    DateTime? fromDate,
    DateTime? toDate,
  });
}
```

### 10.7. `StorageRepository`

```dart
class StorageRepository {
  final _supabase = Supabase.instance.client;

  // Ticket photo
  Future<String> uploadTicketPhoto(int idTicket, XFile file);
  Future<String> getTicketPhotoUrl(String path);
  Future<void> deleteTicketPhoto(String path);

  // Comment attachment
  Future<String> uploadCommentAttachment(int idComment, XFile file, int index);
  Future<String> getCommentAttachmentUrl(String path);
  Future<void> deleteCommentAttachment(String path);

  // Avatar
  Future<String> uploadAvatar(int idUser, XFile file);
  Future<String> getAvatarUrl(int idUser);

  // Validation
  Future<bool> validateFileSize(XFile file, {int maxMb = 5});
  Future<bool> validateMimeType(XFile file, {List<String> allowed = const ['image/jpeg', 'image/png']});
}
```

### 10.8. `UserRepository`

```dart
class UserRepository {
  final _supabase = Supabase.instance.client;

  Future<User?> getUser(int idUser);
  Future<User?> getUserByUsername(String username);
  Future<List<User>> getUsersByRole(UserRole role);
  Future<User> updateUser(int idUser, {String? username, String? avatarUrl});
}
```

---

## 11. Model Flutter (Final Skeleton)

### 11.1. `User` (tabel `users`)

```dart
enum UserRole { user, admin, helpdesk }

class User {
  final int idUser;              // maps to id_user
  final String authUserId;       // UUID dari Supabase Auth
  final String username;
  final String email;
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;

  factory User.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
}
```

### 11.2. `Ticket`

```dart
enum TicketStatus {
  open,
  assigned,
  inProgress,
  pendingUnassign,
  done,
  cancelled,
}

class Ticket {
  final int idTicket;                       // maps to id_ticket
  final String title;
  final String description;
  final TicketStatus status;
  final int idUser;                          // maps to id_user (creator)
  final int? idHelpdesk;                     // maps to id_helpdesk
  final String? photoPath;
  final String? cancelledReason;
  final DateTime? cancelledAt;
  final int? unassignIdHelpdesk;             // helpdesk yang request
  final String? unassignReason;
  final DateTime? unassignDecidedAt;
  final String? unassignRejectReason;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Ticket.fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap();
  Ticket copyWith({...});
}
```

### 11.3. `Comment`

```dart
class Comment {
  final int idComment;                       // maps to id_comment
  final int idTicket;                        // maps to id_ticket
  final int idUser;                          // maps to id_user (author)
  final String message;                      // was 'content' in v2
  final bool isEdited;
  final List<CommentAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Comment.fromMap(Map<String, dynamic> map);
}

class CommentAttachment {
  final int idCommentAttachment;             // maps to id_comment_attachment
  final int idComment;                       // maps to id_comment
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final DateTime uploadedAt;

  factory CommentAttachment.fromMap(Map<String, dynamic> map);
}
```

### 11.4. `Helpdesk`

```dart
class Helpdesk {
  final int idHelpdesk;                      // maps to id_helpdesk
  final int idUser;                          // maps to id_user (1-to-1)
  final String name;
  final String? phone;
  final bool isAvailable;
  final User? user;                          // renamed from Profile
  final int? activeTicketCount;              // untuk assignment picker

  factory Helpdesk.fromMap(Map<String, dynamic> map);
}
```

### 11.5. `AppNotification`

```dart
enum NotificationType {
  ticketCreated,
  ticketAssigned,
  ticketReassigned,
  ticketUnassigned,
  ticketUnassignRequested,
  ticketUnassignApproved,
  ticketUnassignRejected,
  ticketInProgress,
  ticketDone,
  ticketCancelled,
  ticketEdited,
  commentAdded,
  helpdeskAvailabilityChanged,
}

class AppNotification {
  final int idNotification;                  // maps to id_notification
  final int idUser;                          // maps to id_user (recipient)
  final NotificationType type;
  final String title;
  final String body;
  final int? idTicket;                       // maps to id_ticket (related)
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromMap(Map<String, dynamic> map);
}
```

### 11.6. `TicketLog`

```dart
class TicketLog {
  final int idTicketLog;                     // maps to id_ticket_log
  final int idTicket;                        // maps to id_ticket
  final int? idUser;                         // maps to id_user (actor)
  final UserRole actorRole;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory TicketLog.fromMap(Map<String, dynamic> map);
}
```

### 11.7. `TicketStats`

```dart
class TicketStats {
  final int totalTickets;
  final int openTickets;
  final int assignedTickets;
  final int inProgressTickets;
  final int pendingUnassignTickets;
  final int doneTickets;
  final int cancelledTickets;
  final int activeTickets;
  final int completedTickets;

  TicketStats({...});

  // Untuk user
  factory TicketStats.fromUserTickets(List<Ticket> tickets);

  // Untuk admin
  factory TicketStats.fromAllTickets(List<Ticket> tickets);

  // Untuk helpdesk
  factory TicketStats.fromHelpdeskTickets(List<Ticket> tickets);
}
```

---

## 12. State Management (Riverpod)

| Provider                          | Tipe                          | Sumber                          |
| --------------------------------- | ----------------------------- | ------------------------------- |
| `authRepositoryProvider`          | `Provider`                    | Instance                        |
| `currentUserProvider`             | `StateProvider<User?>`        | Dari `supabase.auth`            |
| `ticketsListProvider`             | `StateNotifierProvider`       | Get all tickets                 |
| `userTicketsProvider`             | `FutureProvider.family`       | By id_user                      |
| `helpdeskTicketsProvider`         | `FutureProvider.family`       | By id_helpdesk                  |
| `ticketDetailProvider`            | `FutureProvider.family`       | By id_ticket                    |
| `commentsProvider`                | `FutureProvider.family`       | Per tiket                       |
| `notificationsProvider`           | `StateNotifierProvider`       | By id_user                      |
| `logsProvider`                    | `FutureProvider.family`       | Per tiket / per user            |
| `helpdesksProvider`               | `FutureProvider`              | All helpdesks                   |
| `dashboardStatsProvider`          | `FutureProvider.family`       | Per role                        |
| `themeModeProvider`               | `StateNotifierProvider<bool>` | SharedPreferences               |
| `notificationsEnabledProvider`    | `StateNotifierProvider<bool>` | SharedPreferences               |
| `soundEnabledProvider`            | `StateNotifierProvider<bool>` | SharedPreferences               |

> **Catatan:** Tidak ada realtime subscription. Data di-refresh via:
> - `ref.invalidate(provider)` setelah action (create/update/delete)
> - `ref.refresh(provider)` (manual)
> - Re-fetch otomatis saat widget build (kalau pakai `FutureProvider`)
> - Pull-to-refresh di UI
| `languageProvider`                | `StateNotifierProvider<String>` | SharedPreferences              | -         |

---

## 13. Ringkasan Keputusan Final

| # | Topik                     | Keputusan                                                       |
| - | ------------------------- | --------------------------------------------------------------- |
| 1 | Login                     | Semua role pakai Supabase Auth (email)                          |
| 2 | Re-assign                 | Admin boleh, di `assigned` atau `in_progress`                   |
| 3 | Un-assign                 | Admin boleh, kondisi bebas, kembali ke `open`                   |
| 4 | Self-un-assign            | Helpdesk boleh, dengan alasan, tunggu approval admin            |
| 5 | Edit comment              | Author only, unlimited window, label "(diedit)"                 |
| 6 | Hapus comment             | Author only (admin tidak boleh), hard delete                    |
| 7 | Admin manage comment      | Tidak bisa, hanya nimbrung                                     |
| 8 | Notif ke admin dari comment | ❌ Tidak ada                                                   |
| 9 | Max foto per comment      | 3 foto, 5 MB per foto                                          |
| 10| Pagination                | Cursor-based, "Load More" button, default 20                    |
| 11| Pagination comments       | Tampilkan semua per tiket (no pagination)                      |
| 12| Log history per tiket     | Tampilkan semua, filter Hari Ini / 7 Hari / Semua              |
| 13| Hard delete tiket         | ❌ Tidak ada, hanya cancel oleh user                            |
| 14| Hapus akun                | ❌ Tidak ada untuk saat ini                                    |
| 15| `is_available` helpdesk  | Toggle di profil helpdesk sendiri                              |
| 16| `cancelled_reason`        | ✅ Wajib diisi, min 5 karakter                                 |
| 17| `unassign_reason`         | ✅ Wajib diisi saat helpdesk request                           |
| 18| Re-assign trigger notif   | Helpdesk lama dapat "tiket dilepas", baru dapat "ditugaskan"   |
| 19| Log history permanent     | Tidak bisa di-update atau di-delete                            |
| 20| Storage path              | `tickets/{id}/{ts}.jpg`, `comments/{id}/{ts}-{n}.jpg`, `avatars/{userId}.jpg` |

---

**Dokumen ini bagian dari [rancangan lengkap](./flow.md) dan [diagram ER](./erd.md).**
