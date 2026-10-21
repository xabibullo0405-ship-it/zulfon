import {ui} from './i18n/index.js';
import React,{useEffect,useRef,useState} from 'react';
import {Camera,X,RotateCcw,RefreshCw,ImageIcon} from 'lucide-react';
import {supabase} from './lib/supabase';
export const MAX_PHOTOS=5;
const BUCKET='report-photos';
export function CameraCapture({onCapture,onClose}){
 const video=useRef(null),stream=useRef(null),[facing,setFacing]=useState('environment'),[error,setError]=useState(''),[ready,setReady]=useState(false),[busy,setBusy]=useState(false);
 useEffect(()=>{
  let cancelled=false;setReady(false);setError('');
  const stop=()=>{stream.current?.getTracks().forEach(t=>t.stop());stream.current=null};
  const start=async()=>{
   if(!window.isSecureContext||!navigator.mediaDevices?.getUserMedia){setError('Kamera uchun saytni HTTPS orqali oching va kamera qo‘llab-quvvatlanadigan brauzerdan foydalaning.');return}
   try{const media=await navigator.mediaDevices.getUserMedia({audio:false,video:{facingMode:{ideal:facing},width:{ideal:1920},height:{ideal:1080}}});if(cancelled){media.getTracks().forEach(t=>t.stop());return}stream.current=media;video.current.srcObject=media;await video.current.play()}
   catch(e){if(!cancelled)setError(e.name==='NotAllowedError'?'Kameraga ruxsat berilmadi. Brauzer sozlamalarida kamera ruxsatini yoqing.':e.name==='NotFoundError'?'Kamera topilmadi. Kamerali qurilmadan foydalaning.':'Kamerani ochib bo‘lmadi. Boshqa dastur ishlatayotgan bo‘lsa, uni yoping va qayta urinib ko‘ring.')}
  };start();
  const onHide=()=>{stop();onClose()},onKey=e=>{if(e.key==='Escape')onHide()},onVisibility=()=>{if(document.hidden)onHide()};window.addEventListener('pagehide',onHide);document.addEventListener('keydown',onKey);document.addEventListener('visibilitychange',onVisibility);
  return()=>{cancelled=true;stop();window.removeEventListener('pagehide',onHide);document.removeEventListener('keydown',onKey);document.removeEventListener('visibilitychange',onVisibility)};
 },[facing]);
 const takePhoto=async()=>{
  if(!video.current?.videoWidth||busy)return;setBusy(true);
  try{const canvas=document.createElement('canvas'),v=video.current,scale=Math.min(1,1920/Math.max(v.videoWidth,v.videoHeight));canvas.width=Math.round(v.videoWidth*scale);canvas.height=Math.round(v.videoHeight*scale);canvas.getContext('2d').drawImage(v,0,0,canvas.width,canvas.height);
   const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',.85));
   if(!blob||blob.size>5*1024*1024)throw new Error('Rasmni tayyorlab bo‘lmadi. Qayta rasmga oling.');
   onCapture({id:crypto.randomUUID(),blob});
  }catch(e){setError(e.message);setBusy(false)}
 };
 return <div className="modal-backdrop camera-backdrop"><section className="camera-dialog" role="dialog" aria-modal="true" aria-label={ui("Kamera")}><header><h2><Camera size={20}/>{ui("Hisobot uchun rasm")}</h2><button className="icon-btn" aria-label={ui("Kamerani yopish")} onClick={onClose}><X size={22}/></button></header><div className="camera-view"><video ref={video} autoPlay muted playsInline onLoadedData={()=>setReady(true)}/>{ui(!ready&&!error&&<p>{ui("Kamera ochilmoqda...")}</p>)}{ui(error&&<p role="alert">{ui(error)}</p>)}</div><footer><button type="button" className="btn" disabled={busy} onClick={()=>setFacing(f=>f==='environment'?'user':'environment')}><RefreshCw size={17}/>{ui("Kamerani almashtirish")}</button><button type="button" className="btn primary" disabled={!ready||!!error||busy} onClick={takePhoto}><Camera size={18}/>{ui(busy?'Tayyorlanmoqda...':'Rasmga olish')}</button></footer><p className="camera-hint">{ui("Faqat kamera orqali olingan rasm qo‘shiladi.")}</p></section></div>;
}
function LocalPreview({photo,onRemove,disabled}){
 const [url,setUrl]=useState('');useEffect(()=>{const value=URL.createObjectURL(photo.blob);setUrl(value);return()=>URL.revokeObjectURL(value)},[photo.blob]);
 return <div className="photo-preview"><img src={url} alt={ui("Kamera orqali olingan rasm")}/><button type="button" className="icon-btn" aria-label={ui("Rasmni olib tashlash")} disabled={disabled} onClick={onRemove}><X size={16}/></button></div>;
}
export function PhotoPicker({photos,onChange,disabled}){
 const [cameraOpen,setCameraOpen]=useState(false);
 return <section className="photo-picker"><div className="photo-picker-heading"><div><h3>{ui("Hisobot rasmlari ")}<span className="number-chip">{ui(photos.length)}/{ui(MAX_PHOTOS)}</span></h3><p>{ui("Kamerada suratga oling. Har bir hisobotga ")}{ui(MAX_PHOTOS)}{ui(" tagacha rasm.")}</p></div><button type="button" className="btn" disabled={disabled||photos.length>=MAX_PHOTOS} onClick={()=>setCameraOpen(true)}><Camera size={17}/>{ui("Kamerani ochish")}</button></div>{ui(photos.length>0&&<div className="photo-grid">{ui(photos.map(p=><LocalPreview key={p.id} photo={p} disabled={disabled} onRemove={()=>onChange(photos.filter(item=>item.id!==p.id))}/>))}</div>)}{ui(cameraOpen&&<CameraCapture onClose={()=>setCameraOpen(false)} onCapture={photo=>{onChange([...photos,photo]);setCameraOpen(false)}}/>)}</section>;
}
export function ReportPhotoGallery({paths=[]}){
 const [urls,setUrls]=useState([]),[error,setError]=useState(''),[retry,setRetry]=useState(0);
 const key=paths.join('|');
 useEffect(()=>{let active=true;setUrls([]);setError('');if(!paths.length)return;
  (async()=>{try{const {data,error}=await supabase.storage.from(BUCKET).createSignedUrls(paths,600);if(!active)return;if(error||!data||data.some(item=>item.error||!item.signedUrl)){setError('Rasmlarni yuklab bo‘lmadi. Ruxsat va Storage sozlamalarini tekshiring.');return}setUrls(data.map(item=>item.signedUrl))}catch{if(active)setError('Rasmlarni yuklab bo‘lmadi. Qayta urinib ko‘ring.')}})();
  const timer=setInterval(()=>setRetry(n=>n+1),540000);return()=>{active=false;clearInterval(timer)};
 },[key,retry]);
 if(!paths.length)return null;
 return <section className="report-photo-gallery"><h3><ImageIcon size={17}/>{ui("Hisobot rasmlari ")}<span className="number-chip">{ui(paths.length)}</span></h3>{ui(error?<div className="photo-load-error"><p role="alert">{ui(error)}</p><button className="btn" onClick={()=>setRetry(n=>n+1)}><RotateCcw size={14}/>{ui("Qayta yuklash")}</button></div>:urls.length?<div className="photo-grid">{ui(urls.map((url,i)=><a key={paths[i]} href={url} target="_blank" rel="noreferrer" aria-label={ui(`${i+1} — ${ui('rasmni katta ko‘rish')}`)}><img src={url} alt={ui(`${ui('Hisobot rasmlari')} ${i+1}`)} loading="lazy" onError={()=>setError('Rasm havolasi eskirgan yoki rasmni yuklab bo‘lmadi. Qayta yuklang.')}/></a>))}</div>:<p className="muted">{ui("Rasmlar yuklanmoqda...")}</p>)}</section>;
}
export async function submitReportWithPhotos({userId,submissionId,photos,fields,onProgress}){
 if(photos.length>MAX_PHOTOS)throw new Error('Bitta hisobotga 5 tagacha rasm qo‘shish mumkin.');
 // An ambiguous response after commit must not create a duplicate on retry.
 const existing=await supabase.from('reports').select('id').eq('id',submissionId).maybeSingle();
 if(existing.error)throw new Error(existing.error.message);
 if(existing.data)return submissionId;
 const uploaded=[];
 try{
  for(let i=0;i<photos.length;i++){
   const photo=photos[i];if(photo.blob.type!=='image/jpeg'||photo.blob.size>5*1024*1024)throw new Error('Faqat kamerada olingan, 5 MB gacha JPEG rasm qo‘shiladi.');
   const path=`${userId}/${submissionId}/${photo.id}.jpg`;
   onProgress?.(`${i+1}/${photos.length} ${ui('rasm yuklanmoqda...')}`);
   uploaded.push(path);
   const {error}=await supabase.storage.from(BUCKET).upload(path,photo.blob,{contentType:'image/jpeg',upsert:false});
   if(error&&String(error.statusCode)!=='409')throw new Error('Rasm yuklanmadi. Storage sozlamalari va internetni tekshiring. Hisobot saqlanmagan bo‘lsa, qayta urinishingiz mumkin.');
  }
  onProgress?.('Hisobot saqlanmoqda...');
  const {data,error}=await supabase.rpc('submit_report_with_photos',{p_id:submissionId,...fields,p_paths:uploaded});
  if(error)throw new Error(error.message);
  return data;
 }catch(error){
  // Deletion policy protects photos if the report committed but its response was lost.
  if(uploaded.length)await supabase.storage.from(BUCKET).remove(uploaded).catch(()=>{});
  throw error;
 }
}
