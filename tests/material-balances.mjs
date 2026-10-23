import {pagedRows} from '../src/lib/pagedRows.js';
import assert from 'node:assert/strict';
import {brigadeBalances} from '../src/lib/materialBalances.js';
const m=(brigadier_id,item_id,kind,quantity)=>({brigadier_id,item_id,kind,quantity});
const result=brigadeBalances([m(null,'a','receipt',100),m('one','a','issue','0.1'),m('one','a','issue','0.2'),m('one','a','return','0.3'),m('one','b','issue',30),m('one','b','return',10),m('two','b','issue',5)]);
assert.deepEqual(result,[{brigadierId:'one',itemId:'b',quantity:20},{brigadierId:'two',itemId:'b',quantity:5}]);
assert.deepEqual(brigadeBalances([]),[]);
console.log('Brigade balances verified: grouped materials/recipients, returns deducted, no zero holdings and decimal precision.');

const ledger=Array.from({length:1001},(_,i)=>({...m('one','x',i===1000?'issue':'return',i===1000?1001:1),id:String(i)}));
const full=await pagedRows(async(from,to)=>({data:ledger.slice(from,to+1)}));
assert.equal(full.data.length,1001);assert.equal(brigadeBalances(full.data)[0].quantity,1,'Older issues beyond the API default limit must be counted');
const failure={error:{message:'Access denied'}};assert.equal(await pagedRows(async()=>failure),failure);
