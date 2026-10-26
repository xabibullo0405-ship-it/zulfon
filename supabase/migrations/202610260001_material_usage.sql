-- Run once after 202610240001_owner_admin.sql. Retains the stock/allocation history.
begin;
do $$begin
 if to_regprocedure('themelio_private.work_uid()') is null or to_regprocedure('public.admin_act(uuid,text,jsonb)') is null then
  raise exception 'Avval 202610240001_owner_admin.sql migratsiyasini bajaring. Hech qanday o‘zgarish kiritilmadi.';
 end if;
end $$;
alter table public.inventory_movements add column operation_id uuid;
alter table public.inventory_movements drop constraint inventory_movements_kind_check;
alter table public.inventory_movements add constraint inventory_movements_kind_check check(kind in ('receipt','issue','return','usage'));
alter table public.inventory_movements drop constraint inventory_movements_check;
alter table public.inventory_movements add constraint inventory_movements_check check(
 (kind='receipt' and brigadier_id is null and reference_id is null and operation_id is null) or
 (kind='issue' and brigadier_id is not null and reference_id is null and operation_id is null) or
 (kind='return' and brigadier_id is not null and reference_id is not null and operation_id is null) or
 (kind='usage' and brigadier_id is not null and reference_id is not null and operation_id is not null)
);
create index inventory_operation on public.inventory_movements(operation_id) where operation_id is not null;
create index inventory_reference on public.inventory_movements(reference_id) where reference_id is not null;
create function public.consume_material(p_id uuid,p_item uuid,p_quantity numeric,p_note text) returns uuid language plpgsql security definer set search_path='' as $$
declare item public.inventory_items;existing public.inventory_movements;issued record;balance numeric;left_to_use numeric:=p_quantity;part numeric;first_entry boolean:=true;who uuid:=themelio_private.work_uid();site uuid:=themelio_private.my_project();
begin
 if themelio_private.staff_role() is distinct from 'brigadier' or site is null then raise exception 'Brigadir va biriktirilgan obyekt talab qilinadi';end if;
 if p_id is null or p_quantity is null or p_quantity<=0 or p_quantity>=10000000000000 or p_quantity<>round(p_quantity,3) then raise exception 'Miqdor noto‘g‘ri';end if;
 if length(trim(coalesce(p_note,''))) not between 1 and 1000 then raise exception 'Material qayerda ishlatilganini yozing';end if;
 -- Same lock as receipts/returns/issues: concurrent operations cannot overdraw an allocation.
 select * into item from public.inventory_items where id=p_item and project_id=site for update;
 if not found then raise exception 'Material topilmadi';end if;
 select * into existing from public.inventory_movements where id=p_id;
 if found then
  if existing.kind='usage' and existing.operation_id=p_id and existing.brigadier_id=who and existing.item_id=p_item and existing.project_id=site and existing.note=trim(p_note) and (select sum(quantity) from public.inventory_movements where operation_id=p_id)=p_quantity then return p_id;end if;
  raise exception 'Operation ID conflict';
 end if;
 select coalesce(sum(case when kind='issue' then quantity else -quantity end),0) into balance from public.inventory_movements where item_id=p_item and brigadier_id=who and project_id=site and kind in ('issue','return','usage');
 if p_quantity>balance then raise exception 'Miqdor qo‘lingizdagi qoldiqdan oshmasligi kerak';end if;
 -- A single use can span several deliveries. Track each portion against its original issue.
 for issued in select m.id,m.quantity-coalesce((select sum(r.quantity) from public.inventory_movements r where r.reference_id=m.id and r.kind in ('return','usage')),0) available from public.inventory_movements m where m.item_id=p_item and m.project_id=site and m.brigadier_id=who and m.kind='issue' order by m.created_at,m.id loop
  if issued.available<=0 then continue;end if;
  part:=least(left_to_use,issued.available);
  insert into public.inventory_movements(id,item_id,project_id,kind,quantity,brigadier_id,reference_id,operation_id,note,created_by)
  values(case when first_entry then p_id else gen_random_uuid() end,p_item,site,'usage',part,who,issued.id,p_id,trim(p_note),who);
  first_entry:=false;left_to_use:=left_to_use-part;
  exit when left_to_use=0;
 end loop;
 if left_to_use<>0 then raise exception 'Material qoldig‘i mos kelmadi. Qayta tekshiring.';end if;
 -- Consumed material stays out of warehouse stock; only the brigade balance decreases.
 return p_id;
end;
$$;
revoke all on function public.consume_material(uuid,uuid,numeric,text) from public,anon;
grant execute on function public.consume_material(uuid,uuid,numeric,text) to authenticated;

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
 if p_quantity>issued.quantity-coalesce((select sum(quantity) from public.inventory_movements where reference_id=p_reference and kind in ('return','usage')),0) then raise exception 'Qaytarish miqdori berilgan miqdordan oshdi';end if;qty=p_quantity;
 end if;
 update public.inventory_items set quantity=quantity+qty where id=p_item;
 insert into public.inventory_movements(id,item_id,project_id,kind,quantity,brigadier_id,reference_id,note,created_by) values(p_id,p_item,site,p_kind,p_quantity,p_brigadier,p_reference,coalesce(p_note,''),themelio_private.work_uid());return p_id;
end;
$$;
create or replace function public.admin_act(p_target uuid,p_action text,p_args jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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
 when 'consume_material' then 'public.consume_material(uuid,uuid,numeric,text)'::regprocedure::oid
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
commit;
select 'Material sarfi tayyor' as status;
