# Hermes CMS Tools — Pringland Article Management

## Tujuan
Hermes AI Agent menjadi asisten untuk CRUD artikel promo & update pembangunan di Pringland.com

## Database

**Supabase Project:** vfvgqdwrfotjyzoltqtm
**Table:** cms_posts

### Schema
\\\sql
cms_posts {
  id              UUID      PRIMARY KEY
  slug            TEXT      -- URL-friendly: promo-juni-2026
  title_id        TEXT      -- Judul Bahasa Indonesia
  title_en        TEXT      -- Judul English
  content_id      TEXT      -- Konten HTML/Markdown (Bahasa)
  content_en      TEXT      -- Konten HTML/Markdown (English)
  excerpt_id      TEXT      -- Ringkasan short (Bahasa)
  excerpt_en      TEXT      -- Ringkasan short (English)
  category        TEXT      -- blog | promo | update-proyek
  featured_image  TEXT      -- Image URL dari Supabase Storage
  tags            TEXT[]    -- Array: [ternak,investasi,promo]
  meta_title_id   TEXT      -- SEO title (Bahasa)
  meta_title_en   TEXT      -- SEO title (English)
  meta_description_id   TEXT -- SEO description (Bahasa)
  meta_description_en    TEXT -- SEO description (English)
  author_name     TEXT      -- Pring Land Team
  published_at    TIMESTAMP -- NULL = draft, datetime = terjadwal
  status          TEXT      -- published (belum ada draft workflow)
  progress_percent INT      -- 0-100 untuk update-proyek
  project_name    TEXT      -- Nama project: Purwakarta, Bogor, dll
  created_at      TIMESTAMP
  updated_at      TIMESTAMP
}
\\\

## Workflow

1. DRAFT — Hermes buat draft baru
2. REVIEW — User approve via chat
3. SCHEDULE — Sekarang atau jadwal datetime
4. PUBLISH — Live ke pringland.com

## API Access

Credentials di: D:\\pringland-2-refactor\\.env
\\\
VITE_SUPABASE_URL=https://vfvgqdwrfotjyzoltqtm.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbG...VCJ9...
SUPABASE_SERVICE_KEY=eyJhbG...VCJ9...
\\\

Service Key diperlukan untuk operasi write (INSERT/UPDATE/DELETE).

## Hermes Tools

### 1. Skill: pringland-article-crud
Load: skill_view(name="pringland-article-crud")

Kemampuan:
- listArticles(category?, status?, limit?) — list artikel
- getArticle(id) — detail artikel
- createDraft(data) — buat draft baru (status=draft)
- updateArticle(id, data) — update artikel
- publishArticle(id) — langsung publish
- scheduleArticle(id, datetime) — terjadwal publish
- uploadImage(file) — upload ke Supabase Storage

### 2. Cron Job (Optional)
- Auto-scrape dari sumber external → draft
- Auto-publish terjadwal

## Contoh Usage

// List promo articles
const promos = await listArticles({ category: promo, limit: 10 })

// Create draft
await createDraft({
  title_id: Promo Juni: Bonus Bibit Gratis,
  content_id: <p>Promo terbaru...</p>,
  category: promo,
  project_name: Purwakarta,
})

// Schedule publish
await scheduleArticle(id, 2026-06-15T09:00:00Z)

// Update progress pembangunan (update-proyek)
await updateArticle(id, {
  progress_percent: 75,
  title_id: Progress Pembangunan Juni - 75%,
})

## Status Values (saat ini)

| Value | Description |
|-------|-------------|
| published | Artikel live di website |

NOTE: Belum ada draft / pending — langsung publish. Kalau butuh workflow review, perlu extended schema.

## Revisi Terakhir

- 2026-06-09 — Validasi cms_posts table, add schema + workflow
