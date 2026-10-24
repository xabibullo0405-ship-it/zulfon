-- Supabase SQL Editor only, as project administrator. Run the ENTIRE file.
-- Creates the missing director with a random password, Auth identity and member profile.
-- Does not reset an existing director or change employee accounts.
-- The helper is temporary and SECURITY INVOKER; it is not a public application RPC.
create temporary table if not exists themelio_bootstrap_scope(marker integer) on commit drop;
create or replace function pg_temp.themelio_create_director()
returns table(login text, new_password text, status text)
language plpgsql security invoker set search_path='' as $$
declare
 v_user_id uuid;
 v_password text;
 v_metadata jsonb;
 v_existing_login text;
begin
 if to_regclass('public.members') is null then
  raise exception 'Avval scripts/repair-schema.sql faylini bajaring.';
 end if;
 perform pg_advisory_xact_lock(81810210);
 select m.login into v_existing_login from public.members m where m.app_role='director';
 if found then
  return query select v_existing_login, null::text,
   'Direktor hisobi allaqachon bor. Parol o‘zgartirilmadi; reset-director.sql faylidan foydalaning.'::text;
  return;
 end if;
 if (select count(*) from public.members where app_role<>'admin')>=10 then
  raise exception '10 ta hisob chegarasiga yetilgan. Hech qanday hisob o‘zgartirilmadi.';
 end if;
 select u.id into v_user_id from auth.users u where lower(u.email)='direktor@accounts.themelio.invalid';
 if v_user_id is not null and exists(select 1 from public.members m where m.id=v_user_id) then
  raise exception 'Bu email boshqa xodimga tegishli. Hech qanday hisob o‘zgartirilmadi.';
 end if;
 if exists(select 1 from public.members m where m.login='direktor') then
  raise exception 'direktor logini band. Hech qanday hisob o‘zgartirilmadi.';
 end if;
 v_password:=encode(extensions.gen_random_bytes(24),'hex');
 v_metadata:=jsonb_build_object('provider','email','providers',jsonb_build_array('email'),
                              'themelio_role','director','login','direktor','position','Direktor');
 if v_user_id is null then
  v_user_id:=gen_random_uuid();
  insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
                         raw_app_meta_data,raw_user_meta_data,created_at,updated_at,
                         confirmation_token,recovery_token,email_change_token_new,email_change,
                         email_change_token_current,reauthentication_token)
  values('00000000-0000-0000-0000-000000000000',v_user_id,'authenticated','authenticated',
         'direktor@accounts.themelio.invalid',extensions.crypt(v_password,extensions.gen_salt('bf')),
         now(),v_metadata,'{}'::jsonb,now(),now(),'','','','','','');
  -- The migration's Auth trigger normally inserts this row.
  insert into public.members(id,login,app_role,position)
  values(v_user_id,'direktor','director','Direktor') on conflict(id) do nothing;
 else
  -- Recover an Auth user created before the members table/trigger was installed.
  update auth.users u set encrypted_password=extensions.crypt(v_password,extensions.gen_salt('bf')),
   email_confirmed_at=coalesce(u.email_confirmed_at,now()),
   raw_app_meta_data=coalesce(u.raw_app_meta_data,'{}'::jsonb)||v_metadata,
   confirmation_token=coalesce(u.confirmation_token,''),recovery_token=coalesce(u.recovery_token,''),
   email_change_token_new=coalesce(u.email_change_token_new,''),email_change=coalesce(u.email_change,''),
   email_change_token_current=coalesce(u.email_change_token_current,''),
   reauthentication_token=coalesce(u.reauthentication_token,''),updated_at=now()
  where u.id=v_user_id;
  insert into public.members(id,login,app_role,position) values(v_user_id,'direktor','director','Direktor') on conflict(id) do nothing;
 end if;
 if not exists(select 1 from auth.identities i where i.user_id=v_user_id and i.provider='email') then
  insert into auth.identities(id,provider_id,user_id,identity_data,provider,created_at,updated_at)
  values(gen_random_uuid(),v_user_id::text,v_user_id,
   jsonb_build_object('sub',v_user_id::text,'email','direktor@accounts.themelio.invalid','email_verified',true),
   'email',now(),now());
 end if;
 if not exists(select 1 from public.members m where m.id=v_user_id and m.app_role='director') then
  raise exception 'Direktor profili yaratilmadi; amallar bekor qilindi.';
 end if;
 return query select 'direktor'::text,v_password,
  'Direktor yaratildi. Login va new_password bilan saytga kiring. Parolni xavfsiz saqlang.'::text;
end;
$$;
select * from pg_temp.themelio_create_director();
