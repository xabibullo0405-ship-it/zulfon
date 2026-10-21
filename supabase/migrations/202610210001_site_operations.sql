-- Zulfon: project documents, staff chat, warehouse and approved construction workers.
-- Run once after 202610160002_management_workflows.sql. Existing rows are retained.
begin;
alter table public.projects add column block_count integer check(block_count between 1 and 1000);
alter table public.projects add column floor_count integer check(floor_count between 1 and 300);
-- Older objects remain valid; complete their new fields when editing.
create function themelio_private.staff_role() returns text language sql stable security definer set search_path='' as $$
 select case when app_role='director' then 'director'
 when lower(trim(position)) in ('omborchi','кладовщик') then 'warehouse'
 when lower(trim(position)) in ('prorab','прораб') then 'foreman'
 when lower(trim(position)) in ('brigadir','brigadar','brigada boshlig‘i','brigada boshlig''i','бригадир') then 'brigadier'
 else 'employee' end from public.members where id=auth.uid() and employment_status='employed' and status='active';
$$;
create function themelio_private.my_project() returns uuid language sql stable security definer set search_path='' as $$
 select project_id from public.members where id=auth.uid() and employment_status='employed' and status='active';
$$;
revoke all on function themelio_private.staff_role(),themelio_private.my_project() from public;
grant execute on function themelio_private.staff_role(),themelio_private.my_project() to authenticated;
create function public.staff_directory() returns table(id uuid,name text,"position" text,project_id uuid) language sql stable security definer set search_path='' as $$
 select m.id,m.name,m.position,m.project_id from public.members m where themelio_private.is_active() and m.status='active' and m.employment_status='employed';
$$;
create or replace function public.send_message(p_recipient uuid,p_body text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_active() then raise exception 'Complete your profile first';end if;
 if not exists(select 1 from public.members where id=p_recipient and status='active' and employment_status='employed') then raise exception 'Recipient unavailable';end if;
 insert into public.messages(sender_id,recipient_id,body) values(auth.uid(),p_recipient,trim(p_body)) returning id into result;return result;
end;
$$;
create function public.save_site(p_id uuid,p_name text,p_address text,p_blocks integer,p_floors integer,p_finish date,p_progress integer default 0) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if p_blocks is null or p_floors is null or p_finish is null or length(trim(coalesce(p_address,'')))=0 then raise exception 'Obyekt ma’lumotlarini to‘ldiring';end if;
 if p_id is null then
 insert into public.projects(name,city,address,block_count,floor_count,planned_finish,progress,created_by) values(trim(p_name),left(trim(p_address),120),trim(p_address),p_blocks,p_floors,p_finish,p_progress,auth.uid()) returning id into result;
 else update public.projects set name=trim(p_name),address=trim(p_address),block_count=p_blocks,floor_count=p_floors,planned_finish=p_finish,progress=p_progress where id=p_id returning id into result;
 if not found then raise exception 'Project not found';end if;end if;return result;
end;
$$;
create table public.project_documents(
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id),
 name text not null check(length(name) between 1 and 200),path text not null unique,created_by uuid not null references public.members(id),created_at timestamptz not null default now()
);
alter table public.project_documents enable row level security;
create policy site_doc_read on public.project_documents for select to authenticated using(themelio_private.is_director() or (themelio_private.is_active() and project_id=themelio_private.my_project()));
create function public.attach_project_document(p_project uuid,p_name text,p_path text) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not themelio_private.is_director() then raise exception 'Director access required';end if;
 if split_part(p_path,'/',1)<>auth.uid()::text or split_part(p_path,'/',2)<>p_project::text then raise exception 'Invalid document path';end if;
 if not exists(select 1 from storage.objects where bucket_id='project-documents' and name=p_path and metadata->>'mimetype'='application/pdf' and (metadata->>'size')::bigint between 1 and 10485760) then raise exception 'PDF hujjat topilmadi';end if;
 insert into public.project_documents(project_id,name,path,created_by) values(p_project,p_name,p_path,auth.uid()) on conflict(path) do update set name=excluded.name returning id into result;return result;
end;
$$;
create function public.remove_project_document(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin if not themelio_private.is_director() then raise exception 'Director access required';end if;delete from public.project_documents where id=p_id;end;
$$;
create table public.inventory_items(
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id),
 name text not null check(length(trim(name)) between 1 and 120),unit text not null check(length(trim(unit)) between 1 and 30),
 quantity numeric(16,3) not null default 0 check(quantity>=0),archived boolean not null default false,
 created_at timestamptz not null default now(),unique(project_id,name,unit)
);
create table public.inventory_movements(
 id uuid primary key, item_id uuid not null references public.inventory_items(id),
 project_id uuid not null references public.projects(id),kind text not null check(kind in ('receipt','issue','return')),
 quantity numeric(16,3) not null check(quantity>0),brigadier_id uuid references public.members(id),
 reference_id uuid references public.inventory_movements(id),note text not null default '' check(length(note)<=1000),
 created_by uuid not null references public.members(id),created_at timestamptz not null default now(),
 check((kind='receipt' and brigadier_id is null and reference_id is null) or (kind='issue' and brigadier_id is not null and reference_id is null) or (kind='return' and brigadier_id is not null and reference_id is not null))
);
create index inventory_project on public.inventory_items(project_id);
create index movements_recipient on public.inventory_movements(brigadier_id,project_id);
alter table public.inventory_items enable row level security;
alter table public.inventory_movements enable row level security;
create policy stock_read on public.inventory_items for select to authenticated using(themelio_private.is_director() or (project_id=themelio_private.my_project() and themelio_private.staff_role() in ('warehouse','foreman')));
create policy movement_read on public.inventory_movements for select to authenticated using(project_id=themelio_private.my_project() and (themelio_private.staff_role() in ('warehouse','foreman') or (themelio_private.staff_role()='brigadier' and brigadier_id=auth.uid())));
create function public.save_inventory_item(p_id uuid,p_name text,p_unit text,p_archived boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
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
create function public.move_inventory(p_id uuid,p_item uuid,p_kind text,p_quantity numeric,p_brigadier uuid default null,p_reference uuid default null,p_note text default '') returns uuid language plpgsql security definer set search_path='' as $$
declare item public.inventory_items;issued public.inventory_movements;existing public.inventory_movements;site uuid:=themelio_private.my_project();qty numeric(16,3);
begin
 if themelio_private.staff_role() is distinct from 'warehouse' or site is null then raise exception 'Omborchi va biriktirilgan obyekt talab qilinadi';end if;
 if p_id is null or p_kind is null or p_kind not in ('receipt','issue','return') or p_quantity is null or p_quantity<=0 or p_quantity>=10000000000000 or p_quantity<>round(p_quantity,3) then raise exception 'Miqdor noto‘g‘ri';end if;
 select * into item from public.inventory_items where id=p_item and project_id=site and not archived for update;
 if not found then raise exception 'Material topilmadi';end if;
 -- Stable operation UUID makes retries safe after a lost HTTP response.
 select * into existing from public.inventory_movements where id=p_id;
 if found then
 if existing.created_by=auth.uid() and existing.item_id=p_item and existing.kind=p_kind and existing.quantity=p_quantity and existing.brigadier_id is not distinct from p_brigadier and existing.reference_id is not distinct from p_reference then return p_id;end if;
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
 insert into public.inventory_movements(id,item_id,project_id,kind,quantity,brigadier_id,reference_id,note,created_by) values(p_id,p_item,site,p_kind,p_quantity,p_brigadier,p_reference,coalesce(p_note,''),auth.uid());return p_id;
end;
$$;
-- A brigadier sees item labels for their allocations, never warehouse balances.
create function public.allocation_labels() returns table(id uuid,name text,unit text) language sql stable security definer set search_path='' as $$
 select i.id,i.name,i.unit from public.inventory_items i where themelio_private.staff_role()='brigadier' and exists(select 1 from public.inventory_movements m where m.item_id=i.id and m.brigadier_id=auth.uid() and m.project_id=themelio_private.my_project());
$$;
create table public.construction_workers(
 id uuid primary key,project_id uuid not null references public.projects(id),brigadier_id uuid not null references public.members(id),
 name text not null check(length(trim(name)) between 1 and 120),duty text not null check(length(trim(duty)) between 1 and 120),
 passport_data text not null check(length(trim(passport_data)) between 3 and 2000),photo_paths text[] not null check(cardinality(photo_paths) between 1 and 4),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),reason text,
 reviewed_by uuid references public.members(id),reviewed_at timestamptz,created_at timestamptz not null default now(),
 check(status<>'rejected' or length(trim(coalesce(reason,'')))>0),check(reason is null or length(reason)<=2000)
);
create index workers_site on public.construction_workers(project_id,brigadier_id);
alter table public.construction_workers enable row level security;
create policy worker_read on public.construction_workers for select to authenticated using(project_id=themelio_private.my_project() and (themelio_private.staff_role()='foreman' or (themelio_private.staff_role()='brigadier' and brigadier_id=auth.uid())));
create function public.submit_worker(p_id uuid,p_name text,p_duty text,p_passport text,p_paths text[]) returns uuid language plpgsql security definer set search_path='' as $$
declare path text;existing public.construction_workers;
begin
 if themelio_private.staff_role() is distinct from 'brigadier' or themelio_private.my_project() is null then raise exception 'Brigadir va biriktirilgan obyekt talab qilinadi';end if;
 select * into existing from public.construction_workers where id=p_id;
 if found then if existing.brigadier_id=auth.uid() then return p_id;end if;raise exception 'Access denied';end if;
 if p_paths is null or cardinality(p_paths) not between 1 and 4 or cardinality(p_paths)<>(select count(distinct v) from unnest(p_paths) v) then raise exception '1–4 ta pasport rasmi kerak';end if;
 foreach path in array p_paths loop
 if split_part(path,'/',1)<>auth.uid()::text or split_part(path,'/',2)<>p_id::text or not exists(select 1 from storage.objects where bucket_id='worker-passports' and name=path and metadata->>'mimetype' in ('image/jpeg','image/png') and (metadata->>'size')::bigint between 1 and 5242880) then raise exception 'Pasport rasmi topilmadi';end if;
 end loop;
 insert into public.construction_workers(id,project_id,brigadier_id,name,duty,passport_data,photo_paths) values(p_id,themelio_private.my_project(),auth.uid(),trim(p_name),trim(p_duty),trim(p_passport),p_paths);return p_id;
end;
$$;
create function public.review_worker(p_id uuid,p_approve boolean,p_reason text default null) returns void language plpgsql security definer set search_path='' as $$
begin
 if themelio_private.staff_role() is distinct from 'foreman' then raise exception 'Prorab huquqi kerak';end if;
 if p_approve is null or (not p_approve and length(trim(coalesce(p_reason,'')))=0) then raise exception 'Rad etish sababini yozing';end if;
 update public.construction_workers set status=case when p_approve then 'approved' else 'rejected' end,reason=case when p_approve then null else trim(p_reason) end,reviewed_by=auth.uid(),reviewed_at=now() where id=p_id and project_id=themelio_private.my_project() and status='pending';
 if not found then raise exception 'Quruvchi topilmadi yoki ko‘rib chiqilgan';end if;
end;
$$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('project-documents','project-documents',false,10485760,array['application/pdf']),
 ('worker-passports','worker-passports',false,5242880,array['image/jpeg','image/png']);
create function themelio_private.file_allowed(p_bucket text,p_path text,p_action text) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if not themelio_private.is_active() then return false;end if;
 if p_bucket='project-documents' then
 if p_action='insert' then return themelio_private.is_director() and split_part(p_path,'/',1)=auth.uid()::text and exists(select 1 from public.projects where id::text=split_part(p_path,'/',2));end if;
 if p_action='read' then return (themelio_private.is_director() and split_part(p_path,'/',1)=auth.uid()::text) or exists(select 1 from public.project_documents where path=p_path and (themelio_private.is_director() or project_id=themelio_private.my_project()));end if;
 if p_action='delete' then return themelio_private.is_director() and not exists(select 1 from public.project_documents where path=p_path);end if;
 elsif p_bucket='worker-passports' then
 if p_action='insert' then return themelio_private.staff_role()='brigadier' and themelio_private.my_project() is not null and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.construction_workers where id::text=split_part(p_path,'/',2));end if;
 if p_action='read' then return exists(select 1 from public.construction_workers where p_path=any(photo_paths) and project_id=themelio_private.my_project() and (themelio_private.staff_role()='foreman' or (themelio_private.staff_role()='brigadier' and brigadier_id=auth.uid()))) or (themelio_private.staff_role()='brigadier' and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.construction_workers where id::text=split_part(p_path,'/',2)));end if;
 if p_action='delete' then return themelio_private.staff_role()='brigadier' and split_part(p_path,'/',1)=auth.uid()::text and not exists(select 1 from public.construction_workers where p_path=any(photo_paths));end if;
 end if;return false;
end;
$$;
revoke all on function themelio_private.file_allowed(text,text,text) from public;
grant execute on function themelio_private.file_allowed(text,text,text) to authenticated;
create policy site_files_read on storage.objects for select to authenticated using(bucket_id in ('project-documents','worker-passports') and themelio_private.file_allowed(bucket_id,name,'read'));
create policy site_files_insert on storage.objects for insert to authenticated with check(bucket_id in ('project-documents','worker-passports') and themelio_private.file_allowed(bucket_id,name,'insert'));
create policy site_files_delete on storage.objects for delete to authenticated using(bucket_id in ('project-documents','worker-passports') and themelio_private.file_allowed(bucket_id,name,'delete'));
create policy site_files_read_guard on storage.objects as restrictive for select to authenticated using(bucket_id not in ('project-documents','worker-passports') or themelio_private.file_allowed(bucket_id,name,'read'));
create policy site_files_insert_guard on storage.objects as restrictive for insert to authenticated with check(bucket_id not in ('project-documents','worker-passports') or themelio_private.file_allowed(bucket_id,name,'insert'));
create policy site_files_delete_guard on storage.objects as restrictive for delete to authenticated using(bucket_id not in ('project-documents','worker-passports') or themelio_private.file_allowed(bucket_id,name,'delete'));
create policy site_files_no_update on storage.objects as restrictive for update to authenticated using(bucket_id not in ('project-documents','worker-passports')) with check(bucket_id not in ('project-documents','worker-passports'));
create policy site_files_no_anon on storage.objects as restrictive for all to anon using(bucket_id not in ('project-documents','worker-passports')) with check(bucket_id not in ('project-documents','worker-passports'));
revoke all on public.project_documents,public.inventory_items,public.inventory_movements,public.construction_workers from anon,authenticated;
grant select on public.project_documents,public.inventory_items,public.inventory_movements,public.construction_workers to authenticated;
grant all on public.project_documents,public.inventory_items,public.inventory_movements,public.construction_workers to service_role;
revoke all on function public.staff_directory(),public.save_site(uuid,text,text,integer,integer,date,integer),public.attach_project_document(uuid,text,text),public.remove_project_document(uuid),public.save_inventory_item(uuid,text,text,boolean),public.move_inventory(uuid,uuid,text,numeric,uuid,uuid,text),public.allocation_labels(),public.submit_worker(uuid,text,text,text,text[]),public.review_worker(uuid,boolean,text) from public,anon;
grant execute on function public.staff_directory(),public.save_site(uuid,text,text,integer,integer,date,integer),public.attach_project_document(uuid,text,text),public.remove_project_document(uuid),public.save_inventory_item(uuid,text,text,boolean),public.move_inventory(uuid,uuid,text,numeric,uuid,uuid,text),public.allocation_labels(),public.submit_worker(uuid,text,text,text,text[]),public.review_worker(uuid,boolean,text) to authenticated;
do $$declare tab text;begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
 foreach tab in array array['project_documents','inventory_items','inventory_movements','construction_workers'] loop execute format('alter publication supabase_realtime add table public.%I',tab);end loop;
 end if;
end $$;
commit;
select 'Obyektlar, ombor va quruvchilar tayyor' as status;
