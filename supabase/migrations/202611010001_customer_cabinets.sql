-- Run after 202610260002_account_removal.sql. Customer identities are NOT staff members.
begin;
create table public.customer_accounts(
 id uuid primary key references auth.users(id),sale_id uuid not null unique references public.sales(id),
 login text not null unique,created_by uuid not null references public.members(id),created_at timestamptz not null default now()
);
create table public.customer_weekly_photos(
 id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id),
 week_start date not null,report_id uuid not null references public.reports(id),photo_paths text[] not null,
 created_at timestamptz not null default now(),unique(project_id,week_start)
);
alter table public.customer_accounts enable row level security;
alter table public.customer_weekly_photos enable row level security;
revoke all on public.customer_accounts,public.customer_weekly_photos from public,anon,authenticated;
grant all on public.customer_accounts,public.customer_weekly_photos to service_role;
-- Fail closed even for orphaned customer identities after a failed provisioning attempt.
create function themelio_private.is_customer() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from auth.users where id=auth.uid() and raw_app_meta_data->>'themelio_role'='customer')
 or exists(select 1 from public.customer_accounts where id=auth.uid());
$$;
revoke all on function themelio_private.is_customer() from public;
grant execute on function themelio_private.is_customer() to authenticated;
-- Existing broad staff policies must never reveal director profiles or internal records to customers.
do $$ declare t text;begin
 foreach t in array array['members','reports','tasks','messages','projects','sales','project_documents','inventory_items','inventory_movements','construction_workers','payroll','receipt_costs','admin_audit'] loop
 execute format('create policy customer_boundary on public.%I as restrictive for all to authenticated using(not themelio_private.is_customer()) with check(not themelio_private.is_customer())',t);
 end loop;
end $$;
-- Service-only transaction rechecks sale ownership; the UNIQUE constraint serializes concurrent creation.
create function public.register_customer(p_id uuid,p_sale uuid,p_actor uuid,p_login text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.members where id=p_actor and app_role='employee' and access_area='sales' and status='active' and employment_status='employed') then raise exception 'Faqat faol sotuvchi mijoz kabinetini yaratadi';end if;
 perform 1 from public.sales where id=p_sale and seller_id=p_actor for update;
 if not found then raise exception 'O‘zingiz kiritgan sotuvni tanlang';end if;
 if not exists(select 1 from auth.users where id=p_id and raw_app_meta_data->>'themelio_role'='customer' and raw_app_meta_data->>'login'=p_login) or exists(select 1 from public.members where id=p_id) then raise exception 'Mijoz hisobi yaroqsiz';end if;
 insert into public.customer_accounts(id,sale_id,created_by,login) values(p_id,p_sale,p_actor,p_login);
end;
$$;
revoke all on function public.register_customer(uuid,uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.register_customer(uuid,uuid,uuid,text) to service_role;
create function public.list_customers() returns table(id uuid,sale_id uuid,login text,buyer_name text,buyer_phone text,unit_label text,project_id uuid,project_name text,created_at timestamptz) language sql stable security definer set search_path='' as $$
 select c.id,c.sale_id,c.login,s.buyer_name,s.buyer_phone,s.unit_label,s.project_id,p.name,c.created_at
 from public.customer_accounts c join public.sales s on s.id=c.sale_id join public.projects p on p.id=s.project_id
 where not themelio_private.is_customer() and (themelio_private.is_director() or exists(select 1 from public.members m where m.id=auth.uid() and m.app_role='employee' and m.access_area='sales' and m.status='active' and m.employment_status='employed' and s.seller_id=m.id))
 order by c.created_at desc,c.id;
$$;
create function public.customer_dashboard() returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('name',s.buyer_name,'unit',s.unit_label,'price',s.price,'paid',s.paid,'sold_on',s.sold_on,
 'project',jsonb_build_object('name',p.name,'address',p.address,'progress',p.progress,'planned_finish',p.planned_finish,'blocks',p.block_count,'floors',p.floor_count),
 'updates',coalesce((select jsonb_agg(jsonb_build_object('id',w.id,'date',w.week_start,'photos',w.photo_paths) order by w.week_start desc)
 from public.customer_weekly_photos w join public.reports r on r.id=w.report_id where w.project_id=p.id and r.status<>'rejected'),'[]'::jsonb))
 from public.customer_accounts c join public.sales s on s.id=c.sale_id join public.projects p on p.id=s.project_id where c.id=auth.uid();
$$;
revoke all on function public.list_customers(),public.customer_dashboard() from public,anon;
grant execute on function public.list_customers(),public.customer_dashboard() to authenticated;
-- No scheduler and no copying files: publish the first same-day Monday foreman report's photos.
-- Never backfill old reports; backdated reports, other roles and reports without photos do not qualify.
create function themelio_private.publish_customer_photos() returns trigger language plpgsql security definer set search_path='' as $$
declare d date:=(new.created_at at time zone 'Asia/Tashkent')::date;
begin
 if extract(isodow from d)<>1 or new.report_date<>d or new.project_id is null or cardinality(new.photo_paths)=0 or new.status='rejected' then return new;end if;
 if not exists(select 1 from public.members where id=new.author_id and app_role='employee' and status='active' and employment_status='employed' and project_id=new.project_id and lower(trim(position)) in ('prorab','прораб')) then return new;end if;
 insert into public.customer_weekly_photos(project_id,week_start,report_id,photo_paths) values(new.project_id,d,new.id,new.photo_paths) on conflict(project_id,week_start) do nothing;
 return new;
end;
$$;
revoke all on function themelio_private.publish_customer_photos() from public;
create trigger publish_customer_photos after insert on public.reports for each row execute function themelio_private.publish_customer_photos();
create function themelio_private.customer_photo_allowed(p_path text) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.customer_accounts c join public.sales s on s.id=c.sale_id
 join public.customer_weekly_photos w on w.project_id=s.project_id join public.reports r on r.id=w.report_id
 where c.id=auth.uid() and p_path=any(w.photo_paths) and r.status<>'rejected');
$$;
revoke all on function themelio_private.customer_photo_allowed(text) from public;
grant execute on function themelio_private.customer_photo_allowed(text) to authenticated;
create policy customer_photo_read on storage.objects for select to authenticated using(bucket_id='report-photos' and themelio_private.customer_photo_allowed(name));
drop policy report_photo_read_guard on storage.objects;
create policy report_photo_read_guard on storage.objects as restrictive for select to authenticated using(bucket_id<>'report-photos' or
 ((storage.foldername(name))[1]=auth.uid()::text and themelio_private.is_active()) or
 (themelio_private.is_director() and exists(select 1 from public.reports where name=any(photo_paths))) or themelio_private.customer_photo_allowed(name));
-- Customers can read only selected weekly photos, regardless of unrelated bucket policies.
create policy customer_storage_boundary on storage.objects as restrictive for all to authenticated
 using(not themelio_private.is_customer() or (bucket_id='report-photos' and themelio_private.customer_photo_allowed(name)))
 with check(not themelio_private.is_customer());
commit;
