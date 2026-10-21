import React,{useSyncExternalStore,useEffect} from 'react';
import {subscribe,getLanguage,setLanguage} from './index.js';
export function LanguageRoot({render}){
 const language=useSyncExternalStore(subscribe,getLanguage,getLanguage);
 useEffect(()=>{document.documentElement.lang=language;document.title=language==='ru'?'Zulfon — Кабинет управления':'Zulfon — Boshqaruv kabineti'},[language]);
 return <><div className="language-switch" role="group" aria-label={language==='ru'?'Язык интерфейса':'Interfeys tili'}><button type="button" lang="uz" aria-pressed={language==='uz'} onClick={()=>setLanguage('uz')}>O‘z</button><button type="button" lang="ru" aria-pressed={language==='ru'} onClick={()=>setLanguage('ru')}>Рус</button></div>{render(language)}</>;
}
