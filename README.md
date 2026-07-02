# ⚡ VelocityIQ — The Used Car Profit Engine

An AI-powered reconditioning & inventory-intelligence demo for used-car dealerships.
Built as a **single, self-contained HTML file** with **zero external dependencies** — it runs
fully offline and is hosted 24/7 on GitHub Pages.

### 🔗 Live site
**https://vasanthvaidya.github.io/velocityiq/**

---

## ✨ Features

- **Recon Tracker** — live 5-stage pipeline (Mechanical → Detail → Photos → Pricing → Ready) with a per-second floorplan cost ticker, DELAY badges, and expandable stage history.
- **AI Decision Engine** — every unit shows *how* its front-line-ready date was predicted (work type, vendor history, queue load, day offset) with factor-weight bars; the Scan flow shows a live AI prediction preview + confidence.
- **Customer Match** — CRM-sourced buyer matches on Ready units (internal-use only, no buyer login).
- **GM Briefing** — AI morning brief with regenerate/typewriter animation.
- **Vendor Scorecards**, **Floorplan ROI calculator**, **User Roles**, **Billing**.
- **About** page explaining the product, the AI model, and the competitive edge.
- **Command palette** (`Ctrl`/`⌘ + K`), **localStorage persistence**, and **full mobile responsiveness**.

## 📁 Project structure

```
velocityiq.html      → the entire application (HTML + CSS + JS, one file)
index.html           → generated at deploy time from velocityiq.html (Pages landing page)
.github/workflows/
    deploy.yml       → GitHub Actions: auto-deploys to Pages on every push to main
serve-local.js       → optional local dev server with live-reload (NOT deployed)
README.md            → this file
```

> The deployed website contains **only** the static demo. `serve-local.js` and the helper
> scripts are development conveniences and are never shipped to the live site, so there are
> **no localhost dependencies** in production.

---

## 🚀 Run locally

**Option A — just open it** (no tools needed):

Double-click **`velocityiq.html`**. It works offline in any modern browser.

**Option B — local dev server with live-reload** (Node.js required):

```bash
node serve-local.js
# then open http://localhost:8080/
```

Editing `velocityiq.html` and saving auto-refreshes the browser.

---

## 🌐 Deployment (GitHub Pages)

This repo deploys automatically. **Every push to `main` publishes the live site** via GitHub Actions.

**How it works**

1. `.github/workflows/deploy.yml` triggers on push to `main` (or manual `workflow_dispatch`).
2. It copies `velocityiq.html` to `index.html` (the Pages landing page) into a `_site/` folder and adds `.nojekyll`.
3. It uploads the artifact and deploys to GitHub Pages.
4. The site goes live at `https://<username>.github.io/<repo>/`.

**One-time setup for a fresh fork/clone**

```bash
git clone https://github.com/VasanthVaidya/velocityiq.git
cd velocityiq
# In GitHub: Settings → Pages → Build and deployment → Source: "GitHub Actions"
git push origin main        # triggers the first deploy
```

**Update the live site**

```bash
git add -A
git commit -m "Update demo"
git push origin main        # auto-redeploys in ~1–2 minutes
```

Track deploys under the repo's **Actions** tab.

---

## ✅ Notes

- **Relative paths only** — the app is a single file with inline CSS/JS and emoji icons, so it works correctly under the `/velocityiq/` subpath with no absolute or CDN references.
- **No external requests** on load (no fonts, scripts, or images from URLs).
- **Not for production use** — this is a hackathon demo (VelocityIQ v1.0 · Solera Inventory+ · 2026).

## 👤 Credits

Proposed and designed by **Vasanth** for the **Solera Hackathon 2026**, built on Solera's
Inventory+ platform using the DealerSocket CRM data bridge.

