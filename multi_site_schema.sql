-- ============================================================
-- N4N Tracker — Multi-Site Schema
-- Sites: 21 Fountain Place, Manor House, Bogart, Giorgio, Metro
-- Run this in Supabase → SQL Editor → New query → Run
-- ============================================================

-- 1) Sites table
create table if not exists public.sites (
  id   text primary key,
  name text not null
);

insert into public.sites (id, name) values
  ('21fp',   '21 Fountain Place'),
  ('manor',  'Manor House'),
  ('bogart', 'Bogart'),
  ('giorgio','Giorgio'),
  ('metro',  'Metro')
on conflict (id) do nothing;

-- 2) User ↔ site access (role: 'admin' sees all, 'staff' sees assigned only)
create table if not exists public.user_site_access (
  user_id uuid not null references auth.users(id) on delete cascade,
  site_id text not null references public.sites(id) on delete cascade,
  role    text not null default 'staff' check (role in ('admin','staff')),
  primary key (user_id, site_id)
);

-- 3) Add site_id to households (assign existing Giorgio data)
alter table public.households
  add column if not exists site_id text references public.sites(id);

update public.households
set site_id = 'giorgio'
where site_id is null;

-- 4) Add site_id to discharges too
alter table public.discharges
  add column if not exists site_id text references public.sites(id);

update public.discharges
set site_id = 'giorgio'
where site_id is null;

-- 5) Row Level Security
alter table public.sites              enable row level security;
alter table public.user_site_access  enable row level security;
alter table public.households        enable row level security;
alter table public.discharges        enable row level security;

-- Helper: is the current user an admin of a given site?
create or replace function public.is_admin(p_site text)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.user_site_access
    where user_id = auth.uid() and site_id = p_site and role = 'admin'
  );
$$;

-- Helper: can the current user access a given site?
create or replace function public.can_access(p_site text)
returns boolean language sql stable as $$
  select exists (
    select 1 from public.user_site_access
    where user_id = auth.uid() and site_id = p_site
  ) or exists (
    select 1 from public.user_site_access
    where user_id = auth.uid() and role = 'admin'
  );
$$;

-- sites: readable by anyone logged in
drop policy if exists sites_read on public.sites;
create policy sites_read on public.sites
  for select to authenticated using (true);

-- user_site_access: users see only their own rows
drop policy if exists usa_read on public.user_site_access;
create policy usa_read on public.user_site_access
  for select to authenticated using (user_id = auth.uid());

-- households: only rows of sites the user can access
drop policy if exists hh_all on public.households;
create policy hh_all on public.households
  for all to authenticated
  using (public.can_access(site_id))
  with check (public.can_access(site_id));

-- discharges: same rule
drop policy if exists dc_all on public.discharges;
create policy dc_all on public.discharges
  for all to authenticated
  using (public.can_access(site_id))
  with check (public.can_access(site_id));

-- 6) Storage bucket for family photos (public read, auth write)
insert into storage.buckets (id, name, public)
values ('family-photos', 'family-photos', true)
on conflict (id) do nothing;

drop policy if exists fp_read on storage.objects;
create policy fp_read on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'family-photos');

drop policy if exists fp_write on storage.objects;
create policy fp_write on storage.objects
  for all to authenticated
  using (bucket_id = 'family-photos')
  with check (bucket_id = 'family-photos');

-- ============================================================
-- DONE. Next step: assign users to sites, e.g.
--   insert into public.user_site_access (user_id, site_id, role)
--   values ('UUID-DEL-USUARIO', 'giorgio', 'admin');
-- Admin role grants access to ALL sites automatically.
-- ============================================================
