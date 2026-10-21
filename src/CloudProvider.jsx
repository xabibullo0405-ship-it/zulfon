import {ui,getLocale} from './i18n/index.js';
import React,{createContext,useContext,useEffect,useState,useCallback,useRef} from 'react';
import {Building2,KeyRound,LogOut,RefreshCw,ArrowRight} from 'lucide-react';
import {supabase,loginEmail} from './lib/supabase';
const Context=createContext(null);
export const useCloud=()=>useContext(Context);
export const todayCloud=()=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Tashkent',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());
const initials=name=>name.trim().split(/\s+/).filter(Boolean).slice(0,2).map(n=>n[0]).join('').toUpperCase();
const time=value=>new Date(value).toLocaleTimeString(getLocale(),{timeZone:'Asia/Tashkent',hour:'2-digit',minute:'2-digit'});
function CloudLogin(){
 const [busy,setBusy]=useState(false),[error,setError]=useState('');
 return <div className="access-screen"><div className="access-brand"><Building2 size={28}/>ZULFON</div><section className="panel access-card"><span className="modal-symbol"><KeyRound size={25}/></span><span className="eyebrow">{ui("DIREKTOR VA XODIMLAR UCHUN")}</span><h1>{ui("Kabinetga kirish")}</h1><p className="muted">{ui("O‘zingizga berilgan login va parol bilan kiring.")}</p><form onSubmit={async e=>{e.preventDefault();const f=new FormData(e.currentTarget);setBusy(true);setError('');try{const {error}=await supabase.auth.signInWithPassword({email:loginEmail(f.get('login')),password:f.get('password')});if(error)setError(error.status===400?'Login yoki parol noto‘g‘ri.':'Kirish amalga oshmadi. Supabase ulanishini tekshiring.')}catch{setError('Serverga ulanib bo‘lmadi. Internet ulanishini tekshiring.')}finally{setBusy(false)}}}><label>{ui("Login")}<input name="login" autoComplete="username" required autoFocus/></label><label>{ui("Parol")}<input name="password" type="password" autoComplete="current-password" required/></label>{ui(error&&<p className="form-error" role="alert">{ui(error)}</p>)}<button className="btn primary full" disabled={busy}>{ui(busy?'Tekshirilmoqda...':'Kabinetga kirish')}<ArrowRight size={16}/></button></form><p className="login-hint">{ui("Hisobingiz yo‘qmi? Kirish ma’lumotlarini direktoringizdan oling.")}</p></section></div>;
}
export function CloudProvider({children,employee}){
 const [session,setSession]=useState(undefined),[snapshot,setSnapshot]=useState(null),[error,setError]=useState(''),[loading,setLoading]=useState(false);
 const version=useRef(0);
 useEffect(()=>{let active=true;supabase.auth.getSession().then(({data,error})=>{if(active){if(error)setError('Sessiyani tekshirib bo‘lmadi.');setSession(data.session)}});const {data:{subscription}}=supabase.auth.onAuthStateChange((_event,next)=>{if(active){version.current++;setSnapshot(null);setSession(next)}});return()=>{active=false;subscription.unsubscribe()}},[]);
 const refresh=useCallback(async()=>{
  if(!session)return;const request=++version.current;setLoading(true);
  try{
   const results=await Promise.all(['members','reports','tasks','messages','projects','sales'].map(table=>supabase.from(table).select('*').order('created_at',{ascending:table==='messages'})));
   let schemaReady=true;for(let i=0;i<results.length;i++)if(results[i].error){if(i>=4&&['42P01','PGRST205'].includes(results[i].error.code)){schemaReady=false;results[i]={data:[]}}else throw results[i].error;}
   if(request!==version.current)return;
   const [members,reports,tasks,messages,projects,sales]=results.map(r=>r.data);
   const me=members.find(m=>m.id===session.user.id);if(!me)throw new Error('Hisobning bazadagi profili topilmadi. Administratorga murojaat qiling.');
   setSnapshot({members,reports,tasks,messages,projects,sales,me,schemaReady});setError('');
  }catch(e){if(request===version.current)setError(e.code==='42P01'||e.code==='PGRST205'?'Supabase jadvallari hali o‘rnatilmagan. SQL migratsiyasini bajaring.':e.message||'Ma’lumotlarni yuklab bo‘lmadi.')}
  finally{if(request===version.current)setLoading(false)}
 },[session]);
 useEffect(()=>{
  if(!session)return;refresh();
  const channel=supabase.channel('themelio-'+session.user.id).on('postgres_changes',{event:'*',schema:'public'},()=>refresh()).subscribe();
  const timer=setInterval(refresh,30000),onFocus=()=>refresh();window.addEventListener('focus',onFocus);
  return()=>{version.current++;clearInterval(timer);window.removeEventListener('focus',onFocus);supabase.removeChannel(channel)};
 },[session,refresh]);
 const signOut=async()=>{version.current++;setSnapshot(null);await supabase.auth.signOut();setSession(null)};
 const rpc=async(name,args)=>{const {data,error}=await supabase.rpc(name,args);if(error)throw Object.assign(new Error(error.message),{code:error.code});await refresh();return data};
 if(session===undefined)return <div className="access-screen"><p>{ui("Sessiya tekshirilmoqda...")}</p></div>;
 if(!session)return <CloudLogin/>;
 if(!snapshot)return <div className="access-screen"><section className="panel access-card"><h2>{ui(error?'Ulanishni yakunlash kerak':'Ma’lumotlar yuklanmoqda...')}</h2>{ui(error&&<><p className="form-error" role="alert">{ui(error)}</p><button className="btn" onClick={refresh} disabled={loading}><RefreshCw size={15}/>{ui("Qayta tekshirish")}</button><button className="btn" onClick={signOut}><LogOut size={15}/>{ui("Chiqish")}</button></>)}</section></div>;
 if(snapshot.me.employment_status&&snapshot.me.employment_status!=='employed')return <div className="access-screen"><section className="panel access-card"><h1>{ui("Hisob faol emas")}</h1><p className="muted">{ui(snapshot.me.employment_status==='deleted'?'Profilingiz o‘chirilgan.':'Ish faoliyatingiz to‘xtatilgan.')}{ui(" Qo‘shimcha ma’lumot uchun direktorga murojaat qiling.")}</p><button className="btn" onClick={signOut}>{ui("Chiqish")}</button></section></div>;
 const memberToPerson=m=>({id:m.id,accountId:m.id,name:m.name,role:m.position,initials:initials(m.name),phone:m.phone,email:m.contact_email,address:m.address,birthDate:m.birth_date,employment:m.employment_status||'employed',projectId:m.project_id,accessArea:m.access_area||'operations',color:'blue',online:false,report:snapshot.reports.some(r=>r.author_id===m.id&&r.report_date===todayCloud()),tasks:snapshot.tasks.filter(t=>t.assignee_id===m.id&&t.status!=='done').length});
 const allPeople=snapshot.members.filter(m=>m.app_role==='employee').map(memberToPerson);
 const people=allPeople.filter(m=>m.employment==='employed'&&snapshot.members.find(row=>row.id===m.id)?.status==='active');
 const reports=snapshot.reports.map(r=>({id:r.id,person:r.author_id,title:r.title,text:r.body,type:r.report_type,date:r.report_date,time:time(r.created_at),status:r.status,project:r.project_id||'',photos:r.photo_paths||[],rejectionReason:r.rejection_reason||''}));
 const tasks=snapshot.tasks.map(t=>({id:t.id,title:t.title,description:t.description,person:t.assignee_id,due:t.due_date,priority:t.priority,progress:t.progress,projectId:t.project_id||'',status:t.progress===100?'done':t.due_date<todayCloud()?'late':t.status}));
 const messages=snapshot.messages.map(m=>({id:m.id,conversation:m.sender_id===session.user.id?m.recipient_id:m.sender_id,text:m.body,time:time(m.created_at),incoming:m.sender_id!==session.user.id}));
 const accounts=snapshot.members.filter(m=>m.app_role==='employee'&&m.employment_status!=='deleted').map(m=>({id:m.id,login:m.login,role:m.position,status:m.status,employment:m.employment_status||'employed'}));
 const profile={name:snapshot.me.name,email:snapshot.me.contact_email,notify:true};
 const saveProfile=async(details)=>rpc('complete_profile',{p_name:details.name,p_phone:details.phone||'',p_email:details.email,p_address:details.address||'',p_birth_date:details.birthDate||null});
 const setTasks=async(fn)=>{const next=typeof fn==='function'?fn(tasks):fn;for(const t of next){const old=tasks.find(o=>o.id===t.id);if(!old)await rpc('create_task',{p_title:t.title,p_description:t.description,p_assignee:t.person,p_due:t.due,p_priority:t.priority});else if(old.progress!==t.progress)await rpc('update_task_progress',{p_id:t.id,p_progress:t.progress})}};
 const setReports=async(fn)=>{const next=fn(reports);for(const r of next){const old=reports.find(o=>o.id===r.id);if(old&&old.status!==r.status)await rpc('review_report',{p_id:r.id})}};
 const setMessages=async(fn)=>{const next=fn(messages);for(const m of next)if(!messages.some(old=>old.id===m.id))await rpc('send_message',{p_recipient:m.conversation,p_body:m.text})};
 const value={projects:snapshot.projects,sales:snapshot.sales,schemaReady:snapshot.schemaReady,allPeople,people,reports,tasks,messages,accounts,profile,me:snapshot.me,members:snapshot.members,refresh,rpc,signOut,setTasks,setReports,setMessages,setProfile:saveProfile,saveProfile,error,setError,loading};
 return <Context.Provider value={value}>{ui(error&&<div className="cloud-error" role="alert">{ui(error)}<button onClick={()=>setError('')}>×</button></div>)}{ui(snapshot.me.app_role==='director'?children:employee)}</Context.Provider>;
}
