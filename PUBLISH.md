# Publish the VelocityIQ demo as a shareable link

Goal: a single URL you can send your manager that **auto-updates every time you push**.
Hosting is **GitHub Pages** — free, HTTPS, no server to run.

Your repo is already git-initialized and committed, with an auto-deploy workflow
(`.github/workflows/deploy.yml`). You just need to connect it to GitHub once.

---

## One-time setup (about 2 minutes)

1. **Create an empty repo** on GitHub:
   https://github.com/new → name it **`velocityiq`** → **Public** →
   **do NOT** add a README/.gitignore/license → **Create repository**.

2. **Push** from this folder (replace `YOURNAME`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\publish-to-github.ps1 -User YOURNAME -Repo velocityiq
   ```

3. Wait ~1–2 minutes for the first deploy (watch it at
   `https://github.com/YOURNAME/velocityiq/actions`).

### ✅ Your shareable link
```
https://YOURNAME.github.io/velocityiq/
```
Send that to your manager. It works on any device, no install.

---

## Pushing updates (auto-reflected on the link)

Any time you change `velocityiq.html`, publish it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\publish-to-github.ps1 -Update "what changed"
```

GitHub rebuilds and the **same link** shows your update in ~1 minute.
(Ask viewers to hard-refresh — Ctrl+F5 — if they had it open.)

> Prefer manual git? `git add -A; git commit -m "update"; git push` does the same thing.

---

## First push asks for login?
A browser window / prompt will ask you to sign in to GitHub (or paste a
Personal Access Token). That authorizes the push from this machine — one time only.

---

## Need an INSTANT link right now (no GitHub)?
Go to **https://app.netlify.com/drop** and drag `velocityiq.html` onto the page.
You get a public URL in seconds. Note: that link is a **one-off snapshot** — it does
**not** auto-update on push. Use GitHub Pages (above) for the auto-updating link.

