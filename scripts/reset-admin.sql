-- Run only in your Supabase project's SQL Editor as project administrator.
-- Resets the existing admin only. Does not create users or expose a public RPC.
-- Keep the returned password private; do not paste it into chat or Git.
with target as materialized (
  select u.id, m.login
  from auth.users u
  join public.members m on m.id = u.id
  where m.app_role = 'admin'
), new_password as materialized (
  select 'Aa2!'||encode(extensions.gen_random_bytes(24), 'hex') as value
  where (select count(*) from target) = 1
), updated as (
  update auth.users u
  set encrypted_password = extensions.crypt(p.value, extensions.gen_salt('bf')),
      updated_at = now()
  from target t cross join new_password p
  where u.id = t.id
  returning t.login
)
select updated.login, p.value as new_password,
       'Parol yangilandi. Natijani xavfsiz saqlang.' as status
from updated cross join new_password p
union all
select null, null,
       'Admin hisobi topilmadi yoki bittadan ortiq. Hech qanday parol o‘zgartirilmadi.'
where not exists (select 1 from updated);
