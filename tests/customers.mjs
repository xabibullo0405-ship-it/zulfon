import {PGlite} from '@electric-sql/pglite';
import {readFile,readdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const db=new PGlite(),source=await readFile('tests/database.mjs','utf8'),blocks=[...source.matchAll(/await db.exec\(`([\s\S]*?)`\);/g)].map(m=>m[1]);
await db.exec(blocks[0]);await db.exec(await readFile('supabase/migrations/202610150001_initial.sql','utf8'));await db.exec(blocks[1]);
for(const file of (await readdir('supabase/migrations')).filter(f=>f.endsWith('.sql')&&f!=='202610150001_initial.sql').sort())await db.exec(await readFile('supabase/migrations/'+file,'utf8'));
const ids=Array.from({length:14},(_,i)=>`c0000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`);
const as=async i=>{await db.exec('reset role');await db.query("select set_config('request.jwt.claim.sub',$1,false)",[ids[i]]);await db.exec('set role authenticated')};
for(let i=0;i<6;i++){await db.exec('reset role');await db.query('insert into auth.users(id,raw_app_meta_data) values($1,$2)',[ids[i],{themelio_role:i===0?'director':i===5?'admin':'employee',login:'customer-test'+i,position:['Direktor','Sotuvchi','Prorab','Brigadir','Sotuvchi','Admin'][i]}]);await as(i);await db.query("select public.complete_profile($1,'+998901234567','u@example.com','Address',null)",['User '+i])}
await as(0);const site=(await db.query("select public.save_site(null,'Site A','Address A',2,9,current_date,45) id")).rows[0].id,other=(await db.query("select public.save_site(null,'Site B','Address B',1,7,current_date,20) id")).rows[0].id;
await db.query('select public.assign_employee_project($1,$2)',[ids[2],site]);await db.query('select public.assign_employee_project($1,$2)',[ids[3],site]);
const sale=async(i,project,unit)=>{await as(i);return (await db.query("select public.save_sale(null,$1,$2,'Buyer','+998909999999',100000000,25000000,current_date) id",[project,unit])).rows[0].id};
const a=await sale(1,site,'A-12'),b=await sale(4,other,'B-23'),c=await sale(1,site,'A-14');
for(const i of [6,7,8,9]){await db.exec('reset role');await db.query('insert into auth.users(id,raw_app_meta_data) values($1,$2)',[ids[i],{themelio_role:'customer',login:'buyer'+i}]);assert.equal((await db.query('select * from public.members where id=$1',[ids[i]])).rows.length,0,'Customer never consumes staff membership')}
for(const i of [0,1,2,5,6]){await as(i);await assert.rejects(db.query('select public.register_customer($1,$2,$3,$4)',[ids[6],a,ids[1],'buyer6']),/permission denied/)}
await db.exec('reset role');await db.query('select public.register_customer($1,$2,$3,$4)',[ids[6],a,ids[1],'buyer6']);await db.query('select public.register_customer($1,$2,$3,$4)',[ids[7],b,ids[4],'buyer7']);
await assert.rejects(db.query('select public.register_customer($1,$2,$3,$4)',[ids[8],a,ids[1],'buyer8']),/unique/);
await assert.rejects(db.query('select public.register_customer($1,$2,$3,$4)',[ids[8],c,ids[0],'buyer8']),/faol sotuvchi/);
await assert.rejects(db.query('select public.register_customer($1,$2,$3,$4)',[ids[8],c,ids[4],'buyer8']),/kiritgan sotuv/);
await as(1);assert.equal((await db.query('select * from public.list_customers()')).rows.length,1,'Seller sees own customer list');await as(4);assert.equal((await db.query('select * from public.list_customers()')).rows.length,1);await as(0);assert.equal((await db.query('select * from public.list_customers()')).rows.length,2);
// Clock fixtures use known Mondays in Tashkent. Production created_at cannot be supplied by clients.
const photo=async({author=2,project=site,stamp='2026-11-02T05:00:00Z',date='2026-11-02',paths=true})=>{
 await db.exec('reset role');const id=crypto.randomUUID(),path=ids[author]+'/'+id+'/camera.jpg';
 if(paths)await db.query("insert into storage.objects(bucket_id,name,metadata) values('report-photos',$1,'{\"mimetype\":\"image/jpeg\",\"size\":100}')",[path]);
 await db.query("insert into public.reports(id,author_id,title,body,report_type,report_date,created_at,photo_paths,project_id) values($1,$2,'PRIVATE TITLE','PRIVATE BODY','morning',$3,$4,$5,$6)",[id,ids[author],date,stamp,paths?[path]:[],project]);return {id,path};
};
const tuesday=await photo({stamp:'2026-11-03T05:00:00Z',date:'2026-11-03'}),wrongRole=await photo({author:3}),wrongDate=await photo({date:'2026-11-01'}),empty=await photo({paths:false});
assert.equal((await db.query('select * from public.customer_weekly_photos')).rows.length,0);
const first=await photo({stamp:'2026-11-01T19:30:00Z'}); // Sunday UTC is already Monday in Tashkent.
const later=await photo({stamp:'2026-11-02T06:00:00Z'});
assert.equal((await db.query('select * from public.customer_weekly_photos')).rows.length,1,'Only first qualified report per site/week');
await as(6);let dashboard=(await db.query('select public.customer_dashboard() d')).rows[0].d;assert.equal(dashboard.unit,'A-12');assert.equal(dashboard.project.progress,45);assert.equal(dashboard.updates.length,1);assert.deepEqual(dashboard.updates[0].photos,[first.path]);assert(!JSON.stringify(dashboard).includes('PRIVATE'));
for(const table of ['members','reports','tasks','messages','projects','sales','project_documents','inventory_items','inventory_movements','construction_workers','payroll','receipt_costs','admin_audit'])assert.equal((await db.query('select * from public.'+table)).rows.length,0,'Customer cannot read '+table);
assert.equal((await db.query('select * from public.list_customers()')).rows.length,0);
for(const fn of ['staff_directory','allocation_labels','accounting_staff','brigade_headcounts','receipt_ledger'])assert.equal((await db.query('select * from public.'+fn+'()')).rows.length,0,'No internal data via '+fn);
assert.deepEqual((await db.query("select name from storage.objects where bucket_id='report-photos'")).rows.map(r=>r.name),[first.path]);
for(const p of [tuesday.path,wrongRole.path,wrongDate.path,later.path])assert.equal((await db.query('select themelio_private.customer_photo_allowed($1) ok',[p])).rows[0].ok,false);
await assert.rejects(db.query("insert into storage.objects(bucket_id,name,metadata) values('report-photos',$1,'{}')",[ids[6]+'/unauthorized.jpg']),/row-level security/);
await assert.rejects(db.query("select public.send_message($1,'Private')",[ids[0]]),/profile|Faol|active/i);
await assert.rejects(db.query("select public.submit_report('No','No','morning',current_date)"),/profile/i);
await assert.rejects(db.query("select public.complete_profile('No','+998901234567','u@example.com','Address',null)"),/authorized/i);
await as(7);dashboard=(await db.query('select public.customer_dashboard() d')).rows[0].d;assert.equal(dashboard.unit,'B-23');assert.equal(dashboard.updates.length,0);assert.equal((await db.query("select * from storage.objects where bucket_id='report-photos'")).rows.length,0,'Other site photos stay private');
await as(9);assert.equal((await db.query('select public.customer_dashboard() d')).rows[0].d,null,'Orphaned identity gets no dashboard');assert.equal((await db.query('select * from public.members')).rows.length,0);
await as(0);await db.query("select public.decide_report($1,'rejected','Not suitable')",[first.id]);await as(6);assert.equal((await db.query('select public.customer_dashboard() d')).rows[0].d.updates.length,0,'Rejected report photos disappear');assert.equal((await db.query("select * from storage.objects where bucket_id='report-photos'")).rows.length,0);
await db.exec('reset role');await db.query("update public.reports set status='accepted' where id=$1",[first.id]);await as(0);await db.query("select public.save_site($1,'Site A','Address A',2,9,current_date,61)",[site]);await as(6);assert.equal((await db.query('select public.customer_dashboard() d')).rows[0].d.project.progress,61,'Progress is live');
await db.exec('reset role');for(let i=10;i<14;i++)await db.query('insert into auth.users(id,raw_app_meta_data) values($1,$2)',[ids[i],{themelio_role:'employee',login:'quota'+i,position:'Muhandis'}]);assert.equal((await db.query("select count(*)::int n from public.members where app_role<>'admin'")).rows[0].n,9,'Customers do not consume staff seats');
await db.close();console.log('Customer SQL passed: seller-only service registration, uniqueness/ownership, isolated data/Storage, local Monday automatic photos, no report text, rejected photos hidden and live progress.');
