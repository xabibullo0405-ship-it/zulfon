import {build} from 'esbuild';
import {mkdir,writeFile,unlink} from 'node:fs/promises';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const outfile=path.resolve('node_modules/.cache/customer-views-test.mjs');await mkdir(path.dirname(outfile),{recursive:true});
const source=`
import React from 'react';import {renderToStaticMarkup} from 'react-dom/server';import assert from 'node:assert/strict';
import {CustomerCabinet} from './src/CustomerCabinet.jsx';import {CustomersWorkspace} from './src/Customers.jsx';import {CloudScope} from './src/CloudProvider.jsx';import {setLanguage} from './src/i18n/index.js';
const data={name:'Sinov Xaridor',unit:'A-12',price:100000000,paid:25000000,sold_on:'2026-11-01',project:{name:'Sinov Obyekt',address:'Sinov manzil',progress:45,blocks:2,floors:9,planned_finish:'2027-12-01'},updates:[{id:'week',date:'2026-11-02',photos:['foreman/report/photo.jpg']}],body:'PRIVATE REPORT TEXT'};
const render=()=>renderToStaticMarkup(<CustomerCabinet dashboard={data} refresh={()=>{}} signOut={()=>{}} loading={false} error=""/>);
let html=render();for(const value of ['Sinov Xaridor','A-12','Sinov Obyekt','Sinov manzil','2027-12-01','2026-11-02','aria-valuenow="45"','Qurilish rasmlari'])assert(html.includes(value),value);for(const value of ['PRIVATE REPORT TEXT','Hisobot matni','Hisobot rasmlari','Mijoz kabinetini yaratish'])assert(!html.includes(value),value+' must stay absent');
setLanguage('ru');html=render();assert(html.includes('Кабинет клиента'));assert(html.includes('Фотографии строительства'));assert(html.includes('Sinov Xaridor'));assert(!html.includes('Haftalik qurilish rasmlari'));setLanguage('uz');
for(const role of ['director','employee']){const context={me:{id:'seller',app_role:role,access_area:role==='employee'?'sales':'operations',status:'active'},sales:[],projects:[]};html=renderToStaticMarkup(<CloudScope value={context}><CustomersWorkspace/></CloudScope>);assert.equal(html.includes('Mijoz kabinetini yaratish'),role==='employee','Only seller sees create control');}
data.updates=[];html=render();assert(html.includes('Haftalik rasmlar hali kelmagan'));
console.log('Customer views passed: apartment/progress/payments/weekly photo layout, Uzbek/Russian copy, no internal report text, seller-only creation control and empty state. Browser interaction was not exercised.');
`;
try{const result=await build({stdin:{contents:source,resolveDir:process.cwd(),loader:'jsx'},bundle:true,platform:'node',format:'esm',packages:'external',define:{'import.meta.env':'{}'},write:false});await writeFile(outfile,result.outputFiles[0].contents);await import(pathToFileURL(outfile).href)}finally{await unlink(outfile).catch(()=>{})}
