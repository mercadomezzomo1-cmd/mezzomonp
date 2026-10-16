-- Cole tudo em: Supabase > SQL Editor > New query > Run. Pode rodar de novo sem problema.

create table if not exists products (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists clients  (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists orders   (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists admins   (user_id uuid primary key references auth.users(id) on delete cascade);
alter table products enable row level security;
alter table clients  enable row level security;
alter table orders   enable row level security;
alter table admins   enable row level security;

-- Dono da loja = usuário mais antigo (o que você criou primeiro). Para incluir outro:
-- insert into admins select id from auth.users where email = 'outro@email.com';
insert into admins (user_id) select id from auth.users order by created_at limit 1 on conflict do nothing;

create or replace function public.sou_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from admins where user_id = auth.uid());
$$;
grant execute on function public.sou_admin() to anon, authenticated;

-- Limpa regras antigas
drop policy if exists "logados acessam produtos" on products;
drop policy if exists "logados acessam clientes" on clients;
drop policy if exists "logados acessam pedidos"  on orders;
drop policy if exists "clientes veem produtos" on products;
drop policy if exists "clientes enviam pedidos" on orders;
drop function if exists public.salvar_cliente(text, jsonb);
drop function if exists public.meus_pedidos(text);
drop policy if exists "admin produtos" on products;
drop policy if exists "todos veem produtos" on products;
drop policy if exists "admin clientes" on clients;
drop policy if exists "cliente cadastro proprio" on clients;
drop policy if exists "admin pedidos" on orders;
drop policy if exists "cliente envia pedido" on orders;
drop policy if exists "cliente ve seus pedidos" on orders;

-- Loja (admin): acesso total
create policy "admin produtos" on products for all to authenticated using (public.sou_admin()) with check (public.sou_admin());
create policy "admin clientes" on clients  for all to authenticated using (public.sou_admin()) with check (public.sou_admin());
create policy "admin pedidos"  on orders   for all to authenticated using (public.sou_admin()) with check (public.sou_admin());

-- Clientes: todos veem produtos; cada cliente mexe só no próprio cadastro e nos próprios pedidos
create policy "todos veem produtos" on products for select to anon, authenticated using (true);
create policy "cliente cadastro proprio" on clients for all to authenticated using (id = auth.uid()::text) with check (id = auth.uid()::text);
create policy "cliente envia pedido" on orders for insert to authenticated with check (data->>'cid' = auth.uid()::text);
create policy "cliente ve seus pedidos" on orders for select to authenticated using (data->>'cid' = auth.uid()::text);

-- Dados da empresa (nome, CNPJ, endereço, logotipo): todos leem, só o administrador altera
create table if not exists config (id text primary key, data jsonb not null, updated_at timestamptz default now());
alter table config enable row level security;
drop policy if exists "todos veem config" on config;
drop policy if exists "admin config" on config;
create policy "todos veem config" on config for select to anon, authenticated using (true);
create policy "admin config" on config for all to authenticated using (public.sou_admin()) with check (public.sou_admin());
