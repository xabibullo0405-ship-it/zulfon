# Supabase’ni ishga tushirish

Loyiha: `pumkmcpekrbshcvfojim`.
Frontend uchun to‘g‘ri URL: `https://pumkmcpekrbshcvfojim.supabase.co` — `/rest/v1/` qo‘shimchasisiz.

## Foydalanuvchini o‘chirish va umumiy chat interfeysi

Oldingi migratsiyalar o‘rnatilgach **`supabase/migrations/202610260002_account_removal.sql`** faylini SQL Editor’da to‘liq bir marta bajaring. So‘ng `manage-members` Edge Function kodini repozitoriydagi eng yangi `supabase/functions/manage-members/index.ts` bilan almashtirib, Deploy updates bosing. Yangi Edge versiyasi admin o‘chirilgan direktor o‘rniga yangi direktor yaratishi uchun kerak.

- **Admin → Hisoblar → Foydalanuvchini o‘chirish:** tasdiqdan keyin profil shaxsiy ma’lumotlari tozalanadi, kirish huquqi yopiladi, hisob ro‘yxatdan chiqadi. Hisobot/topshiriq/chat/oylik/ombor tarixi va audit aloqalari saqlanadi. Bu Auth foydalanuvchisini jismoniy o‘chirish emas: eski login bilan autentifikatsiya bo‘lsa ham ilova ruxsatlari berilmaydi. Profil qayta tiklanmaydi. Operatsion 10 hisob limitida joy bo‘shaydi.
- Admin o‘zini o‘chira olmaydi. Direktorni ham o‘chirish mumkin; shundan keyin Admin → Lavozim yaratish → Hisob turi → Direktor orqali yangi direktor hisobi yaratiladi. Bir vaqtning o‘zida faqat bitta o‘chirilmagan direktor bo‘ladi. Oddiy direktor bunday hisob yarata olmaydi.
- **Parol:** Supabase eski parolning qayta o‘qiladigan nusxasini saqlamaydi. Admin mavjud parolni ko‘rmaydi. “Yangi parol olish” bosilganda alohida tasdiq chiqadi: hozirgi parol almashtiriladi va yangi parol bir marta ko‘rsatiladi/nusxalanadi. Sayt yangi parollarni ham alohida ochiq matnli bazada yoki brauzer xotirasida saqlamaydi.
- **Chat:** admin, direktor va xodimlar bir xil Telegramga o‘xshash interfeysdan foydalanadi. Adminning shaxsiy chati faqat admin qatnashgan suhbatlarni ko‘rsatadi; egasining global ko‘rish ruxsati boshqa odamlarning o‘zaro yozishmalarini adminga yuborilgandek ko‘rsatmaydi. Boshqa kabinet suhbatlarini kuzatish uchun oldingi “Kabinetni ochish” rejimi saqlanadi.
- O‘chirilgan/faol bo‘lmagan suhbatdosh bilan shaxsiy yozishmalar faqat tarix sifatida ochiladi; unga yangi xabar yuborish yopiq. Direktor profilini hali to‘ldirmagan bo‘lsa chatdan profil sozlamalariga o‘tish ko‘rsatiladi.

## Brigadir material sarfi (26-oktabr)

Oldingi yettita migratsiya, jumladan `202610240001_owner_admin.sql`, bajarilgan bo‘lsa, **`supabase/migrations/202610260001_material_usage.sql`** faylini SQL Editor’da yangi so‘rovga to‘liq qo‘yib, bir marta Run bosing. Eski fayllarni takrorlamang. Edge Function yoki login-parollarni o‘zgartirish kerak emas.

Brigadir → Ombor → “Qo‘limdagi materiallar” → material yonidagi **Ishlatildi**. Ishlatilgan miqdor va qayerda ishlatilgani kiritiladi, so‘ng “Sarfni tasdiqlash” bosiladi. Qoldiqdan ortiq sarf kiritilmaydi. To‘liq ishlatilgan material joriy qoldiq ro‘yxatidan chiqadi, lekin berish/qaytarish/sarf tarixi saqlanadi. Material turi katalogdan o‘chmaydi.

Sarf faqat brigadirning shu obyekt bo‘yicha o‘ziga berilgan materialidan ayriladi. Ombordagi qoldiq o‘zgarmaydi, chunki bu material oldin brigadirga berilganda ombordan chiqqan. Omborchi va prorab sarfni “Materiallar harakati”da, qoldiqni “Brigadirlardagi materiallar”da ko‘radi; direktorning oldingi faqat ombor qoldig‘i ruxsati saqlanadi. Admin brigadir kabinetini ochib shu amalni bajara oladi va bu admin tarixiga yoziladi.

SQL miqdor/obyekt/egalikni tekshiradi. Bitta sarf bir nechta avvalgi berishlardan FIFO tartibida olinishi mumkin; har bir qism tegishli berish yozuviga bog‘lanadi. Qaytarish va sarf bir xil material qatori qulfi ostida hisoblanadi: sarflangan materialni yana omborga qaytarish mumkin emas. Bir xil operatsiya identifikatori bilan takroriy so‘rov sarfni ikki marta ayirmaydi. Sarf yozuvlari mijoz tomonidan o‘chirilmaydi.

## Loyiha egasi uchun alohida Admin (24-oktabr)

Admin — direktordan alohida, eng yuqori huquqli hisob. Bitta egasi Admin bo‘ladi; u 1 direktor + 9 xodim limitidan tashqari hisoblanadi (jami 11 gacha). Oddiy lavozim nomiga “Admin” yozish bu huquqni bermaydi. Direktor admin yaratmaydi yoki admin parolini yangilay olmaydi.

O‘rnatish tartibi:

1. Oldingi oltita migratsiya bajarilganidan keyin SQL Editor’da **`supabase/migrations/202610240001_owner_admin.sql`** faylini to‘liq bir marta bajaring. Mavjud direktor, xodimlar va ma’lumotlar saqlanadi.
2. Edge Functions → `manage-members` → Code’da `index.ts`ni repozitoriydagi **`supabase/functions/manage-members/index.ts`** bilan almashtiring va **Deploy updates** bosing. Shundan keyin Admin direktor va xodim parolini qayta bera oladi. Admin hisobi oddiy lavozim yaratish orqali yaratilmaydi.
3. SQL Editor → New query’da **`scripts/create-admin.sql`** faylini to‘liq bajaring. **Results → login = admin, new_password** ustunlari chiqadi. Yangi parolni faqat egasi xavfsiz saqlaydi; chatga yoki Git’ga yubormang.
4. Vercel yangi kodni deploy qilgach odatdagi saytda shu login-parol bilan kiring. Admin kabineti avtomatik ochiladi. Direktor hisobini uning egasiga, har bir xodim hisobini tegishli odamga topshiring. Oldingi login-parollar o‘zgarishsiz qoladi.

`create-admin.sql`ni qayta bajarish mavjud admin parolini o‘zgartirmaydi. Parol yo‘qolsa, Supabase loyihasi egasi **`scripts/reset-admin.sql`**ni SQL Editor’da bajarib yangi parol oladi. Ushbu SQL fayllar vaqtinchalik helper va pgcrypto orqali ishonchli administrator muhitida ishlaydi; ommaviy parol o‘rnatish RPCsi yaratilmaydi.

Admin kabinetida:

- **Hisoblar:** direktor va barcha xodimlarni ko‘rish, lavozim/obyektni almashtirish, kirishni to‘xtatish/qaytarish, login uchun yangi parol olish va xodim yaratish. Adminning o‘zini boshqa kabinetlar o‘chira yoki o‘zgartira olmaydi. Yangi hisob o‘chirish migratsiyasidan keyin direktor profilini ham o‘chirib, boshqa direktor yaratish mumkin; o‘chirish o‘rniga mavjud kabinetida shaxsiy ma’lumot va parolni yangilash ham mumkin.
- **Kabinetni ochish:** direktor, omborchi, prorab, brigadir, hisobchi yoki sotuvchining aynan shu kabinetidagi barcha funksiyalar bilan ishlash. Login-parolini bilish shart emas. Yuqorida “Admin boshqaruvi” belgisi turadi. “Admin kabinetiga qaytish” yoki preview ichidagi Chiqish sizni Admin’ga qaytaradi; Admin bosh sahifasidagi Chiqish haqiqiy sessiyani tugatadi.
- **Obyektlar va Umumiy nazorat:** barcha obyektlar/hujjatlar, hisobotlar va umumiy yozuvlar. Ombor, quruvchi, sotuv va moliyaviy o‘zgartirishlar uchun tegishli lavozim kabinetini oching. Shu sabab real ishni sinashdan oldin kerakli lavozimlar yaratilgan va obyektga biriktirilgan bo‘lishi kerak.
- **Admin tarixi:** oxirgi 200 ta ochilgan kabinet va bajarilgan amal. Muvaffaqiyatli ilova amallari bazadagi o‘zgarish bilan bir tranzaksiyada yoziladi. Parol almashtirish/hisob yaratish server urinishlari Auth amalidan avval yoziladi; parol yoki pasport matni jurnalga kiritilmaydi.

Texnik ruxsatlar: haqiqiy JWT hamisha Adminniki qoladi, boshqa odamning sessiyasi/paroli olinmaydi. `admin_act` faqat Admin uchun va aniq RPC imzolari ro‘yxati bilan ishlaydi; maqsad hisob transaction-local kontekstda beriladi. Alohida tablar bir-birining tanlangan kabinetini almashtirmaydi. Oddiy foydalanuvchi bu kontekstni soxtalashtirsa ham o‘z huquqidan chiqmaydi. Admin haqiqiy egasi sifatida barcha loyiha ma’lumotlarini, jumladan moliyaviy yozuvlar, hisobot rasmlari, xodimlar o‘rtasidagi chatlar va quruvchilarning pasport hujjatlarini ko‘ra oladi; foydalanuvchilarni bu boshqaruv tartibidan xabardor qiling. Direktor/xodimlarning avvalgi rol cheklovlari saqlanadi.

Git push SQL, Edge deploy yoki admin hisobini avtomatik yaratmaydi. Mahalliy testlarda SQL ruxsatlari/crypto stublari va mock Auth tekshiriladi; haqiqiy Supabase loginini yuqoridagi amallardan keyin sinang.

## Brigadir bo‘yicha saralash va qayta kirim (23-oktabr)

Bu yangilanish uchun yangi SQL yoki Edge Function deployi kerak emas; oldingi migratsiyalar o‘rnatilgan bo‘lishi kerak.

- Prorab → Quruvchilar → “Brigadir bo‘yicha saralash”: tanlangan brigadirning quruvchilari va holatlari ko‘rinadi; “Barcha brigadirlar” umumiy ro‘yxatni qaytaradi.
- Ombor → “Brigadirlardagi materiallar”: omborchi/prorab brigadirni tanlab, undagi materiallar va berilganidan qaytarishlar ayrilgan qoldiqni ko‘radi. Brigadir faqat o‘z materiallarini ko‘radi; direktorda oldingi faqat-ombor-qoldig‘i ruxsati saqlanadi.
- “Kirim” yuqorida, “Material qo‘shish” yonida. Mavjud tur tanlanib, kelgan miqdor yoziladi. Material turi qoldiq 0 bo‘lsa ham saqlanadi; qayta yaratish shart emas. Ataylab arxivlangan materialga kirim qilish uchun avval uni tahrirlash oynasida arxivdan chiqaring.
- Ombor harakatlari va quruvchilar API sahifalari bo‘yicha to‘liq yuklanadi; ko‘p yozuv bo‘lsa ham eski berilgan materiallar hisobdan tushib qolmaydi.

## Hisobchi, quruvchi hujjatlari va sotuv ruxsatlari (22-oktabr)

Oldingi beshta migratsiya, jumladan `202610210001_site_operations.sql`, bajarilgach **`supabase/migrations/202610220001_accounting_and_workers.sql`** faylini SQL Editor’da yangi so‘rovga to‘liq qo‘yib, bir marta Run bosing. Avval bajarilgan fayllarni takrorlamang. Yangi loyiha migratsiyalarni fayl nomi bo‘yicha ketma-ket bajaradi. Edge Function’ni o‘zgartirish talab qilinmaydi.

- **Omborchi:** yuqoridagi “Brigadirlarga taqsimlash” tugmasi orqali material va shu obyekt brigadirini tanlaydi. Tugma telefon ekranida ham ko‘rinadi. Omborda qoldiq bo‘lmasa avval material yarating va Kirim qiling. Omborchi va brigadirlar bir obyektga biriktirilgan, profillari faol bo‘lishi kerak.
- **Chat:** Telegramga o‘xshash suhbatlar ro‘yxati, qidiruv, avatar, oxirgi xabar, sana va xabar pufakchalari. Enter yuboradi, Shift+Enter yangi satr; har bir suhbat qoralamasi chat oynasi ichida saqlanadi. Bitta belgi serverga yuborilganini anglatadi, o‘qilganini bildirmaydi. Telefon ko‘rinishida orqaga tugmasi suhbatlar ro‘yxatiga qaytaradi.
- **Pasport:** 2 lotin harfi + 6–7 raqam (`AD123456` yoki `AD1234567`); JSHSHIR alohida **14 raqamli matn** (boshidagi 0 saqlanadi). 1–4 ta pasport rasmi majburiy; frontend va SQL ikkisi tekshiradi. Eski erkin matnli `submit_worker` RPCsi yopiladi.
- **Eski quruvchilar:** ma’lumotlar o‘chmaydi. Oldin tasdiqlanganlar ishlashda davom etadi. Tasdiq kutilayotgan eski yozuvda pasport raqami/JSHSHIR bo‘lmasa, brigadir “Batafsil → Quruvchi ma’lumotlarini to‘ldirish” orqali tuzatadi; mavjud rasmlarni saqlashi yoki yangisini yuklashi mumkin. Rad etilgan yozuv ham shu yo‘l bilan yana tasdiqqa yuboriladi. Tasdiqlangan quruvchining hujjatlarini brigadir o‘zgartira olmaydi.
- **Ishdan bo‘shatish:** prorab faqat o‘z obyektidagi tasdiqlangan quruvchini sabab yozib bo‘shatadi. Yozuv va hujjatlar tarixda saqlanadi, “Ishdan bo‘shatilgan” ro‘yxatiga o‘tadi va faol quruvchilar sonidan chiqadi. Boshqa brigadir yoki boshqa obyekt prorabi bu amalni bajara olmaydi.
- **Hisobchi / Бухгалтер:** barcha obyektlar bo‘yicha “Xodimlar va oyliklar”, “Ombor xarajatlari”, “Brigadalar” bo‘limlari. Xodim uchun oyiga bitta yozuv: belgilangan summa, to‘langan summa va qoldiq. Direktor va quruvchilar kiritilmaydi. Bu mablag‘ hisobini yuritadi; bank orqali pul o‘tkazmaydi. Oylikni tahrirlash shu oyning yozuvini yangilaydi. Bo‘shatilgan xodimning avvalgi yozuvlari saqlanadi, yangi oylik belgilanmaydi.
- **Ombor xarajatlari:** hisobchi haqiqiy Kirim harakatiga xarajat, to‘langan summa, yetkazib beruvchi va hisob-faktura raqamini yozadi. Narx kiritilmagan kirimlar alohida sanaladi; ular bepul kirim deb hisoblanmaydi. Miqdor ombor daftaridan olinadi, hisobchi miqdorni o‘zgartirmaydi.
- **Brigadalar:** hisobchi brigadir nomi, obyekti va tasdiqlangan faol quruvchilar sonini ko‘radi. Pasport raqami, JSHSHIR yoki rasmlar hisobchiga berilmaydi.
- **Sotuvlar:** direktor faqat ko‘radi va eksport qiladi. Qo‘shish/tahrirlash interfeysda ham, SQL RPCda ham faqat Sotuvchiga ochiq.

Moliyaviy jadvallar: `payroll`, `receipt_costs`. Ularni faqat faol Hisobchi o‘qiydi/yangilaydi; boshqa rollarga moliyaviy yozuvlar berilmaydi. Eski hisoblar va lavozimlar saqlanadi. Hisobchi lavozimi aynan `Hisobchi` yoki `Бухгалтер` bo‘lishi kerak.

## Obyekt hujjatlari, ombor va quruvchilar (21-oktabr yangilanishi)

Oldingi to‘rtta migratsiya, jumladan `202610160002_management_workflows.sql`, bajarilgan bo‘lishi kerak. So‘ng **`supabase/migrations/202610210001_site_operations.sql`** faylini SQL Editor’da yangi so‘rovga to‘liq qo‘yib, bir marta Run bosing. Avval bajarilgan migratsiyalarni takrorlamang. Yangi loyiha uchun `supabase/migrations/` fayllari nomi bo‘yicha ketma-ket bajariladi. Ushbu yangilanish uchun `manage-members` Edge Function’ni qayta deploy qilish shart emas.

Migratsiya mavjud ma’lumotlarni saqlaydi. Eski obyektlarda blok/qavat sonlari bo‘sh qoladi; ularni Obyektlar → Tahrirlash orqali to‘ldiring. Direktor xodim profilida obyektni biriktiradi. Ombor va quruvchilar shu obyekt bo‘yicha ajratiladi; obyekt biriktirilmagan xodim omborni boshqara olmaydi yoki quruvchi yubora olmaydi.

| Lavozim | Ombor | Quruvchilar |
| --- | --- | --- |
| Direktor | Barcha obyektlardagi mavjud qoldiq; boshqarish va taqsimot tarixi yo‘q | Pasport ma’lumotlari ochilmaydi |
| Omborchi | Biriktirilgan obyekt: material yaratish/tahrirlash, kirim, brigadaga berish, qaytarish, nol qoldiqli materialni arxivlash | Yo‘q |
| Prorab | Biriktirilgan obyektning qoldig‘i va brigadalarga berilgan materiallar, faqat o‘qish | Shu obyektdagi arizalarni ko‘rish, tasdiqlash yoki sabab bilan rad etish |
| Brigadir | Faqat o‘ziga berilgan/qaytarilgan materiallar, ombor qoldig‘i ochilmaydi | O‘z brigadasi quruvchilarini yuborish va tasdiqlanganlar ro‘yxati |
| Boshqa xodim | Yo‘q | Yo‘q |

`Brigada boshlig‘i`, `Brigadir`, `Brigadar` va ruscha standart nomlar taniladi. Ixtiyoriy boshqa lavozim avtomatik maxsus ruxsat olmaydi. Hisobotlar, Topshiriqlar va Chat barcha xodimlarda bor; Sotuvlar faqat Sotuvchi uchun saqlangan. Chat barcha faol xodimlar orasida ishlaydi, xabar matnini faqat ikki ishtirokchi ko‘radi. Aloqa ro‘yxati faqat ID, ism, lavozim va obyektni beradi, pasport/telefon/emailni bermaydi.

- **Obyekt hujjatlari:** nom, manzil, blok/qavat soni va tugash sanasi. PDF hujjatlar ixtiyoriy, har biri 10 MB gacha; keyinroq tahrirlash oynasida yana qo‘shish mumkin. `project-documents` yopiq bucket. Yuklash/o‘chirish direktor uchun, o‘qish direktor va biriktirilgan obyekt xodimlari uchun. Obyekt saqlanib, fayl yuklashda xato bo‘lsa, shu oynada qayta saqlash yangi obyekt nusxasini yaratmaydi.
- **Ombor:** miqdorlar 0.001 aniqlikkacha. Taqsimot faqat shu obyektning faol brigadiriga. Yetarli qoldiq bo‘lmasa berilmaydi; qaytarish avval berilgan va hali qaytmagan miqdordan oshmaydi. Harakatlar o‘chirilmaydi; xato berilgan material qaytarish orqali hisobga olinadi. RPClar item qatorini bloklaydi va qayta yuborilgan bir xil operatsiyani ikki marta hisoblamaydi.
- **Quruvchi:** ism-familiya, vazifa, pasport matni va 1–4 JPEG/PNG rasm (har biri 5 MB gacha). Quruvchi alohida Auth hisobini olmaydi va 10 hisob limitini egallamaydi. Prorab tasdig‘igacha faqat “Tasdiq kutilmoqda” ro‘yxatida turadi. Rad etilgan yozuv tarixda saqlanadi; tuzatilgan ma’lumotlar yangi so‘rov bilan yuboriladi.
- **Pasport rasmlari:** `worker-passports` yopiq bucketida; faqat o‘z brigadiri va shu obyekt prorabi. Direktor, omborchi, boshqa brigadir va boshqa obyekt prorabi o‘qiy olmaydi. Yuborilgan rasmlar mijoz orqali almashtirilmaydi/o‘chirilmaydi. Ko‘rish havolasi 60 soniya amal qiladi; avval olingan havola shu muddat tugaguncha ishlashi mumkin. Bo‘shatilgan xodimning yangi so‘rovlari darhol bloklanadi. Qoralama yuklamalar oynani bekor qilishda tozalanadi; brauzer kutilmaganda yopilsa yuklangan qoralama fayllarni administrator keyin tozalashi mumkin.

Git push bu SQLni Supabase’da avtomatik bajarmaydi. O‘rnatgandan keyin obyekt yarating, Omborchi/Prorab/Brigadirlarni shu obyektga biriktiring, kirim → berish → qaytarish hamda quruvchi → prorab tasdig‘i jarayonini ikki qurilmada tekshiring.

## Ishlayotgan saytga yangi imkoniyatlarni o‘rnatish

Oldingi uch migratsiya bajarilgan bo‘lsa, ularni qaytarmang:

1. SQL Editor → New query’da **`supabase/migrations/202610160002_management_workflows.sql`** faylini to‘liq bajaring. Hisoblar va hisobotlar saqlanadi. Bu bir martalik migratsiya.
2. Edge Functions → `manage-members` → Code → `index.ts` ichidagi kodni repozitoriydagi **`supabase/functions/manage-members/index.ts`** bilan to‘liq almashtiring va **Deploy updates** bosing. Avval SQL, keyin Edge Function.
3. Vercel yangi Git commitni deploy qilgach saytni yangilang. Obyekt yarating, xodim profilida obyekt biriktiring, Sotuvchi lavozimini yarating.

Yangi migratsiya bajarilmaguncha sayt ko‘rsatma chiqaradi va yangi boshqaruv amallarini bloklaydi. Git push Supabase SQL yoki Edge Function’ni avtomatik o‘rnatmaydi.

- **Obyektlar:** yaratish, tahrirlash va xodimga biriktirish. Yangi hisobot xodimning shu paytdagi obyektiga yoziladi; eski hisobotlar o‘z-o‘zidan yangi obyektga ko‘chmaydi.
- **Xodimlar:** ishdan bo‘shatish kirish huquqlarini bazada ham bekor qiladi; qayta ishga olish mumkin. Profilni o‘chirish shaxsiy maydonlarni tozalaydi va kirishni bloklaydi, tarixiy hisobot/topshiriq yozuvlarini saqlaydi. Auth foydalanuvchisi fizik o‘chirilmaydi; eski login orqali autentifikatsiya bo‘lsa ham ma’lumotlarga ruxsat yo‘q. O‘chirilgan profil tiklanmaydi va 10 hisob limitida joy bo‘shatadi; bo‘shatilgan profil joy egallashda davom etadi.
- **Topshiriqlar:** tahrirlash, mas’ulni almashtirish va tasdiq bilan o‘chirish.
- **Hisobotlar:** tekshirilayotgan hisobotni tasdiqlash yoki majburiy sabab bilan bekor qilish. Sabab xodimga ko‘rinadi. Qaror qayta o‘zgartirilmaydi; xodim tuzatilgan yangi hisobot yuborishi mumkin.
- **PDF:** bitta yoki filtrlangan hisobotlarni barcha rasmlari bilan haqiqiy PDFga yuklash. Rasm yuklanmasa tugallanmagan PDF chiqarilmaydi. Yopiq rasmlarga vaqtinchalik havolalar 10 daqiqagacha amal qiladi; bo‘shatish ilgari berilgan havolani muddatidan oldin bekor qilmaydi.
- **Sotuvchi:** Sotuvlar kabinetida obyekt, kvartira, xaridor, narx va tushgan to‘lovni kiritadi; o‘z sotuvlarini tahrirlaydi. Direktor barcha sotuvlarni kuzatadi (22-oktabr migratsiyasidan keyin faqat o‘qish). Oddiy xodim sotuv ma’lumotlarini o‘qiy olmaydi.

Boshqaruv migratsiyasidan keyin eski `repair-schema.sql` ishlatilmaydi: u yangi ruxsatlarni eski versiyaga tushirmaslik uchun to‘xtaydi.

## Hozir nima tayyor?

- Sayt Supabase Auth orqali login/parol bilan kiradi. Direktor yoki xodim kabineti bazadagi rol bo‘yicha ochiladi.
- Eski mahalliy hisoblar haqiqiy hisobga avtomatik aylantirilmaydi. Login sahifasini chetlab direktor kabinetiga kirish olib tashlangan.
- SQL migratsiyasi: `members`, `reports`, `tasks`, `messages`, profilni yakunlash funksiyalari va RLS ruxsatlari.
- Bitta kompaniya uchun jami 10 hisob: 1 direktor + 9 xodim. Parallel hisob yaratish so‘rovlarida ham SQL darajasida limit tekshiriladi.
- Xodim faqat o‘z hisobotlari va topshiriqlarini ko‘radi. Direktor barcha hisobotlarni ko‘radi va tasdiqlaydi.
- Realtime yangilanishlar yoqiladi; sahifa fokusga qaytganda va har 30 soniyada zaxira yangilanish ham bor.
- Lavozim yaratish/parol yangilash uchun serverdagi `manage-members` Edge Function tayyor.
- Dastlabki 10 hisobni Auth Admin API bilan yaratuvchi `npm run provision` skripti tayyor.

**Fayllarning repozitoriyda mavjudligi ularning Supabase’da o‘rnatilganini anglatmaydi. Quyidagi amallar haqiqiy loyiha administratori kirishini talab qiladi. Public/publishable kalit bunga yetmaydi.**

## Qisman o‘rnatilgan bazani tiklash

Agar `function "is_director" already exists` yoki oldingi bajarishda `public.members does not exist` xatosi chiqqan bo‘lsa, SQL Editor’da **yangi so‘rov** oching va `scripts/repair-schema.sql` faylini to‘liq bajaring. Unda asosiy jadvallar ham, kamera rasmlari uchun Storage sozlamalari ham bor. Mavjud hisob va hisobot yozuvlari o‘chirilmaydi; faqat Themelio’ning nomlangan funksiyalari, triggeri va siyosatlari qayta o‘rnatiladi. Boshqaruv migratsiyasi o‘rnatilmagan sxemada faylni qayta bajarish mumkin. Tiklashdan keyin yangi `202610160002_management_workflows.sql` migratsiyasini ham bajaring.

Natijada `status = Baza tayyor`, `accounts` va `director_accounts` chiqadi. `director_accounts = 0` bo‘lsa, direktor hisobi hali yo‘q: parolni yangilash skripti hisob yaratmaydi. Hisob yaratish bosqichini bajaring. Bu tiklash usuli ma’lum Themelio sxemasi uchun; bir xil nomli, boshqa tuzilishdagi jadvallar bo‘lsa, ularni o‘chirmang va xatoni tekshiring.

## 1. Jadvallarni yarating

Supabase Dashboard → loyihangiz → **SQL Editor → New query**.

`supabase/migrations/202610150001_initial.sql` faylining to‘liq matnini ko‘chirib, **Run** bosing. Keyin alohida so‘rovda `supabase/migrations/202610150002_report_photos.sql` faylini bajaring. So‘ng `supabase/migrations/202610160001_fix_auth_metadata_timing.sql` faylini bajaring. Oxirida `supabase/migrations/202610160002_management_workflows.sql` faylini bajaring. Oldin bajarilgan migratsiyalarni takrorlash shart emas. Bu bir martalik, tranzaksiyali migratsiya. Shu nomdagi jadvallar oldin bo‘lsa, ustiga qayta ishga tushirmang; holatni avval tekshiring.

Migratsiya Auth foydalanuvchisi yaratilganda `members` yozuvini avtomatik yaratadigan trigger o‘rnatadi. `app_role` va `position` faqat administrator bergan `app_metadata`dan olinadi. Oddiy signup yoki profil formasi direktor rolini bera olmaydi.

Authentication sozlamalarida Email/Password kirishini yoqing, ochiq **Allow new users to sign up** ni o‘chiring. Hisoblarni direktor/server admin yaratadi; xodimlar o‘zlari ochiq ro‘yxatdan o‘tmaydi. Ishonchli app_metadata roli bo‘lmagan Auth hisobiga ilova profili va ma’lumot ruxsatlari berilmaydi.

## 2. Server funksiyasini joylashtiring

Supabase Dashboard → **Edge Functions → Deploy a new function → Via Editor**:

- Nomi: `manage-members`
- Kodi: `supabase/functions/manage-members/index.ts` faylining to‘liq matni.
- Deploy qiling.
- Agar `Verify JWT with legacy secret` sozlamasi bo‘lsa, o‘chiring. **Funksiya har bir so‘rovda JWTni `auth.getUser` orqali o‘zi tekshiradi**, keyin bazadagi direktor rolini tekshiradi. Bu sozlama loginni tekshirmaslik degani emas.
- `SUPABASE_URL` va `SUPABASE_SERVICE_ROLE_KEY` Supabase Edge muhitida avtomatik taqdim etiladi. Ularni frontendga qo‘shmang.

CLI orqali o‘rnatish varianti (Supabase akkauntingiz bilan autentifikatsiya talab qiladi):

```sh
npx supabase@latest login
npx supabase@latest functions deploy manage-members --project-ref pumkmcpekrbshcvfojim --no-verify-jwt
```

## SQL Editor orqali birinchi direktor hisobini tiklash

Agar `repair-schema.sql` natijasida `director_accounts = 0` chiqsa va Auth Admin API bilan ishlash uchun server kaliti muhitga uzatilmayotgan bo‘lsa, loyiha administratori SQL Editor’da `scripts/create-director.sql` faylini **to‘liq** bajarishi mumkin.

Bu administrator uchun tiklash skripti: `auth.users`, email `auth.identities` va Themelio profilini yaratadi. Login `direktor`, tasodifiy parol esa oxirgi **Results → new_password** ustunida ko‘rinadi. Parolni xavfsiz saqlang. Mavjud direktor topilsa, uning paroli o‘zgartirilmaydi; parol yo‘qolgan bo‘lsa `scripts/reset-director.sql` ishlatiladi. Ushbu fayllar frontendga qo‘shilmaydi va ommaviy RPC yaratmaydi.

Bu usul standart Supabase Auth sxemasi va `extensions` sxemasidagi pgcrypto funksiyalariga mo‘ljallangan. SQL sxemasi mahalliy modelda tekshirilgan; haqiqiy Auth kirishi SQL bajarilgandan keyin tekshiriladi. Kundalik yangi xodimlar uchun rasmiy Auth Admin API’ni ishlatuvchi Edge Function afzal.

Birinchi direktor kirgach, qolgan 9 ta xodim lavozimini kabinet orqali bittadan yaratishi mumkin. Bu bilan dastlabki xodimlar parollari direktorning tegishli oynasida ko‘rsatiladi.

## 3. Dastlabki 10 ta hisobni yarating

Bu amalni ishonchli lokal terminalda yoki shu cloud muhitda bajaring. Kerakli administrator kaliti: Supabase **Project Settings → API Keys → service_role / server secret key**. Public/publishable kalitni ishlatmang.

Kalitni chatga yoki GitHubga yubormang. Shu cloud muhitda ishlatish uchun environment settings’dagi `SUPABASE_SERVICE_ROLE_KEY` maxfiy talabi orqali xavfsiz kiriting; loyiha domeniga tarmoq kirishini ham saqlang. Muhit sozlamalari o‘zgarishi joriy jarayonga qo‘llangach skript qayta tekshiriladi. Lokal Bash terminalda esa kalitni buyruqlar tarixiga yozmasdan kiriting:

```sh
read -rsp 'Supabase server key: ' SUPABASE_SERVICE_ROLE_KEY
export SUPABASE_SERVICE_ROLE_KEY
printf '\n'
npm ci
npm run provision
unset SUPABASE_SERVICE_ROLE_KEY
```

Natija:

- `direktor` — Direktor.
- `xodim01` … `xodim09` — xodimlar; boshlang‘ich lavozimlar skriptdagi `positions` ro‘yxatida. Kerak bo‘lsa, skriptni bajarishdan oldin shu lavozimlarni o‘zgartiring.
- Har bir hisob uchun alohida tasodifiy kuchli parol yaratiladi. `auth.users`ga to‘g‘ridan-to‘g‘ri SQL yozilmaydi, rasmiy Auth Admin API ishlatiladi.
- Yangi parollar faqat `.private/themelio-credentials.json` fayliga `0600` ruxsat bilan yoziladi; konsolga chiqarilmaydi, Git’dan chiqarib tashlangan. Faylni xavfsiz joyda saqlang va har bir xodimga faqat uning login-parolini bering.
- Oldin mavjud hisoblar/parollar o‘zgartirilmaydi. Qisman xatolik bo‘lsa, yaratilgan hisoblarning ma’lumotlari faylda qoladi. Qayta urinish uchun `CREDENTIALS_FILE=.private/credentials-next.json npm run provision` kabi boshqa chiqish faylini belgilang.
- Xodimning ismi va boshqa shaxsiy ma’lumotlari oldindan kiritilmaydi. Login qilib profilini to‘ldirgach, direktor ro‘yxatiga qo‘shiladi.

**10 ta hisobning barchasi yaratilgach, yana yangi hisob yaratib bo‘lmaydi.** Dastlabki 9 xodim lavozimi oldindan tayyorlanadi; ularni ushbu jamoangiz uchun moslab oling. Hisobni to‘liq o‘chirish/almashtirish uchun administrator amali kerak bo‘ladi; frontendda o‘chirish hali qo‘shilmagan.

## 4. Vercel sozlamalari

`.env.example` frontend uchun faqat ommaviy qiymatlarni ko‘rsatadi:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY`

Bu loyihaning public qiymatlari kodda standart sifatida ham mavjud. Vercel → Project → Settings → Environment Variables’da ularni belgilab, **Redeploy** qilish mumkin. Brauzer kodi ichida `service_role`, server secret key yoki Supabase access token bo‘lmasligi kerak. Vercelga server kalitini berish talab qilinmaydi: hisob yaratish Supabase Edge Function’da bajariladi.

## 5. Haqiqiy ishga tushirish tekshiruvi

1. `direktor` bilan kiring; direktorning o‘z profilini to‘ldiring.
2. Boshqa qurilma yoki inkognito brauzerda `xodim01` bilan kiring, profilini yakunlang.
3. Direktorning Xodimlar sahifasida shu xodim ko‘ringanini tekshiring.
4. Xodim ertalabki/yakuniy hisobot yuborsin; direktor ayni sana va tur filtrida hisobotni ochib tasdiqlasin.
5. Xodim sahifasida **Qabul qilindi** holati paydo bo‘lsin.
6. `xodim02` bilan kirganda boshqa xodimning hisoboti ko‘rinmasligi kerak.
7. Direktor topshiriq biriktirsin; tegishli xodim o‘z kabinetida bajarilish foizini yangilasin.

SQL bazasi, Auth hisoblari va Edge Function o‘rnatilmaguncha ushbu haqiqiy tekshiruvlar o‘tkazilgan hisoblanmaydi.

## Chegaralar va test dalillari

- Kamera orqali olingan JPEG rasmlar hisobotga qo‘shiladi. Har bir hisobotga 5 tagacha, har bir rasm 5 MB gacha. Galereya/fayl tanlash yo‘q. PDF yuklash hali qo‘shilmagan.
- Loyiha bitta kompaniyaga mo‘ljallangan. Bir nechta kompaniya uchun alohida tenant va RLS qoidalari kerak.
- Savdo va obyekt boshqaruvi hozircha bo‘sh interfeys holatida.
- `test:db` — aynan SQL migratsiyasini PGlite/PostgreSQL’da bajarib RLS, rollar, 10 hisob limiti, hisobotlar, topshiriqlar va xabarlar ruxsatlarini tekshiradi.
- `test:edge` — Edge handlerni mock Auth Admin API bilan tekshiradi.
- `test:ui` — Supabase HTTP javoblarini mock qilib haqiqiy brauzerda ikki mustaqil sessiya oqimini tekshiradi. Haqiqiy Supabase loyihasiga ulanmaydi.
- Cloud test muhitida Supabase domeniga dastlabki so‘rovlar proxy tomonidan `403 Forbidden` bilan rad etilgan. Domen muhit konfiguratsiyasi loyihasiga qo‘shilgan; bu joriy tarmoq allaqachon ochilganini bildirmaydi.

## Faqat kameradan rasmli hisobot

`202610150002_report_photos.sql` migratsiyasi `report-photos` nomli **yopiq** Storage bucket va rasmlarni hisobotga biriktirish funksiyasini yaratadi.

- Xodim faol profil bilan kiradi, **Kamerani ochish → Rasmga olish** tugmalaridan foydalanadi. Brauzerga kamera ruxsati berilishi kerak. Telefonning orqa kamerasi afzal tanlanadi; kameralarni almashtirish ham bor.
- Qurilma kamerasidan `getUserMedia` orqali olinadi; galereya uchun `input[type=file]` mavjud emas. Kamera uchun HTTPS yoki localhost kerak. Haqiqiy telefonlarda kamera ruxsatlari va brauzer qo‘llab-quvvatlashini tekshiring.
- Rasm JPEG sifatida maksimal 1920 pikselga moslanadi. Yuborishdan oldin preview ko‘rinadi; ortiqcha rasmni o‘chirish mumkin.
- Kamera surat olingach, oyna yopilgach yoki sahifa yashirilgach to‘xtatiladi. Mikrofon so‘ralmaydi.
- Fayllar faqat xodimning UUID papkasiga yuklanadi. Xodim o‘z rasmlarini, direktor esa yuborilgan hisobotga biriktirilgan rasmlarni ko‘radi. Boshqa xodimlar ko‘ra olmaydi. Bucket ommaviy emas.
- Rasm ko‘rish uchun 10 daqiqalik vaqtinchalik havola yaratiladi. Ochiq sahifada havolalar yangilanadi. Hisobotga biriktirilgan rasmlarni xodim almashtira yoki o‘chira olmaydi.
- Yuborishda xatolik bo‘lsa, tanlangan rasmlar va matn formadan o‘chmaydi. Yuklangan qoralamalarni tozalashga urinish qilinadi. Ulanish to‘liq uzilsa, yuborilmagan fayl bucketda qolishi mumkin; keyinchalik administrator qoralamalarni tozalashi mumkin.
- Har bir yuborishning UUIDsi bor: server javobi yo‘qolganidan keyin qayta urinish bir xil hisobotni takror yaratmaydi.

Mahalliy baza testlari Storage jadvallari modeli bilan haqiqiy SQL siyosatlarini bajaradi; brauzer testi sun’iy kamera va mock Supabase Storage javoblarini ishlatadi. Haqiqiy Supabase Storage va jismoniy telefondagi kamera tekshiruvi migratsiya o‘rnatilgandan keyin alohida bajariladi.

## Lavozim yaratishda umumiy xato chiqsa

`manage-members` Edge Function’ning yangi kodi 24 belgili, katta-kichik harf, raqam va maxsus belgini kafolatlaydigan parollar yaratadi. Qat’iy Auth parol siyosati yoqilgan loyihalarda ham shu sinflar bajariladi. Avvalgi generator maxsus belgi yaratmagan.

Funksiya Auth xatosini endi `error_code` bilan qaytaradi; frontend uni `[weak_password]`, `[unexpected_failure]` kabi ko‘rsatadi. Xato sababini faqat kod yoki tegishli Auth logi tasdiqlaydi. Hech qanday parol, token yoki admin kaliti logga yozilmaydi.

**GitHub/Vercel deployi Supabase Edge Function kodini yangilamaydi.** Supabase → Edge Functions → `manage-members` → kod tahrirlash oynasida repozitoriydagi `supabase/functions/manage-members/index.ts` matnini to‘liq yangilang va Deploy qiling. CLI ishlatilsa, yuqoridagi `functions deploy` buyrug‘ini qayta bajaring.

Agar Logs’da `No logs queries` yozilsa, bu loglar bo‘shligini tasdiqlamaydi: avval Logs → New/Create query ochib, quyidagini bajaring (bu oddiy SQL Editor uchun emas):

```sql
select timestamp, event_message
from auth_logs
order by timestamp desc
limit 20;
```

Hisob yaratishni qayta sinab, log so‘rovini yangilang. `/admin/users` amali yoki bazaga yozish bilan bog‘liq xato kerak bo‘ladi. `unexpected_failure` bo‘lsa, eski Auth triggerlari yoki ruxsatlar kabi aniq sababni shu logdan aniqlang; noma’lum triggerlarni ko‘r-ko‘rona o‘chirmang.

## `Database error creating new user` diagnostikasi

SQL Editor’da `scripts/diagnose-auth-create.sql` faylini to‘liq bajaring. Bu administrator uchun vaqtinchalik diagnostika: Auth serverining `supabase_auth_admin` roli bilan xodim va email identity yozishni tekshiradi, triggerlarni ishga tushiradi va barcha sinov yozuvlarini subtranzaksiyada **bekor qiladi**. Triggerlar o‘chirilmaydi, mavjud hisoblar/parollar o‘zgarmaydi.

Results’da `error_code`, `error_message`, `error_function` va Auth trigger funksiyalarining nomlari ko‘rinadi. SQL satrlari, yozuv tafsilotlari va parol xeshlari qaytarilmaydi. `OK` natijasi faqat tekshirilgan DB yozish yo‘li muvaffaqiyatli bo‘lganini bildiradi; Auth Admin API’ning boshqa bosqichlari uchun haqiqiy Auth logi kerak. Boshqa natija qaysi trigger/jadval/ruxsatni tuzatish kerakligini aniqlashga yordam beradi. Noma’lum triggerlarni taxmin bilan o‘chirmang.

SQL Editor `permission denied to set role "supabase_auth_admin"` qaytarsa, bu diagnostikaning rol almashtirishi rad etilganidir; u asl Auth xatosining sababi emas. Diagnostikaning yangi versiyasi bunday holatda SQL Editor roli bilan davom etadi va natijada Auth rolidagi ruxsatlar tekshirilmaganini alohida yozadi. Asl xatoni Logs Explorer’dagi `auth_logs` orqali aniqlang.

## Tasdiqlangan Auth trigger xatosi: `Themelio accounts must be created by an administrator`

Supabase Auth Admin API yangi userni avval oddiy provider app_metadata bilan INSERT qiladi, keyin custom app_metadata’ni UPDATE qiladi. Eski AFTER INSERT trigger custom rol hali yozilmagan paytda xato qaytargan. Bu holat rasmiy Auth kodining `internal/api/admin.go` faylidagi `adminUserCreate` tartibida ham ko‘rinadi.

**Tuzatish:** SQL Editor’da `supabase/migrations/202610160001_fix_auth_metadata_timing.sql` faylini to‘liq bajaring. Bu mavjud hisoblar, parollar yoki hisobotlarni o‘chirmaydi. Yangi trigger AFTER INSERT va AFTER UPDATE OF raw_app_meta_data’da ishlaydi. Ishonchli rol bo‘lmasa, Auth yozuviga ruxsat beradi, ammo ilova profili yaratmaydi. Faqat server boshqaradigan app_metadata’da employee/director roli mavjud bo‘lganda membership yaratiladi; user_metadata’dan rol olinmaydi. Rolsiz hisoblar direktor profili yoki boshqa ilova ma’lumotlarini o‘qiy olmaydi. Qayta UPDATE profilni takror yaratmaydi va 10 hisob limiti saqlanadi.

SQL muvaffaqiyatli bajarilgach saytda lavozim yaratishni qayta sinang. Avval yangilangan Edge Function kodini bu tuzatish uchun yana o‘zgartirish shart emas. Yangi o‘rnatishlarda shu uchinchi migratsiya ham bajarilishi kerak. `repair-schema.sql` ham ushbu tuzatishni o‘z ichiga oladi.
