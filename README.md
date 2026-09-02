# Kanvas

Prototipe web-based image/poster generator untuk membantu bisnis lokal membuat materi promosi dengan hingga sepuluh arah kreatif yang berbeda.

## Menjalankan dengan Qwen lokal

Mode lokal memakai Qwen-Image-2512 melalui ComfyUI. Tidak diperlukan API key.

### 1. Siapkan ComfyUI dan model Qwen

1. Buka **ComfyUI Desktop** dan jalankan project ComfyUI Anda.
2. Buka **Workflow > Browse Templates**.
3. Cari dan buka template **Qwen-Image-2512**.
4. Unduh model yang diminta oleh template.

Pastikan empat file berikut tersedia di folder model ComfyUI:

```text
models/
├── diffusion_models/
│   └── qwen_image_2512_fp8_e4m3fn.safetensors
├── text_encoders/
│   └── qwen_2.5_vl_7b_fp8_scaled.safetensors
├── vae/
│   └── qwen_image_vae.safetensors
└── loras/
    └── Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors
```

Pada ComfyUI Desktop, shared model directory biasanya berada di:

```text
C:\Users\farre\AppData\Local\Comfy-Desktop\ComfyUI-Shared\models
```

Tes satu gambar langsung dari template terlebih dahulu. ComfyUI harus tetap terbuka dan dapat diakses melalui [http://127.0.0.1:8188](http://127.0.0.1:8188).

### 2. Jalankan Kanvas dalam mode lokal

Buka PowerShell baru pada folder proyek ini, lalu jalankan:

```powershell
$env:IMAGE_PROVIDER="comfyui"
$env:COMFYUI_URL="http://127.0.0.1:8188"
$env:COMFYUI_WIDTH="768"
$env:COMFYUI_HEIGHT="1024"
powershell -ExecutionPolicy Bypass -File .\server.ps1
```

Kemudian buka [http://localhost:8000](http://localhost:8000). Interface akan menampilkan **AI lokal aktif · Qwen-Image-2512** ketika koneksi berhasil.

Kanvas mengirim satu workflow untuk setiap agent yang dipilih, masing-masing dengan arahan kreatif dan seed berbeda. Paket gratis memilih satu agent, sedangkan akun Pro dapat memilih hingga sepuluh. Pengaturan default memakai Lightning 4-step dan batch size 1 agar lebih sesuai untuk RTX 3060 12 GB.

Qwen hanya membuat **key visual tanpa teks**. Nama brand, headline, dan call-to-action ditambahkan oleh aplikasi sebagai layer terpisah agar ejaannya tetap benar, dapat diedit tanpa generasi ulang, dan ikut digabungkan saat poster diunduh.

### Konfigurasi lokal opsional

Nama file atau resolusi dapat diubah sebelum server dijalankan:

```powershell
$env:COMFYUI_MODEL="qwen_image_2512_fp8_e4m3fn.safetensors"
$env:COMFYUI_TEXT_ENCODER="qwen_2.5_vl_7b_fp8_scaled.safetensors"
$env:COMFYUI_VAE="qwen_image_vae.safetensors"
$env:COMFYUI_LORA="Qwen-Image-2512-Lightning-4steps-V1.0-fp32.safetensors"
$env:COMFYUI_WIDTH="768"
$env:COMFYUI_HEIGHT="1024"
$env:COMFYUI_TIMEOUT_SECONDS="1800"
$env:COMFYUI_REFINE_DENOISE="0.38"
```

`COMFYUI_WIDTH` dan `COMFYUI_HEIGHT` menjadi acuan budget resolusi. Kanvas menurunkan ukuran final dari format yang dipilih: 4:5, 9:16, atau 1:1. `COMFYUI_REFINE_DENOISE` mengatur seberapa jauh variasi boleh berubah dari gambar sumber; nilai rendah lebih konsisten, sedangkan nilai tinggi lebih bebas.

Jika VRAM penuh, turunkan resolusi, tutup aplikasi yang memakai GPU, dan jangan menjalankan batch lebih dari satu.

## Menjalankan dengan OpenAI GPT Image

OpenAI adalah provider cloud utama dan menggunakan `gpt-image-2` secara default. ComfyUI/Qwen lokal tetap tersedia sebagai pilihan tanpa API key.

1. Buat API key di [OpenAI Platform](https://platform.openai.com/api-keys).
2. Atur provider dan API key pada terminal PowerShell yang sama, lalu jalankan server:

```powershell
$env:IMAGE_PROVIDER="openai"
$env:OPENAI_API_KEY="MASUKKAN_KEY_ANDA"
powershell -ExecutionPolicy Bypass -File .\server.ps1
```

3. Buka [http://localhost:8000](http://localhost:8000).

Input key disembunyikan dan hanya diberikan melalui environment variable kepada proses server. Key tidak ditulis ke source code, file konfigurasi, atau command history. Jangan menaruh key di `app.js`, `index.html`, README, atau repository Git.

Kualitas dapat diubah sebelum menjalankan launcher:

```powershell
$env:OPENAI_IMAGE_MODEL="gpt-image-2"
$env:OPENAI_IMAGE_QUALITY="medium"
powershell -ExecutionPolicy Bypass -File .\server.ps1
```

Pilihan kualitas adalah `auto`, `high`, `medium`, atau `low`; default aplikasi adalah `low` agar iterasi awal lebih hemat. Setiap agent yang dipilih menjalankan satu request image generation berbayar. Setiap refinement menambah satu request image edit. Sebagian organisasi mungkin harus menyelesaikan verifikasi sebelum dapat memakai model GPT Image.

Kanvas meminta key visual tanpa tulisan kepada model. Nama brand, headline, dan call-to-action tetap dibuat sebagai layer aplikasi agar teks tajam, mudah diubah, dan tidak bergantung pada kemampuan model mengeja.

Referensi resmi: [GPT Image 2](https://developers.openai.com/api/docs/models/gpt-image-2) dan [panduan image generation](https://developers.openai.com/api/docs/guides/image-generation).

## Mencoba NevaGate secara eksperimental

Mode NevaGate memakai model chat/vision untuk menulis ilustrasi SVG yang kemudian diamankan dan ditampilkan sebagai key visual. Ini **bukan** image generation raster: hasilnya berupa vector art, bukan foto seperti GPT Image atau Qwen Image. OpenAI dan ComfyUI tetap tersedia dan tidak dihapus.

Jalankan dengan input API key tersembunyi:

```powershell
powershell -ExecutionPolicy Bypass -File .\start-nevagate.ps1
```

Model default adalah `kimi-k3`. Model dapat diganti sebelum launcher dijalankan:

```powershell
$env:NEVAGATE_MODEL="claude-sonnet-5-b"
powershell -ExecutionPolicy Bypass -File .\start-nevagate.ps1
```

Pilihan yang terdeteksi pada deployment saat dokumentasi ini ditulis antara lain `kimi-k3`, `claude-sonnet-5-b`, dan `claude-opus-5-b`. Setiap agent yang dipilih menjalankan satu request Chat Completions. Model dapat menolak format SVG atau hanya mengembalikan teks; kegagalan tersebut akan ditampilkan pada kartu konsep dan tidak memengaruhi provider lain.

SVG dari model dibatasi ke elemen vector aman: tidak boleh memuat script, event handler, HTML, embedded image, atau URL eksternal. API key hanya diteruskan melalui environment variable dan tidak disimpan ke proyek.

## Menggunakan aplikasi

1. Masuk dengan akun awal `maya@rumahseduh.id` dan kata sandi `kanvasdemo`, atau klik **Daftar gratis** untuk membuat akun sendiri.
2. Akun baru dimulai dengan nol proyek. Buat proyek dari nol atau gunakan salah satu contoh di menu **Inspirasi**.
3. Tulis brief hingga 1000 karakter, atur teks poster dan logo PNG/JPG/JPEG opsional, lalu pilih warna, arah visual, format, kualitas, serta agent sebelum membuat gambar. Kosongkan field brand, headline, atau CTA bila elemen tersebut tidak diinginkan. Posisi awal logo dapat diminta di prompt dan logo dapat diseret langsung pada hasil.
4. Klik salah satu poster, lalu pilih **Simpan ke Library**.
5. Buka menu **Library** untuk melakukan editing. Pada mode lokal, gambar terpilih diunggah kembali ke input ComfyUI dan dipakai sebagai latent awal agar perubahan kecil tetap mempertahankan komposisi. Setiap refinement dibuat sebagai versi baru (`V2`, `V3`, dan seterusnya), sedangkan `Original` tetap terkunci.
6. Gunakan **Gunakan desain** untuk menetapkan konsep proyek sebagai hasil utama atau unduh versi yang dipilih. File PNG hasil unduhan sudah menggabungkan key visual dengan teks poster.
7. Klik profil di bagian bawah sidebar untuk mengubah nama, preferensi proyek baru, kata sandi, atau keluar dari akun.

Hasil generasi di workspace bersifat immutable: editing gambar tidak tersedia di sana.

## Akun dan database lokal

Kanvas membuat database lokal `data\kanvas.mdb` secara otomatis saat server pertama kali dijalankan. Database menyimpan pengguna, hash kata sandi PBKDF2-SHA256, sesi login, preferensi, status paket, catatan kredit, brand paket gratis, sinyal anti-abuse yang sudah di-hash, proyek, dan Library secara terpisah untuk setiap akun. Folder `data/` tidak dimasukkan ke Git.

Paket gratis memperoleh 11 kredit setiap minggu, maksimal satu generasi gambar 1MP/HD, tiga edit, satu agent, dan satu brand. Generasi 1MP memakai 2 kredit dan setiap edit memakai 3 kredit. Layera Pro (`plan_code` `premium`) memperoleh 200 kredit setiap bulan, dapat memilih hingga sepuluh agent, memakai brand tanpa batas, dan memilih 1MP (2 kredit), 2MP (4 kredit), atau 4MP (8 kredit) per gambar. Biaya edit tetap 3 kredit. Biaya atau batas provider AI tetap berlaku.

Pendaftaran lokal dilindungi CAPTCHA sekali pakai, pembatasan percobaan per alamat jaringan, maksimal tiga akun gratis per perangkat dalam 90 hari, pencatatan fingerprint yang di-hash, dan pembatasan sesi akun. Integrasi Google OAuth, pengiriman verifikasi email, dan verifikasi WhatsApp memerlukan provider serta kredensial production dan belum diaktifkan pada server lokal.

Microsoft Access Database Engine (provider `Microsoft.ACE.OLEDB.12.0`) harus tersedia pada Windows. Database ini ditujukan untuk penggunaan prototipe lokal melalui `localhost`, bukan untuk diekspos langsung ke internet.

Data proyek lama dari `localStorage` akan dipindahkan satu kali ke akun awal Maya setelah login pertama. Akun baru dimulai dengan workspace kosong.

## Mode public beta

Untuk berbagi sementara tanpa Cloudflare, gunakan [`TEMPORARY-PUBLIC.md`](TEMPORARY-PUBLIC.md). Mode ini membuka HTTP langsung lewat public IP dan port forwarding, jadi hanya cocok untuk demo singkat.

Untuk membuka aplikasi ke publik dengan HTTPS, gunakan mode proxy. Backend `server.ps1` tetap listen di `127.0.0.1`, sementara Caddy atau reverse proxy menerima traffic internet dan meneruskannya ke backend.

Panduan lengkap ada di [`PUBLIC-DEPLOYMENT.md`](PUBLIC-DEPLOYMENT.md). Jangan expose port backend `8000` atau `8001` langsung ke internet.

## Struktur

- `index.html` — halaman login/registrasi, dashboard, workspace, pengaturan akun, dan refinement drawer.
- `styles.css` — design system, layout responsif, dan arah visual poster.
- `app.js` — autentikasi, state proyek per akun, streaming hasil, seleksi, dan refinement.
- `account.ps1` — database lokal, password hashing, sesi, preferensi, serta API akun.
- `start-nevagate.ps1` — launcher eksperimen NevaGate dengan input API key tersembunyi.
- `server.ps1` — static server serta backend untuk OpenAI, NevaGate SVG eksperimental, atau ComfyUI/Qwen lokal.
- `assets/` — aset visual untuk contoh proyek.
- `generated/` — hasil gambar runtime; dibuat otomatis dan tidak dimasukkan ke Git.

## Catatan production

Mode public beta sudah memakai secure cookie, CSRF token, origin check HTTPS, security headers, Turnstile signup, rate limit dasar, dan proteksi file gambar runtime per akun. Untuk deployment production komersial, tetap migrasikan server dan database ke stack production, tambahkan email verification/reset password, distributed rate limiting, object storage private, job queue, monitoring, backup otomatis, dan payment subscription.
#   P r o j e k J e m s  
 