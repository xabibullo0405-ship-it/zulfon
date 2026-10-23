# Zulfon — qurilish boshqaruvi

PDF maketlari asosida yaratilgan o‘zbek tilidagi React/Vite kabineti. Supabase Auth, direktor/xodim rollari, xodimning o‘z profilini to‘ldirishi, hisobot yuborish va direktor tomonidan tasdiqlash qo‘shilgan.

## Ishga tushirish

Node.js 22.12+ yoki 24:

```sh
npm ci --cache /tmp/themelio-npm-cache
npm run dev -- --port 3000
```

Ishchi papka: `/workspace/themelio`. Production: `npm run build`, natija `dist/`. Vercel sozlamalari `vercel.json`da.

## Supabase’ni o‘rnatish

**[SUPABASE_SETUP.md](SUPABASE_SETUP.md)** qo‘llanmasini bajaring:

1. SQL Editor’da `supabase/migrations/202610150001_initial.sql` migratsiyasini, keyin `202610150002_report_photos.sql` va `202610160001_fix_auth_metadata_timing.sql` va `202610160002_management_workflows.sql`, so‘ng `202610210001_site_operations.sql` va `202610220001_accounting_and_workers.sql` migratsiyalarini ketma-ket bajaring. Barchasi `supabase/migrations/` papkasida.
2. `supabase/functions/manage-members/index.ts` Edge Function’ni joylashtiring.
3. Server kaliti bilan `npm run provision` bajarib 1 direktor + 9 xodim hisobini yarating. Parollar faqat Git’dan chiqarilgan `.private/` fayliga yoziladi.
4. Saytda login, profil, hisobot yuborish va tasdiqlashni ikki qurilmada tekshiring.

Public loyiha URL/kaliti kodda sozlangan, `.env.example` orqali almashtirilishi mumkin. Public kalit jadvallar yoki Auth hisoblarini yaratishga ruxsat bermaydi. Server kalitlari hech qachon `VITE_*` ichiga kiritilmaydi.

Eski mahalliy brauzer hisoblari serverga avtomatik ko‘chirilmaydi. Supabase o‘rnatilmaguncha haqiqiy tizim tayyor deb hisoblamang.

## Imkoniyatlar

- O‘zbekcha/ruscha interfeys: pastki o‘ng burchakdagi O‘z / Рус tugmalari. Til shu brauzerda saqlanadi, formadagi ma’lumotlar va sessiya saqlanib qoladi. Ismlar va foydalanuvchi yozgan hisobotlar tarjima qilinmaydi. PDF yorliqlari tanlangan tilda chiqadi.


- Supabase login/parol va sessiya; rol bazadan aniqlanadi.
- Jami 10 hisob chegarasi, direktor boshqaradigan lavozim va login-parol yaratish.
- Xodim profilini o‘zi to‘ldiradi; yakunlangach direktor ro‘yxatida ko‘rinadi.
- Ertalabki/yakuniy hisobotlar, faqat kamerada olingan rasmlar (5 tagacha), sana filtri, direktor tasdig‘i yoki sabab bilan bekor qilish, rasmlar bilan PDF eksport. Rasmlar yopiq Supabase Storage bucketida saqlanadi.
- Direktor obyekt yaratadi, xodimga obyekt biriktiradi; topshiriq yaratadi, tahrirlaydi va o‘chiradi. Xodim bajarilish foizini yangilaydi.
- Xodimni ishdan bo‘shatish, qaytarish va profilini o‘chirish; tarixiy hisobotlar saqlanadi.
- Sotuvchi kabinetida sotuv yaratish/tahrirlash, xaridor, kvartira, tushgan to‘lov va qarzdorlik. Direktor sotuvlarni faqat kuzatadi.
- Direktorning xodimga xabar yuborishi, xabarlar uchun bazada shaxsiy ruxsatlar.
- Obyektning manzili, blok/qavat soni, tugash sanasi va yopiq PDF hujjatlari.
- Barcha xodimlar uchun Hisobotlar, Topshiriqlar va shaxsiy Chat.
- Omborchi: yuqoridagi Kirim tugmasidan saqlangan material turini tanlash, taqsimot/qaytarish; direktor: qoldiq; prorab: qoldiq va taqsimot; brigadir: faqat olingan materiallar. Brigadirlar qo‘lidagi qoldiq qaytarishlar ayrilgan holda alohida ko‘rinadi.
- Prorab quruvchilarni brigadir bo‘yicha saralaydi; holat yorliqlaridagi sonlar ham shu brigadirga moslanadi.
- Brigadir quruvchi, pasport raqami, 14 raqamli JSHSHIR va majburiy pasport rasmlarini yuboradi. Prorab tasdiqlaydi yoki ishdan bo‘shatadi; quruvchilar uchun login yaratilmaydi.
- Hisobchi xodimlar oyligi va to‘lovlarini oy bo‘yicha yuritadi, ombor kirimlari xarajatini qayd qiladi, brigadirlardagi faol quruvchilar sonini ko‘radi. Direktor va quruvchilar oylikka kiritilmaydi.
- Xodimlar chati: suhbatlar ro‘yxati, qidiruv, xabar pufakchalari, suhbat qoralamalari va mobil ko‘rinish.
- Mobil ko‘rinish, qidiruv, arxiv, profil, bildirishnomalar.

Galereyadan rasm tanlash yo‘q. PDF uchun Unicode shriftlar ilovaga kiritilgan; litsenziya `src/assets/DejaVu-LICENSE.txt` ichida.

## Testlar

```sh
npm run test:db
npm run test:edge
npm run test:pdf
# Dev server 3000-portda ishlab turgan bo‘lishi kerak:
BROWSER_PATH=/usr/bin/chromium npm run test:ui
npm run build
```

Chromium bo‘lmasa `npx playwright install chromium`, so‘ng `npm test`. `BASE_URL` test serverini o‘zgartiradi. Baza testlari haqiqiy SQLni lokal PostgreSQL/PGlite’da bajaradi; Edge/UI testlari Supabase API’larini mock qiladi. Bu testlar haqiqiy Supabase deploymenti yoki real hisoblar yaratilganini tasdiqlamaydi.
