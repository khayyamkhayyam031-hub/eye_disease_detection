-- Eye Disease Detection: Supabase backend setup
-- Run once in the Supabase dashboard → SQL Editor.
-- The app only uses the anon/publishable key; all access is protected by RLS.

-- 1. History table ----------------------------------------------------------
create table if not exists public.history (
  id              bigint generated always as identity primary key,
  user_id         uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  client_id       uuid not null unique,          -- generated on the phone (idempotent uploads)
  predicted_label text not null
                  check (predicted_label in ('cataract','diabetic_retinopathy','glaucoma','normal')),
  confidence      real not null check (confidence >= 0 and confidence <= 1),
  probabilities   jsonb not null default '{}'::jsonb,
  image_path      text not null,                 -- storage path {user_id}/{client_id}.jpg
  created_at      timestamptz not null default now()
);

create index if not exists history_user_created_idx
  on public.history (user_id, created_at desc);

alter table public.history enable row level security;

drop policy if exists "history select own" on public.history;
create policy "history select own" on public.history
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "history insert own" on public.history;
create policy "history insert own" on public.history
  for insert to authenticated with check (auth.uid() = user_id);

-- Needed only so that retried uploads (upsert on client_id) succeed.
drop policy if exists "history update own" on public.history;
create policy "history update own" on public.history
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "history delete own" on public.history;
create policy "history delete own" on public.history
  for delete to authenticated using (auth.uid() = user_id);

-- 2. Private storage bucket for scan images ---------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('scans', 'scans', false, 2097152, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = 2097152, allowed_mime_types = array['image/jpeg'];

drop policy if exists "scans select own" on storage.objects;
create policy "scans select own" on storage.objects
  for select to authenticated
  using (bucket_id = 'scans' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "scans insert own" on storage.objects;
create policy "scans insert own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'scans' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "scans update own" on storage.objects;
create policy "scans update own" on storage.objects
  for update to authenticated
  using (bucket_id = 'scans' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "scans delete own" on storage.objects;
create policy "scans delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'scans' and (storage.foldername(name))[1] = auth.uid()::text);

-- 3. Auth settings (dashboard, not SQL) -------------------------------------
-- Authentication → Providers → Email: enable "Confirm email".
-- Authentication → Email Templates → "Confirm signup" and "Reset password":
--   include the 6-digit code with {{ .Token }} so the app's OTP screens work, e.g.
--   <h2>Your verification code</h2><p>{{ .Token }}</p>
