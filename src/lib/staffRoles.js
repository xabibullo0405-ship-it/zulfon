export function staffRole(member){
 if(member.app_role==='director')return 'director';
 const position=member.position?.trim().toLowerCase();
 if(['omborchi','кладовщик'].includes(position))return 'warehouse';
 if(['prorab','прораб'].includes(position))return 'foreman';
 if(['brigadir','brigadar','brigada boshlig‘i',"brigada boshlig'i",'бригадир'].includes(position))return 'brigadier';
 return 'employee';
}
