# eGFR Slope API Hosting (for Netlify)

This is the **local R backend** packaged for deployment so the Netlify site can call it.

## Files
- `egfr_slope_api.R` — Plumber API
- `run_egfr_slope_api.R` — entrypoint (binds to `0.0.0.0` and `$PORT`)
- `Dockerfile` — container build for Render/Railway/Fly.io/etc.

## Option A: Render (simple)
1. Create a new **Web Service** from this repo.
2. Choose **Docker** as the runtime.
3. Deploy — Render will build the Dockerfile.
4. Copy the public URL (e.g., `https://your-service.onrender.com`).

## Option B: Railway
1. Create a new **Service** from repo.
2. It will detect the Dockerfile and build.
3. Copy the public URL.

## Update Netlify HTML
Edit `Index_netlify.html` and set:
```
const EGFR_API_URL = "https://YOUR-API-URL/egfr-slope";
```

## Local Run (unchanged)
```
Rscript run_egfr_slope_api.R
```
