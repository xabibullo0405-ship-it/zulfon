// Read every page rather than silently dropping older rows at the API row limit.
export async function pagedRows(readPage,pageSize=500,key='id'){
 const rows=new Map();
 for(let from=0;;from+=pageSize){
  const result=await readPage(from,from+pageSize-1);
  if(result.error)return result;
  for(const row of result.data||[])rows.set(row[key],row);
  if((result.data||[]).length<pageSize)return {data:[...rows.values()],error:null};
 }
}
