# Simplework – Kestra on Railway with AI Copilot

This folder contains a ready-to-deploy Kestra service tailored for Railway. It combines the streamlined setup from the original template (`kestra-railway/`) with the AI Copilot configuration that was previously only present in the root project.

## What you get
- Docker image based on `kestra/kestra:latest-lts-no-plugins` (lighter, without extra plugins), already wired with the expected entrypoint. You can override the `IMAGE_TAG` build arg if you need the full image.
- Writable directories for `/app/config`, `/app/flows`, and `/app/storage` so you can mount a Railway volume at `/app/storage`.
- `application.yaml` baked into the image, referencing environment variables for Postgres, authentication, public URL, and Gemini AI.

## How to use
1. **Build/Deploy**  
   Point your Railway service (or local `docker build`) to `simplework/`. The `Dockerfile` copies `application.yaml` and exposes ports `8080` (UI/API) and `8081` (metrics/health).

2. **Database variables**  
   Provide the Postgres connection via a single env var expected by `application.yaml`:
   - `DATABASE_URL` (JDBC-style, e.g. `jdbc:postgresql://host:port/db?sslmode=require`)

3. **Authentication and URL**  
   - `KESTRA_USERNAME` / `KESTRA_PASSWORD` – admin credentials for the UI.  
   - `PUBLIC_URL` – public Railway URL (e.g., `https://your-service.up.railway.app`).

4. **AI Copilot**  
   - `GEMINI_API_KEY` – Gemini key used by Kestra AI Copilot.  
   - Optional `GEMINI_MODEL` (defaults to `gemini-2.5-flash`).

5. **Storage**  
   Attach a Railway volume to `/app/storage` so executions and files persist across deploys.

6. **Optional flows**  
   If you want to ship seed flows, place them in `simplework/flows/` and uncomment the `COPY flows` line in the `Dockerfile`.

## Local smoke test
```bash
cd simplework
docker build -t simplework .
docker run --rm -p 8080:8080 -p 8081:8081 \
  -e KESTRA_PG_URL=jdbc:postgresql://host:5432/db \
  -e KESTRA_PG_USER=user \
  -e KESTRA_PG_PASSWORD=pass \
  -e GEMINI_API_KEY=your-key \
  -e PUBLIC_URL=http://localhost:8080/ \
  simplework
```
Remember to point the env vars to a real Postgres instance (e.g., Railway Postgres or a local container).
