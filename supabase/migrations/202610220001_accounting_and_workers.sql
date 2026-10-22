-- Run once after 202610210001_site_operations.sql. Retains existing records.
begin;
create or replace function themelio_private.staff_role() returns text language sql stable security definer set search_path='' as $$
 select case when app_role='director' then 'director'
 when lower(trim(position)) in ('hisobchi','бухгалтер') then 'accountant'
 when lower(trim(position)) in ('omborchi','кладовщик') then 'warehouse'
 when lower(trim(position)) in ('prorab','прораб') then 'foreman'
 when lower(trim(position)) in ('brigadir','brigadar','brigada boshlig‘i','brigada boshlig''i','бригадир') then 'brigadier'
 else 'employee' end from public.members where id=auth.uid() and employment_status='employed' and status='active';
$$;
alter table public.construction_workers add column passport_number text check(passport_number ~ '^[A-Z]{2}[0-9]{6,7}$');
alter table public.construction_workers add column jshshir text check(jshshir ~ '^[0-9]{14}$');
alter table public.construction_workers add column dismissed_at timestamptz;
alter table public.construction_workers add column dismissed_by uuid references public.members(id);
alter table public.construction_workers add column dismissal_reason text check(length(dismissal_reason)<=2000);
alter table public.construction_workers drop constraint construction_workers_status_check;
alter table public.construction_workers add constraint construction_workers_status_check check(status in ('pending','approved','rejected','dismissed'));
-- Legacy free-text identities are retained, never guessed. New submissions use verified fields.
create function public.submit_worker_verified(p_id uuid,p_name text,p_duty text,p_passport_number text,p_jshshir text,p_paths text[]) returns uuid language plpgsql security definer set search_path='' as $$
declare path text;existing public.construction_workers;passport text:=upper(trim(p_passport_number));pin text:=trim(p_jshshir);
begin
 if themelio_private.staff_role() is distinct from 'brigadier' or themelio_private.my_project() is null then raise exception 'Brigadir va biriktirilgan obyekt talab qilinadi';end if;
 if passport is null or passport !~ '^[A-Z]{2}[0-9]{6,7}$' then raise exception 'Pasport raqami: 2 ta harf va 6–7 ta raqam';end if;
 if pin is null or pin !~ '^[0-9]{14}$' then raise exception 'JSHSHIR 14 ta raqamdan iborat bo‘lishi kerak';end if;
 if p_id is null then raise exception 'Worker ID required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into existing from public.construction_workers where id=p_id for update;
 if found then
 if existing.brigadier_id<>auth.uid() or existing.project_id<>themelio_private.my_project() then raise exception 'Access denied';end if;
 if existing.status='pending' and existing.name=trim(p_name) and existing.duty=trim(p_duty) and existing.passport_number=passport and existing.jshshir=pin and existing.photo_paths=p_paths then return p_id;end if;
 if existing.status not in ('pending','rejected') then raise exception 'Tasdiqlangan quruvchini o‘zgartirib bo‘lmaydi';end if;
 end if;
 if p_paths is null or cardinality(p_paths) not between 1 and 4 or cardinality(p_paths)<>(select count(distinct v) from unnest(p_paths) v) then raise exception '1–4 ta pasport rasmi kerak';end if;
 foreach path in array p_paths loop
 if split_part(path,'/',1)<>auth.uid()::text or split_part(path,'/',2)<>p_id::text or not exists(select 1 from storage.objects where bucket_id='worker-passports' and name=path and metadata->>'mimetype' in ('image/jpeg','image/png') and (metadata->>'size')::bigint between 1 and 5242880) then raise exception 'Pasport rasmi topilmadi';end if;
 end loop;
 insert into public.construction_workers(id,project_id,brigadier_id,name,duty,passport_data,passport_number,jshshir,photo_paths)
 values(p_id,themelio_private.my_project(),auth.uid(),trim(p_name),trim(p_duty),passport,passport,pin,p_paths)
 on conflict(id) do update set name=excluded.name,duty=excluded.duty,passport_data=excluded.passport_data,passport_number=excluded.passport_number,jshshir=excluded.jshshir,photo_paths=excluded.photo_paths,status='pending',reason=null,reviewed_by=null,reviewed_at=null;
 return p_id;
end;
$$;
-- Close the old free-text submission API; users cannot bypass identity validation.
revoke execute on function public.submit_worker(uuid,text,text,text,text[]) from authenticated,anon,public;
create or replace function public.review_worker(p_id uuid,p_approve boolean,p_reason text default null) returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'foreman' then raise exception 'Prorab huquqi kerak';end if;
 if p_approve is null or (not p_approve and length(trim(coalesce(p_reason,'')))=0) then raise exception 'Rad etish sababini yozing';end if;
 if p_approve and exists(select 1 from public.construction_workers where id=p_id and project_id=themelio_private.my_project() and (passport_number is null or jshshir is null)) then raise exception 'Brigadir pasport raqami va JSHSHIRni to‘ldirishi kerak';end if;
 update public.construction_workers set status=case when p_approve then 'approved' else 'rejected' end,reason=case when p_approve then null else trim(p_reason) end,reviewed_by=auth.uid(),reviewed_at=now() where id=p_id and project_id=themelio_private.my_project() and status='pending';
 if not found then raise exception 'Quruvchi topilmadi yoki ko‘rib chiqilgan';end if;
end;
$$;
create function public.dismiss_worker(p_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'foreman' then raise exception 'Prorab huquqi kerak';end if;
 if length(trim(coalesce(p_reason,''))) not between 1 and 2000 then raise exception 'Ishdan bo‘shatish sababini yozing';end if;
 update public.construction_workers set status='dismissed',dismissal_reason=trim(p_reason),dismissed_at=now(),dismissed_by=auth.uid() where id=p_id and project_id=themelio_private.my_project() and status='approved';
 if not found then raise exception 'Faol quruvchi topilmadi';end if;
end;
$$;
create or replace function themelio_private.file_allowed(p_bucket text,p_path text,p_action text) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if not themelio_private.is_active() then return false;end if;
 if p_bucket='project-documents' then
 if p_action='insert' then return themelio_private.is_director() and split_part(p_path,'/',1)=auth.uid()::text and exists(select 1 from public.projects where id::text=split_part(p_path,'/',2));end if;
 if p_action='read' then return (themelio_private.is_director() and split_part(p_path,'/',1)=auth.uid()::text) or exists(select 1 from public.project_documents where path=p_path and (themelio_private.is_director() or project_id=themelio_private.my_project()));end if;
 if p_action='delete' then return themelio_private.is_director() and not exists(select 1 from public.project_documents where path=p_path);end if;
 elsif p_bucket='worker-passports' then
 if p_action='insert' then return themelio_private.staff_role()='brigadier' and themelio_private.my_project() is not null and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.construction_workers where id::text=split_part(p_path,'/',2) and (status not in ('pending','rejected') or brigadier_id<>auth.uid() or project_id<>themelio_private.my_project()));end if;
 if p_action='read' then return exists(select 1 from public.construction_workers where p_path=any(photo_paths) and project_id=themelio_private.my_project() and (themelio_private.staff_role()='foreman' or (themelio_private.staff_role()='brigadier' and brigadier_id=auth.uid()))) or (themelio_private.staff_role()='brigadier' and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.construction_workers where id::text=split_part(p_path,'/',2)));end if;
 if p_action='delete' then return themelio_private.staff_role()='brigadier' and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.construction_workers where p_path=any(photo_paths));end if;
 end if;return false;
end;
$$;

create table public.payroll(
 id uuid primary key default gen_random_uuid(),employee_id uuid not null references public.members(id),month date not null check(extract(day from month)=1),
 amount numeric(16,2) not null check(amount>=0 and amount<100000000000000),paid numeric(16,2) not null check(paid>=0 and paid<=amount),
 note text not null default '' check(length(note)<=1000),updated_by uuid not null references public.members(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(employee_id,month)
);
create table public.receipt_costs(
 receipt_id uuid primary key references public.inventory_movements(id),total numeric(16,2) not null check(total>0 and total<100000000000000),
 paid numeric(16,2) not null check(paid>=0 and paid<=total),supplier text not null default '' check(length(supplier)<=160),
 document_ref text not null default '' check(length(document_ref)<=120),note text not null default '' check(length(note)<=1000),
 updated_by uuid not null references public.members(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.payroll enable row level security;
alter table public.receipt_costs enable row level security;
create policy payroll_read on public.payroll for select to authenticated using(themelio_private.staff_role()='accountant');
create policy costs_read on public.receipt_costs for select to authenticated using(themelio_private.staff_role()='accountant');
revoke all on public.payroll,public.receipt_costs from public,anon,authenticated;
grant select on public.payroll,public.receipt_costs to authenticated;
grant all on public.payroll,public.receipt_costs to service_role;
create function public.accounting_staff() returns table(id uuid,name text,"position" text,project_id uuid,employment_status text) language sql stable security definer set search_path='' as $$
 select m.id,m.name,m.position,m.project_id,m.employment_status from public.members m where themelio_private.staff_role()='accountant' and m.app_role='employee' and m.status='active' ;
$$;
create function public.brigade_headcounts() returns table(brigadier_id uuid,name text,project_id uuid,project_name text,worker_count bigint) language sql stable security definer set search_path='' as $$
 select m.id,m.name,m.project_id,p.name,(select count(*) from public.construction_workers w where w.brigadier_id=m.id and w.status='approved') from public.members m left join public.projects p on p.id=m.project_id
 where themelio_private.staff_role()='accountant' and m.app_role='employee' and m.status='active' and m.employment_status='employed' and lower(trim(m.position)) in ('brigadir','brigadar','brigada boshlig‘i','brigada boshlig''i','бригадир');
$$;
create function public.receipt_ledger() returns table(id uuid,project_id uuid,project_name text,item_name text,unit text,quantity numeric,note text,created_at timestamptz) language sql stable security definer set search_path='' as $$
 select m.id,m.project_id,p.name,i.name,i.unit,m.quantity,m.note,m.created_at from public.inventory_movements m join public.inventory_items i on i.id=m.item_id join public.projects p on p.id=m.project_id where themelio_private.staff_role()='accountant' and m.kind='receipt' order by m.created_at desc;
$$;
create function public.save_payroll(p_employee uuid,p_month date,p_amount numeric,p_paid numeric,p_note text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if themelio_private.staff_role() is distinct from 'accountant' then raise exception 'Hisobchi huquqi kerak';end if;
 if not exists(select 1 from public.members where id=p_employee and app_role='employee' and status='active' and employment_status='employed') then raise exception 'Faol xodimni tanlang';end if;
 if p_month is null or extract(day from p_month)<>1 or p_amount is null or p_paid is null or p_amount<0 or p_amount>=100000000000000 or p_paid<0 or p_paid>p_amount or p_amount<>round(p_amount,2) or p_paid<>round(p_paid,2) then raise exception 'Oylik yoki to‘lov miqdori noto‘g‘ri';end if;
 insert into public.payroll(employee_id,month,amount,paid,note,updated_by) values(p_employee,p_month,p_amount,p_paid,coalesce(p_note,''),auth.uid()) on conflict(employee_id,month) do update set amount=excluded.amount,paid=excluded.paid,note=excluded.note,updated_by=auth.uid(),updated_at=now() returning id into result;return result;
end;
$$;
create function public.save_receipt_cost(p_receipt uuid,p_total numeric,p_paid numeric,p_supplier text default '',p_document text default '',p_note text default '') returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'accountant' then raise exception 'Hisobchi huquqi kerak';end if;
 if not exists(select 1 from public.inventory_movements where id=p_receipt and kind='receipt') then raise exception 'Ombor kirimi topilmadi';end if;
 if p_total is null or p_paid is null or p_total<=0 or p_total>=100000000000000 or p_paid<0 or p_paid>p_total or p_total<>round(p_total,2) or p_paid<>round(p_paid,2) then raise exception 'Xarajat yoki to‘lov miqdori noto‘g‘ri';end if;
 insert into public.receipt_costs(receipt_id,total,paid,supplier,document_ref,note,updated_by) values(p_receipt,p_total,p_paid,trim(coalesce(p_supplier,'')),trim(coalesce(p_document,'')),coalesce(p_note,''),auth.uid()) on conflict(receipt_id) do update set total=excluded.total,paid=excluded.paid,supplier=excluded.supplier,document_ref=excluded.document_ref,note=excluded.note,updated_by=auth.uid(),updated_at=now();
end;
$$;
create or replace function public.save_sale(p_id uuid,p_project uuid,p_unit text,p_buyer text,p_phone text,p_price numeric,p_paid numeric,p_date date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if themelio_private.is_director() or not themelio_private.can_sales() then raise exception 'Faqat sotuvchi sotuv kiritishi mumkin';end if;
 if p_id is null then
  insert into public.sales(project_id,unit_label,buyer_name,buyer_phone,price,paid,seller_id,sold_on) values(p_project,trim(p_unit),trim(p_buyer),trim(p_phone),p_price,p_paid,auth.uid(),p_date) returning id into result;
 else
  update public.sales set project_id=p_project,unit_label=trim(p_unit),buyer_name=trim(p_buyer),buyer_phone=trim(p_phone),price=p_price,paid=p_paid,sold_on=p_date,updated_at=now() where id=p_id and (seller_id=auth.uid() or themelio_private.is_director()) returning id into result;
  if not found then raise exception 'Sotuv topilmadi yoki tahrirlashga ruxsat yo‘q';end if;
 end if;
 return result;
end;
$$;

revoke all on function public.submit_worker_verified(uuid,text,text,text,text,text[]),public.dismiss_worker(uuid,text),public.accounting_staff(),public.brigade_headcounts(),public.receipt_ledger(),public.save_payroll(uuid,date,numeric,numeric,text),public.save_receipt_cost(uuid,numeric,numeric,text,text,text) from public,anon;
grant execute on function public.submit_worker_verified(uuid,text,text,text,text,text[]),public.dismiss_worker(uuid,text),public.accounting_staff(),public.brigade_headcounts(),public.receipt_ledger(),public.save_payroll(uuid,date,numeric,numeric,text),public.save_receipt_cost(uuid,numeric,numeric,text,text,text) to authenticated;
do $$begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table public.payroll,public.receipt_costs;end if;
end $$;
commit;
select 'Hisobchi va quruvchilar yangilandi' as status;
