-- Run once after 202610260001_material_usage.sql. History is retained.
begin;
do $$begin
 if to_regprocedure('public.admin_act(uuid,text,jsonb)') is null then raise exception 'Avval 202610240001_owner_admin.sql migratsiyasini bajaring';end if;
end $$;
-- Deleted director profiles remain as history; only one non-deleted director is allowed.
drop index public.one_director;
create unique index one_director on public.members(app_role) where app_role='director' and employment_status<>'deleted';
create function public.admin_delete_account(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare target public.members;
begin
 if not themelio_private.is_admin() then raise exception 'Admin access required';end if;
 select * into target from public.members where id=p_id for update;
 if not found or target.app_role='admin' or p_id=auth.uid() then raise exception 'Admin hisobini o‘chirish mumkin emas';end if;
 if target.employment_status='deleted' then return;end if;
 update public.members set employment_status='deleted',name='O‘chirilgan foydalanuvchi',phone='',contact_email='',address='',birth_date=null,project_id=null where id=p_id;
 insert into public.admin_audit(actor_id,target_id,action) values(auth.uid(),p_id,'delete-account');
end;
$$;
revoke all on function public.admin_delete_account(uuid) from public,anon;
grant execute on function public.admin_delete_account(uuid) to authenticated;
commit;
select 'Admin foydalanuvchilarni o‘chira oladi' as status;
