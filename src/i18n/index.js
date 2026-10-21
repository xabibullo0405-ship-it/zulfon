import ru from './ru.js';
export const LANGUAGE_KEY='zulfon-language';
let language='uz';
try{if(globalThis.localStorage?.getItem(LANGUAGE_KEY)==='ru')language='ru'}catch{}
export const getLanguage=()=>language;
export const getLocale=()=>language==='ru'?'ru-RU':'uz-UZ';
const listeners=new Set();
export const subscribe=listener=>{listeners.add(listener);return()=>listeners.delete(listener)};
export function setLanguage(next){
 if(!['uz','ru'].includes(next)||next===language)return;
 language=next;try{globalThis.localStorage?.setItem(LANGUAGE_KEY,next)}catch{}
 for(const listener of listeners)listener();
}
// Only application labels are passed here. Data from users is rendered verbatim.
export function ui(value){
 if(Array.isArray(value))return value.map(ui);
 if(language!=='ru'||typeof value!=='string')return value;
 const key=value.trim(),translated=ru[key];
 return translated?value.slice(0,value.indexOf(key))+translated+value.slice(value.indexOf(key)+key.length):value;
}

export const canonicalRole=value=>Object.keys(ru).find(key=>['Prorab','Brigada boshlig‘i','Omborchi','Hisobchi','Muhandis','Sotuvchi'].includes(key)&&ru[key]===value)||value;
