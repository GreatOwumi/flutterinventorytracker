-- Run once in the SQL Editor of a new Supabase project.
begin;

create table public.products (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id) default auth.uid(),
  name text not null check (length(trim(name)) > 0),
  category text not null check (length(trim(category)) > 0),
  price numeric(14,2) not null check (price >= 1 and price <= 999999999999.99),
  stock integer not null check (stock >= 0),
  "minStock" integer not null check ("minStock" >= 0)
);
create index products_owner_idx on public.products(owner_id);

-- Product details are copied here so changing/deleting a product never
-- rewrites old receipts. The product ID is intentionally not a foreign key.
create table public.sales (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id),
  request_id uuid not null,
  product_id bigint not null,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 1 and unit_price <= 999999999999.99),
  total numeric generated always as (quantity * unit_price) stored,
  payment_method text not null check (payment_method in ('cash', 'transfer')),
  sold_at timestamptz not null default now(),
  unique (owner_id, request_id)
);
create index sales_owner_date_idx on public.sales(owner_id, sold_at desc);

alter table public.products enable row level security;
alter table public.sales enable row level security;
create policy own_products_select on public.products for select to authenticated using ((select auth.uid()) = owner_id);
create policy own_products_insert on public.products for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy own_products_update on public.products for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy own_products_delete on public.products for delete to authenticated using ((select auth.uid()) = owner_id);
create policy own_sales_select on public.sales for select to authenticated using ((select auth.uid()) = owner_id);

revoke all on public.products, public.sales from anon, authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select on public.sales to authenticated;
grant usage, select on sequence public.products_id_seq to authenticated;

-- These functions run as their owner. Every access explicitly checks the
-- signed-in user's ID, and the empty search path prevents object substitution.
create function public.adjust_stock(p_product_id bigint, p_delta integer)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or p_delta is null or p_delta = 0 then
    raise exception 'A signed-in user and non-zero stock change are required.';
  end if;
  update public.products set stock = (stock::bigint + p_delta)::integer
    where id = p_product_id and owner_id = auth.uid()
    and stock::bigint + p_delta between 0 and 2147483647;
  if not found then raise exception 'Stock change failed. Refresh and check the quantity.'; end if;
end;
$$;

create function public.record_sale(
  p_product_id bigint, p_quantity integer, p_expected_price numeric,
  p_payment_method text, p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_product public.products%rowtype;
  v_sale public.sales%rowtype;
begin
  if auth.uid() is null then raise exception 'Please sign in again.'; end if;
  if p_product_id is null or p_quantity is null or p_quantity < 1 or p_expected_price is null
    or p_request_id is null or p_payment_method is null
    or p_payment_method not in ('cash', 'transfer') then
    raise exception 'Invalid sale details.';
  end if;
  -- A reference identifies one checkout, including retries after a lost response.
  -- The transaction lock also serializes retries using this reference.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(auth.uid()::text || p_request_id::text, 0));
  select * into v_sale from public.sales where owner_id = auth.uid() and request_id = p_request_id;
  if found then
    if v_sale.product_id <> p_product_id or v_sale.quantity <> p_quantity
      or v_sale.unit_price <> p_expected_price or v_sale.payment_method <> p_payment_method then
      raise exception 'Sale reference already used for different details.';
    end if;
    return to_jsonb(v_sale);
  end if;
  -- Lock this product so two devices cannot sell the same last item.
  select * into v_product from public.products
    where id = p_product_id and owner_id = auth.uid() for update;
  if not found then raise exception 'Product no longer exists. Refresh inventory.'; end if;
  if v_product.stock < p_quantity then raise exception 'Not enough stock. Refresh inventory.'; end if;
  if v_product.price <> p_expected_price then raise exception 'Price changed. Refresh inventory.'; end if;
  insert into public.sales(owner_id, request_id, product_id, product_name, quantity, unit_price, payment_method)
    values (auth.uid(), p_request_id, v_product.id, v_product.name, p_quantity, v_product.price, p_payment_method)
    returning * into v_sale;
  update public.products set stock = stock - p_quantity where id = v_product.id and owner_id = auth.uid();
  return to_jsonb(v_sale);
end;
$$;

revoke all on function public.adjust_stock(bigint, integer) from public, anon;
revoke all on function public.record_sale(bigint, integer, numeric, text, uuid) from public, anon;
grant execute on function public.adjust_stock(bigint, integer) to authenticated;
grant execute on function public.record_sale(bigint, integer, numeric, text, uuid) to authenticated;
commit;
