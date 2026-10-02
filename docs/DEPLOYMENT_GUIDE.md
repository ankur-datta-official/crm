# Vercel deployment

This project runs on Next.js 16 with PostgreSQL, Prisma, and Better Auth. The old Supabase Auth and Storage deployment instructions do not apply to this branch.

## Before deploying

1. Provision a reachable PostgreSQL database. `127.0.0.1` in `DATABASE_URL` will not work from Vercel.
2. Run the checked-in Prisma migrations against that database from a trusted environment: `npx prisma migrate deploy`. Back up an existing database first.
3. Add the environment variables below to the Vercel project for the appropriate environment. Keep secrets server-only.
4. Import the GitHub repository as a Next.js project and use the repository's default `npm install` and `npm run build` commands. The build script generates the Prisma client.
5. Redeploy after changing environment variables. Test `/api/health/prisma`, authentication, and the main CRM pages.

## Required environment variables

```text
DATABASE_URL=postgresql://...  # remote database reachable from Vercel
NEXT_PUBLIC_APP_URL=https://your-domain.example
BETTER_AUTH_URL=https://your-domain.example
BETTER_AUTH_SECRET=<long random secret>
AUTH_SECRET=<long random secret>
NEXTAUTH_URL=https://your-domain.example
AUTH_PROVIDER=betterauth
NEXT_PUBLIC_AUTH_PROVIDER=betterauth
OPEN_ACCESS_ENABLED=false
NEXT_PUBLIC_OPEN_ACCESS_ENABLED=false
```

Set both open-access variables to `true` only if the intended deployment is the shared, login-free workspace. Use the same public origin for the three URL variables and configure them for each preview or production environment that needs to work.

Email features require `RESEND_API_KEY` and `RESEND_FROM_EMAIL`, or the SMTP settings in `.env.example`. Scheduled reminders additionally require `CRON_SECRET` and a configured scheduler.

## File uploads on Vercel

The current avatar and document storage implementation writes to local directories (`lib/storage/local.ts`). Vercel functions do not provide persistent writable storage for those files. Deploying the app to Vercel will not make uploaded files durable; use a persistent object storage implementation before enabling avatar or document uploads in production. The VPS deployment guide remains appropriate if local filesystem storage is required.
