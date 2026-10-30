-- =====================================================================
-- PDV DO BALCÃO · Mercado Mezzomo
-- Rode este arquivo inteiro no SQL Editor do Supabase (uma vez).
-- =====================================================================

-- Fatura uma venda do balcão (pedido novo) OU um pedido do catálogo (já existe).
-- * Só administradores podem chamar.
-- * Estoque: baixa a diferença entre os itens novos e os itens que o pedido já tinha
--   (pedido do catálogo já baixou estoque ao ser criado; se o caixa tirou ou
--   acrescentou itens, só a diferença mexe no estoque).
-- * Idempotente: se o PDV reenviar o mesmo faturamento (fila offline), não baixa de novo.
create or replace function public.pdv_faturar(p_id text, p_data jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  old jsonb;
  r record;
  fid text := p_data->'fat'->>'id';
  novo jsonb;
begin
  if not sou_admin() then raise exception 'Somente a loja pode faturar'; end if;
  if p_id is null or fid is null then raise exception 'Faturamento inválido'; end if;
  if jsonb_array_length(coalesce(p_data->'items','[]'::jsonb)) = 0 then raise exception 'Venda sem itens'; end if;

  select data into old from orders where id = p_id for update;

  -- reenvio do mesmo faturamento: não faz nada
  if old is not null and old->'fat'->>'id' = fid then return old; end if;
  if old is not null and old ? 'fat' then raise exception 'Este pedido já foi faturado'; end if;
  if old is not null and old->>'st' = 'canc' then raise exception 'Pedido cancelado não pode ser faturado'; end if;

  -- estoque pela diferença (itens novos - itens antigos)
  for r in
    with n as (
      select it->>'pid' pid, sum((it->>'q')::numeric) q
      from jsonb_array_elements(p_data->'items') it
      where it->>'pid' is not null group by 1),
    o as (
      select it->>'pid' pid, sum((it->>'q')::numeric) q
      from jsonb_array_elements(coalesce(old->'items','[]'::jsonb)) it
      where it->>'pid' is not null group by 1)
    select coalesce(n.pid, o.pid) pid, coalesce(n.q,0) - coalesce(o.q,0) d
    from n full join o on n.pid = o.pid
  loop
    if r.d <> 0 then
      update products
        set data = jsonb_set(data, '{est}', to_jsonb(greatest(0, (data->>'est')::numeric - r.d))),
            updated_at = now()
        where id = r.pid and nullif(data->>'est','') is not null;
    end if;
  end loop;

  if old is null then
    novo := p_data || jsonb_build_object('id', p_id);
    insert into orders (id, data, updated_at) values (p_id, novo, now());
  else
    -- mantém dados do cliente do catálogo e aplica o que veio do caixa
    novo := old || p_data || jsonb_build_object('id', p_id, 'cid', old->'cid', 'canal', coalesce(old->>'canal','app'));
    update orders set data = novo, updated_at = now() where id = p_id;
  end if;
  return novo;
end $$;

revoke all on function public.pdv_faturar(text, jsonb) from public, anon;
grant execute on function public.pdv_faturar(text, jsonb) to authenticated;
