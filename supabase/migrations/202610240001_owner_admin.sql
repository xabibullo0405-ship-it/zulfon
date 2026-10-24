-- Zulfon owner admin. Run once after 202610220001_accounting_and_workers.sql.
begin;
alter table public.members drop constraint members_app_role_check;
alter table public.members add constraint members_app_role_check check(app_role in ('admin','director','employee'));
create unique index one_owner_admin on public.members(app_role) where app_role='admin';
create function themelio_private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=auth.uid() and app_role='admin' and employment_status='employed');
$$;
create function themelio_private.work_uid() returns uuid language sql stable security definer set search_path='' as $$
 select case when themelio_private.is_admin() then coalesce(nullif(current_setting('zulfon.work_member',true),'')::uuid,auth.uid()) else auth.uid() end;
$$;
revoke all on function themelio_private.is_admin(),themelio_private.work_uid() from public;
grant execute on function themelio_private.is_admin(),themelio_private.work_uid() to authenticated;
create table public.admin_audit(id uuid primary key default gen_random_uuid(),actor_id uuid not null references public.members(id),target_id uuid references public.members(id),action text not null,created_at timestamptz not null default now());
alter table public.admin_audit enable row level security;
revoke all on public.admin_audit from public,anon,authenticated;
grant select on public.admin_audit to authenticated;
grant all on public.admin_audit to service_role;
create policy admin_audit_read on public.admin_audit for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.members for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.reports for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.tasks for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.messages for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.projects for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.sales for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.project_documents for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.inventory_items for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.inventory_movements for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.construction_workers for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.payroll for select to authenticated using(themelio_private.is_admin());
create policy owner_read on public.receipt_costs for select to authenticated using(themelio_private.is_admin());
create or replace function themelio_private.is_director() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=themelio_private.work_uid() and app_role in ('director','admin') and employment_status='employed');
$$;
create or replace function themelio_private.is_active() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.members where id=themelio_private.work_uid() and status='active' and employment_status='employed');
$$;
create or replace function themelio_private.can_sales() returns boolean language sql stable security definer set search_path='' as $$
 select themelio_private.is_director() or exists(select 1 from public.members where id=themelio_private.work_uid() and status='active' and employment_status='employed' and access_area='sales');
$$;
create or replace function themelio_private.staff_role() returns text language sql stable security definer set search_path='' as $$
 select case when app_role='admin' then 'admin' when app_role='director' then 'director'
 when lower(trim(position)) in ('hisobchi','бухгалтер') then 'accountant'
 when lower(trim(position)) in ('omborchi','кладовщик') then 'warehouse'
 when lower(trim(position)) in ('prorab','прораб') then 'foreman'
 when lower(trim(position)) in ('brigadir','brigadar','brigada boshlig‘i','brigada boshlig''i','бригадир') then 'brigadier'
 else 'employee' end from public.members where id=themelio_private.work_uid() and employment_status='employed' and status='active';
$$;
create or replace function themelio_private.my_project() returns uuid language sql stable security definer set search_path='' as $$
 select project_id from public.members where id=themelio_private.work_uid() and employment_status='employed' and status='active';
$$;
create or replace function themelio_private.guard_profile_edit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.work_uid()=old.id and old.employment_status<>'employed' and not themelio_private.is_director() then raise exception 'Hisob faol emas';end if;
 return new;
end;
$$;
create or replace function public.complete_profile(p_name text,p_phone text,p_email text,p_address text,p_birth_date date default null) returns void language plpgsql security definer set search_path='' as $$
declare current_member public.members;
begin
 select * into current_member from public.members where id=themelio_private.work_uid();
 if not found then raise exception 'Not authorized'; end if;
 if length(trim(coalesce(p_name,''))) not between 1 and 100 or length(coalesce(p_email,''))>254 or coalesce(p_email,'') !~ '^[^[:space:]@]+@[^[:space:]@]+[.][^[:space:]@]+$' then raise exception 'Valid name and email are required'; end if;
 if length(coalesce(p_phone,''))>25 or length(coalesce(p_address,''))>250 then raise exception 'Profile fields too long'; end if;
 if current_member.app_role='employee' and (length(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'))<9 or length(trim(coalesce(p_address,'')))=0) then raise exception 'Phone and address are required'; end if;
 if p_birth_date>(now() at time zone 'Asia/Tashkent')::date then raise exception 'Birth date cannot be in the future'; end if;
 update public.members set name=trim(p_name),phone=trim(coalesce(p_phone,'')),contact_email=trim(p_email),address=trim(coalesce(p_address,'')),birth_date=p_birth_date,status='active' where id=themelio_private.work_uid();
end;
$$;
create or replace function public.submit_report(p_title text,p_body text,p_type text,p_date date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first'; end if;
 insert into public.reports(author_id,title,body,report_type,report_date) values(themelio_private.work_uid(),trim(p_title),trim(p_body),p_type,p_date) returning id into result;
 return result;
end;
$$;
create or replace function public.review_report(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform public.decide_report(p_id,'accepted',null);end;
$$;
create or replace function public.create_task(p_title text,p_description text,p_assignee uuid,p_due date,p_priority text) returns uuid language plpgsql security definer set search_path='' as $$
begin return public.save_task(null,p_title,p_description,p_assignee,p_due,p_priority,0,null);end;
$$;
create or replace function public.update_task_progress(p_id uuid,p_progress integer) returns void language plpgsql security definer set search_path='' as $$
begin
 update public.tasks set progress=p_progress,status=case when p_progress=100 then 'done' else 'progress' end
 where id=p_id and (themelio_private.is_director() or (assignee_id=themelio_private.work_uid() and themelio_private.is_active()));
 if not found then raise exception 'Task not found or access denied'; end if;
end;
$$;
create or replace function public.send_message(p_recipient uuid,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first';end if;
 if not exists(select 1 from public.members where id=p_recipient and status='active' and employment_status='employed') then raise exception 'Recipient unavailable';end if;
 insert into public.messages(sender_id,recipient_id,body) values(themelio_private.work_uid(),p_recipient,trim(p_body)) returning id into result;return result;
end;
$$;
create or replace function public.submit_report_with_photos(p_id uuid,p_title text,p_body text,p_type text,p_date date,p_paths text[]) returns uuid language plpgsql security definer set search_path='' as $$
declare path text;existing_author uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first'; end if;
 select author_id into existing_author from public.reports where id=p_id;
 if found then
  if existing_author<>themelio_private.work_uid() then raise exception 'Access denied'; end if;
  return p_id;
 end if;
 if p_paths is null or cardinality(p_paths)>5 then raise exception 'At most 5 photos are allowed'; end if;
 if cardinality(p_paths)<>(select count(distinct item) from unnest(p_paths) item) then raise exception 'Duplicate photo path'; end if;
 foreach path in array p_paths loop
  if split_part(path,'/',1)<>themelio_private.work_uid()::text or split_part(path,'/',2)<>p_id::text then raise exception 'Photo does not belong to this report'; end if;
  if not exists(select 1 from storage.objects where bucket_id='report-photos' and name=path and metadata->>'mimetype'='image/jpeg' and (metadata->>'size')::bigint between 1 and 5242880) then raise exception 'Photo is missing or invalid'; end if;
 end loop;
 insert into public.reports(id,author_id,title,body,report_type,report_date,photo_paths)
 values(p_id,themelio_private.work_uid(),trim(p_title),trim(p_body),p_type,p_date,p_paths) on conflict(id) do nothing;
 select author_id into existing_author from public.reports where id=p_id;
 if existing_author<>themelio_private.work_uid() then raise exception 'Access denied'; end if;
 return p_id;
end;
$$;
create or replace function public.set_employee_state(p_id uuid,p_state text) returns void language plpgsql security definer set search_path='' as $$
declare target public.members;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_state is null or p_state not in ('employed','dismissed','deleted') then raise exception 'Invalid employee state';end if;
 select * into target from public.members where id=p_id and app_role='employee' for update;
 if not found then raise exception 'Employee not found';end if;
 if target.employment_status='deleted' then raise exception 'Deleted profiles cannot be restored';end if;
 update public.members set employment_status=p_state,
 name=case when p_state='deleted' then 'O‘chirilgan xodim' else name end,
 phone=case when p_state='deleted' then '' else phone end,contact_email=case when p_state='deleted' then '' else contact_email end,
 address=case when p_state='deleted' then '' else address end,birth_date=case when p_state='deleted' then null else birth_date end,
 project_id=case when p_state='deleted' then null else project_id end where id=p_id;
end;
$$;
create or replace function public.save_project(p_id uuid,p_name text,p_city text,p_address text,p_progress integer,p_finish date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_id is null then
  insert into public.projects(name,city,address,progress,planned_finish,created_by) values(trim(p_name),trim(p_city),trim(coalesce(p_address,'')),p_progress,p_finish,themelio_private.work_uid()) returning id into result;
 else
  update public.projects set name=trim(p_name),city=trim(p_city),address=trim(coalesce(p_address,'')),progress=p_progress,planned_finish=p_finish where id=p_id returning id into result;
  if not found then raise exception 'Project not found';end if;
 end if;
 return result;
end;
$$;
create or replace function public.assign_employee_project(p_id uuid,p_project uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 update public.members set project_id=p_project where id=p_id and app_role='employee' and employment_status<>'deleted';
 if not found then raise exception 'Employee not found';end if;
end;
$$;
create or replace function public.decide_report(p_id uuid,p_decision text,p_reason text default null) returns void language plpgsql security definer set search_path='' as $$
declare target public.reports;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_decision is null or p_decision not in ('accepted','rejected') then raise exception 'Invalid decision';end if;
 if p_decision='rejected' and (p_reason is null or length(trim(p_reason)) not between 1 and 2000) then raise exception 'Bekor qilish sababini yozing (1–2000 belgi)';end if;
 select * into target from public.reports where id=p_id for update;
 if not found then raise exception 'Report not found';end if;
 if target.status<>'review' then raise exception 'Hisobot allaqachon ko‘rib chiqilgan';end if;
 update public.reports set status=p_decision,rejection_reason=case when p_decision='rejected' then trim(p_reason) else null end,reviewed_by=themelio_private.work_uid(),reviewed_at=now() where id=p_id;
end;
$$;
create or replace function public.save_task(p_id uuid,p_title text,p_description text,p_assignee uuid,p_due date,p_priority text,p_progress integer,p_project uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;assignment public.members;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 select * into assignment from public.members where id=p_assignee and app_role='employee' and status='active' and employment_status='employed';
 if not found then raise exception 'An active employee is required';end if;
 if p_id is null then
  insert into public.tasks(title,description,assignee_id,created_by,due_date,priority,progress,status,project_id)
  values(trim(p_title),p_description,p_assignee,themelio_private.work_uid(),p_due,p_priority,p_progress,case when p_progress=100 then 'done' else 'progress' end,coalesce(p_project,assignment.project_id)) returning id into result;
 else
  update public.tasks set title=trim(p_title),description=p_description,assignee_id=p_assignee,due_date=p_due,priority=p_priority,progress=p_progress,status=case when p_progress=100 then 'done' else 'progress' end,project_id=coalesce(p_project,assignment.project_id) where id=p_id returning id into result;
  if not found then raise exception 'Task not found';end if;
 end if;
 return result;
end;
$$;
create or replace function public.delete_task(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 delete from public.tasks where id=p_id;
 if not found then raise exception 'Task not found';end if;
end;
$$;
create or replace function public.save_sale(p_id uuid,p_project uuid,p_unit text,p_buyer text,p_phone text,p_price numeric,p_paid numeric,p_date date) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if themelio_private.is_director() or not themelio_private.can_sales() then raise exception 'Faqat sotuvchi sotuv kiritishi mumkin';end if;
 if p_id is null then
  insert into public.sales(project_id,unit_label,buyer_name,buyer_phone,price,paid,seller_id,sold_on) values(p_project,trim(p_unit),trim(p_buyer),trim(p_phone),p_price,p_paid,themelio_private.work_uid(),p_date) returning id into result;
 else
  update public.sales set project_id=p_project,unit_label=trim(p_unit),buyer_name=trim(p_buyer),buyer_phone=trim(p_phone),price=p_price,paid=p_paid,sold_on=p_date,updated_at=now() where id=p_id and (seller_id=themelio_private.work_uid() or themelio_private.is_director()) returning id into result;
  if not found then raise exception 'Sotuv topilmadi yoki tahrirlashga ruxsat yo‘q';end if;
 end if;
 return result;
end;
$$;
create or replace function public.staff_directory() returns table(id uuid,name text,"position" text,project_id uuid) language sql stable security definer set search_path='' as $$
 select m.id,m.name,m.position,m.project_id from public.members m where themelio_private.is_active() and m.status='active' and m.employment_status='employed';
$$;
create or replace function public.save_site(p_id uuid,p_name text,p_address text,p_blocks integer,p_floors integer,p_finish date,p_progress integer default 0) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_blocks is null or p_floors is null or p_finish is null or length(trim(coalesce(p_address,'')))=0 then raise exception 'Obyekt ma’lumotlarini to‘ldiring';end if;
 if p_id is null then
 insert into public.projects(name,city,address,block_count,floor_count,planned_finish,progress,created_by) values(trim(p_name),left(trim(p_address),120),trim(p_address),p_blocks,p_floors,p_finish,p_progress,themelio_private.work_uid()) returning id into result;
 else update public.projects set name=trim(p_name),address=trim(p_address),block_count=p_blocks,floor_count=p_floors,planned_finish=p_finish,progress=p_progress where id=p_id returning id into result;
 if not found then raise exception 'Project not found';end if;end if;return result;
end;
$$;
create or replace function public.attach_project_document(p_project uuid,p_name text,p_path text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if split_part(p_path,'/',1)<>themelio_private.work_uid()::text or split_part(p_path,'/',2)<>p_project::text then raise exception 'Invalid document path';end if;
 if not exists(select 1 from storage.objects where bucket_id='project-documents' and name=p_path and metadata->>'mimetype'='application/pdf' and (metadata->>'size')::bigint between 1 and 10485760) then raise exception 'PDF hujjat topilmadi';end if;
 insert into public.project_documents(project_id,name,path,created_by) values(p_project,p_name,p_path,themelio_private.work_uid()) on conflict(path) do update set name=excluded.name returning id into result;return result;
end;
$$;
create or replace function public.remove_project_document(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin if not themelio_private.is_director() then raise exception 'Director access required';end if;delete from public.project_documents where id=p_id;end;
$$;
create or replace function public.save_inventory_item(p_id uuid,p_name text,p_unit text,p_archived boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;site uuid:=themelio_private.my_project();current_item public.inventory_items;
begin
 if themelio_private.staff_role() is distinct from 'warehouse' or site is null then raise exception 'Omborchi va biriktirilgan obyekt talab qilinadi';end if;
 if p_id is null then insert into public.inventory_items(project_id,name,unit) values(site,trim(p_name),trim(p_unit)) returning id into result;
 else
 select * into current_item from public.inventory_items where id=p_id and project_id=site for update;
 if not found then raise exception 'Material topilmadi';end if;
 if trim(p_unit) is distinct from current_item.unit and exists(select 1 from public.inventory_movements where item_id=p_id) then raise exception 'Harakat mavjud: o‘lchov birligini o‘zgartirib bo‘lmaydi';end if;
 update public.inventory_items set name=trim(p_name),unit=trim(p_unit),archived=p_archived where id=p_id and project_id=site and (not p_archived or quantity=0) returning id into result;
 if not found then raise exception 'Material topilmadi yoki qoldiq mavjud';end if;end if;return result;
end;
$$;
create or replace function public.move_inventory(p_id uuid,p_item uuid,p_kind text,p_quantity numeric,p_brigadier uuid default null,p_reference uuid default null,p_note text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare item public.inventory_items;issued public.inventory_movements;existing public.inventory_movements;site uuid:=themelio_private.my_project();qty numeric(16,3);
begin
 if themelio_private.staff_role() is distinct from 'warehouse' or site is null then raise exception 'Omborchi va biriktirilgan obyekt talab qilinadi';end if;
 if p_id is null or p_kind is null or p_kind not in ('receipt','issue','return') or p_quantity is null or p_quantity<=0 or p_quantity>=10000000000000 or p_quantity<>round(p_quantity,3) then raise exception 'Miqdor noto‘g‘ri';end if;
 select * into item from public.inventory_items where id=p_item and project_id=site and not archived for update;
 if not found then raise exception 'Material topilmadi';end if;
 -- Stable operation UUID makes retries safe after a lost HTTP response.
 select * into existing from public.inventory_movements where id=p_id;
 if found then
 if existing.created_by=themelio_private.work_uid() and existing.item_id=p_item and existing.kind=p_kind and existing.quantity=p_quantity and existing.brigadier_id is not distinct from p_brigadier and existing.reference_id is not distinct from p_reference then return p_id;end if;
 raise exception 'Operation ID conflict';end if;
 if p_kind='receipt' then
 if p_brigadier is not null or p_reference is not null then raise exception 'Invalid receipt';end if;qty=p_quantity;
 elsif p_kind='issue' then
 if p_reference is not null or not exists(select 1 from public.members where id=p_brigadier and employment_status='employed' and status='active' and project_id=site and lower(trim(position)) in ('brigadir','brigadar','brigada boshlig‘i','brigada boshlig''i','бригадир')) then raise exception 'Shu obyekt brigadirini tanlang';end if;
 if item.quantity<p_quantity then raise exception 'Omborda yetarli miqdor yo‘q';end if;qty=-p_quantity;
 else
 select * into issued from public.inventory_movements where id=p_reference and item_id=p_item and kind='issue';
 if not found or p_brigadier is distinct from issued.brigadier_id then raise exception 'Invalid return reference';end if;
 if p_quantity>issued.quantity-coalesce((select sum(quantity) from public.inventory_movements where reference_id=p_reference and kind='return'),0) then raise exception 'Qaytarish miqdori berilgan miqdordan oshdi';end if;qty=p_quantity;
 end if;
 update public.inventory_items set quantity=quantity+qty where id=p_item;
 insert into public.inventory_movements(id,item_id,project_id,kind,quantity,brigadier_id,reference_id,note,created_by) values(p_id,p_item,site,p_kind,p_quantity,p_brigadier,p_reference,coalesce(p_note,''),themelio_private.work_uid());return p_id;
end;
$$;
create or replace function public.allocation_labels() returns table(id uuid,name text,unit text) language sql stable security definer set search_path='' as $$
 select i.id,i.name,i.unit from public.inventory_items i where themelio_private.staff_role()='brigadier' and exists(select 1 from public.inventory_movements m where m.item_id=i.id and m.brigadier_id=themelio_private.work_uid() and m.project_id=themelio_private.my_project());
$$;
create or replace function public.review_worker(p_id uuid,p_approve boolean,p_reason text default null) returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'foreman' then raise exception 'Prorab huquqi kerak';end if;
 if p_approve is null or (not p_approve and length(trim(coalesce(p_reason,'')))=0) then raise exception 'Rad etish sababini yozing';end if;
 if p_approve and exists(select 1 from public.construction_workers where id=p_id and project_id=themelio_private.my_project() and (passport_number is null or jshshir is null)) then raise exception 'Brigadir pasport raqami va JSHSHIRni to‘ldirishi kerak';end if;
 update public.construction_workers set status=case when p_approve then 'approved' else 'rejected' end,reason=case when p_approve then null else trim(p_reason) end,reviewed_by=themelio_private.work_uid(),reviewed_at=now() where id=p_id and project_id=themelio_private.my_project() and status='pending';
 if not found then raise exception 'Quruvchi topilmadi yoki ko‘rib chiqilgan';end if;
end;
$$;
create or replace function public.submit_worker_verified(p_id uuid,p_name text,p_duty text,p_passport_number text,p_jshshir text,p_paths text[]) returns uuid language plpgsql security definer set search_path='' as $$
declare path text;existing public.construction_workers;passport text:=upper(trim(p_passport_number));pin text:=trim(p_jshshir);
begin
 if themelio_private.staff_role() is distinct from 'brigadier' or themelio_private.my_project() is null then raise exception 'Brigadir va biriktirilgan obyekt talab qilinadi';end if;
 if passport is null or passport !~ '^[A-Z]{2}[0-9]{6,7}$' then raise exception 'Pasport raqami: 2 ta harf va 6–7 ta raqam';end if;
 if pin is null or pin !~ '^[0-9]{14}$' then raise exception 'JSHSHIR 14 ta raqamdan iborat bo‘lishi kerak';end if;
 if p_id is null then raise exception 'Worker ID required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select * into existing from public.construction_workers where id=p_id for update;
 if found then
 if existing.brigadier_id<>themelio_private.work_uid() or existing.project_id<>themelio_private.my_project() then raise exception 'Access denied';end if;
 if existing.status='pending' and existing.name=trim(p_name) and existing.duty=trim(p_duty) and existing.passport_number=passport and existing.jshshir=pin and existing.photo_paths=p_paths then return p_id;end if;
 if existing.status not in ('pending','rejected') then raise exception 'Tasdiqlangan quruvchini o‘zgartirib bo‘lmaydi';end if;
 end if;
 if p_paths is null or cardinality(p_paths) not between 1 and 4 or cardinality(p_paths)<>(select count(distinct v) from unnest(p_paths) v) then raise exception '1–4 ta pasport rasmi kerak';end if;
 foreach path in array p_paths loop
 if split_part(path,'/',1)<>themelio_private.work_uid()::text or split_part(path,'/',2)<>p_id::text or not exists(select 1 from storage.objects where bucket_id='worker-passports' and name=path and metadata->>'mimetype' in ('image/jpeg','image/png') and (metadata->>'size')::bigint between 1 and 5242880) then raise exception 'Pasport rasmi topilmadi';end if;
 end loop;
 insert into public.construction_workers(id,project_id,brigadier_id,name,duty,passport_data,passport_number,jshshir,photo_paths)
 values(p_id,themelio_private.my_project(),themelio_private.work_uid(),trim(p_name),trim(p_duty),passport,passport,pin,p_paths)
 on conflict(id) do update set name=excluded.name,duty=excluded.duty,passport_data=excluded.passport_data,passport_number=excluded.passport_number,jshshir=excluded.jshshir,photo_paths=excluded.photo_paths,status='pending',reason=null,reviewed_by=null,reviewed_at=null;
 return p_id;
end;
$$;
create or replace function public.dismiss_worker(p_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'foreman' then raise exception 'Prorab huquqi kerak';end if;
 if length(trim(coalesce(p_reason,''))) not between 1 and 2000 then raise exception 'Ishdan bo‘shatish sababini yozing';end if;
 update public.construction_workers set status='dismissed',dismissal_reason=trim(p_reason),dismissed_at=now(),dismissed_by=themelio_private.work_uid() where id=p_id and project_id=themelio_private.my_project() and status='approved';
 if not found then raise exception 'Faol quruvchi topilmadi';end if;
end;
$$;
create or replace function public.accounting_staff() returns table(id uuid,name text,"position" text,project_id uuid,employment_status text) language sql stable security definer set search_path='' as $$
 select m.id,m.name,m.position,m.project_id,m.employment_status from public.members m where themelio_private.staff_role()='accountant' and m.app_role='employee' and m.status='active' ;
$$;
create or replace function public.brigade_headcounts() returns table(brigadier_id uuid,name text,project_id uuid,project_name text,worker_count bigint) language sql stable security definer set search_path='' as $$
 select m.id,m.name,m.project_id,p.name,(select count(*) from public.construction_workers w where w.brigadier_id=m.id and w.status='approved') from public.members m left join public.projects p on p.id=m.project_id
 where themelio_private.staff_role()='accountant' and m.app_role='employee' and m.status='active' and m.employment_status='employed' and lower(trim(m.position)) in ('brigadir','brigadar','brigada boshlig‘i','brigada boshlig''i','бригадир');
$$;
create or replace function public.receipt_ledger() returns table(id uuid,project_id uuid,project_name text,item_name text,unit text,quantity numeric,note text,created_at timestamptz) language sql stable security definer set search_path='' as $$
 select m.id,m.project_id,p.name,i.name,i.unit,m.quantity,m.note,m.created_at from public.inventory_movements m join public.inventory_items i on i.id=m.item_id join public.projects p on p.id=m.project_id where themelio_private.staff_role()='accountant' and m.kind='receipt' order by m.created_at desc;
$$;
create or replace function public.save_payroll(p_employee uuid,p_month date,p_amount numeric,p_paid numeric,p_note text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if themelio_private.staff_role() is distinct from 'accountant' then raise exception 'Hisobchi huquqi kerak';end if;
 if not exists(select 1 from public.members where id=p_employee and app_role='employee' and status='active' and employment_status='employed') then raise exception 'Faol xodimni tanlang';end if;
 if p_month is null or extract(day from p_month)<>1 or p_amount is null or p_paid is null or p_amount<0 or p_amount>=100000000000000 or p_paid<0 or p_paid>p_amount or p_amount<>round(p_amount,2) or p_paid<>round(p_paid,2) then raise exception 'Oylik yoki to‘lov miqdori noto‘g‘ri';end if;
 insert into public.payroll(employee_id,month,amount,paid,note,updated_by) values(p_employee,p_month,p_amount,p_paid,coalesce(p_note,''),themelio_private.work_uid()) on conflict(employee_id,month) do update set amount=excluded.amount,paid=excluded.paid,note=excluded.note,updated_by=themelio_private.work_uid(),updated_at=now() returning id into result;return result;
end;
$$;
create or replace function public.save_receipt_cost(p_receipt uuid,p_total numeric,p_paid numeric,p_supplier text default '',p_document text default '',p_note text default '') returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'accountant' then raise exception 'Hisobchi huquqi kerak';end if;
 if not exists(select 1 from public.inventory_movements where id=p_receipt and kind='receipt') then raise exception 'Ombor kirimi topilmadi';end if;
 if p_total is null or p_paid is null or p_total<=0 or p_total>=100000000000000 or p_paid<0 or p_paid>p_total or p_total<>round(p_total,2) or p_paid<>round(p_paid,2) then raise exception 'Xarajat yoki to‘lov miqdori noto‘g‘ri';end if;
 insert into public.receipt_costs(receipt_id,total,paid,supplier,document_ref,note,updated_by) values(p_receipt,p_total,p_paid,trim(coalesce(p_supplier,'')),trim(coalesce(p_document,'')),coalesce(p_note,''),themelio_private.work_uid()) on conflict(receipt_id) do update set total=excluded.total,paid=excluded.paid,supplier=excluded.supplier,document_ref=excluded.document_ref,note=excluded.note,updated_by=themelio_private.work_uid(),updated_at=now();
end;
$$;
create or replace function themelio_private.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if coalesce(new.raw_app_meta_data->>'themelio_role','') not in ('admin','director','employee') then return new;end if;
 if exists(select 1 from public.members where id=new.id) then return new;end if;
 perform pg_advisory_xact_lock(81810210);
 if exists(select 1 from public.members where id=new.id) then return new;end if;
 if new.raw_app_meta_data->>'themelio_role'<>'admin' and (select count(*) from public.members where employment_status<>'deleted' and app_role<>'admin')>=10 then raise exception 'Themelio supports at most 10 accounts';end if;
 insert into public.members(id,login,app_role,position,access_area) values(new.id,new.raw_app_meta_data->>'login',new.raw_app_meta_data->>'themelio_role',new.raw_app_meta_data->>'position',
 case when new.raw_app_meta_data->>'themelio_role'='employee' and (new.raw_app_meta_data->>'access_area'='sales' or lower(trim(new.raw_app_meta_data->>'position'))='sotuvchi') then 'sales' else 'operations' end);
 return new;
end;
$$;
create or replace function themelio_private.file_allowed(p_bucket text,p_path text,p_action text) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if themelio_private.is_admin() then
  if p_action='read' then return true;end if;
  if p_action='insert' then return exists(select 1 from public.members where id::text=split_part(p_path,'/',1));end if;
  if p_action='delete' then return (p_bucket='project-documents' and not exists(select 1 from public.project_documents where path=p_path)) or (p_bucket='worker-passports' and not exists(select 1 from public.construction_workers where p_path=any(photo_paths)));end if;
 end if;
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

create policy owner_report_upload on storage.objects for insert to authenticated with check(bucket_id='report-photos' and themelio_private.is_admin());
drop policy report_photo_insert_guard on storage.objects;
create policy report_photo_insert_guard on storage.objects as restrictive for insert to authenticated with check(bucket_id<>'report-photos' or themelio_private.is_admin() or ((storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active()));
drop policy report_photo_delete_guard on storage.objects;
create policy report_photo_delete_guard on storage.objects as restrictive for delete to authenticated using(bucket_id<>'report-photos' or ((themelio_private.is_admin() or (themelio_private.is_active() and (storage.foldername(name))[1]=auth.uid()::text)) and not exists(select 1 from public.reports where name=any(photo_paths))));
create policy owner_report_cleanup on storage.objects for delete to authenticated using(bucket_id='report-photos' and themelio_private.is_admin() and not exists(select 1 from public.reports where name=any(photo_paths)));
create function public.admin_open_cabinet(p_target uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not themelio_private.is_admin() then raise exception 'Admin access required';end if;
 if not exists(select 1 from public.members where id=p_target and app_role in ('director','employee') and employment_status='employed') then raise exception 'Faol hisob topilmadi';end if;
 insert into public.admin_audit(actor_id,target_id,action) values(auth.uid(),p_target,'open-cabinet');
end;
$$;
create function public.admin_update_account(p_id uuid,p_position text,p_project uuid,p_state text) returns void language plpgsql security definer set search_path='' as $$
declare target public.members;
begin
 if not themelio_private.is_admin() then raise exception 'Admin access required';end if;
 select * into target from public.members where id=p_id for update;
 if not found or target.app_role='admin' then raise exception 'Hisobni o‘zgartirish mumkin emas';end if;
 if target.employment_status='deleted' then raise exception 'Deleted profiles cannot be restored';end if;
 if p_state not in ('employed','dismissed','deleted') or p_state is null then raise exception 'Invalid employee state';end if;
 if target.app_role='director' and (p_state='deleted' or p_position<>'Direktor') then raise exception 'Direktor profilini o‘chirish mumkin emas';end if;
 if length(trim(coalesce(p_position,''))) not between 1 and 80 then raise exception 'Lavozim nomini kiriting';end if;
 if p_state='deleted' then perform public.set_employee_state(p_id,'deleted');else
 update public.members set position=trim(p_position),project_id=p_project,employment_status=p_state,access_area=case when lower(trim(p_position)) in ('sotuvchi','продавец') then 'sales' else 'operations' end where id=p_id;
 end if;
 insert into public.admin_audit(actor_id,target_id,action) values(auth.uid(),p_id,'update-account:'||p_state);
end;
$$;
-- Exact signature allowlist: no arbitrary SQL, schema changes, Auth role writes or nested dispatch.
create function public.admin_act(p_target uuid,p_action text,p_args jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare fn oid;proc record;args text:='';i integer;key text;value_type text;result jsonb;previous text:=current_setting('zulfon.work_member',true);
begin
 if not themelio_private.is_admin() then raise exception 'Admin access required';end if;
 if p_target is not null and not exists(select 1 from public.members where id=p_target and app_role in ('director','employee') and employment_status='employed') then raise exception 'Faol hisob topilmadi';end if;
 if jsonb_typeof(p_args) is distinct from 'object' then raise exception 'Invalid arguments';end if;
 fn:=case p_action
 when 'complete_profile' then 'public.complete_profile(text,text,text,text,date)'::regprocedure::oid
 when 'submit_report' then 'public.submit_report(text,text,text,date)'::regprocedure::oid
 when 'review_report' then 'public.review_report(uuid)'::regprocedure::oid
 when 'create_task' then 'public.create_task(text,text,uuid,date,text)'::regprocedure::oid
 when 'update_task_progress' then 'public.update_task_progress(uuid,integer)'::regprocedure::oid
 when 'send_message' then 'public.send_message(uuid,text)'::regprocedure::oid
 when 'submit_report_with_photos' then 'public.submit_report_with_photos(uuid,text,text,text,date,text[])'::regprocedure::oid
 when 'set_employee_state' then 'public.set_employee_state(uuid,text)'::regprocedure::oid
 when 'save_project' then 'public.save_project(uuid,text,text,text,integer,date)'::regprocedure::oid
 when 'assign_employee_project' then 'public.assign_employee_project(uuid,uuid)'::regprocedure::oid
 when 'decide_report' then 'public.decide_report(uuid,text,text)'::regprocedure::oid
 when 'save_task' then 'public.save_task(uuid,text,text,uuid,date,text,integer,uuid)'::regprocedure::oid
 when 'delete_task' then 'public.delete_task(uuid)'::regprocedure::oid
 when 'save_sale' then 'public.save_sale(uuid,uuid,text,text,text,numeric,numeric,date)'::regprocedure::oid
 when 'staff_directory' then 'public.staff_directory()'::regprocedure::oid
 when 'save_site' then 'public.save_site(uuid,text,text,integer,integer,date,integer)'::regprocedure::oid
 when 'attach_project_document' then 'public.attach_project_document(uuid,text,text)'::regprocedure::oid
 when 'remove_project_document' then 'public.remove_project_document(uuid)'::regprocedure::oid
 when 'save_inventory_item' then 'public.save_inventory_item(uuid,text,text,boolean)'::regprocedure::oid
 when 'move_inventory' then 'public.move_inventory(uuid,uuid,text,numeric,uuid,uuid,text)'::regprocedure::oid
 when 'allocation_labels' then 'public.allocation_labels()'::regprocedure::oid
 when 'review_worker' then 'public.review_worker(uuid,boolean,text)'::regprocedure::oid
 when 'submit_worker_verified' then 'public.submit_worker_verified(uuid,text,text,text,text,text[])'::regprocedure::oid
 when 'dismiss_worker' then 'public.dismiss_worker(uuid,text)'::regprocedure::oid
 when 'accounting_staff' then 'public.accounting_staff()'::regprocedure::oid
 when 'brigade_headcounts' then 'public.brigade_headcounts()'::regprocedure::oid
 when 'receipt_ledger' then 'public.receipt_ledger()'::regprocedure::oid
 when 'save_payroll' then 'public.save_payroll(uuid,date,numeric,numeric,text)'::regprocedure::oid
 when 'save_receipt_cost' then 'public.save_receipt_cost(uuid,numeric,numeric,text,text,text)'::regprocedure::oid
 else null end;
 if fn is null then raise exception 'Operation not allowed';end if;
 select * into proc from pg_proc where oid=fn;
 for key in select jsonb_object_keys(p_args) loop
 if not key=any(proc.proargnames[1:proc.pronargs]) then raise exception 'Unknown argument: %',key;end if;
 end loop;
 for i in 1..proc.pronargs loop
 key:=proc.proargnames[i];if not p_args ? key then continue;end if;
 value_type:=pg_catalog.format_type(proc.proargtypes[i-1],null);
 if args<>'' then args:=args||',';end if;
 if right(value_type,2)='[]' then args:=args||format('%I => (case when $1->%L=''null''::jsonb then null else array(select jsonb_array_elements_text($1->%L)) end)::%s',key,key,key,value_type);
 else args:=args||format('%I => ($1->>%L)::%s',key,key,value_type);end if;
 end loop;
 perform set_config('zulfon.work_member',coalesce(p_target::text,''),true);
 if proc.proretset then execute format('select coalesce(jsonb_agg(to_jsonb(x)),''[]''::jsonb) from public.%I(%s) x',proc.proname,args) into result using p_args;
 else execute format('select to_jsonb(public.%I(%s))',proc.proname,args) into result using p_args;end if;
 perform set_config('zulfon.work_member',coalesce(previous,''),true);
 if p_action not in ('staff_directory','allocation_labels','accounting_staff','brigade_headcounts','receipt_ledger') then
 insert into public.admin_audit(actor_id,target_id,action) values(auth.uid(),p_target,p_action);
 end if;
 return result;
end;
$$;
revoke all on function public.admin_open_cabinet(uuid),public.admin_update_account(uuid,text,uuid,text),public.admin_act(uuid,text,jsonb) from public,anon;
grant execute on function public.admin_open_cabinet(uuid),public.admin_update_account(uuid,text,uuid,text),public.admin_act(uuid,text,jsonb) to authenticated;
commit;
select 'Admin tizimi tayyor. scripts/create-admin.sql orqali egasi hisobini yarating.' as status;
