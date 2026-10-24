# We R in Trouble — Game Design Document (Theme A: ภัยพิบัติธรรมชาติ)

| | |
|---|---|
| สถานะ | **v0.5 — Boss อนุมัติแล้ว** (v0.4 + solo start ปิด; v0.4 = review 3 D1–D9) |
| **เส้นตายส่งงาน** | **25 ต.ค. 2026 เวลา 12:00 (เวลากรุงเทพฯ)** ส่ง: เกมที่ publish แล้ว + เอกสาร + วิดีโอ → **สิ่งที่สร้างก่อนคือหัวข้อ 8 "Deadline build"** ส่วนหัวข้ออื่นเป็นวิสัยทัศน์ระยะยาว (ป้าย M1/M2 ในหัวข้อเหล่านั้น = งานหลังส่งงาน) |
| ชื่ออื่นของโปรเจกต์ | "Roblox Hamster Conquror the world" |
| ผู้เขียน | Game Designer |
| วันที่ | 2026-10-23 |
| ผู้อ่าน | Boss, Gameplay Scripter, Systems/Data, UI/UX, Level Designer, Art & Audio, QA |

> ตัวเลขทุกตัวในเอกสารนี้เป็น **ค่าเริ่มต้นสำหรับ playtest** และต้องอยู่ใน `src/shared/Config/` ตาม CONVENTIONS.md (ห้าม hard-code) ชื่อ Config key ที่แนะนำอยู่ในหัวข้อ 9
>
> จุดที่เขียนว่า **(รอ Boss ยืนยัน Qn)** คือจุดที่ออกแบบตามคำตอบที่ผมแนะนำในหัวข้อ 11 ถ้า Boss ตอบตามค่าแนะนำ ไม่ต้องแก้เอกสาร

## คำศัพท์

| คำ | ความหมาย |
|---|---|
| Round | หนึ่งรอบเต็ม: Lobby → Match → Result |
| Match | ช่วงที่ผู้เล่นอยู่ในแมพ (ยาวสุด 7:00) |
| Mission | ชุดภารกิจของแมพ ประกอบด้วย Step ที่ทำตามลำดับ แล้วตามด้วย Extraction |
| Step | กลุ่ม Objective ที่ทำคู่ขนานได้ ต้องเสร็จทุกอันที่ไม่ optional จึงเปิด Step ถัดไป |
| Objective | งานชิ้นเดียว เช่น วิ่งวงล้อ 1 วง, ส่งถ่าน N ก้อน |
| Anchor | จุด interact ของ objective บนแมพ (1 objective มีได้หลาย anchor) |
| Stage | ระดับภัยพิบัติ: Calm → Warning → Active → Critical |
| Hazard component | ชิ้นกลไกภัยแบบ generic ที่ DisasterDef นำมาประกอบ |
| Extraction | ช่วงหลังปลดล็อกทางออก: รอยานกู้ภัยมาถึง (ETA) แล้วนับ Departure |
| Team member | ผู้เล่นที่อยู่ใน Match และ **ไม่ Inactive** (นับทั้ง Standing, Downed, Eliminated) |
| `teamCount` | จำนวน Team member ณ ขณะนั้น |
| `activeCount` | จำนวน Team member ที่ **ไม่ Eliminated** (Standing + Downed) ใช้กับ MultiHold, Departure, Last call |
| Collapse | หมดเวลา 7:00 = สถานที่พัง/จมทั้งหมด จบ Match |

### หลักการออกแบบ (ใช้ตัดสินเวลาไม่แน่ใจ)

1. **ภัยพิบัติทำให้ภารกิจอันตรายขึ้น แต่ไม่ทำให้ภารกิจเป็นไปไม่ได้** — ไม่มี softlock จากภัย, item, คนออก, คน AFK หรือคนไม่ยอมช่วย (ดู 5.10)
2. **ความเสียหายและการเปลี่ยนแปลงแมพทุกแบบต้องมี telegraph ≥ 1 วินาที** ยกเว้นความเสียหายต่อเนื่องที่มองเห็นอยู่แล้ว (ยืนในน้ำ/ไฟ)
3. **Co-op ถูกบังคับด้วยกลไก และขยายตามจำนวนคน** — ทีม 2, 3, 4 คน ทุกคนต้องมีส่วนในงานบังคับ
4. **ธีม = ข้อมูล** — โค้ดรู้จักแค่ Hazard component / Objective kind / Stage / status effect แบบ generic ชื่อธีม (แผ่นดินไหว, ถ่าน, กรงแมว, น้ำ, แฮมสเตอร์) อยู่ในไฟล์ data, asset และ string table เท่านั้น tag/attribute บนแมพก็ใช้ชื่อ generic
5. **Server เป็นเจ้าของ state ทั้งหมด** (CONVENTIONS.md) — HP, ความคืบหน้า, ตำแหน่ง item, ตัวคูณความเร็ว
6. **น่ารัก ไม่น่ากลัว** — ไม่มีเลือดหรือความรุนแรง ความเสียหายแสดงเป็น "โป๊ก!" + ดาวหมุน ล้มแล้ว "มึน" ไม่ใช่ "ตาย" (ข้อตัดสินใจของ Boss: กลุ่มเพื่อนทุกวัย)

---

## 1. Pitch

ทีมแฮมสเตอร์ 2–4 ตัวถูกลืมไว้ในครัวตอนดึก ขณะที่บ้านเจอภัยพิบัติที่สุ่มมา 1 แบบต่อรอบ ต้องแยกกันไปวิ่งวงล้อปั่นไฟ ลากถ่านก้อนยักษ์มาเสียบ แล้วกลับมา**ช่วยกันทั้งทีมพร้อมกัน**ส่งเสียงเรียกคนช่วยผ่านวิทยุของเล่นและปลดล็อกหน้าต่าง จากนั้นเอาตัวรอดบนขอบหน้าต่างระหว่างที่นักดับเพลิงหย่อนกรงสัตว์เลี้ยงลงมารับ ยิ่งช้าภัยยิ่งแรง และแฮมสเตอร์ที่มึนอยู่ลุกเองไม่ได้ ต้องให้เพื่อนกลับไปช่วย

| | |
|---|---|
| ผู้เล่นต่อ server | **2–4 คน** (`MAX_PLAYERS = 4`), 1 Match ต่อ server, **เริ่มได้เมื่อ ≥ 2 คนเท่านั้น (ไม่มี solo start — Boss ตัดสินแล้ว)** ยกเว้นใน Studio ที่ใช้ `DEV_MIN_PLAYERS_STUDIO = 1` เพื่อเทสต์ |
| ภัยพิบัติ | **สุ่ม 1 ภัยต่อรอบ** จากรายการของแมพ แล้วรุนแรงขึ้นตาม Stage (ข้อตัดสินใจของ Boss) |
| ความยาว Match | สูงสุด 7:00 โดยทีมปกติใช้ ~4:35–4:55, ทีมเก่ง ~3:05–3:30, ทีมช้า ~6:05 (ดู 2.3) **(รอ Boss ยืนยัน Q1-ข)** |
| หนึ่ง Round | ~6 นาที (Lobby 30s + Match ~5:00 + Result 15s) |
| Session เป้าหมาย | 4–5 Round ≈ 25–30 นาที |
| กลุ่มเป้าหมาย | กลุ่มเพื่อนทุกวัย, PC + มือถือ, ปุ่มน้อย (เดิน/กระโดด/วิ่ง/กดใช้/วางของ) |

### 1.1 โลก ตัวละคร และสเกล

- **ตัวละคร**: แฮมสเตอร์การ์ตูนตัวกลมยืนสองขา ใช้ `StarterCharacter` แบบ **R15 ขนาดมาตรฐานของ Roblox** (สูง ~5 studs) ใส่ mesh/accessory ให้เป็นแฮมสเตอร์ ความเร็วเดิน 16 / วิ่ง 24 studs/s เหมือนเดิม ตัวเลขระยะทางและ pacing ทั้งหมดในเอกสารจึงใช้ได้ตามเดิม
- **โลก**: สถานที่ของคนที่สร้างให้ใหญ่รอบตัวแฮมสเตอร์ ของใช้คนกลายเป็นภูมิประเทศ เช่น เคาน์เตอร์ = หน้าผา, ชั้นวาง = ชั้นของอาคาร, ผ้าม่าน = ที่ปีน, กระป๋อง = ก้อนหิน
- **สเกลมาตรฐาน: 1 cm ของคน = 0.5 studs (1 stud = 2 cm)** แฮมสเตอร์สูง 5 studs ≈ 10 cm (ตัวโตแบบการ์ตูน) ตัวอย่างขนาดสำหรับ Level/Art:

| ของจริง | ขนาดจริง | ในเกม (studs) |
|---|---|---|
| คนสูง | 170 cm | 85 |
| เพดานครัว | 250 cm | 125 |
| ประตู | 200 × 80 cm | 100 × 40 |
| เคาน์เตอร์ครัว | สูง 90 cm | +45 |
| เบาะเก้าอี้ | สูง 46 cm | +23 |
| ขอบหน้าต่างเหนือซิงก์ | สูง 122 cm | +61 |
| ถ่าน AA | 5 × 1.4 cm | 2.5 × 0.7 (ถือได้ด้วยมือเดียว) |
| แอปเปิล / กระป๋องซุป | 8 / 10 cm | 4 / 5 (debris) |
| ครัวทั้งห้อง | 4.0 × 3.2 m | 200 × 160 |

- **การนำเสนอแบบน่ารัก**: โดน damage = ดาวกระจาย "โป๊ก!" + เสียงร้องจี๊ด (ไม่มีจอแดงหรือเลือด), Downed = ม้วนตัวกลม มีดาวหมุนบนหัว (UI: "Dizzy!"), Eliminated = "ปุ๊ฟ" กลายเป็นกลุ่มขนฟู (UI: "Poofed!"), Respawn = โผล่ออกมาจากกองทิชชู่

---

## 2. Core loop

```
Lobby (30s) ──► Match (≤ 7:00) ─────────────────────────────────────────────────► Result (15s) ──► Lobby
                 Step 1 แยกกันทำ ─► Step 2 วิทยุพร้อมกัน ─► Step 3 สลักหน้าต่างพร้อมกัน ─► Extraction (ETA 60s + Departure 10s)
   ภัย 1 แบบ (สุ่ม):  Calm 0:00 ─ Warning 0:30 ─ Active 0:45 ──────────── Critical 3:30 (หรือทันทีที่ทางออกปลดล็อก) ── Collapse 7:00
```

### 2.1 Lobby
- Lobby คือ **"กรงแฮมสเตอร์ยักษ์"** (มีท่อ, วงล้อ, ชามเมล็ดทานตะวัน ให้เดินเล่นได้) อยู่ใน place เดียวกับแมพ แต่**ห่างจากแมพ 3,000 studs ทางแกน X** มีกำแพงล่องหน (CanCollide, Transparency 1) ทุกด้านรวมเพดาน ไม่มีทางเชื่อมกับแมพ hazard ทุกชนิดทำงานเฉพาะใน bounds ของแมพ
- `PlayerAdded` → server เรียก `LoadCharacter` ที่ Lobby ถ้าตัวละครใน Lobby หายหรือตาย ให้ `LoadCharacter` ใหม่หลัง 2s
- เมื่อ Lobby มีผู้เล่นที่**ไม่ AFK** ≥ `MIN_PLAYERS_TO_START` (2) คน → นับ Intermission 30s บน HUD ถ้าต่ำกว่า 2 → หยุดนับและแสดง "Waiting for players (1/2)" (Boss ตัดสินแล้ว: ไม่มี solo start) — ใน Studio ใช้ `DEV_MIN_PLAYERS_STUDIO` = 1 แทน (ไม่มีผลบน live)
- **AFK ใน Lobby**: ไม่มี activity ≥ 60s (วิธีตรวจดู 5.9) → ไม่ถูกส่งเข้า Match และไม่นับในเงื่อนไขเริ่ม HUD แสดง "AFK — move to join next match"
- ครบเวลา → server **สุ่มภัย 1 แบบ** จาก `MissionDef.disasters`, clone แมพจาก `ServerStorage.Maps.<MapId>` เข้า `Workspace.Map`, เรียก `LoadCharacter` ผู้เล่นที่ไม่ AFK แล้ว `PivotTo` ไปที่ spawn (5.4)
- ผู้เล่นที่เข้ามาระหว่าง Match รออยู่ใน Lobby จนถึง Round ถัดไป (HUD แสดงเวลาที่เหลือของ Match)

### 2.2 Match — timeline (ทีม 2 คน เล่นแบบ "typical")

> หัวข้อ 2.1–2.3 คือแมพเต็ม (หลังส่งงาน) เกมที่ส่งใช้ timeline 2 Step ใน 8.4–8.5

| เวลา | Stage | ระบบ | ผู้เล่น |
|---|---|---|---|
| 0:00–0:05 | Calm | Spawn ที่มุมกรงที่ล้มอยู่บนพื้นครัว, Briefing overlay (ชื่อ Mission + Step 1) เดินได้ทันที | อ่านเป้าหมาย แล้วแยกกันไป |
| 0:05–0:30 | Calm | ยังไม่มี hazard, marker ของ Step 1 แสดง | ตัวหนึ่งไปวิ่งวงล้อที่มุมซักผ้า อีกตัวค้นหาถ่าน |
| 0:30–0:45 | Warning | Banner ชื่อภัย + เสียงไซเรนข้างนอก + สัญญาณ visual (จานสั่น / น้ำซึมใต้เครื่องซักผ้า) ไม่มี damage | เร่งงาน วางแผนตามชนิดภัย |
| 0:45–~1:50 | Active | Hazard ระดับ 1 เริ่มทำ damage | ทำ Step 1 ต่อ: วิ่งวงล้อให้เสร็จ ค้นและส่งถ่าน ระหว่างหลบของตก ใครล้มก็ revive |
| ~1:50–~2:45 | Active | Step 2 เปิด: วิทยุของเล่นบนชั้นล่าง | **รวมตัว**: แต่ละตัวกดปุ่มพูดวิทยุคนละเครื่องพร้อมกัน สะสมให้ครบ 30s (ปล่อยหลบของตกแล้วกลับมากดต่อได้ ความคืบหน้าไม่หาย) |
| ~2:45–~3:25 | Active | Step 3 เปิด: สลักหน้าต่าง 4 อันบนเคาน์เตอร์ | **แยกไปสลักคนละอัน** กดค้างพร้อมกันต่อเนื่อง 5s |
| ~3:25 | → Critical | หน้าต่างปลดล็อก, Stage เป็น Critical (ถ้ายังไม่ถึง), เริ่ม ETA 60s | ปีนขึ้นขอบหน้าต่าง |
| ~3:25–~4:25 | Critical | Hazard สูงสุด รวมบนขอบหน้าต่างด้วย, Exit Zone ยังไม่นับ | **เอาตัวรอด 60s** และ revive กันบนขอบหน้าต่าง |
| ~4:25–~4:35 | Critical | กรงสัตว์เลี้ยงถูกหย่อนลงที่กระบะดอกไม้นอกหน้าต่าง, Exit Zone เปิด, Departure 10s เมื่อทุกตัวอยู่ในโซน | เข้ากรงให้ครบ |
| ≤ 7:00 | — | ชนะเมื่อ Departure ครบ / แพ้เมื่อ Collapse หรือ Wipe | — |

**หน้าต่างต้องปลดล็อกภายใน 5:50** ไม่เช่นนั้นกรงจะมาไม่ทันก่อน Collapse (7:00 − ETA 60s − Departure 10s) HUD จะเตือน "Last chance" ตอน 5:20 ถ้า Step 3 ยังไม่เสร็จ

### 2.3 Pacing budget

ใช้ความเร็วเดิน 16 studs/s (ไม่นับวิ่ง เพื่อเผื่อเวลา) ระยะเดินตาม 7.3 เวลา action ตามหัวข้อ 3 และ 9 (ระยะทุกตัวเป็น studs ของแฮมสเตอร์ขนาดมาตรฐาน)

#### ทีม 2 คน: ideal (เล่นถูกทางทุกอย่าง ไม่ล้ม)

| # | งาน | ผู้ทำ | ระยะเดิน (studs) | เดิน (s) | Action (s) | เริ่ม | เสร็จ |
|---|---|---|---|---|---|---|---|
| 0 | Briefing | ทั้งคู่ | — | — | 5 | 0:00 | 0:05 |
| 1 | `RunWheel` (Repair 45s คนเดียว) | P1 | Spawn→วงล้อ 110 | 7 | 45 | 0:05 | 0:57 |
| 2 | ถ่านก้อนที่ 1: เข้าโซน + ค้น + ถือไปแท่นชาร์จ | P2 | 60 + 120 + 60 | 15 | ค้น 10, หยิบ+เสียบ 3 | 0:05 | 0:33 |
| 3 | ถ่านก้อนที่ 2 (อีกโซน) | P2 | 60 + 120 + 60 | 15 | 13 | 0:33 | 1:01 |
| — | **Step 1 เสร็จ** | | | | | | **1:01** |
| 4 | `CallForHelp` (MultiHold Cumulative ต้อง 2 คน สะสม 30s) | ทั้งคู่ | วงล้อ→ชั้นล่าง 70 / แท่นชาร์จ→ชั้นล่าง 30 | 5 | รอกัน+เริ่มกด 1 + 30 | 1:01 | 1:37 |
| 5 | `WindowLatches` (MultiHold Continuous ต้อง 2 คน ต่อเนื่อง 5s) | ทั้งคู่ | ชั้นล่าง→สลักบนเคาน์เตอร์ 90–110 (ขึ้นบันไดม้านั่ง) | 7 | ประสานกัน 6 + 5 | 1:37 | 1:55 |
| 6 | Extraction ETA | ทั้งคู่ | สลัก→ขอบหน้าต่าง (ทางหลัก) 60 | (อยู่ใน ETA) | 60 | 1:55 | 2:55 |
| 7 | Departure | ทั้งคู่ | — | — | 10 | 2:55 | **3:05** |

#### Overhead บน critical path (ทีม "typical" = ผู้เล่นใหม่ถึงปานกลาง)

| Overhead | เหตุผล | 2 คน | 4 คน |
|---|---|---|---|
| ค้นหาไม่เป็นระบบ | ถ่านไม่มี marker ค้นช้ากว่า ideal +15s ต่อก้อน (ทีม 2 คน: 2 ก้อนบน critical path, ทีม 4 คน: 1 ก้อน) | +30s | +15s |
| ความเร็วลด + หลบวงเตือน | Pulse ×0.7 นาน 5s ทุก 20s ทำให้ช้าลง ~8–10% ในช่วง Active | +10s | +10s |
| ล้ม + revive | คาดว่าล้ม 2 ครั้ง (ทีม 2 คน) / 3 ครั้ง (ทีม 4 คน) ครั้งละ ~12s | +25s | +20s |
| ประสาน MultiHold | สื่อสาร, ปล่อยหลบแล้วกดใหม่, คันโยกหลุดแล้วต้องเริ่มนับใหม่ | +25s | +40s |
| **รวม** | | **+90s** | **+85s** |

#### สรุปเวลาจบ

| ทีม | ทางออกปลดล็อก | จบ Match | อยู่ใน Active ก่อนปลดล็อก |
|---|---|---|---|
| 2 คน ideal | 1:55 | 3:05 | 70s |
| 2 คน typical | ~3:25 | **~4:35** | ~160s |
| 3 คน typical | ~3:27 | ~4:37 | ~160s |
| 4 คน ideal | 2:19 | 3:29 | 94s |
| 4 คน typical | ~3:44 | **~4:54** | 165s แล้วต่อด้วย Critical ตามเวลาตั้งแต่ 3:30 |
| ทีมช้า (overhead ×2) | ~4:55 | ~6:05 | ทั้งหมด |
| ปลดล็อกหลัง 5:50 | — | **แพ้ (Collapse)** | — |

ทีม 4 คน ideal: 2 ตัววิ่งวงล้อพร้อมกัน (`maxStack` 2) เสร็จ ~0:35 ส่วนอีก 2 ตัวส่งถ่านคนละก้อนภายใน 0:37 ถ่านก้อนที่ 3–4 ใช้เวลาจนถึง ~1:11 (โซนที่ไกลที่สุด: แท่นชาร์จ→โซน B 110 + ค้น 120 + กลับ 110 = 340 studs ≈ 21s + 13s) วิทยุต้องกดครบ 4 เครื่อง (รวมตัว 8 + ประสาน 8 + 30) เสร็จ 1:57 สลัก 4 อัน (เดิน 7 + ประสาน 10 + 5) เสร็จ 2:19

**ผลที่ต้องการ:** ทุกทีม รวมทีมเก่ง ทำภารกิจใน Active ≥ 60s และเอาตัวรอดใน Critical ≥ 70s ระบบ Downed/Revive ถูกใช้ทุก Match QA ต้องวัดเวลาจริงเทียบตารางนี้ด้วยผู้เล่นจริง (8 DoD)

### 2.4 Result (15s)
- แสดง: ชนะ/แพ้ (และสาเหตุ: Escaped / Collapse / Wipe), ชื่อภัยที่สุ่มได้, เวลาที่ใช้, รายชื่อ Escaped, objective ที่แต่ละคนได้เครดิต, จำนวน revive, จำนวนครั้งที่มึน แฮมสเตอร์ที่หนีได้นั่งอยู่ในกรงและโบกมือ
- M2: แสดง Seeds ที่ได้ (หัวข้อ 6)
- จบ 15s → ทำลาย `Workspace.Map` และ instance ที่ spawn ใน Round ทั้งหมด, disconnect connection ของ Round, เรียก `LoadCharacter` ทุกคนที่ Lobby, เริ่ม Intermission ใหม่

---

## 3. Mission structure

### 3.1 โครงสร้าง
```
Mission
 ├─ Step 1  [Objective A, Objective B]   ← ทำคู่ขนานได้ ต้องเสร็จทุกอันที่ไม่ optional
 ├─ Step 2  [Objective C]
 ├─ Step 3  [Objective D]
 └─ Extraction: ปลดล็อก LockedDoor ที่ UnlockedBy = exitFlag → ETA (exitArrivalDelay) → ยานมาถึง → Exit Zone เปิด → Departure
```
- Objective ใน Step ที่ยังไม่เปิด: prompt `Enabled = false`, ไม่มี marker, HUD แสดงเป็น "Locked"
- Objective ที่เสร็จแล้วไม่ย้อนกลับ
- Step เสร็จ → server เปิด Step ถัดไปใน tick เดียวกัน พร้อมเสียงและ Banner สั้น "Step complete"

### 3.2 ชนิดของ Objective

| Kind | ทำอย่างไร | บังคับ co-op? | บังคับอย่างไร | M1 |
|---|---|---|---|---|
| `Repair` | กดค้างที่ anchor จน progress เต็ม | ไม่บังคับ (2 คนเร็วขึ้น 2 เท่า) | — | IN |
| `Deliver` | หาของที่ spawn แบบสุ่มแล้วถือไปเสียบ socket จำนวนของขยายตาม `teamCount` | ไม่บังคับ (แต่งานขยายตามจำนวนคน) | ถือได้ทีละ 1 ชิ้น → ต้องแยกกันไปหา | IN |
| `MultiHold` | มี anchor หลายอันห่างกัน ต้องมี**ผู้เล่นต่างคนกัน**จับ anchor ต่างอันพร้อมกันให้ครบ `required` คน มี 2 โหมด: **Cumulative** (progress สะสม หยุดเมื่อคนไม่ครบแต่ไม่หาย) และ **Continuous** (ต้องครบต่อเนื่อง หลุดแล้วรีเซ็ต) | **บังคับ** | `required` ขยายตามจำนวนผู้เล่นที่ยังไม่ Eliminated (3.4), server ให้ 1 คนจับได้ไม่เกิน 1 anchor, anchor อยู่ห่างกันเกินระยะ interact | IN |
| `HeavyCarry` | ของมี 2 ที่จับ ต้องมี 2 คนจับพร้อมกันจึงเคลื่อนได้ | **บังคับ** | จับข้างเดียว → ของไม่ขยับ, ห่างกัน > 12 studs หรือมีคนล้ม → ของตก | M2 |
| `Rescue` | ตัวหนึ่งจับงัดสิ่งของที่ทับอยู่ (hold ต่อเนื่อง) อีกตัวดึง NPC ออก (hold 2s เปิดเฉพาะตอนมีคนงัด) แล้ว NPC เดินตามไป Exit Zone | **บังคับ** | prompt ดึงปิดถ้าไม่มีคนงัด, server ปฏิเสธถ้าคนดึงเป็นคนเดียวกับคนงัด | M2 (bonus) |

Co-op ที่บังคับนอกเหนือจาก objective:
- **Downed/Revive**: มึนแล้วลุกเองไม่ได้ (5.3) และ MultiHold นับคนที่ Downed ด้วย ทีมจึงต้องไป revive ก่อน หรือรอให้ override ช่วยหลัง 75s (3.4)
- **Departure ต้องอยู่ครบทีม** (5.8) **(รอ Boss ยืนยัน Q2)**

### 3.3 Server-timed hold (ใช้กับทุก interaction ที่ต้องกดค้าง)

ใช้กลไกเดียวทั้งเกม: `Repair`, `MultiHold`, Revive, Rescue (งัด/ดึง), Suppress (M2)

- `ProximityPrompt` ใช้ **Style = Default** และ `HoldDuration = 0`
- Server ถือว่า `Triggered(player)` = **เริ่มจับ** และ `TriggerEnded(player)` = **ปล่อย**
- Server เก็บ holder set ของแต่ละ anchor และใช้กฎ **1 ผู้เล่นอยู่ใน holder set ได้ไม่เกิน 1 anchor ทั้งแมพ** ถ้าเริ่มจับ anchor ใหม่ จะถูกถอดออกจาก anchor เดิมก่อน
- ทุก `HOLD_TICK` (0.1s) server ตรวจ holder แต่ละคนว่ายัง Standing, ไม่ Inactive และระยะ HRP ถึง anchor ≤ `INTERACT_SERVER_RANGE` (10 studs) ถ้าไม่ผ่าน → ถอดออก (ผู้เล่นต้องกดใหม่)
- Tick ทำงานเฉพาะตอนที่มี holder ≥ 1 คนทั้งแมพ (ไม่มี loop ถาวร)
- Progress เก็บใน Attribute บน anchor model: `Progress` (0–1) และสำหรับ MultiHold: `Held`, `Required`, `Override` (bool)
- Client แสดง progress ด้วย BillboardGui ที่อ่านจาก Attribute ส่วน prompt แบบ Default ใช้ได้ทั้งคีย์บอร์ด, gamepad และการแตะบนมือถือ
- เวลา hold ทั้งหมดจับจาก tick ฝั่ง server การยิง `Triggered` ปลอมจึงไม่ทำให้สำเร็จเร็วขึ้น
- QA ต้องเทสต์ว่า `TriggerEnded` ยิงเมื่อเดินออกนอกระยะหรือ prompt ถูกปิด (ถ้าไม่ยิง server tick ยังถอดออกตามระยะอยู่)
- ภาพบน client: ระหว่างกดค้าง ตัวละครเล่น animation ตาม `HoldAnim` ของ ObjectiveDef (เช่น วิ่งในวงล้อ, ร้องใส่วิทยุ, ดันสลัก)

### 3.4 สเปกต่อชนิด

#### `Repair`
| พารามิเตอร์ | ค่า | หมายเหตุ |
|---|---|---|
| `duration` | 45s (คนเดียว) | ต่อ objective ใน data |
| อัตรา | +1/duration ต่อ holder ที่ถูกนับ ต่อวินาที | |
| `maxStack` | 2 | holder ที่ถูกนับคือ `maxStack` คนแรกตามลำดับที่เริ่มจับ คนที่ 3 ไม่ช่วยและไม่ได้เครดิต จนกว่าจะมีคนปล่อย |
| `submergedRateMult` | 0.5 (วงล้อ) | ใช้เมื่อ `PromptPart` อยู่ใน volume ที่ทำให้เกิด status `Submerged` (4.2) ค่า default = 1 |
| ปล่อยมือ | progress คงอยู่ | |
| เครดิต | ทุก tick แบ่ง progress ให้ holder ที่ถูกนับเท่าๆ กัน ได้เครดิตเมื่อสะสม ≥ 25% | |
| ทางเลือกถ้า playtest พบว่าน่าเบื่อ | แบ่งเป็น 2 objective `Repair` เครื่องละ 22s อยู่คนละโซน (แก้แค่ data) | ดู DoD |

#### `Deliver`
- ตอนเริ่ม Match: `count = clamp(teamCount, params.minCount, params.maxCount)` (แมพ #1: 1–4 คือเท่ากับจำนวนคน) เลือก `ItemSpawn` ที่ `ItemType` ตรงกัน **โซนละไม่เกิน 1 จุด** (Attribute `Zone`) แบบสุ่ม แล้ว spawn item และจำ `ItemSpawn` นั้นเป็น "จุดเกิดเดิม" ของ item
- ถ้า `teamCount` ลดลงระหว่าง Match: จำนวนที่ต้องส่ง = `max(ส่งแล้ว, min(count เดิม, max(1, teamCount)))` ลดได้อย่างเดียว ไม่เพิ่ม **item ส่วนเกินที่ต้องลบ**: ลบอันที่ไม่มีใครถือ โดยลบอันที่ยังไม่เคยถูกหยิบก่อน ถ้าทุกอันมีคนถืออยู่ จะลบอันแรกที่ถูกวางลง
- หยิบ: prompt กดครั้งเดียว (`HoldDuration 0`) ระยะ 8 studs → server สร้าง weld ที่ RightHand (item ตั้ง `Massless`, `CanCollide = false`)
- Socket: prompt "Insert" แสดงเฉพาะกับผู้ที่ถือ item ชนิดที่ถูก กดครั้งเดียว → item หาย, `Delivered +1` socket แสดง "x / N" ทั้งบน Billboard และ HUD
- **การค้นหา**: item ไม่มี marker บน HUD แต่มี PointLight กะพริบ + เสียง loop ที่ได้ยินในระยะ 30 studs (`RollOffMaxDistance = 30`)
- เครดิต: คนที่หยิบครั้งแรก + คนที่เสียบ
- การกู้คืน item: ดู 5.7

#### `MultiHold`
| พารามิเตอร์ | ความหมาย | `CallForHelp` | `WindowLatches` |
|---|---|---|---|
| `anchorCount` | จำนวน anchor (Attribute `Part` = "A".."D") | 4 | 4 |
| `mode` | `Cumulative` / `Continuous` | Cumulative | Continuous |
| `holdTime` | วินาทีที่ต้องครบ | 30 (สะสม) | 5 (ต่อเนื่อง) |
| `assist` | เปิดใช้ Emergency override | true | true |

**คำนวณ `required`** (ทุก tick ที่ไม่ได้ล็อก):
1. `baseRequired = min(anchorCount, activeCount)` โดย `activeCount` = team member ที่**ไม่ Eliminated** คนที่ Downed **ยังนับ** (ทีมจึงยังต้องไป revive) แต่คนที่ไม่มีตัวละคร (รอ respawn), Inactive หรือออกจากเกมแล้วไม่นับ
2. **Emergency override**: ถ้า Step นี้เปิดมาแล้ว ≥ `MULTIHOLD_ASSIST_AFTER` (75s) และ `baseRequired ≥ 3` → `required = baseRequired − 1` (ต่ำสุด `MULTIHOLD_ASSIST_MIN` = 2) ตั้ง Attribute `Override = true` และ HUD/Billboard แสดง "Override engaged — 3 of 4 needed" ถ้าไม่เข้าเงื่อนไข `required = baseRequired`
3. `activeCount = 1` → `required = 1` (solo fallback, 3.5)
4. **`required = max(1, …)` เสมอ** (ถ้า `activeCount = 0` เช่นทุกคนรอ respawn → required = 1 ห้ามเป็น 0)

- **นับว่าครบ** เมื่อจำนวน anchor ที่มี holder ≥ `required` (กฎ 1 คน/1 anchor ทำให้เท่ากับจำนวนคนที่ต่างกัน)
- **Cumulative**: ทุก tick ที่ครบ → `Progress += tick/holdTime` ถ้าไม่ครบ → หยุด ไม่ลด `required` คำนวณใหม่ทุก tick
- **Continuous**: ตอนเริ่มครบ → **ล็อก** `lockedRequired = required` แล้วเริ่มนับ ระหว่างนับจะ**รีเซ็ต (Progress = 0) เฉพาะเมื่อ `Held < lockedRequired`** ถ้า `teamCount`/`activeCount` เปลี่ยนแต่ยังจับครบตามที่ล็อกไว้ ให้นับต่อ หลังรีเซ็ต ปลดล็อกแล้วคำนวณ `required` ใหม่
- HUD/Billboard บนทุก anchor: "Held 2 / 3" + สถานะแต่ละ anchor (ว่าง / มีคนจับ) + progress
- กฎแมพ: anchor ทุกคู่ห่างกันเป็นเส้นตรง ≥ 30 studs (มากกว่า 3 เท่าของระยะ interact ฝั่ง server) สำหรับ Continuous แนะนำให้มองไม่เห็นกันทั้งหมด (ต้องสื่อสารกัน)
- เครดิต: holder ทุกคนในช่วงที่ progress เดิน

#### `HeavyCarry` (M2) — ตัวอย่างธีม: ถ่าน 9V ก้อนยักษ์, ขนมปังกรอบ
- Item มี 2 ที่จับ แต่ละข้างมี prompt "Grab" (กดครั้งเดียว) ผู้เล่นถือได้ทีละ 1 อย่าง
- จับครบ 2 คน → server วาง CFrame ของ item (anchored ไม่ใช้ฟิสิกส์) ไว้ที่จุดกึ่งกลางของทั้งสองทุก 0.1s และตั้ง `MoveMode = HeavyCarry` ให้ทั้งคู่ (10 studs/s วิ่งไม่ได้)
- ห่างกัน > 12 studs, คนใดกด Drop, ล้ม หรือออกจากเกม → item วางลงพื้น (ตามกฎการวาง 5.7)
- ส่งสำเร็จเมื่อจุดกึ่งกลาง item อยู่ใน 6 studs ของเป้าหมาย solo fallback: คนเดียวยกได้ที่ 8 studs/s

#### `Rescue` (M2, `optional = true`) — ตัวอย่างธีม: ลูกแฮมสเตอร์ติดใต้ตะแกรงคว่ำ
- งัด: server-timed hold ที่สิ่งของที่ทับ (ต่อเนื่อง ไม่มีเวลาสิ้นสุด) ดึง: server-timed hold 2s เปิดเฉพาะตอนที่มีคนงัดอยู่ และคนดึงต้องไม่ใช่คนงัด
- NPC เดินตามคนที่ดึงด้วยความเร็ว 14 studs/s, HP 60, โดน hazard ได้, HP 0 → Downed (revive ได้แบบผู้เล่น) ถ้า NPC อยู่ใน Exit Zone ตอน Departure จบ = ได้ bonus
- Solo fallback: ปล่อยการงัดแล้วสิ่งของค้างอยู่ 3s ให้คนเดียวดึงได้

### 3.5 Solo fallback
- เกิดเมื่อ `activeCount = 1` (เพื่อนออก, Inactive หรือรอ respawn) หรือเทสต์ใน Studio คนเดียวด้วย `DEV_MIN_PLAYERS_STUDIO = 1` (fallback นี้คือการรับมือเมื่อเพื่อนออกกลาง Match ไม่ใช่โหมดเล่นคนเดียว: Match เริ่มได้เมื่อ ≥ 2 คนเสมอบน live)
- `MultiHold`: required = 1 อัตโนมัติ ถ้ากำลังนับ Continuous อยู่และ `Held` ต่ำกว่าค่าที่ล็อก → รีเซ็ตตามกฎ 3.4 แล้วเริ่มใหม่ด้วย required = 1
- `Deliver`: จำนวนลดตามสูตรใน 3.4
- `HeavyCarry` / `Rescue`: ตาม 3.4
- เมื่อ `teamCount = 1` (เหลือคนเดียวจริงๆ): ล้ม = Eliminated ทันที (ไม่มีใคร revive ได้) และ**ไม่มี Team Wipe** → respawn ตามปกติ

### 3.6 Data definitions (ฟิลด์ ไม่ใช่โค้ด)

**ObjectiveDef**
| ฟิลด์ | ชนิด | ตัวอย่าง |
|---|---|---|
| `id` | string | `"RunWheel"` (ตรงกับ Attribute `ObjectiveId` บนแมพ) |
| `kind` | enum | `Repair` / `Deliver` / `MultiHold` / `HeavyCarry` / `Rescue` |
| `displayName` | string key | `"obj.run_wheel"` |
| `params` | table | Repair `{duration=45, maxStack=2}`, Deliver `{itemType="Battery", minCount=1, maxCount=4}`, MultiHold `{anchorCount=4, mode="Cumulative", holdTime=30, assist=true}` |
| `holdAnim` | string | `"RunInWheel"` (ชื่อ animation ใน Assets) |
| `submergedRateMult` | number | 1 (default) |
| `optional` | bool | false |

**MissionDef**
| ฟิลด์ | ตัวอย่าง |
|---|---|
| `id`, `mapId` | `"MidnightKitchen_CallForHelp"`, `"MidnightKitchen"` |
| `steps` | array ของ `{ id, displayName, objectives = {ObjectiveDef...} }` |
| `exitFlag` | `"WindowOpen"` |
| `exitArrivalDelay` | 60 (s) |
| `exitVehicleAsset` | `"RescueCarrier"` (ชื่อใน `ReplicatedStorage.Assets`) |
| `disasters` | `{"Earthquake","Flood"}` — **สุ่ม 1 ภัยต่อรอบ** |

**ItemDef**: `id`, `displayName`, `size` (`Small`/`Heavy`), `model`, `ability` (optional เช่น `SuppressZone` ใน M2)

---

## 4. Disaster system

**กฎหลัก (ข้อตัดสินใจของ Boss): สุ่ม 1 ภัยต่อรอบ** ตอนเริ่ม Match จาก `MissionDef.disasters` (สุ่มแบบเท่ากัน และห้ามได้ภัยเดิมซ้ำ 2 รอบติดกันถ้ารายการมี ≥ 2 แบบ) ภัยนั้นอยู่ตลอด Match และรุนแรงขึ้นตาม Stage ไม่มีภัยที่สองซ้อนเข้ามา

### 4.1 Stages

Stage เดินตามเวลาของ Match โดยมีกฎความคืบหน้าข้อเดียว: **เมื่อทางออกปลดล็อก (Step สุดท้ายเสร็จ) ถ้า Stage ยังต่ำกว่า Critical ให้เข้า Critical ทันที** (`EXIT_UNLOCK_FORCES_CRITICAL = true`) ช่วง Extraction จึงอยู่ใน Critical เสมอ

| Stage | เวลาเริ่ม (default) | ยาว | Hazard | Lighting/Audio (client) | HUD |
|---|---|---|---|---|---|
| Calm | 0:00 | 30s | ไม่มี | ครัวตอนดึก แสงจันทร์จากหน้าต่าง | ตัวบอก Stage สีเขียว + timer ถึง Collapse |
| Warning | 0:30 | 15s | visual อย่างเดียว ไม่มี damage | โทนส้ม, ไซเรนข้างนอก 1 ครั้ง, เสียง ambience ของภัย | Banner 3s: ชื่อภัย + คำแนะนำ 1 บรรทัด, สีเหลือง |
| Active | 0:45 | 165s | hazard ระดับ 1 | ไฟกะพริบเป็นช่วง | สีส้ม |
| Critical | 3:30 หรือตอนที่ทางออกปลดล็อก | ถึง 7:00 | hazard ระดับ 2 | แสงไฟฉายของนักดับเพลิงกวาดผ่านหน้าต่าง, alarm loop | สีแดง, timer กะพริบเมื่อเหลือ < 30s |
| Collapse | 7:00 | — | จบ Match | fade ดำ + เสียงถล่ม/น้ำซัด | ไป Result |

**กฎการข้าม Stage (fast-forward)** ใช้เมื่อกฎความคืบหน้าทำให้ข้ามมากกว่า 1 ขั้น (แมพ #1 เกิดไม่ได้จริง แต่ต้องรองรับสำหรับแมพอื่นและ DEV):
1. รัน **on-enter** ของทุก Stage ที่ถูกข้ามตามลำดับใน tick เดียวกัน
2. Hazard ที่เป็นจังหวะของ Stage ที่ถูกข้าม **ไม่ทำงาน**
3. Lighting/Audio ไปที่ preset ของ Stage ปลายทางทันที
4. **Banner ชื่อภัยต้องแสดง ≥ 3s เสมอ** ถ้ายังไม่เคยแสดงใน Match นี้

**StageDef** (global, DisasterDef override ได้): `id`, `duration`, `lightingPreset`, `audioPreset`, `uiColor`

### 4.2 Hazard components (โค้ดเขียนครั้งเดียว ใช้ทุกธีม)

| Component | ทำอะไร | พารามิเตอร์หลัก | ฝั่ง |
|---|---|---|---|
| `Pulse` | เหตุการณ์เป็นจังหวะ: เริ่มหลังเข้า Stage `firstDelay` s แล้วเกิดทุก `interval` s นาน `duration` s ระหว่าง pulse จะเปิด component ลูก | firstDelay, interval, duration, children | Server คุมจังหวะ, client ทำ shake |
| `TelegraphedImpact` | สุ่มจุดตก → วงเตือนบนพื้น `telegraph` s → ตรวจ hit → วาง prop ค้างไว้ `lifetime` s (กฎละเอียดด้านล่าง) | rate, countFormula, radius, damage, telegraph, lifetime, targeting (`NearPlayer` / `RandomPoint` / `ExposedPlayer`), minDist, maxDist, propCollides, propPool | Server ตัดสิน, client ทำ VFX |
| `RisingVolume` | Volume ที่ผิวบนสูงขึ้นตาม `riseRate` ของแต่ละ Stage จาก `startLevel` ถึง `maxLevel` (อ้างอิง tag `VolumeLevel`) และให้ status effect กับผู้เล่นที่อยู่ข้างใน | startLevel, maxLevel, riseRate {Stage→studs/s}, inEffect, submergedEffect | Server คำนวณ `SurfaceY`, client tween ภาพ |
| `SpreadingZone` | `SpreadNode` ที่ active ลามไป node ข้างเคียงทุก `spreadInterval` ยืนใน node ที่ active โดน dps | startNodes, spreadInterval, neighborRange, dps, maxActiveRatio | Server |
| `PushForce` | ผลักผู้เล่นตามแนวนอนในทิศที่กำหนด ยกเว้นคนที่อยู่ใน `SafeZone` | direction, speed, interval, duration | Server |
| `MovingVortex` | entity เคลื่อนตาม `VortexPath` ดูดผู้เล่นในรัศมี ใจกลางเหวี่ยง + damage | speed, pullRadius, pullSpeed, coreRadius, damage, cooldown | Server |
| `MoveModifier` | เพิ่มตัวคูณความเร็วให้ผู้เล่นทุกคน (ใช้ใต้ Pulse) | multiplier | Server (ผ่าน `SpeedMult`, 5.5) |
| `RouteCollapse` | สลับ `CollapseGroup` (Before → After) หลังเข้า Stage ที่ระบุ + `delay` พร้อม telegraph | groupId, stage, delay, telegraph | Server |
| `ScreenEffect` | camera shake, fog, flicker, tint (ภาพอย่างเดียว) | type, intensity | Client |

**Status effects แบบ generic** (โค้ดรู้จักชื่อเหล่านี้ แต่ไม่รู้จัก "น้ำ"):
| Effect | ผล | ใครให้ |
|---|---|---|
| `Slowed` | คูณ `SpeedMult` และตั้ง `CanSprint = false` ตามพารามิเตอร์ | RisingVolume (inEffect), MoveModifier |
| `Submerged` | นับ Breath ถอยหลัง หมดแล้วโดน dps, bleed-out ของ Downed × `downedBleedMult`, objective ที่ anchor อยู่ใน volume ใช้ `submergedRateMult` | RisingVolume (submergedEffect) |
| `Burning` (M2) | dps | SpreadingZone |

Query ที่ระบบอื่นใช้: `isPointHazardous(position)` คืนค่า true ถ้าจุดนั้นอยู่ใน volume ที่ทำ damage หรือ Submerged, อยู่ใน SpreadNode ที่ active หรืออยู่ใน bounds ของ CollapseGroup ที่กำลัง telegraph/สลับแล้ว ระบบที่ใช้คือ respawn selector (5.4) และการวาง/กู้คืน item (5.7)

#### Volume ที่ควบคุม impact (2 tag แยกกัน)
| Tag | ความหมาย | วางที่ไหน |
|---|---|---|
| `NoBlockingProp` | impact **ยังตกและทำ damage ได้** แต่ไม่วาง prop ที่ขวางทาง (prop ถูกข้ามไป หรือเป็น VFX ที่หายไปทันที) | รอบ anchor/socket รัศมี 4, บันได/ทางปีน, ช่องประตู/หน้าต่าง, ทางเดินแคบ |
| `NoImpact` | ห้ามมี impact ตกเลย | รัศมี 6 studs รอบ `PlayerSpawn` **ที่ไม่มี `EnabledBy`** และ Exit Zone **หลังจากยานมาถึงแล้ว** (server ถือว่า Part ที่มี tag `ExitZone` และ Attribute `Open = true` เป็น NoImpact โดยอัตโนมัติ) |

#### กฎ `TelegraphedImpact` (floor-aware)
1. **เลือกตำแหน่งแนวนอน**: สุ่มรอบเป้าหมายในระยะ `minDist`–`maxDist`
2. **หาพื้น**: raycast ลงจาก (Y ของเท้าเป้าหมาย + 6) ระยะ 20 studs (ไม่ชนผู้เล่น, item, debris) ต้องเจอพื้นที่ `|ΔY| ≤ 4` เทียบกับพื้นใต้เท้าเป้าหมาย และจุดนั้นต้องไม่อยู่ใน `NoImpact`
3. ไม่ผ่าน → สุ่มใหม่ สูงสุด 5 ครั้ง แล้วข้าม (ไม่ตก)
4. **Hit check** หลัง telegraph: ผู้เล่น Standing ที่ระยะแนวนอน ≤ `radius` **และ** `|ΔY| ≤ 6` (Y เท้าผู้เล่นเทียบจุดตก) → damage + "โป๊ก!"
5. **Prop**: สุ่มจาก `propPool` ถ้าจุดตกอยู่ใน `NoBlockingProp` → ไม่วาง prop ถ้า `propCollides = true` server ตรวจ `GetPartsInPart` ตอนวาง ถ้าทับ character → prop นั้นอยู่ใน CollisionGroup `DebrisNoPlayer` (ไม่ชนผู้เล่น ภาพยังเหมือนเดิม) ไม่เช่นนั้นอยู่ใน `Debris` (ชนผู้เล่น) prop ทั้งหมด anchored
6. `ExposedPlayer`: เป็นเป้าเฉพาะผู้เล่นที่ raycast ขึ้นไป 60 studs แล้วไม่ชนอะไร (ใช้กับฟ้าผ่ากลางแจ้ง)
7. ภาพ: prop ตกลงมาจากด้านบน (เริ่มที่ +30 studs) และถึงพื้นพอดีตอน telegraph จบ (client tween)

#### กฎ `RouteCollapse`
1. เมื่อถึงเวลา (เข้า `stage` + `delay`) → **telegraph 3s**: shake เฉพาะจุด, เสียงลั่นเอี๊ยด, ฝุ่นที่ `Before`, Billboard "!" บน group
2. สลับ: ซ่อน `Before` (CanCollide false, Transparency 1) แล้วแสดง `After`
3. ตอนสลับ server ตรวจ `GetPartsInPart` ของทุก Part ใน `After` เทียบกับ HRP ผู้เล่นและ item ผู้เล่นที่ทับ → `PivotTo` ไปที่ `RecoveryPoint` ที่ใกล้ที่สุด (ตั้ง `ForcedMoveUntil` ด้วย ดู 5.5) item ที่ทับ → กู้คืนตาม 5.7
4. กฎแมพ: ห้ามมี anchor, socket, ItemSpawn, PlayerSpawn, Exit Zone อยู่ใน bounds ของ CollapseGroup และต้องมีเส้นทางไป Exit Zone อย่างน้อย 1 เส้นที่ไม่ผ่าน CollapseGroup เลย

**DisasterDef**
| ฟิลด์ | ตัวอย่าง |
|---|---|
| `id` | `"Earthquake"` |
| `displayName`, `warningText` | `"EARTHQUAKE!"`, `"Watch for red circles — things will fall!"` |
| `stages` | `{ Warning = {components...}, Active = {...}, Critical = {...} }` |
| `stageOverrides` | (optional) duration ของ Stage |
| `audio`, `vfx`, `propPool` | ชื่อ asset |

### 4.3 ภัยพิบัติ Theme A (ภาพที่สเกลแฮมสเตอร์)

#### 4.3.1 Earthquake — แผ่นดินไหว (M1)
**ภาพ**: บ้านทั้งหลังสั่น ของบนชั้นและเคาน์เตอร์ร่วงลงมาใส่แฮมสเตอร์ (แอปเปิล, กระป๋องซุป, ฟองน้ำ, ช้อน, กล่องนม) จานบนชั้นกระทบกันเสียงดัง กล่องซีเรียลที่ซ้อนกันล้ม และที่คว่ำจานไถลล้ม
**แนวคิด**: "บ้านสั่น = ดูวงแดง" ให้เรียนรู้จังหวะแล้วหลบ

| Stage | Components |
|---|---|
| Warning | `Pulse` 1 ครั้ง (firstDelay 0, duration 3s): `MoveModifier` ×0.85, `ScreenEffect` shake เบา, จานสั่นและเศษขนมปังตก (visual) |
| Active | `Pulse` firstDelay 5s, interval 20s, duration 5s → ลูก: `MoveModifier` ×0.7, shake กลาง, `TelegraphedImpact` (`NearPlayer`, ทุก 1.0s, จำนวน `ceil(standingPlayers/2)`, ระยะ 3–10, telegraph 1.5s, radius 5, damage 30, prop ค้าง 6s, `propCollides = true`, propPool: แอปเปิล/กระป๋อง/ฟองน้ำ) และ `RouteCollapse` groupId `"CerealTower"` delay 30s (**M1-stretch**) |
| Critical | `Pulse` firstDelay 2s, interval 12s, duration 7s → `MoveModifier` ×0.6, shake แรง, `TelegraphedImpact` ทุก 0.7s, telegraph 1.2s, damage 30 และ `RouteCollapse` groupId `"DishRack"` delay 40s (**M1-stretch**) |

- `DishRack` (ที่คว่ำจานซึ่งเป็นบันไดหลักจากเคาน์เตอร์ขึ้นขอบหน้าต่าง) ล้มที่ Critical + 40s ทีมที่เพิ่งปลดล็อกหน้าต่าง (ซึ่งทำให้เข้า Critical) มีเวลา 40s ปีนทางหลัก (~60 studs ≈ 4s) ส่วนคนที่ respawn หรือมาช้าต้องปีนผ้าม่าน ทีมที่ช้าจนเข้า Critical ตามเวลา (3:30) จะเสียทางหลักตอน 4:10
- ของที่ตกไม่ทำลาย objective บันได/ทางปีน/ช่องหน้าต่าง และรอบ anchor เป็น `NoBlockingProp` คือของยังตกใส่และทำ damage ได้ แต่ไม่ค้างขวางทาง **QA ต้องเทสต์โดยยืนบนบันไดม้านั่งและที่คว่ำจานในช่วง Critical แล้วต้องโดน impact**

#### 4.3.2 Flood — น้ำท่วม (**M1-stretch**)
**ภาพ**: สายน้ำเข้าเครื่องซักผ้าแตก น้ำพุ่งออกมาท่วมมุมซักผ้าที่อยู่ต่ำกว่าพื้นครัวหนึ่งขั้นก่อน แล้วค่อยๆ ท่วมทั้งพื้นครัว ของลอยน้ำได้ (จุกขวด, ฟองน้ำ) ช่วง Critical เพดานรั่วเพราะพายุข้างนอก หยดน้ำยักษ์ตกลงมา
**แนวคิด**: "ข้างล่างมีเวลาจำกัด" ทำงานจากล่างขึ้นบน

`RisingVolume`: `startLevel = 0`, `maxLevel = 3`, `riseRate` = Warning 0 (มีแค่แอ่งน้ำบางๆ ที่ Level 0 เพื่อเตือน ไม่มีผล), Active 0.067, Critical 0.067 studs/s
- Server คำนวณ `SurfaceY = min(maxY, startY + Σ(riseRate × เวลาที่อยู่ในแต่ละ Stage))` แล้วตั้ง Attribute `SurfaceY` บน volume (อัปเดตทุก 1s) → client tween Part น้ำ (โปร่งใส, CanCollide false, ไม่ใช่ Terrain water, ว่ายน้ำไม่ได้) ขนาดเท่ากับพื้นที่ของแมพเท่านั้น
- ตรวจผู้เล่นทุก 0.25s จาก `SurfaceY` (ไม่ใช้ touch):
  - `SurfaceY ≥ เท้า + 1.5` → `Slowed` (×0.6 วิ่งไม่ได้)
  - `SurfaceY ≥ ยอดหัว` → `Submerged`: Breath 8s (แสดงบน HUD เป็นฟองอากาศ) หมดแล้วโดน 10 dps ขึ้นพ้นน้ำแล้ว Breath เต็มทันที Downed bleed-out เร็วขึ้น ×2
- Critical เพิ่ม `TelegraphedImpact` "หยดน้ำจากเพดาน" (`NearPlayer`, ทุก 3s, telegraph 1.5s, radius 4, damage 20, ไม่มี prop) ช่วงรอยานบนขอบหน้าต่างซึ่งน้ำท่วมไม่ถึงจึงยังมีความตึง

ระดับอ้างอิงแมพ #1 (Y เทียบพื้นครัว = 0, แฮมสเตอร์สูง ~5.5)
สูตร: เวลา = 0:45 + (SurfaceY − (−3)) / 0.067 วินาที

| เหตุการณ์ | SurfaceY | เวลาโดยประมาณ |
|---|---|---|
| เริ่ม Active (Level 0 = พื้นมุมซักผ้า) | −3 | 0:45 |
| มุมซักผ้า: ลุยน้ำ (Slowed) | −1.5 | ~1:07 |
| มุมซักผ้า: `PromptPart` ของวงล้อ (สูงจากพื้น 2) จมน้ำ → วิ่งได้ช้าลง ×0.5 | −1 | ~1:15 |
| มุมซักผ้า: มิดหัว | +2.5 | ~2:07 |
| แท่นชาร์จ (+4) จมน้ำ (ยังเสียบได้ตามปกติ) | +4 | ~2:29 |
| พื้นครัว: มิดหัว / วิทยุบนชั้นล่าง (+4): ลุยน้ำ | +5.5 | ~2:52 |
| ชั้นล่าง: มิดหัว | +9.5 | ~3:52 |
| Level 3 (สูงสุด) | +19 | ~6:13 |
| เบาะเก้าอี้ (+23), เคาน์เตอร์ (+45), ขอบหน้าต่าง (+61) | ไม่ท่วม | — |

ทีม typical วิ่งวงล้อเสร็จ ~1:00–1:20 (ถ้าช้าเกิน 1:15 จะโดน ×0.5 ช่วงท้าย) และกดวิทยุเสร็จ ~2:45 ก่อนชั้นล่างจมมิด จึงตึงแต่ไม่ softlock (ทุก objective ทำใต้น้ำได้) หลังพื้นท่วม คนที่ respawn จะเกิดบนเคาน์เตอร์ (5.4)

#### 4.3.3 Wildfire — ไฟไหม้ (M2)
**ภาพ**: เครื่องปิ้งขนมปังช็อตเป็นประกายไฟ ไฟลามไปตามผ้าเช็ดจานและกล่องกระดาษบนเคาน์เตอร์ ควันเป็นการ์ตูนนุ่มๆ สีเทา (ไม่น่ากลัว)
- แมพมี `SpreadNode` (volume ~12×12) และ Attribute `StartNode = true` ที่จุดเริ่ม
- Warning: ควันออกจาก start nodes (visual)
- Active: จุด 2 start nodes, `SpreadingZone` ทุก 12s (node ที่ active จุด node ข้างเคียงในระยะ ≤ 16 studs ที่ยังไม่ active 1 node), status `Burning` 15 dps, fog ใกล้ node (client)
- Critical: ลามทุก 6s, 20 dps, node ที่ active ได้ไม่เกิน 60%
- ตอบโต้: item ability `SuppressZone` (ใน data คือ "Spray bottle" ขวดฉีดน้ำต้นไม้: Small, 3 charges) ใช้ server-timed hold 2s ขณะยืนใน/ติด node → ดับ node นั้น และ node กันไฟลาม 30s
- Node ที่มี `NoSpread` (รอบ anchor/socket/Exit Zone/ผ้าม่านที่เป็นทางสำรอง) ไม่ติดไฟ

#### 4.3.4 Storm — พายุ (M3, แมพกึ่งกลางแจ้ง เช่น ระเบียง/โรงเก็บของในสวน)
**ภาพ**: ประตูกระจกระเบียงถูกลมกระแทกเปิด ลมพัดใบไม้และกระดาษปลิวว่อน ใบไม้หมุนวนเป็นลมหมุนเล็กๆ ฟ้าผ่าลงลานกลางแจ้ง
- Active: `PushForce` ทุก 15s นาน 3s ความเร็ว 20 studs/s ตามทิศลม (ยกเว้นใน `SafeZone` เช่น ใต้กระถางคว่ำ, ในรองเท้าบูท) และ `TelegraphedImpact` `ExposedPlayer` (ฟ้าผ่า) ทุก 8s, telegraph 2s, radius 4, damage 40
- Critical: gust ทุก 8s นาน 4s ความเร็ว 30 studs/s และ `MovingVortex` (ลมหมุนใบไม้) เคลื่อนตาม `VortexPath` 10 studs/s ดูดในรัศมี 30 ที่ 15 studs/s ใจกลาง 8 studs → เหวี่ยงขึ้น + 25 damage (cooldown ต่อคน 4s) ทำลาย prop ที่มี tag `Breakable`
- Exit Zone ต้องเป็น `SafeZone` เสมอ

---

## 5. Player mechanics

### 5.1 สถานะผู้เล่น (Attribute `State` บน Player, server เป็นคนตั้ง)

| สถานะ | ความหมาย | ทำอะไรได้ | ภาพ (แฮมสเตอร์) |
|---|---|---|---|
| `Lobby` | อยู่ใน Lobby | เดิน | — |
| `Standing` | ปกติใน Match | ทุกอย่าง | — |
| `Downed` | HP หมด | คลาน 5 studs/s (0 ขณะถูก revive), ไม่โดน damage (ยกเว้น `Submerged` ที่เร่ง bleed-out), interact ไม่ได้, ถือของไม่ได้ (ของตก), กระโดดไม่ได้ | ม้วนตัวกลม ดาวหมุนบนหัว (UI: "Dizzy!") |
| `Eliminated` | bleed-out หมด / ตกนอกแมพ / ตายแบบ Roblox | ไม่มีตัวละคร กล้องตามเพื่อน รอ respawn | "ปุ๊ฟ" เป็นกลุ่มขนฟู (UI: "Poofed!") |
| `Escaped` | อยู่ใน Exit Zone ตอน Departure ครบ | (ตัดสินตอนจบ) | นั่งในกรงโบกมือ |

แยกจาก `State` ยังมี flag **`Inactive`** (bool) ดู 5.9

```
Standing --HP<=0--> Downed --revive--> Standing (HP 40)
                    Downed --bleed-out 30s--> Eliminated --respawn delay--> Standing
Standing/Downed --Y < KillY หรือ Humanoid.Died--> Eliminated
```

### 5.2 Health / Damage และการปิดระบบตายของ Roblox
- **HP ของเกมเก็บใน Attribute `HP` บน Player** (0–100) และจัดการโดย server `DamageService` เท่านั้น ไม่ใช้และไม่ลด `Humanoid.Health` (คงที่ 100)
- ค่าที่ต้องตั้ง:
  - Server: `Players.CharacterAutoLoads = false` → server เรียก `LoadCharacter()` เองทุกครั้ง (PlayerAdded ที่ Lobby, เข้า Match, respawn, กลับ Lobby)
  - เมื่อ character spawn: `Humanoid.BreakJointsOnDeath = false` และ `Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)` **เรียกทั้ง server และ client** (state ของ Humanoid คุมโดยเครื่องที่เป็นเจ้าของตัวละคร คือ client)
  - Client: `StarterGui:SetCore("ResetButtonCallback", false)` (เรียกซ้ำด้วย pcall จนสำเร็จ เพราะตอนเริ่มเกม SetCore อาจยังไม่พร้อม) และ `SetCoreGuiEnabled(Health, false)` (ใช้แถบ HP ของเราแทน)
  - ถ้า `Humanoid.Died` ยังยิง → ถือว่า Eliminated ถ้าตอนนั้นอยู่ในสถานะ Downed ให้**บวกเวลา bleed-out ที่เหลือเข้าไปใน respawn delay** (ฆ่าตัวเองแล้วไม่ได้เปรียบ)
- HP ≤ 0 → Downed
- **ไม่มี regen** ใน M1 (M2 พิจารณา +2 HP/s หลังจากไม่โดน damage 8s)
- Spawn protection 3s หลัง spawn/respawn (ไม่โดน damage)
- ไม่มี fall damage, friendly fire หรือ PvP
- Feedback เมื่อโดน: "โป๊ก!" ดาวกระจาย + เสียงจี๊ด + แถบ HP สั่น (ไม่มีจอแดง ไม่มีเลือด)

### 5.3 Downed & Revive
- Downed: bleed-out 30s (HUD ใหญ่ของผู้ล้ม + marker ดาวหมุนบนหัวที่เพื่อนเห็นทะลุกำแพงพร้อมบอกระยะ)
- ภาพ: animation ม้วนตัว/คลานแบบมึนๆ (Art ทำ) และ `MoveMode = Downed`
- **Revive = server-timed hold (3.3)** บน prompt ที่ HRP ของผู้ล้ม (เห็นเฉพาะเพื่อน) ใช้เวลา 4s ระยะ prompt 7 studs ถ้าปล่อยก่อนครบ → progress revive กลับเป็น 0 ภาพ: เพื่อนเขย่าตัว/ป้อนเมล็ดทานตะวัน
- ระหว่างที่มีคน revive อยู่: bleed-out หยุดนับ, **ผู้ล้มถูกตั้ง `MoveMode = Pinned` (ความเร็ว 0)** เพื่อไม่ให้คลานหลุดระยะ, คนที่ revive โดน damage แล้วไม่ขัดจังหวะ
- สำเร็จ → Standing, HP 40, protection 2s
- ผู้ล้มคลานได้ตอนไม่มีใคร revive (หนีน้ำ, คลานหาเพื่อน, คลานเข้า Exit Zone)

### 5.4 Eliminated / Spectate / Respawn
- Eliminated → ลบ character, กล้องตามเพื่อนคนแรกที่ไม่ Eliminated ตามลำดับ UserId (M1) ถ้าไม่มี กล้องจะลอยมองแมพจากมุมกว้าง
- Respawn delay = 20s + 10s × (จำนวนครั้งที่ Eliminated ก่อนหน้าใน Match นี้) สูงสุด 40s (+ เวลา bleed-out ที่เหลือ ถ้าตายแบบ Roblox ขณะ Downed) **(รอ Boss ยืนยัน Q3)**
- Respawn ได้ทุก Stage จนกว่า Match จบ ได้ HP 100, protection 3s, ไม่มีของติดตัว
- **Respawn selector** (generic):
  1. ผู้สมัคร = `PlayerSpawn` ที่เปิดใช้: ไม่มี Attribute `EnabledBy` หรือ flag นั้นเป็นจริงแล้ว
  2. ตัดจุดที่ `isPointHazardous(spawn + (0,3,0))` เป็นจริง
  3. เลือกจุดที่ `Priority` ต่ำสุด (เลขน้อยได้ก่อน) ถ้าเสมอกันให้สุ่ม
  4. ถ้าไม่เหลือเลย → เลือกจุดที่ Y สูงสุดในบรรดาจุดที่เปิดใช้
- แมพ #1: มุมกรงบนพื้น Priority 2 (×4), บนเคาน์เตอร์ Priority 3 (×2), ขอบหน้าต่างด้านใน Priority 1 + `EnabledBy = WindowOpen` (×2) หลังปลดล็อก คนที่ respawn จะเกิดใกล้ทางออก ถ้าพื้นน้ำท่วม จะเกิดบนเคาน์เตอร์

### 5.5 Movement (server-authoritative ผ่าน Attribute)
| | ค่า |
|---|---|
| Walk | 16 studs/s |
| Sprint (Shift / ปุ่มบนจอมือถือ) | 24 studs/s |
| Stamina | 100 ลด 25/s ขณะวิ่ง ฟื้น 20/s หลังหยุดวิ่ง 1.0s ต้องมี ≥ 20 จึงเริ่มวิ่งได้ |
| Jump | JumpHeight 7.2 (Downed = 0) |
| ปีน | ผ้าม่าน/เชือกใช้ `TrussPart` ล่องหนซ้อนกับ mesh (ระบบปีนมาตรฐานของ Roblox) |
| การชนกันระหว่างผู้เล่น | ปิด (CollisionGroup `Players` ไม่ชนกันเอง) |

**ใครตั้งค่าอะไร** (เพื่อไม่ให้เขียนทับกัน):
- **Server** ตั้ง Attribute บน Player: `SpeedMult` (ผลคูณของ modifier ที่ active: Pulse, `Slowed`, ถือ Small item ×0.9), `CanSprint` (false เมื่อ `Slowed`, HeavyCarry, Downed) และ `MoveMode` (`Normal` / `Downed` / `Pinned` / `HeavyCarry`)
- **Client** เป็นผู้เดียวที่เขียน `Humanoid.WalkSpeed`:
  - `Downed` → 5, `Pinned` → 0, `HeavyCarry` → 10
  - `Normal` → `max(6, (sprinting and CanSprint ? 24 : 16) × SpeedMult)`
  - Stamina คำนวณฝั่ง client
- **Server ตรวจระยะที่เคลื่อนที่จริง** (กัน teleport และ speed hack) แบบหน้าต่างเลื่อน 2s ที่ทนต่อ network กระตุก:
  - เก็บ sample ตำแหน่ง HRP ทุก 0.5s พร้อม timestamp จริง
  - ระยะแนวนอนรวมใน 2s ล่าสุดต้อง ≤ `24 × max(SpeedMult,1) × (เวลาจริงที่ครอบคลุม) × 1.1 + 4` studs (ไม่ตรวจแกน Y การตกจึงไม่ผิด)
  - ข้ามการตรวจขณะ `ForcedMoveUntil > now` (ตั้งโดย PushForce, Vortex, RecoveryPoint, respawn, เข้า Match)
  - ผิด → `PivotTo` กลับไปยังตำแหน่งล่าสุดที่ผ่าน ถ้าผิด ≥ 3 ครั้งใน 10s → log (Systems/Data ตัดสินบทลงโทษภายหลัง)

### 5.6 Interaction
- ทุก interaction ใช้ `ProximityPrompt` Style Default, `MaxActivationDistance` = 8 (revive = 7), `RequiresLineOfSight` = true ปุ่มเดียวคือ E / แตะบนจอ
- 2 แบบ: **Press** (`HoldDuration 0` ใช้ `Triggered` ครั้งเดียว เช่น หยิบ, เสียบ, Grab) และ **Server-timed hold** (3.3)
- Server ตรวจทุกครั้ง: ผู้เล่น Standing, ไม่ Inactive, ระยะ ≤ 10 studs, objective อยู่ใน Step ที่เปิดและยังไม่เสร็จ, (ถ้าต้องถือของ) ถือของชนิดที่ถูก
- Prompt ของ Step ที่ยังไม่เปิดหรือทำเสร็จแล้ว → `Enabled = false`

### 5.7 การถือของและการกู้คืน item
**Small item** (ถ่าน AA, ขวดฉีดน้ำ)
- ถือได้ครั้งละ 1 ชิ้น (Small หรือ Heavy อย่างใดอย่างหนึ่ง) server สร้าง weld ที่ RightHand (แฮมสเตอร์กอดของไว้)
- `SpeedMult` ×0.9 วิ่งได้
- Drop: ปุ่ม G (PC) / ปุ่มบนจอ (มือถือ ใช้ `ContextActionService` สร้างปุ่มแตะ) → client ขอผ่าน Remote แล้ว server เป็นคนทำ
- ของตกเองเมื่อ Downed, Eliminated, ออกจากเกม หรือกลายเป็น Inactive
- หยิบไม่ได้ขณะถือของอื่นอยู่ (prompt ซ่อน)

**การวาง item (ทุกกรณี)**: server raycast หาพื้นในระยะ ≤ 4 studs หน้าผู้เล่น (ถ้าไม่เจอ ใช้ใต้เท้า) จุดนั้นต้องไม่อยู่ใน CollapseGroup item ที่วางอยู่ **anchored เสมอ** (ไม่มีฟิสิกส์ และ client ไม่มี network ownership)

**การกู้คืน (กัน softlock)** → item กลับไปที่ **ItemSpawn เดิมของมัน** ถ้าจุดเดิมเป็น `isPointHazardous` ให้ไปที่ ItemSpawn ชนิดเดียวกันในโซนที่ยังไม่มี item ชนิดนี้และไม่อันตราย พร้อมแสง/เสียงเตือนในระยะ 30 studs:
1. item ต่ำกว่า `Map.KillY` → หลัง 3s
2. item ทับ `After` ของ CollapseGroup ตอนสลับ → ทันที
3. `ITEM_IDLE_RESPAWN`: **เฉพาะ item ที่เคยถูกหยิบอย่างน้อย 1 ครั้ง** เริ่มนับเวลาตั้งแต่ตอนที่ item ถูกวางหรือตก ถ้าไม่มีใครหยิบภายใน 45s **และ** ไม่มีผู้เล่นอยู่ในระยะ 15 studs → กู้คืน item ที่ยังไม่เคยถูกหยิบจะไม่ถูกย้ายด้วยกฎนี้

### 5.8 ชนะ / แพ้ (ระดับทีม)

**Extraction** (ธีม: นักดับเพลิงหย่อนกรงสัตว์เลี้ยงลงมาที่หน้าต่าง)
1. Step สุดท้ายเสร็จ → ปลดล็อก `LockedDoor` ที่ `UnlockedBy = exitFlag` (บานหน้าต่างเลื่อนเปิด), เปิด spawn ที่ `EnabledBy = exitFlag`, Stage เข้า Critical, HUD แสดง "Rescue ETA 60s" + marker ไปที่กระบะดอกไม้นอกหน้าต่าง
2. ETA ครบ → spawn `exitVehicleAsset` (กรงสัตว์เลี้ยงห้อยเชือก ประตูกรงเปิด) ที่ `ExitVehicleSpot`, Exit Zone ตั้ง `Open = true` (กลายเป็น NoImpact)
3. **Departure 10s** เริ่มนับเมื่อ **มีผู้เล่นใน Exit Zone ≥ 1 คน และ** ทุก team member ที่ไม่ Eliminated (`activeCount`) อยู่ใน Exit Zone (Downed ที่อยู่ในโซนก็นับ) — ถ้า `activeCount = 0` (เช่น solo ถูก Eliminated) จะไม่นับจนกว่าจะมีคน respawn และเข้าโซน **(รอ Boss ยืนยัน Q2)**
4. ถ้ามีคนก้าวออก → countdown **หยุดชั่วคราว** (ไม่รีเซ็ต) เมื่อกลับมาครบ → นับต่อ
5. **Last call**: เมื่อกรงรออยู่ครบ `LAST_CALL_AFTER` = 45s เงื่อนไขข้อ 3 จะลดเหลือ `max(1, ceil(activeCount / 2))` คน (HUD: "Last call! The carrier is leaving") เพื่อไม่ให้คนเดียวจับทีมเป็นตัวประกัน
6. นับครบ → กรงถูกดึงขึ้น Match จบ ใครอยู่ใน Exit Zone (Standing หรือ Downed) = Escaped

**ชนะ**: Match จบด้วย Departure และ Escaped ≥ 1 คน หรือถึง 7:00 ขณะที่กรงมาถึงแล้วและมีคนอยู่ใน Exit Zone ≥ 1 คน (คนในโซน = Escaped)

**แพ้**:
1. **Collapse** (7:00) ขณะที่กรงยังไม่มาถึง หรือไม่มีใครอยู่ใน Exit Zone
2. **Team Wipe** (`TEAM_WIPE_RULE = AllDowned`): team member **ทุกคนอยู่ในสถานะ Downed พร้อมกัน** (ไม่มีใคร Standing และไม่มีใครรอ respawn) → แพ้ทันที **(รอ Boss ยืนยัน Q3)** ไม่ใช้เมื่อ `teamCount = 1` (3.5)
3. ไม่มี team member เหลือ (ทุกคนออกหรือ Inactive) → แพ้ทันที

**ลำดับตรวจใน tick เดียวกัน**: ชนะ (Departure ครบ) → Wipe → Collapse

ผลรายคน: Escaped ได้รางวัลเพิ่ม (6.1) แต่ทุกคนในทีม "ชนะ" ร่วมกัน

### 5.9 Inactive (AFK) และคนออก
- **การตรวจ activity**: server ถือว่ามี activity เมื่อเกิดข้อใดข้อหนึ่ง:
  - (ก) HRP เคลื่อนเกิน 2 studs จากตำแหน่งที่บันทึกล่าสุด
  - (ข) client ส่ง Remote `ActivityPing` (ส่งเมื่อมี input ใดๆ throttle 1 ครั้ง/10s และ server รับไม่เกิน 1 ครั้ง/5s)
  - (ค) **อยู่ใน holder set ของ anchor ใดๆ**
  - (ง) **กำลังถือ item**
- ตัวนับ Inactive **หยุดชั่วคราวขณะ Eliminated** (ไม่มีตัวละคร) แล้วเริ่มนับใหม่ตอน respawn
- **ใน Match**: ไม่มี activity 60s → `Inactive = true`:
  - ไม่เป็น team member → ไม่นับใน `teamCount`/`activeCount` (MultiHold required, Deliver count, Departure, Last call, Wipe, solo fallback)
  - ของที่ถืออยู่ตก และถูกถอดจาก holder set ทุกอัน
  - ตัวละครยังอยู่ (โดน hazard ตามปกติ) HUD ของเขาแสดง "You are inactive — move to rejoin"
  - เมื่อมี activity อีกครั้ง → `Inactive = false` และกลับเป็น team member ทันที (MultiHold Continuous ที่กำลังนับอยู่ไม่รีเซ็ต เพราะใช้กฎ lockedRequired ใน 3.4)
  - ไม่ได้รางวัลรอบนั้นถ้า Inactive รวม ≥ 90s (M2)
- **ใน Lobby**: ดู 2.1
- **คนออกจาก server**: ของที่ถือตก ถูกถอดจาก holder set และไม่นับอีกต่อไป

### 5.10 การรับประกันว่า Match ชนะได้เสมอ (สรุปสำหรับ QA)

| ความเสี่ยง | สิ่งที่กันไว้ |
|---|---|
| ภัยทำลายหรือปิด objective | anchor/socket/ItemSpawn อยู่นอก CollapseGroup, `NoBlockingProp` รอบ anchor, objective ทำใต้น้ำได้ (แค่ช้าลง) |
| Item หายหรือติด | กฎกู้คืน 3 ข้อ (5.7) และ item วางแบบ anchored |
| คนไม่พอทำ MultiHold | `required` นับเฉพาะคนที่ไม่ Eliminated, Inactive/คนออกไม่นับ, `activeCount = 1` → solo |
| **คนที่ยังขยับแต่ไม่ยอมช่วย (เด็กที่ยังไม่เข้าใจ, หา anchor ไม่เจอ, คนป่วน)** | **Emergency override หลัง 75s ลด required ลง 1 (ต่ำสุด 2) ในทีม ≥ 3 คน** ส่วนทีม 2 คนยังต้องช่วยกัน 2 คนเสมอ (เป็นความเสี่ยงที่ยอมรับ ดู Q2) |
| คน AFK ขวาง Departure | Inactive ไม่นับ + Last call |
| เกิดในจุดอันตรายหรือติดใน geometry | Respawn selector, RecoveryPoint ตอน collapse |
| ไม่มีทางไป Exit | ต้องมีเส้นทางที่ไม่ผ่าน CollapseGroup (ผ้าม่าน) และ Exit Zone อยู่สูงกว่า `maxLevel` ของ RisingVolume |

ทางแพ้ที่ตั้งใจไว้มี 2 ทาง: เวลาหมด และ Team Wipe

---

## 6. Progression & rewards (M2 — ไม่อยู่ใน M1)

### 6.1 ได้อะไร
สกุลเงินเดียว: **Seeds** (เมล็ดทานตะวัน, ชื่อ placeholder) + **XP** = จำนวน Seeds ที่ได้ในรอบนั้น (Level ให้แค่ title/กรอบชื่อ)

| เงื่อนไข | Seeds |
|---|---|
| อยู่จนจบ Match และ Inactive รวม < 90s | 20 |
| ทีมชนะ | 40 |
| ตัวเอง Escaped | 30 |
| team member ทุกคน Escaped | +20 ให้ทุกคน |
| เครดิต objective (กฎใน 3.4) | 10 ต่อ objective สูงสุด 30 |
| Revive เพื่อน | 10 ต่อครั้ง สูงสุด 30 |
| ชนะครั้งแรกของวัน (UTC) | +50 |
| **เพดานต่อ Match** (ไม่รวม daily) | 150 |

ไม่มีรางวัลตามความเร็ว (ไม่อยากให้ทีมทิ้งเพื่อน)

### 6.2 ใช้กับอะไร (cosmetic เท่านั้น)
| หมวด | ตัวอย่าง | ราคา (Seeds) |
|---|---|---|
| สีขน/ลาย | ทอง, ขาวดำ, ลายวัว, ลายเสือ | 150–400 |
| หมวก | หมวกนักดับเพลิงจิ๋ว, ฝาขวด, ถุงเท้าทำเป็นหมวก | 150–400 |
| เสื้อ/ผ้าพันคอ | เสื้อกั๊กสะท้อนแสง, ผ้าพันคอถักไหมพรม | 200–500 |
| Trail ตอนวิ่ง | เศษเมล็ด, ฟองสบู่ | 300–800 |
| Emote | ยืนสองขาส่งเสียงจี๊ด, ตุนแก้มป่อง | 250 |
| ท่าตอนชนะ (Result) | | 500 |

### 6.3 ความแฟร์
- ไม่ขายหรือให้สิ่งที่เพิ่ม HP, ความเร็ว, stamina, ลดเวลา revive/respawn หรือข้าม objective
- Robux (ถ้ามี): cosmetic หรือ Seeds pack เท่านั้น ไม่มี "revive ด้วย Robux"
- Seeds คำนวณและบันทึกฝั่ง server เท่านั้น

---

## 7. Map #1 — "Midnight Kitchen" (`MidnightKitchen`) ฉบับเต็ม (ระยะยาว)

> ตอนส่งงานใช้ "Deadline cut" ของแมพนี้ (8.3) ซึ่งเล็กกว่าและมี 2 ระดับ หัวข้อนี้คือผังเต็มสำหรับหลังส่งงาน

### 7.1 แนวคิด
ครัวของบ้านครอบครัวหนึ่งตอนเที่ยงคืน ครอบครัวอพยพออกไปอย่างรีบร้อนและลืมแฮมสเตอร์ไว้ กรงล้มอยู่บนพื้น นักดับเพลิงอยู่นอกบ้าน ทีมต้องปั่นไฟแท่นชาร์จวิทยุของเล่น (วิ่งวงล้อ + ใส่ถ่าน) ร้องเรียกคนช่วยผ่านวิทยุทุกเครื่องพร้อมกัน แล้วปลดสลักหน้าต่างเหนือซิงก์ เพื่อให้นักดับเพลิงหย่อนกรงลงมารับ

**ทำไมเลือกครัว**:
- (1) ทุกวัยจำได้ทันที
- (2) มีหลายระดับตามธรรมชาติ (มุมซักผ้าต่ำลงไป 1 ขั้น → พื้น → ชั้นล่าง → เคาน์เตอร์ → ขอบหน้าต่าง) ซึ่งตรงกับผังเดิม "ใต้ดิน → ชั้น 1 → catwalk → ชั้น 2 → ดาดฟ้า" ทุกระดับ
- (3) มีแหล่งน้ำ (เครื่องซักผ้า/ซิงก์) สำหรับ Flood และของบนชั้นจำนวนมากสำหรับ Earthquake
- (4) หน้าต่างเป็นทางออกที่เข้าใจง่าย

ใช้กับ **Earthquake** (M1) และ **Flood** (M1-stretch) โดยทั้งสองภัยมีทางหนีอยู่ที่สูง

### 7.2 ขนาดและสเกล
- สเกล 1 stud = 2 cm (1.1) ครัว 4.0 × 3.2 m = **200 × 160 studs** (เท่ากับที่ดินของแมพเดิม)
- ระดับ (Y เทียบพื้นครัว):

| ระดับ | Y | เทียบกับผังเดิม |
|---|---|---|
| มุมซักผ้า (ต่ำลงไป 1 ขั้น 6 cm) | −3 | ห้องเครื่องใต้ดิน |
| พื้นครัว (กระเบื้อง) | 0 | ชั้น 1 |
| ชั้นล่างของชั้นวางเปิด (สูง 8 cm) | +4 | catwalk |
| เบาะเก้าอี้ (ทางผ่าน) | +23 | — |
| เคาน์เตอร์ (รูปตัว L ตามผนังทิศเหนือและตะวันออก) | +45 | ชั้น 2 |
| ขอบหน้าต่างเหนือซิงก์ | +61 | ดาดฟ้า |
| เพดาน | +125 | — |

- `KillY` = −30, `Workspace.FallenPartsDestroyHeight` = −80 (ตาข่ายสำรอง)
- ผนังและเพดานเป็นขอบเขตแมพ (กำแพงล่องหนซ้อนตามช่องประตูที่ปิดอยู่)

### 7.3 ผังและระยะ
```
ระดับพื้น (Y 0 / −3 / +4)
                         N  (ผนังหน้าต่าง: ใต้เคาน์เตอร์เป็นตู้ปิด เข้าไม่ได้)
 +-------------------+--------------------------------+------------------+
 | [D] PANTRY        | [B] FRIDGE & OPEN SHELVES      | [C] LAUNDRY NOOK |
 |  (walk-in)        |  แท่นชาร์จวิทยุ (socket, +4)     |  (−3)            |
 |  Zone P: ถ่าน x2  |  ชั้นล่าง +4: วิทยุ A B C D       |  วงล้อแฮมสเตอร์    |
 |  (CerealTower)    |  [S] บันไดม้านั่ง: ลิ้นชัก→         |  + ไดนาโม,        |
 |                   |      ม้านั่ง→เคาน์เตอร์ ↑         |  เครื่องซักผ้า      |
 +---------+---------+---------+----------------------+------------------+
 | [E] DINING TABLE & CHAIRS   Zone T: ถ่าน x2 (ใต้โต๊ะ/บนเบาะเก้าอี้)   |
 +--W-----------------------------------------------------------------------+
    ^ ผ้าม่านยาวถึงพื้น (ผนังตะวันตก: พื้น → ระดับเคาน์เตอร์ → ขอบหน้าต่างฝั่งตะวันตก)
          [A] PET CORNER: กรงที่ล้ม SPAWN x4       [shoe rack] Zone B: ถ่าน x2
                         S  (ประตูหลังบ้าน: ปิดล็อก)

ระดับเคาน์เตอร์ (+45)
  Latch A: ปลายตะวันตก (ข้างเขียงที่ตั้งพิงผนัง)    Latch B: ปลายตะวันออก (หลังกาต้มน้ำ)
  Latch C: มุมตัว L (หลังโถขนมปัง)                Latch D: ปีกตะวันออก (หลังกล่องซีเรียล)
  Zone K: ถ่าน x2 (ข้างชามผลไม้)   spawn x2 (Priority 3)
  [S] บันไดหลักต่อ: ที่คว่ำจาน (DishRack) → บานหน้าต่างกลาง (LockedDoor, UnlockedBy=WindowOpen)
  ทางสำรอง: ผ้าม่าน → บานหน้าต่างฝั่งตะวันตก (LockedDoor, UnlockedBy=WindowOpen)

ขอบหน้าต่าง (+61): spawn x2 (EnabledBy=WindowOpen)
นอกหน้าต่าง: กระบะดอกไม้ [G] = Exit Zone 24 × 24 + ExitVehicleSpot (กรงหย่อนลงมาจากด้านบน)
```

| จาก → ถึง | ระยะเดิน (studs) | หมายเหตุ |
|---|---|---|
| Spawn [A] → วงล้อ [C] | 110 | ลงขั้นเข้ามุมซักผ้า |
| Spawn → แต่ละโซนถ่าน | P 70, T 50, B 60, K 90 | K อยู่บนเคาน์เตอร์ ขึ้นทางบันไดม้านั่ง |
| ค้นทั่ว 1 โซน (เดินวน) | ~120 | ItemSpawn 2 จุดต่อโซน |
| แต่ละโซน → แท่นชาร์จ [B] | P 50, T 60, B 110, K 45 | |
| วงล้อ → ชั้นล่าง (วิทยุ) | 70 | |
| แท่นชาร์จ → ชั้นล่าง | 30 | |
| วิทยุ ↔ วิทยุ | ≥ 30 เส้นตรง | ชั้นวางรูปตัว L มีขวดซอสและโหลบังสายตาบางส่วน |
| ชั้นล่าง → สลักใดๆ | 90–110 | ผ่านบันไดม้านั่ง (สูงขึ้น 45) |
| สลัก ↔ สลัก | ≥ 40 เส้นตรง, ≥ 60 เดิน | มองไม่เห็นกัน (กาต้มน้ำ, โถขนมปัง, กล่องซีเรียลบัง) |
| สลัก → Exit Zone (ที่คว่ำจาน) | ~60 | ทางหลัก |
| สลัก → Exit Zone (ผ้าม่าน) | ~110 | ไม่ผ่าน CollapseGroup เลย |

### 7.4 Mission: "Call for Help" (`MidnightKitchen_CallForHelp`)

| Step | Objective | Kind | ตำแหน่ง | ค่า | ภาพ |
|---|---|---|---|---|---|
| 1 "Power up the charger" | `RunWheel` | Repair | [C] | duration 45, maxStack 2, submergedRateMult 0.5, holdAnim `RunInWheel` | วิ่งในวงล้อที่ต่อกับไดนาโมชุดวิทยาศาสตร์ของเด็ก (วิ่งพร้อมกันได้ 2 ตัว) |
| 1 | `DeliverBatteries` | Deliver | ItemSpawn 4 โซน (P/T/B/K) × 2 จุด → แท่นชาร์จ [B] | itemType `Battery`, count = teamCount (1–4) โซนละ 1 ก้อน | กอดถ่าน AA ไปใส่ช่องถ่าน |
| 2 "Call for help" | `CallForHelp` | MultiHold Cumulative | วิทยุ A–D บนชั้นล่าง [B] | anchorCount 4, holdTime 30, assist | กดปุ่มพูดวิทยุแล้วร้องจี๊ดๆ ทุกเครื่องพร้อมกัน เสียงรวมจึงดังพอให้นักดับเพลิงได้ยิน |
| 3 "Unlock the window" | `WindowLatches` | MultiHold Continuous | Latch A–D บนเคาน์เตอร์ | anchorCount 4, holdTime 5, assist | ดันปุ่มสลักกันเด็กเปิดพร้อมกันทุกอัน |
| Extraction | — | — | บานหน้าต่างกลาง + ฝั่งตะวันตกเลื่อนเปิด, ETA 60s, กระบะดอกไม้ [G] | exitFlag `WindowOpen`, exitVehicleAsset `RescueCarrier` | นักดับเพลิงหย่อนกรงสัตว์เลี้ยงลงมาด้วยเชือก |
| (M2 bonus) | `RescueBaby` | Rescue | [D] | optional | ลูกแฮมสเตอร์ติดใต้ตะแกรงคว่ำ |

### 7.5 เส้นทางหนี
- **ทางหลัก**: บันไดม้านั่ง (ลิ้นชักที่เปิดค้าง → ม้านั่ง → เคาน์เตอร์) → ที่คว่ำจาน → บานหน้าต่างกลาง → กระบะดอกไม้ (~60 studs จากสลัก)
- **ทางสำรอง**: ปีนผ้าม่าน (TrussPart) ผนังตะวันตก จากพื้นหรือจากระดับเคาน์เตอร์ → บานหน้าต่างฝั่งตะวันตก → เดินบนขอบหน้าต่าง → กระบะดอกไม้ (~110 studs) ไม่ผ่าน CollapseGroup ใดๆ (เป็นทางที่รับประกัน)
- Earthquake (RouteCollapse ใน M1-stretch):
  - `CerealTower` ปิดทางลัดใน pantry ที่ Active+30s (ต้องอ้อมเพิ่ม 20 studs)
  - `DishRack` ล้มที่ Critical+40s หลังจากนั้นต้องใช้ผ้าม่าน
- Flood: ทั้งสองทางใช้ได้เพราะเริ่มจากเคาน์เตอร์ที่น้ำท่วมไม่ถึง หลัง ~2:52 พื้นท่วมมิดหัว คนที่อยู่ข้างล่างต้องลุยน้ำไปบันไดม้านั่ง/ผ้าม่าน และคนที่ respawn จะเกิดบนเคาน์เตอร์

### 7.6 Map markup contract (tag + Attribute ทั้งหมดเป็นชื่อ generic)

| Tag | ใส่บน | Attributes | ใช้โดย |
|---|---|---|---|
| `PlayerSpawn` | Part | `Priority` (number), `EnabledBy` (string, optional) | Round/Respawn |
| `ObjectiveAnchor` | Model (มี child `PromptPart`) | `ObjectiveId`, `Part` ("A".."D" สำหรับ MultiHold) | Mission |
| `ItemSpawn` | Part | `ItemType`, `Zone` | Mission |
| `LockedDoor` | Model | `UnlockedBy` | Mission |
| `ExitZone` | Part (CanCollide false) | `Open` (server ตั้ง) | Round |
| `ExitVehicleSpot` | Part | — | Mission |
| `CollapseGroup` | Model ที่มี folder `Before` / `After` | `GroupId` (เวลาสลับกำหนดใน DisasterDef) | Disaster |
| `RecoveryPoint` | Part | — | Disaster |
| `NoBlockingProp` | Part volume | — | TelegraphedImpact |
| `NoImpact` | Part volume | — | TelegraphedImpact |
| `VolumeLevel` | Part (ใช้แค่ค่า Y) | `Level` (0–3) | RisingVolume |
| `SafeZone` / `SpreadNode` / `NoSpread` / `VortexPath` / `Breakable` | (M2+) | ตาม 4.2–4.3 | Disaster |
| Map root | Model `MidnightKitchen` | `KillY` | Round |

กฎแมพที่ Level Designer ต้องผ่าน:
- ระยะ anchor ตาม 3.4 และ 7.3
- ห้ามวาง anchor/socket/ItemSpawn/PlayerSpawn/ExitZone ใน bounds ของ CollapseGroup
- ต้องมีเส้นทางไป Exit ที่ไม่ผ่าน CollapseGroup
- Exit Zone อยู่สูงกว่า VolumeLevel สูงสุด
- บันได/ทางปีน/ช่องหน้าต่างครอบด้วย `NoBlockingProp` (ห้ามใช้ `NoImpact`)
- รัศมี 6 studs รอบ PlayerSpawn ครอบด้วย `NoImpact`
- ของประกอบฉากยักษ์ที่ไม่ได้ใช้เดิน ตั้ง `CanQuery = false` ถ้าเป็นไปได้ เพื่อไม่ให้ raycast ของ impact ชน

สเปกเต็มอยู่ที่ `docs/levels/MidnightKitchen.md`

---

## 8. Deadline build (สร้างก่อน) — ส่งงาน 25 ต.ค. 2026 เวลา 12:00 (เวลากรุงเทพฯ)

> **เส้นตายส่งงาน: 25 ต.ค. 2026 เวลา 12:00 น. (Asia/Bangkok)** นับจากตอนเขียน (23 ต.ค. ~22:40) เหลือ ~37 ชั่วโมง
> หัวข้อนี้คือ**สิ่งที่สร้างก่อน** หัวข้อ 1–7 และ 9–10 เป็นวิสัยทัศน์ระยะยาวของเกม ป้าย "M1", "M1-stretch", "M2" ในหัวข้อเหล่านั้นหมายถึงแผนระยะยาว **หลังส่งงาน** ถ้าขัดกัน ให้ยึดหัวข้อ 8 นี้สำหรับงานก่อนเส้นตาย
> ทีมทำงาน: Boss (dev 1 คน ใน Studio) + AI agents (Scripter, Systems, UI, Level, Art/Audio, QA)
>
> **สิ่งที่ต้องส่ง 3 อย่าง**: (1) เกม Roblox ที่ publish แล้วและเล่นได้ (2) เอกสารประกอบ (3) วิดีโอ gameplay เวลาสำหรับเอกสารและวิดีโอถูกจองไว้ในแผน 8.9 แล้ว และ**ห้ามใช้เวลาส่วนนั้นไปทำ build** (8.12)

### 8.1 สรุปสิ่งที่สร้าง

| หัวข้อ | Deadline build |
|---|---|
| แมพ | **"Midnight Kitchen — Deadline cut"** มี 2 ระดับ: พื้นครัว + เคาน์เตอร์ (และขอบหน้าต่างเป็นทางออก) ขนาด 160 × 120 studs (8.3) |
| ภัยพิบัติ | **Earthquake ตัวเดียวที่ทำงานครบ** (Flood เป็น stretch เท่านั้น) — ยังเป็น "สุ่ม 1 ภัยต่อรอบ" จากรายการที่ตอนนี้มีภัยเดียว ระบบสุ่มเขียนไว้แล้ว เพิ่ม Flood เข้ารายการได้ทันทีโดยไม่ต้องแก้โค้ด |
| Objective types | 3 แบบ: `Repair` (วิ่งวงล้อ), `Deliver` (ถ่าน), **`MultiHold` Cumulative (วิทยุ: บังคับ co-op)** |
| Mission | 2 Step + Extraction (ตัด Step สลักหน้าต่างออก) |
| ผู้เล่น | HP, Downed (ม้วนตัว + ดาวหมุน) / Revive, Eliminated → respawn คงที่ 15s, Team Wipe, ปิดปุ่ม Reset ของ Roblox |
| Extraction | ETA 60s → กรงสัตว์เลี้ยงหย่อนลงมา → Departure 10s + Last call |
| HUD | 8 ชิ้น พร้อม world marker ของ objective (8.6) |
| ปุ่มควบคุม | เดิน, กระโดด, กดใช้ (E / แตะ) — **ไม่มีวิ่ง ไม่มีปุ่มวางของ** จึงไม่ต้องทำปุ่มพิเศษบนมือถือ |
| ผู้เล่นต่อ server | **2–4 คน เริ่มได้เมื่อ ≥ 2 คนเท่านั้น** (Boss ตัดสิน: ไม่มี solo start) — Studio เท่านั้น: `DEV_MIN_PLAYERS_STUDIO = 1` ให้ agent เทสต์คนเดียวได้ (ไม่มีผลบน live) |
| ฉากเด่นสำหรับวิดีโอ | **"Rescue Moment"**: ตอนหน้าต่างเปิด แผ่นดินไหวแรงที่สุด + ไฟกู้ภัยแดง/น้ำเงินสาดเข้ามา + กรงหย่อนลงมาพร้อมไฟสปอตไลต์ + กล้องตอนชนะ (8.6.1) และปุ่มซ่อน HUD สำหรับถ่ายวิดีโอ |

### 8.2 ทำไมเลือก Earthquake
- **ถูกที่สุด**: ใช้ 3 component (`Pulse`, `TelegraphedImpact`, `MoveModifier`) + camera shake ฝั่ง client ไม่มีระดับน้ำ, Breath HUD, ระบบหาจุดเกิดที่ปลอดภัย หรือ tween น้ำ (Flood ต้องมีทั้งหมดนี้)
- **อ่านง่ายที่สุดที่สเกลแฮมสเตอร์**: วงแดงบนพื้น → แอปเปิล/กระป๋องยักษ์ตกลงมา "โป๊ก!" เด็กเข้าใจได้ทันทีโดยไม่ต้องอ่าน
- **ใช้ได้ทุกระดับของแมพ** (พื้น/เคาน์เตอร์/ขอบหน้าต่าง) ช่วงรอกรงจึงยังตึง
- ความเสี่ยงต่ำ: deadline build ใช้ debris แบบ**ภาพอย่างเดียว** (CanCollide false, จางหายใน 3s) จึงไม่มีปัญหาตัวละครติดหรือถูกเหวี่ยง และไม่ต้องใช้ `NoBlockingProp`

### 8.3 แมพ: Midnight Kitchen — Deadline cut (`MidnightKitchen`)

เรื่องเดิม (ครัวตอนเที่ยงคืน แฮมสเตอร์ถูกลืม ต้องเรียกนักดับเพลิง) แต่ตัดระดับมุมซักผ้าที่ต่ำลงไป ชั้นล่าง และ pantry ออก เหลือ 2 ระดับที่สร้างได้เร็วด้วย Part เปล่า

| ระดับ | Y | มีอะไร |
|---|---|---|
| พื้นครัว | 0 | Spawn, วงล้อ, แท่นชาร์จ, ถ่าน 3 โซน |
| เคาน์เตอร์ (ตัว L ตามผนังเหนือ + ตะวันออก กว้าง 30) | +45 | วิทยุ A–D |
| ขอบหน้าต่าง + กระบะดอกไม้ด้านนอก | +61 | Exit Zone, spawn หลังปลดล็อก |

```
            N  ผนังหน้าต่าง (หน้าต่างเหนือซิงก์อยู่กลางผนัง)
 +--------------------------------------------------------------+
 | ======== เคาน์เตอร์ +45 (Radio A ....... Radio B ...... Radio C)=|
 |[P] ประตู pantry   [B] ตู้เย็น: แท่นชาร์จ (socket)        ‖ เคาน์ |
 |    ถ่าน x2                                          ‖ เตอร์ |
 |ผ้าม่าน                          [C] วงล้อ + ไดนาโม    ‖ ปีก  |
 |(W, ปีนถึง  ทางลาด: เขียงพิง (พื้น→เบาะเก้าอี้ +23)      ‖ ตะวัน|
 | ขอบหน้าต่าง)        → ตำราอาหารเป็นขั้น (→ เคาน์เตอร์ +45)‖ ออก  |
 |[T] โต๊ะกินข้าว ถ่าน x2                              ‖Radio D|
 |[A] มุมกรงที่ล้ม SPAWN x4                 [S] ชั้นรองเท้า ถ่าน x2 |
 +--------------------------------------------------------------+
 ที่คว่ำจาน: เคาน์เตอร์ → ขอบหน้าต่าง (ทางหลัก)   ผ้าม่าน: พื้น → ขอบหน้าต่างฝั่งตะวันตก (ทางสำรอง)
 นอกหน้าต่าง: กระบะดอกไม้ = Exit Zone 24×24 + ExitVehicleSpot
```

| จาก → ถึง | ระยะเดิน (studs) |
|---|---|
| Spawn [A] → วงล้อ [C] | 90 |
| Spawn → โซนถ่าน T / S / P | 40 / 50 / 60 |
| ค้นทั่ว 1 โซน (ItemSpawn 2 จุด) | ~80 |
| โซน T / S / P → แท่นชาร์จ [B] | 60 / 70 / 50 |
| แท่นชาร์จ → เคาน์เตอร์ (ทางลาด 2 ช่วง) | ~90 |
| วิทยุ ↔ วิทยุ | ≥ 40 เส้นตรง (A x=20, B x=70, C มุม x=140, D ปีกตะวันออก 50 studs ใต้มุม) |
| วิทยุ → Exit Zone (ที่คว่ำจาน) | ~40 |
| เคาน์เตอร์ → Exit Zone (ผ้าม่าน: ลงพื้นแล้วปีน) | ~120 |

กฎ build (ให้ Level ทำเร็วและไม่พัง):
- ทางลาดเป็น `WedgePart` ชันไม่เกิน 35° (ห้ามบังคับให้กระโดดต่อกันหลายครั้ง) ผ้าม่านใช้ `TrussPart` ล่องหนซ้อนกับ mesh/Part ผ้า
- ทุกพื้นที่เดินได้ต้องเป็น Part ที่ `CanQuery = true` ส่วนของประกอบฉากที่ไม่ได้ใช้เดิน (ผนังตกแต่ง, ของบนผนัง) ตั้ง `CanQuery = false`
- `NoImpact` ครอบรัศมี 6 studs รอบ PlayerSpawn **เฉพาะจุดที่ไม่มี `EnabledBy`** (จุดเริ่มบนพื้น) ส่วน spawn บนขอบหน้าต่าง (`EnabledBy = WindowOpen`) **ไม่มี NoImpact** ใช้แค่ spawn protection 3s (Exit Zone เป็น NoImpact อัตโนมัติเมื่อ `Open = true`)
- `KillY = −30` บน map root, ผนัง/เพดานเป็นกำแพงล่องหน — **กำแพง/เพดานล่องหนทั้งหมด (รวมใน Lobby) ตั้ง `CanQuery = false`** (CanCollide ยัง true) เพื่อไม่ให้ raycast ของ impact/`RandomPoint`/การวาง item ชน
- Tag/Attribute ใช้ชุดเดียวกับ 7.6 (เฉพาะที่ใช้: `PlayerSpawn`, `ObjectiveAnchor`, `ItemSpawn`, `LockedDoor`, `ExitZone`, `ExitVehicleSpot`, `NoImpact`)

### 8.4 Mission (Deadline): `MidnightKitchen_CallForHelp`

| Step | Objective | Kind | ค่า |
|---|---|---|---|
| 1 "Power up the charger" | `RunWheel` | Repair | duration 45, maxStack 2 |
| 1 | `DeliverBatteries` | Deliver | count = clamp(teamCount, 1, **3**) โซนละ 1 ก้อน (3 โซน) |
| 2 "Call for help" | `CallForHelp` | MultiHold **Cumulative** | anchorCount 4, **holdTime 45**, required = min(4, activeCount), override หลัง 75s (−1, ต่ำสุด 2) |
| Extraction | — | — | exitFlag `WindowOpen` (บานหน้าต่างกลาง + ฝั่งตะวันตกเปิด), ETA 60, Departure 10, Last call หลัง 45s |

### 8.5 Pacing (Deadline cut, เดิน 16 studs/s, ไม่มีวิ่ง)

| ทีม | งาน | ทางออกปลดล็อก | จบ | อยู่ใน Active ก่อนปลดล็อก |
|---|---|---|---|---|
| 2 คน ideal | P1: เดิน 6s + วงล้อ 45s → 0:56 / P2: ถ่าน T (180 studs 11s + 13s) → 0:29, ถ่าน S (220 studs 14s + 13s) → 0:56 / วิทยุ: เดินขึ้น 7s + ประสาน 2s + 45s | 1:50 | 3:00 | 65s |
| 4 คน ideal | วงล้อ 2 ตัว → 0:34 / ถ่าน T, P → ~0:30, ถ่าน S → 0:56 / วิทยุ: รวมตัว 7 + ประสาน 8 + 45 | 1:56 | 3:06 | 71s |
| 2 คน typical | ideal + overhead ~78s (ค้น +30, pulse +8, ล้ม +25, ประสาน +15) | ~3:08 | **~4:18** | ~143s |
| 4 คน typical | ideal + ~85s | ~3:21 | ~4:31 | ~156s |
| ทีมช้า (overhead ×2) | | ~4:45 | ~5:55 | ทั้งหมด |

Stage, เวลา Collapse 7:00 และเส้นตายปลดล็อก 5:50 เหมือนหัวข้อ 2 ทุกทีมได้เจอ Active ≥ 60s และ Critical ≥ 70s

### 8.6 IN — สิ่งที่ต้องมีตอนส่งงาน

| ระบบ | รายละเอียด (อ้างอิงสเปกเต็ม) | เจ้าของ |
|---|---|---|
| Foundation | Rojo project, `Remotes.luau`, Config + Data (Mission/Objective/Item/Disaster/Stage) ตาม CONVENTIONS.md | Systems |
| Round flow | Lobby = แท่นธรรมดา (ห่างแมพ 3,000 studs, กำแพงล่องหน), Intermission 30s เมื่อมีคนที่ไม่ AFK ≥ 2 คน (ไม่มี solo start; ใน Studio ใช้ `DEV_MIN_PLAYERS_STUDIO = 1` ตรวจด้วย `RunService:IsStudio()` บน live ใช้ค่า 2 เสมอ), สุ่มภัยจากรายการ, clone/ล้างแมพ, Result 15s (2.1, 2.4) | Scripter |
| Debug commands (Studio เท่านั้น) | `skipStep`, `setStage <name>`, `unlockExit`, `setHP <n>`, `spawnDummyHolder <anchor>` (holder ปลอมสำหรับเทสต์ MultiHold และถ่าย "Held 4/4"), `endMatch win/lose` — ทำงานเฉพาะเมื่อ `RunService:IsStudio()` หรือ UserId อยู่ในรายชื่อ dev ใน Config (บน live ใช้ไม่ได้สำหรับคนอื่น และ server ตรวจทุกครั้ง) | Systems (Day 1) |
| Server-timed hold | กลไกเดียวสำหรับ Repair, MultiHold, Revive (3.3) | Scripter |
| Objectives | `Repair`, `Deliver`, `MultiHold` Cumulative + Emergency override + fallback เมื่อเพื่อนออกกลาง Match (required ลดตาม `activeCount`) (3.4, 3.5) | Scripter |
| Items | หยิบ (Press), เสียบ, ตกเองเมื่อ Downed/Eliminated/ออกจากเกม, วางแบบ anchored ด้วย raycast, กู้คืนเมื่อต่ำกว่า KillY (5.7 ข้อ 1) | Systems |
| Player state | HP attribute, `CharacterAutoLoads = false`, ปิด Reset/Dead (5.2), Downed + bleed-out 30s, Revive 4s (Pinned), Eliminated → **respawn คงที่ 15s** ที่ spawn ที่มี Priority ต่ำสุดและเปิดใช้ (ไม่ตรวจ hazard), spawn protection 3s, Team Wipe `AllDowned`, ถ้าเหลือคนเดียวกลาง Match (เพื่อนออก): ล้ม = Eliminated | Systems |
| Speed | Server ตั้ง `SpeedMult` / `MoveMode`, client เขียน WalkSpeed (16 × SpeedMult, Downed 5, Pinned 0) (5.5 ไม่มีวิ่ง ไม่ตรวจระยะ) | Systems |
| Disaster | Stage system 4 ขั้น + fast-forward (4.1), Earthquake: Pulse, TelegraphedImpact floor-aware (ข้อ 1–4, 6–7), MoveModifier, ScreenEffect shake, debris แบบภาพ (`propCollides = false`), `NoImpact` รอบ spawn | Scripter (server), UI (VFX client) |
| Extraction / Win-Lose | ETA 60s, กรงหย่อนลงมา, Departure 10s (หยุดชั่วคราวเมื่อมีคนออกจากโซน), Last call 45s, ชนะ / แพ้ Collapse / แพ้ Wipe, ลำดับตรวจ (5.8) | Scripter |
| HUD (8 ชิ้น) | (1) Stage + timer + Banner ชื่อภัย (2) รายการ objective + progress + ถ่าน x/N (3) **world marker** (anchor/socket ของ Step ปัจจุบัน, Exit Zone หลังปลดล็อก, เพื่อนที่ Downed) แบบ Billboard AlwaysOnTop + ระยะ (4) Billboard บน anchor: progress, "Held 2/3", "Override engaged" (5) แถบ HP (6) Overlay Downed (bleed-out) / Eliminated (นับถอยหลัง respawn) (7) ETA / Departure / Last call (8) Result screen — ใช้ `Scale` ไม่ใช่ `Offset` เพื่อรองรับมือถือ | UI |
| Character | แฮมสเตอร์ v1: R15 ขนาดมาตรฐาน สีน้ำตาลทอง + หู/หาง/แก้มเป็น accessory (mesh จาก Toolbox หรือ Part) ตั้งเป็น `StarterCharacter`, Downed = นอนตะแคง + ดาวหมุน (ParticleEmitter/Billboard), Eliminated = เอฟเฟกต์ "ปุ๊ฟ" (ParticleEmitter ขนฟู) | Art |
| Props | วงล้อ + ไดนาโม, ถ่าน AA (Part ทรงกระบอก + แสงกะพริบ + เสียง loop), แท่นชาร์จ, วิทยุของเล่น ×4, debris (แอปเปิล, กระป๋อง, ฟองน้ำ), กรงสัตว์เลี้ยงห้อยเชือก, ของประกอบฉากยักษ์ (ตู้เย็น, โต๊ะ, เก้าอี้, ชั้นรองเท้า) ทำจาก Part เปล่า | Art + Level |
| Audio | ไซเรน, เสียงสั่นสะเทือน, "โป๊ก!", เสียงจี๊ด, เสียงถ่าน, วิทยุซ่า, เสียงเชือก/กรง, เพลงชนะ/แพ้ (Roblox audio library ที่ใช้ได้ฟรี) | Art/Audio |
| Lighting | Preset กลางคืน 4 ขั้นตาม Stage (ปรับ `Lighting.Ambient` / `ColorCorrection`) | Art/Audio |
| Rescue Moment | ตาม 8.6.1 | Scripter (data + trigger), UI (กล้อง/ซ่อน HUD), Art/Audio (ไฟ/เสียง/กรง) |


#### 8.6.1 "Rescue Moment" — ฉากที่ต้องถ่ายวิดีโอได้สวย
ทุกส่วนเป็น data + client visual ไม่มีระบบใหม่ฝั่ง server นอกจาก Pulse เพิ่ม 1 รายการ

| จังหวะ | เกิดอะไร | ทำด้วยอะไร |
|---|---|---|
| ทางออกปลดล็อก (เข้า Critical) | **Big Shake**: เพิ่ม Pulse 1 รายการใน `Earthquake.stages.Critical` (firstDelay 0, interval 999 = ครั้งเดียว, duration 4s) ลูก: (ก) `TelegraphedImpact` `NearPlayer` ทุก 0.4s, telegraph 1.5s, **damage 15** (ดูอลังการแต่ไม่ wipe ทีม) (ข) `TelegraphedImpact` `RandomPoint` ทุก 0.15s, **damage 0** (ของร่วงทั่วครัวเพื่อภาพ) + shake แรงสุด | Data เท่านั้น — `RandomPoint`: สุ่ม x,z ภายใน bounds ของแมพ แล้ว raycast ลงจาก Y = +120 หาพื้นแรกที่ `CanQuery` ไม่อยู่ใน `NoImpact` (ไม่ต้องเทียบ ΔY กับเป้าหมาย) |
| ช่วง ETA 60s | ไฟกู้ภัยสีแดง/น้ำเงินสลับกันสาดผ่านหน้าต่าง (SpotLight 2 ดวงหมุนนอกหน้าต่าง), เสียงไซเรนใกล้เข้ามา, บานหน้าต่างเปิดค้าง ลมพัดผ้าม่าน | Lighting preset `Critical` + โมเดลไฟนอกหน้าต่าง (client tween) |
| ETA ครบ | กรงสัตว์เลี้ยงหย่อนลงมาจากด้านบนด้วยเชือกใน 3s มีลำแสงไฟฉายส่องตามลงมา + เสียงเพลงสั้นๆ "ฮีโร่มาแล้ว" | Client tween ของ `exitVehicleAsset` จาก +60 → `ExitVehicleSpot` (server ตั้ง `Open = true` หลัง tween 3s) |
| ชนะ | กล้องของทุกคน tween ไปมุมนอกหน้าต่าง 3s: กรงถูกดึงขึ้นพร้อมแฮมสเตอร์โบกมือ ส่วนครัวด้านหลังยังสั่นและของยังร่วง จากนั้นค่อยขึ้น Result | Client: `Camera.CameraType = Scriptable` + tween ไปที่ Part `WinCameraPoint` (Level วาง), server หน่วง Result 3s |
| ถ่ายวิดีโอ | ปุ่ม **H = ซ่อน/แสดง HUD ทั้งหมด** (client เท่านั้น) และ marker ยังซ่อนตามได้ | UI |

ค่าใหม่: `WIN_CINEMATIC_TIME = 3`, `CARRIER_DESCEND_TIME = 3`, `BIG_SHAKE_DURATION = 4`, `BIG_SHAKE_DAMAGE = 15`, `HUD_TOGGLE_KEY = H` | Part ใหม่ในแมพ: `WinCameraPoint` (ไม่ใช่ tag ชื่อธีม ใช้ซ้ำได้ในทุกแมพ)

**ค่าที่ต่างจากหัวข้อ 9 (Deadline overrides)**

| Key | ค่าเต็ม (หัวข้อ 9) | Deadline build |
|---|---|---|
| `MIN_PLAYERS_TO_START` | 2 | 2 (ไม่มี solo start) |
| `DEV_MIN_PLAYERS_STUDIO` | (ไม่มี) | 1 — ใช้เฉพาะใน Studio (`RunService:IsStudio()`), ไม่มีผลบน live |
| `SPRINT_SPEED` / Stamina | 24 / มี | ไม่มี (เดิน 16 อย่างเดียว) |
| ปุ่ม Drop | มี | ไม่มี (ของตกเองเมื่อล้ม/ออกจากเกม) |
| `DeliverBatteries.maxCount` | 4 | 3 (มี 3 โซน) |
| `CallForHelp.holdTime` | 30 | 45 (ชดเชยที่ตัด Step 3) |
| `WindowLatches` | Step 3 | ไม่มี |
| `RESPAWN_BASE` / `STEP` / `MAX` | 20 / 10 / 40 | 15 / 0 / 15 |
| Respawn spawns | 3 กลุ่ม + ตรวจ hazard | พื้น ×4 (Priority 2), ขอบหน้าต่าง ×2 (Priority 1, `EnabledBy = WindowOpen`) ไม่ตรวจ hazard |
| Debris `propCollides` / lifetime | true / 6s | **false / จางหายใน 3s** |
| `NoBlockingProp` | ใช้ | ไม่ใช้ |
| `INACTIVE_AFTER` (Match) | 60 | ไม่ใช้ (มีแค่ AFK filter ใน Lobby 60s) |
| `ITEM_IDLE_RESPAWN` | 45 | ไม่ใช้ (KillY อย่างเดียว) |
| ตรวจระยะเคลื่อนที่ฝั่ง server | มี | ไม่มี |

### 8.7 Stretch (ทำหลัง CP3 เท่านั้น และเฉพาะเมื่อ Boss ตัดสินว่า "Go" ตอน 22:30 ของวันที่ 24)
1. **Flood**: ใส่ `"Flood"` เข้ารายการ disasters + RisingVolume + Slowed/Submerged + Breath HUD (4.3.2) แมพ Deadline cut: Level 0 = พื้นครัว (Y 0), Level สูงสุด = +9 (พื้นจมมิดหัวตอน ~3:00) เคาน์เตอร์ไม่ท่วม
2. Screen shake ที่แรงขึ้น / เสียงประกอบเพิ่ม
3. Step 3 `WindowLatches` แบบ Cumulative (แก้แค่ data + วาง anchor 4 จุด)

### 8.8 หลังส่งงาน (post-deadline) — ยังไม่ทำตอนนี้
- **ระบบ**: Inactive ใน Match, MultiHold **Continuous**, วิ่ง + stamina, ปุ่ม Drop, idle respawn ของ item, ตรวจระยะเคลื่อนที่ฝั่ง server, respawn delay ที่เพิ่มขึ้น (20/30/40) + selector ที่ตรวจ hazard, debris ที่ชนผู้เล่นได้ + `NoBlockingProp` + `DebrisNoPlayer`, RouteCollapse + RecoveryPoint, spectate สลับคน
- **คอนเทนต์**: แมพครัวเต็ม (มุมซักผ้า −3, ชั้นล่าง +4, pantry, โซน K, `CerealTower`/`DishRack`), Step สลักหน้าต่าง, Flood (ถ้าไม่ได้ทำใน stretch), Wildfire, Storm, `HeavyCarry`, `Rescue` + NPC, แมพที่ 2
- **Meta**: DataStore, Seeds, Shop, Cosmetics, Practice solo mode เต็มรูปแบบ, Tutorial, Settings, Analytics, Localization ไทย, Console
- **ขัดเกลา**: animation/VFX จริง, โมเดลแฮมสเตอร์ custom rig, Lobby กรงยักษ์
- ลำดับที่แนะนำหลังส่งงาน: Inactive → Continuous + Step 3 → วิ่ง/Drop → แมพเต็ม + RouteCollapse → Flood → DataStore/Seeds/Shop

### 8.9 แผนทำงานรายชั่วโมง (เวลากรุงเทพฯ, H0 = 23:00 วันที่ 23 ต.ค.)

**กติกา**:
- ชั่วโมงแรก ทุก agent ใช้ **Deadline contract** ร่วมกัน: รายชื่อ Remote + payload, Attribute ทั้งหมด (`State`, `HP`, `SpeedMult`, `MoveMode`, `Progress`, `Held`, `Required`, `Override`, `Open`, ค่า Stage/เวลาบน `ReplicatedStorage`), tag ตาม 8.3, Config keys หลังจากนั้นแต่ละฝ่ายทำงานคู่ขนานกันได้โดยไม่ต้องรอกัน
- ช่วงที่ Boss นอน agent ทำเฉพาะงาน**โค้ด/เอกสารใน repo** (ไม่ต้องใช้ Studio) แล้ว Boss sync และเทสต์ตอนตื่น — **โค้ดทุกชิ้นต้องผ่าน `luau-analyze` (`--!strict` ไม่มี type error) + `selene` lint และ QA ตรวจเทียบ Deadline contract ก่อน 09:00 จึงจะให้ Boss sync** ถ้าต่อ Studio MCP ได้ ให้เปิด Studio ทิ้งไว้เพื่อให้ agent สั่ง playtest เองได้
- **CP (checkpoint)** = Boss เล่นเทสต์เอง ถ้าไม่ผ่าน ใช้ลำดับตัด (8.10) ทันที **ห้ามเลื่อน CP3 (Feature freeze 21:00)** และ **ห้ามเลื่อน Code freeze (25 ต.ค. 08:00)**
- คอลัมน์ "Lead" = agent หลักที่เขียนเอกสารส่งงานและ storyboard วิดีโอ (8.12)

| เวลา (BKK) | H | Scripter | Systems | UI | Level | Art/Audio | QA | Lead (docs/video) | Boss |
|---|---|---|---|---|---|---|---|---|---|
| 23 ต.ค. 23:00–00:00 | 0–1 | อ่าน contract, โครง RoundService | **Deadline contract**, Rojo, Config/Data, `Remotes.luau`, debug commands | โครง ScreenGui | Blockout พื้น 160×120 + ผนัง + เคาน์เตอร์ตัว L | สเปกแฮมสเตอร์ + รายการ asset (เลือกเสียง/asset จากคลังที่ใช้ได้กับ place นี้แน่นอน) | checklist CP0–CP4 | — | สร้าง place, ต่อ Rojo + GitHub, publish เป็น private place + **compliance (~20 นาที)**: กรอกแบบสอบถาม Maturity & Compliance ใน Creator Hub, ตั้ง Genre, อุปกรณ์ Computer/Phone/Tablet, Max players 4, ตรวจว่า audio/asset ใช้ได้ |
| 00:00–02:00 | 1–3 | Round flow (Lobby, intermission ≥ 2 คน + `DEV_MIN_PLAYERS_STUDIO`, clone/ล้างแมพ, Result) | HP attr, ปิด autoload/reset/Dead, LoadCharacter ใน Lobby | Stage + timer, รายการ objective | ทางลาด, ผ้าม่าน, ขอบหน้าต่าง, วาง spawn/anchor/ItemSpawn + tags, `WinCameraPoint` | แฮมสเตอร์ v0 เป็น `StarterCharacter` | — | — | **CP0 (02:00)**: Rojo sync ได้, เดินแฮมสเตอร์บนแมพได้, Round เริ่ม-จบได้ |
| 02:00–09:00 (Boss นอน) | 3–10 | Server-timed hold, Repair, Deliver, MultiHold Cumulative + override + fallback คนออก, Mission runner, Extraction/Departure/Last call, ชนะ/แพ้ | Downed/Revive/Pinned, respawn 15s, Wipe, ItemService, `SpeedMult` | Markers, Billboard anchor, HP, overlay, ETA/Departure, Result, ปุ่ม H ซ่อน HUD | `docs/levels/MidnightKitchen-deadline.md` | รายการเสียง + asset ID, สเปก prop/ดาวหมุน/ปุ๊ฟ/ไฟกู้ภัย/กรง, lighting 4 preset | ตรวจโค้ดเทียบ GDD + CONVENTIONS | โครงเอกสารส่งงาน (หัวข้อ, สรุปโปรเจกต์, workflow agent จาก TEAM.md) | นอน |
| 24 ต.ค. 09:00–12:00 | 10–13 | Sync + แก้บั๊ก mission | Sync + แก้บั๊ก player/items | ต่อ HUD กับ Attribute จริง | ปรับแมพตามผล CP0 | Prop ใน Studio | เทสต์ 2 clients (+ 1 client ด้วย DEV_MIN_PLAYERS_STUDIO) | วิธีเล่น (how to play) ร่าง 1 | **CP1 (12:00)**: Lobby → Step 1 → Step 2 → ETA → ชนะ ได้ (ยังไม่มีภัย) ด้วย 2 clients |
| 12:00–13:00 | 13–14 | พัก / buffer | | | | | | | |
| 13:00–17:00 | 14–18 | Stage system + Earthquake + Big Shake (data) | ต่อ damage → Downed → Revive/Respawn, Wipe, cleanup ข้ามรอบ | Banner, วงเตือน + debris (VFX), shake, overlay Downed | `NoImpact` รอบ spawn, ตรวจว่า raycast เจอพื้นทุกจุด | แฮมสเตอร์ v1, ดาวหมุน, ปุ๊ฟ, เสียงทั้งหมด | เทสต์ 3–4 clients | **Storyboard + shot list + บทบรรยายวิดีโอ** (8.12) ส่งก่อน 18:00 | **CP2 (17:00)**: Match เต็มพร้อม Earthquake, ล้ม/revive/respawn, แพ้ Collapse และ Wipe ได้ |
| 17:00–18:00 | 18–19 | พัก / buffer | | | | | | | อ่าน storyboard (10 นาที), นัดเพื่อนสำหรับ 21:00 |
| 18:00–21:00 | 19–22 | จูนตาม CP2, edge case (ออกกลาง Match → fallback) | ตรวจ validation ของ Remote, ตรวจ leak ข้ามรอบ | Result, กล้องตอนชนะ, ทดสอบจอมือถือ (Device Emulator) | ตกแต่งฉากยักษ์, แสงกลางคืน | Rescue Moment: ไฟกู้ภัยนอกหน้าต่าง, กรงหย่อน + ไฟฉาย, เพลงชนะ/แพ้ | Regression, มือถือ | เอกสารร่าง 2 (ใส่ placeholder รูป) | **CP3 (21:00) = FEATURE FREEZE**: ทุกอย่างใน 8.6 + Rescue Moment ทำงาน → **เปิด public ครั้งแรก** (เทสต์ live ล่วงหน้า) |
| 21:00–22:30 | 22–23.5 | แก้บั๊กสด | แก้บั๊กสด | แก้บั๊กสด | — | **ถ่าย screenshot** 8–10 รูป (ตาม list ของ Lead) | จับเวลา + จดบั๊ก | — | **Playtest ผู้เล่นจริง + ถ่าย footage ดิบ** บน live place ที่เพิ่งเปิด (Boss + เพื่อน ≥ 1, ≥ 3 Match, มือถือ ≥ 1) อัดหน้าจอทุก Match ตาม shot list (ทีม 2 ตัวเป็นหลัก) |
| 22:30–01:00 | 23.5–26 | ถ้า Go: Flood (server) / No-go: แก้บั๊ก | แก้บั๊กจาก playtest | ถ้า Go: Breath HUD + น้ำ tween | ถ้า Go: `VolumeLevel` | ขัดเสียง/แสง, icon + thumbnail ของเกม | สรุปเวลาเทียบ 8.5 + จัดบั๊ก Blocker/Major/Minor | ใส่ screenshot ลงเอกสาร | 22:30 ตัดสิน **Go/No-go** stretch (Go เฉพาะเมื่อ CP2 และ CP3 ผ่านตรงเวลา), 23:00–00:00 **ตัดวิดีโอร่างแรก** จาก footage ดิบ, 01:00 sync |
| 25 ต.ค. 01:00–07:00 (Boss นอน) | 26–32 | แก้เฉพาะบั๊ก (ไม่เพิ่ม feature) | แก้เฉพาะบั๊ก | แก้เฉพาะบั๊ก | — | คำอธิบายเกมบนหน้า Roblox (ต้องมี "Needs 2–4 players / ต้องเล่น 2–4 คน") | smoke test checklist สุดท้าย | เอกสารฉบับเกือบสมบูรณ์ + ข้อความที่ขึ้นบนจอในวิดีโอ | นอน |
| 07:00–08:00 | 32–33 | — | — | — | — | — | Regression เต็มรอบ | — | Sync งานสุดท้าย, ถ้า Flood ไม่เสถียร → เอาออกจากรายการ disasters (แก้ data 1 บรรทัด) → **08:00 CODE FREEZE** |
| 08:00–09:00 | 33–34 | standby: แก้เฉพาะ Blocker | | | | | **CP4**: เล่นบน live server 2 คน (PC + มือถือ) จนจบ, ยืนยันว่าคนเดียวบน live รอ "Waiting for players (1/2)" ไม่เริ่มเอง | ใส่ลิงก์เกมลงเอกสาร | **Publish เวอร์ชันสุดท้าย** (ตั้งค่า public/compliance ทำไว้แล้วตั้งแต่ H0 และ CP3, อัปเดต icon/thumbnail/คำอธิบาย) + **playtest บน live place** |
| 09:00–10:30 | 34–35.5 | — | — | — | — | — | — | — | **วิดีโอ**: ถ่ายช็อตเพิ่ม (pickup) บน live place 20 นาที → ตัดต่อจบ + บรรยาย/ข้อความ 60 นาที → export + อัปโหลด 10 นาที |
| 10:30–11:15 | 35.5–36.25 | — | — | — | — | — | ตรวจเอกสารเทียบกับเกม live | ใส่ลิงก์วิดีโอ + export เอกสารเป็น PDF | ตรวจเอกสารครั้งสุดท้าย |
| 11:15–11:30 | 36.25–36.5 | | | | | | | | **ส่งงานทั้ง 3 อย่าง** (เกม + เอกสาร + วิดีโอ) |
| 11:30–12:00 | | | | | | | | | **Margin 30 นาที** (อินเทอร์เน็ต/อัปโหลดมีปัญหา) |

**สรุปการใช้เวลา**:
- Build ถึง feature freeze: 23:00–21:00 = 22 ชั่วโมง (Boss ตื่น ~14 ชั่วโมง + agent ทำโค้ด/เอกสารคู่ขนานระหว่าง Boss นอน ~7 ชั่วโมง, พัก 2 ชั่วโมง) — งาน build ทั้งหมด ~30 ชั่วโมง-agent ถ้านับคู่ขนาน
- Playtest + แก้บั๊ก + stretch: 21:00–01:00 และ 07:00–08:00 ≈ 5 ชั่วโมง
- **ส่งงาน (publish + live test + วิดีโอ + เอกสาร + ส่ง)**: 08:00–11:30 = 3.5 ชั่วโมงที่จองไว้ + footage ดิบและตัดร่างแรกตั้งแต่คืนวันที่ 24 + เอกสารที่ Lead เขียนคู่ขนานตลอดวันที่ 24

### 8.10 ลำดับตัด (ถ้า CP ไหนไม่ผ่านตามเวลา)
1. Stretch ทั้งหมด (Flood) → No-go
2. Last call (เหลือ: กรงออกเมื่อทุกคนที่ไม่ Eliminated อยู่ในโซน)
3. Emergency override
4. กล้องตอนชนะ (เหลือ: Result ขึ้นทันที)
5. Lighting ต่อ Stage (คงไว้เฉพาะ preset Critical + ไฟกู้ภัย)
6. แฮมสเตอร์ v1 → ใช้ v0
7. Team Wipe (เหลือแพ้แบบ Collapse อย่างเดียว)
8. Floor-aware raycast → ใช้ Y ของเท้าเป้าหมายตรงๆ

**ห้ามตัดเด็ดขาด (ขั้นต่ำที่ส่งได้)**: Lobby → Match → 3 objective (รวม MultiHold) → ETA → ชนะ/แพ้, Earthquake ทำ damage + **Big Shake + กรงหย่อนลงมา** (ฉากสำหรับวิดีโอ), Downed/Revive, respawn, HUD (1)(2)(3)(8) + ปุ่มซ่อน HUD, แฮมสเตอร์ v0, เล่นบนมือถือได้
**ห้ามเอาเวลาของบล็อก 08:00–11:30 ไปทำ build** ถ้าเกมยังมีบั๊กตอน 08:00 ให้ publish เวอร์ชันล่าสุดที่ผ่าน CP3/CP4 แล้วระบุบั๊กที่รู้ในเอกสาร

### 8.11 Definition of Done (Deadline)
**Studio (Test → Clients and Servers)**
- 2 และ 4 clients เล่นจบ 3 Round ติดกัน (1 client ใช้ได้เฉพาะกับ `DEV_MIN_PLAYERS_STUDIO = 1`) ไม่มี error และไม่มีแมพ/instance ค้างข้ามรอบ
- เกิดทั้ง ชนะ, แพ้ Collapse, แพ้ Wipe
- วิทยุต้องกดพร้อมกันครบทุกคนที่ไม่ Eliminated (2 clients = 2 คน) และหลัง 75s ทีม 3–4 คนใช้น้อยลง 1 คนได้
- Impact ตกโดนผู้เล่นได้ทั้งบนพื้น, ทางลาด, เคาน์เตอร์ และขอบหน้าต่าง แต่ไม่ตกในรัศมี 6 studs รอบ spawn
- Big Shake ไม่ทำให้ทีมที่ HP เต็มล้มทั้งทีม (damage 15 ต่อครั้ง)
- ปุ่ม Reset ใช้ไม่ได้ และตัวละครไม่เกิดใหม่เอง
- **ผู้เล่นที่เหลือคนเดียว (เพื่อนออกกลาง Match) ถูก Eliminated ระหว่างรอกรง**: Departure ไม่นับจนกว่าจะ respawn และเข้าโซน แล้วจบเป็นชนะได้ (หรือแพ้ Collapse ถ้าไม่ทัน) ไม่มี Match ที่จบด้วย Escaped = 0 แบบไม่มีผล
- **ยืนบน spawn ขอบหน้าต่างช่วง ETA แล้วต้องโดน impact**
- คนเดียวใน Lobby บน live: ไม่เริ่ม Match (แสดง "Waiting for players (1/2)"), คนที่ 2 เข้ามา → นับ 30s แล้วทั้งคู่เข้า Match
- เพื่อนออกกลาง Match 2 คน → คนที่เหลือเล่นต่อจนจบได้ (fallback 3.5)
- Debug commands ใช้ไม่ได้บน live สำหรับบัญชีที่ไม่ใช่ dev

**ผู้เล่นจริง (Studio multi-client ใช้แทนไม่ได้ เพราะ dev คนเดียวคุมทุก client)**
- Private place, ผู้เล่นจริง ≥ 2 คน, ≥ 3 Match: ทีม typical จบในช่วง 3:30–5:30 ถ้าไม่ผ่าน จูน `CallForHelp.holdTime` / `RunWheel.duration` / ETA
- มือถือ ≥ 1 เครื่อง: เดิน, กระโดด, แตะ prompt, อ่าน HUD ได้

**ส่งงาน**
- (1) เกม public เข้าได้ทั้ง PC และมือถือ และเล่น 2 คนจนจบได้บน live server (เปิด public ครั้งแรกตอน CP3 ไม่ใช่เช้าวันส่ง)
- (2) เอกสารส่งงานครบทุกหัวข้อใน 8.12 พร้อม screenshot ≥ 6 รูป และลิงก์เกม/วิดีโอใช้งานได้
- (3) วิดีโอ 60–90s มี Rescue Moment และตอนชนะ อัปโหลดแล้วเปิดได้จากลิงก์

### 8.12 เอกสารส่งงานและวิดีโอ

**เอกสาร** (`docs/submission/SUBMISSION.md` → export PDF) — Lead เขียน, Boss ตรวจ

> **ต้องเขียนชัดเจนทั้งในคำอธิบายหน้าเกม Roblox และในเอกสารส่งงาน (หัวข้อสรุปและวิธีเล่น): "ต้องเล่น 2–4 คน / Needs 2–4 players"** เพราะเกมไม่เริ่มถ้ามีคนเดียว (แนะนำให้กรรมการชวนเพื่อนอีก 1 คน หรือเข้า server พร้อมกัน)
>
> **เนื้อหาในเอกสารส่งงานต้องมาจากหัวข้อ 8** (แมพ Deadline cut, 2 Step + Extraction, Lobby แบบแท่น, pacing 8.5) ห้ามใช้ pitch/timeline 3 Step/Lobby กรงยักษ์จากหัวข้อ 1–2 ซึ่งเป็นแมพเต็มหลังส่งงาน
| หัวข้อ | เนื้อหา | ที่มา |
|---|---|---|
| สรุปโปรเจกต์ | ชื่อเกม (We R in Trouble / Roblox Hamster Conquror the world), pitch 2–3 บรรทัด, **"ต้องเล่น 2–4 คน / Needs 2–4 players"**, กลุ่มเป้าหมาย, ลิงก์เกม, ลิงก์วิดีโอ | หัวข้อ 1 |
| วิธีเล่น | **ต้องมีผู้เล่น 2–4 คน**, ปุ่ม (เดิน/กระโดด/E หรือแตะ), เป้าหมาย 2 Step + Extraction, Downed/Revive, ชนะ/แพ้ — แบบสั้น มีรูปประกอบ | 8.4, 5 |
| ฟีเจอร์เด่น | co-op ที่บังคับจริง (วิทยุ), ภัยแบบสุ่ม + 4 Stage, Rescue Moment, รองรับมือถือ, ระบบที่เปลี่ยนธีมได้ด้วย data | 3, 4, 10 |
| ทีมและ workflow ของ agent | Boss + บทบาท agent ตาม TEAM.md, เส้นทางงาน (โจทย์ → ทำ → review → แก้ ≤ 2 รอบ → Boss), ตัวอย่างจริง: GDD ผ่าน review 2 รอบ (FAIL → PASS WITH FIXES), Rojo + GitHub | TEAM.md, `docs/reviews/` |
| Screenshots | 6–10 รูป: Lobby, แฮมสเตอร์บนพื้นครัวเทียบกับโต๊ะยักษ์, วิ่งวงล้อ, ถือถ่าน, กดวิทยุ 4 ตัวพร้อมกัน, วงแดง + ของตก, เพื่อนกำลัง revive ตัวที่มึน, Rescue Moment, Result ชนะ | ถ่าย 21:00–22:30 |
| ข้อจำกัดและแผนต่อ | สิ่งที่อยู่ใน "หลังส่งงาน" (8.8) + บั๊กที่รู้ | 8.8, QA |

**วิดีโอ** (60–90s, 1080p, แนวนอน) — **storyboard หลักใช้แฮมสเตอร์ 2 ตัว** (Boss + เพื่อน 1 คน) ส่วนช็อต 4 ตัวเป็นตัวเลือกถ้าหาคนได้ครบ หรือถ่าย Billboard "Held 4/4" ใน Studio ด้วย `spawnDummyHolder` — Lead เขียน storyboard/shot list/บทบรรยายก่อน 18:00 วันที่ 24 ส่วน Boss อัดในเกม (OBS หรือตัวอัดของ Roblox, ซ่อน HUD ด้วยปุ่ม H เมื่อต้องการ) และตัดต่อ
| # | ช่วง (s) | ช็อต | ข้อความบนจอ/บรรยาย (แนวทาง) |
|---|---|---|---|
| 1 | 0–5 | โลโก้/ชื่อเกม บนภาพครัวมืดๆ จากมุมแฮมสเตอร์ | ชื่อเกม |
| 2 | 5–15 | แฮมสเตอร์ 2 ตัวโผล่จากกรงที่ล้ม (ทางเลือก: 4 ตัว) กล้องแพนขึ้นไปเห็นโต๊ะ/ตู้เย็นยักษ์ | "คุณคือแฮมสเตอร์… ในบ้านที่กำลังเจอภัยพิบัติ" |
| 3 | 15–28 | วิ่งวงล้อ + ถือถ่านไปเสียบ (ตัดสลับ) | "ช่วยกันปั่นไฟ หาถ่าน" |
| 4 | 28–38 | Banner "EARTHQUAKE!", วงแดง, แอปเปิลตก "โป๊ก!" | "ภัยพิบัติสุ่ม รุนแรงขึ้นเรื่อยๆ" |
| 5 | 38–50 | 2 ตัวกดวิทยุคนละเครื่องพร้อมกัน แสดง "Held 2/2" แบบ split-screen ทั้ง 2 มุม (ทางเลือก: 4 ตัวจริง "Held 4/4" หรือ insert shot จาก Studio + dummy holder) | "ต้องช่วยกันทั้งทีมเท่านั้น" |
| 6 | 50–58 | ตัวหนึ่งมึน ดาวหมุน แล้วเพื่อนวิ่งมา revive | "เพื่อนล้ม ต้องกลับไปช่วย" |
| 7 | 58–78 | **Rescue Moment**: หน้าต่างเปิด, Big Shake, ไฟกู้ภัยแดง/น้ำเงิน, กรงหย่อนลงมา, ทุกตัววิ่งเข้ากรง (HUD ซ่อน) | ไม่มีบรรยาย ใช้เพลง + เสียงเกม |
| 8 | 78–90 | กล้องตอนชนะ แล้วต่อด้วย Result + ชื่อเกม + "Play now on Roblox" + ลิงก์ | Call to action |

---

## 9. Tuning table (ค่าเริ่มต้นสำหรับ playtest ทั้งหมด)

| Config key (แนะนำ) | ค่า | หน่วย | หมายเหตุ |
|---|---|---|---|
| **World** | | | |
| สเกลแมพ (สำหรับ Level/Art ไม่ใช่โค้ด) | 1 stud = 2 cm | | 1.1 |
| **Round** | | | |
| `MAX_PLAYERS` | 4 | คน | (รอ Boss ยืนยัน Q1-ก) |
| `MIN_PLAYERS_TO_START` | 2 | คน | Boss ตัดสินแล้ว (ไม่มี solo start) |
| `DEV_MIN_PLAYERS_STUDIO` | 1 | คน | ใช้เฉพาะเมื่อ `RunService:IsStudio()` บน live ไม่มีผล |
| `INTERMISSION_TIME` | 30 | s | |
| `BRIEFING_TIME` | 5 | s | อยู่ใน Calm |
| `RESULT_TIME` | 15 | s | |
| `MATCH_HARD_LIMIT` | 420 | s | 7:00 Collapse (รอ Boss ยืนยัน Q1-ข) |
| `LAST_CHANCE_WARNING_AT` | 320 | s | 5:20 ถ้า Step สุดท้ายยังไม่เสร็จ |
| `LOBBY_OFFSET_X` | 3000 | studs | |
| `LOBBY_RELOAD_DELAY` | 2 | s | ตัวละครใน Lobby หาย/ตาย |
| `DISASTER_NO_REPEAT` | true | bool | ห้ามได้ภัยเดิมซ้ำ 2 รอบติด |
| **Stages** | | | |
| `STAGE_CALM` / `STAGE_WARNING` / `STAGE_ACTIVE` | 30 / 15 / 165 | s | Critical ตามเวลาที่ 3:30 |
| `EXIT_UNLOCK_FORCES_CRITICAL` | true | bool | |
| `WARNING_BANNER_MIN` | 3 | s | |
| **Extraction** | | | |
| `exitArrivalDelay` (MissionDef) | 60 | s | (รอ Boss ยืนยัน Q1-ข) |
| `DEPARTURE_COUNTDOWN` | 10 | s | หยุดชั่วคราวเมื่อเงื่อนไขหลุด |
| `LAST_CALL_AFTER` | 45 | s | หลังกรงมาถึง |
| `LAST_CALL_QUORUM` | 0.5 (ปัดขึ้น) | สัดส่วนของ activeCount | (รอ Boss ยืนยัน Q2) |
| `EXIT_ZONE_SIZE` | 24 × 24 | studs | |
| **Player** | | | |
| `MAX_HP` | 100 | HP | |
| `SPAWN_PROTECTION` | 3 | s | |
| `WALK_SPEED` / `SPRINT_SPEED` | 16 / 24 | studs/s | |
| `STAMINA_MAX` / `DRAIN` / `REGEN` | 100 / 25 / 20 | — / ต่อ s / ต่อ s | |
| `STAMINA_REGEN_DELAY` / `STAMINA_MIN_TO_SPRINT` | 1.0 / 20 | s / — | |
| `MIN_MOVE_SPEED` | 6 | studs/s | |
| `MOVE_SAMPLE_INTERVAL` / `MOVE_WINDOW` | 0.5 / 2 | s | |
| `MOVE_TOLERANCE` / `MOVE_SLACK` | 1.1 / 4 | × / studs | |
| `KILL_Y` (แมพ #1) | −30 | studs | Attribute บน map root |
| **Downed / Respawn** | | | |
| `DOWNED_CRAWL_SPEED` | 5 | studs/s | ขณะถูก revive = 0 (Pinned) |
| `BLEED_OUT_TIME` | 30 | s | |
| `REVIVE_HOLD` / `REVIVE_PROMPT_RANGE` | 4 / 7 | s / studs | |
| `REVIVED_HP` / `REVIVE_PROTECTION` | 40 / 2 | HP / s | |
| `RESPAWN_BASE` / `RESPAWN_STEP` / `RESPAWN_MAX` | 20 / 10 / 40 | s | (รอ Boss ยืนยัน Q3) |
| `TEAM_WIPE_RULE` | `AllDowned` | enum | `AllDowned` / `NoneStanding` (รอ Boss ยืนยัน Q3) |
| **Activity** | | | |
| `INACTIVE_AFTER` (Match) / `LOBBY_AFK_AFTER` | 60 / 60 | s | หยุดนับขณะ Eliminated |
| `ACTIVITY_MOVE_THRESHOLD` | 2 | studs | |
| `ACTIVITY_PING_CLIENT_INTERVAL` / `SERVER_MIN_INTERVAL` | 10 / 5 | s | |
| **Interaction / Items** | | | |
| `INTERACT_RANGE` / `INTERACT_SERVER_RANGE` | 8 / 10 | studs | |
| `HOLD_TICK` | 0.1 | s | |
| `SMALL_CARRY_SPEED_MULT` | 0.9 | × | |
| `ITEM_KILLY_RESPAWN_DELAY` | 3 | s | |
| `ITEM_IDLE_RESPAWN` / `ITEM_IDLE_PLAYER_RADIUS` | 45 / 15 | s / studs | เฉพาะ item ที่เคยถูกหยิบ |
| `ITEM_DROP_RAY_DISTANCE` | 4 | studs | |
| `ITEM_HINT_RADIUS` | 30 | studs | แสง/เสียงของถ่าน |
| `HEAVY_CARRY_SPEED` / `HEAVY_MAX_SEPARATION` | 10 / 12 | studs/s / studs | M2 |
| **MultiHold** | | | |
| `MULTIHOLD_ASSIST_AFTER` | 75 | s | นับจากตอนที่ Step เปิด (รอ Boss ยืนยัน Q2) |
| `MULTIHOLD_ASSIST_MIN` | 2 | คน | override ลดได้ไม่ต่ำกว่านี้ |
| MultiHold anchor spacing (กฎแมพ) | ≥ 30 เส้นตรง | studs | |
| **Objectives (แมพ #1)** | | | |
| `RunWheel.duration` / `maxStack` | 45 / 2 | s / คน | ทางเลือก: 2 × 22s |
| `RunWheel.submergedRateMult` | 0.5 | × | |
| `DeliverBatteries.minCount` / `maxCount` | 1 / 4 | ก้อน | count = teamCount |
| `CallForHelp.anchorCount` / `holdTime` | 4 / 30 | — / s | Cumulative |
| `WindowLatches.anchorCount` / `holdTime` | 4 / 5 | — / s | Continuous (ถ้าตัด Continuous: Cumulative 8) |
| Repair credit threshold | 25 | % | |
| **Earthquake** | | | |
| Warning tremor | 3s, ×0.85 | | |
| Active pulse firstDelay / interval / duration | 5 / 20 / 5 | s | |
| Active pulse speed mult | 0.7 | × | |
| Active impact rate / count | ทุก 1.0s / ceil(standing/2) | | |
| Critical pulse firstDelay / interval / duration | 2 / 12 / 7 | s | |
| Critical pulse speed mult | 0.6 | × | |
| Critical impact rate | ทุก 0.7s | | |
| Impact telegraph (Active / Critical) | 1.5 / 1.2 | s | |
| Impact radius / damage | 5 / 30 | studs / HP | |
| Impact distance from target | 3–10 | studs | |
| Impact floor ray start / max ΔY floor / max ΔY hit | +6 / 4 / 6 | studs | |
| Impact reroll attempts | 5 | ครั้ง | |
| Impact drop start height (ภาพ) | 30 | studs | |
| `NO_IMPACT_SPAWN_RADIUS` | 6 | studs | |
| Debris lifetime | 6 | s | |
| RouteCollapse telegraph | 3 | s | stretch |
| `CerealTower` / `DishRack` delay | Active+30 / Critical+40 | s | stretch |
| **Flood (stretch)** | | | |
| riseRate Warning / Active / Critical | 0 / 0.067 / 0.067 | studs/s | |
| SurfaceY attribute update | 1 | s | client tween |
| Player check interval | 0.25 | s | |
| Slowed threshold / mult | เท้า +1.5 / 0.6 | studs / × | |
| Breath / drown dps | 8 / 10 | s / HP/s | |
| Downed submerged bleed mult | 2 | × | |
| Critical ceiling drips | ทุก 3s, telegraph 1.5s, r 4, 20 dmg | | |
| **Wildfire (M2)** | | | |
| Spread interval (Active / Critical) | 12 / 6 | s | |
| Burning dps (Active / Critical) | 15 / 20 | HP/s | |
| Max active ratio | 0.6 | | |
| Suppress hold / charges / immunity | 2 / 3 / 30 | s / ครั้ง / s | |
| **Storm (M3)** | | | |
| Gust (Active / Critical) | ทุก 15s นาน 3s 20 / ทุก 8s นาน 4s 30 | s / s / studs/s | |
| Lightning | ทุก 8s, telegraph 2s, r 4, 40 dmg | | |
| Vortex | 10 studs/s, ดูด r30 @15, core r8, 25 dmg, cd 4s | | |
| **Rewards (M2)** | | | |
| Participation / Win / Escaped / All escaped | 20 / 40 / 30 / 20 | Seeds | |
| Objective credit / cap | 10 / 30 | Seeds | |
| Revive / cap | 10 / 30 | Seeds | |
| Match cap / Daily first win | 150 / 50 | Seeds | |
| Inactive limit for reward | 90 | s | |

---

## 10. Theme B (Sci-fi) compatibility notes

แนวคิด: **แฮมสเตอร์บนสถานีอวกาศ** (ที่อยู่ของแฮมสเตอร์ทดลองในห้องแล็บบนสถานี) ยังเป็นแฮมสเตอร์ตัวจิ๋วในโลกของคน (สเกลเดิม 1 stud = 2 cm) โค้ดเหมือนเดิมทั้งหมด เปลี่ยนแค่ DisasterDef / MissionDef / ItemDef / แมพ / asset / string table ส่วน tag บนแมพเป็นชื่อ generic อยู่แล้ว (7.6)

| Theme A (ครัว) | Theme B (สถานีอวกาศ) | สิ่งที่ใช้ซ้ำ |
|---|---|---|
| Earthquake (ของบนชั้นร่วง) | Meteor impact (เครื่องมือแล็บและแผงเพดานร่วง) | Pulse + TelegraphedImpact + RouteCollapse |
| Flood (สายน้ำเครื่องซักผ้าแตก) | Coolant leak (น้ำยาหล่อเย็นท่วมพื้น) | RisingVolume + `Slowed` / `Submerged` |
| Wildfire (เครื่องปิ้งขนมปังไฟลุก) | Plasma fire / สไลม์เอเลี่ยนลาม | SpreadingZone + `Burning` + `SuppressZone` ("Foam gun") |
| Storm (ลมพัด/ลมหมุนใบไม้) | Hull breach (อากาศรั่ว ดูดเข้าหารู) | PushForce + MovingVortex (vortex อยู่กับที่), `SafeZone` = ห้องปิดผนึก |
| วงล้อ + ถ่าน AA | วงล้อปั่นไฟสถานี + power cell | Repair / Deliver |
| วิทยุของเล่น / สลักหน้าต่าง | เสาสัญญาณฉุกเฉิน / keycard terminal | MultiHold |
| ถ่าน 9V ก้อนยักษ์ | แกนพลังงาน | HeavyCarry |
| ลูกแฮมสเตอร์ใต้ตะแกรง | ลูกแฮมสเตอร์ใน cryo pod | Rescue |
| กรงที่นักดับเพลิงหย่อนลงมา + กระบะดอกไม้ | **ลูกบอลแฮมสเตอร์ escape pod** + docking port | `exitVehicleAsset` + `ExitVehicleSpot` + Extraction |
| Calm → Critical | Nominal → Alert → Breach → Meltdown | StageDef (ชื่อ/สี/เสียง) |

ข้อห้าม: ห้ามมีชื่อธีมใน logic code, ชื่อ tag หรือชื่อ attribute ชื่อธีมมีได้เฉพาะใน**ค่า**ของ data (เช่น `ItemType = "Battery"`, `GroupId = "DishRack"`) และใน asset/string table

---

## 11. Open questions for the Boss (สูงสุด 3 ข้อ)

Boss ตัดสินแล้ว: ผู้เล่นเป็นแฮมสเตอร์ในโลกสเกลคน, สุ่ม 1 ภัยต่อรอบ, กลุ่มเพื่อนทุกวัย เอกสารนี้ออกแบบครบตามคำตอบที่แนะนำด้านล่าง ถ้า Boss ตอบตามค่าแนะนำ ไม่ต้องแก้อะไร

**Q1. รูปแบบ Match** (ตอบแยกได้ทีละข้อย่อย)
- **ก. ขนาดทีม**: 2–4 คนต่อ server และต้องมี ≥ 2 คนจึงเริ่มได้
  → **แนะนำ: ใช่** เพราะทีมเล็กสื่อสารกันง่ายและแมพสร้างเร็ว ถ้าอยากได้ 6 คน ค่อยขยายใน M2 โดยเพิ่ม anchor/item
- **ข. ความยาว Match + ช่วงรอกรง**: Match ยาวสุด 7:00 (ทีมปกติจบ ~4:35–4:55) และหลังปลดล็อกหน้าต่างต้องเอาตัวรอด 60s ใน Critical ก่อนกรงจะมาถึง
  → **แนะนำ: ใช่** เพราะงานที่ขยายตามจำนวนคนทำให้ทุกทีมใช้เวลาใกล้เคียงกัน และช่วงรอทำให้ทุก Match จบด้วยช่วงที่ตื่นเต้นเสมอ (ตาราง 2.3)
- **ค. เล่นคนเดียวได้ไหม** — ✅ **Boss ตัดสินแล้ว (v0.5): ไม่มี solo start** Match เริ่มได้เมื่อ ≥ 2 คนเท่านั้น ใน Studio ใช้ `DEV_MIN_PLAYERS_STUDIO = 1` เพื่อเทสต์ หน้าเกมและเอกสารส่งงานต้องเขียน "ต้องเล่น 2–4 คน / Needs 2–4 players" ส่วน fallback เมื่อเพื่อนออกกลาง Match (3.5) ยังอยู่ (ไม่ใช่ solo mode) โหมดฝึกคนเดียวอยู่ในรายการหลังส่งงาน

จุดที่ได้รับผล: 1, 2.1, 2.3, 8.1, 8.6, 9 (`MAX_PLAYERS`, `MIN_PLAYERS_TO_START`, `DEV_MIN_PLAYERS_STUDIO`, `MATCH_HARD_LIMIT`, `exitArrivalDelay`)

**Q2. ความเข้มของ co-op**: แฮมสเตอร์ทุกตัวที่ยังไม่ปุ๊ฟต้องกดวิทยุ/สลักพร้อมกัน (ทีม 4 = 4 ตัว) และกรงจะออกเมื่อทุกตัวอยู่ในกรงแล้ว โดยมีตาข่าย 3 ชั้น:
- (1) คนที่ AFK 60s ไม่นับ
- (2) **Emergency override**: ถ้ามีเพื่อนไม่ยอมมาช่วยกดนาน 75s ระบบจะลดจำนวนที่ต้องกดลง 1 (ต่ำสุด 2 ตัว)
- (3) **Last call**: กรงรอครบ 45s แล้ว ครึ่งทีมก็ออกได้

→ **แนะนำ: ใช่ทั้งชุด** เพราะเกมยังรู้สึกว่า "ต้องช่วยกันทั้งทีม" แต่เด็กที่ยังไม่เข้าใจเกมหรือคนป่วนจะไม่ทำให้ทั้งทีมแพ้ ข้อแลกเปลี่ยน: ในทีม 2 คน override ใช้ไม่ได้ (ต่ำสุด 2) ถ้าเพื่อนยังขยับแต่ไม่ยอมช่วยจะชนะไม่ได้ แต่กลุ่มเป้าหมายคือกลุ่มเพื่อน จึงยอมรับความเสี่ยงนี้ได้

จุดที่ได้รับผล: 3.2, 3.4 MultiHold, 5.8, 5.10, 9 (`MULTIHOLD_ASSIST_AFTER`, `LAST_CALL_QUORUM`)

**Q3. กฎล้ม/ปุ๊ฟ**: respawn หลังรอ 20/30/40s และแพ้ทันที (Team Wipe) เมื่อ "ทุกตัวมึนพร้อมกัน" (ถ้ามีตัวที่รอ respawn อยู่ ทีมยังไม่แพ้) = `AllDowned`

→ **แนะนำ: ใช่ (`AllDowned`)** เพราะไม่มีใครต้องนั่งดูนาน และให้อภัยมากซึ่งเหมาะกับกลุ่มเพื่อนทุกวัย **ข้อควรรู้**: ด้วยกฎนี้ ทีม 3–4 คนจะ**แทบไม่แพ้แบบ Wipe เลย** เพราะมักจะมีอย่างน้อย 1 ตัวที่รอ respawn อยู่ แรงกดดันจึงมาจากนาฬิกาเป็นหลัก ถ้าอยากให้เข้มกว่านี้ให้เลือก `NoneStanding` (ไม่มีใครยืนอยู่ = แพ้ แม้จะมีคนรอ respawn) ซึ่งเปลี่ยนได้ด้วย Config ค่าเดียว

จุดที่ได้รับผล: 5.4, 5.8, 9 (`RESPAWN_*`, `TEAM_WIPE_RULE`)

---

## 12. Assumptions (สิ่งที่ผมตั้งเองและ Boss ยังไม่ได้ตัดสิน)

1. 1 server = 1 Match, Lobby (กรงยักษ์) อยู่ใน place เดียวกันห่าง 3,000 studs, ไม่ใช้ TeleportService ใน M1
2. การสุ่มภัยเป็นแบบเท่ากันและห้ามได้ภัยเดิมซ้ำ 2 รอบติด (ใน M1 core มีแค่ Earthquake กฎนี้จึงมีผลเมื่อมี Flood)
3. ไม่บอกชนิดภัยจนถึง Warning (0:30) และ Banner ต้องแสดงเสมอแม้จะข้าม Stage
4. ทางออกปลดล็อก → Stage เข้า Critical ทันที
5. สเกล 1 stud = 2 cm ตัวแฮมสเตอร์เป็น R15 ขนาดมาตรฐาน (การ์ตูนตัวโตกว่าของจริงเล็กน้อย) ยืนสองขา ไม่มี fall damage/PvP/friendly fire และปิดการชนระหว่างผู้เล่น
6. ข้อความในเกมเป็น**ภาษาอังกฤษ** สั้นและใช้ไอคอนช่วย รวมไว้ที่ string table เดียวเพื่อแปลไทยภายหลัง
7. แพลตฟอร์ม M1: PC + มือถือ (console ยังไม่รองรับ)
8. แมพ clone ใหม่ทุก Round จาก `ServerStorage.Maps`
9. น้ำท่วมใช้ Part โปร่งใสที่ client tween ตาม `SurfaceY` (ไม่ใช่ Terrain water และว่ายน้ำไม่ได้)
10. ไม่มี regen ใน M1 ส่วนรางวัล/เซฟเป็นงาน M2 ตาม TEAM.md
11. ถ่านไม่มี marker บน HUD (ใช้แสง/เสียงในระยะ 30 studs) เพื่อให้การค้นหาเป็นส่วนหนึ่งของเวลา Match ส่วน anchor อื่นทั้งหมดมี marker
12. นักดับเพลิงไม่ปรากฏตัว (เห็นแค่แสงไฟฉาย เชือก และกรง) เพื่อไม่ต้องทำโมเดลคน
13. ชื่อ "Seeds", ราคา cosmetic และตัวเลขทั้งหมดเป็น placeholder รอ playtest
14. ประมาณการเวลาใน 2.3 และ 8.5 ใช้ความเร็วเดิน 16 (ไม่นับวิ่ง) และ overhead ที่ผมประเมินเอง ต้องยืนยันด้วย playtest กับผู้เล่นจริง
15. แผนรายชั่วโมง (8.9) สมมติว่า Boss นอน ~6–7 ชั่วโมงต่อคืน, agent เขียนโค้ด/เอกสารใน repo ได้ระหว่างที่ Boss นอน, Boss หาเพื่อนมาเทสต์ได้ตอน 21:00 วันที่ 24 และมีโปรแกรมอัดหน้าจอ/ตัดต่อพร้อม
16. รูปแบบเอกสารส่งงาน (Markdown → PDF) และสเปกวิดีโอ (60–90s, 1080p) เป็นค่าที่ผมเลือกเอง ถ้าผู้จัดกำหนดรูปแบบไว้ ให้ใช้ของผู้จัด

---

## 13. Changelog v2 (ตอบ `GDD-review-1.md`)

| ID | ระดับ | สิ่งที่แก้ |
|---|---|---|
| R1 | Blocker | เพิ่มเป็น 3 Step, งานซ่อม 16→45s, ของที่ต้องส่ง = teamCount, MultiHold สะสม 30s, Extraction ETA 60s, Calm/Warning 30/15 และตาราง pacing 2.3 |
| R2 | Major | กฎ fast-forward 4 ข้อ + Banner ≥ 3s เสมอ |
| R3 | Major | `RouteCollapse.delay` บันไดหลักล้มที่ Critical+40s |
| R4 | Major | RouteCollapse telegraph 3s + `RecoveryPoint`, debris ที่ทับตัวละครใช้ `DebrisNoPlayer` |
| R5 | Major | Impact floor-aware (raycast, ΔY ≤ 4 / hit ΔY ≤ 6) |
| R6 | Major | `MultiHold` ขยายตามจำนวนคน + Departure ต้องอยู่ครบทีม + Last call |
| R7 | Major | Server ตั้ง `SpeedMult`/`CanSprint`/`MoveMode`, client เขียน WalkSpeed คนเดียว, ตรวจระยะเคลื่อนที่ |
| R8 | Major | ปิด CharacterAutoLoads/Reset/Dead และเก็บ HP เป็น Attribute |
| R9 | Major | Server-timed hold บน prompt แบบ Default |
| R10 | Major | Respawn selector (`Priority`, `EnabledBy`, ตรวจ hazard) |
| R11 | Major | กฎแมพ CollapseGroup + กู้คืน item |
| R12 | Major | สถานะ `Inactive` + กรอง AFK ใน Lobby |
| R13 | Major | ย้ายบางส่วนไป stretch, เพิ่ม marker, วันที่ 1 = Rojo |
| R14 | Major | tag/attribute ชื่อ generic, status effects, `SuppressZone` |
| R15–R23 | Minor | KillY, Departure หยุดชั่วคราว, 1 คน/1 anchor, hold จับเวลาฝั่ง server, รีเซ็ต Continuous, `riseRate`/`SurfaceY`, เครดิต, Lobby แยก, item anchored |

## 14. Changelog v3 (ตอบ `GDD-review-2.md` + ข้อตัดสินใจใหม่ของ Boss)

| ID / ที่มา | สิ่งที่แก้ |
|---|---|
| N1 (Major) | `required` ใช้ `activeCount` (ไม่นับคนที่ Eliminated แต่นับคนที่ Downed) + Emergency override หลัง 75s ลด required ลง 1 (ต่ำสุด 2) + Continuous ล็อก required และรีเซ็ตเฉพาะเมื่อ `Held < lockedRequired` เพิ่มแถวใน 5.10 และ DoD (3.4, 5.10, 8) |
| N2 (Major) | แยกเป็น 2 tag: `NoBlockingProp` (ตกและทำ damage ได้ แต่ไม่วาง prop) สำหรับบันได/ทางปีน/รอบ anchor และ `NoImpact` เฉพาะรอบ PlayerSpawn 6 studs + Exit Zone หลังกรงมาถึง เพิ่มการเทสต์บนบันไดใน DoD (4.2, 4.3.1, 7.6, 8) |
| N3 (Major) | idle respawn ใช้เฉพาะ item ที่เคยถูกหยิบ นับเวลาตั้งแต่วาง/ตก และทุกการกู้คืนกลับไปที่ ItemSpawn เดิม (หรือโซนที่ยังไม่มี item ชนิดนี้ถ้าจุดเดิมอันตราย) (5.7) |
| N4 (Minor) | ตรวจระยะเคลื่อนที่แบบหน้าต่างเลื่อน 2s ตาม timestamp จริง + slack 4 studs (5.5) |
| N5 (Minor) | อยู่ใน holder set / ถือ item นับเป็น activity และตัวนับหยุดชั่วคราวขณะ Eliminated (5.9) |
| N6 (Minor) | `SetStateEnabled(Dead)` เรียกทั้ง 2 ฝั่ง, `Died` ขณะ Downed บวกเวลา bleed-out ที่เหลือเข้า respawn delay, PlayerAdded → `LoadCharacter` ที่ Lobby (5.2, 2.1) |
| N7 (Minor) | DoD แยกเป็นเทสต์ใน Studio กับเทสต์ผู้เล่นจริงบน private place (≥ 2 คน, ≥ 3 Match, บันทึกเวลา, มือถือ 1 คน) (8) |
| N8 (Minor) | กฎลบ item ส่วนเกิน: ลบอันที่ไม่มีใครถือ โดยลบอันที่ยังไม่เคยถูกหยิบก่อน ถ้าทุกอันมีคนถือ ลบเมื่อถูกวาง (3.4) |
| N9 (Minor) | คง 45s ไว้ (ตอนนี้เป็นการวิ่งในวงล้อซึ่งดูสนุกกว่ากดค้าง) เพิ่มคำถามใน playtest และทางเลือก 2 × 22s ผ่าน data (3.4, 8) |
| N10 (Minor) | เพิ่มในลำดับตัด: MultiHold Continuous → Cumulative และ Inactive ใน Match → AFK filter ใน Lobby ย้ายการตรวจระยะไปหลัง HUD จัดแผน 14 วันใหม่ (วัน 3–4 และ 7 ไม่แน่นเกิน) และเพิ่ม buffer 2 วัน (8) |
| N11 (Minor) | ขณะถูก revive ผู้ล้มอยู่ใน `MoveMode = Pinned` (ความเร็ว 0) (5.3, 5.5) |
| Boss: แฮมสเตอร์ | Pitch ใหม่, หัวข้อ 1.1 (ตัวละคร R15 ขนาดมาตรฐาน, ความเร็วเดิม, สเกล 1 stud = 2 cm พร้อมตารางขนาด) |
| Boss: แฮมสเตอร์ | แมพ #1 เปลี่ยนจาก "Riverside Pump Station" เป็น "Midnight Kitchen" โดยคงผังเดิมทุกระดับ, โซน, ระยะ MultiHold, ทางหลัก + ทางสำรอง (7) |
| Boss: แฮมสเตอร์ | Objectives/items ธีมใหม่: RunWheel, DeliverBatteries, CallForHelp, WindowLatches และ exitFlag `WindowOpen` (3.6, 7.4) |
| Boss: แฮมสเตอร์ | Extraction ธีมใหม่: นักดับเพลิงหย่อนกรงสัตว์เลี้ยงลงที่กระบะดอกไม้ (`RescueCarrier`) กฎ 60s เหมือนเดิม (5.8) |
| Boss: แฮมสเตอร์ | ภัยทั้ง 4 แบบบรรยายภาพที่สเกลแฮมสเตอร์ GroupId เปลี่ยนเป็น `CerealTower`/`DishRack` และฟ้าผ่าใน Flood Critical เปลี่ยนเป็นหยดน้ำจากเพดาน เพราะครัวเป็นพื้นที่ในร่ม (4.3) |
| Boss: แฮมสเตอร์ | targeting `OutdoorPlayer` เปลี่ยนชื่อเป็น `ExposedPlayer` (ยังเป็นชื่อ generic) (4.2) |
| Boss: สุ่ม 1 ภัย/รอบ | เขียนเป็นกฎหลักใน 1, 2.1, 4 และ 3.6 + กฎห้ามได้ภัยเดิมซ้ำ 2 รอบติด แล้วลบออกจาก Assumptions |
| Boss: ทุกวัย | เพิ่มหลักการข้อ 6 "น่ารัก ไม่น่ากลัว", ภาพ Downed = ม้วนตัว + ดาวหมุน ("Dizzy!"), Eliminated = "Poofed!", damage = "โป๊ก!" ไม่มีเลือด, ปุ่มน้อย, HUD ใช้ไอคอน (1, 1.1, 5.1–5.3, 8) |
| Boss: ทุกวัย | สกุลเงิน Coins → Seeds (เมล็ดทานตะวัน) และ cosmetic ธีมแฮมสเตอร์ (6) |
| Theme B | ปรับเป็นแฮมสเตอร์บนสถานีอวกาศ และ escape pod = ลูกบอลแฮมสเตอร์ (10) |
| หัวข้อ 11 | เขียนใหม่ 3 ข้อ: Q1 แยกข้อย่อย ก/ข/ค, Q2 รวม Emergency override, Q3 บอกว่า AllDowned ทำให้ทีม 3–4 คนแทบไม่แพ้แบบ Wipe |
| **เส้นตาย 25 ต.ค. 12:00** | แทนที่ "M1 vertical slice + แผน 14 วัน" ด้วย **"Deadline build"** (หัวข้อ 8): แมพ Deadline cut 2 ระดับ 160×120, Earthquake ภัยเดียว (Flood เป็น stretch), 3 objective types (Repair, Deliver, MultiHold Cumulative), 2 Step + Extraction, respawn คงที่ 15s, ไม่มีวิ่ง/Drop/Inactive/Continuous, HUD 8 ชิ้น พร้อมตาราง override ค่าใน 9 |
| เส้นตาย: แผน | แผนรายชั่วโมงแบ่งตาม agent (Scripter/Systems/UI/Level/Art/QA/Lead) มี CP0–CP4, Feature freeze 21:00 วันที่ 24, Code freeze 08:00 วันที่ 25, ลำดับตัด และรายการ "หลังส่งงาน" (8.8–8.10) |
| เส้นตาย: สิ่งที่ส่ง | จองบล็อก 08:00–11:30 สำหรับ publish + playtest บน live place + วิดีโอ + เอกสาร, ถ่าย footage ดิบ/screenshot ตั้งแต่ 21:00 วันที่ 24, Lead เขียน storyboard/บท/เอกสารคู่ขนาน, เพิ่ม 8.12 (โครงเอกสารส่งงาน + shot list วิดีโอ) และเกณฑ์ส่งงานใน DoD |
| เส้นตาย: ฉากวิดีโอ | เพิ่ม "Rescue Moment" (8.6.1): Big Shake ตอนปลดล็อก (data), ไฟกู้ภัย, กรงหย่อนลงมา, กล้องตอนชนะ, ปุ่ม H ซ่อน HUD และอยู่ในรายการ "ห้ามตัด" |
| Q1-ค | เปลี่ยนคำแนะนำเป็น: ให้เริ่ม solo ได้เมื่อรอคนเดียว 20s ตอนส่งงาน (คนตรวจอาจเล่นคนเดียว) |

## 15. Changelog v4 (ตอบ `GDD-review-3.md`)

| ID | สิ่งที่แก้ |
|---|---|
| D1 | Departure เริ่มนับเฉพาะเมื่อมีคนในโซน ≥ 1 คน, Last call ใช้ `max(1, …)`, MultiHold `required = max(1, …)`, เพิ่มเคส solo ถูก Eliminated ระหว่างรอกรงใน DoD (3.4, 5.8, 8.11) |
| D2 | `NoImpact` รอบ spawn ใช้เฉพาะ spawn ที่ไม่มี `EnabledBy` ส่วน spawn ขอบหน้าต่างใช้แค่ spawn protection + เพิ่มเทสต์ใน DoD (4.2, 8.3, 8.11) |
| D3 | Storyboard หลักใช้ 2 ตัว ("Held 2/2" split-screen) ส่วนช็อต 4 ตัวเป็นตัวเลือก หรือใช้ `spawnDummyHolder` (8.12) |
| D4 | ย้าย Maturity & Compliance, Genre, อุปกรณ์, Max players, ตรวจ audio/asset ไปที่ H0 และเปิด public ครั้งแรกที่ CP3 (21:00 วันที่ 24) บล็อก 08:00 เหลือแค่ publish เวอร์ชันสุดท้าย (8.9, 8.11) |
| D5 | เพิ่ม debug commands เฉพาะ Studio/dev (`skipStep`, `setStage`, `unlockExit`, `setHP`, `spawnDummyHolder`, `endMatch`) ใน IN และ Day 1 ของ Systems (8.6, 8.9) |
| D6 | โค้ดที่ทำระหว่าง Boss นอนต้องผ่าน `luau-analyze --!strict` + `selene` + QA ตรวจเทียบ contract ก่อน sync (8.9) |
| D7 | คนที่ 2 เข้ามาระหว่างนับ solo → เปลี่ยนเป็นนับ co-op (เวลาที่เหลือ = max(เหลือ, 10s)) (8.6, 8.11) |
| D8 | 8.12 ระบุให้เอกสารส่งงานใช้เนื้อหาจากหัวข้อ 8 + หมายเหตุใน 2.2 ว่าเป็นแมพเต็มหลังส่งงาน |
| D9 | กำแพง/เพดานล่องหนทั้งหมดตั้ง `CanQuery = false` (8.3) |

## 16. Changelog v5 (Boss อนุมัติ + ปิด solo start)

1. **Solo start ปิด**: ลบการนับ solo 20s ทั้งหมด (1, 2.1, 8.1, 8.6, 8.9, 8.11, 9) Match เริ่มได้เมื่อ ≥ 2 คนเสมอบน live ส่วน fallback เมื่อเพื่อนออกกลาง Match (3.5) ยังอยู่
2. เพิ่ม `DEV_MIN_PLAYERS_STUDIO = 1` (เฉพาะ Studio ไม่มีผลบน live) แทน `DEV_ALLOW_SOLO` / `SOLO_START_AFTER` เพื่อให้ agent เทสต์คนเดียวได้
3. 8.12: หน้าเกม Roblox + เอกสารส่งงานต้องเขียน "ต้องเล่น 2–4 คน / Needs 2–4 players" และ Q1-ค ใน 11 เปลี่ยนเป็น "ตัดสินแล้ว"
