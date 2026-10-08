-- Secure one-time ID submission policies.
-- Run this in the Supabase SQL Editor for the project used by the app.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.users
    where user_id = auth.uid()
      and role in ('admin', 'super_admin')
  );
$$;

grant execute on function public.is_admin() to authenticated;

alter table public.id_validations enable row level security;

create unique index if not exists id_validations_one_per_user
on public.id_validations (user_id);

drop policy if exists "Users can insert their own ID validation"
on public.id_validations;

drop policy if exists "Admins can view ID validations"
on public.id_validations;

drop policy if exists "Users can view their own ID validation"
on public.id_validations;

drop policy if exists "Users can view their own ID validation"
on public.id_validations;

drop policy if exists "Users can upload their own ID files"
on storage.objects;

drop policy if exists "Temporary ID upload testing"
on storage.objects;

drop policy if exists "Admins can view ID files"
on storage.objects;

drop policy if exists "Users can clean up incomplete ID uploads"
on storage.objects;

create policy "Users can insert their own ID validation"
on public.id_validations
for insert
to authenticated
with check (
  user_id = auth.uid()
  and not exists (
    select 1
    from public.id_validations
    where user_id = auth.uid()
  )
);

create policy "Admins can view ID validations"
on public.id_validations
for select
to authenticated
using (public.is_admin());

-- ID files are stored at id-verification/{uid}/{front|back}.
-- No UPDATE policy is created, so submitted files cannot be replaced.
create policy "Users can upload their own ID files"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'valid-ids'
  and (storage.foldername(name))[1] = 'id-verification'
  and (storage.foldername(name))[2] = auth.uid()::text
  and array_length(storage.foldername(name), 1) = 2
  and storage.filename(name) in ('front', 'back')
);

create policy "Admins can view ID files"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'valid-ids'
  and public.is_admin()
);

-- Allows cleanup only before a validation row exists. Once submitted, there
-- is no delete policy path for that user's ID files.
create policy "Users can clean up incomplete ID uploads"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'valid-ids'
  and (storage.foldername(name))[1] = 'id-verification'
  and (storage.foldername(name))[2] = auth.uid()::text
  and array_length(storage.foldername(name), 1) = 2
  and storage.filename(name) in ('front', 'back')
  and not exists (
    select 1
    from public.id_validations
    where user_id = auth.uid()
  )
);
