import {supabase} from './supabase';
import {ui} from '../i18n/index';
export async function uploadSiteFile(bucket,path,file){
 const pdf=bucket==='project-documents';
 if(!file||file.size===0||file.size>(pdf?10485760:5242880))throw new Error(ui(pdf?'PDF hajmi 10 MB dan oshmasin.':'Rasm hajmi 5 MB dan oshmasin.'));
 const bytes=new Uint8Array(await file.slice(0,8).arrayBuffer());
 const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255,png=bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71;
 if(pdf?String.fromCharCode(...bytes.slice(0,5))!=='%PDF-':!jpeg&&!png)throw new Error(ui(pdf?'Faqat PDF fayl tanlang.':'Faqat JPEG yoki PNG rasm tanlang.'));
 const {error}=await supabase.storage.from(bucket).upload(path,file,{contentType:pdf?'application/pdf':jpeg?'image/jpeg':'image/png',upsert:false});if(error)throw new Error(ui('Fayl yuklanmadi. Internet va Storage sozlamalarini tekshiring.'));
 return path;
}
export async function openSiteFile(bucket,path,filename){
 const {data,error}=await supabase.storage.from(bucket).download(path);if(error)throw new Error(ui('Faylni yuklab bo‘lmadi.'));
 const url=URL.createObjectURL(data);const a=document.createElement('a');a.href=url;a.download=filename||'Zulfon-hujjat.pdf';a.click();setTimeout(()=>URL.revokeObjectURL(url),60000);
}
