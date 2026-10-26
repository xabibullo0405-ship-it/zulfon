import {PGlite} from '@electric-sql/pglite';import {readFile,readdir} from 'node:fs/promises';import assert from 'node:assert/strict';
const db=new PGlite(),source=await readFile('tests/database.mjs','utf8'),blocks=[...source.matchAll(/await db.exec\(`([\s\S]*?)`\);/g)].map(m=>m[1]);
await db.exec(blocks[0]);await db.exec(await readFile('supabase/migrations/202610150001_initial.sql','utf8'));await db.exec(blocks[1]);
for(const file of (await readdir('supabase/migrations')).filter(f=>f.endsWith('.sql')&&f!=='202610150001_initial.sql').sort()){
 if(file==='202610240001_owner_admin.sql'){
  await assert.rejects(db.exec(await readFile('supabase/migrations/202610260001_material_usage.sql','utf8')),/Avval 202610240001/);await db.exec('rollback');
  assert.equal((await db.query("select * from information_schema.columns where table_name='inventory_movements' and column_name='operation_id'")).rows.length,0,'Missing prerequisite must not partially alter stock schema');
 }
 await db.exec(await readFile('supabase/migrations/'+file,'utf8'));
}
const ids=Array.from({length:7},(_,i)=>`90000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`),roles=['Direktor','Omborchi','Prorab','Brigadir','Brigadir','Brigadir','Admin'];
const as=async i=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[i]]);await db.exec('set role authenticated')};
for(let i=0;i<7;i++){await db.exec('reset role');await db.query('insert into auth.users(id,raw_app_meta_data) values($1,$2)',[ids[i],{themelio_role:i===0?'director':i===6?'admin':'employee',login:'usage'+i,position:roles[i]}]);await as(i);await db.query("select public.complete_profile($1,'+998901234567','usage@example.com','Address',null)",['Usage '+i])}
await as(0);const site=(await db.query("select public.save_site(null,'Site','Address',1,5,current_date,0) id")).rows[0].id,other=(await db.query("select public.save_site(null,'Other','Address',1,5,current_date,0) id")).rows[0].id;
for(let i=1;i<6;i++)await db.query('select public.assign_employee_project($1,$2)',[ids[i],i===5?other:site]);
const id=n=>`91000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
await as(1);const item=(await db.query("select public.save_inventory_item(null,'Sement','kg',false) id")).rows[0].id;
await db.query("select public.move_inventory($1,$2,'receipt',100,null,null,'Receipt')",[id(1),item]);
await db.query("select public.move_inventory($1,$2,'issue',30,$3,null,'First')",[id(2),item,ids[3]]);await db.query("select public.move_inventory($1,$2,'issue',20,$3,null,'Second')",[id(3),item,ids[3]]);await db.query("select public.move_inventory($1,$2,'return',10,$3,$4,'Return')",[id(4),item,ids[3],id(2)]);
for(const i of [0,1,2]){await as(i);await assert.rejects(db.query("select public.consume_material($1,$2,1,'Use')",[id(5),item]),/Brigadir/)}
await as(4);await assert.rejects(db.query("select public.consume_material($1,$2,1,'Use')",[id(5),item]),/qoldiqdan/);
await as(5);await assert.rejects(db.query("select public.consume_material($1,$2,1,'Use')",[id(5),item]),/topilmadi/);
await as(3);
for(const qty of [0,-1,40.001,'NaN',0.0001])await assert.rejects(db.query("select public.consume_material($1,$2,$3,'Use')",[id(5),item,qty]),/Miqdor/);
await assert.rejects(db.query("select public.consume_material($1,$2,1,' ')",[id(5),item]),/ishlatilganini/);
await db.query("select public.consume_material($1,$2,35,'Birinchi qavatga')",[id(5),item]);const parts=(await db.query('select * from public.inventory_movements where operation_id=$1',[id(5)])).rows;assert.equal(parts.length,2,'One use spans two deliveries');assert.equal(parts.reduce((n,r)=>n+Number(r.quantity),0),35);
await db.query("select public.consume_material($1,$2,35,'Birinchi qavatga')",[id(5),item]);assert.equal((await db.query('select * from public.inventory_movements where operation_id=$1',[id(5)])).rows.length,2,'Retry cannot consume twice');
await assert.rejects(db.query("select public.consume_material($1,$2,34,'Birinchi qavatga')",[id(5),item]),/conflict/);
await as(1);assert.equal(Number((await db.query('select quantity from public.inventory_items where id=$1',[item])).rows[0].quantity),60,'Usage must not touch warehouse stock');
await assert.rejects(db.query("select public.move_inventory($1,$2,'return',1,$3,$4,'No')",[id(6),item,ids[3],id(2)]),/oshdi/);await db.query("select public.move_inventory($1,$2,'return',5,$3,$4,'Remaining')",[id(7),item,ids[3],id(3)]);
await as(3);await assert.rejects(db.query("select public.consume_material($1,$2,0.001,'No')",[id(8),item]),/qoldiqdan/);assert.equal((await db.query('select * from public.inventory_items')).rows.length,0,'Brigadier never sees stock balances');
await assert.rejects(db.query("insert into public.inventory_movements(id,item_id,project_id,kind,quantity,brigadier_id,reference_id,operation_id,created_by) values($1,$2,$3,'usage',1,$4,$5,$1,$4)",[id(8),item,site,ids[3],id(2)]),/permission denied/);
await as(1);await db.query("select public.move_inventory($1,$2,'issue',5,$3,null,'Other brigade')",[id(9),item,ids[4]]);await as(4);await db.query("select public.consume_material($1,$2,2,'Floor')",[id(10),item]);assert.equal((await db.query("select * from public.inventory_movements where kind='usage'")).rows.length,1,'Other brigade usage is hidden');
await as(6);await db.query('select public.admin_act($1,$2,$3)',[ids[4],'consume_material',{p_id:id(11),p_item:item,p_quantity:1,p_note:'Admin use'}]);assert.equal((await db.query("select * from public.admin_audit where action='consume_material'")).rows.length,1);
await as(1);await db.query("select public.move_inventory($1,$2,'issue',60,$3,null,'All stock')",[id(12),item,ids[4]]);await db.query("select public.save_inventory_item($1,'Sement','kg',true)",[item]);await as(4);await db.query("select public.consume_material($1,$2,62,'Use all')",[id(13),item]);
await as(1);assert.equal(Number((await db.query('select quantity from public.inventory_items')).rows[0].quantity),0,'Archived zero-stock catalogue may still have usable issued material');
await as(0);await db.query("select public.set_employee_state($1,'dismissed')",[ids[4]]);await as(4);await assert.rejects(db.query("select public.consume_material($1,$2,1,'No')",[id(14),item]),/Brigadir/);
await db.close();console.log('Material usage SQL verified: own brigade/project only, fractional validation, split deliveries, retry safety, usage/return overdraw protection, unchanged warehouse stock, archived catalogue, admin audit and dismissed access.');
