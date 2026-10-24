import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const reply=(status:number,body:unknown)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const alphabet='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
const random=(length:number)=>Array.from(crypto.getRandomValues(new Uint8Array(length)),n=>alphabet[n%alphabet.length]).join('');
// Satisfy upper/lower/digit/symbol policies, not merely a probabilistic mix.
const newPassword=()=>{
 const chars=[...'Aa2!'+random(20)];
 for(let i=chars.length-1;i>0;i--){const j=crypto.getRandomValues(new Uint32Array(1))[0]%(i+1);[chars[i],chars[j]]=[chars[j],chars[i]]}
 return chars.join('');
};
const authFailure=(error:{code?:string;status?:number;message?:string},operation:string,sensitive:string[]=[])=>{
 const code=error.code&&/^[a-z0-9_]{1,80}$/.test(error.code)?error.code:'auth_error';
 const hints:Record<string,string>={
  weak_password:'Supabase parol talabi bajarilmadi. Auth parol sozlamalarini tekshiring.',
  validation_failed:'Supabase hisob ma’lumotini qabul qilmadi. Auth logidagi tafsilotni tekshiring.',
  email_address_invalid:'Supabase login uchun email manzilini rad etdi. Auth logini tekshiring.',
  email_exists:'Bu login bilan hisob mavjud. Boshqa login yarating.',
  user_already_exists:'Bu login bilan hisob mavjud. Boshqa login yarating.',
  unexpected_failure:'Auth bazaga yozishda xato qaytardi. Supabase Logs → Auth bo‘limida shu vaqtdagi xatoni tekshiring.',
  not_admin:'Server kalitida Auth administrator huquqi yo‘q. Edge Function sozlamalarini tekshiring.'
 };
 let detail=typeof error.message==='string'?error.message:'';
 for(const value of sensitive)if(value)detail=detail.replaceAll(value,'[redacted]');
 detail=detail.replace(/sb_secret_[A-Za-z0-9_-]+/g,'[redacted]').replace(/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,'[redacted]').replace(/[\x00-\x1F]/g,' ').slice(0,300);
 const upstream=detail?' Server: '+detail+(error.status?' (HTTP '+error.status+')':''):'';
 const requestId=crypto.randomUUID();
 // Log only operational metadata, never passwords, tokens, keys or the request body.
 console.error(JSON.stringify({event:'themelio_auth_failure',operation,code,status:error.status,request_id:requestId}));
 return reply(code==='unexpected_failure'?503:400,{error:(hints[code]||'Supabase hisob amalini bajara olmadi.')+upstream,error_code:code,request_id:requestId});
};
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return reply(405,{error:'POST required'});
 const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');
 if(!token)return reply(401,{error:'Kirish talab qilinadi.'});
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:{user},error:authError}=await admin.auth.getUser(token);
 if(authError||!user)return reply(401,{error:'Sessiya yaroqsiz. Qayta kiring.'});
 const {data:actor,error:actorError}=await admin.from('members').select('app_role,employment_status').eq('id',user.id).single();
 if(actorError||!['director','admin'].includes(actor?.app_role)||actor.employment_status&&actor.employment_status!=='employed')return reply(403,{error:'Hisob yaratish uchun direktor yoki admin huquqi kerak.'});
 let body;try{body=await req.json()}catch{return reply(400,{error:'Invalid JSON'})}
 if(!body||typeof body!=='object'||Array.isArray(body))return reply(400,{error:'Invalid JSON object'});
 if(body.action==='reset-password'){
  const {data:member}=await admin.from('members').select('id,login,position,status,app_role,employment_status').eq('id',body.id).single();
  if(!member||!(member.app_role==='employee'||actor.app_role==='admin'&&member.app_role==='director')||member.employment_status&&member.employment_status!=='employed')return reply(404,{error:'Xodim topilmadi.'});
  if(actor.app_role==='admin'){const {error}=await admin.from('admin_audit').insert({actor_id:user.id,target_id:member.id,action:'reset-password-request'});if(error)return reply(503,{error:'Admin tarixi yozilmadi. Qayta urinib ko‘ring.'})}
  const password=newPassword(),{error}=await admin.auth.admin.updateUserById(member.id,{password});
  if(error)return authFailure(error,'reset-password',[password,token,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'']);
  return reply(200,{account:{id:member.id,login:member.login,role:member.position,status:member.status},password});
 }
 if(body.action!=='create')return reply(400,{error:'Unknown operation'});
 const position=typeof body.position==='string'?body.position.trim():'';
 if(!position||position.length>80)return reply(400,{error:'Lavozim nomini kiriting (1–80 belgi).'});
 const {count,error:countError}=await admin.from('members').select('id',{count:'exact',head:true}).neq('employment_status','deleted').neq('app_role','admin');
 if(countError)return reply(503,{error:'Baza tayyor emas. SQL migratsiyasini tekshiring.'});
 if((count||0)>=10)return reply(409,{error:'10 ta hisob chegarasiga yetildi (1 direktor + 9 xodim).'});
 if(actor.app_role==='admin'){const {error}=await admin.from('admin_audit').insert({actor_id:user.id,target_id:null,action:'create-account-request'});if(error)return reply(503,{error:'Admin tarixi yozilmadi. Qayta urinib ko‘ring.'})}
 const login='tm-'+random(10).toLowerCase(),password=newPassword();
 const {data,error}=await admin.auth.admin.createUser({email:login+'@accounts.themelio.invalid',password,email_confirm:true,app_metadata:{themelio_role:'employee',position,login,access_area:position.toLowerCase()==='sotuvchi'?'sales':'operations'}});
 if(error)return authFailure(error,'create',[password,token,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')||'']);
 if(!data.user)return reply(503,{error:'Auth foydalanuvchi ma’lumotini qaytarmadi.',error_code:'missing_user'});
 return reply(200,{account:{id:data.user.id,login,role:position,status:'pending'},password});
});
