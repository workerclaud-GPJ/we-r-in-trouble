# GDD Review รอบที่ 1 — We R in Trouble (Theme A)

| | |
|---|---|
| เอกสารที่ตรวจ | `docs/GDD.md` Draft v0.1 |
| ผู้ตรวจ | Design Reviewer (อิสระ) |
| วันที่ | 2026-10-23 |
| อ้างอิง | `docs/TEAM.md`, `docs/CONVENTIONS.md` |

## Verdict: **FAIL** (ส่งแก้รอบ 1 จาก 2)

โครงเอกสารดีมาก: ระบบ Hazard แบบ generic, สเปก interaction ละเอียด, ตาราง tuning ครบ แต่มีปัญหาระดับ Blocker 1 ข้อที่กระทบ core loop โดยตรง คือ **ภารกิจใน M1 สั้นเกินไปจนทีมปกติหนีออกได้ก่อนภัยพิบัติเริ่มทำ damage** (ดูการคำนวณใน R1) ซึ่งขัดกับนิยามแนวเกมใน TEAM.md ต้องปรับ mission/pacing ใหม่และคำนวณยืนยันด้วยตัวเลข นอกจากนี้ยังมี Major อีก 13 ข้อ ส่วนใหญ่เป็นช่องว่างที่ scripter ต้องเดาเอง หรือเป็นเรื่องที่ Roblox ทำงานต่างจากที่เอกสารสมมติไว้ ทุกข้อแก้ได้ในรอบเดียวโดยไม่ต้องรื้อสถาปัตยกรรม

| ความรุนแรง | จำนวน |
|---|---|
| Blocker | 1 |
| Major | 13 |
| Minor | 9 |

### หลักฐานของ R1: pacing budget คำนวณจากตัวเลขใน GDD เอง (ทีม 2 คน เดิน 16 studs/s)

| ช่วง | คนที่ 1 | คนที่ 2 | เวลาใน Match |
|---|---|---|---|
| Briefing | — | — | 0:05 |
| Step 1 | Spawn → Generator ≤ 120 studs (~7.5s) + Repair 16s ≈ 24s | สำรวจจุดฟิวส์ 4 จุด แย่สุด ~300 studs (~19s) + ไป socket ~80 studs (~5s) ≈ 25s | ~0:30–0:40 |
| Step 2 | เดินไปคันโยก A/B ~60–100 studs (~5s) + กดค้าง 3s | | ~0:45–0:55 |
| Exit | Exit ปลดล็อก → **Stage กระโดดจาก Calm เป็น Critical** → Helipad ~60–110 studs (~5–7s) → ทุกคนอยู่ในโซน = จบทันที | | **~1:00–1:10** |

ถึงทีมจะเล่นช้ากว่านี้ 2 เท่า ก็ยังจบราว 2:00 แต่ Active (stage แรกที่มี damage) เริ่มที่ 1:30 และ Flood เพิ่งเริ่มขึ้นตอน 1:30 ด้วย ตาราง 2.2 ที่เขียนว่า "Step 1 เสร็จ ~2:30–3:30" และให้ Step 2 ใช้เวลา 90 วินาที จึงไม่ตรงกับตัวเลขในหัวข้อ 3.3 และ 7

---

## Findings

| ID | ความรุนแรง | หัวข้อ | ปัญหา | วิธีแก้ที่แนะนำ |
|---|---|---|---|---|
| R1 | **Blocker** | 2.2, 3.3, 4.1, 7.4 | **งานในภารกิจน้อยเกินไปเมื่อเทียบกับ Match 7:00** (ดูตารางด้านบน) ทีมปกติจบที่ ~1:00–2:00 ก่อนเข้า Active จึงไม่เคยเจอ damage, Flood ไม่ทันท่วม, ระบบ Downed/Revive ไม่ถูกใช้ ขัดกับ TEAM.md ที่กำหนดว่าผู้เล่นต้อง "ทำภารกิจร่วมกันขณะที่ภัยพิบัติรุนแรงขึ้นเรื่อยๆ" และ timeline 2.2 ก็ขัดกับตัวเลขของเอกสารเอง | (1) เพิ่มตาราง **pacing budget** ต่อ objective (ระยะเดิน + เวลาทำ) ใน GDD ให้ทีมปกติจบที่ ~4:30–6:00 (2) ใช้อย่างน้อย 2 ข้อจากนี้: ลด Calm 60→25s และ Warning 30→15s (Active เริ่มราว 0:40) / Deliver `count` = จำนวนผู้เล่นตอนเริ่ม (ฟิวส์ 2–4 อันอยู่คนละโซน) / Generator `duration` 16→30–35s / เพิ่ม **Extraction ETA**: Exit ปลดล็อกแล้วเฮลิคอปเตอร์มาถึงใน 60s และ Exit Zone ยังไม่นับจนกว่าจะถึง ทีมจึงต้องเอาตัวรอดใต้ Critical (ทำเป็นฟิลด์ data `exitArrivalDelay`) / กำหนด Stage ขั้นต่ำตามความคืบหน้า เช่น Step 1 เสร็จแล้วต้องเป็น Active เป็นอย่างน้อย (3) หลังปรับแล้วให้เช็คหน้าต่างเวลา Flood ใหม่ เพราะ Generator อยู่ใต้ดิน: ซ่อมคนเดียวใต้น้ำได้ประมาณ 8s Breath + ~10s HP ต่อรอบ |
| R2 | Major | 4.1, 4.2, 4.3 | **กฎการกระโดด Stage ยังไม่ครบ** ถ้าเอกสารยังเป็นแบบนี้ เคส Calm/Warning → Critical จะเกิดแทบทุก Match แต่ไม่ได้บอกว่า banner ชื่อภัย (Warning) จะแสดงไหม, `RouteCollapse` ของ Active ("WarehouseShelves") จะทำงานด้วยไหม และ siren/lighting ของ stage ที่ข้ามไปต้องทำอะไร Assumption 3 บอกว่าจะเปิดเผยชนิดภัยตอน Warning แต่ทีมที่เร็วจะไม่เคยเห็นเลย | เขียนกฎว่า "เมื่อข้าม Stage ให้รัน on-enter ของทุก Stage ที่ข้ามตามลำดับใน tick เดียวกัน (collapse/ระดับน้ำ) แต่ banner ชื่อภัยต้องแสดงอย่างน้อย 3s เสมอ" หรือกำหนดให้ jump ไปได้แค่ "Stage ถัดไป" ไม่ใช่ข้ามถึง Critical ทันที |
| R3 | Major | 7.5, 4.1, 4.3.1 | **Earthquake: ทางหลัก (Roof Door) ใช้ไม่ได้ทุกครั้ง** เพราะ Exit จะปลดล็อกตอนที่เป็น Critical อยู่แล้ว หรือทำให้กลายเป็น Critical ทันที และ Critical สั่ง collapse "StairUpper" ทันที เส้นทาง "~60 studs" ใน 7.5 จึงไม่มีอยู่จริงในโหมด Earthquake และผู้เล่นที่อยู่บนบันไดตอน Exit เปิดจะโดน collapse ทับพอดี | เพิ่มพารามิเตอร์ `delay` ให้ `RouteCollapse` แล้วตั้ง StairUpper = Critical + 45s หรือผูกกับเวลา Match (เช่น 5:30) แทนการผูกกับตอนเข้า Critical ถ้าตั้งใจให้ใช้ Fire Escape เสมอ ให้ตัดทางหลักออกจาก 7.5 และไม่ต้องสร้าง Roof Door |
| R4 | Major | 4.2 `RouteCollapse`, 4.3.1 debris | **Geometry สลับหรือเกิดขึ้นทับตัวผู้เล่น** ตอนที่ `After` โผล่ หรือซาก debris (ค้าง 6s, กีดขวาง) ตกลงตรงที่ผู้เล่นยืน ผู้เล่นจะติดอยู่ในชิ้นส่วน หรือโดนฟิสิกส์ Roblox เหวี่ยง (fling) และ collapse ไม่มี telegraph ขัดหลักข้อ 1–2 | RouteCollapse: telegraph 3s (shake + เสียงร้าว + ฝุ่นที่ `Before`) และตอนสลับให้ server เช็ค `GetPartsInPart(After)` เทียบกับ HRP ถ้าทับให้ย้ายไป `SafePoint` ที่ใกล้ที่สุด (tag ใหม่) / Debris: ถ้ามี character ทับอยู่ตอนตก ให้ debris อยู่ใน CollisionGroup ที่ไม่ชนผู้เล่น |
| R5 | Major | 4.2 `TelegraphedImpact` | **แมพมีหลายชั้น (−3 / 0 / 16 / 32) แต่ตรวจ hit ด้วย "ระยะแนวนอน" และไม่ได้ระบุว่าจุดตกอยู่ที่ Y เท่าไร** ผู้เล่นชั้น 1 จึงโดน debris ที่เล็งคนชั้น 2 ได้ และจุดสุ่มอาจไปอยู่ในกำแพง นอกอาคาร หรือกลางอากาศ | จุดตก: สุ่มตำแหน่งแนวนอนรอบเป้าหมาย แล้ว raycast ลงจาก (Y เป้าหมาย + 6) หาพื้น ต้องได้ \|ΔY\| ≤ 4 เทียบพื้นของเป้าหมาย ไม่งั้นสุ่มใหม่ (ใช้กฎสุ่มใหม่ 5 ครั้งเดิม) / hit = ระยะแนวนอน ≤ radius **และ** \|ΔY\| ≤ 6 |
| R6 | Major | 1, 3.2, 5.8, 7.4 | **Co-op ที่ถูกบังคับจริงมีแค่ 3 วินาที** (DualSwitch) Step 1 คนเดียวทำได้ทั้งหมด ทีม 3–4 คนมี 1–2 คนที่ไม่มีงานบังคับเลย (RoofBreakers ใช้แค่ 2 คน) และ quorum ครึ่งทีมทำให้หนีออกได้โดยไม่รอเพื่อน ผู้เล่นคนเดียวจึง carry ได้เกือบทั้ง Match ขัดหลักข้อ 3 และ Pitch ที่ว่า "ไม่มีใครรอดคนเดียวได้" | (1) ขยาย DualSwitch เป็น `MultiSwitch` ใช้ logic เดิม: `required = clamp(playersAtStart, 2, 4)` คันโยก A–D (2) เพิ่ม co-op ใน Step 1 โดยใช้ระบบเดิมผ่าน data: DualSwitch ที่มี `resetOnBreak = false` และ `overlap = 20` จะกลายเป็น "ซ่อมสองจุดพร้อมกัน" ที่ progress ไม่หาย (3) แก้ Pitch ให้ตรงกับกฎ quorum หรือแก้ quorum ตามที่ Boss เลือก (ดูคำถาม 2) |
| R7 | Major | 5.5, 9 `SPEED_CAP_TOLERANCE` | **การตรวจ WalkSpeed ฝั่ง server ใช้ไม่ได้** เพราะค่า `Humanoid.WalkSpeed` ที่ client ตั้งเองไม่ replicate ไป server และตอนนี้มี 2 ฝ่ายเขียน WalkSpeed (client: sprint/stamina, server: pulse/น้ำ/ถือของ) ซึ่งจะเขียนทับกัน | server ประกาศตัวคูณเป็น Attribute บนผู้เล่น (`SpeedMult`, `CanSprint`) แล้วให้ client เป็นคนเดียวที่ตั้ง `WalkSpeed = (sprint ? 24 : 16) × SpeedMult` (ขั้นต่ำ 6) / server ตรวจ**ระยะที่ HRP เคลื่อนจริง**ทุก 0.5–1s เทียบกับ maxSpeed × SpeedMult × 1.1 (เผื่อการตกและ PushForce) ถ้าเกินให้ดึงกลับ วิธีนี้กันการ teleport เข้า Exit Zone ได้ด้วย |
| R8 | Major | 5.2, 5.4 | **ยังไม่ได้ปิดระบบตาย/เกิดใหม่ของ Roblox** ปุ่ม Reset Character ในเมนู Esc ทำให้ Health = 0 แล้วข้าม Downed/bleed-out/respawn delay ไปได้ ถ้า `CharacterAutoLoads` ยังเปิดอยู่ ตัวละครจะเกิดใหม่เองที่ SpawnLocation | ระบุในสเปก: `Players.CharacterAutoLoads = false` (server เรียก `LoadCharacter` เอง) / client `StarterGui:SetCore("ResetButtonCallback", false)` / `Humanoid:SetStateEnabled(Dead, false)` และถ้า `Died` ยังยิงอยู่ดี ให้ถือว่าเป็น Eliminated |
| R9 | Major | 3.3 continuous hold, 5.6, 8 (มือถือ) | **`Style = Custom` บังคับให้ต้องเขียน UI ของ prompt เองทั้งหมด** ทั้ง key hint และปุ่มแตะบนมือถือที่ต้องเรียก `InputHoldBegin/End` เอง เป็นงานที่เสี่ยงและไม่ได้ลงไว้ในแผน 2 สัปดาห์ ส่วน `HoldDuration = 999` กับ Default style จะโชว์วงแหวนที่แทบไม่ขยับ | ใช้ Default style กับ `HoldDuration = 0` แล้วฟัง `Triggered` (กดลง) และ `TriggerEnded` (ปล่อย) เป็น begin/end แทน แสดง progress ด้วย BillboardGui ที่อ่าน Attribute `Progress` วิธีนี้ใช้กับมือถือได้ทันที และ server tick ที่เช็คระยะทุก 0.1s ยังเป็นตัวกันอยู่ (QA ต้องเทสต์ว่า TriggerEnded ยิงเมื่อเดินออกนอกระยะ) |
| R10 | Major | 4.3.2, 5.4, 7.5–7.6 | **Flood: จุดเกิด `PlayerSpawn` อยู่ที่ลาน [A] ซึ่งน้ำท่วมมิดหัวตั้งแต่ ~3:30** และลึก +9 ถึง +19 ในช่วง Critical ผู้เล่นที่ respawn จะเกิดใต้น้ำ (Breath 8s แล้วโดน 10 dps) ต้องลุยน้ำด้วยความเร็ว ×0.6 ไปที่ Fire Escape ถ้าล้มใต้น้ำจะไม่มีใครมาช่วยทัน (bleed ×2) การ respawn จึงแทบไม่มีความหมาย | ให้ respawn เลือก spawn ที่ไม่อยู่ใน hazard volume (generic `RespawnSelector`) และวาง `PlayerSpawn` สำรองที่ชั้น 2 กับดาดฟ้า (Attribute `Priority` หรือ `MinStage`) ใช้ได้กับ Theme B (แก๊ส) ด้วย |
| R11 | Major | 3.3 Deliver, 4.3.1, 7.3 | **Item softlock**: จุดฟิวส์ #1–#2 อยู่ในโกดัง ส่วนฟิวส์ที่ผู้เล่นทำตกอาจไปอยู่ใต้หรือหลัง `CollapseGroup` "WarehouseShelves" หลังจากสลับเป็น After แล้วหยิบไม่ได้ กฎ respawn ของ item ครอบคลุมแค่กรณี "ตกนอกแมพ" ขัดหลักข้อ 1 | กฎแมพ: ItemSpawn, Socket, คันโยก และเครื่องจักรต้องไม่อยู่ใน bounds ของ CollapseGroup ใดๆ / ตอน RouteCollapse ทำงาน item ที่ทับ After ต้อง respawn ที่ ItemSpawn อื่น / ตาข่าย: `ITEM_IDLE_RESPAWN` (ไม่มีใครถือ 45s และไม่มีผู้เล่นอยู่ในระยะ 15 studs → respawn) |
| R12 | Major | 3.4, 5.9 | **ผู้เล่น AFK ทำให้ Match 2 คนเล่นต่อไม่ได้** คนที่ AFK ไม่นับว่า "ออก" จึงไม่เปิด soloFallback ทำให้ DualSwitch ทำไม่ได้จนแพ้ Collapse ที่ 7:00 (การตรวจ AFK มีแค่ใน rewards ของ M2) และคนที่ AFK อยู่ใน Lobby ก็จะถูกส่งเข้า Match ด้วย | M1: ในระหว่าง Match ถ้าไม่มี input หรือการเคลื่อนที่ 60s ให้เป็นสถานะ `Inactive` ที่ไม่นับใน soloFallback, quorum และ Wipe (หรือส่งกลับ Lobby) / Lobby: ไม่ส่งผู้เล่นที่ AFK ≥ 60s เข้า Match |
| R13 | Major | 8 | **M1 ใหญ่เกิน 2 สัปดาห์และยังขาดของจำเป็น** HUD 13 ชิ้น + มือถือได้แค่ 2 วัน, Flood ทั้งระบบได้ 1 วัน และไม่มีวันสำหรับตั้ง Rojo, `Remotes.luau` และ validation หลังแก้ R1/R6/R7 งานจะเพิ่มอีก ส่วนที่ขาดคือ**ตัวบอกตำแหน่ง objective**: แมพมี 2 ชั้นกับใต้ดิน HUD มีแค่รายการ objective ผู้เล่นใหม่จะไม่รู้ว่าเครื่องอยู่ที่ไหน และยังไม่ได้ตัดสินว่าฟิวส์ (สุ่มตำแหน่ง) จะมี marker หรือไม่ | ย้าย Flood เป็น "M1-stretch" (ไม่ใช่ IN) / Spectate เหลือแค่กล้องตามเพื่อนคนแรก / ตัด Regen / เพิ่มใน IN: marker ของ objective ที่อยู่ตายตัว (Billboard + ระยะ) ส่วนฟิวส์ไม่มี marker แต่มีแสงหรือเสียงเมื่ออยู่ใกล้ 30 studs (ช่วยเพิ่มเวลาค้นหาตาม R1) / วันที่ 1 ของแผน: Rojo + Remotes skeleton |
| R14 | Major | หลักข้อ 4, 3.3 Repair, 4.3.2–4.3.3, 7.7 | **ชื่อธีมรั่วเข้าไปในโค้ด**: tag `FloodLevel`, `NoDebris`, `FireNode`, `HelicopterSpot`, `Shelter` ต้องถูกอ่านจากโค้ดโดยตรง กฎ Repair "ใต้น้ำ (ใช้ Flood)" ผูก objective เข้ากับภัยชนิดเดียว `Extinguisher` เป็นพฤติกรรมเฉพาะ และ "Downed ใต้น้ำ" ก็เช่นกัน Theme B จะต้องติด tag ชื่อ Flood บนยานอวกาศ หรือไม่ก็ต้องแก้โค้ด ขัด TEAM.md (ยังไม่ถึง Blocker เพราะเปลี่ยนชื่อก่อนเขียนโค้ดได้ แต่ถ้าปล่อยไปถึงตอนเขียนโค้ดจะกลายเป็น Blocker) | เปลี่ยนชื่อเป็น generic: `VolumeLevel`, `NoImpact`, `SpreadNode`, `ExitVehicleSpot`, `SafeZone` / `RisingVolume` มี query `isSubmerged(pos)` และ ObjectiveDef มี `submergedRateMult` / ใช้ status effect "Submerged" แบบ generic คุม bleed mult / ใช้ item ability `SuppressZone` แทน Extinguisher |
| R15 | Minor | 3.3 Deliver vs 5.9 | กรณีตกนอกแมพใช้ 2 กลไก (`Map.KillY` กับ `FallenPartsDestroyHeight`) | ใช้ `KillY` เป็นหลัก (server เช็ค Y ของ HRP ทุก 0.5s) และตั้ง FallenPartsDestroyHeight ให้ต่ำกว่าเป็นตาข่าย |
| R16 | Minor | 5.8 | Departure: (ก) ก้าวออกนอกโซนชั่วครู่เพื่อหลบ debris แล้ว countdown รีเซ็ตเป็น 15s ใหม่ ลงโทษหนักเกินไป (ข) ไม่ได้บอกว่า Exit Zone เป็น NoDebris หรือไม่ (ค) Downed ที่อยู่ในโซนนับเป็น Escaped ไหม (ถูกนับในเงื่อนไข "จบทันที" แต่ไม่นับใน quorum) (ง) ถ้าเงื่อนไข Win และ Wipe เกิดใน tick เดียวกัน ตัดสินอย่างไร | ให้ countdown หยุดชั่วคราวแทนการรีเซ็ต (หรือมี grace 2s) / ระบุว่า Downed ในโซน = Escaped / ตรวจ Win ก่อน Wipe / ตัดสินเรื่อง debris บน helipad ให้ชัด |
| R17 | Minor | 3.2, 3.3 DualSwitch | ที่บอกว่า "ProximityPrompt กดได้ทีละอัน" เป็นตัวบังคับนั้นไม่ปลอดภัย exploit เรียก hold หลาย prompt พร้อมกันได้ (ตอนนี้ระยะ ≥40 studs ยังกันได้อยู่ แต่ไม่ควรพึ่งข้อนี้) | ใช้กฎฝั่ง server: ผู้เล่น 1 คนอยู่ใน holder set ได้ไม่เกิน 1 anchor ถ้าเริ่ม hold ใหม่ให้เอาออกจาก set เดิม |
| R18 | Minor | 5.3, 5.6 | Hold prompt แบบปกติ (Revive 4s, Pull 2s) โดน exploit ยิง `Triggered` ทันทีโดยไม่ต้องกดค้างได้ | server จับเวลาตั้งแต่ HoldBegan ถึง Triggered ต้อง ≥ HoldDuration − 0.2s และยกเลิกถ้าผู้ช่วยออกนอกระยะ 10 studs |
| R19 | Minor | 3.4 | ถ้า soloFallback เปิดขึ้นตอนกำลังนับ DualSwitch อยู่ ไม่ได้บอกว่า overlap ที่นับไว้จะนับต่อหรือรีเซ็ต | ระบุว่า "เปิด fallback แล้วรีเซ็ต overlap เป็น 0 เงื่อนไขใหม่คือมี holder ≥ 1 ฝั่งใดก็ได้" |
| R20 | Minor | 4.3.2, 9 Flood | "อัตรา Critical" ไม่ได้กำหนดเป็นตัวเลข เพราะคำนวณจากเวลาที่เหลือถึง 7:00 เคส Critical เริ่มก่อนกำหนดจึงคำนวณได้หลายแบบ และการ resize Part น้ำขนาดใหญ่บน server ทุก 0.25s จะดูกระตุก | ใน data ให้กำหนด `riseRate` (studs/s) ต่อ Stage (Active 0.067, Critical 0.067) / server คำนวณความสูงผิวน้ำจากสูตรและตั้งเป็น Attribute แล้ว client tween Part น้ำเอง |
| R21 | Minor | 4.1 vs 6.1, 3.3 Repair | "ทีมที่เร็วได้ bonus เวลา (M2)" ไม่มีอยู่ในตารางรางวัล 6.1 และเครดิต Repair ≥ 25% ไม่ได้บอกว่าคนที่ 3 (เกิน maxStack) จะได้ส่วนแบ่งอย่างไร | เพิ่มแถวในตารางหรือลบข้อความนั้นออก / เครดิต = แบ่ง progress ในแต่ละ tick ให้ holder ที่ถูกนับ (คนแรกๆ ไม่เกิน maxStack คนตามลำดับที่เริ่มกด) |
| R22 | Minor | 2.1, 7 | Lobby อยู่ใน place เดียวกับแมพ แต่ไม่ได้ระบุว่าจะกันคนใน Lobby ไม่ให้เดินเข้าแมพอย่างไร และน้ำ, debris กับ collapse ต้องไม่กระทบ Lobby | วาง Lobby ห่างจากแมพมาก (เช่น Y = 500) มีกำแพงล่องหน และกำหนดขนาด Part น้ำให้เท่ากับที่ดินของแมพเท่านั้น |
| R23 | Minor | 3.3 Deliver, 5.7 | item ที่วางหรือตก ถ้าเป็น physics แบบ unanchored จะมี network ownership เป็นของ client ซึ่งเปิดช่องให้ exploit เหวี่ยงหรือย้าย item ได้ และ item อาจไหลหรือกลิ้งไปที่อื่น | item ที่วางอยู่ให้ anchored เสมอ ตอนวางให้ server raycast หาพื้นหน้าผู้เล่นในระยะ ≤ 4 studs และ server เป็นคนสร้าง weld ตอนถือ |

---

## What works well

- ระบบ Hazard component แบบ generic (Pulse, TelegraphedImpact, RisingVolume ฯลฯ) และตารางเทียบ Theme B ในหัวข้อ 10 ตอบโจทย์ "ธีม = ข้อมูล" ได้ดีมาก
- หลักการออกแบบ 5 ข้อ (ไม่มี softlock, telegraph ≥ 1s, co-op ต้องบังคับด้วยกลไก) ใช้เป็นเกณฑ์ตัดสินได้จริง ซึ่ง review นี้ก็ใช้เกณฑ์เหล่านั้น
- สเปก continuous hold ฝั่ง server (holder set + tick 0.1s + เช็คระยะและสถานะ) และ HeavyCarry แบบไม่ใช้ฟิสิกส์ เป็นการเลือกที่ถูกสำหรับ Roblox
- ตาราง tuning ครบทุกค่าและมี Config key ให้เลย ทำให้เช็คตัวเลขได้ง่าย ซึ่งเป็นเหตุผลที่จับปัญหา R1 ได้
- มีลำดับการตัด scope, Definition of Done ที่ QA ใช้ได้ และตาราง edge case ให้เริ่มต้นแล้ว

## คำถามที่ Boss ต้องตัดสิน

1. **จะทำให้ Match ยาวและตึงขึ้นด้วยวิธีไหน (R1)**: (ก) เพิ่มงานภารกิจ (ฟิวส์หลายอัน ซ่อมนานขึ้น) / (ข) เพิ่มช่วง "รอเฮลิคอปเตอร์ 60s" ใต้ Critical หลัง Exit ปลดล็อก / (ค) ผสมทั้งสองแบบ ผู้ตรวจแนะนำ (ค) แต่เรื่องนี้เป็นเรื่องความชอบของเกม
2. **ในทีม 3–4 คน ทุกคนต้องมีงานที่บังคับไหม และต้องหนีออกครบทีมหรือเปล่า (R6)**: แบบ "ทุกคนต้องจับคันโยก และต้องหนีครบทุกคนที่ยังไม่ Eliminated" จะ co-op จริงจังกว่า แต่ถ้ามีคนเล่นแย่ คนในทีมจะหงุดหงิดกว่า ส่วน "ครึ่งทีมหนีได้ = ชนะ" จะเล่นง่ายกว่า
3. **Team Wipe ระหว่างที่เพื่อนรอ respawn**: ในทีม 2 คน ถ้าคนหนึ่ง Eliminated แล้วอีกคนล้ม จะแพ้ทันทีตามกฎปัจจุบัน ระบบ respawn จึงช่วยได้น้อยมากในทีม 2 คน จะคงความเข้มแบบนี้ไว้ หรือให้ Wipe นับเฉพาะตอนที่ไม่มีใครรอ respawn อยู่
