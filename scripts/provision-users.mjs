import {createClient} from '@supabase/supabase-js';
import {randomBytes} from 'node:crypto';
import {mkdir,writeFile,access} from 'node:fs/promises';
import {dirname,resolve} from 'node:path';
// Execute only on an administrator's machine. The secret is never sent to the frontend.
const url=(process.env.SUPABASE_URL||'https://pumkmcpekrbshcvfojim.supabase.co').replace(/\/rest\/v1\/?$/,'');
const secret=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!secret){console.error('SUPABASE_SERVICE_ROLE_KEY is required. Set it securely in your terminal; never add it to VITE_* or Git.');process.exit(1)}
const output=resolve(process.env.CREDENTIALS_FILE||'.private/themelio-credentials.json');
try{await access(output);console.error('Credentials file already exists. Choose another CREDENTIALS_FILE; existing passwords will not be overwritten.');process.exit(1)}catch(e){if(e.code!=='ENOENT')throw e}
const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});
const {data:existing,error}=await admin.from('members').select('id,login,app_role,position').neq('employment_status','deleted').neq('app_role','admin');
if(error){console.error('Cannot read members. Apply the SQL migration and check the server key.');process.exit(1)}
if(existing.length>10)throw new Error('Unexpected account count: more than 10');
const positions=['Prorab','Brigada boshlig‘i','Omborchi','Hisobchi','Muhandis','Prorab','Brigada boshlig‘i','Omborchi','Sotuvchi'];
const credentials=[];
await mkdir(dirname(output),{recursive:true,mode:0o700});
// Create the file before provisioning, then append each successful account immediately.
await writeFile(output,JSON.stringify({project:url,accounts:credentials},null,2),{mode:0o600,flag:'wx'});
const persist=()=>writeFile(output,JSON.stringify({project:url,accounts:credentials},null,2),{mode:0o600});
const create=async(login,appRole,position)=>{
 const password='Aa2!'+randomBytes(24).toString('base64url');
 const {data,error}=await admin.auth.admin.createUser({email:login+'@accounts.themelio.invalid',password,email_confirm:true,app_metadata:{themelio_role:appRole,login,position}});
 if(error||!data.user){await persist();throw new Error('Account creation failed; already-created credentials are retained. Check the Supabase Auth logs and seat limit.')}
 credentials.push({login,password,role:appRole,position});await persist();
 existing.push({id:data.user.id,login,app_role:appRole,position});
};
try{
 if(!existing.some(u=>u.app_role==='director'))await create('direktor','director','Direktor');
 for(let n=1;existing.length<10;n++){
  const login='xodim'+String(n).padStart(2,'0');
  if(existing.some(u=>u.login===login))continue;
  await create(login,'employee',positions[(n-1)%positions.length]);
 }
 console.log(`Ready: ${existing.length} accounts total; ${credentials.length} new passwords saved to ${output}.`);
 console.log('Existing accounts/passwords were preserved. Share each login only with its owner. Keep the file private.');
}catch(e){console.error(e.message);process.exitCode=1}
