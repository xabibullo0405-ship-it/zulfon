import {buildReportsPdf} from './pdfDocument.js';
import {supabase} from './supabase';
export async function downloadReportsPdf(reports,getPerson,getProject){
 const getFont=async(url)=>{const response=await fetch(url);if(!response.ok)throw new Error('PDF shrifti yuklanmadi.');return new Uint8Array(await response.arrayBuffer())};
 const [fontBytes,boldFontBytes]=await Promise.all([getFont(new URL('../assets/DejaVuSans.ttf',import.meta.url)),getFont(new URL('../assets/DejaVuSans-Bold.ttf',import.meta.url))]);
 const bytes=await buildReportsPdf({reports,getPerson,getProject,fontBytes,boldFontBytes,loadPhoto:async path=>{const {data,error}=await supabase.storage.from('report-photos').download(path);if(error)throw new Error('Hisobot rasmi yuklanmadi. PDF tayyorlanmadi; qayta urinib ko‘ring.');return new Uint8Array(await data.arrayBuffer())}});
 const url=URL.createObjectURL(new Blob([bytes],{type:'application/pdf'}));const a=document.createElement('a');a.href=url;a.download=reports.length===1?'Zulfon-hisobot.pdf':'Zulfon-hisobotlar.pdf';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
