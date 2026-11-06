// Isolated PostgreSQL checks; no Supabase project or credentials needed.
// npm.cmd install --prefix .dart_tool/sql-validation --no-audit --no-fund @electric-sql/pglite
// node test/supabase_schema_test.mjs
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { PGlite } from '../.dart_tool/sql-validation/node_modules/@electric-sql/pglite/dist/index.js';

const db = new PGlite();
const alice = '11111111-1111-4111-8111-111111111111';
const bob = '22222222-2222-4222-8222-222222222222';
const reference = '33333333-3333-4333-8333-333333333333';
const secondReference = '44444444-4444-4444-8444-444444444444';
let passed = 0;
const check = (name) => { passed++; console.log(`PASS ${name}`); };
const query = (sql, args = []) => db.query(sql, args);
const asUser = async (id) => {
  await db.exec('reset role; set role authenticated;');
  await query("select set_config('request.jwt.claim.sub', $1, false)", [id]);
};
const record = (id, quantity, ref = reference, price = 1500, method = 'cash') =>
  query('select public.record_sale($1, $2, $3, $4, $5) as sale', [id, quantity, price, method, ref]);

try {
  // Reproduce the Supabase auth interface, then execute the actual migration.
  await db.exec(`
    create role anon;
    create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
    grant usage on schema auth to authenticated, anon;
    grant execute on function auth.uid() to authenticated, anon;
    insert into auth.users values ('${alice}'), ('${bob}');
  `);
  await db.exec(readFileSync(new URL('../supabase/migrations/202611040001_inventory_and_sales.sql', import.meta.url), 'utf8'));
  check('migration executes in PostgreSQL');

  await db.exec('set role anon;');
  await assert.rejects(query('select * from public.products'), /permission denied/);
  await assert.rejects(record(1, 1), /permission denied/);
  check('anonymous users cannot read inventory or execute a sale');

  await asUser(alice);
  const { rows: [product] } = await query(`insert into public.products(name, category, price, stock, "minStock") values ('Rice', 'Food', 1500, 3, 1) returning id`);
  await assert.rejects(query(`insert into public.products(owner_id, name, category, price, stock, "minStock") values ($1, 'Other', 'Food', 1, 1, 0)`, [bob]), /row-level security/);
  check('owners can create products but cannot create another account\'s products');

  await asUser(bob);
  assert.equal((await query('select * from public.products')).rows.length, 0);
  assert.equal((await query('update public.products set stock = 100 where id = $1 returning id', [product.id])).rows.length, 0);
  assert.equal((await query('delete from public.products where id = $1 returning id', [product.id])).rows.length, 0);
  await assert.rejects(record(product.id, 1), /Product no longer exists/);
  await assert.rejects(query('select public.adjust_stock($1, 1)', [product.id]), /Stock change failed/);
  check('another account cannot read, edit, delete, adjust, or sell the product');

  await asUser(alice);
  const sale = (await record(product.id, 2)).rows[0].sale;
  assert.equal(Number(sale.total), 3000);
  assert.equal((await query('select stock from public.products where id = $1', [product.id])).rows[0].stock, 1);
  assert.equal((await record(product.id, 2)).rows[0].sale.id, sale.id);
  assert.equal((await query('select * from public.sales')).rows.length, 1);
  await assert.rejects(record(product.id, 1), /Sale reference already used/);
  check('sale reduces stock and retry returns the original receipt without a second sale');

  await assert.rejects(record(product.id, 2, secondReference), /Not enough stock/);
  await assert.rejects(record(product.id, 1, secondReference, 1), /Price changed/);
  await assert.rejects(record(product.id, 1, secondReference, 1500, 'card'), /Invalid sale/);
  await assert.rejects(query('select public.adjust_stock($1, -2)', [product.id]), /Stock change failed/);
  await assert.rejects(query('select public.adjust_stock($1, 2147483647)', [product.id]), /Stock change failed/);
  assert.equal((await query('select stock from public.products where id = $1', [product.id])).rows[0].stock, 1);
  assert.equal((await query('select * from public.sales')).rows.length, 1);
  check('insufficient stock, changed prices, invalid payment and stock bounds leave data unchanged');

  await assert.rejects(query('update public.sales set quantity = 99'), /permission denied/);
  await assert.rejects(query('delete from public.sales'), /permission denied/);
  await asUser(bob);
  assert.equal((await query('select * from public.sales')).rows.length, 0);
  check('receipts cannot be edited/deleted by clients and are private to their owner');

  // Force a failure after the receipt insert to verify the function rolls it back.
  await db.exec(`reset role;
    create function public.test_reject_stock_update() returns trigger language plpgsql as $$
    begin raise exception 'Simulated stock write failure'; end; $$;
    create trigger test_stock_failure before update on public.products for each row execute function public.test_reject_stock_update();`);
  await asUser(alice);
  await assert.rejects(record(product.id, 1, secondReference), /Simulated stock write failure/);
  assert.equal((await query('select * from public.sales')).rows.length, 1);
  assert.equal((await query('select stock from public.products where id = $1', [product.id])).rows[0].stock, 1);
  await db.exec('reset role; drop trigger test_stock_failure on public.products; drop function public.test_reject_stock_update();');
  check('failure after inserting receipt rolls back both sale and stock change');

  await asUser(alice);
  await record(product.id, 1, secondReference);
  await assert.rejects(record(product.id, 1, '55555555-5555-4555-8555-555555555555'), /Not enough stock/);
  await query('delete from public.products where id = $1', [product.id]);
  assert.equal((await query('select * from public.sales')).rows.length, 2);
  assert.equal((await record(product.id, 2)).rows[0].sale.product_name, 'Rice');
  check('last item sells only once; receipts and idempotent retries survive product deletion');
  console.log(`${passed} database checks passed.`);
} finally {
  await db.close();
}
