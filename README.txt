DORTY ROAD COMMUNITY — SUPABASE CONNECTED APP

FILES
- index.html: updated static website using Supabase Auth and database APIs.
- drc-logo.jpeg: existing community badge, unchanged.
- supabase_integration_migration.sql: additive database migration for the app features.

IMPORTANT SETUP
1. In your existing Supabase project, open SQL Editor and run the entire supabase_integration_migration.sql file once. It adds membership fields, suggestions/settings tables, and secure RPC functions. It is designed to be re-runnable, but review any SQL error instead of ignoring it.
2. Your project URL and publishable key are configured in index.html. The publishable key is intended to be public. NEVER put a service_role/secret key in this file.
3. Open index.html through a static web host or local development server (recommended) rather than relying on localStorage.
4. Sign in with the admin account you created in Supabase. The existing profiles.role='admin' value is used by the server-side RLS checks.
5. In Supabase Authentication settings, set the Site URL and allowed redirect URLs to your hosted website URL so email confirmation and password reset can return to the app.

FEATURES
- Supabase email/password account registration and sign-in
- Membership code assigned server-side and uniquely across users/devices
- Member status review (pending/approved/rejected) for administrators
- Administrator-only dashboard and role management for existing accounts
- Community suggestions stored in Supabase
- Administrator-managed Admirer of the Month feature
- CSV export of member records

SECURITY NOTES
- Browser-side controls are not the security boundary; RLS and server-side RPC functions are.
- New membership requests start as pending.
- To grant another admin, that person must first have a Supabase Auth account/profile; then use the Trusted Administrators form.
- The first-admin role you previously assigned is not changed by this migration.
- This is a static app. Hosting may be free, but domain names and some providers can cost money.
