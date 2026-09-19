create table if not exists public.layera_app_store (
  id text primary key,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default timezone('utc', now()),
  constraint layera_app_store_primary_row check (id = 'primary')
);

alter table public.layera_app_store enable row level security;
revoke all on table public.layera_app_store from anon, authenticated;
grant all on table public.layera_app_store to service_role;
