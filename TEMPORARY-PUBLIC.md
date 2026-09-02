# Layera Temporary Public Share

Panduan ini untuk membuka Layera sementara lewat public IP Spectrum tanpa Cloudflare dan tanpa domain.

Mode ini memakai HTTP biasa. Pakai hanya untuk demo singkat ke teman yang Anda percaya. Jangan pakai untuk password penting, data pelanggan asli, atau promosi publik jangka panjang.

## 1. Pastikan Router Sudah Forward Port

Di My Spectrum, forward TCP port `8000` ke IP lokal komputer Windows yang menjalankan server.

Contoh:

```text
External port: 8000
Internal port: 8000
Protocol: TCP
Device: komputer Windows Anda
```

## 2. Jalankan ComfyUI

Pastikan ComfyUI aktif di:

```text
http://127.0.0.1:8188
```

## 3. Jalankan Server Temporary Public

Buka PowerShell di folder proyek:

```powershell
$env:IMAGE_PROVIDER="comfyui"
$env:COMFYUI_URL="http://127.0.0.1:8188"
powershell -ExecutionPolicy Bypass -File .\start-temporary-public.ps1 -PublicHost "PUBLIC_IP_ANDA:8000"
```

Contoh:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-temporary-public.ps1 -PublicHost "123.45.67.89:8000"
```

Bagikan URL ini ke teman:

```text
http://PUBLIC_IP_ANDA:8000
```

## 4. Kalau Server Menolak Start

Jika muncul pesan akun demo Maya masih memakai password bawaan, jalankan server lokal dulu:

```powershell
powershell -ExecutionPolicy Bypass -File .\server.ps1
```

Masuk sebagai Maya, buka settings akun, ganti password, lalu hentikan server lokal dan jalankan mode temporary public lagi.

## 5. Setelah Selesai

- Tekan `Ctrl+C` di terminal server.
- Hapus atau disable port forwarding `8000` di My Spectrum.
- Jangan tinggalkan PC menyala dengan port publik terbuka lebih lama dari kebutuhan demo.
