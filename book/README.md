# Kindle Book Project

This folder contains a scaffold for writing and exporting a Kindle-ready EPUB for KDP.

Contents:
- `manuscript/` — Markdown chapters and front/back matter
- `assets/` — Images (JPEG/PNG), under 2560px on longest side for inline images
- `styles/` — EPUB CSS (`ebook.css`) and title page HTML
- `metadata.yaml` — Book metadata used during build
- `build.ps1` — PowerShell script to build `build/book.epub`

Quick start:
1. Edit `metadata.yaml`.
2. Write chapters in `manuscript/chapters/` as `01.md`, `02.md`, etc.
3. Run `./build.ps1` in PowerShell. Output: `build/book.epub`.
4. Upload the EPUB to KDP.

Notes:
- Use `#` for chapter titles. Avoid page numbers or headers—Kindle handles navigation.
- For images: place in `assets/images/` and reference like `![Caption](../assets/images/figure01.jpg)`.
- Avoid fixed layout features; this template targets reflowable EPUB for KDP.




