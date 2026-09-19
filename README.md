# Layera

Layera adalah web-based image/poster generator untuk membuat materi promosi bisnis. Backend Node.js menggunakan Replicate sebagai satu-satunya provider gambar, dengan model `black-forest-labs/flux-2-pro`.

## Kebutuhan

- Node.js 20.9 atau lebih baru.
- Token API Replicate dengan billing yang aktif.
- Proyek Supabase dengan URL, publishable key, dan secret key.
- Persistent disk untuk `generated/` apabila aplikasi dideploy.

## Menjalankan secara lokal

1. Salin `.env.example` menjadi `.env` apabila file `.env` belum ada.
2. Isi token pada `.env`:

   ```dotenv
   REPLICATE_API_TOKEN=isi_di_environment_vercel
   SUPABASE_URL=https://project-ref-anda.supabase.co
   SUPABASE_PUBLISHABLE_KEY=sb_publishable_isi_key_anda
   SUPABASE_SECRET_KEY=sb_secret_isi_key_anda
   ```

3. Install dependency dan jalankan server:

   ```text
   npm install
   npm start
   ```

4. Buka `http://localhost:8000`.

Di Windows, `start-node.cmd` dapat dipakai sebagai launcher. Token hanya dibaca oleh backend; jangan menaruh token di `app.js`, `index.html`, Git, atau kode browser.

## Cara kerja gambar

- Generate memakai model resmi `black-forest-labs/flux-2-pro` melalui Replicate Predictions API.
- Pilihan kualitas Layera dipetakan ke resolusi Flux 2 Pro: 1MP, 2MP, atau 4MP.
- Logo di-resize di browser, latar solidnya dihapus, lalu dipakai sebagai overlay dan tidak dikirim ke Replicate. Area di belakang logo dianalisis otomatis; preview dan file ekspor memilih bayangan atau pelat kontras terang/gelap tanpa mengubah warna identitas logo. Setiap gambar referensi yang memang dikirim ke API selalu dirotasi sesuai metadata, di-resize ke sekitar 1MP, dan dikompresi di bawah 1 MB oleh backend sebelum menjadi data URI.
- Hasil Replicate langsung diunduh ke `generated/`, karena URL output provider tidak permanen.
- Edit dari Library mengirim gambar sebelumnya melalui `input_images` dan menyimpan hasilnya sebagai versi baru.
- Teks poster tetap dirender oleh browser sebagai layer tajam. Field brand, headline, atau CTA yang kosong tidak diganti dengan teks contoh.
- Sepuluh behavioral agent memakai kontrak visual yang eksklusif: human narrative, kinetic impact, modular explainer, catalog matrix, macro craft, bold diptych, spatial journey, mixed collage, premium sculpture, dan surreal scale. Masing-masing memiliki komposisi, medium, copy zone, serta larangan kemiripan yang berbeda.

## Akun dan penggunaan

Akun baru dimulai dengan nol proyek. Tiga contoh tersedia di menu **Inspirasi**: Kampanye Kopi Gula Aren, Peluncuran Lunea Skincare, dan Koleksi Raya 2026.

Paket gratis memperoleh 11 kredit setiap minggu, maksimal satu generasi 1MP, tiga edit, satu agent, dan satu brand. Generasi memakai 2 kredit dan setiap edit memakai 3 kredit.

Paket Pro memperoleh 200 kredit per bulan, dapat memilih hingga sepuluh agent dan kualitas 1MP, 2MP, atau 4MP. Generate memakai 2, 4, atau 8 kredit berdasarkan kualitas; biaya edit tetap 3 kredit.

CAPTCHA masih dinonaktifkan. Backend tetap menerapkan rate limit signup/login, batas akun per perangkat, cookie HttpOnly/SameSite, CSRF, pemeriksaan origin, batas ukuran request, dan proteksi file hasil per pengguna.

## Penyimpanan

Supabase Auth menjadi sumber identitas untuk registrasi, login, perubahan email, nama profil, dan kata sandi. Supabase Postgres menyimpan state aplikasi—sesi Layera, preferensi, usage/kredit, proyek, Library, dan metadata file—pada tabel privat `layera_app_store`.

Browser tidak menerima `SUPABASE_SECRET_KEY`; seluruh akses database dan administrasi Auth berjalan di backend Node. Adapter state saat ini memakai cache dengan satu baris JSONB, sehingga jalankan satu instance Node untuk private beta. Sebelum horizontal scaling, normalisasi state menjadi tabel per entitas atau tambahkan transaksi/locking. File hasil gambar masih disimpan di `generated/` dan memerlukan persistent disk atau private object storage.

`npm run migrate:supabase` adalah alat migrasi satu kali dari `data/node-store.json`. Script akan menolak target yang sudah berisi data kecuali `MIGRATION_OVERWRITE=true` diberikan secara eksplisit.

## Deployment

Panduan environment variable, Docker, HTTPS, dan persistent disk tersedia di:

- [NODE-DEPLOYMENT.md](NODE-DEPLOYMENT.md)
- [PUBLIC-DEPLOYMENT.md](PUBLIC-DEPLOYMENT.md)

Untuk deployment production, setidaknya isi:

```dotenv
NODE_ENV=production
HOST=0.0.0.0
PORT=8000
PUBLIC_ORIGIN=https://domain-anda.example
REPLICATE_API_TOKEN=isi_di_environment_vercel
SUPABASE_URL=https://project-ref-anda.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_isi_key_anda
SUPABASE_SECRET_KEY=sb_secret_isi_key_anda
GENERATED_DIR=/data/generated
```

Jalankan satu instance selama adapter state masih memakai satu dokumen JSONB. Tambahkan verifikasi/reset email, distributed rate limiting, backup, monitoring, job queue, dan payment verification sebelum peluncuran komersial.

## Struktur utama

- `server.js` — HTTP server, autentikasi, akun, kredit, state proyek, dan endpoint generate/refine.
- `lib/supabase.js` — adapter Supabase Auth dan state aplikasi di Postgres.
- `lib/replicate.js` — integrasi Flux 2 Pro, resize input, polling, validasi output, dan penyimpanan file.
- `lib/creative-agents.js` — definisi sepuluh behavioral agent dan kontrak pembeda visualnya.
- `supabase/schema.sql` — tabel privat yang dibutuhkan backend.
- `scripts/` — konfigurasi dan migrasi Supabase.
- `app.js` — frontend, state UI, streaming hasil, seleksi, dan refinement.
- `index.html` dan `styles.css` — markup dan tampilan aplikasi.
- `tests/` — pengujian resize dan kontrak Replicate.
- `Dockerfile` — image deployment Node.
- `start-node.cmd` — launcher Windows.

## Verifikasi

```text
npm run check
npm test
```

Endpoint kesehatan tersedia di `GET /api/health`. Ketika token telah diisi, respons akan menampilkan provider `replicate`, model `black-forest-labs/flux-2-pro`, dan `configured: true`.
