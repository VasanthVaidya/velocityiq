# ⚡ VelocityIQ — The Used Car Profit Engine

An AI-powered reconditioning & inventory-intelligence demo for used-car dealerships.
Built as a **single, self-contained HTML file** with **zero external dependencies** — it runs
fully offline and is hosted 24/7 on GitHub Pages.

### 🔗 Live links

| Environment | Branch | URL |
| ----------- | ------ | --- |
| **Production** | `main` | **https://vasanthvaidya.github.io/velocityiq/** |
| **Staging** | `dev` | **https://vasanthvaidya.github.io/velocityiq/dev/** |

Both are live 24/7 and redeploy automatically when you push to their branch, so you can
develop on `dev` (its own link, shows a **STAGING** badge) without touching the demo your
manager opens on `main`.

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
    deploy-main.yml  → publishes main → gh-pages root  (production link)
    deploy-dev.yml   → publishes dev  → gh-pages /dev/  (staging link)
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

## 🌐 Deployment (GitHub Pages · two environments)

This repo publishes **two independent live sites** from the **same repo**, using the
`gh-pages` branch with per-branch subfolders:

| Branch | Deploys to (gh-pages) | Live URL |
| ------ | --------------------- | -------- |
| `main` | `/` (root) | https://vasanthvaidya.github.io/velocityiq/ |
| `dev`  | `/dev/` | https://vasanthvaidya.github.io/velocityiq/dev/ |

**How it works**

1. Pushing **`main`** runs `deploy-main.yml` → builds `index.html` from `velocityiq.html`
   and publishes it to the **root** of the `gh-pages` branch (it never touches `/dev`).
2. Pushing **`dev`** runs `deploy-dev.yml` → publishes to the **`/dev/`** subfolder and
   stamps a **STAGING** badge on the page.
3. GitHub serves the `gh-pages` branch, so both URLs stay live 24/7 and each redeploys on
   its own push — completely independently.

**One-time setup** (already done for this repo; needed only on a fresh fork):

```
GitHub → Settings → Pages → Build and deployment
  Source: Deploy from a branch
  Branch: gh-pages   Folder: / (root)   → Save
```

**Work on the staging branch**

```bash
git checkout dev
# edit velocityiq.html …
git add -A
git commit -m "Try something new"
git push origin dev         # → redeploys ONLY the /dev/ link in ~1–2 min
```

**Promote staging to production** when you're happy with it:

```bash
git checkout main
git merge dev
git push origin main        # → redeploys the main link
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

