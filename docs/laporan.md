# Laporan Dokumentasi API — UTS Mobile

> **Project:** UTS Mobile (E-Ticketing Helpdesk)
> **Backend Target:** Supabase (Postgres + Auth + Storage)
> **Tanggal:** 2026-06-03
> **Versi:** 3.0
> **Dokumen Terkait:** [`flow.md`](./flow.md), [`API.md`](./API.md), [`erd.md`](./erd.md), [`env.md`](./env.md)

---

## Daftar Isi

1. [Overview](#1-overview)
2. [Arsitektur Sistem](#2-arsitektur-sistem)
3. [Base URL](#3-base-url)
4. [Authentication](#4-authentication)
5. [Data Model](#5-data-model)
6. [Endpoint List](#6-endpoint-list)
7. [Business Flow](#7-business-flow)
8. [ERD Mapping](#8-erd-mapping)

---

## 1. Overview

### 1.1. Deskripsi Project

**UTS Mobile** adalah aplikasi helpdesk berbasis mobile (Flutter) yang digunakan untuk mengelola tiket gangguan internal. Aplikasi ini menghubungkan 3 role pengguna yang saling berkolaborasi:

- **User** — membuat request tiket gangguan
- **Admin** — menerima tiket, menugaskan helpdesk
- **Helpdesk** — mengerjakan tiket, konfirmasi selesai

Project ini menggunakan **Supabase** sebagai Backend-as-a-Service (BaaS) yang menyediakan:

- **Postgres Database** — penyimpanan data terstruktur
- **Supabase Auth** — autentikasi berbasis JWT (email + password)
- **Storage** — penyimpanan file (foto tiket, attachment comment, avatar)
- **PostgREST** — REST API auto-generated dari schema database

> **Catatan:** Realtime channel (websocket push) tidak dipakai di versi demo 1-device. Untuk production multi-user, lihat section "Future Work".

### 1.2. Tujuan Pendokumentasian API

Dokumentasi ini disusun dengan tujuan:

1. **Sebagai rancangan API definitif** — menjadi acuan saat implementasi integrasi ke Supabase
2. **Kontrak antara frontend dan backend** — menghindari inkonsistensi data yang dikirim/diterima
3. **Panduan pengembangan kolaboratif** — memudahkan developer lain memahami struktur dan alur data
4. **Referensi testing** — acuan untuk pengujian endpoint satu per satu
5. **Dokumentasi akademis** — memenuhi tugas akhir dengan dokumentasi yang terstruktur dan mudah dipahami

### 1.3. Scope Project

- **Platform:** Flutter (Android/iOS)
- **Backend:** Supabase
- **Database:** Postgres
- **3 Role:** user, admin, helpdesk
- **6 Status Tiket:** open, assigned, in_progress, pending_unassign, done, cancelled
- **Auto-trigger:** notifikasi & log history via Postgres triggers

### 1.4. Konvensi Penamaan

Project ini menggunakan konvensi penamaan **konsisten** untuk semua atribut dan tabel:

#### 1.4.1. Tabel

| Tabel                    | Fungsi                                          |
| ------------------------ | ----------------------------------------------- |
| `users`                  | Extend `auth.users` (sebelumnya bernama `profiles`) |
| `helpdesks`              | Profil teknisi                                  |
| `tickets`                | Tiket gangguan                                  |
| `comments`               | Komentar 3-arah di tiket                        |
| `ticket_attachments`     | Foto utama tiket                                |
| `comment_attachments`    | Foto attachment di komentar (max 3)             |
| `notifications`          | Notifikasi per user                             |
| `ticket_logs`            | Audit trail permanent                           |

> **Catatan:** Tabel `users` (bukan `profiles`) untuk konsistensi dengan domain project. Supabase Auth tetap mengelola `auth.users` (managed) — tabel `users` kita adalah layer bisnis di atasnya.

#### 1.4.2. Primary Key (PK)

Format: `id_{nama_tabel_singular}`

| Tabel                  | PK                |
| ---------------------- | ----------------- |
| `users`                | `id_user`         |
| `helpdesks`            | `id_helpdesk`     |
| `tickets`              | `id_ticket`       |
| `comments`             | `id_comment`      |
| `ticket_attachments`   | `id_ticket_attachment` |
| `comment_attachments`  | `id_comment_attachment` |
| `notifications`        | `id_notification` |
| `ticket_logs`          | `id_ticket_log`   |

#### 1.4.3. Foreign Key (FK)

Format: `id_{tabel_referensi_singular}` (sama dengan PK, context-aware)

| FK di tabel       | Merujuk ke            | Nama field       |
| ----------------- | --------------------- | ---------------- |
| `tickets`         | `users`               | `id_user` (creator)  |
| `tickets`         | `helpdesks`           | `id_helpdesk`        |
| `tickets`         | `helpdesks`           | `id_helpdesk` (unassign_requested_by) |
| `tickets`         | `users`               | `id_user` (unassign_decided_by)  |
| `comments`        | `tickets`             | `id_ticket`          |
| `comments`        | `users`               | `id_user` (author)   |
| `ticket_attachments` | `tickets`          | `id_ticket`          |
| `comment_attachments`| `comments`          | `id_comment`         |
| `notifications`   | `users`               | `id_user`            |
| `ticket_logs`     | `tickets`             | `id_ticket`          |
| `ticket_logs`     | `users`               | `id_user` (actor)    |

> **Catatan:** Karena `users` punya 2 FK ke tabel lain (`created_by` di tickets dan `actor` di ticket_logs), kita pakai `id_user` di kedua tempat. **Bukan** `id_creator` / `id_actor` — context keliatan dari tabel.

#### 1.4.4. Penamaan Lainnya

| Aturan                          | Contoh                                          |
| ------------------------------- | ----------------------------------------------- |
| Field timestamp: `created_at`, `updated_at`, `cancelled_at`, dll | Pascal-style snake_case |
| Field enum: status pakai langsung `status`      | `tickets.status`, `users.role`                  |
| Field message: ganti `content` jadi `message` di tabel `comments` | `comments.message` |
| Boolean prefix: `is_*` atau `has_*`            | `is_available`, `is_read`, `is_edited`          |

### 1.5. Tipe Data & Justifikasi

| Tipe Postgres | Tipe Dart            | Dipakai untuk                       | Justifikasi                                                          |
| ------------- | -------------------- | ----------------------------------- | -------------------------------------------------------------------- |
| `INT`         | `int`                | Primary key, foreign key, file_size | ✅ Sederhana, auto-increment, mudah debug. Cocok skala tugas akhir. |
| `TEXT`        | `String`             | Username, title, message, reason   | ✅ Performa sama VARCHAR di Postgres, fleksibel                      |
| `BOOLEAN`     | `bool`               | is_available, is_read, is_edited    | ✅ Type-safe                                                         |
| `TIMESTAMPTZ` | `DateTime`           | created_at, completed_at, dll       | ✅ Konsistensi timezone (UTC di DB)                                  |
| `ENUM`        | `enum` Dart          | status, role, notif_type            | ✅ Type safety, daftar nilai terbatas jelas                          |
| `JSONB`       | `Map<String, dynamic>` | payload di ticket_logs            | ✅ Fleksibel, queryable, indexable                                   |
| `UUID`        | `String`             | `users.auth_user_id` saja          | Bridge ke Supabase Auth yang pakai UUID                              |

**Catatan:** Primary key tabel bisnis menggunakan `INT` (auto-increment via `GENERATED ALWAYS AS IDENTITY`), bukan `UUID`, untuk mempermudah development di skala tugas akhir. UUID hanya dipakai di kolom `users.auth_user_id` untuk sinkronisasi dengan Supabase Auth.

---

## 2. Arsitektur Sistem

### 2.1. Arsitektur Umum (Termasuk Auth)

```
┌────────────────────────────────────────────────────────────────────┐
│                          FLUTTER CLIENT                             │
│                                                                      │
│  ┌──────────┐ ┌───────────┐ ┌─────────┐ ┌──────────┐                 │
│  │ Login    │ │ Dashboard │ │ Ticket  │ │ Settings │                 │
│  │ Register │ │ (role-    │ │ Detail  │ │          │                 │
│  │ Reset    │ │  based)   │ │ List    │ │          │                 │
│  └────┬─────┘ └─────┬─────┘ └────┬────┘ └────┬─────┘                 │
│       │             │           │           │                        │
│  ┌────▼─────────────▼───────────▼───────────▼────────────────────┐   │
│  │            Riverpod Providers (State Management)             │   │
│  └────┬──────────────┬────────────────┬──────────────┬──────────┘   │
│       │              │                │              │              │
│  ┌────▼─────┐  ┌─────▼─────┐  ┌───────▼─────┐  ┌────▼──────┐       │
│  │ Auth     │  │ Ticket    │  │ Comment     │  │  Notif    │       │
│  │ Repo     │  │ Repo      │  │ Repo        │  │  Repo     │       │
│  └────┬─────┘  └─────┬─────┘  └──────┬──────┘  └─────┬─────┘       │
│       │              │               │               │              │
│  ┌────▼──────┐  ┌────▼──────┐  ┌─────▼──────┐                         │
│  │ Log Repo  │  │ Storage   │  │ Helpdesk   │                         │
│  │           │  │ Repo      │  │ Repo       │                         │
│  └────┬──────┘  └────┬──────┘  └─────┬──────┘                         │
│       │              │              │                                │
│       └──────────────┴──────────────┘                                │
│                              │                                     │
│                    ┌─────────▼──────────┐                          │
│                    │  Supabase Client   │                          │
│                    │  (supabase_flutter)│                          │
│                    └─────────┬──────────┘                          │
└──────────────────────────────┼───────────────────────────────────┘
                               │ HTTPS
                               │ Header: Authorization: Bearer <jwt>
                               │ Header: apikey: <anon_key>
                               │
       ┌───────────────────────┼──────────────────────────────────┐
       │                       │                                  │
┌──────▼──────────┐   ┌─────────▼─────────┐   ┌──────────────────┐
│  Supabase Auth  │   │  Postgres DB      │   │  Supabase        │
│  (auth.users)   │   │  (tabel bisnis)   │   │  Storage         │
│                 │   │                   │   │  (file)          │
│ - Login         │   │ - users           │   │                  │
│ - Register      │   │ - helpdesks       │   │ - ticket-photos  │
│ - Logout        │   │ - tickets         │   │ - comment-       │
│ - JWT issue     │   │ - comments        │   │   attachments    │
│ - Session mgmt  │   │ - notifications   │   │ - avatars        │
│                 │   │ - ticket_logs     │   │                  │
│ UUID identity   │   │                   │   │ + RLS            │
│ Password hash   │   │ + RLS (pakai      │   │   (path-based)   │
│                 │   │   auth.uid())      │   └──────────────────┘
└─────────────────┘   │ + Triggers        │            │
         │             │ + Functions        │            │
         │             └─────────┬─────────┘            │
         │                       │                      │
         └───────────────────────┴──────────────────────┘
                                 │
                  Semua identitas user dari auth.users
                  di-bridge via users.auth_user_id (UUID)
```

### 2.2. Bagaimana Auth Bekerja

**Step 1: User Login**
- User input email + password di Flutter
- `AuthRepository.login()` panggil Supabase Auth `/auth/v1/token`
- Supabase verifikasi password (di-hash pakai bcrypt)
- Supabase kembalikan **JWT** + refresh token

**Step 2: Setiap Request Kirim JWT**
- `supabase_flutter` otomatis attach header:
  - `Authorization: Bearer <jwt>`
  - `apikey: <anon_key>`
- Postgres verifikasi JWT di setiap query
- Postgres cek **RLS policy** → user hanya bisa akses data yang diizinkan

**Step 3: Identifikasi User**
- `auth.uid()` di Postgres = UUID dari JWT
- Untuk lookup ke tabel bisnis: `SELECT * FROM users WHERE auth_user_id = auth.uid()`
- Semua RLS policy pakai pattern `EXISTS (SELECT 1 FROM users WHERE auth_user_id = auth.uid() AND ...)`

### 2.3. Arsitektur Layer

| Layer             | Tanggung Jawab                                                                |
| ----------------- | ----------------------------------------------------------------------------- |
| **UI (Pages)**    | Menampilkan data, menerima input user, navigasi                              |
| **Provider**      | State management, business logic sederhana, caching                          |
| **Repository**    | Akses data (Supabase client), mapping response, error handling               |
| **Supabase Auth** | Login, register, JWT issue, session management (terpisah dari REST)          |
| **Supabase**      | REST API client (PostgREST) + Storage                                        |
| **Postgres**      | Database, RLS (auth check), triggers, functions (logic terpusat)             |
| **Storage**       | File storage (foto)                                                           |

### 2.4. Prinsip Desain

- **Client tidak percaya input sendiri** — semua validasi & authorization via RLS di database
- **JWT = identitas** — `auth.uid()` di Postgres = UUID user yang sedang login
- **Bridge pattern** — `auth.users` (managed UUID) ↔ `users` (bisnis INT) via `auth_user_id`
- **Triggers push notification & log** — auto-generate, tidak manual di client
- **Cursor-based pagination** — efisien untuk data besar
- **Single source of truth** — Postgres jadi pusat semua data

---

## 3. Base URL

### 3.1. Base URL Project

```
https://{SUPABASE_PROJECT_REF}.supabase.co
```

**Project ref saat ini:**
```
https://brkylvdfffjmfaiebgcf.supabase.co
```

### 3.2. Service Path

Supabase menyediakan 4 service dengan path prefix berbeda:

| Service       | Path Prefix     | Contoh                                                            | Dipakai di Project? |
| ------------- | --------------- | ----------------------------------------------------------------- | :-----------------: |
| Auth          | `/auth/v1/`     | `/auth/v1/token?grant_type=password`, `/auth/v1/signup`           | ✅ Ya                |
| REST (DB)     | `/rest/v1/`     | `/rest/v1/tickets`, `/rest/v1/comments`                           | ✅ Ya                |
| Storage       | `/storage/v1/`  | `/storage/v1/object/ticket-photos/{path}`                         | ✅ Ya                |
| Realtime      | `/realtime/v1/` | `wss://...supabase.co/realtime/v1/websocket`                      | ❌ Future work      |

⚠️ **Catatan:** Semua prefix di atas ditambahkan **otomatis** oleh `supabase_flutter` package.

### 3.3. Contoh URL Lengkap

| Method | Path                          | Full URL                                                                   |
| ------ | ----------------------------- | -------------------------------------------------------------------------- |
| GET    | `/rest/v1/tickets`            | `https://brkylvdfffjmfaiebgcf.supabase.co/rest/v1/tickets`                 |
| GET    | `/rest/v1/comments`           | `https://brkylvdfffjmfaiebgcf.supabase.co/rest/v1/comments`                |
| POST   | `/auth/v1/token`              | `https://brkylvdfffjmfaiebgcf.supabase.co/auth/v1/token?grant_type=password` |
| POST   | `/storage/v1/object/...`      | `https://brkylvdfffjmfaiebgcf.supabase.co/storage/v1/object/ticket-photos/...` |

Detail konfigurasi environment ada di [`env.md`](./env.md).

---

## 4. Authentication

### 4.1. Overview

Autentikasi menggunakan **Supabase Auth** dengan metode **email + password**. Setelah login berhasil, Supabase mengembalikan **JWT (JSON Web Token)** yang digunakan untuk authorize request selanjutnya.

**Karakteristik:**
- 🔐 Password disimpan aman (di-hash) oleh Supabase
- 🎫 JWT dikirim via header `Authorization: Bearer <token>`
- ⏰ Token punya expiry, auto-refresh oleh library
- 🚪 Logout = hapus session dari local storage

### 4.2. Alur Autentikasi

```
┌─────────┐                  ┌─────────────┐                  ┌────────────┐
│  User   │                  │   Flutter   │                  │  Supabase  │
└────┬────┘                  └──────┬──────┘                  └─────┬──────┘
     │                              │                               │
     │  Input email + password      │                               │
     ├─────────────────────────────>│                               │
     │                              │  POST /auth/v1/token          │
     │                              │  {email, password}            │
     │                              ├──────────────────────────────>│
     │                              │                               │
     │                              │  Validasi credentials          │
     │                              │  Generate JWT                  │
     │                              │                               │
     │                              │  200 OK                        │
     │                              │  {access_token, refresh_token} │
     │                              │<──────────────────────────────┤
     │                              │                               │
     │  Navigate to Dashboard       │  Simpan token di local         │
     │<─────────────────────────────┤  (auto-managed by library)     │
     │                              │                               │
```

**Untuk request selanjutnya:**
```
┌─────────────┐                           ┌────────────┐
│   Flutter   │                           │  Supabase  │
└──────┬──────┘                           └─────┬──────┘
       │  GET /rest/v1/tickets                  │
       │  Headers:                              │
       │    Authorization: Bearer <jwt>          │
       │    apikey: <anon_key>                   │
       ├───────────────────────────────────────>│
       │                                        │  Verify JWT
       │                                        │  Check RLS policy
       │                                        │  Return data
       │  200 OK                                │
       │  [{ticket data}]                       │
       │<───────────────────────────────────────┤
```

### 4.3. Endpoints Autentikasi

| Method | Path                                       | Body                                                 | Response                                       | Auth |
| ------ | ------------------------------------------ | ---------------------------------------------------- | ---------------------------------------------- | ---- |
| POST   | `/auth/v1/token?grant_type=password`       | `{email, password}`                                  | `{access_token, refresh_token, user}`          | -    |
| POST   | `/auth/v1/signup`                          | `{email, password, options: {data: {username}}}`     | `{user, session}`                              | -    |
| POST   | `/auth/v1/logout`                          | -                                                    | 204 No Content                                 | ✅   |
| GET    | `/auth/v1/user`                            | -                                                    | `{id, email, ...}`                             | ✅   |
| PUT    | `/auth/v1/user`                            | `{password?, email?}`                                | `{user}`                                       | ✅   |
| POST   | `/auth/v1/recover`                         | `{email}`                                            | 200 OK                                         | -    |

### 4.4. Role-Based Access

Setiap user punya role yang disimpan di tabel `users`:

```
auth.users (Supabase managed, UUID)
    │
    │ 1:1 (via auth_user_id UUID)
    ▼
users (PK: id_user INT)
    ├── id_user (INT, auto-increment)
    ├── auth_user_id (UUID, FK ke auth.users.id)
    ├── username
    ├── role: 'user' | 'admin' | 'helpdesk'
    └── avatar_url
```

> **Catatan penting:** Supabase Auth mengelola `auth.users.id` sebagai **UUID** (bukan INT). Untuk menyinkronkan dengan tabel bisnis kita yang pakai INT, kita simpan UUID itu di kolom `users.auth_user_id`. Foreign key dari tabel lain (`tickets`, `comments`, `notifications`, dll) merujuk ke `users.id_user` (INT), bukan `auth.users.id`.

Authorization per aksi dikontrol oleh **Row Level Security (RLS)** di Postgres (lihat `erd.md`).

---

## 5. Data Model

> Tipe data `INT` untuk primary key tabel bisnis. `UUID` hanya di `users.auth_user_id` (bridge ke Supabase Auth).

### 5.1. `users` (sebelumnya `profiles`)

| Field           | Tipe (Postgres) | Tipe (Dart) | Constraint                                       | Keterangan                                |
| --------------- | --------------- | ----------- | ------------------------------------------------ | ----------------------------------------- |
| `id_user`       | INT             | int         | PK, GENERATED ALWAYS AS IDENTITY                 | Auto-increment                            |
| `auth_user_id`  | UUID            | String      | UNIQUE, FK → `auth.users.id` ON DELETE CASCADE   | UUID dari Supabase Auth, untuk login check |
| `username`      | TEXT            | String      | UNIQUE, NOT NULL                                 | Display name                              |
| `role`          | ENUM            | UserRole    | NOT NULL, DEFAULT 'user'                         | user/admin/helpdesk                       |
| `avatar_url`    | TEXT            | String?     | NULL                                             | Public URL dari Storage                   |
| `created_at`    | TIMESTAMPTZ     | DateTime    | DEFAULT now()                                    |                                           |

**Trigger:** `handle_new_user()` — auto-insert ke `users` saat ada user baru di `auth.users`.

### 5.2. `helpdesks`

| Field           | Tipe (Postgres) | Tipe (Dart) | Constraint                                       | Keterangan              |
| --------------- | --------------- | ----------- | ------------------------------------------------ | ----------------------- |
| `id_helpdesk`   | INT             | int         | PK, GENERATED ALWAYS AS IDENTITY                 |                         |
| `id_user`       | INT             | int         | UNIQUE, FK → `users.id_user` ON DELETE CASCADE   | 1-to-1 dengan user     |
| `name`          | TEXT            | String      | NOT NULL                                         | Nama lengkap            |
| `phone`         | TEXT            | String?     | NULL                                             | Kontak                  |
| `is_available`  | BOOLEAN         | bool        | NOT NULL, DEFAULT true                           | Bisa terima assignment  |
| `created_at`    | TIMESTAMPTZ     | DateTime    | DEFAULT now()                                    |                         |

> Setiap helpdesk punya entri di `users` (untuk login) dan di `helpdesks` (untuk profil teknisi).

### 5.3. `tickets`

| Field                     | Tipe (Postgres) | Tipe (Dart)    | Constraint                                            | Keterangan                              |
| ------------------------- | --------------- | -------------- | ----------------------------------------------------- | --------------------------------------- |
| `id_ticket`               | INT             | int            | PK, GENERATED ALWAYS AS IDENTITY                      | Auto-increment                          |
| `title`                   | TEXT            | String         | NOT NULL                                              |                                         |
| `description`             | TEXT            | String         | NOT NULL                                              |                                         |
| `status`                  | ENUM            | TicketStatus   | NOT NULL, DEFAULT 'open'                              | Lihat section status                    |
| `id_user` (creator)       | INT             | int            | FK → `users.id_user` ON DELETE SET NULL               | User yang buat                          |
| `id_helpdesk`             | INT             | int?           | FK → `helpdesks.id_helpdesk` ON DELETE SET NULL       | Helpdesk yang ditugaskan                |
| `photo_path`              | TEXT            | String?        | NULL                                                  | Path file di Storage                    |
| `cancelled_reason`        | TEXT            | String?        | NULL                                                  | Wajib saat `status = 'cancelled'`       |
| `cancelled_at`            | TIMESTAMPTZ     | DateTime?      | NULL                                                  |                                         |
| `unassign_id_helpdesk`    | INT             | int?           | FK → `helpdesks.id_helpdesk` ON DELETE SET NULL       | Helpdesk yang request un-assign         |
| `unassign_requested_at`   | TIMESTAMPTZ     | DateTime?      | NULL                                                  |                                         |
| `unassign_reason`         | TEXT            | String?        | NULL                                                  | Alasan dari helpdesk                    |
| `unassign_id_user`        | INT             | int?           | FK → `users.id_user` ON DELETE SET NULL               | Admin yang approve/reject               |
| `unassign_decided_at`     | TIMESTAMPTZ     | DateTime?      | NULL                                                  |                                         |
| `unassign_reject_reason`  | TEXT            | String?        | NULL                                                  | Alasan reject (opsional)                |
| `started_at`              | TIMESTAMPTZ     | DateTime?      | NULL                                                  | Pertama kali helpdesk buka              |
| `completed_at`            | TIMESTAMPTZ     | DateTime?      | NULL                                                  | Saat helpdesk mark as done              |
| `created_at`              | TIMESTAMPTZ     | DateTime       | DEFAULT now()                                         |                                         |
| `updated_at`              | TIMESTAMPTZ     | DateTime       | DEFAULT now()                                         | Auto-update via trigger                 |

> **Catatan penamaan:** `id_user` (creator) dan `unassign_id_user` (admin) namanya sama — `id_user` — karena tabel `tickets` boleh punya banyak reference ke `users`. Bedanya jelas dari konteks. Kalau mau lebih eksplisit, bisa pakai `creator_id_user` / `admin_id_user`, tapi konsistensi dengan format `id_*` lebih diutamakan.

**Enum `ticket_status`:** `open` | `assigned` | `in_progress` | `pending_unassign` | `done` | `cancelled`

### 5.4. `comments`

| Field          | Tipe (Postgres) | Tipe (Dart) | Constraint                                            | Keterangan                          |
| -------------- | --------------- | ----------- | ----------------------------------------------------- | ----------------------------------- |
| `id_comment`   | INT             | int         | PK, GENERATED ALWAYS AS IDENTITY                      |                                     |
| `id_ticket`    | INT             | int         | FK → `tickets.id_ticket` ON DELETE CASCADE, NOT NULL  |                                     |
| `id_user`      | INT             | int         | FK → `users.id_user` ON DELETE SET NULL               | Author                              |
| `message`      | TEXT            | String      | NOT NULL                                              | Isi komentar (sebelumnya `content`)  |
| `is_edited`    | BOOLEAN         | bool        | NOT NULL, DEFAULT false                               | Indikator "(diedit)"                |
| `created_at`   | TIMESTAMPTZ     | DateTime    | DEFAULT now()                                         |                                     |
| `updated_at`   | TIMESTAMPTZ     | DateTime    | DEFAULT now()                                         | Auto-update saat edit               |

### 5.5. `comment_attachments`

| Field                   | Tipe (Postgres) | Tipe (Dart) | Constraint                                                | Keterangan                |
| ----------------------- | --------------- | ----------- | --------------------------------------------------------- | ------------------------- |
| `id_comment_attachment` | INT             | int         | PK, GENERATED ALWAYS AS IDENTITY                          |                           |
| `id_comment`            | INT             | int         | FK → `comments.id_comment` ON DELETE CASCADE, NOT NULL    |                           |
| `storage_path`          | TEXT            | String      | NOT NULL                                                 | Path di Storage           |
| `mime_type`             | TEXT            | String      | NOT NULL                                                 | image/jpeg atau image/png |
| `file_size`             | INT             | int         | NOT NULL, CHECK (file_size <= 5242880)                    | Bytes, max 5MB            |
| `uploaded_at`           | TIMESTAMPTZ     | DateTime    | DEFAULT now()                                            |                           |

### 5.6. `ticket_attachments` (foto utama tiket)

| Field                   | Tipe (Postgres) | Tipe (Dart) | Constraint                                                | Keterangan                |
| ----------------------- | --------------- | ----------- | --------------------------------------------------------- | ------------------------- |
| `id_ticket_attachment`  | INT             | int         | PK, GENERATED ALWAYS AS IDENTITY                          |                           |
| `id_ticket`             | INT             | int         | FK → `tickets.id_ticket` ON DELETE CASCADE, NOT NULL      |                           |
| `storage_path`          | TEXT            | String      | NOT NULL                                                 | Path di Storage           |
| `mime_type`             | TEXT            | String      | NOT NULL                                                 |                           |
| `file_size`             | INT             | int         | NOT NULL                                                 |                           |
| `uploaded_at`           | TIMESTAMPTZ     | DateTime    | DEFAULT now()                                            |                           |

### 5.7. `notifications`

| Field              | Tipe (Postgres) | Tipe (Dart)        | Constraint                                            | Keterangan                          |
| ------------------ | --------------- | ------------------ | ----------------------------------------------------- | ----------------------------------- |
| `id_notification`  | INT             | int                | PK, GENERATED ALWAYS AS IDENTITY                      |                                     |
| `id_user`          | INT             | int                | FK → `users.id_user` ON DELETE CASCADE, NOT NULL      | Penerima notif                      |
| `type`             | ENUM            | NotificationType   | NOT NULL                                              | Lihat notif type di API.md          |
| `title`            | TEXT            | String             | NOT NULL                                              | Short title                         |
| `body`             | TEXT            | String             | NOT NULL                                              | Description                         |
| `id_ticket`        | INT             | int?               | NULL                                                  | FK ke tiket terkait (opsional)      |
| `is_read`          | BOOLEAN         | bool               | NOT NULL, DEFAULT false                               |                                     |
| `created_at`       | TIMESTAMPTZ     | DateTime           | DEFAULT now()                                         |                                     |

### 5.8. `ticket_logs`

| Field           | Tipe (Postgres) | Tipe (Dart)            | Constraint                                            | Keterangan                          |
| --------------- | --------------- | ---------------------- | ----------------------------------------------------- | ----------------------------------- |
| `id_ticket_log` | INT             | int                    | PK, GENERATED ALWAYS AS IDENTITY                      |                                     |
| `id_ticket`     | INT             | int                    | FK → `tickets.id_ticket` ON DELETE CASCADE, NOT NULL  |                                     |
| `id_user`       | INT             | int?                   | FK → `users.id_user` ON DELETE SET NULL               | Siapa yang melakukan                |
| `actor_role`    | ENUM            | UserRole               | NOT NULL                                              | Snapshot role saat event            |
| `event_type`    | TEXT            | String                 | NOT NULL                                              | Lihat event list                    |
| `payload`       | JSONB           | Map<String, dynamic>  | NOT NULL                                              | Detail event (before/after, dll)    |
| `created_at`    | TIMESTAMPTZ     | DateTime               | DEFAULT now()                                         |                                     |

---

## 6. Endpoint List

> Path menggunakan format relatif. Base URL: `https://brkylvdfffjmfaiebgcf.supabase.co`

### 6.1. Auth (Supabase Auth SDK)

| Method | Path                                       | Deskripsi                                  |
| ------ | ------------------------------------------ | ------------------------------------------ |
| POST   | `/auth/v1/token?grant_type=password`       | Login dengan email + password              |
| POST   | `/auth/v1/signup`                          | Register user baru                         |
| POST   | `/auth/v1/logout`                          | Logout (hapus session)                     |
| GET    | `/auth/v1/user`                            | Get info user yang sedang login            |
| PUT    | `/auth/v1/user`                            | Update email/password                      |
| POST   | `/auth/v1/recover`                         | Kirim email reset password                 |

### 6.2. Users (sebelumnya Profiles)

| Method | Path                                            | Deskripsi                                  |
| ------ | ----------------------------------------------- | ------------------------------------------ |
| GET    | `/rest/v1/users?id_user=eq.{id}`                | Get user by id                             |
| GET    | `/rest/v1/users?username=eq.{username}`        | Get user by username                       |
| GET    | `/rest/v1/users?role=eq.{role}`                | Filter by role                             |
| PATCH  | `/rest/v1/users?id_user=eq.{id}`                | Update user (sendiri / oleh admin)         |

### 6.3. Helpdesks

| Method | Path                                                          | Deskripsi                                  |
| ------ | ------------------------------------------------------------- | ------------------------------------------ |
| GET    | `/rest/v1/helpdesks?order=name.asc`                           | List semua helpdesk                        |
| GET    | `/rest/v1/helpdesks?is_available=eq.true`                     | List helpdesk yang available               |
| GET    | `/rest/v1/helpdesks?id_helpdesk=eq.{id}`                      | Detail helpdesk                            |
| PATCH  | `/rest/v1/helpdesks?id_helpdesk=eq.{id}`                      | Update profil / toggle is_available        |

### 6.4. Tickets — List & Detail

| Method | Path                                                                                  | Deskripsi                                  |
| ------ | ------------------------------------------------------------------------------------- | ------------------------------------------ |
| GET    | `/rest/v1/tickets?order=created_at.desc&limit=20`                                     | List semua tiket (cursor pagination)       |
| GET    | `/rest/v1/tickets?id_user=eq.{id}`                                                    | Tiket milik user tertentu                  |
| GET    | `/rest/v1/tickets?id_helpdesk=eq.{id}`                                                | Tiket yang di-assign ke helpdesk           |
| GET    | `/rest/v1/tickets?status=eq.{status}`                                                 | Filter by status                           |
| GET    | `/rest/v1/tickets?id_ticket=eq.{id}&select=*,comments(*)`                             | Detail tiket + comments                    |

### 6.5. Tickets — Create

| Method | Path                              | Body                                                 | Deskripsi                |
| ------ | --------------------------------- | ---------------------------------------------------- | ------------------------ |
| POST   | `/rest/v1/tickets`                | `{title, description, id_user, photo_path?}`         | Create tiket (auto: status=open) |
| POST   | `/rest/v1/ticket_attachments`     | `{id_ticket, storage_path, mime_type, file_size}`    | Simpan foto tiket        |

### 6.6. Tickets — User Actions (saat status=open)

| Method | Path                                                  | Body                                              | Deskripsi            |
| ------ | ----------------------------------------------------- | ------------------------------------------------- | -------------------- |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.open`   | `{title?, description?, photo_path?}`            | Edit tiket           |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.open`   | `{status: 'cancelled', cancelled_reason, cancelled_at}` | Cancel tiket (wajib alasan) |

### 6.7. Tickets — Admin Actions

| Method | Path                                                                  | Body                                                                                | Deskripsi                |
| ------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------ |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.open`                  | `{id_helpdesk, status: 'assigned'}`                                                 | Assign tiket             |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`| `{id_helpdesk: null, status: 'open'}`                                               | Un-assign (kembali open) |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`| `{id_helpdesk: '{new_id}'}`                                                         | Re-assign (ganti helpdesk) |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.pending_unassign`      | `{status: 'open', unassign_id_user, unassign_decided_at}`                          | Approve un-assign request |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.pending_unassign`      | `{status: '{prev}', unassign_id_user, unassign_decided_at, unassign_reject_reason}` | Reject un-assign request |

### 6.8. Tickets — Helpdesk Actions

| Method | Path                                                                  | Body                                                                                | Deskripsi                |
| ------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------ |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=eq.assigned`              | `{status: 'in_progress', started_at: now()}`                                        | Auto: in_progress saat buka |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`| `{status: 'done', completed_at: now()}`                                              | Mark as done              |
| PATCH  | `/rest/v1/tickets?id_ticket=eq.{id}&status=in.(assigned,in_progress)`| `{status: 'pending_unassign', unassign_id_helpdesk, unassign_requested_at, unassign_reason}` | Request un-assign (wajib alasan) |

### 6.9. Comments

| Method | Path                                                                  | Deskripsi                                  |
| ------ | --------------------------------------------------------------------- | ------------------------------------------ |
| GET    | `/rest/v1/comments?id_ticket=eq.{id}&order=created_at.asc`            | List comment per tiket + attachments       |
| GET    | `/rest/v1/comments?id_comment=eq.{id}`                                | Detail comment                             |
| POST   | `/rest/v1/comments`                                                   | Tambah comment                             |
| POST   | `/rest/v1/comment_attachments`                                        | Upload attachment (max 3 per comment)      |
| PATCH  | `/rest/v1/comments?id_comment=eq.{id}&id_user=eq.{user_id}`           | Edit comment (set is_edited=true)          |
| DELETE | `/rest/v1/comments?id_comment=eq.{id}&id_user=eq.{user_id}`           | Hard delete comment (author only)          |

### 6.10. Notifications

| Method | Path                                                                  | Deskripsi                                  |
| ------ | --------------------------------------------------------------------- | ------------------------------------------ |
| GET    | `/rest/v1/notifications?id_user=eq.{id}&order=created_at.desc&limit=20` | List notif user (cursor)              |
| GET    | `/rest/v1/notifications?id_user=eq.{id}&is_read=eq.false`             | Notif belum dibaca                         |
| PATCH  | `/rest/v1/notifications?id_notification=eq.{id}&id_user=eq.{id}`      | Mark as read (single)                      |
| PATCH  | `/rest/v1/notifications?id_notification=in.({ids})&id_user=eq.{id}`   | Bulk mark as read                          |
| PATCH  | `/rest/v1/notifications?id_user=eq.{id}&is_read=eq.false`             | Mark all as read                           |
| DELETE | `/rest/v1/notifications?id_notification=eq.{id}&id_user=eq.{id}`      | Dismiss (delete) notif                     |

### 6.11. Ticket Logs

| Method | Path                                                                  | Deskripsi                                  |
| ------ | --------------------------------------------------------------------- | ------------------------------------------ |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&order=created_at.desc`        | Log per tiket                              |
| GET    | `/rest/v1/ticket_logs?id_user=eq.{id}&order=created_at.desc&limit=20` | Log agregat per user                       |
| GET    | `/rest/v1/ticket_logs?id_ticket=eq.{id}&created_at=gte.{date}`        | Filter by tanggal                          |

### 6.12. Storage

| Method | Path                                                       | Deskripsi                                  |
| ------ | ---------------------------------------------------------- | ------------------------------------------ |
| POST   | `/storage/v1/object/ticket-photos/{path}`                  | Upload foto tiket                          |
| GET    | `/storage/v1/object/ticket-photos/{path}`                  | Download foto tiket                        |
| POST   | `/storage/v1/object/comment-attachments/{path}`            | Upload attachment comment                  |
| POST   | `/storage/v1/object/avatars/{id_user}.jpg`                 | Upload avatar                              |

> **Catatan:** Storage path lengkap, body format multipart, dan detail lainnya ada di [`API.md` Section 5](./API.md).

---

## 7. Business Flow

### 7.1. Alur Utama Per Role

#### User Flow
```
Login → Dashboard → Lihat Tiket Saya → Buat/Edit/Cancel (saat open) → Chat → Selesai
```

#### Admin Flow
```
Login → Dashboard → Lihat Semua Tiket → Assign/Un-assign/Re-assign → Approve/Reject Un-assign Request → Monitoring
```

#### Helpdesk Flow
```
Login → Dashboard → Lihat Tiket Assigned → Kerjakan (auto in_progress) → Mark as Done / Request Un-assign
```

### 7.2. State Machine Status Tiket

```
                       ┌─────────┐
            create ──> │  open   │
                       └────┬────┘
                            │ admin.assign(helpdesk)
                            ▼
                       ┌─────────┐
                       │ assigned│
                       └────┬────┘
                            │ helpdesk buka tiket (auto)
                            ▼
                       ┌──────────────┐
                       │ in_progress  │
                       └────┬─────────┘
                            │ helpdesk.confirmDone()
                            ▼
                       ┌─────────┐
                       │  done   │ (terminal)
                       └─────────┘

   Saat open / assigned / in_progress:
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
   admin.unassign     helpdesk.request    user.cancel
   atau                 Unassign()
   admin.reassign      ▼
        │          ┌──────────────────┐
        ▼          │ pending_unassign │ (status baru)
   (kembali ke       └────────┬────────┘
    status open)              │
                       admin approve
                       ├──> open
                       └──> reject (kembali ke assigned/in_progress)

   user.cancel (hanya dari status open):
        └────> cancelled (terminal, dengan cancelled_reason)
```

### 7.3. Trigger Auto-Notification (Postgres)

| Event                                   | Yang Dapat Notif                                |
| --------------------------------------- | ---------------------------------------------- |
| User bikin tiket baru                   | Semua admin                                    |
| Admin assign ke helpdesk                | User + helpdesk yang ditugaskan                |
| Helpdesk mulai kerja (in_progress)      | User                                           |
| Ada comment baru                        | User ticket + helpdesk assigned (BUKAN admin)  |
| Helpdesk request un-assign              | Semua admin                                    |
| Admin approve un-assign                 | Helpdesk yang request                          |
| Admin reject un-assign                  | Helpdesk yang request                          |
| Helpdesk selesaikan tiket (done)        | User + semua admin                             |
| User cancel tiket                       | Semua admin                                    |
| Admin re-assign (ganti helpdesk)        | Helpdesk lama + baru + user                    |

### 7.4. Log History Event

Setiap perubahan dicatat di `ticket_logs` secara permanen (audit trail):

| Event Type                      | Data yang Dicatat                                  |
| ------------------------------- | -------------------------------------------------- |
| `ticket.created`                | id_user, id_ticket, snapshot                       |
| `ticket.assigned`               | id_user (admin), id_ticket, id_helpdesk            |
| `ticket.reassigned`             | id_user, id_ticket, from_helpdesk, to_helpdesk     |
| `ticket.unassigned`             | id_user, id_ticket, from_helpdesk                  |
| `ticket.unassign_requested`     | id_user (helpdesk), id_ticket, reason              |
| `ticket.unassign_approved`      | id_user (admin), id_ticket                         |
| `ticket.unassign_rejected`      | id_user (admin), id_ticket, reject_reason          |
| `ticket.status_changed`         | id_user, id_ticket, from_status, to_status         |
| `ticket.cancelled`              | id_user, id_ticket, reason                         |
| `ticket.updated`                | id_user, id_ticket, before/after (title, desc)     |
| `comment.added`                 | id_user, id_ticket, id_comment, snippet            |
| `comment.edited`                | id_user, id_comment, before, after                 |
| `comment.deleted`               | id_user, id_comment, id_ticket                     |
| `helpdesk.availability_changed` | id_user (helpdesk), from, to                       |

Detail lengkap business flow ada di [`flow.md`](./flow.md).

---

## 8. ERD Mapping

### 8.1. Relasi Antar Tabel

```
┌──────────────────┐
│   auth.users     │ (Supabase managed, UUID)
└────────┬─────────┘
         │ 1:1 (via auth_user_id)
         ▼
┌──────────────────┐
│   users          │ (id_user INT, role: user/admin/helpdesk)
└────────┬─────────┘
         │ 1:1 (untuk role=helpdesk)
         ▼
┌──────────────────┐
│   helpdesks      │ (id_helpdesk INT, is_available, phone)
└────────┬─────────┘
         │ 1:N
         ▼
┌──────────────────────────────────────────┐
│   tickets                                │
│   - status (enum)                        │
│   - photo_path (Storage ref)             │
│   - cancelled_* (kalau cancelled)        │
│   - unassign_* (kalau pending/decided)   │
│   - started_at, completed_at             │
└──┬─────────┬─────────┬───────────────┬───┘
   │ 1:N     │ 1:N     │ 1:N           │ 1:N
   ▼         ▼         ▼               ▼
┌──────┐ ┌─────────┐ ┌──────────┐ ┌──────────────┐
│ticket│ │comments │ │ notifica-│ │ ticket_logs  │
│attach│ │         │ │ tions    │ │ (audit trail)│
│ments │ │         │ │ (per     │ │ permanent    │
└──────┘ └──┬──────┘ │  user)   │ └──────────────┘
            │ 1:N    └──────────┘
            ▼
      ┌──────────────────┐
      │ comment_         │
      │ attachments      │ (max 3 per comment)
      └──────────────────┘
```

### 8.2. Tabel Ringkas

| Tabel                  | PK                | Relasi Utama                                          | Fungsi                          |
| ---------------------- | ----------------- | ----------------------------------------------------- | ------------------------------- |
| `auth.users`           | UUID              | (managed Supabase)                                    | Login identity                  |
| `users`                | `id_user`         | 1:1 ke `auth.users` (via `auth_user_id`)              | User data + role                |
| `helpdesks`            | `id_helpdesk`     | 1:1 ke `users` (via `id_user`)                        | Profil teknisi                  |
| `tickets`              | `id_ticket`       | N:1 ke `users` (creator), N:1 ke `helpdesks`          | Tiket gangguan                  |
| `comments`             | `id_comment`      | N:1 ke `tickets`, N:1 ke `users`                      | Komentar pada tiket             |
| `ticket_attachments`   | `id_ticket_attachment` | N:1 ke `tickets`                                  | Foto utama tiket                |
| `comment_attachments`  | `id_comment_attachment` | N:1 ke `comments`                              | Foto di komentar (max 3)        |
| `notifications`        | `id_notification` | N:1 ke `users`                                        | Notifikasi per user             |
| `ticket_logs`          | `id_ticket_log`   | N:1 ke `tickets`, N:1 ke `users`                      | Audit trail permanent           |

### 8.3. Cascade Behavior

| Relasi                                          | On Delete |
| ----------------------------------------------- | --------- |
| `auth.users` → `users` (auth_user_id)           | CASCADE   |
| `users` → `helpdesks` (id_user)                 | CASCADE   |
| `users` → `tickets` (id_user / creator)         | SET NULL  |
| `helpdesks` → `tickets` (id_helpdesk)           | SET NULL  |
| `tickets` → `comments` (id_ticket)              | CASCADE   |
| `tickets` → `ticket_attachments` (id_ticket)    | CASCADE   |
| `tickets` → `ticket_logs` (id_ticket)           | CASCADE   |
| `comments` → `comment_attachments` (id_comment) | CASCADE   |
| `users` → `notifications` (id_user)             | CASCADE   |

> Detail ERD + SQL DDL lengkap ada di [`erd.md`](./erd.md).

---

## Lampiran

### A. File Referensi

- [`flow.md`](./flow.md) — Rancangan alur aplikasi + audit existing implementation
- [`API.md`](./API.md) — Kontrak API lengkap (endpoint detail, repository, model, trigger SQL)
- [`erd.md`](./erd.md) — Diagram ER + SQL DDL lengkap
- [`env.md`](./env.md) — Environment & konfigurasi setup

### B. Statistik Project

- **Total tabel:** 9 (termasuk auth.users)
- **Total endpoint:** ~40 (auth + REST + storage)
- **Total trigger function:** 7
- **Total enum:** 3 (user_role, ticket_status, notif_type)
- **Total storage bucket:** 3 (ticket-photos, comment-attachments, avatars)
- **Role:** 3 (user, admin, helpdesk)
- **Status tiket:** 6 (open, assigned, in_progress, pending_unassign, done, cancelled)

### C. Catatan untuk Developer

- **Tipe data ID:** Menggunakan `INT` (auto-increment) untuk primary key tabel bisnis, bukan `UUID`. `UUID` hanya di kolom `users.auth_user_id` untuk bridge dengan Supabase Auth.
- **Password:** Disimpan aman (di-hash) oleh Supabase Auth.
- **RLS:** Wajib diaktifkan di semua tabel — lihat `erd.md` untuk policy lengkap.
- **Triggers:** Auto-insert ke `notifications` dan `ticket_logs` — tidak perlu manual di client.
- **Pagination:** Cursor-based, default 20 item, "Load More" button.
- **Realtime:** Tidak dipakai di demo 1-device. Future work untuk production multi-user.
- **Konvensi penamaan:**
  - PK: `id_user`, `id_ticket`, `id_comment`, dll
  - FK: `id_user`, `id_helpdesk`, `id_ticket`, `id_comment` (sama dengan nama PK di tabel referensi, context-aware)
  - Tabel `users` (bukan `profiles`)
  - Field `comments.message` (bukan `content`)

---

## Lampiran D. Future Work

Fitur-fitur yang **belum diimplementasi** di versi demo (1-device) tapi akan berguna untuk production multi-user:

### D.1. Realtime Subscriptions (Supabase Realtime)

Untuk production dengan multi-user di device berbeda, butuh push notification dari server ke client.

**Channel yang akan dipakai:**

| Channel | Event | Fungsi |
|---------|-------|--------|
| `tickets` | INSERT, UPDATE | Dashboard auto-update saat ada tiket baru / status berubah |
| `tickets:id_ticket=eq.{id}` | UPDATE | Detail tiket update real-time |
| `comments:id_ticket=eq.{id}` | INSERT, UPDATE, DELETE | Chat real-time di tiket |
| `notifications:id_user=eq.{id}` | INSERT, UPDATE | Badge notifikasi update real-time |
| `ticket_logs:id_ticket=eq.{id}` | INSERT | Log history update real-time |

**Implementasi (preview):**
```dart
final channel = supabase
  .channel('tickets-list')
  .onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'tickets',
    callback: (payload) { ref.invalidate(allTicketsProvider); },
  )
  .subscribe();
```

**Endpoint Supabase:** `wss://{project-ref}.supabase.co/realtime/v1/websocket`

**Mengapa tidak dipakai di demo 1-device:**
- Demo menggunakan 1 device, user logout-login pindah role
- Tiap navigasi / pull-to-refresh sudah fetch data baru dari server
- Realtime lebih relevan untuk production dengan 3 device berbeda yang dipakai bersamaan

### D.2. Push Notification (FCM)

Selain in-app notification, kirim push notification ke device saat user sedang off-app. Butuh:
- Firebase Cloud Messaging (FCM) setup
- Trigger dari Postgres (via Edge Function) atau client-side
- Handle device token management

### D.3. Email Notification

Supabase Auth bisa kirim email:
- Reset password (sudah built-in)
- Verifikasi email
- Custom email template via Edge Function

### D.4. File Compression

Foto yang diupload saat ini full size. Untuk optimasi:
- Compress sebelum upload (client-side)
- Generate thumbnail (Supabase Image Transform)
- Lazy load image di list

### D.5. Search Full-Text

Untuk pencarian tiket by title/description:
- Postgres `tsvector` + GIN index
- Search di `users.username`, `tickets.title`, `comments.message`

