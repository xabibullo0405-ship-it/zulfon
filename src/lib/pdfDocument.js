import {ui} from '../i18n/index.js';
import {PDFDocument,rgb} from 'pdf-lib';
import fontkit from '@pdf-lib/fontkit';
export async function buildReportsPdf({reports,getPerson,getProject,fontBytes,boldFontBytes,loadPhoto}){
 if(!reports.length)throw new Error(ui('Yuklab olish uchun hisobot tanlang.'));
 const doc=await PDFDocument.create();doc.registerFontkit(fontkit);
 const font=await doc.embedFont(fontBytes,{subset:true}),bold=await doc.embedFont(boldFontBytes,{subset:true});
 doc.setTitle(ui('Zulfon — hisobotlar'));doc.setCreator('Zulfon');
 const width=595,height=842,margin=44,maxWidth=width-2*margin;
 let page,y;
 const newPage=()=>{page=doc.addPage([width,height]);y=height-margin;page.drawText('ZULFON',{x:margin,y,size:15,font:bold,color:rgb(.13,.25,.2)});y-=34};
 const text=(value,size=11,strong=false)=>{
  const chosen=strong?bold:font;
  for(const paragraph of String(value??'').replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g,'').split('\n')){
   let line='';
   const flush=()=>{if(y<margin+size*1.5)newPage();page.drawText(line||' ',{x:margin,y,size,font:chosen,color:rgb(.18,.24,.2)});y-=size*1.55;line=''};
   for(const word of paragraph.split(/\s+/)){
    if(chosen.widthOfTextAtSize(line+(line?' ':'')+word,size)<=maxWidth){line+=(line?' ':'')+word;continue}
    if(line)flush();
    // Also wrap long unbroken strings and URLs.
    for(const char of word){if(chosen.widthOfTextAtSize(line+char,size)>maxWidth)flush();line+=char}
   }
   flush();
  }
 };
 for(const report of reports){
  newPage();text(report.title,17,true);y-=10;
  const person=getPerson(report.person);
  text(ui('Xodim:')+' '+(person?.name||ui('O‘chirilgan xodim')));text(ui('Lavozim:')+' '+ui(person?.role||'—'));
  text(ui('Obyekt:')+' '+getProject(report.project));text(ui('Sana:')+' '+report.date+' · '+(report.time||'')+' · '+(report.type==='morning'?ui('Ertalabki'):ui('Yakuniy')));
  text(ui('Holat:')+' '+({review:ui('Tekshirish kutilmoqda'),accepted:ui('Tasdiqlangan'),rejected:ui('Bekor qilingan')}[report.status]||report.status));
  if(report.rejectionReason)text(ui('Bekor qilish sababi:')+' '+report.rejectionReason);
  y-=15;text(ui('Bajarilgan ishlar'),12,true);y-=5;text(report.text);y-=15;
  for(let i=0;i<(report.photos||[]).length;i++){
   const bytes=await loadPhoto(report.photos[i]);
   const png=bytes[0]===137&&bytes[1]===80;
   const image=png?await doc.embedPng(bytes):await doc.embedJpg(bytes);
   const ratio=Math.min(maxWidth/image.width,310/image.height,1),w=image.width*ratio,h=image.height*ratio;
   if(y-h-30<margin)newPage();text(ui('Rasm')+' '+(i+1),10,true);page.drawImage(image,{x:margin,y:y-h,width:w,height:h});y-=h+24;
  }
 }
 doc.getPages().forEach((p,i)=>p.drawText(`${i+1} / ${doc.getPageCount()}`,{x:width-margin-50,y:24,size:9,font,color:rgb(.5,.55,.48)}));
 return doc.save();
}
