# Layera Public Deployment

Mode publik dibuat untuk private beta lewat HTTPS proxy. Backend PowerShell tetap berjalan di `127.0.0.1`, lalu Caddy atau Cloudflare Tunnel yang menerima traffic internet.

Jangan forward port backend `8000` atau `8001` langsung ke internet.

## Rekomendasi Topologi

```text
Internet -> HTTPS Caddy/Cloudflare Tunnel -> 127.0.0.1:8001 -> server.ps1 -> ComfyUI 127.0.0.1:8188
```

Untuk Spectrum, port forward yang disarankan adalah TCP `80` dan `443` ke komputer Windows yang menjalankan Caddy. Port `8000`/`8001` tetap private.

## Yang Dibutuhkan

- Domain atau subdomain, misalnya `app.domainanda.com`.
- DNS `A` record mengarah ke public IP Spectrum Anda.
- Cloudflare Turnstile site key dan secret key untuk domain tersebut.
- Caddy terpasang di Windows, atau Cloudflare Tunnel bila tidak ingin membuka port router.
- ComfyUI tetap berjalan di komputer yang sama bila memakai Qwen lokal.
- Password akun demo Maya sudah diganti sebelum public mode dinyalakan.

Catatan: IP Spectrum bisa berubah. Untuk penggunaan serius, pakai dynamic DNS atau tunnel. Cek juga kebijakan internet provider Anda sebelum menjalankan layanan publik dari koneksi rumah.

## Menjalankan Backend Publik

Buka PowerShell di folder proyek:

```powershell
$env:TURNSTILE_SITE_KEY="SITE_KEY_DARI_CLOUDFLARE"
$env:TURNSTILE_SECRET_KEY="SECRET_KEY_DARI_CLOUDFLARE"
$env:IMAGE_PROVIDER="comfyui"
$env:COMFYUI_URL="http://127.0.0.1:8188"
powershell -ExecutionPolicy Bypass -File .\start-public.ps1 -PublicOrigin "https://app.domainanda.com"
```

Backend akan listen di `127.0.0.1:8001`. Itu sengaja, supaya backend tidak bisa ditembak langsung dari internet.

## Menjalankan Caddy

Set environment variable untuk host publik:

```powershell
$env:LAYERA_PUBLIC_HOST="app.domainanda.com"
$env:ACME_EMAIL="email-anda@example.com"
caddy run --config .\Caddyfile.example
```

Setelah Caddy berhasil mendapat sertifikat HTTPS, buka:

```text
https://app.domainanda.com
```

## Checklist Sebelum Dibagikan

- Router forward TCP `80` dan `443` ke PC, bukan `8000` atau `8001`.
- Windows Firewall mengizinkan Caddy pada port `80` dan `443`.
- `http://localhost:8001/api/health` hanya bisa dibuka dari komputer server.
- `https://app.domainanda.com/api/health` bisa dibuka dari internet.
- Signup menampilkan Cloudflare Turnstile, bukan CAPTCHA matematika lokal.
- Akun demo `maya@rumahseduh.id` tidak lagi memakai password `kanvasdemo`.
- Database `data\kanvas.mdb` sudah dibackup berkala.

## Batasan Yang Masih Perlu Diingat

Versi ini sudah menambah secure cookie, CSRF token, public origin check, security headers, Turnstile signup, rate limit login/signup, dan proteksi gambar runtime per akun saat public mode aktif.

Untuk benar-benar production komersial, backend PowerShell dan Microsoft Access masih perlu diganti ke backend/web server production, PostgreSQL atau managed database, email verification/reset password, object storage private, job queue, backup otomatis, monitoring, dan payment subscription.
