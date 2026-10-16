-- Cole tudo em: Supabase > SQL Editor > New query > Run. Pode rodar de novo sem problema.

create table if not exists products (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists clients  (id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists orders   (id text primary key, data jsonb not null, updated_at timestamptz default now());
alter table products enable row level security;
alter table clients  enable row level security;
alter table orders   enable row level security;

-- Loja (usuário logado): acesso total
drop policy if exists "logados acessam produtos" on products;
drop policy if exists "logados acessam clientes" on clients;
drop policy if exists "logados acessam pedidos"  on orders;
create policy "logados acessam produtos" on products for all to authenticated using (true) with check (true);
create policy "logados acessam clientes" on clients  for all to authenticated using (true) with check (true);
create policy "logados acessam pedidos"  on orders   for all to authenticated using (true) with check (true);

-- Clientes (sem login): veem produtos e enviam pedidos
drop policy if exists "clientes veem produtos" on products;
drop policy if exists "clientes enviam pedidos" on orders;
create policy "clientes veem produtos" on products for select to anon using (true);
create policy "clientes enviam pedidos" on orders for insert to anon with check (true);

-- Cadastro do cliente: o id (código longo e aleatório) criado no aparelho funciona como chave
create or replace function public.salvar_cliente(p_id text, p_data jsonb) returns void
language sql security definer set search_path = public as $$
  insert into clients (id, data, updated_at)
  select p_id, p_data, now() where length(p_id) >= 30
  on conflict (id) do update set data = excluded.data, updated_at = now() where length(clients.id) >= 30;
$$;

-- Cliente consulta só os próprios pedidos
create or replace function public.meus_pedidos(p_cid text) returns setof jsonb
language sql security definer set search_path = public as $$
  select data from orders where length(p_cid) >= 30 and data->>'cid' = p_cid order by updated_at desc limit 30;
$$;

grant execute on function public.salvar_cliente(text, jsonb), public.meus_pedidos(text) to anon, authenticated;
