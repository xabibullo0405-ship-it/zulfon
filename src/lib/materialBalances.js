// Quantities are stored at 0.001 precision. Work in thousandths to avoid float drift.
export function brigadeBalances(movements){
 const result=new Map();
 for(const m of movements){
  if(!m.brigadier_id||!['issue','return','usage'].includes(m.kind))continue;
  const key=m.brigadier_id+':'+m.item_id;
  const row=result.get(key)||{brigadierId:m.brigadier_id,itemId:m.item_id,quantity:0};
  row.quantity+=(m.kind==='issue'?1:-1)*Math.round(Number(m.quantity)*1000);result.set(key,row);
 }
 return [...result.values()].filter(r=>r.quantity>0).map(r=>({...r,quantity:r.quantity/1000}));
}
