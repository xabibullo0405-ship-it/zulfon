import React from 'react';
import {Building2,CalendarDays,LogOut,RefreshCw,Home,Camera} from 'lucide-react';
import {BrandLogo} from './BrandLogo';
import {ReportPhotoGallery} from './ReportPhotos';
import {ui,getLocale} from './i18n';
export function CustomerCabinet({dashboard,refresh,signOut,loading,error}){
 const p=dashboard.project;
 const money=v=>new Intl.NumberFormat(getLocale(),{maximumFractionDigits:2}).format(Number(v))+ui(' so‘m');
 return <div className="employee-shell customer-shell"><header className="employee-topbar"><BrandLogo className="staff-brand"/><span>{ui('Mijoz kabineti')}</span><button className="btn" onClick={signOut}><LogOut size={15}/>{ui('Chiqish')}</button></header><main className="employee-main">
 <div className="page-heading"><div><div className="eyebrow">{ui('MENING XONADONIM')}</div><h1>{dashboard.name}</h1><p>{ui('Xonadoningiz va qurilish jarayoni bir joyda.')}</p></div><button className="btn" onClick={refresh} disabled={loading}><RefreshCw size={16}/>{ui('Yangilash')}</button></div>
 {error&&<p className="form-error" role="alert">{ui(error)}</p>}
 <section className="customer-home panel"><div className="customer-home-icon"><Home size={32}/></div><div><span className="eyebrow">{ui('SOTIB OLINGAN XONADON')}</span><h2>{dashboard.unit}</h2><p><Building2 size={16}/>{p.name}</p><p className="muted">{p.address}</p></div><span className="badge success">{ui('Xarid sanasi')}: {dashboard.sold_on}</span></section>
 <div className="customer-details"><section className="panel customer-progress"><h2>{ui('Qurilish holati')}</h2><div className="customer-percent">{p.progress}<small>%</small></div><div className="customer-progress-track" role="progressbar" aria-label={ui('Qurilish holati')} aria-valuenow={p.progress} aria-valuemin={0} aria-valuemax={100}><span style={{width:p.progress+'%'}}/></div><p className="muted">{ui('Obyektning umumiy bajarilish darajasi')}</p><div className="customer-facts"><span>{ui('Bloklar soni')}<strong>{p.blocks??'—'}</strong></span><span>{ui('Qavatlar soni')}<strong>{p.floors??'—'}</strong></span><span><CalendarDays size={15}/>{ui('Tugash sanasi')}<strong>{p.planned_finish||'—'}</strong></span></div></section>
 <section className="panel customer-payments"><h2>{ui('Xonadon ma’lumotlari')}</h2><dl><div><dt>{ui('Sotuv narxi (so‘m)')}</dt><dd>{money(dashboard.price)}</dd></div><div><dt>{ui('Tushgan to‘lov')}</dt><dd>{money(dashboard.paid)}</dd></div><div><dt>{ui('Qoldiq')}</dt><dd>{money(Number(dashboard.price)-Number(dashboard.paid))}</dd></div></dl></section></div>
 <section className="customer-updates"><div className="panel-title"><h2><Camera size={21}/>{ui('Haftalik qurilish rasmlari')}</h2></div><p className="muted">{ui('Har dushanba prorabning o‘sha kungi birinchi rasmli hisobotidan suratlar avtomatik keladi.')}</p>
 {dashboard.updates.length?dashboard.updates.map(w=><article className="panel customer-update" key={w.id}><span className="badge neutral"><CalendarDays size={14}/>{w.date}</span><ReportPhotoGallery paths={w.photos} title="Qurilish rasmlari"/></article>):<div className="panel empty"><Camera size={32}/><h3>{ui('Haftalik rasmlar hali kelmagan')}</h3><p>{ui('Dushanba kuni prorab rasmli hisobot yuborgach, suratlar shu yerda ko‘rinadi.')}</p></div>}</section>
 </main></div>;
}
