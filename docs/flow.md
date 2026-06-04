# Flow Aplikasi — UTS Mobile (Final Design)

> **Status:** Rancangan final (target implementasi)
> **Tanggal:** 2026-06-03
> **Versi:** 3.0 — Final, siap masuk laporan
> **Backend Target:** Supabase (Postgres + Auth + Storage)

---

## Changelog

| Versi | Tanggal      | Perubahan                                                          |
| ----- | ------------ | ------------------------------------------------------------------ |
| 1.0   | 2026-06-03   | Initial draft (current state project)                              |
| 2.0   | 2026-06-03   | Tambah role helpdesk, notif, log history, edit/cancel, profil     |
| 3.0   | 2026-06-03   | Final: pending_unassign, is_available, Load More pagination, dll  |

---

## 0. Ringkasan Aplikasi

**UTS Mobile** adalah aplikasi helpdesk internal dengan 3 role yang saling berkolaborasi untuk menyelesaikan tiket gangguan.

| Role      | Deskripsi                                                          |
| --------- | ------------------------------------------------------------------ |
| `user`    | Membuat request tiket gangguan                                     |
| `admin`   | Menerima tiket, menugaskan helpdesk yang tersedia                  |
| `helpdesk`| Mengerjakan tiket yang ditugaskan, konfirmasi selesai              |

---

## 0.1. Existing Implementation (Audit Project Saat Ini)

> Hasil pembacaan menyeluruh semua file di `lib/`. Semua sudah jalan dengan **data dummy in-memory** (bukan database).

### Pages yang sudah ada (fungsional, statis)

**Auth (4 halaman):**
- ✅ `SplashScreen` — 2 detik loading, auto-redirect ke login/dashboard
- ✅ `LoginScreen` — Form username + password, navigasi ke register & reset
- ✅ `RegisterScreen` — Form username + email + password (DUMMY: simulasi 1 detik, tidak call API)
- ✅ `ResetPasswordScreen` — Form email (DUMMY: simulasi 1 detik)

**Main Shell:**
- ✅ `MainLayout` — Bottom Navigation 4 tab: Dashboard / Tickets / Notifications / Settings

**Dashboard (2 widget, switch by role):**
- ✅ `DashboardUserWidget` — Welcome + 2 stat card (Total Tickets, Active Tickets) + Theme toggle card
- ✅ `DashboardAdminWidget` — Welcome + Admin badge + Big total card + 4 status breakdown (Open/Assigned/InProgress/Done)

**Ticket (4 halaman):**
- ✅ `TicketListPage` — List tiket + 6 filter chip (All + 5 status: open/assigned/in_progress/done/cancelled)
- ✅ `TicketDetailPage` — Status badge + status tracking visual (stepper horizontal) + comment section + admin actions (assign + change status dropdown)
- ✅ `CreateTicketPage` — Form title + description + camera button
- ✅ `CameraScreen` — Capture/gallery/save/use dengan permission flow lengkap

**Notification:**
- ✅ `NotificationPage` — List dengan read/unread state (icon & bold), tap untuk mark as read + navigate ke ticket

**Settings:**
- ✅ `SettingsPage` — Profile section (avatar inisial + role badge) + Dark mode switch (persist) + Notifications switch + Sound switch + App version + Logout

### Models yang sudah ada

| Model              | File                                          | Catatan                                                          |
| ------------------ | --------------------------------------------- | ---------------------------------------------------------------- |
| `User`             | `auth/.../user_model.dart`                    | Username + password + role (untuk dummy auth)                    |
| `Ticket`           | `ticket/.../ticket_model.dart`                | + `copyWith`, photoPath sebagai base64 string                    |
| `Comment`          | `ticket/.../comment_model.dart`               | Simple, tidak ada `isEdited` atau attachments                    |
| `Technician`       | `ticket/.../technician_model.dart`            | Digunakan oleh AdminActions di TicketDetail (nama akan jadi `Helpdesk`) |
| `DashboardStats`   | `dashboard/.../dashboard_model.dart`          | Punya 2 factory: `fromUserTickets` (simple) & `fromAllTickets` (breakdown) |
| `Notification`     | `notification/.../notification_model.dart`   | Field `time` sudah formatted string ("2 hours ago")              |
| `UserSettings`     | `settings/.../settings_model.dart`            | Ada field `language` (default 'en')                              |

### Repositories (semua masih dummy in-memory)

| Repository               | Method yang sudah ada                                                            |
| ------------------------ | -------------------------------------------------------------------------------- |
| `AuthRepository`         | `login()`, `logout()`                                                            |
| `TicketRepository`       | `getAllTickets`, `getByUser`, `getById`, `getByStatus`, `updateStatus`, `assignToTechnician`, `addComment`, `createTicket` |
| `TechnicianRepository`   | `getTechnicians`, `getById`, `getByUsername` (akan di-rename jadi `HelpdeskRepository`) |
| `DashboardRepository`    | `getUserDashboardStats`, `getAdminDashboardStats` (delegasi ke TicketRepository) |
| `NotificationRepository` | `getAll`, `getUnread`, `getById`, `markAsRead`, `markAllAsRead`, `delete`, `getUnreadCount` |
| `SettingsRepository`     | `getSettings`, `setDarkMode`, `setLanguage`, `setNotificationsEnabled`, `setSoundEnabled`, `resetSettings` (persist ke SharedPreferences) |

### Providers (Riverpod)

| Provider                          | Tipe                        | Auto-refresh                       |
| --------------------------------- | --------------------------- | ---------------------------------- |
| `authRepositoryProvider`          | `Provider`                  | -                                  |
| `currentUserProvider`             | `StateProvider<User?>`      | Di-set manual dari `loginProvider` |
| `loginProvider`                   | `FutureProvider.family`     | -                                  |
| `logoutProvider`                  | `FutureProvider`            | -                                  |
| `ticketRepositoryProvider`        | `Provider`                  | -                                  |
| `allTicketsProvider`              | `StateProvider<List<Ticket>>` | Manual via `ref.refresh()`       |
| `fetchAllTicketsProvider`         | `FutureProvider`            | -                                  |
| `userTicketsProvider`             | `FutureProvider.family`     | -                                  |
| `ticketsByStatusProvider`         | `FutureProvider.family`     | -                                  |
| `ticketDetailProvider`            | `FutureProvider.family`     | -                                  |
| `dashboardRepositoryProvider`     | `Provider`                  | -                                  |
| `userDashboardStatsProvider`      | `FutureProvider.family`     | -                                  |
| `adminDashboardStatsProvider`     | `FutureProvider`            | -                                  |
| `notificationRepositoryProvider`  | `Provider`                  | -                                  |
| `allNotificationsProvider`        | `FutureProvider`            | Auto-refresh via `mark/delete`     |
| `unreadNotificationsProvider`     | `FutureProvider`            | Auto-refresh                       |
| `unreadCountProvider`             | `FutureProvider`            | Auto-refresh                       |
| `markNotificationAsReadProvider`  | `FutureProvider.family`     | Trigger refresh                    |
| `markAllAsReadProvider`           | `FutureProvider`            | Trigger refresh                    |
| `deleteNotificationProvider`      | `FutureProvider.family`     | Trigger refresh                    |
| `themeModeProvider`               | `StateNotifierProvider<bool>` | ✅ Persist SharedPreferences      |
| `settingsRepositoryProvider`      | `Provider`                  | -                                  |
| `darkModeProvider`                | `StateNotifierProvider<bool>` | ✅ Persist                          |
| `languageProvider`                | `StateNotifierProvider<String>` | ✅ Persist (default 'en')         |
| `notificationsEnabledProvider`    | `StateNotifierProvider<bool>` | ✅ Persist                          |
| `soundEnabledProvider`            | `StateNotifierProvider<bool>` | ✅ Persist                          |

### Status yang sudah dipakai (existing)

Saat ini: `open`, `assigned`, `in_progress`, `done`, `cancelled` (5 status).

**Status `pending_unassign`** belum ada — ini fitur baru sesuai rancangan v3.0.

### Role yang sudah dipakai (existing)

Saat ini: `user`, `admin` (2 role).

**Role `helpdesk`** belum ada — ini fitur baru sesuai rancangan v3.0. Tabel `Technician` di data layer akan di-rename jadi `helpdesks` dengan tambahan field `is_available` dan relasi ke `users` (sebelumnya `profiles`).

### Status flow di UI Ticket Detail (existing)

`_buildStatusTracking()` di `ticket_detail_page.dart` membuat visual stepper horizontal:
- Untuk `cancelled`: alur `open → cancelled`
- Untuk status lain: alur `open → assigned → in_progress → done`

Visual ini perlu di-update untuk handle status `pending_unassign`.

### Admin Actions di Ticket Detail (existing)

Saat ini admin punya 2 dropdown:
- **Assign Technician** — pilih dari list, auto set `assignedTo`
- **Change Status** — manual change ke status apapun

⚠️ **Penting:** Sesuai rancangan final, **admin tidak boleh manual change status**. Dropdown "Change Status" perlu di-restrict atau dihapus. Hanya helpdesk yang punya kendali status (mark as done + request un-assign), dan admin cuma assign/un-assign/re-assign.

### Theme persistence (existing)

`ThemeModeNotifier` di `theme_provider.dart` sudah persist `isDarkMode` ke SharedPreferences dengan key `'isDarkMode'`. Saat app launch, otomatis load. ✅ Tidak perlu diubah.

### Camera & permission flow (existing)

`CameraService` (singleton) + `CameraScreen` sudah handle:
- Permission check
- Permission request
- Fallback ke app settings kalau permanently denied
- Capture dari camera
- Pick dari gallery
- Save (ke SharedPreferences sebagai base64)
- Use (return XFile)

Saat create tiket, foto di-convert ke base64 dan disimpan di `Ticket.photoPath`. Ini akan diganti upload ke Supabase Storage.

### Comment system (existing)

Saat ini:
- ✅ List comment di TicketDetail
- ✅ Add comment (form input + button)
- ❌ Belum ada edit comment
- ❌ Belum ada delete comment
- ❌ Belum ada indikator "(diedit)"
- ❌ Belum ada attachment/foto di comment

### Filtering & search (existing)

TicketListPage punya 6 filter chip: All, Open, Assigned, InProgress, Done, Cancelled. Tidak ada search bar.

Notification tidak ada filter (All / Unread).

### Pagination (existing)

Saat ini **TIDAK ADA pagination**. Semua data diload sekaligus, ditampilkan via `ListView.builder`. Untuk project sekarang dengan data kecil, tidak masalah. Untuk Supabase nanti, akan diganti cursor-based + "Load More" (lihat section 12).

---

### Ringkasan yang perlu ditambah sesuai rancangan v3.0

| Fitur Baru | Existing | Keterangan |
|------------|----------|------------|
| Helpdesk role | ❌ | Tambah role baru, model, repository, dashboard widget |
| `pending_unassign` status | ❌ | Tambah enum value + visual di stepper |
| Helpdesk `is_available` toggle | ❌ | Tambah field di model + UI di profile |
| Helpdesk self-un-assign | ❌ | Flow baru |
| Admin un-assign / re-assign | ❌ (hanya assign) | Tambah 2 aksi baru |
| Edit ticket (user) | ❌ | Form sama kayak create, hanya saat `open` |
| Cancel ticket + alasan | ❌ | Dialog dengan textarea wajib |
| Edit comment + "(diedit)" | ❌ | Long-press menu atau icon edit |
| Delete comment | ❌ | Author only (admin tidak boleh) |
| Foto di comment (max 3) | ❌ | Tambah field attachments + UI |
| Log history page | ❌ | Tambah halaman baru + filter |
| Realtime updates | ❌ | Subscribe channel per entity |
| Cursor pagination + Load More | ❌ | Tambah di list tiket, notif, log agregat |
| Filter log Hari Ini/7/Semua | ❌ | Tambah di UI log history |
| Email login (bukan username) | ❌ | Migrasi AuthRepository |
| Helpdesk dashboard stats | ❌ | Tambah widget baru |
| Admin full update policy | ❌ | RLS belum ada (no backend) |
| Profil lengkap (statistik per role) | sebagian (avatar + role badge) | Tambah section statistik |

---

---

## 1. Arsitektur Target

```
┌──────────────────────────────────────────────────────────┐
│                      FLUTTER UI                          │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐      │
│  │  Login   │ │Dashboard │ │  Ticket  │ │  Profile │      │
│  │ Register │ │          │ │  Detail  │ │          │      │
│  │  Reset   │ │          │ │   List   │ │          │      │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──────────┘      │
│       │            │            │                          │
│  ┌────▼────────────▼────────────▼────────────────────┐     │
│  │        Riverpod Providers (State Management)      │     │
│  └────┬─────────────┬──────────────┬──────────────┬───┘     │
│       │             │              │              │         │
│  ┌────▼─────┐ ┌─────▼─────┐ ┌──────▼──────┐ ┌────▼─────┐   │
│  │AuthRepo  │ │TicketRepo │ │NotifRepo    │ │LogRepo   │   │
│  └────┬─────┘ └─────┬─────┘ └──────┬──────┘ └────┬─────┘   │
│       │             │              │              │         │
│       └─────────────┴──────┬───────┴──────────────┘         │
│                            │                                │
│                   ┌────────▼────────┐                       │
│                   │ Supabase Client │                       │
│                   │   + JWT header  │                       │
│                   └────────┬────────┘                       │
└────────────────────────────┼───────────────────────────────┘
                             │ HTTPS
                             │ Authorization: Bearer <jwt>
                             │
              ┌──────────────┼──────────────┐
              │              │              │
        ┌─────▼─────┐ ┌──────▼──────┐ ┌─────▼─────┐
        │ Supabase  │ │  Postgres   │ │  Storage  │
        │   Auth    │ │     DB      │ │  (foto)   │
        │           │ │  + RLS      │ │           │
        │ - login   │ │ + Triggers  │ │ - photo   │
        │ - JWT     │ │ + Functions │ │ - comment │
        │ - session │ │             │ │ - avatar  │
        └─────┬─────┘ └──────┬──────┘ └─────┬─────┘
              │               │              │
              └───────────────┴──────────────┘
                              │
                  auth.users (UUID) di-bridge
                  via users.auth_user_id
```

---

## 2. Role & Hak Akses

| Role      | Tanggung Jawab                                                       |
| --------- | -------------------------------------------------------------------- |
| `user`    | Bikin tiket, edit/cancel tiket sendiri, chat, statistik pribadi     |
| `admin`   | Assign tiket ke helpdesk, un-assign, monitoring global, chat         |
| `helpdesk`| Kerjakan tiket, konfirmasi selesai, request un-assign, chat         |

**Login:** semua role pakai **Supabase Auth** dengan **email + password**.

```
┌──────────────────┐
│  auth.users      │  ← Supabase Auth (login identity)
└────────┬─────────┘
         │ 1-to-1
         ▼
┌──────────────────┐
│  users           │  ← data tambahan: username, role, avatar (sebelumnya bernama `profiles`)
└────────┬─────────┘
         │ role = 'helpdesk'
         ▼
┌──────────────────┐
│  helpdesks       │  ← profil teknisi: name, phone, is_available, workload
└──────────────────┘
```

---

## 3. Status Tiket — State Machine

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
        ▲              admin approve
        │              ├──> open
        └──────       └──> reject (kembali ke assigned/in_progress)

   user.cancel (hanya dari status open):
        └────> cancelled (terminal, dengan cancelled_reason)
```

**Status yang ada:**
- `open` — tiket baru, belum di-assign
- `assigned` — sudah di-assign ke helpdesk, belum mulai kerja
- `in_progress` — helpdesk sedang mengerjakan
- `pending_unassign` — helpdesk minta dilepas, menunggu approval admin
- `done` — selesai (terminal)
- `cancelled` — dibatalkan user (terminal, dengan `cancelled_reason`)

**Trigger perubahan status:**

| Status change              | Trigger                              | Otomatis?  |
| -------------------------- | ------------------------------------ | :--------: |
| `→ open`                   | user create tiket                    | ✅         |
| `→ assigned`               | admin klik "Assign Helpdesk"         | ✅         |
| `→ in_progress`            | helpdesk buka tiket pertama kali     | ✅ (auto)  |
| `→ done`                   | helpdesk klik "Konfirmasi Selesai"   | ✅         |
| `→ cancelled`              | user klik "Cancel" + isi alasan      | ✅         |
| `→ pending_unassign`       | helpdesk klik "Request Un-assign"    | ✅         |
| `pending_unassign → open`  | admin approve                        | ✅         |
| `pending_unassign → assigned/in_progress` | admin reject           | ✅         |
| `assigned/in_progress → open` | admin un-assign                    | ✅         |
| `assigned/in_progress → assigned` (helpdesk beda) | admin re-assign     | ✅         |

---

## 4. Flow Autentikasi

```
┌─────────┐
│  Splash │
└────┬────┘
     │ cek auth.currentUser
     ├──> ada session ──> Dashboard (by role)
     │
     └──> tidak ada ──> Login Page
                              │
                              ▼
                        ┌────────────┐
                        │   Login    │
                        │ (email+    │
                        │  password) │
                        └─────┬──────┘
                              │ submit
                              ▼
                  ┌─────────────────────┐
                  │ AuthRepository.login│
                  └─────┬───────────────┘
                        │
                        ├─── gagal ──> tampilkan error
                        │
                        └─── sukses ──> load profile (role)
                                            │
                                            ▼
                                     ┌──────────────┐
                                     │  Dashboard   │
                                     │  (by role)   │
                                     └──────────────┘
```

**Session:** Supabase JWT, auto-persist di SharedStorage (dikelola SDK).

**Catatan:** Register flow belum ada untuk saat ini. Admin yang membuatkan akun via dashboard.

---

## 5. Flow Per-Role

### 5.1. User Flow

```
                         ┌─────────────────┐
                         │   Dashboard     │
                         │   (User)        │
                         │                 │
                         │ • Tiket saya    │
                         │ • Statistik     │
                         │   pribadi       │
                         └────────┬────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
                  ▼               ▼               ▼
           ┌────────────┐  ┌─────────────┐  ┌─────────────┐
           │ Tiket Saya │  │ Buat Tiket  │  │ Notifikasi  │
           │ List       │  │ (FAB)       │  │             │
           └─────┬──────┘  └─────────────┘  └─────────────┘
                 │ tap
                 ▼
           ┌──────────────────────┐
           │  Ticket Detail       │
           │  (User View)         │
           │                      │
           │  if status == open:  │
           │    [Edit] [Cancel]   │
           │                      │
           │  • Comments (chat)   │
           │  • [Add Comment]     │
           │    + foto (max 3)    │
           │  • Log History       │
           └──────────────────────┘
```

**Aksi user:**
- ✅ Create tiket (dengan foto via camera/gallery)
- ✅ Edit tiket — **hanya jika** `status == 'open'`
- ✅ Cancel tiket — **hanya jika** `status == 'open'`, wajib isi `cancelled_reason`
- ✅ Chat via comment (3 arah), bisa attach foto
- ✅ Edit comment sendiri (**unlimited window**), ada label "(diedit)"
- ❌ Tidak bisa edit/cancel setelah di-assign
- ✅ Toggle theme
- ✅ Lihat statistik pribadi
- ✅ Terima notifikasi
- ✅ Lihat log history

**Trigger notifikasi untuk user:**
- Tiket di-assign ke helpdesk
- Tiket selesai (done)
- Ada comment baru **dari helpdesk/admin** (tidak trigger notif ke admin dari komentar — lihat section 6.2)

---

### 5.2. Admin Flow

```
                         ┌─────────────────┐
                         │   Dashboard     │
                         │   (Admin)       │
                         │                 │
                         │ • Semua tiket   │
                         │ • Statistik     │
                         │   global        │
                         │ • Workload      │
                         │   per helpdesk  │
                         └────────┬────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
                  ▼               ▼               ▼
           ┌────────────┐  ┌─────────────┐  ┌─────────────┐
           │All Tickets │  │ Helpdesk    │  │ Notifikasi  │
           │List (admin)│  │ + workload  │  │             │
           └─────┬──────┘  └──────┬──────┘  └─────────────┘
                 │ tap            │
                 │                │
                 ▼                │
           ┌──────────────────────┐│
           │ Ticket Detail        ││
           │ (Admin View)         ││
           │                      ││
           │ if status == open:   ││
           │   [Assign Helpdesk]  ││  pilih helpdesk
           │                      ││  (filter: tersedia)
           │ if status ==         ││
           │   assigned/in_prog:  ││
           │   [Re-assign]        ││
           │   [Un-assign]        ││
           │                      ││
           │ if pending_unassign: ││
           │   [Approve] [Reject] ││
           │                      ││
           │ • Comments           ││
           │ • Log History        ││
           └──────────────────────┘│
                                   │
           ┌──────────────────────┐│
           │ Helpdesk Detail      │◄┘
           │ • Active tickets     │
           │ • Workload           │
           │ • is_available       │
           └──────────────────────┘
```

**Aksi admin:**
- ✅ Lihat **semua** tiket
- ✅ Filter tiket (by status, by user, by helpdesk)
- ✅ Assign tiket ke helpdesk — **hanya jika** `status == 'open'`
- ✅ Re-assign tiket ke helpdesk lain — saat `assigned` atau `in_progress`
- ✅ Un-assign tiket — saat `assigned` atau `in_progress`, kembali ke `open`
- ✅ Approve/reject un-assign request
- ❌ **TIDAK ADA** update status manual (semua via aksi: assign, un-assign, re-assign, helpdesk action)
- ✅ Chat via comment
- ✅ Lihat statistik global
- ✅ Lihat workload helpdesk
- ✅ Toggle theme
- ✅ Terima notifikasi (kecuali dari comment — lihat section 6.2)
- ✅ Lihat log history

**Trigger notifikasi untuk admin:**
- User bikin tiket baru
- Helpdesk request un-assign
- Helpdesk konfirmasi selesai
- ❌ **TIDAK** dapat notifikasi dari comment baru (admin cuma nimbrung, bukan "manajer comment")

**Kondisi admin memilih helpdesk saat assign:**
- Filter: `is_available = true`
- Sort by: jumlah tiket aktif paling sedikit (workload)
- Tampilkan di UI: nama, jumlah tiket aktif, status available

---

### 5.3. Helpdesk Flow

```
                         ┌─────────────────┐
                         │   Dashboard     │
                         │   (Helpdesk)    │
                         │                 │
                         │ • Tugas saya    │
                         │ • Workload      │
                         └────────┬────────┘
                                  │
                  ┌───────────────┼───────────────┐
                  │               │               │
                  ▼               ▼               ▼
           ┌────────────┐  ┌─────────────┐  ┌─────────────┐
           │ Tugas Saya │  │  Profile    │  │ Notifikasi  │
           │ List       │  │  + toggle   │  │             │
           └─────┬──────┘  │ is_available│  └─────────────┘
                 │ tap     └─────────────┘
                 │
                 ▼
           ┌──────────────────────┐
           │ Ticket Detail        │
           │ (Helpdesk View)      │
           │                      │
           │ if status==assigned: │
           │   (auto: in_progress)│  <── otomatis saat dibuka
           │                      │
           │ • Comments           │
           │ • [Add Comment]      │
           │   + foto (max 3)     │
           │ • [Mark as Done]     │  <── selesai
           │ • [Request Un-assign]│  <── dengan alasan
           │   + alasan           │
           │ • Log History        │
           └──────────────────────┘
```

**Aksi helpdesk:**
- ✅ Lihat tiket yang di-assign ke dia
- ✅ Otomatis `in_progress` saat pertama buka tiket (auto-trigger)
- ✅ Chat via comment
- ✅ Edit comment sendiri unlimited, label "(diedit)"
- ✅ **Konfirmasi selesai** → status `done`
- ✅ **Request un-assign** → status `pending_unassign`, wajib isi alasan, tunggu approval admin
- ✅ Toggle `is_available` di profil (kalau `false`, tidak dapat assignment baru)
- ✅ Toggle theme
- ✅ Lihat statistik pribadi
- ✅ Terima notifikasi
- ✅ Lihat log history

**Trigger notifikasi untuk helpdesk:**
- Di-assign tiket baru oleh admin
- Ada comment baru dari user/admin
- Request un-assign disetujui/ditolak admin

**Self-un-assign flow detail:**

```
Helpdesk di tiket assigned/in_progress
   │
   ▼
[Klik "Request Un-assign"]
   │
   ▼
┌─────────────────────────────────┐
│  Dialog: Form Request           │
│  • Alasan (wajib, min 5 char)  │
│  [Submit] [Cancel]              │
└────────┬────────────────────────┘
         │ submit
         ▼
   update tickets
     set status = 'pending_unassign',
         unassign_requested_by = helpdesk_id,
         unassign_requested_at = now(),
         unassign_reason = 'alasan'
   │
   ▼
   Notifikasi ke SEMUA admin:
     "Helpdesk X request un-assign tiket #abc dengan alasan: ..."
   │
   ▼
   Tunggu admin action
```

**Admin response ke un-assign request:**

```
Admin lihat notifikasi / buka tiket
   │
   ▼
┌────────────────────────────┐
│  [Approve]                 │  → status: open, id_helpdesk: NULL
│  [Reject]                  │  → status: kembali ke assigned/in_progress
│  + alasan reject (opsional)│
└────────┬───────────────────┘
         │
         ▼
   Notifikasi ke helpdesk:
     "Request un-assign disetujui/ditolak"
   │
   ▼
   Log history mencatat keputusan admin
```

---

## 6. Flow Notification

### 6.1. Karakteristik

| Aspek           | Notification                          | Log History                       |
| --------------- | ------------------------------------- | --------------------------------- |
| Granularitas    | Umum, template                        | Sangat detail, raw event          |
| Tipe pesan      | Pre-defined                           | Structured payload                |
| Read/unread     | ✅ Ada (mark as read)                 | ❌ Tidak (selalu full)            |
| Retention       | Dismissable (bisa dihapus)            | Permanent, tidak bisa dihapus     |
| Realtime        | ✅ Subscribe channel                  | ✅ Subscribe channel              |

### 6.2. Event Matrix (Final)

| Event                            | User | Admin | Helpdesk | Catatan                        |
| -------------------------------- | :--: | :---: | :------: | ------------------------------ |
| User bikin tiket baru            |      |  ✅   |          |                                |
| Admin assign ke helpdesk         |  ✅  |       |    ✅    |                                |
| Helpdesk buka tiket (in_progress)|  ✅  |       |    (auto)| Notif masuk-dashboard          |
| Ada comment baru (di tiket tsb)  |  ✅  |   ❌  |    ✅    | **Admin tidak dapat** dari comment |
| Helpdesk request un-assign       |      |  ✅   |    (auto)|                                |
| Admin approve un-assign          |      |       |    ✅    |                                |
| Admin reject un-assign           |      |       |    ✅    |                                |
| Helpdesk selesaikan tiket        |  ✅  |   ✅  |    (auto)|                                |
| Admin un-assign (kembali open)   |  ✅  |       |    ✅    | Helpdesk yg lama tetap dapat   |
| Admin re-assign (helpdesk ganti) |  ✅  |       | ✅ (baru)| Helpdesk lama juga dapat notif "tiket dilepas" |
| User edit tiket                  |      |   ✅  |    ✅    |                                |
| User cancel tiket                |      |   ✅  |          |                                |

### 6.3. Implementasi

- **Trigger:** Postgres trigger functions (auto-insert ke `notifications` saat event di tabel `tickets` atau `comments` berubah)
- **Disimpan di:** tabel `notifications`
- **Realtime:** subscribe channel `notifications:id_user=eq.{id}`
- **Mark as read:** update `is_read = true` (single atau bulk)

---

## 7. Flow Log History

### 7.1. Karakteristik

- **Lokasi:** halaman khusus per tiket + halaman agregat per user
- **Granularitas:** setiap perubahan (CRUD tiket, comment, status change, assignment, un-assign, cancel, edit, dll)
- **Aktor:** siapa yang melakukan (username + role)
- **Timestamp:** kapan
- **Detail:** apa yang berubah (before → after, atau summary text)
- **Pagination:** tampil semua per tiket, **filter periode** Hari Ini / 7 Hari / Semua

### 7.2. Event yang Dicatat

| Event                          | Data yang Dicatat                                         |
| ------------------------------ | --------------------------------------------------------- |
| `ticket.created`               | id_user, id_ticket, snapshot                              |
| `ticket.updated`               | id_user, id_ticket, fields_changed, before, after         |
| `ticket.cancelled`             | id_user, id_ticket, cancelled_reason                      |
| `ticket.assigned`              | id_user (admin), id_ticket, id_helpdesk                   |
| `ticket.reassigned`            | id_user, id_ticket, from_helpdesk, to_helpdesk            |
| `ticket.unassigned`            | id_user, id_ticket, from_helpdesk, reason                 |
| `ticket.unassign_requested`    | id_user (helpdesk), id_ticket, reason                     |
| `ticket.unassign_approved`     | id_user (admin), id_ticket                                |
| `ticket.unassign_rejected`     | id_user (admin), id_ticket, rejection_reason (opsional)   |
| `ticket.status_auto_changed`   | id_user, id_ticket, from_status, to_status                |
| `comment.added`                | id_user, id_ticket, id_comment, snippet                   |
| `comment.edited`               | id_user, id_comment, before_message, after_message       |
| `comment.deleted`              | id_user, id_comment, id_ticket                            |
| `attachment.uploaded`          | id_user, id_ticket atau id_comment, file_name             |
| `helpdesk.availability_changed`| id_user (helpdesk), from, to                              |

### 7.3. Tampilan per Tiket

```
┌────────────────────────────────────────┐
│  Log History — Tiket #abc123           │
├────────────────────────────────────────┤
│  [Hari Ini] [7 Hari] [Semua]          │  ← filter periode
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │ 14:32  user/budi                │  │
│  │        Created ticket            │  │
│  │        "Laptop nggak nyala"      │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ 14:45  user/budi                │  │
│  │        Updated description       │  │
│  │        "Laptop nggak nyala sama  │  │
│  │         sekali"                  │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │ 15:10  admin/eko                │  │
│  │        Assigned to helpdesk/udin │  │
│  └──────────────────────────────────┘  │
│  ... (semua event tampil)              │
└────────────────────────────────────────┘
```

---

## 8. Flow Profile

```
┌──────────────────────────────┐
│  Profile Page                │
│                              │
│  • Avatar                    │
│  • Username                  │
│  • Email                     │
│  • Role badge                │
│  • Statistik ringkas:        │
│    - User: tiket aktif/selesai│
│    - Admin: total tiket hari ini│
│    - Helpdesk: tiket selesai │
│  • [Edit Profile]            │
│  • [Change Password]         │
│  • (Helpdesk only)           │
│    Toggle is_available       │
│  • [Logout]                  │
└──────────────────────────────┘
```

---

## 9. Flow Statistik Dashboard (Per-Role)

### 9.1. User Stats

- Tiket per status: open / assigned / in_progress / done / cancelled
- Total tiket bulan ini
- Rata-rata waktu penyelesaian tiket saya

### 9.2. Admin Stats

- Tiket masuk hari ini / minggu ini
- Tiket per status (pie/bar chart)
- Tiket per helpdesk (workload bar)
- Rata-rata waktu penyelesaian
- Tiket belum di-assign (perlu action)

### 9.3. Helpdesk Stats

- Tiket aktif (assigned + in_progress)
- Tiket selesai (done)
- Tiket menunggu (assigned belum dibuka)
- Rata-rata waktu kerja per tiket

---

## 10. Flow Komentar (3 Arah)

```
┌──────────────────────────────────────────────────┐
│  Ticket Detail — Comments Section                │
│                                                  │
│  ┌─────────────────────────────────────────┐     │
│  │ [user1]                                 │     │
│  │ Udah aku restart berkali2               │     │
│  │ 📷 foto1.jpg 📷 foto2.jpg               │     │
│  │ 2 jam lalu                              │     │
│  └─────────────────────────────────────────┘     │
│  ┌─────────────────────────────────────────┐     │
│  │ [helpdesk/udin]                         │     │
│  │ Saya cek dulu ya                        │     │
│  │ (diedit) 1 jam lalu                     │     │
│  └─────────────────────────────────────────┘     │
│  ┌─────────────────────────────────────────┐     │
│  │ [admin/eko]                             │     │
│  │ Tolong prioritaskan ya                   │     │
│  │ 1 jam lalu                              │     │
│  └─────────────────────────────────────────┘     │
│                                                  │
│  ┌──────────────────────────────────────┐       │
│  │ [Type a comment...]                  │       │
│  │ 📎 [foto1] [foto2] [+ Tambah]       │       │  ← max 3 foto
│  │                       [Send]         │       │
│  └──────────────────────────────────────┘       │
└──────────────────────────────────────────────────┘
```

**Akses comment:**
- Semua role yang punya akses ke tiket bisa **baca & tulis** (3 arah)
- **Admin** hanya nimbrung, tidak manage comment orang lain
- **Edit comment:** author only, **unlimited window**
- **Hapus comment:** author only (admin **tidak** boleh hapus comment orang lain, sesuai poin 3)
- Edit indicator: label "(diedit)" di bawah message
- Max attachment: **3 foto per comment, 5 MB per foto**

**Tidak ada pagination untuk comments per tiket** (biasanya < 50, real-time harus langsung keliatan).

---

## 11. Flow Edit & Cancel Tiket (User)

### 11.1. Edit — hanya saat `status == 'open'`

```
Ticket Detail (status=open)
   │
   ├─> [Edit] button visible
   │
   ▼
┌────────────────────┐
│  Edit Ticket Form  │
│  (sama kayak create)│
└────────┬───────────┘
         │ save
         ▼
   update tickets set title=?, description=?, photo=?
     where id=? and status='open'
   (RLS enforce: only owner can update when status=open)
         │
         ├─> affected 1 row → sukses
         └─> affected 0 row → "Tiket sudah di-proses, tidak bisa diedit"
```

### 11.2. Cancel — hanya saat `status == 'open'`, dengan alasan

```
Ticket Detail (status=open)
   │
   ├─> [Cancel] button visible
   │
   ▼
┌──────────────────────────────┐
│  Confirmation Dialog         │
│  "Yakin cancel tiket?"        │
│  ┌──────────────────────────┐│
│  │ Alasan cancel (wajib)   ││
│  │ [textarea, min 5 char]  ││
│  └──────────────────────────┘│
│  [Ya, Cancel] [Tidak]        │
└────────┬─────────────────────┘
         │ ya
         ▼
   update tickets
     set status='cancelled',
         cancelled_reason=?,
         cancelled_at=now()
     where id=? and status='open'
   (RLS enforce: only owner can update when status=open)
```

---

## 12. Flow Pagination (UX Lengkap)

### 12.1. Strategi: Cursor-based + "Load More" Button

**Alasan pakai cursor-based** (bukan offset/page number):
- ✅ Supabase PostgREST support `?order=created_at.desc&limit=20&created_at=lt.{cursor}` out of the box
- ✅ Data tiket akan terus numpuk seiring waktu → offset bakal lemot
- ✅ Realtime insert tidak menyebabkan duplikat atau skip item
- ✅ Cocok untuk mobile (tidak perlu "loncat ke page 5")

**Alasan pakai "Load More" button** (bukan infinite scroll):
- ✅ Feedback visual jelas "ada lagi data di bawah"
- ✅ Kombinasi lebih baik dengan filter/search
- ✅ Hemat memori: Flutter render 20 item, bukan semua
- ✅ Cocok untuk list dense (bukan feed sosial)

### 12.2. UX per Konteks

| Konteks                          | Bentuk            | Default | Filter Tambahan              |
| -------------------------------- | ----------------- | :-----: | ---------------------------- |
| Daftar tiket (semua role)        | Load More button  | 20      | Status, helpdesk, search     |
| Notifikasi (semua role)          | Load More button  | 20      | "Belum Dibaca" tab           |
| Comments per tiket               | Tampilkan semua   | all     | - (biasanya < 50)            |
| Log history per tiket            | Tampilkan semua   | all     | Hari Ini / 7 Hari / Semua    |
| Log history agregat per user     | Load More button  | 20      | Filter by event_type         |
| Helpdesks list                   | Tampilkan semua   | all     | (biasanya < 50 helpdesk)     |

### 12.3. Visual "Load More"

```
┌────────────────────────────────────────┐
│  ... (20 tiket tertampil)              │
│                                        │
│         ┌─────────────────┐            │
│         │   Load More ▼   │            │  ← button
│         └─────────────────┘            │
│                                        │
│     Menampilkan 20 dari 47 tiket       │  ← info counter
└────────────────────────────────────────┘
```

**Behavior:**
- Tap button → fetch 20 berikutnya dengan cursor
- Tampilkan loading spinner di button saat fetch
- Button hilang kalau sudah tidak ada data lagi
- Counter update real-time

### 12.4. Default Page Size: 20

**Alasan:** Sweet spot antara "terlalu sering klik" (10) dan "scroll panjang" (50). Standar untuk Twitter, Instagram, Gmail, GitHub.

---

## 13. State Machine Ringkas

| Dari Status         | Aksi                | Trigger Oleh         | Ke Status           |
| ------------------- | ------------------- | -------------------- | ------------------- |
| (none)              | Create              | user                 | `open`              |
| `open`              | Assign              | admin                | `assigned`          |
| `assigned`          | Buka tiket          | helpdesk (auto)      | `in_progress`       |
| `in_progress`       | Mark as Done        | helpdesk             | `done`              |
| `open`              | Cancel              | user + alasan        | `cancelled`         |
| `assigned`/`in_progress` | Request un-assign | helpdesk + alasan | `pending_unassign`  |
| `pending_unassign`  | Approve             | admin                | `open`              |
| `pending_unassign`  | Reject              | admin                | `assigned`/`in_progress` (sesuai sebelumnya) |
| `assigned`/`in_progress` | Un-assign      | admin                | `open`              |
| `assigned`/`in_progress` | Re-assign      | admin                | `assigned` (helpdesk beda) |
| `assigned`/`in_progress` | Re-assign      | admin                | `in_progress` (helpdesk beda) |

---

## 14. Ringkasan Keputusan Final (untuk Laporan)

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

---

Dokumen ini adalah **single source of truth** untuk rancangan. Setiap perubahan → update file ini → baru implementasi.
