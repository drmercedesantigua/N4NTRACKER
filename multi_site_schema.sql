-- N4N Tracker multi-site schema
create table if not exists public.sites (
  id text primary key,
  name text not null
);
insert into public.sites (id, name) values
  ('21fp','21 Fountain Place'),
  ('manor','Manor House'),
  ('bogart','Bogart'),
  ('giorgio','Giorgio'),
  ('metro','Metro')
on conflict (id) do nothing;
