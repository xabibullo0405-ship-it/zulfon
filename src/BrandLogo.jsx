import React from 'react';
const logo='/brand/zulfon-logo.png';
// The compact lockup uses the same emblem and wordmark as the full supplied design.
export function BrandLogo({variant='compact',className=''}){
 if(variant==='full')return <img className={`brand-logo brand-logo--full ${className}`} src={logo} width="1536" height="1024" alt="Zulfon — Qurilish jarayonlari - bir tizimda" decoding="async"/>;
 return <svg className={`brand-logo brand-logo--compact ${className}`} viewBox="0 0 370 90" role="img" aria-label="Zulfon"><rect width="370" height="90" rx="9" fill="#fff"/><svg x="5" y="5" width="82" height="80" viewBox="420 50 700 580" preserveAspectRatio="xMidYMid meet"><image href={logo} width="1536" height="1024"/></svg><svg x="95" y="20" width="270" height="51" viewBox="65 630 1405 265" preserveAspectRatio="xMidYMid meet"><image href={logo} width="1536" height="1024"/></svg></svg>;
}
