-- Cole tudo isto em: Supabase > SQL Editor > New query > Run

create table if not exists products (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists clients  (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists orders   (id text primary key, data jsonb not null, updated_at timestamptz default now());

-- Segurança: só usuários logados (você e sua equipe) leem e escrevem.
alter table products enable row level security;
alter table clients  enable row level security;
alter table orders   enable row level security;

create policy "logados acessam produtos" on products for all to authenticated using (true) with check (true);
create policy "logados acessam clientes" on clients  for all to authenticated using (true) with check (true);
create policy "logados acessam pedidos"  on orders   for all to authenticated using (true) with check (true);
