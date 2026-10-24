# QA Checkpoints — We R in Trouble (Deadline build)

| | |
|---|---|
| ผู้เขียน | QA/Playtest |
| วันที่ | 2026-10-23 |
| อ้างอิง | `docs/GDD.md` v0.4 §5.8, §5.10, §8.6, §8.9 (CP0–CP4), §8.10, §8.11 / `docs/TEAM.md` / `docs/reviews/GDD-review-1..3.md` |
| ข้อตัดสินใจของ Boss ที่ใช้ | **ไม่มีโหมดเล่นคนเดียว**: ต้องมี ≥ 2 คนถึงเริ่ม (`SOLO_START_AFTER` = ปิด) ผู้เล่นคนเดียวใน Lobby ต้อง**รอ** และเห็นข้อความ "Waiting for players (1/2)" ชัดเจน |

> เอกสารนี้ใช้แทน checklist ใน GDD §8.9/§8.11 ส่วนที่พูดถึง solo ทั้งหมด (ดูหัวข้อ 0)
> รหัสใช้อ้างอิงในบั๊ก: `CP1-7` = CP1 ข้อ 7, `S3` = smoke ข้อ 3, `E5` = edge case 5

---

## 0. สิ่งที่เปลี่ยนจาก GDD เพราะปิด solo

| ที่ใน GDD | เดิม | ใช้แทนในเอกสารนี้ |
|---|---|---|
| §8.6 Round flow | Intermission 20s เมื่ออยู่คนเดียว + เปลี่ยนเป็นนับ co-op เมื่อคนที่ 2 เข้ามา | **ไม่มี** คนเดียว = รอไม่มีกำหนด และขึ้น "Waiting for players (1/2)" / ครบ 2 คน → นับ 30s / เหลือ 1 คนระหว่างนับ → หยุดนับ กลับไปขึ้น Waiting (E7) |
| §8.9 CP1 | "ทั้ง 2 คนและ solo" | 2 clients เท่านั้น |
| §8.9 CP4 | "PC และมือถือ + solo จนจบ" | PC + มือถือ **2 บัญชีใน server เดียวกัน** เล่นจนจบ + เช็คหน้าจอรอของคนเดียว |
| §8.11 DoD Studio | "1 (solo), 2 และ 4 clients" | **2, 3 และ 4 clients** |
| §8.11 DoD | "Solo ถูก Eliminated ระหว่างรอกรง" | ยังต้องเทสต์ แต่ทำผ่าน**เพื่อนออกกลาง Match จนเหลือ 1 คน** (E3) |
| §8.11 DoD | "คนที่ 2 เข้ามาระหว่างนับ solo" | เทสต์ Lobby รอ/เริ่มนับ/หยุดนับ (E7) |
| §8.11 DoD ส่งงาน | "เล่นคนเดียวจนจบได้บน live server" | คนเดียวเห็นหน้ารอชัดเจน ไม่ error + 2 คนเล่นจนจบบน live ได้ |

**สมมติฐาน (QA ตั้งเอง ต้องให้ Lead ยืนยัน):** solo fallback **ระหว่าง Match** (§3.5: `activeCount = 1` → MultiHold required = 1, ล้ม = Eliminated ทันที, ไม่มี Wipe) **ยังอยู่** เพราะเป็นตาข่ายกัน softlock ตอนเพื่อนออกกลาง Match ไม่ใช่โหมดเล่นคนเดียว Boss ปิดแค่การเริ่ม Match คนเดียว

---

## 1. วิธีตั้งค่าเทสต์ (อ่านครั้งเดียว)

### 1.1 Studio "Local Server"
1. แท็บ **Test** → กลุ่ม **Clients and Servers** → dropdown เลือก **Local Server** → จำนวนเลือก **2 Players** (หรือ 3/4 ตามที่ CP ระบุ) → กด **Start**
2. จะได้ 1 หน้าต่าง Server + 1 หน้าต่างต่อ client สลับหน้าต่างเพื่อคุมทีละตัว
3. คำสั่ง Luau สำหรับตรวจ: เปิด **View → Command Bar** ในหน้าต่าง **Server** (หรือ client ถ้าระบุว่า client)
4. จบเทสต์: กด **Cleanup** (ปุ่มเดียวกับ Start) ปิดทุกหน้าต่าง
5. **ดู Output ทุกหน้าต่าง** (Server + ทุก client) ข้อความสีแดงที่ไม่ได้ตั้งใจ = บั๊ก

### 1.2 ข้อจำกัดสำคัญ: คนเดียวกดค้าง E ใน 2 หน้าต่างพร้อมกันไม่ได้
- Studio ส่ง input ให้หน้าต่างที่ focus อยู่เท่านั้น การกดวิทยุ (MultiHold) "พร้อมกัน 2 คน" จึง**ต้องใช้ debug command `spawnDummyHolder <anchor>`** แทนคนที่ 2 (§8.6) เช่น client 1 กดค้างวิทยุ A ส่วนวิทยุ B ใช้ dummy
- งานที่ใช้คนเดียวทำ (วงล้อ, ถ่าน, revive, เดินเข้าโซน) สลับหน้าต่างทำทีละคนได้ปกติ
- ความรู้สึกเรื่อง co-op จริงทดสอบได้เฉพาะตอน playtest กับผู้เล่นจริง (21:00 วันที่ 24)

### 1.3 Debug commands (Studio/dev เท่านั้น)
`skipStep`, `setStage <Calm|Warning|Active|Critical>`, `unlockExit`, `setHP <n>`, `spawnDummyHolder <A-D>`, `endMatch win|lose` เรียกผ่านช่องทางที่ Systems กำหนด (chat/command) ใช้เพื่อย่นเวลาในทุก CP

### 1.3b Studio dev switches (Lead ตัดสิน 24 ต.ค. หลัง CODE-review-1)
- Studio ทำงานเหมือน live โดย default: **ต้อง 2 คน** (CP0-5/6, S3, E7 เทสต์ใน Studio ได้ตรงๆ)
- AI เทสต์คนเดียว: ตั้ง Attribute `DevMinPlayers = 1` (number) บน `ServerStorage` ก่อนกด Start
- CP1 (ยังไม่มีภัย): ตั้ง Attribute `DevNoHazards = true` บน `ServerStorage` — Stage/timer ยังเดิน แต่ไม่มีของตก/damage · CP2 ต้องลบออก
- ทั้งสองค่าไม่มีผลบน live · ห้ามเซฟ place ที่ publish พร้อม attribute เหล่านี้ (S2: ตรวจว่าไม่มี)

### 1.4 Snippet ตรวจเร็ว (วางใน Command Bar ของหน้าต่าง Server)
```lua
-- สถานะผู้เล่นทุกคน
for _, p in game.Players:GetPlayers() do print("[QA]", p.Name, p:GetAttribute("State"), "HP", p:GetAttribute("HP"), p:GetAttribute("MoveMode"), p:GetAttribute("SpeedMult")) end
```
```lua
-- นับ instance (ใช้เทียบ leak ข้ามรอบ ต้องรันตอนอยู่ใน Lobby ทุกครั้ง)
print("[QA] CharacterAutoLoads =", game.Players.CharacterAutoLoads, "| Map exists =", workspace:FindFirstChild("Map") ~= nil, "| descendants =", #workspace:GetDescendants())
```

---

## 2. Checkpoints

### CP0 — 02:00 วันที่ 24 · "Rojo sync ได้, เดินแฮมสเตอร์บนแมพได้, Round เริ่ม–จบได้"
**Setup:** Studio, `rojo serve` + Rojo plugin Connect → Local Server **2 Players** · **เวลา: ~12 นาที**

| # | ทดสอบ | ผ่านเมื่อ |
|---|---|---|
| 1 | Rojo plugin กด Connect | ไม่มี error ใน Rojo/Output และเห็น `ServerScriptService.Server`, `StarterPlayerScripts.Client`, `ReplicatedStorage.Shared` |
| 2 | แก้คอมเมนต์ 1 บรรทัดในไฟล์ `.luau` ใดก็ได้แล้ว save | การเปลี่ยนแปลงโผล่ใน Studio ภายในไม่กี่วินาที |
| 3 | Start Local Server 2 Players | Output ของ Server + client ทั้ง 2 ไม่มีสีแดง |
| 4 | รัน snippet นับ instance (1.4) | `CharacterAutoLoads = false`, `Map exists = false` |
| 5 | ดู client 1 ก่อนที่ client 2 จะโหลดเสร็จ (หรือเทสต์ซ้ำด้วย 1 Player 30s) | อยู่ใน Lobby เป็นแฮมสเตอร์, HUD ขึ้น **"Waiting for players (1/2)"** และ**ไม่เริ่มนับ** |
| 6 | เมื่อครบ 2 คน | ทั้ง 2 หน้าจอขึ้น Intermission 30s นับตรงกัน |
| 7 | เดินชนขอบ Lobby และกระโดดที่ขอบ | ออกจาก Lobby ไม่ได้ (กำแพงล่องหน) |
| 8 | นับครบ | มี `Workspace.Map` 1 อัน ทั้ง 2 ตัวไปโผล่ที่มุมกรง [A] บนพื้นครัว |
| 9 | เดิน: พื้น → เขียง/ตำราอาหาร → เคาน์เตอร์ → ที่คว่ำจาน → ขอบหน้าต่าง และปีนผ้าม่านจากพื้น | ขึ้นได้ทุกช่วงโดยไม่ต้องกระโดดต่อกันหลายครั้ง ไม่ติด ไม่ทะลุพื้น |
| 10 | กด Shift ค้างแล้วเดิน | ความเร็วไม่เปลี่ยน (ไม่มีวิ่ง) ตัวละครเป็นแฮมสเตอร์ v0 |
| 11 | Esc → Reset Character | ปุ่มใช้ไม่ได้ / กดแล้วไม่มีอะไรเกิด |
| 12 | `endMatch win` (หรือรอจบตามเวลา) | Result 15s → ทุกคนกลับ Lobby → `Workspace.Map` หายไป |
| 13 | รอรอบที่ 2 เริ่ม แล้วรัน snippet (1.4) ในหน้าต่าง Server | Intermission เริ่มเอง, `Map` มีแค่ 1 อันตอนเข้า Match (ไม่ซ้อน) |
| 14 | Cleanup | ไม่มี error ตอนปิด |

ไม่ผ่านข้อ 1–3, 5–6, 8, 12 = **Blocker** (ห้ามไปต่อ) ข้ออื่นเปิดบั๊กแล้วไปต่อได้

---

### CP1 — 12:00 วันที่ 24 · "Lobby → Step 1 → Step 2 → ETA → ชนะ (ยังไม่มีภัย)"
**Setup:** Local Server **2 Players** (ข้อ 15 ใช้ 3 Players) · **เวลา: ~15 นาที** (ใช้ `skipStep` ถ้าต้องเทสต์ซ้ำ)

| # | ทดสอบ | ผ่านเมื่อ |
|---|---|---|
| 1 | Smoke test (หัวข้อ 3) | ผ่านครบ |
| 2 | เข้า Match | Briefing ขึ้นชื่อ Mission + Step 1, HUD มีรายการ objective, marker บนวงล้อและแท่นชาร์จ (ถ่าน**ไม่มี** marker) |
| 3 | ดู HUD ถ่าน | "0/2" (2 คน), ถ่าน 2 ก้อนอยู่**คนละโซน** มีแสงกะพริบ + เสียงเมื่อเข้าใกล้ ~30 studs |
| 4 | กดค้างที่วงล้อ (client 1) แล้วปล่อย จากนั้นกดค้างแล้วเดินออกห่าง > 10 studs | progress บน Billboard ขึ้น + ท่าวิ่งในวงล้อ, ปล่อยแล้วค่าคงอยู่, เดินออกนอกระยะแล้ว progress หยุด (ต้องกดใหม่) |
| 5 | หยิบถ่าน (client 2) | ถ่านติดมือ, prompt หยิบถ่านก้อนอื่นซ่อน, prompt "Insert" ที่แท่นชาร์จขึ้นเฉพาะคนที่ถือ |
| 6 | เสียบถ่าน | HUD และ Billboard เป็น "1/2", ถ่านหายจากมือ |
| 7 | ระหว่าง Step 1 ไปที่วิทยุ | prompt วิทยุกดไม่ได้ / ไม่ขึ้น (Locked) |
| 8 | ทำ Step 1 ครบ | Banner "Step complete", prompt วิทยุ A–D เปิด, marker ย้ายไปที่วิทยุ |
| 9 | client 1 กดค้างวิทยุ A คนเดียว | "Held 1/2" progress **ไม่ขึ้น** |
| 10 | `spawnDummyHolder B` ขณะ client 1 ยังกด A | "Held 2/2" progress ขึ้น, ปล่อย A → progress หยุดแต่**ไม่ลด** (Cumulative) |
| 11 | client 1 กดค้าง A แล้วเดินไปกด C | ถูกถอดจาก A (1 คนจับได้ 1 anchor) |
| 12 | สะสมครบ 45s | หน้าต่างเปิด, HUD "Rescue ETA 60s", marker ชี้ Exit Zone → ครบ 60s กรงหย่อนลงมา |
| 13 | ให้แค่ client 1 เข้า Exit Zone | Departure **ไม่นับ** → client 2 เข้าด้วย → นับ 10s → client 2 ก้าวออกตอนเหลือ ~5 → หยุด (ไม่รีเซ็ต) → กลับเข้า → นับต่อจาก ~5 |
| 14 | นับครบ | ชนะ, Result ขึ้น Escaped ทั้ง 2 ชื่อ + เวลา, 15s แล้วกลับ Lobby รอบใหม่ไม่มีถ่าน/กรงเก่าค้าง |
| 15 | Cleanup → Local Server **3 Players** → เข้า Match → `skipStep` → `endMatch lose` (~3 นาที) | HUD ถ่าน "0/3" และวิทยุ "Held x/3" |

---

### CP2 — 17:00 วันที่ 24 · "Match เต็มพร้อม Earthquake, ล้ม/revive/respawn, แพ้ Collapse และ Wipe"
**Setup:** Local Server **2 Players** · **เวลา: ~15 นาที** · ข้อ 13 ต้องใช้ค่าชั่วคราว `MATCH_HARD_LIMIT = 120` ใน Config บน Studio เท่านั้น (**ห้าม commit** และ smoke test ข้อ S2 ต้องเห็น 420 ทุกครั้ง) หรือให้ AI รัน Collapse 7:00 จริงแทน (หัวข้อ 6)

| # | ทดสอบ | ผ่านเมื่อ |
|---|---|---|
| 1 | Smoke test | ผ่านครบ |
| 2 | ดู 0:00–0:50 | Calm (สีเขียว) → 0:30 Warning: Banner "EARTHQUAKE!" ≥ 3s + สั่นเบา, **ไม่มี damage** → 0:45 Active (สีส้ม) |
| 3 | ยืนนิ่งช่วง Active | วงแดงขึ้นก่อนของตก ~1.5s, โดนแล้ว HP −30 + "โป๊ก!" (ไม่มีจอแดง/เลือด), debris ไม่ชนตัวและจางหายใน ~3s |
| 4 | ยืนบน spawn บนพื้น 30s ช่วง Active | ไม่มีวงแดงในรัศมี ~6 studs รอบ spawn |
| 5 | ยืนบนทางลาด, บนเคาน์เตอร์ และบนขอบหน้าต่าง (ใช้ `setStage Active`) | โดน impact ได้ทุกที่ และวงแดงอยู่บนพื้นระดับเดียวกับเรา (ไม่ลอย/ไม่จมคนละชั้น) |
| 6 | client 1 ถือถ่านแล้ว `setHP 0` | Downed: ม้วนตัว + ดาวหมุน, overlay "Dizzy!" + นับ bleed-out 30s, คลานช้า, กระโดด/กด prompt ไม่ได้, ถ่านตกวางอยู่บนพื้น |
| 7 | สลับไป client 2 | เห็น marker เพื่อนที่ Downed ทะลุกำแพงพร้อมระยะ, หยิบถ่านที่ตกได้ |
| 8 | client 2 revive: ปล่อยตอน 2s แล้วกดใหม่จนครบ 4s | ปล่อยก่อนครบ → progress กลับ 0, ระหว่าง revive ผู้ล้มขยับไม่ได้, ครบ → Standing HP 40 |
| 9 | `setHP 0` client 1 แล้วปล่อย 30s | "Poofed!", กล้องตามเพื่อน, นับ respawn 15s → เกิดที่ spawn พื้น HP 100 ไม่โดน damage 3s แรก |
| 10 | `unlockExit` | เข้า Critical ทันที (สีแดง) + Big Shake 4s (ของร่วงทั่วครัว) ทีมที่ HP เต็ม**ไม่ล้มทั้งทีม** |
| 11 | ช่วง ETA ให้ client 1 ยืนนิ่งบน spawn ขอบหน้าต่าง | โดน impact ได้ (ไม่ใช่จุดปลอดภัย) |
| 12 | `setHP 0` ทั้ง 2 คน (ห่างกันไม่เกิน 2s) | **แพ้ทันที** Result ขึ้นสาเหตุ Wipe |
| 13 | รอบใหม่ (`MATCH_HARD_LIMIT = 120`): ไม่ทำภารกิจ รอหมดเวลา | แพ้ Collapse (fade ดำ) Result ขึ้นสาเหตุ Collapse |
| 14 | รอบใหม่: `skipStep` ×2 → รอกรง → เข้าโซน | ไม่มีวงแดงใน Exit Zone หลังกรงมาถึง, ชนะได้ |
| 15 | กลับ Lobby แล้วรัน snippet (1.4) + เริ่มรอบถัดไป | ไม่มี debris/วงแดงค้าง, HP = 100, State ถูกรีเซ็ต, จำนวน descendants ใกล้เคียงหลังรอบแรก |

---

### CP3 — 21:00 วันที่ 24 · FEATURE FREEZE · "ทุกอย่างใน §8.6 + Rescue Moment → เปิด public"
**Setup:** Studio Local Server **3 และ 4 Players** (ข้อ 1–5), **Device Emulator** (ข้อ 9), **live place** (ข้อ 12–15) · **เวลา: ~15 นาที** (Studio 10 + live 5)

| # | ทดสอบ | ผ่านเมื่อ |
|---|---|---|
| 1 | 3 Players: smoke S1–S7 | ผ่าน, ถ่าน "0/3" |
| 2 | 3 Players: Step 2 เปิดแล้ว กดวิทยุ 2 อัน (client + dummy) รอ 75s | ขึ้น "Override engaged — 2 of 3 needed" แล้ว progress เริ่มขึ้นด้วย 2 คน |
| 3 | 2 Players: Step 2 รอเกิน 75s โดยกดแค่ 1 อัน | **ไม่มี** override (ต่ำสุด 2) |
| 4 | 4 Players: เข้า Match | ถ่าน "0/3" (สูงสุด 3), วิทยุ "Held x/4" |
| 5 | 2 Players: รอกรงมาถึงแล้วให้เข้าโซนแค่ 1 คน 45s | "Last call! The carrier is leaving" แล้ว Departure นับด้วย 1 คน, คนนอกโซนไม่ได้ Escaped |
| 6 | Rescue Moment ตอน `unlockExit` → ETA → ชนะ | ไฟแดง/น้ำเงินสาดผ่านหน้าต่าง + ไซเรน, กรงหย่อนลงพร้อมไฟฉาย, ชนะแล้วกล้องไปมุมนอกหน้าต่าง 3s ก่อน Result |
| 7 | กด H | HUD + marker หายหมด กด H อีกครั้งกลับมา |
| 8 | ดูทั้ง Match | Lighting เปลี่ยนตาม Stage, มีเสียงไซเรน/สั่น/"โป๊ก!"/จี๊ด/ถ่าน/วิทยุซ่า/กรง/เพลงชนะ-แพ้ |
| 9 | Device Emulator (มือถือแนวนอน 1 รุ่น + แท็บเล็ต 1 รุ่น) | HUD ทั้ง 8 ชิ้นไม่ล้นจอ ไม่ทับปุ่มกระโดด/จอยสติ๊ก อ่านออก, แตะ prompt ได้ |
| 10 | ดูตัวละคร | แฮมสเตอร์ v1 (หรือ v0 ถ้าใช้ลำดับตัดข้อ 6), ดาวหมุนตอน Downed, ปุ๊ฟตอน Eliminated |
| 11 | Edge case E1 + E2 (หัวข้อ 4) | ผ่าน |
| 12 | Live: เปิด public แล้วเข้าจากบัญชีที่ 2 / มือถือผ่านลิงก์ | เข้าได้, Max players 4, คนแรกเห็น "Waiting for players (1/2)" |
| 13 | Live: บัญชีที่**ไม่อยู่**ในรายชื่อ dev ลองสั่ง debug command | ไม่มีผลใดๆ |
| 14 | Live: Esc → Reset | ใช้ไม่ได้ |
| 15 | Live: F9 Developer Console (บัญชีเจ้าของ) | Server/Client log ไม่มีสีแดงหลังเล่น 1 Match |

---

### CP4 — 08:00–09:00 วันที่ 25 · "live server ทั้ง PC และมือถือ จนจบ"
**Setup:** live place (เวอร์ชันหลัง code freeze), PC (บัญชี Boss) + มือถือ (บัญชีที่ 2 ที่ไม่อยู่ในรายชื่อ dev หรือเพื่อน) อยู่ server เดียวกัน · **เวลา: ~15 นาที**

| # | ทดสอบ | ผ่านเมื่อ |
|---|---|---|
| 1 | Creator Hub → Version history | เวอร์ชันล่าสุดตรงกับ commit ตอน code freeze |
| 2 | มือถือเข้าเกมก่อนคนเดียว รอ 60s | อยู่ใน Lobby, "Waiting for players (1/2)" ชัด, ไม่เริ่ม Match เอง |
| 3 | PC กด Join ตามเข้า server เดียวกัน | Intermission 30s เริ่มบนทั้ง 2 เครื่อง |
| 4 | มือถือ: เดิน, กระโดด, แตะค้างที่วงล้อ, หยิบ/เสียบถ่าน | ทำได้ครบ ไม่ต้องใช้ปุ่มพิเศษ |
| 5 | Step 2: PC และมือถือกดวิทยุคนละอันพร้อมกัน | "Held 2/2" progress ขึ้น |
| 6 | ระหว่างเล่นให้คนหนึ่งล้มแล้วอีกคน revive | revive ได้ทั้งจาก PC ไป มือถือ และกลับกัน (อย่างน้อย 1 ทิศ) |
| 7 | เล่นจนชนะ | Rescue Moment + กล้องตอนชนะ + Result ขึ้นบนทั้ง 2 เครื่อง |
| 8 | กลับ Lobby | รอบถัดไปเริ่มนับได้ |
| 9 | HUD บนมือถือจริง | อ่าน timer, objective, HP, ETA ได้ ไม่ทับปุ่ม |
| 10 | F9 Developer Console (PC) | ไม่มีสีแดง |
| 11 | มือถือ (บัญชีไม่ใช่ dev) สั่ง debug command | ไม่มีผล |
| 12 | Esc → Reset บนทั้ง 2 เครื่อง | ใช้ไม่ได้ |
| 13 | หน้าเกมบน Roblox (เปิดจาก incognito) | Public, ชื่อ/คำอธิบาย/icon/thumbnail ถูก, อุปกรณ์ Computer/Phone/Tablet, คำอธิบายบอกว่า**ต้องมี 2 คนขึ้นไป** |

ถ้า CP4 เจอ Blocker: ทำตาม §8.10 — publish เวอร์ชันล่าสุดที่ผ่าน CP3/CP4 แล้วใส่บั๊กในเอกสาร ห้ามกินเวลาบล็อก 08:00–11:30

---

## 3. Smoke test (หลัง sync ทุกครั้ง · ≤ 5 นาที)

**Setup:** Local Server **2 Players**

| # | ทดสอบ | ผ่านเมื่อ |
|---|---|---|
| S1 | Rojo Connect + Start | Output ของ Server และ client ทั้ง 2 ไม่มีสีแดง |
| S2 | ดูค่าใน Config (ไฟล์ใน `src/shared/Config/`) หรือรัน snippet 1.4 | `MIN_PLAYERS_TO_START = 2`, solo start ปิด, `MATCH_HARD_LIMIT = 420`, `CharacterAutoLoads = false` (ไม่มีค่าเทสต์ชั่วคราวค้าง) |
| S3 | client แรกตอนอยู่คนเดียว | "Waiting for players (1/2)" ไม่นับถอยหลัง |
| S4 | ครบ 2 คน | Intermission 30s ทั้ง 2 จอ |
| S5 | เข้า Match | `Workspace.Map` มี 1 อัน, ทั้งคู่อยู่ที่ spawn, HUD Stage/timer/objective ขึ้น |
| S6 | กดค้างวงล้อ 3s | progress ขึ้น |
| S7 | `endMatch win` | Result → กลับ Lobby → `Map` หาย |
| S8 | Esc → Reset | ใช้ไม่ได้ |
| S9 | Cleanup | ไม่มี error ตอนปิด |

ไม่ผ่านข้อใด = แจ้ง Lead ทันที **ห้ามเทสต์ CP ต่อบน build นี้**

---

## 4. Edge cases (Deadline build) เรียงตามความเสี่ยง

ความเสี่ยง = โอกาสเกิดจริงตอนตรวจงาน/playtest × ผลถ้าพัง ทุกข้อใช้ Local Server ตามจำนวนที่ระบุ "ผล" คือสิ่งที่ต้องเกิดตาม GDD

| # | ความเสี่ยง | เคส | ขั้นตอนทำซ้ำ (ตรงตัว) | ผลที่ต้องเกิด | GDD |
|---|---|---|---|---|---|
| E1 | **สูงมาก** | **คนออกกลาง Match ระหว่างวิทยุ (2 → 1)** | 2 Players → `skipStep` → client 1 กดค้างวิทยุ A → ปิดหน้าต่าง client 2 (กากบาท) | วิทยุเปลี่ยนเป็น "Held 1/1" และ progress เดินต่อ, Match ไม่ค้าง, ไม่มี error จบได้ด้วยคนเดียว | 3.4 ข้อ 3, 3.5, 5.9 |
| E1b | สูงมาก | คนออกขณะถือถ่าน + จำนวนถ่านลด | 3 Players → เสียบถ่าน 1 ก้อน → client 3 หยิบถ่านก้อนที่ 2 → ปิด client 3 | ถ่านของ client 3 ตกวางบนพื้น, HUD เปลี่ยนจาก "1/3" เป็น "1/2", ถ่านที่เกินซึ่งยังไม่มีใครหยิบหายไป | 3.4 Deliver, 5.7 |
| E2 | **สูงมาก** | **ทุกคน Downed (Wipe)** และกรณีที่ไม่ใช่ Wipe | (ก) 2 Players `setHP 0` ทั้งคู่ (ข) รอบใหม่: `setHP 0` client 1 ปล่อยจน Poofed (รอ respawn) แล้ว `setHP 0` client 2 | (ก) แพ้ Wipe ทันที (ข) **ไม่แพ้** เพราะยังมีคนรอ respawn → client 1 respawn แล้ว revive client 2 ได้ | 5.8 แพ้ข้อ 2 |
| E2b | สูง | เหลือคนเดียวหลังเพื่อนออก แล้วล้ม | 2 Players → ปิด client 2 → `setHP 0` client 1 | Eliminated ทันที (ไม่ผ่าน Downed), ไม่แพ้ Wipe, respawn 15s แล้วเล่นต่อได้ | 3.5 |
| E3 | **สูง** | **Exit Zone ว่าง / `activeCount = 0`** | 2 Players → `unlockExit` → รอกรงมาถึง → ปิด client 2 → `setHP 0` client 1 (Eliminated) แล้วนั่งดู | Departure **ไม่นับ** ระหว่างรอ respawn → respawn บน spawn ขอบหน้าต่าง → เดินเข้าโซน → นับ 10s → ชนะ ห้ามจบด้วย Escaped = 0 | 5.8 ข้อ 3, D1 |
| E4 | สูง | Departure หยุดชั่วคราว / Downed ในโซน / Last call | 2 Players หลังกรงมาถึง: (ก) ทั้งคู่เข้าโซน นับถึง 5 แล้ว client 2 ออก (ข) client 2 กลับเข้าแล้ว `setHP 0` client 2 ในโซน (ค) รอบใหม่: เข้าโซนแค่ 1 คน รอ 45s | (ก) หยุดที่ ~5 ไม่รีเซ็ต (ข) นับต่อ client 2 ที่ Downed ในโซนได้ Escaped (ค) "Last call" แล้วออกด้วย 1 คน | 5.8 ข้อ 4–6 |
| E4b | กลาง | 7:00 ขณะกรงมาถึงแล้ว | `MATCH_HARD_LIMIT = 120` (ชั่วคราว) → `unlockExit` ที่ ~0:50 → ให้ 1 คนอยู่ในโซน อีกคนอยู่นอกโซนจนหมดเวลา | **ชนะ** คนในโซน = Escaped (ถ้า Last call ไม่ทำให้จบก่อน) | 5.8 ชนะ |
| E5 | **สูง** | **Round cleanup รั่วข้ามรอบ** | 2 Players → เล่น 3 รอบติดด้วย `endMatch win`, `endMatch lose`, Wipe → หลังกลับ Lobby ทุกรอบรัน snippet 1.4 | `Map exists = false`, descendants ไม่เพิ่มขึ้นเรื่อยๆ (ต่างกันไม่เกินหลักสิบ), ไม่มี debris/กรง/ถ่าน/Billboard ค้าง, Attribute ผู้เล่นรีเซ็ต (State=Lobby, HP=100) | 2.4, CONVENTIONS |
| E6 | สูง | คนเข้ามากลาง Match | 2 Players กำลังอยู่ใน Match → หน้าต่าง Server: Test → **Add Player** (หรือ Start client เพิ่ม) | คนใหม่อยู่ใน Lobby, HUD บอกเวลาที่เหลือของ Match, ไม่นับใน `teamCount` (วิทยุยัง "Held x/2", ถ่านไม่เพิ่ม) → รอบถัดไปเข้า Match พร้อมกัน 3 คน | 2.1 |
| E7 | สูง | **Lobby รอผู้เล่น (ไม่มี solo)** | (ก) 1 Player รอ 60s (ข) เพิ่มคนที่ 2 → นับไปถึง ~15 → ปิดคนที่ 2 (ค) 2 Players ให้ client 2 ไม่แตะอะไร 60s | (ก) "Waiting for players (1/2)" ไม่เริ่ม (ข) หยุดนับ กลับไป Waiting (1/2) ไม่เริ่ม Match คนเดียว (ค) client 2 ขึ้น "AFK — move to join next match" และไม่เริ่ม (นับแค่ 1/2) | 2.1, ข้อตัดสินใจ Boss |
| E8 | สูง | **Debug commands บน live** | บน live place ใช้บัญชีที่ไม่อยู่ในรายชื่อ dev ลองทุกคำสั่ง (`skipStep`, `unlockExit`, `setHP 0`, `endMatch win`) | ไม่มีผลใดๆ และไม่มี error บอกชื่อคำสั่ง AI ตรวจโค้ดว่า server เช็ค `IsStudio()` / UserId ทุกครั้ง ไม่ใช่เช็คแค่ฝั่ง client | 8.6 |
| E9 | สูง | **ปุ่ม Reset / ตายแบบ Roblox** | (ก) Esc → Reset Character (Studio + live, PC + มือถือ) (ข) Command Bar ของ**หน้าต่าง client**: `game.Players.LocalPlayer.Character.Humanoid.Health = 0` ขณะ Standing (ค) ทำ (ข) ขณะ Downed | (ก) ใช้ไม่ได้ (ข) ไม่ตาย หรือถ้าตาย = Eliminated + respawn 15s โดย server (ไม่เกิดเองที่ SpawnLocation) (ค) respawn delay = 15 + เวลา bleed-out ที่เหลือ | 5.2 |
| E10 | สูง | **Prompt บนมือถือ** | มือถือจริง (CP3/CP4) หรือ Device Emulator: (ก) แตะค้างวงล้อแล้วยกนิ้ว (ข) แตะค้างวิทยุแล้วลากนิ้วไปหมุนกล้อง (ค) ถือถ่านยืนใกล้แท่นชาร์จที่มีถ่านอีกก้อนวางอยู่ใกล้ๆ (ง) revive เพื่อนที่ล้มติดกำแพง | (ก) progress หยุดเมื่อยกนิ้ว (ข) ไม่ค้างสถานะกดอยู่ตลอด (ค) prompt Insert ขึ้นและแตะถูก (ง) prompt revive แตะได้ (`RequiresLineOfSight` ไม่บัง) | 3.3, 5.6 |
| E11 | กลาง | Prompt ถูกปิดขณะกดค้าง | 2 Players: client 1 กดค้างวิทยุ A + dummy B จน progress ครบ (Step 2 เสร็จ) / รอบใหม่: client 1 กดค้างวงล้อแล้ว `setHP 0` | ผู้เล่นถูกถอดจาก holder set, ไม่ค้างท่ากด, ไม่ค้าง `Pinned`, เดินได้ปกติ | 3.3 |
| E12 | กลาง | Revive ถูกขัด | 2 Players + client 3: client 1 Downed, client 2 กำลัง revive → (ก) ปิด client 1 (ข) รอบใหม่ `setHP 0` client 2 ระหว่าง revive | (ก) prompt หาย client 2 ไม่ค้างท่า (ข) revive ยกเลิก, bleed-out ของ client 1 นับต่อ, client 1 ไม่ค้าง Pinned | 5.3 |
| E13 | กลาง | Impact รอบ spawn | 2 Players `setStage Critical` ยืนบน spawn พื้น 30s แล้วไปยืนบน spawn ขอบหน้าต่าง (หลัง `unlockExit`) 30s | spawn พื้น: ไม่มีวงแดงในรัศมี 6 / spawn ขอบหน้าต่าง: **โดนได้** | 4.2, D2 |
| E14 | กลาง | ถ่านตกนอกแมพ | Command Bar ของ Server: ย้ายถ่านที่วางอยู่ไป Y = −40 (`<ถ่าน>:PivotTo(CFrame.new(0,-40,0))` ใช้ชื่อ instance ตามที่ Systems ตั้ง) | 3s ต่อมาถ่านกลับไปที่ ItemSpawn เดิม พร้อมแสง/เสียง | 5.7 ข้อ 1 |
| E15 | กลาง | ผู้เล่นตกนอกแมพ | Command Bar ของ Server: `game.Players.<ชื่อ>.Character:PivotTo(CFrame.new(0,-50,0))` | Eliminated → respawn 15s ไม่ค้างกลางอากาศ | 5.1 |
| E16 | กลาง | ทุกคนออกจาก Match | 2 Players ใน Match → ปิดทั้ง 2 client → Test → Add Player 1 คน | Match จบเป็นแพ้ (ไม่มี team member) ไม่มี error, คนใหม่อยู่ใน Lobby เห็น Waiting (1/2) ไม่ใช่ติดอยู่ใน Match เก่า | 5.8 แพ้ข้อ 3 |
| E17 | กลาง | Respawn หลังหน้าต่างเปิด | 2 Players `unlockExit` → `setHP 0` client 1 รอ Poofed + 15s | เกิดบน spawn ขอบหน้าต่าง (Priority 1) ไม่ใช่พื้น | 5.4, 8.6 |
| E18 | กลาง | Big Shake ไม่ wipe | 2 Players HP 100 ยืนใกล้กัน → `unlockExit` → ยืนนิ่ง 4s | อย่างน้อย 1 คนไม่ล้ม (damage 15/ครั้ง) | 8.6.1, 8.11 |
| E19 | ต่ำ | Downed คลานเข้า Exit Zone | หลังกรงมาถึง `setHP 0` client 2 ห่างโซน ~5 studs คลานเข้าโซน แล้ว client 1 เข้าโซน | Departure นับ, client 2 ได้ Escaped | 5.3, 5.8 |
| E20 | ต่ำ | เข้ามาตอน Result/Intermission | ขณะ Result 15s → Add Player | คนใหม่เข้ารอบถัดไปพร้อมคนอื่น Intermission เริ่มปกติ | 2.1 |
| E21 | ต่ำ | ปุ่ม H ระหว่างพิมพ์แชท | กด `/` พิมพ์ข้อความที่มีตัว h | HUD ไม่ซ่อน | 8.6.1 |

**ลำดับทำถ้าเวลาน้อย:** E1 → E2 → E3 → E5 → E7 → E9 → E8 → E10 → E4 → E6 (ที่เหลือทำตามเวลา)

---

## 5. Bug report template (กรอกได้ใน < 1 นาที)

ส่งในแชทถึง Lead (Lead เป็นคนลงทะเบียน) คัดลอกแล้วเติมเฉพาะช่องว่าง:

```
BUG [Blocker / Major / Minor] — <สรุป 1 บรรทัด>
เจอตอน: CP_ / Smoke / Playtest   รหัสข้อ: ____ (เช่น CP1-11, E3)
Setup: Studio _ clients / Live PC / Live มือถือ
ทำอะไร: 1) ____ 2) ____ 3) ____
ควรเป็น: ____
เกิดจริง: ____
เกิดทุกครั้ง? ใช่ / บางครั้ง
Error (copy บรรทัดแดงบรรทัดแรกจาก Output / F9) หรือแนบ screenshot: ____
```

| ระดับ | ใช้เมื่อ | ทำอย่างไร |
|---|---|---|
| **Blocker** | เล่นจบ Match ไม่ได้ (softlock), Round ไม่เริ่ม/ไม่จบ, server error ที่ทำให้ระบบหยุด, เข้าเกมไม่ได้, ฟีเจอร์ในรายการ "ห้ามตัด" (§8.10) ใช้ไม่ได้, debug command ใช้ได้บน live | แก้ก่อนทำอย่างอื่น ถ้าแก้ไม่ทันก่อน CP ถัดไป → ใช้ลำดับตัด §8.10 |
| **Major** | ฟีเจอร์ IN ทำงานผิดแต่ยังเล่นจบได้ หรือมีทางเลี่ยง, เห็นชัดในวิดีโอ, ตัวเลขผิดจาก GDD จนบาลานซ์พัง, มือถือใช้ได้แต่ลำบาก | แก้ก่อน Feature freeze (CP3) / หลัง CP3 แก้เฉพาะที่เสี่ยงต่ำ |
| **Minor** | ภาพ เสียง ข้อความ ตำแหน่ง UI ตัวเลขจูน | แก้ถ้ามีเวลา ไม่งั้นใส่ "บั๊กที่รู้" ในเอกสารส่งงาน |

---

## 6. ใครเทสต์อะไร: AI agents (Studio automation) vs Boss

**เงื่อนไข:** AI ใช้ Studio ได้เฉพาะตอนที่ Boss เปิด Studio ทิ้งไว้และต่อ Studio MCP แล้ว (§8.9) เครื่องมือที่มี: เริ่ม/หยุด Play, รัน Luau ใน Edit/Server/Client, อ่าน Output, สั่งตัวละครเดินไปจุด/instance, ส่งปุ่มคีย์บอร์ด (เช่นกด E ค้างแล้วปล่อย), จับภาพหน้าจอตอน edit

**ข้อจำกัดใหญ่:** เท่าที่ QA ทราบ คำสั่ง Play ผ่าน MCP เป็นการเล่น**ผู้เล่นเดียว** (ไม่มีคำสั่งเปิด Local Server หลาย client — ให้ Systems ตรวจยืนยันตอน H0) เมื่อต้องมี ≥ 2 คนถึงเริ่ม Match **AI จะเริ่ม Match เองไม่ได้เลย** ถ้าไม่มีทางเลี่ยงสำหรับ dev → ดู "เรื่องที่ต้องตัดสิน" ข้อ 1

| ทดสอบ | AI ทำเองได้ | ต้องเป็น Boss | หมายเหตุ |
|---|---|---|---|
| `luau-analyze --!strict`, `selene`, grep หา `wait(`/`spawn(`/`delay(`/`_G`, ตัวเลข hard-code, Remote ที่ไม่ validate | ✅ (ไม่ต้องใช้ Studio) | | ทำก่อนทุก sync (D6) |
| ตรวจโค้ด: debug command เช็ค `IsStudio()`/UserId **ฝั่ง server**, `ResetButtonCallback`, `CharacterAutoLoads = false`, `SetStateEnabled(Dead)` ทั้ง 2 ฝั่ง, disconnect connection ตอนจบรอบ | ✅ | | E8, E9, E5 ระดับโค้ด |
| ตรวจ markup ของแมพ (Edit mode Luau): tag/Attribute ครบ (§8.3), spawn พื้น ×4 + ขอบหน้าต่าง ×2 `EnabledBy`, วิทยุห่างกัน ≥ 30 studs, ItemSpawn 3 โซน, `KillY = −30`, `NoImpact` เฉพาะ spawn ที่ไม่มี `EnabledBy`, กำแพงล่องหน `CanQuery = false`, raycast ตาราง grid ลงหาพื้นทุกจุดที่เดินได้, มี `WinCameraPoint` | ✅ | | ทำได้ทันทีหลัง Level วางแมพ ลดงาน CP0-9 |
| เริ่ม/หยุด Play แล้วอ่าน Output หา error, ตรวจ Lobby คนเดียวขึ้น Waiting (1/2) และ **ไม่เริ่ม** (อ่าน Attribute/GUI ผ่าน Luau) | ✅ | | S1, S3, E7(ก) |
| Match flow คนเดียวผ่าน debug: Stage timeline, timer, `skipStep`, `unlockExit`, ETA/กรง, `endMatch`, cleanup 3 รอบ + นับ instance, Collapse ที่ 7:00 จริง (ปล่อยรัน 7 นาที), ถ่านตก KillY, ผู้เล่นตก KillY, Downed → bleed-out 30s → respawn 15s, impact ไม่ตกรอบ spawn (log ตำแหน่ง impact) | ✅ **เฉพาะเมื่อมีทางเลี่ยง dev** | | AI รายงานผลเป็นตารางผ่าน/ไม่ผ่าน ให้ Boss ข้าม CP ข้อนั้นได้ |
| กดค้าง prompt ด้วยการส่งปุ่ม E + สั่งเดินไป anchor (วงล้อ, ถ่าน, ออกนอกระยะ) | ✅ (บางส่วน) | | ProximityPrompt กับ input จำลองอาจไม่ทำงานเหมือนจริง ถ้าไม่ได้ผล ให้ถือเป็นงาน Boss |
| ทุกอย่างที่ต้องมี ≥ 2 client: MultiHold "Held 2/2", Wipe, Departure ครบทีม, Last call, override ทีม 3–4, คนออก/เข้ากลาง Match (E1–E4, E6, E12, E16) | | ✅ Local Server | AI เตรียม checklist + อ่าน log หลัง Boss เทสต์ได้ |
| ความรู้สึก co-op, ความสนุก, ความยาก, จับเวลาทีม typical 3:30–5:30 (§8.11) | | ✅ ผู้เล่นจริง ≥ 2 คน | AI สรุปเวลาเทียบ §8.5 จากที่ Boss จด |
| มือถือจริง: แตะ prompt, อ่าน HUD, ปุ่มทับกัน (E10) | | ✅ | Device Emulator ช่วยแค่บางส่วน และ AI จับภาพได้แค่ตอน edit ไม่ใช่ระหว่าง Play |
| เสียง, lighting, Rescue Moment, กล้องตอนชนะ (ดูสวยสำหรับวิดีโอไหม) | | ✅ | |
| Live place: public, เข้าจากบัญชีอื่น/มือถือ, debug ใช้ไม่ได้บน live, Reset บน live, หน้าเกม (E8, CP3-12..15, CP4) | | ✅ | AI เข้า live ไม่ได้ |

---

## 7. เรื่องที่ต้องตัดสิน (ส่งต่อ Lead → Boss)

1. **ทางเลี่ยงสำหรับ dev ให้ AI เทสต์คนเดียวใน Studio** — แนะนำ: Config `DEV_MIN_PLAYERS_STUDIO = 1` ที่ server ใช้**เฉพาะเมื่อ `RunService:IsStudio()`** (live ยังต้อง 2 คนเสมอ ตรงกับข้อตัดสินใจของ Boss) และ smoke test ข้อ S3 ยืนยันทุกครั้งว่า Local Server ยังรอ 2 คน ถ้าไม่ทำ AI จะช่วยเทสต์ Match flow ระหว่าง Boss นอนไม่ได้เลย
2. **กรรมการที่เข้าเกมคนเดียวจะเล่นไม่ได้** (เดิม GDD เปิด solo เพราะเหตุผลนี้) — อย่างน้อยต้องเขียนในคำอธิบายเกมและเอกสารส่งงานว่า "ต้องมีผู้เล่น 2–4 คน ชวนเพื่อนเข้า server เดียวกัน" และหน้าจอรอใน Lobby ควรบอกว่า "Invite a friend" ด้วย (QA ตรวจข้อนี้ใน CP4-13)
3. **GDD ยังพูดถึง solo start** (§1, §8.1, §8.6 Round flow, §8.9 CP1/CP4, §8.11, §11 Q1-ค) — Game Designer ควรแก้ให้ตรงกัน ไม่งั้น Scripter อาจทำ Intermission 20s คนเดียว (smoke S3 และ E7 จะจับได้ แต่เสียเวลา)

## 8. สมมติฐานที่ QA ตั้งเอง

1. solo fallback **ระหว่าง Match** (เพื่อนออกจนเหลือ 1 คน) ยังอยู่ตาม §3.5 (หัวข้อ 0)
2. Debug commands มีครบตาม §8.6 ตั้งแต่ CP0 (Systems Day 1) ถ้ายังไม่มี เวลาของ CP0–CP2 จะเกิน 15 นาที
3. Studio "Add Player" ระหว่าง Local Server กำลังรัน ใช้เทสต์คนเข้ากลาง Match ได้ (ถ้าเวอร์ชัน Studio ไม่มี ให้เริ่ม 3 Players แล้วปิด client 3 ไว้ก่อน → เทสต์ E6 บน live ตอน CP3 แทน)
4. ชื่อ Config key และชื่อ instance ของถ่านอ้างตาม GDD §9 และจะเปลี่ยนตามที่ Systems ตั้งจริงใน Deadline contract (H0)
5. การกดค้าง prompt ใน 2 หน้าต่างพร้อมกันทำไม่ได้ จึงใช้ `spawnDummyHolder` แทนคนที่ 2 ในทุกเทสต์วิทยุบน Studio
