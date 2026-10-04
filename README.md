# EZ Lineup

Phone app for keeping a youth basketball roster and scorebook.

The app in `web/` is the current version. It uses the same Supabase project as Field Commander, with its own score tables, and you sign in with the same email and password. Vienna 6th’s 2025–26 season (eight games) is already loaded.

The older Cloudflare app is still in `frontend/` and `api/` until this version is the one on your phone.

## Run locally

```bash
cd web
cp .env.example .env.local
# fill in the Supabase URL and publishable key
npm install
npm test
npm run dev
```

Open http://localhost:5173

## Deploy

Point a Vercel project at the `web` directory. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`, then deploy.
