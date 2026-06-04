# Environment & Configuration Setup

> **Status:** Final, siap masuk laporan
> **Tanggal:** 2026-06-03
> **Tujuan:** Dokumentasi konfigurasi environment variables untuk project UTS Mobile

---

## 1. File `.env`

Project ini menggunakan `flutter_dotenv` untuk mengelola credentials. File `.env` berada di **root project** (sama level dengan `pubspec.yaml`).

### 1.1. Template `.env`

```env
# ============================================
# Supabase Project Configuration
# ============================================

# Project URL (TANPA /rest/v1/ di belakang!)
# Didapat dari: Supabase Dashboard → Settings → API → Project URL
SUPABASE_URL=https://{project-ref}.supabase.co

# Anon public key (JWT, aman untuk di-expose ke client)
# Didapat dari: Supabase Dashboard → Settings → API → Project API Keys → anon public
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 1.2. ⚠️ PENTING: Format SUPABASE_URL

```env
# ❌ SALAH — ada /rest/v1/ di belakang
SUPABASE_URL=https://xxx.supabase.co/rest/v1/

# ✅ BENAR — tanpa /rest/v1/
SUPABASE_URL=https://xxx.supabase.co
```

**Alasan:**
- `Supabase.initialize()` Expect URL **tanpa** `/rest/v1/`
- Library `supabase_flutter` otomatis menambahkan prefix `/rest/v1/`, `/auth/v1/`, `/storage/v1/`, `/realtime/v1/` sesuai service yang dipanggil
- Kalau URL ada `/rest/v1/`, akan jadi double prefix → `https://xxx.supabase.co/rest/v1/rest/v1/tickets` → 404

**Contoh .env project saat ini:**

```env
SUPABASE_URL=https://brkylvdfffjmfaiebgcf.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### 1.3. Cara Mendapatkan Credentials

1. Buka [supabase.com/dashboard](https://supabase.com/dashboard)
2. Pilih project UTS Mobile
3. Sidebar kiri → **Settings** (ikon ⚙️)
4. Klik **API**
5. Di section "Project API Keys":
   - **Project URL** → copy ke `SUPABASE_URL`
   - **anon public** → copy ke `SUPABASE_ANON_KEY`
   - ⚠️ **JANGAN** copy `service_role` key (bukan untuk client!)

### 1.4. Keamanan

| Item                  | Status         | Keterangan                                       |
| --------------------- | -------------- | ------------------------------------------------- |
| `.env` di `.gitignore` | ✅ WAJIB        | Supaya tidak ter-commit ke Git                   |
| `anon_key` di app     | ✅ Aman         | Dilindungi RLS di database                       |
| `service_role` di app | ❌ DILARANG    | Bypass RLS, hanya untuk server-side/admin       |
| File `.env` di bundle | ⚠️ Tetap ada   | Di-bundle ke APK/IPA, tapi tidak masalah karena RLS |

---

## 2. Konfigurasi di `pubspec.yaml`

Supaya `.env` ter-bundle sebagai asset:

```yaml
flutter:
  uses-material-design: true

  assets:
    - .env
```

⚠️ Setiap kali mengubah `pubspec.yaml`, jalankan:
```bash
flutter pub get
```

---

## 3. Inisialisasi di `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Load .env
  await dotenv.load(fileName: ".env");

  // 2. Inisialisasi Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      initialRoute: AppConstants.routeSplash,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
```

---

## 4. Cara Pakai di Repository

### 4.1. Supabase Client (global singleton)

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class TicketRepository {
  final _supabase = Supabase.instance.client;

  Future<List<Ticket>> getTickets() async {
    // Library otomatis tambah prefix /rest/v1/
    final data = await _supabase
        .from('tickets')
        .select('*')
        .order('created_at', ascending: false);
    return data.map((e) => Ticket.fromMap(e)).toList();
  }
}
```

### 4.2. URL yang di-resolve

Kalau `SUPABASE_URL` di `.env` adalah `https://brkylvdfffjmfaiebgcf.supabase.co`:

| Pemanggilan                                      | Full URL                                                                  |
| ------------------------------------------------ | ------------------------------------------------------------------------- |
| `_supabase.from('tickets').select()`              | `https://brkylvdfffjmfaiebgcf.supabase.co/rest/v1/tickets`                |
| `_supabase.auth.signInWithPassword(...)`         | `https://brkylvdfffjmfaiebgcf.supabase.co/auth/v1/token?grant_type=password` |
| `_supabase.storage.from('avatars').upload(...)`   | `https://brkylvdfffjmfaiebgcf.supabase.co/storage/v1/object/avatars/...`   |
| `_supabase.channel('tickets').subscribe()`        | `wss://brkylvdfffjmfaiebgcf.supabase.co/realtime/v1/websocket`              |

**Library yang handle prefix otomatis**, kita cukup panggil method-nya.

---

## 5. Base URL untuk Dokumentasi API

Di `API.md`, semua endpoint ditulis dengan **path relatif** (misal: `/rest/v1/tickets`). Asumsinya:

```
Base URL: https://{SUPABASE_PROJECT_REF}.supabase.co
Contoh:   https://brkylvdfffjmfaiebgcf.supabase.co
```

Full URL untuk setiap endpoint adalah:
```
{Base URL}{path dari dokumentasi}
```

Contoh:
- `/rest/v1/tickets?status=eq.open` → `https://brkylvdfffjmfaiebgcf.supabase.co/rest/v1/tickets?status=eq.open`
- `/auth/v1/token?grant_type=password` → `https://brkylvdfffjmfaiebgcf.supabase.co/auth/v1/token?grant_type=password`

---

## 6. Testing Manual dengan curl

```bash
# Get all tickets
curl -X GET 'https://brkylvdfffjmfaiebgcf.supabase.co/rest/v1/tickets?select=*' \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Get with filter
curl -X GET 'https://brkylvdfffjmfaiebgcf.supabase.co/rest/v1/tickets?status=eq.open' \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Login
curl -X POST 'https://brkylvdfffjmfaiebgcf.supabase.co/auth/v1/token?grant_type=password' \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'
```

---

## 7. Supabase Service Path Reference

| Service     | Path Prefix  | Method yang handle                  |
| ----------- | ------------ | ----------------------------------- |
| REST/DB     | `/rest/v1/`  | `supabase.from(...).select()` dll   |
| Auth        | `/auth/v1/`  | `supabase.auth.signInWithPassword()` dll |
| Storage     | `/storage/v1/`| `supabase.storage.from(...).upload()` dll |
| Realtime    | `/realtime/v1/` | `supabase.channel(...).subscribe()` |

⚠️ **Semua path di atas ditambahkan otomatis oleh `supabase_flutter` package.** Kamu tidak perlu menulis prefix-nya secara manual.

---

## 8. Checklist Setup

- [ ] Buat project di [supabase.com](https://supabase.com)
- [ ] Copy **Project URL** dan **anon public key** dari Settings → API
- [ ] Buat file `.env` di root project (template di section 1.1)
- [ ] Isi `SUPABASE_URL` **TANPA** `/rest/v1/`
- [ ] Isi `SUPABASE_ANON_KEY`
- [ ] Tambahkan `.env` ke `.gitignore`
- [ ] Daftarkan `.env` sebagai asset di `pubspec.yaml`
- [ ] Jalankan `flutter pub get`
- [ ] Setup inisialisasi di `main.dart` (template di section 3)
- [ ] Test koneksi: `flutter run` dan lihat log

---

**Dokumen ini bagian dari [rancangan API](./API.md), [flow](./flow.md), dan [ERD](./erd.md).**
