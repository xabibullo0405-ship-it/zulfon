import React from 'react';
import {useCloud,CloudScope} from './CloudProvider';
import {staffRole} from './lib/staffRoles';
import {supabase} from './lib/supabase';
import {getLocale} from './i18n';
export function AdminScope({target,children,onExit}){
 const full=useCloud(),director=target.app_role==='director',role=staffRole(target),site=target.project_id;
 const reports=full.reports.filter(r=>director||r.person===target.id),tasks=full.tasks.filter(t=>director||t.person===target.id);
 const queryRpc=(name,args={})=>supabase.rpc('admin_act',{p_target:target.id,p_action:name,p_args:args});
 const rpc=async(name,args)=>{const {data,error}=await queryRpc(name,args);if(error)throw Object.assign(new Error(error.message),{code:error.code});await full.refresh();return data};
 const saveProfile=d=>rpc('complete_profile',{p_name:d.name,p_phone:d.phone||'',p_email:d.email,p_address:d.address||'',p_birth_date:d.birthDate||null});
 const value={...full,signOut:onExit,me:target,queryRpc,rpc,saveProfile,setProfile:saveProfile,
 profile:{name:target.name,email:target.contact_email,notify:true},
 projects:full.projects.filter(p=>director||target.access_area==='sales'||p.id===site||tasks.some(t=>t.projectId===p.id)||reports.some(r=>r.project===p.id)),
 members:full.members.filter(m=>director?m.app_role!=='admin':m.id===target.id||m.app_role==='director'),
 inventory:full.inventory.filter(i=>director||['warehouse','foreman'].includes(role)&&i.project_id===site),
 movements:full.movements.filter(m=>m.project_id===site&&(['warehouse','foreman'].includes(role)||role==='brigadier'&&m.brigadier_id===target.id)),
 workers:full.workers.filter(w=>w.project_id===site&&(role==='foreman'||role==='brigadier'&&w.brigadier_id===target.id)),
 documents:full.documents.filter(d=>director||d.project_id===site),
 allocationLabels:role==='brigadier'?full.inventory.filter(i=>full.movements.some(m=>m.item_id===i.id&&m.brigadier_id===target.id&&m.project_id===site)).map(i=>({id:i.id,name:i.name,unit:i.unit})):[],
 payroll:role==='accountant'?full.payroll:[],receiptCosts:role==='accountant'?full.receiptCosts:[],
 sales:director||target.access_area==='sales'?full.sales:[],reports,tasks,
 messages:full.rawMessages.filter(m=>m.sender_id===target.id||m.recipient_id===target.id).map(m=>({id:m.id,conversation:m.sender_id===target.id?m.recipient_id:m.sender_id,text:m.body,time:new Date(m.created_at).toLocaleTimeString(getLocale(),{timeZone:'Asia/Tashkent',hour:'2-digit',minute:'2-digit'}),createdAt:m.created_at,incoming:m.sender_id!==target.id})),
 setTasks:async fn=>{const next=typeof fn==='function'?fn(tasks):fn;for(const t of next){const old=tasks.find(o=>o.id===t.id);if(!old)await rpc('create_task',{p_title:t.title,p_description:t.description,p_assignee:t.person,p_due:t.due,p_priority:t.priority});else if(old.progress!==t.progress)await rpc('update_task_progress',{p_id:t.id,p_progress:t.progress})}},
 setReports:async fn=>{for(const r of fn(reports)){const old=reports.find(o=>o.id===r.id);if(old&&old.status!==r.status)await rpc('review_report',{p_id:r.id})}},
 setMessages:async fn=>{const old=full.rawMessages;for(const m of fn(value.messages))if(!old.some(o=>o.id===m.id))await rpc('send_message',{p_recipient:m.conversation,p_body:m.text})}
 };
 return <CloudScope value={value}>{children}</CloudScope>;
}
