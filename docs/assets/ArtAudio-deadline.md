# Art & Audio — Deadline build (We R in Trouble)

> เจ้าของ: Art & Audio Director · อ้างอิง GDD v0.5 §1.1, §4.3.1, §5, §8.1–8.6.1, §8.9, §8.12
> ใช้กับ **Deadline cut** เท่านั้น (แมพ 160 × 120, Earthquake, 2 Step + Extraction) · สเกล **1 stud = 2 cm** (ขนาดจริงเป็น cm ÷ 2 = studs)
> สถานะ: v1 (24 ต.ค.) · ID เสียงทุกตัว **ต้องยืนยันใน Studio** (ดู §5.1)

---

## 0. TL;DR — 10 อย่างที่ต้องมี (เรียงตามลำดับทำ)

| # | ของ | ทำไม | ใครทำ | เวลา |
|---|---|---|---|---|
| 1 | **แฮมสเตอร์ StarterCharacter** (รัน `tools/BuildHamster.luau`) | ห้ามตัด (8.10) ทุกช็อตในวิดีโอมีมัน | Boss รันสคริปต์ | 2 นาที |
| 2 | **วงเตือนสีแดง + debris (แอปเปิล/กระป๋อง/ฟองน้ำ) + ฝุ่น + "BONK!"** | หัวใจของ Earthquake ที่เด็กอ่านออกโดยไม่ต้องอ่านหนังสือ | UI (VFX) ใช้สเปก §3.1–3.3, Boss ทำ 3 โมเดล debris | 30 นาที |
| 3 | **กล้องสั่นตาม Stage + เสียงแผ่นดินไหว/จานกระทบกัน** | "บ้านสั่น" ต้องรู้สึกได้ | UI (§3.6) + Audio | 20 นาที |
| 4 | **กรงสัตว์เลี้ยง `RescueCarrier` + เชือก + ไฟฉายส่องตาม** | Rescue Moment ห้ามตัด | Boss ทำโมเดล (§2 #5), UI ทำ tween | 40 นาที |
| 5 | **ไฟกู้ภัยแดง/น้ำเงินนอกหน้าต่าง + ไซเรนที่ดังขึ้นเรื่อยๆ** | ช็อตเด่นของวิดีโอ, cut order ข้อ 5 บอกให้เก็บไว้ | Level วาง, UI tween (§3.7) | 20 นาที |
| 6 | **วงล้อ + ไดนาโม, แท่นชาร์จ + LED, ถ่าน AA เรืองแสง** | objective Step 1 ต้องเห็นชัดในครัวมืด | Boss/Level (§2 #1–3) | 45 นาที |
| 7 | **วิทยุของเล่น 4 สี A–D ที่ไฟติดตอนมีคนกด** | co-op moment "Held 2/2" ในวิดีโอ | Boss/Level (§2 #4) | 25 นาที |
| 8 | **หน้าต่าง + ขอบหน้าต่าง + กระบะดอกไม้ + ที่คว่ำจาน (ทางลาด) + ผ้าม่าน (Truss)** | เส้นทางหนีและ Exit Zone | Level (§2 #6–9) | 60 นาที |
| 9 | **Lighting 4 preset + แสงจันทร์ + ไฟใต้ชั้น** (อย่างน้อย Critical) | ต้องอ่านออกบนมือถือแต่ยังดูเป็น "เที่ยงคืน" | UI ใช้ตาราง §4 | 20 นาที |
| 10 | **ดาวหมุน (Dizzy) + Poof + ชุดเสียงหลัก 10 ตัว + icon/thumbnail 1 รูป** | สถานะผู้เล่นอ่านได้ + หน้าเกมดูน่ากด | UI + Audio + Boss | 60 นาที |

ทุกอย่างทำจาก **Part เปล่า + ParticleEmitter + Light ที่มากับ Roblox** ไม่ต้องอัปโหลด mesh/texture/animation ใดๆ (ไม่มีความเสี่ยงเรื่อง moderation ก่อนเส้นตาย)

---

## 1. แฮมสเตอร์ (ตัวละครผู้เล่น)

**วิธีทำ**: เปิด Studio (Edit mode) → View > Command Bar → วางทั้งไฟล์ `tools/BuildHamster.luau` → Enter → กด Play

| หัวข้อ | ค่า |
|---|---|
| ฐาน | R15 ขนาดมาตรฐาน (สร้างจาก `Players:CreateHumanoidModelFromDescription`, scale 1.0) → hitbox, HipHeight, Animate, WalkSpeed เหมือน Roblox ปกติทุกอย่าง |
| ชิ้นตกแต่ง (welded) | ตัวกลม (ellipsoid 2.9 × 3.0 × 2.3), พุงสีครีม, หัวกลมโต 2.3 × 2.0 × 2.0, หู 2 ข้าง (ขอบนอก + ในสีชมพู), แก้มป่อง 2 ข้าง, ตาดำโต + จุดเงาขาว, จมูกชมพู, ฟันหน้า 2 ซี่, หางกลมจิ๋ว, มือ/เท้าสีชมพู |
| ความสูงรวม | ~6 studs (หูถึงเท้า) ≈ 12 cm การ์ตูน — ตรงกับ GDD (~5–5.5 + หู) |
| ทุกชิ้นตกแต่ง | `CanCollide/CanQuery/CanTouch = false`, `Massless = true`, `Weld` (C0 ชัดเจน) → ไม่กระทบ physics, raycast ของ impact และ animation |
| สี 2 แบบ (`FUR_VARIANT`) | `"Golden"` ขน (226,158,84) พุง (255,240,214) · `"WinterWhite"` ขน (176,180,196) พุง (250,250,255) — **ใช้ Golden เป็นค่าหลัก** (ตัดกับฉากกลางคืนโทนฟ้าได้ดีที่สุด) |
| Attachment (สัญญากับ UI/Systems) | `Head.StatusFxAttachment` (+1.6 เหนือหัว: ดาวหมุน/BONK!), `UpperTorso.PoofAttachment` (กลางตัว: Poof), `UpperTorso.CarryAttachment` (หน้าอก: จุดกอดถ่าน) |
| ตั้งค่าเพิ่ม | `StarterPlayer.LoadCharacterAppearance = false` (กันเสื้อ/หมวกของผู้เล่นมาติดตัวแฮมสเตอร์), ลบ face decal, Head โปร่งใส (ยังเป็น hitbox) |
| รันซ้ำได้ | ตัวเดิมที่สคริปต์สร้าง (Attribute `HamsterBuilder`) ถูกแทนที่ ส่วน StarterCharacter อื่นถูกเก็บเป็น `StarterCharacter_Backup_<เวลา>` ไม่ลบทิ้ง; Ctrl+Z ได้ |
| Fallback | ถ้า command bar เรียก `CreateHumanoidModelFromDescription` ไม่ได้: Avatar tab > Rig Builder > R15 > Block Rig (ได้ `workspace.Rig`) แล้วรันสคริปต์ซ้ำ |
| ภาพ preview | ตั้ง `SPAWN_PREVIEW = true` → วางตัวอย่าง anchored ที่ (0, 10, −3000) สำหรับถ่าย icon/thumbnail |

**ท่าทาง (ใช้ animation ของ Roblox ที่ใช้ได้ทุกเกม ไม่ต้องอัปโหลด — ยืนยัน ID ใน Studio)**

| สถานะ | ท่า | Animation ID (R15 default ของ Roblox) |
|---|---|---|
| Downed ("Dizzy!") | ท่านั่ง loop + คลาน 5 studs/s + ดาวหมุน (§3.4) | sit `rbxassetid://2506281703` |
| วิ่งวงล้อ (`RunInWheel`) | เล่นท่าวิ่งค้างไว้ขณะกด hold หันตามแนววงล้อ | run `rbxassetid://507767714` |
| อยู่ในกรง / กล้องตอนชนะ | โบกมือ | wave `rbxassetid://507770239` |
| ชนะ (Result) | เชียร์ | cheer `rbxassetid://507770677` |

ถ้า ID ไหนเล่นไม่ได้ → ใช้แค่ดาวหมุน/Billboard (ไม่ blocker)

---

## 2. Props ยักษ์ (เรียงตามความสำคัญ)

**กฎร่วมทุกชิ้น**
- ทุกโมเดลเป็น `Model` มี `PrimaryPart` (ชิ้นล่างสุดตรงกลาง), Part ทั้งหมด `Anchored = true`
- **ของตกแต่งที่ไม่ได้เดิน → `CanQuery = false`** (GDD 8.3, สำคัญมาก: `RandomPoint` ของ Big Shake raycast ลงจาก Y +120 ถ้าโดนชั้นวาง/กาต้มน้ำ ของจะไม่ตกบนเคาน์เตอร์) · พื้นที่เดินได้ทั้งหมด `CanQuery = true`
- ทางลาดทุกจุด = **`WedgePart` ล่องหน (Transparency 1) ชัน ≤ 35°** ส่วนเขียง/หนังสือ/ถาดเป็นภาพที่วางทับ (กฎ 8.3)
- Material: `SmoothPlastic` เป็นหลัก (เบาบนมือถือ), `Wood` / `Metal` / `Glass` / `Fabric` เฉพาะที่เขียน
- ชิ้นเล็กกว่า 1 stud ตั้ง `CastShadow = false`
- งบรวมทั้งแมพ: < 2,500 Part, ไฟที่มีเงา ≤ 3 ดวง

**พาเลตครัว** (lighting จะย้อมเป็นโทนกลางคืนให้เอง): กระเบื้องพื้นครีม (225,215,195) สลับ (200,190,170) · ผนังฟ้าเทา (150,160,185) · ตู้ไม้อุ่น (190,140,95) · ท็อปเคาน์เตอร์หินอ่อนอ่อน (230,225,215) · ตู้เย็นขาว (240,244,248) — ห้ามใช้พื้นสีเข้มเกิน (ตัวละครจะหายในความมืดบนมือถือ)

### P0 — ต้องมีเพื่อให้เกมเล่นได้ / Rescue Moment

| # | ของ | ขนาดจริง → studs | สูตร Part | หมายเหตุ |
|---|---|---|---|---|
| 1 | **วงล้อแฮมสเตอร์ + ไดนาโม** `[C]` (anchor `RunWheel`) | วงล้อ Ø28 × ลึก 14 cm → **Ø14 × 7**; ไดนาโม 12×8×8 cm → **6 × 4 × 4** | **แผ่นหลัง**: Cylinder (0.4, 14, 14) ฟ้าเขียวพาสเทล (110,210,200) · **ซี่ลวด** 24 ชิ้น: Cylinder ยาว 7 Ø0.35 ขาว (240,240,240) วางรอบวง r = 6.8 ทุก 15° · **ดุม**: Cylinder (1, 2, 2) เทาเข้ม · **ขาตั้ง**: Block (1, 8, 1) ×2 เอียง ±15° + ฐาน Block (10, 0.5, 9) · แกนวงล้อสูง 7.5 จากพื้น · **ไดนาโม**: Block (6,4,4) เขียว (70,180,90) + แถบเหลือง + หลอด Ball Ø1.2 ด้านบน + สายไฟแดง/ดำ Cylinder Ø0.3 วิ่งตามพื้นไปแท่นชาร์จ | ชิ้นวงล้อทั้งหมด `CanCollide = false` (ผู้เล่นยืนในวงล้อได้ไม่ติด) · `PromptPart` อยู่ในวงล้อสูงจากพื้น 2 · client หมุน Model ซี่ลวด 1.5 รอบ/วินาทีเมื่อ Progress เพิ่ม · หลอดไดนาโมเปลี่ยนจากเทา (90,90,100) → เหลือง Neon (255,220,90) ตาม Progress + PointLight Range 0 → 14 |
| 2 | **แท่นชาร์จถ่าน** `[B]` (socket `DeliverBatteries`) | ที่ชาร์จ 13×8×3.5 cm → **6.5 × 1.75 × 4** วางบนกล่องชุดวิทยาศาสตร์ 20×4×14 cm → **10 × 2 × 7** | กล่องฐาน Block (10,2,7) ส้ม (240,140,60) · ตัวชาร์จ Block (6.5,1.75,4) เทาเข้ม (60,64,76) · ช่องถ่าน 3 ช่อง: Block (2.7,0.3,0.8) ดำ · LED ต่อช่อง: Ball 0.4 Neon แดง (255,70,70) → เขียว (90,230,120) เมื่อเสียบแล้ว · ถ่านที่เสียบแล้ว = สำเนาถ่าน (#3) นอนในช่อง · สายไฟสีขาว Cylinder Ø0.4 วิ่งขึ้นข้างตู้เย็นไปเคาน์เตอร์ (เล่าเรื่องว่า "ไฟไปเลี้ยงวิทยุ") | ด้านบนสูง ~3.75 = ระดับอกแฮมสเตอร์ กดง่าย · deadline มี 3 ช่อง (count สูงสุด 3) · สายไฟ `CanQuery = false` |
| 3 | **ถ่าน AA** (item `Battery`) | 5 × 1.4 cm → **2.5 × 0.7** (GDD 1.1) | Cylinder Size (2.5, 0.7, 0.7) ส้มทอง (255,150,40) · ปลายลบ: Cylinder (0.5, 0.72, 0.72) ดำ · ขั้วบวก: Cylinder (0.12, 0.25, 0.25) `Metal` เงิน · **ทำให้หาเจอในที่มืด**: PointLight (255,210,110) Range 8, Brightness กะพริบ 0.6 ↔ 1.6 ที่ 1 Hz · `Highlight` OutlineColor (255,220,120), FillTransparency 0.85, DepthMode `Occluded` · ParticleEmitter ประกาย Rate 3 (§3.9) · เสียง hum loop 3D (§5) | ห้ามใช้สี/ลายของยี่ห้อจริง · ถือแนวนอนที่ `CarryAttachment` (Systems ตัดสิน) · Highlight ≤ 31 ชิ้นพร้อมกัน (มีถ่านแค่ 3) |
| 4 | **วิทยุของเล่น ×4** (anchor `CallForHelp` A–D บนเคาน์เตอร์) | วิทยุสื่อสารของเล่น 16×6×4 cm + เสาอากาศ 8 cm → **ตัว 3 × 8 × 2, เสา 4** | ตัว Block (3,8,2) สีตามตัวอักษร: **A แดง (255,90,90), B น้ำเงิน (80,150,255), C เหลือง (255,205,60), D เขียว (90,210,120)** · ตะแกรงลำโพง: Block (2.2,0.25,0.1) ดำ ×4 ด้านบนหน้า · **ปุ่มพูด (PTT)**: Cylinder (0.4,1.6,1.6) หันออกหน้า สูง 2.6 จากฐาน สีขาว · **ไฟบนหัว**: Ball 0.8 เทา (60,60,70) → Neon สีของเครื่อง + PointLight Range 12, Brightness 2 เมื่อมีคนกด · เสาอากาศ Cylinder ยาว 4 Ø0.3 ดำ + Ball 0.6 ปลาย · ตัวอักษร: SurfaceGui ด้านหน้า TextLabel "A"–"D" FredokaOne ขาว ขอบดำ | ปุ่มอยู่ระดับมือแฮมสเตอร์ · ห่างกัน ≥ 40 (8.3) · ตอนครบ: ไฟทั้ง 4 กะพริบพร้อมกัน 3 ครั้ง (0.15 s) |
| 5 | **กรงสัตว์เลี้ยง `RescueCarrier`** (exitVehicleAsset) | กรงแมว/หมาขนาดใหญ่ 52×36×34 cm → **26 × 17 × 18** | **ทุกชิ้น `CanCollide/CanQuery/CanTouch = false`** (ไม่ดันผู้เล่นตอนหย่อนลงมา) · ถาดล่าง Block (26,6,18) ฟ้า (70,150,230) · ฝาบน Block (26,9,18) ขาว (240,240,235) + โดม Block (26,3,18) ใส่ Sphere SpecialMesh · ช่องระบายอากาศ: Block (4,1,0.2) เทาเข้ม ×3 ต่อข้าง · **ประตูตะแกรง** (ด้านกว้าง 18 หันเข้าหน้าต่าง): กรอบ + ซี่ Cylinder ยาว 13 Ø0.5 `Metal` (180,185,195) ×7 **เปิดอ้า 110°** · หูหิ้ว: เสา Block (1,2,1.5) ×2 + ด้ามจับ Block (8,1,1.5) เทาเข้ม + `Attachment` ชื่อ `RopeAttachment` · เบาะในกรง Block (24,0.6,16) ชมพู (255,200,210) `Fabric` · สติกเกอร์ข้างกรง: SurfaceGui รูปหัวใจ + อุ้งเท้า (ห้ามใช้โลโก้หน่วยงานจริง) | `PrimaryPart` = `Base` (กลางฐาน) วางตรง `ExitVehicleSpot` · เก็บที่ `ReplicatedStorage.Assets.RescueCarrier` (ยืนยันชื่อ path กับ Scripter) · tween/ไฟฉายดู §3.8 |
| 6 | **หน้าต่างเหนือซิงก์ + ขอบหน้าต่าง** (`LockedDoor`, `UnlockedBy = WindowOpen`) | ช่องหน้าต่าง 120×100 cm → **60 × 50**, ขอบหน้าต่างสูง 122 cm → **+61**, ลึก 20 cm → **10** | กรอบ `Wood` ขาว (245,245,240) หนา 2 · บาน 3 บาน: Part (20, 48, 0.4) `Glass` Transparency 0.55 สี (180,210,255) Reflectance 0.1 — **บานกลาง + บานตะวันตก** เลื่อนเปิด (tween 1.5 s ไปซ้อนบานข้างๆ) · ขอบหน้าต่าง (พื้นเดิน) Block (กว้างเท่าผนังช่วงหน้าต่าง, 1, 10) ขาว `CanQuery = true` | spawn ขอบหน้าต่าง ×2 อยู่ที่นี่ (ไม่มี NoImpact ตาม 8.3) · ภาพนอกหน้าต่าง §2 #22 |
| 7 | **กระบะดอกไม้** (Exit Zone 24 × 24 ด้านนอก) | กระบะใหญ่ 60×52×18 cm → **30 × 9 × 26** | ผนังกระบะ Block หนา 1 สีดินเผา (200,110,70) · ผิวดิน Block (28,1,24) (90,60,40) `Ground` — **ผิวบนอยู่ที่ +61 พอดี** (เดินจากขอบหน้าต่างออกมาได้แบบเรียบ) `CanQuery = true` · ดอกไม้ 4 ต้นที่มุม: ก้าน Cylinder ยาว 8–12 Ø0.5 เขียว (80,170,80) + กลีบ Ball 1.6 ×6 (ชมพู/ขาว/ม่วง) + เกสร Ball 1.2 เหลือง + ใบ ellipsoid | ดอกไม้ `CanCollide/CanQuery = false` · เว้นกลาง 20 × 20 ให้กรงลง · `ExitZone` Part (24 × 10 × 24, CanCollide false) ครอบดิน |
| 8 | **ที่คว่ำจาน** (ทางหลัก เคาน์เตอร์ +45 → ขอบหน้าต่าง +61) | ที่คว่ำจาน 45×32×14 cm → **22.5 × 7 × 16**, จาน Ø26 cm → **Ø13** | **ทางเดิน**: WedgePart ล่องหน (กว้าง 10, สูง 16, ยาว 26 → ชัน 31.6°) · ภาพบนทางลาด: ถาดอบขนม Block (10, 0.6, 30.5) `Metal` (200,200,210) วางทับผิว wedge · ตะกร้า: Block บาง 0.4 `Metal` เทาอ่อนเป็นกรอบ 22.5 × 7 × 16 · จาน 6 ใบ Cylinder (0.6, 13, 13) ตั้งในช่อง สีขาว/ขอบพาสเทล | จาน/ตะกร้า `CanQuery = false` · ถาด+wedge `CanQuery = true` (impact ต้องตกบนทางลาดได้ตาม QA) · จานสั่นกระทบกันตอน Pulse (§3.6) |
| 9 | **ผ้าม่าน** (ทางสำรอง พื้น → ขอบหน้าต่างฝั่งตะวันตก) | ผ้าม่านยาวถึงพื้น ราวสูง 232 cm → **+116**, กว้างรวบ 60 cm → **30** | จีบผ้า 6 ชิ้น: Cylinder ตั้ง ยาว 115 Ø5 สลับสี (120,170,230) / (100,150,210) `Fabric` ห่างกัน 5 · ราว Cylinder Ø1.5 ยาว 40 ไม้ · **ปีน**: `TrussPart` (2, 62, 2) Transparency 1 แนบหน้าผ้าม่าน จากพื้นถึง +62 · ขั้นเล็กที่ยอดให้ก้าวขึ้นขอบหน้าต่าง | จีบผ้า `CanCollide/CanQuery = false`, Truss `CanQuery = true` · ช่วง ETA ผ้าม่านแกว่ง ±4° ที่ 0.4 Hz (ลมเข้าหน้าต่าง) |
| 10 | **กรงที่ล้ม + กองทิชชู่** `[A]` (spawn ×4) | กรงแฮมสเตอร์ 60×40×40 cm → **30 × 20 × 20** นอนตะแคง | ถาดกรง (ตอนนี้ตั้งเป็นผนัง) Block (30,20,1) เขียวมิ้นต์ (90,200,180) · ซี่กรง Cylinder Ø0.3 ทุก 2 studs (~25 ซี่) `Metal` (230,230,240) · ประตูกรงเปิดค้างหันเข้าห้อง · ขี้เลื่อย 12 ชิ้น Block 1–2 (235,210,160) · **กองทิชชู่** (จุด respawn): ellipsoid ขาว 3–5 studs ×6 · ชามอาหารคว่ำ Cylinder (1.5, 6, 6) + เมล็ดทานตะวันหก (Block 0.6 เทาเข้ม ×10) · ขวดน้ำ Cylinder ยาว 10 Ø3 ฟ้าใส Transparency 0.4 | ซี่กรง `CanCollide = false` (กันติด) · ถาด `CanCollide = true` · NoImpact r=6 รอบ spawn (Level) |
| 11 | **Debris (propPool)** — ของที่ตกใส่ | แอปเปิล Ø8 cm → **Ø4** · กระป๋องซุป Ø7.5 × 10 cm → **Ø3.75 × 5** · ฟองน้ำ 10×7×3 cm → **5 × 1.5 × 3.5** | **Apple**: Ball 4 แดง (200,40,50) + ก้าน Cylinder (0.8 × Ø0.25) น้ำตาล + ใบ ellipsoid (1,0.15,0.6) เขียว · **SoupCan**: Cylinder ตั้ง (5, 3.75, 3.75) `Metal` เงิน + แถบฉลาก Cylinder (3, 3.8, 3.8) แดง (210,60,50) · **Sponge**: Block (5,1.5,3.5) เหลือง (255,220,70) + ชั้นขัด Block (5,0.5,3.5) เขียว (60,150,70) · (สำรอง) **Spoon** 18 cm → ด้าม Block (6.5,0.3,0.8) + หัว ellipsoid (2.5,0.4,1.6) `Metal` · **MilkCarton** 20×7×7 cm → Block (3.5,7.5,3.5) ขาวแถบฟ้า + Wedge หลังคา | ทุกชิ้น `Anchored`, `CanCollide/CanQuery/CanTouch = false` (deadline: ภาพอย่างเดียว จางใน 3 s), `CastShadow = true` (เงาที่โตขึ้นช่วยบอกจุดตก) · เก็บที่ `ReplicatedStorage.Assets.Debris.{Apple, SoupCan, Sponge}` ชื่อต้องตรง `propPool` ใน DisasterDef |

### P1 — ฉากใหญ่ที่ทำให้ "อ่านสเกลออก" (ช็อต "แฮมสเตอร์เทียบโต๊ะยักษ์")

| # | ของ | ขนาดจริง → studs | สูตร Part | หมายเหตุ |
|---|---|---|---|---|
| 12 | **เคาน์เตอร์ตัว L** | สูง 90, ลึก 60 cm → **+45, ลึก 30** | ตู้ล่าง Block สูง 43 (190,140,95) + เส้นแบ่งบานตู้ Block บาง 0.3 สีเข้มกว่า ทุก 20 studs + มือจับ Cylinder Metal · ท็อป Block หนา 2 ยื่นออก 1.5 `Marble` (230,225,215) · ช่องเท้า (ล่างสุด) Block สูง 5 ร่นเข้า 2.5 สีเข้ม (60,45,40) | ท็อป `CanQuery = true` |
| 13 | **ตู้เย็น** `[B]` | 180×70×70 cm → **90 × 35 × 35** | Block ขาว (240,244,248) · เส้นแบ่งช่องฟรีซที่ +55 · มือจับ Cylinder ยาว 30 Ø1.5 `Metal` · แม่เหล็ก Block (3,3,0.5) สีสด ×4 · (เสริม) รูปวาดเด็ก SurfaceGui | `CanQuery = false` (ยกเว้นถ้าใช้เดิน) · แหล่งเสียง fridge hum |
| 14 | **โต๊ะกินข้าว + เก้าอี้** `[T]` | โต๊ะสูง 75, หน้า 120×80 cm → **ท็อป 60 × 1.5 × 40 ที่ +37.5**, ขา 2.5 × 36 × 2.5 · เบาะเก้าอี้ 46 cm → **+23**, เบาะ 21 × 2 × 21, พนัก ถึง +45 | `Wood` (170,115,75) · ขาเก้าอี้ Block (2,22,2) · พนัก Block (21,22,1.5) | ใต้โต๊ะคือโซนถ่าน T — มองจากมุมแฮมสเตอร์จะเห็นใต้ท้องโต๊ะ (ช็อตสเกลที่ดีที่สุด) |
| 15 | **เขียงยาวพิง** (พื้น → เบาะเก้าอี้ +23) | เขียงขนมปังยาว 86 × 28 cm → **43 × 1 × 14** | ภาพ: Block (14, 1, 43) `Wood` (205,160,110) วางทับ · ทางเดิน: WedgePart ล่องหน (14, 23, 36) → **32.6°** | |
| 16 | **ตำราอาหารเป็นขั้น** (เบาะเก้าอี้ +23 → เคาน์เตอร์ +45) | หนังสือ 28×21×3 cm → **14 × 1.5 × 10.5** | กองหนังสือเป็นขั้นบันได (ภาพ) สีปก (220,80,70) / (70,130,200) / (240,190,60) / (90,170,110) + ขอบกระดาษ Block บาง สีครีม · ทางเดิน: WedgePart ล่องหน (12, 22, 34) → **32.9°** | |
| 17 | **ชั้นรองเท้า + รองเท้า** `[S]` | ชั้น 60×30×45 cm → **30 × 22.5 × 15** (2 ชั้น) · รองเท้าผ้าใบ 28×10×10 cm → **14 × 5 × 5** | ชั้น `Wood` · รองเท้า: Block ตัว + Wedge หัว + พื้นรองเท้า Block ขาว 0.8 · รองเท้าแตะขนฟู ellipsoid ชมพู | ถ่านโซน S อยู่ระหว่างรองเท้า |
| 18 | **ชั้นวางเปิด + ของที่สั่นจนล้ม** (ผนังเหนือเคาน์เตอร์) | แผ่นชั้น 80×25 cm → **40 × 1 × 12.5** ที่ +85 และ +105 · กล่องซีเรียล 30×20×7 cm → **15 × 10 × 3.5** · โหล Ø10×15 cm → **Ø5 × 7.5** · แก้ว Ø8×10 cm → **Ø4 × 5** · จานซ้อน Ø26 → **Ø13** | กล่องซีเรียลสีสด (ไม่มีโลโก้จริง) · โหล Cylinder `Glass` Transparency 0.4 + ฝา Cylinder สี · ตอน Pulse: ของโยก (§3.6) · Critical/Big Shake: 2–3 ชิ้นไถลตกจากชั้น (tween ภาพ แล้วหาย) | **ทุกชิ้น `CanQuery = false`** มิฉะนั้น Big Shake จะไม่มีของตกบนเคาน์เตอร์ |
| 19 | **ซิงก์ + ก๊อกน้ำ** (เคาน์เตอร์ใต้หน้าต่าง) | อ่าง 50×40 cm → **25 × 20** · ก๊อกสูง 30 cm → **15** | อ่าง**แบบแบน ไม่มีหลุม** (กันตก): ขอบ Block (25,0.4,20) `Metal` (190,195,205) + ด้านใน Block (21,0.3,16) (60,65,75) · ก๊อก: ฐาน Cylinder Ø3 สูง 2 + ท่อตั้ง Cylinder ยาว 15 Ø1.5 + ปาก Cylinder ยาว 8 + คันโยก · (เสริม) หยดน้ำ ParticleEmitter Rate 0.5 | ก๊อก `CanQuery = false` · อ่าง `CanQuery = true` |
| 20 | **ของบนเคาน์เตอร์ที่บังสายตา** | กาต้มน้ำ สูง 25 Ø18 cm → **12.5 × Ø9** · โถขนมปัง 40×25×20 cm → **20 × 12.5 × 10** · ชามผลไม้ Ø25 → **Ø12.5** · เครื่องปิ้งขนมปัง 28×20×16 cm → **14 × 10 × 8** | กาต้มน้ำ Cylinder มิ้นต์ (150,220,200) + หูจับ + Wedge ปาก · โถขนมปัง Block + ฝาโค้ง ellipsoid ครีม · ชาม Cylinder + แอปเปิล Ball 4 ×3 · เครื่องปิ้ง Block `Metal` + ช่องดำ 2 ช่อง | `CanQuery = false` · อย่าวางทับเส้นทางระหว่างวิทยุ |
| 21 | **ประตู pantry** `[P]` (ปิด) | 200 × 80 cm → **100 × 40** | Block (40, 100, 2) `Wood` + ลูกบิด Ball 3 ที่ +45 · (เสริม) แสงอุ่นลอดใต้ประตู SurfaceLight Range 8 | |

### P2 — ถ้ามีเวลา (หลัง CP3 ตกแต่งเพิ่ม)

| # | ของ | สูตรสั้น |
|---|---|---|
| 22 | **ฉากนอกหน้าต่าง** (เห็นในกล้องตอนชนะ!) | ผนัง backdrop Part (400 × 200 × 1) กรมท่า (20,25,45) ห่างหน้าต่าง 150 studs + หน้าต่างบ้านฝั่งตรงข้าม Block Neon อุ่น (255,210,140) ×8 · **รถดับเพลิง** (ไกล): Block (60,25,20) แดง (200,40,40) + ล้อ Cylinder ดำ + lightbar Neon แดง/น้ำเงิน (ไฟกู้ภัย §3.7 ติดที่นี่) · ไม่ต้องโชว์ตัวนักดับเพลิง (มีแค่เชือก + ไฟฉายจากด้านบน) |
| 23 | **นาฬิกาแขวน / ปลั๊ก / ไฟกลางคืน** | นาฬิกา Ø30 cm → Cylinder Ø15 บนผนัง (เสียงติ๊ก) · ไฟกลางคืนเสียบปลั๊กใกล้มุมกรง: Ball 2 Neon อุ่น + PointLight (§4.3) |
| 24 | **Lobby** | แท่นกลม Cylinder (2, 80, 80) สีขี้เลื่อย (230,200,150) + เมล็ดทานตะวันยักษ์ (ellipsoid ลายดำ/ขาว 6 × 2.5 × 3) เป็นที่นั่ง + ป้าย SurfaceGui "WE R IN TROUBLE" + "Needs 2–4 players" |
| 25 | **ฝุ่นเพดาน** | ParticleEmitter บน Part บางใต้เพดาน ช่วง Critical (§3.6) |

---

## 3. VFX (ทั้งหมดเป็น client, Part/Particle/Light ของ Roblox)

Texture ที่ใช้ได้เลยไม่ต้องอัปโหลด: `rbxasset://textures/particles/smoke_main.dds` (ควัน/ฝุ่น), `rbxasset://textures/particles/sparkles_main.dds` (ประกาย/ดาว), `rbxasset://textures/particles/fire_main.dds`
ทุก Part ของ VFX: `Anchored = true`, `CanCollide/CanQuery/CanTouch = false`, `CastShadow = false` · ลบด้วย `Debris:AddItem` เสมอ · จำกัดวงเตือนพร้อมกัน ≤ 24 วง (มือถือ)

### 3.1 วงเตือน (TelegraphedImpact telegraph)
| ชิ้น | ค่า |
|---|---|
| ขอบขาว (outline) | Cylinder วางนอน `Size (0.15, 2r + 0.6, 2r + 0.6)` สีขาว (255,255,255) `Neon` Transparency 0.35 — ช่วยให้เห็นบนของสีแดง/พื้นสว่าง |
| วงแดง | Cylinder `Size (0.2, 2r, 2r)` สี (255,60,60) `SmoothPlastic` Transparency 0.45 · r = `radius` (Earthquake = 5 → Ø10) |
| ไส้ที่โตขึ้น (timer) | Cylinder สี (255,40,40) `Neon` Transparency 0.25 · tween ขนาดจาก 0 → 2r ใน `telegraph` วินาที (1.5 / 1.2) แบบ Linear → ผู้เล่นรู้ว่าเหลือเวลาเท่าไร |
| กะพริบท้าย | 0.4 s สุดท้าย: Transparency ของวงแดงสลับ 0.2 ↔ 0.55 ทุก 0.1 s |
| ตำแหน่ง | Y = จุดตกบนพื้น + 0.08 (outline) / + 0.12 (วงแดง) / + 0.16 (ไส้) กัน z-fighting · หมุน `CFrame.Angles(0, 0, math.rad(90))` ให้แบนกับพื้น |
| จบ | ทันทีที่ของถึงพื้น: ลบวง |

### 3.2 Debris ตก
| ค่า | |
|---|---|
| เริ่ม | clone จาก `Assets.Debris` แบบสุ่ม หมุนสุ่ม (0–360° ทุกแกน) ที่ +30 เหนือจุดตก |
| ตก | tween `PivotTo` ด้วย `CFrameValue` ใน `telegraph` วินาที, EasingStyle **Quad**, Direction **In** (เร่งลง) + หมุนเพิ่ม 180° ระหว่างตก |
| ถึงพื้น | เด้งเล็ก: ขึ้น 0.6 ใน 0.08 s แล้วลง (Quad Out) · ฝุ่น (3.3) · ถ้าผู้เล่น local อยู่ใน 15 studs: shake สั้น 0.15 studs 0.2 s |
| จางหาย | ค้าง 2.4 s → tween Transparency ทุกชิ้น → 1 ใน 0.6 s → Destroy (รวม 3 s ตาม 8.6) |

### 3.3 ฝุ่นตอนกระแทก + "BONK!" ตอนโดน
| เอฟเฟกต์ | ค่า |
|---|---|
| ฝุ่นกระแทก | ParticleEmitter (Enabled false, ใช้ `:Emit(12)`) · Texture smoke_main · Color (210,195,170) · Size 0:1 → 1:3 · Transparency 0:0.3 → 1:1 · Lifetime 0.4–0.7 · Speed 6–10 · SpreadAngle (180, 10) · Drag 5 · Acceleration (0, 2, 0) |
| ข้อความ BONK! (โดน damage) | BillboardGui ที่ `Head.StatusFxAttachment`, Size `UDim2.fromScale(4, 2)` (หน่วย studs), AlwaysOnTop false · TextLabel "BONK!" FredokaOne, TextScaled, สี (255,230,90), UIStroke 3 สี (38,30,58) · pop: scale 0 → 1.2 → 1 ใน 0.15 s (Back Out) แล้วลอยขึ้น 2 studs + จางใน 0.6 s · หมุนสุ่ม −12°..12° |
| ดาวกระจาย | ParticleEmitter `:Emit(8)` · Texture sparkles_main · Color (255,230,90) → (255,255,255) · Size 0:0.6 → 1:0 · Lifetime 0.5 · Speed 8 · SpreadAngle (180,180) · LightEmission 0.5 · RotSpeed 180 |
| UI | แถบ HP สั่น (UI ทำแล้วตาม 5.2) — **ห้ามจอแดง/เลือด** |

### 3.4 ดาวหมุน (Downed / "Dizzy!")
| ค่า | |
|---|---|
| โครง | client สร้าง Part ล่องหน 0.2 (Massless, CanCollide false) ชื่อ `DizzyRing` weld ที่ `Head` ตำแหน่ง `StatusFxAttachment` (+1.6) · หมุน `Weld.C0 *= CFrame.Angles(0, dt * 4, 0)` ทุกเฟรม (~0.65 รอบ/วินาที) |
| ดาว 3 ดวง | Attachment 3 อันบน `DizzyRing` ที่รัศมี 0.9 ห่างกัน 120° · แต่ละอันมี BillboardGui Size `fromScale(0.9, 0.9)` + TextLabel "★" สี (255,225,80), UIStroke 2 สี (120,80,20) · ขึ้นลงเล็กน้อย ±0.15 (sin, ห่างเฟส 120°) |
| หาง | ParticleEmitter บนแต่ละ Attachment: Texture sparkles_main, Rate 12, Lifetime 0.3, Size 0.4 → 0, Color เหลือง, LightEmission 0.6, Speed 0 |
| สีม่วง Dizzy | ใช้ `Style.Color.Dizzy` (176,140,255) กับ marker บน HUD ที่เพื่อนเห็น (UI มีแล้ว) |
| ท่า | sit loop (§1) + ความเร็วคลาน 5 |
| ตอน revive สำเร็จ | ดาวกระจายออก `:Emit(10)` สีเหลือง+เขียว (118,226,140) + เสียง revive → ลบ ring |

### 3.5 Poof (Eliminated / "Poofed!") และ Respawn
| เอฟเฟกต์ | ค่า |
|---|---|
| Poof | ก่อนลบ character: สร้าง Part ล่องหน anchored ที่ตำแหน่ง `PoofAttachment` · ParticleEmitter ควันขน `:Emit(30)`: Texture smoke_main, Color = สีขน → (255,255,255), Size 0:1.5 / 0.3:3.5 / 1:4.5, Transparency 0:0.1 / 0.7:0.4 / 1:1, Lifetime 0.6–1.0, Speed 8–14, Drag 6, SpreadAngle (180,180), Rotation 0–360, RotSpeed −60..60 |
| ปุยขนลอย | ParticleEmitter ที่สอง `:Emit(12)`: Texture sparkles_main, Color ขาว/สีขน, Size 0.5, Lifetime 1.5–2, Speed 4, Acceleration (0, −3, 0), Drag 2 (ลอยลงช้าๆ) |
| ข้อความ | Billboard "POOF!" สี (150,176,210) = `Style.Color.Poof` pop แบบเดียวกับ BONK! · Destroy Part หลัง 2.5 s |
| Respawn "โผล่จากกองทิชชู่" | ที่ spawn: `:Emit(10)` สี่เหลี่ยมขาว (Texture sparkles_main, Color ขาว, Size 0.8, Speed 10, Acceleration (0,−20,0), Lifetime 0.8) + เสียง pop |

### 3.6 Shake ต่อ Stage (ScreenEffect `shake`)
ทำด้วย `Humanoid.CameraOffset` = noise (ใช้ได้กับกล้อง default ทั้ง PC/มือถือ) + เอียงกล้อง (roll) ด้วย `RunService:BindToRenderStep(..., Enum.RenderPriority.Camera.Value + 1, ...)`

| ระดับ (intensity) | ใช้ตอน | Amplitude (studs) | Roll สูงสุด | ความถี่ noise | fade in / out |
|---|---|---|---|---|---|
| `0` | Calm | 0 | 0 | — | — |
| `light` | Warning pulse 3 s | 0.15 | 0.4° | 12 Hz | 0.3 / 0.5 s |
| `medium` | Active pulse 5 s | 0.35 | 0.9° | 14 Hz | 0.3 / 0.5 s |
| `strong` | Critical pulse 7 s | 0.6 | 1.5° | 16 Hz | 0.3 / 0.6 s |
| `max` | **Big Shake 4 s** | 1.0 | 2.5° | 18 Hz | 0.2 / 0.8 s |

สูตร: `offset = Vector3.new(noise(t*f, 0), noise(0, t*f), noise(t*f, t*f)) * A * env(t)` (`math.noise`, env = fade) · หยุดทันทีเมื่อ Downed/ไม่มี character · ระหว่างกล้องตอนชนะ (Scriptable) ใช้ 50% ของค่า

**ของในฉากสั่นตาม (ทำพร้อม pulse)**:
- ของบนชั้น/เคาน์เตอร์ (#18, #20) และจานในที่คว่ำจาน (#8): โยกรอบขอบล่าง ±3° / ±6° / ±10° / ±14° (light/medium/strong/max) ที่ 8 Hz สุ่มเฟสต่อชิ้น
- ฝุ่น/เศษขนมปังร่วงจากใต้ชั้น: ParticleEmitter ใต้แผ่นชั้น Rate 0 ปกติ → 8 / 15 / 25 / 40 ตอน pulse · Texture smoke_main · Color (200,180,150) · Size 0.3–0.6 · Lifetime 1.5 · Speed 0 · Acceleration (0, −20, 0)
- Critical: ฝุ่นเพดาน (#25) Rate 20 ระหว่าง pulse
- Active: ไฟกลางคืน/ไฟใต้ชั้นกะพริบ — ทุก 2–5 s ลด Brightness เหลือ 0.15 นาน 0.05–0.2 s (เฉพาะระหว่าง pulse)

### 3.7 ไฟกู้ภัยแดง/น้ำเงิน (นอกหน้าต่าง, เริ่มตอนทางออกปลดล็อก)
| ค่า | แดง | น้ำเงิน |
|---|---|---|
| Part | Block (2,1,2) Neon (255,40,40) | Block (2,1,2) Neon (40,90,255) |
| SpotLight | Color (255,40,40), Brightness 6, Range 60, Angle 50, Face Front, **Shadows true** | Color (40,90,255), Brightness 6, Range 60, Angle 50, Face Front, Shadows **false** (ประหยัด) |
| ตำแหน่ง | นอกหน้าต่าง ห่าง 40 studs, สูง +50 (ต่ำกว่าขอบหน้าต่างเล็กน้อย = รถอยู่บนถนน) ห่างกัน 6 studs | |
| การเคลื่อนไหว | หมุนรอบแกน Y 180°/s (0.5 รอบ/วินาที) แต่ละดวงเฟสต่างกัน 180° → แสงกวาดผ่านผนังครัวสลับสี · ทับด้วยกะพริบ Brightness 6 ↔ 2 ที่ 2 Hz สลับกัน | |
| เสียง | ไซเรนผูกกับโมเดลนี้ (3D) Volume ไต่ 0.3 → 0.8 ตลอด ETA 60 s |

### 3.8 กรงหย่อนลงมา + ไฟฉาย
| ขั้น | ค่า |
|---|---|
| หย่อน (`CARRIER_DESCEND_TIME = 3`) | `RescueCarrier` จาก `ExitVehicleSpot` +60 → spot, EasingStyle **Quad Out** · ระหว่างหย่อนแกว่ง ±3° (sin 1 Hz, ลดลงจนเป็น 0 ตอนถึง) |
| ลงถึง | เด้ง: ลง −0.5 แล้วกลับ 0 ใน 0.25 s · ฝุ่น (3.3) `:Emit(20)` · เสียง clunk |
| เชือก | Part ล่องหน `RopeAnchor` ที่ spot +60 + `RopeConstraint` (Attachment บน RopeAnchor ↔ `RopeAttachment` ของกรง) Visible true, Thickness 0.35, Color (205,180,130) · ตั้ง `Length` = ระยะจริงทุกเฟรม (เชือกตึง) |
| ไฟฉาย | Part ล่องหน `Flashlight` ที่ spot + (0, 60, −8) (เยื้องเข้าหาบ้าน) หันตามกรงทุกเฟรม `CFrame.lookAt` · SpotLight Color (255,244,214), Brightness 8, Range 75, Angle 35, Face Front, **Shadows true** |
| ลำแสง | `Beam` จาก Attachment ที่ไฟฉาย → Attachment บนฐานกรง · Width0 1, Width1 12, Color (255,244,214), Transparency 0:0.6 → 1:1, LightEmission 1, FaceCamera true, Segments 1 · ฝุ่นในลำแสง: ParticleEmitter Rate 15, Size 0.15, Lifetime 2, Speed 0.5, LightEmission 1 |
| ชนะ | กรงถูกดึงขึ้น +60 ใน 3 s (Quad In) พร้อมแฮมสเตอร์ (ท่า wave) · confetti `:Emit(60)` สีจาก Style (gold/pink/mint) Size 0.4, Speed 15, Acceleration (0,−15,0) · ครัวด้านหลังยังมี debris ตก (8.6.1) |

### 3.9 ไฮไลต์ objective / item (อ่านง่ายบนมือถือ)
| ของ | เอฟเฟกต์ |
|---|---|
| ถ่าน (บนพื้น) | PointLight กะพริบ 1 Hz + Highlight ขอบทอง + ParticleEmitter ประกาย: Texture sparkles_main, Rate 3, Lifetime 1, Size 0.4, Color (255,220,120), LightEmission 1, Speed 1 |
| แท่นชาร์จ | LED แดง → เขียว ต่อช่อง; ครบ 3/3 → PointLight เขียว Range 14 + ประกาย `:Emit(20)` |
| วงล้อ | ซี่หมุน + หลอดไดนาโมสว่างตาม Progress |
| วิทยุ | ไฟบนหัวติด + PointLight เมื่อมีคนกด; Step เสร็จ → กะพริบพร้อมกัน 3 ครั้ง |
| Step ถัดไป | world marker เป็นงาน UI (8.6 HUD #3) |

---

## 4. Lighting 4 preset

### 4.1 ตั้งครั้งเดียวใน Studio (ไม่ใช่ runtime)
วางใน Command Bar:
```lua
local L = game.Lighting; L.Technology = Enum.Technology.ShadowMap; L.GlobalShadows = true; L.ShadowSoftness = 0.3; L.ClockTime = 0; L.GeographicLatitude = 20
for _, n in {"Atmosphere","ColorCorrectionEffect","BloomEffect"} do if not L:FindFirstChildOfClass(n) then Instance.new(n, L) end end
```
- `ShadowMap` = สมดุลดีที่สุดระหว่างสวยกับมือถือ (Future แพงเกินบนมือถือ)
- **กฎอ่านออกบนมือถือ**: มือถือสเปกต่ำปิดเงา/Atmosphere/Bloom และไฟบางดวงเอง → ฉากต้องอ่านออกจาก `Ambient` อย่างเดียว ⇒ **ค่าเฉลี่ย RGB ของ `Ambient` ≥ 80 ทุก preset**, ไม่มีพื้นที่เดินสีเข้มกว่า (120,120,120) ก่อนย้อมแสง
- ความมืดแบบ "เที่ยงคืน" มาจาก **โทนสี (ฟ้า/ม่วง) + contrast** ไม่ใช่จากการลดความสว่าง

### 4.2 ตาราง preset (client tween 2 s ระหว่าง preset, เข้า Critical ใช้ 1 s)

| Property | **Lobby** (อบอุ่น เป็นมิตร) | **Calm** (เที่ยงคืน แสงจันทร์) | **Active** (ฝุ่น โทนอุ่น ตึงขึ้น) | **Critical** (ไฟกู้ภัย ตื่นเต้น) |
|---|---|---|---|---|
| `ClockTime` | 17.6 | 0 | 0 | 0 |
| `Brightness` | 2 | 1.2 | 1.2 | 1.2 |
| `Ambient` | (150,135,150) | (82,90,128) | (96,84,104) | (104,76,92) |
| `OutdoorAmbient` | (160,145,160) | (95,105,145) | (112,92,104) | (124,84,104) |
| `ColorShift_Top` | (255,214,170) | (170,190,255) | (255,190,140) | (255,150,150) |
| `ColorShift_Bottom` | (60,40,60) | (40,40,70) | (60,40,40) | (70,30,50) |
| `EnvironmentDiffuseScale` | 0.4 | 0.25 | 0.25 | 0.25 |
| `EnvironmentSpecularScale` | 0.4 | 0.4 | 0.3 | 0.4 |
| `ExposureCompensation` | 0.2 | 0.35 | 0.3 | 0.3 |
| Atmosphere `Density` | 0.25 | 0.25 | 0.35 | 0.40 |
| Atmosphere `Offset` | 0.1 | 0.15 | 0.2 | 0.2 |
| Atmosphere `Color` | (255,214,170) | (120,135,190) | (170,140,140) | (180,120,130) |
| Atmosphere `Decay` | (180,120,140) | (60,60,110) | (90,60,70) | (110,50,70) |
| Atmosphere `Glare` / `Haze` | 0.2 / 1 | 0 / 0.8 | 0 / 1.2 | 0 / 1.5 |
| ColorCorrection `Brightness` | 0.03 | 0.04 | 0.03 | 0.02 |
| ColorCorrection `Contrast` | 0.08 | 0.12 | 0.18 | 0.22 |
| ColorCorrection `Saturation` | 0.15 | −0.05 | 0 | 0.1 |
| ColorCorrection `TintColor` | (255,248,236) | (225,232,255) | (255,236,220) | (255,225,230) |
| Bloom `Intensity` / `Size` / `Threshold` | 0.6 / 24 / 1.8 | 0.5 / 24 / 1.6 | 0.5 / 24 / 1.6 | 0.8 / 28 / 1.4 |

- **Warning** (15 s) ไม่มี preset แยก: ใช้ Calm แต่ tween `TintColor` → (255,225,190) ใน 0.5 s (โทนส้มตาม 4.1) + ไซเรนไกล 1 ครั้ง
- **Collapse**: UI fade จอดำ 1 s (ไม่แตะ Lighting)
- ถ้าต้องตัดตาม 8.10 ข้อ 5: ใช้ Calm ตลอด + Critical ตอนทางออกปลดล็อก (+ ไฟกู้ภัย)

### 4.3 ไฟประจำแมพ (วางโดย Level, ไม่เปลี่ยนตาม preset ยกเว้นที่เขียน)
| ไฟ | ค่า | เหตุผล |
|---|---|---|
| **แสงจันทร์ลอดหน้าต่าง** | Part ล่องหนนอกหน้าต่าง 30 studs สูง +90 เอียงลง · SpotLight (170,190,255), Brightness 2, Range 90, Angle 60, **Shadows true** | "แผ่นแสงจันทร์" บนพื้น = ภาพจำของฉาก · ปิดตอน Critical (แทนด้วยไฟกู้ภัย) |
| **ไฟใต้ชั้น/ตามเคาน์เตอร์** | Part บางใต้ชั้นวาง (#18) ยาวตามเคาน์เตอร์ · SurfaceLight Face Bottom, (255,220,170), Brightness 1.2, Range 16, Angle 90 | เคาน์เตอร์ (วิทยุ A–D) อ่านออกบนมือถือ · กะพริบตอน Active pulse |
| **ไฟกลางคืนมุมกรง** | Ball Neon อุ่น + PointLight (255,200,140), Brightness 1, Range 30 | จุด spawn อบอุ่น อ่านง่าย |
| **ไฟตู้เย็น/แท่นชาร์จ** | PointLight (200,230,255), Brightness 0.8, Range 20 ที่ฐานตู้เย็น | ชี้ทางไป socket |
| **ไฟกู้ภัย ×2 + ไฟฉาย** | §3.7, §3.8 | เปิดเฉพาะตอนทางออกปลดล็อก |
| งบ | รวม ≤ 12 ดวง, เงา ≤ 3 ดวง (จันทร์ / ไฟกู้ภัยแดง / ไฟฉาย) | มือถือ |

### 4.4 ค่าสำหรับวางใน Config (ให้ UI/Scripter ใช้ตรงๆ)
```lua
--!strict
-- suggested: src/shared/Config/LightingPresets.luau (owner: UI). Values from docs/assets/ArtAudio-deadline.md §4.2
export type Preset = {
	ClockTime: number, Brightness: number, Ambient: Color3, OutdoorAmbient: Color3,
	ColorShift_Top: Color3, ColorShift_Bottom: Color3, EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number, ExposureCompensation: number,
	Atmosphere: { Density: number, Offset: number, Color: Color3, Decay: Color3, Glare: number, Haze: number },
	ColorCorrection: { Brightness: number, Contrast: number, Saturation: number, TintColor: Color3 },
	Bloom: { Intensity: number, Size: number, Threshold: number },
}
local rgb = Color3.fromRGB
local Presets: { [string]: Preset } = {
	Lobby = {
		ClockTime = 17.6, Brightness = 2, Ambient = rgb(150, 135, 150), OutdoorAmbient = rgb(160, 145, 160),
		ColorShift_Top = rgb(255, 214, 170), ColorShift_Bottom = rgb(60, 40, 60),
		EnvironmentDiffuseScale = 0.4, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.2,
		Atmosphere = { Density = 0.25, Offset = 0.1, Color = rgb(255, 214, 170), Decay = rgb(180, 120, 140), Glare = 0.2, Haze = 1 },
		ColorCorrection = { Brightness = 0.03, Contrast = 0.08, Saturation = 0.15, TintColor = rgb(255, 248, 236) },
		Bloom = { Intensity = 0.6, Size = 24, Threshold = 1.8 },
	},
	Calm = {
		ClockTime = 0, Brightness = 1.2, Ambient = rgb(82, 90, 128), OutdoorAmbient = rgb(95, 105, 145),
		ColorShift_Top = rgb(170, 190, 255), ColorShift_Bottom = rgb(40, 40, 70),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.35,
		Atmosphere = { Density = 0.25, Offset = 0.15, Color = rgb(120, 135, 190), Decay = rgb(60, 60, 110), Glare = 0, Haze = 0.8 },
		ColorCorrection = { Brightness = 0.04, Contrast = 0.12, Saturation = -0.05, TintColor = rgb(225, 232, 255) },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.6 },
	},
	Active = {
		ClockTime = 0, Brightness = 1.2, Ambient = rgb(96, 84, 104), OutdoorAmbient = rgb(112, 92, 104),
		ColorShift_Top = rgb(255, 190, 140), ColorShift_Bottom = rgb(60, 40, 40),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.3, ExposureCompensation = 0.3,
		Atmosphere = { Density = 0.35, Offset = 0.2, Color = rgb(170, 140, 140), Decay = rgb(90, 60, 70), Glare = 0, Haze = 1.2 },
		ColorCorrection = { Brightness = 0.03, Contrast = 0.18, Saturation = 0, TintColor = rgb(255, 236, 220) },
		Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.6 },
	},
	Critical = {
		ClockTime = 0, Brightness = 1.2, Ambient = rgb(104, 76, 92), OutdoorAmbient = rgb(124, 84, 104),
		ColorShift_Top = rgb(255, 150, 150), ColorShift_Bottom = rgb(70, 30, 50),
		EnvironmentDiffuseScale = 0.25, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.3,
		Atmosphere = { Density = 0.4, Offset = 0.2, Color = rgb(180, 120, 130), Decay = rgb(110, 50, 70), Glare = 0, Haze = 1.5 },
		ColorCorrection = { Brightness = 0.02, Contrast = 0.22, Saturation = 0.1, TintColor = rgb(255, 225, 230) },
		Bloom = { Intensity = 0.8, Size = 28, Threshold = 1.4 },
	},
}
Presets.Warning = Presets.Calm -- + TintColor tween to (255,225,190), see §4.2
return table.freeze(Presets)
```
(`ClockTime` tween ข้าม 17.6 → 0 จะหมุนผ่านกลางวัน: ให้ **ตั้งค่า ClockTime ทันที** ไม่ tween)

---

## 5. Audio

### 5.1 วิธีหาเสียงและยืนยัน ID (Boss/Art ใน Studio)
1. Toolbox → Creator Store → **Audio** → พิมพ์คีย์เวิร์ดในตาราง → กรอง **Sound Effects** หรือ **Music** และความยาวตามที่เขียน
2. เลือกเสียงที่ผู้สร้างเป็น **Roblox** (ใช้ได้ทุก place แน่นอน) ก่อน ถ้าไม่มีค่อยใช้ของคนอื่นที่เปิด public/ใช้ได้ฟรี
3. ใส่ลงเป็น `Sound` ใน `SoundService.Audio.<ชื่อ>` (หรือ path ที่ UI กำหนด) **กด Play ในเกมจริง** ว่ามีเสียง (เสียงที่ไม่มีสิทธิ์จะเงียบโดยไม่ error ชัด)
4. ใส่ ID ลงคอลัมน์ "ID" ในตารางนี้ แล้วแจ้ง UI/Scripter
- SoundGroup: `Music` 0.5, `SFX` 0.8, `Ambience` 0.6, `UI` 0.7
- เสียง 3D: parent ที่ Part, `RollOffMode = InverseTapered`, `RollOffMinDistance = 10`, `RollOffMaxDistance = 120` (แมพกว้าง 160)
- เสียงที่เล่นซ้ำบ่อย (BONK, squeak, ของตก): สุ่ม `PlaybackSpeed` 0.9–1.15 และเล่นพร้อมกันได้ไม่เกิน 4 ครั้ง/0.25 s

### 5.2 รายการเสียง (P0 = ต้องมี, P1 = ควรมี)

| P | ชื่อ Sound | ใช้ตอน | คำอธิบาย | Loop | Vol | 2D/3D | คีย์เวิร์ด Creator Store | ID |
|---|---|---|---|---|---|---|---|---|
| P0 | `QuakeRumble` | ระหว่าง pulse ทุก Stage (Volume ตามระดับ shake 0.3/0.6/0.8/1.0) | เสียงครืนต่ำๆ ยาว ไม่น่ากลัวเกิน | ✔ | 0.3–1.0 | 2D | `earthquake rumble`, `rumble loop`, `low rumble` | ยืนยันใน Studio |
| P0 | `DishRattle` | ระหว่าง pulse | จาน/แก้วกระทบกันกรุ๊งกริ๊ง | ✔ | 0.5 | 3D (ที่คว่ำจาน/ชั้น) | `dishes rattling`, `plates clatter`, `glass rattle` | ยืนยันใน Studio |
| P0 | `FallWhistle` | ตอนของเริ่มตก (เฉพาะ `NearPlayer` ใกล้ผู้เล่น local ≤ 20 studs) | หวีดตกแบบการ์ตูน ยาว ~1.2–1.5 s (ตรงกับ telegraph) | | 0.4 | 3D | `falling whistle`, `cartoon fall`, `bomb whistle` | ยืนยันใน Studio |
| P0 | `Bonk` | ของถึงพื้น / โดน damage | "โป๊ก!" การ์ตูน | | 0.7 | 3D | `cartoon bonk`, `bonk`, `boing hit` | ยืนยันใน Studio |
| P0 | `ImpactThud` | ของถึงพื้น (สลับกับ Bonk ตามชนิด: แอปเปิล thud, กระป๋อง clang, ฟองน้ำ squish) | กระแทกพื้นเบาๆ | | 0.5 | 3D | `thud`, `metal can drop`, `squish` | ยืนยันใน Studio |
| P0 | `SqueakHurt` | ผู้เล่นโดน damage | เสียงจี๊ดสั้นๆ น่ารัก | | 0.6 | 3D | `squeak`, `mouse squeak`, `toy squeak` | ยืนยันใน Studio |
| P0 | `DizzyLoop` | ระหว่าง Downed | นกร้องจิ๊บๆ / ดาวหมุนการ์ตูน | ✔ | 0.4 | 3D | `cartoon dizzy`, `birds tweeting dizzy`, `dizzy` | ยืนยันใน Studio |
| P0 | `Revive` | revive สำเร็จ | ป๊อป + ระฆังสดใส | | 0.6 | 3D | `revive`, `sparkle pop`, `magic chime` | ยืนยันใน Studio |
| P0 | `Poof` | Eliminated | ปุ๊ฟควันการ์ตูน | | 0.7 | 3D | `poof`, `smoke puff`, `cartoon poof` | ยืนยันใน Studio |
| P0 | `SirenFar` | เข้า Warning (1 ครั้ง) | ไซเรนไกลๆ จางๆ | | 0.35 | 2D | `siren distant`, `fire truck siren far` | ยืนยันใน Studio |
| P0 | `SirenNear` | ETA 60 s (Volume 0.3 → 0.8) | ไซเรนรถดับเพลิง loop | ✔ | 0.3–0.8 | 3D (โมเดลไฟกู้ภัย) | `fire truck siren`, `siren loop`, `emergency siren` | ยืนยันใน Studio |
| P0 | `RadioStatic` | ระหว่างมีคนกดวิทยุ (ต่อเครื่อง) | ซ่าวิทยุสื่อสาร | ✔ | 0.35 | 3D (วิทยุ) | `radio static`, `walkie talkie static` | ยืนยันใน Studio |
| P0 | `BatteryInsert` | เสียบถ่านสำเร็จ | คลิก/แปะเข้าช่อง + บี๊บเล็ก | | 0.7 | 3D | `battery insert`, `click snap`, `plug in` | ยืนยันใน Studio |
| P0 | `StepComplete` | Step 1/2 เสร็จ | jingle สั้นสดใส 1–2 s | | 0.7 | 2D | `success chime`, `level complete short`, `achievement` | ยืนยันใน Studio |
| P0 | `HeroArrive` | ETA ครบ กรงเริ่มหย่อน | เพลงสั้น "ฮีโร่มาแล้ว" brass 3–4 s | | 0.7 | 2D | `heroic fanfare short`, `brass fanfare`, `triumph sting` | ยืนยันใน Studio |
| P0 | `WinStinger` | Result ชนะ | เพลงชนะการ์ตูน 3–6 s | | 0.7 | 2D | `victory fanfare`, `cartoon win`, `you win` | ยืนยันใน Studio |
| P0 | `LoseStinger` | Result แพ้ | แตรเศร้าขำๆ (ไม่หดหู่) 2–4 s | | 0.6 | 2D | `sad trombone`, `cartoon fail`, `wah wah` | ยืนยันใน Studio |
| P1 | `MusicLobby` | Lobby | เพลงสนุกเบาๆ อูคูเลเล/พิซซิกาโต | ✔ | 0.4 | 2D | `playful ukulele`, `quirky pizzicato`, `cute happy` (กรอง Music) | ยืนยันใน Studio |
| P1 | `MusicMatch` | Calm–Active | เพลงตึงแบบการ์ตูนแอบย่อง | ✔ | 0.35 | 2D | `sneaky cartoon`, `tense quirky`, `mischief` | ยืนยันใน Studio |
| P1 | `MusicCritical` | Critical | เพลงไล่ล่าการ์ตูนเร็วขึ้น | ✔ | 0.4 | 2D | `cartoon chase`, `comedic action`, `hurry up` | ยืนยันใน Studio |
| P1 | `AlarmLoop` | Critical (เบาๆ ใต้เพลง) | บี๊บสัญญาณเตือนในบ้าน | ✔ | 0.2 | 2D | `alarm beep loop`, `smoke alarm` | ยืนยันใน Studio |
| P1 | `KitchenNight` | Calm ตลอด | ตู้เย็นหึ่ง + นาฬิกาติ๊ก | ✔ | 0.3 | 2D | `fridge hum`, `clock ticking`, `room tone night` | ยืนยันใน Studio |
| P1 | `WheelSpin` | วงล้อหมุน | ลวดหมุนเอี๊ยดๆ/กริ๊กๆ เป็นจังหวะ | ✔ | 0.5 | 3D | `squeaky wheel`, `hamster wheel`, `rattle spin` | ยืนยันใน Studio |
| P1 | `DynamoHum` | Progress วงล้อ > 0 (PlaybackSpeed 0.8 → 1.3 ตาม Progress) | ไฟฟ้าหึ่งที่สูงขึ้น | ✔ | 0.3 | 3D | `electric hum`, `power up loop`, `generator` | ยืนยันใน Studio |
| P1 | `BatteryHum` | ถ่านวางบนพื้น (ช่วยหาเจอ) | หึ่งเบา + ประกาย | ✔ | 0.25 | 3D (Max 40) | `electric buzz soft`, `magic hum` | ยืนยันใน Studio |
| P1 | `Pickup` | หยิบถ่าน | ป๊อปเก็บของ | | 0.6 | 2D | `pickup`, `item pickup`, `pop` | ยืนยันใน Studio |
| P1 | `ChargerFull` | ถ่านครบ | ชาร์จเต็ม power-up | | 0.7 | 3D | `power up`, `charge complete` | ยืนยันใน Studio |
| P1 | `RadioBeep` | เริ่มกดวิทยุ | บี๊บกดพูด walkie | | 0.5 | 3D | `walkie talkie beep`, `radio chirp` | ยืนยันใน Studio |
| P1 | `SqueakChorus` | วิทยุครบ (Step 2 เสร็จ) | แฮมสเตอร์จี๊ดๆ หลายตัวพร้อมกัน | | 0.6 | 2D | `mice squeaking`, `squeak chorus`, `rodent squeaks` | ยืนยันใน Studio |
| P1 | `WindowSlide` | หน้าต่างเปิด | บานกระจกเลื่อน | | 0.7 | 3D | `window slide`, `sliding glass door` | ยืนยันใน Studio |
| P1 | `RopeCreak` | กรงหย่อน 3 s / ถูกดึงขึ้น | เชือก/รอกเอี๊ยด | | 0.5 | 3D | `rope creak`, `pulley`, `winch` | ยืนยันใน Studio |
| P1 | `CarrierLand` | กรงถึงพื้น | พลาสติกกระทบ "ตุบ" | | 0.6 | 3D | `plastic thud`, `box drop` | ยืนยันใน Studio |
| P1 | `BannerAlert` | Banner "EARTHQUAKE!" | แตรเตือนการ์ตูน | | 0.6 | 2D | `alert horn`, `warning sting`, `cartoon alarm` | ยืนยันใน Studio |
| P1 | `BigShakeBoom` | เริ่ม Big Shake | ตูมต่ำ + ครืนใหญ่ | | 0.9 | 2D | `explosion rumble`, `boom low`, `earthquake hit` | ยืนยันใน Studio |
| P1 | `UIClick` / `Tick` | ปุ่ม UI / นับถอยหลัง < 10 s | คลิก / ติ๊ก | | 0.5 | 2D | `ui click`, `tick`, `countdown beep` | ยืนยันใน Studio |
| P1 | `RespawnPop` | respawn จากกองทิชชู่ | ป๊อปกระดาษ | | 0.6 | 3D | `paper rustle pop`, `pop out` | ยืนยันใน Studio |

**ขั้นต่ำถ้าเวลาหมด (10 ตัว)**: QuakeRumble, FallWhistle, Bonk, SqueakHurt, Poof, SirenNear, RadioStatic, BatteryInsert, WinStinger, LoseStinger

---

## 6. Game icon + thumbnail (ทำ 22:30–01:00 วันที่ 24 ตาม 8.9)

**ข้อกำหนด Roblox**: icon 512 × 512 PNG/JPG (สี่เหลี่ยมจัตุรัส), thumbnail 1920 × 1080 (16:9) ได้สูงสุด 10 รูป · ห้ามโลโก้ Roblox, ห้ามลิงก์นอกแพลตฟอร์ม, ห้ามภาพที่ไม่มีในเกมจริง (ใช้ screenshot จริงจากเกม + ตัวหนังสือเท่านั้น)

**วิธีถ่าย**: ตั้ง `SPAWN_PREVIEW = true` (หรือเล่นจริง) → กด H ซ่อน HUD → ใช้ preset Critical หรือ Calm → Camera FieldOfView 50 (ภาพ "เลนส์ยาว" ทำให้ของยักษ์ดูยักษ์) → screenshot ใน Studio → ใส่ตัวหนังสือใน Canva/Photopea

**ฟอนต์/สีตัวหนังสือ**: Fredoka (ตรงกับ UI FredokaOne) · เนื้อ cream (255,248,232) · ขอบหนา plum (38,30,58) · เน้นคำด้วย gold (255,196,84)

| ชิ้น | องค์ประกอบ | ตัวหนังสือ |
|---|---|---|
| **Icon (P0)** | ใกล้หน้าแฮมสเตอร์ Golden เต็มกรอบ ~70% หันมาทางกล้อง แก้มป่อง ตาโต มองขึ้นข้างบนอย่างตกใจ · แอปเปิลยักษ์ตกลงมาที่มุมขวาบน + วงแดงใต้แฮมสเตอร์ · พื้นหลังครัวกลางคืนโทนฟ้าเบลอ · มีไฟแดง/น้ำเงินขอบภาพ | **ไม่มีตัวหนังสือ** (เล็กเกินจะอ่านบนมือถือ) หรือแค่ "!" ตัวใหญ่สีเหลือง |
| **Thumbnail 1 — Hero (P0)** | แฮมสเตอร์ 2 ตัว (Golden + WinterWhite) วิ่งหนีบนพื้นครัว มุมกล้องต่ำระดับแฮมสเตอร์ · วงแดง 2–3 วง + แอปเปิล/กระป๋องกลางอากาศ · ตู้เย็น/โต๊ะยักษ์ด้านหลัง | บน: **"WE R IN TROUBLE!"** · มุมขวาล่าง badge: **"Co-op 2–4 players"** |
| Thumbnail 2 — Rescue (P1) | Rescue Moment: กรงหย่อนลงมาพร้อมลำแสงไฟฉาย ไฟแดง/น้ำเงินสาดเข้าหน้าต่าง แฮมสเตอร์บนขอบหน้าต่างโบกมือ | "Escape together!" |
| Thumbnail 3 — Teamwork (P1) | แฮมสเตอร์ 2–4 ตัวกดวิทยุคนละเครื่อง ไฟวิทยุติดครบ + Billboard "Held 2/2" | "Work as a team" |
| Thumbnail 4 — Scale (P2) | แฮมสเตอร์ตัวเดียวยืนใต้โต๊ะกินข้าว มองขึ้นไปเห็นขาโต๊ะ/เก้าอี้ยักษ์ | "You are tiny." |

คำอธิบายหน้าเกม (งาน Art/Audio 01:00–07:00 ตาม 8.9) ต้องมี **"ต้องเล่น 2–4 คน / Needs 2–4 players"** (8.12)

---

## 7. Handoff — ใครใช้อะไรจากเอกสารนี้

| ฝ่าย | ใช้ |
|---|---|
| Boss | รัน `tools/BuildHamster.luau` (§1), ทำโมเดล P0 #1–5, #10–11 ตามสูตร §2, หาเสียง P0 §5, ถ่าย icon/thumbnail §6 |
| Level | วาง props §2 (โดยเฉพาะ #6–9 และกฎ `CanQuery`), ไฟประจำแมพ §4.3, ไฟกู้ภัย §3.7 |
| UI (VFX client) | §3 ทั้งหมด, `LightingPresets` §4.4, Attachment names §1 |
| Scripter | ชื่อ `propPool` = `Apple`, `SoupCan`, `Sponge`; `exitVehicleAsset` = `RescueCarrier` (Model, PrimaryPart `Base`, มี `RopeAttachment`) |
| QA | ตรวจ: debris/วงเตือนเห็นบนมือถือ, ของตกบนเคาน์เตอร์/ทางลาด/ขอบหน้าต่างได้ (CanQuery), ไม่มีเสียงเงียบ (ID ใช้ได้), แฮมสเตอร์เดิน/กระโดด/ปีน Truss ได้ |

---

## 8. สมมติฐานที่ตั้งเอง (Boss ยังไม่ได้ตัดสิน)

1. ใช้ **Golden เป็นสีหลัก** (WinterWhite เป็นตัวเลือก — ทั้งเซิร์ฟเวอร์ใช้สีเดียวเพราะเป็น StarterCharacter ตัวเดียว; ให้ผู้เล่นเลือกสีได้เป็นงานหลังส่ง)
2. `StarterPlayer.LoadCharacterAppearance = false` — ผู้เล่นทุกคนเป็นแฮมสเตอร์เหมือนกัน ไม่มีหมวก/เสื้อของตัวเอง
3. วงล้อสร้างใหญ่กว่าของจริงนิดหน่อย (Ø28 cm) เพื่อให้แฮมสเตอร์การ์ตูน 2 ตัวยืนในวงล้อได้; กรงหย่อน 26 × 18 (ใหญ่กว่า Exit Zone 24 × 24 ด้านยาวเล็กน้อย, ทุกชิ้นไม่มี collision จึงไม่กระทบ gameplay)
4. Lobby ใช้แสงเย็นอบอุ่น (17:36) ต่างจากครัวเที่ยงคืน เพื่อให้รู้ทันทีว่า "ยังไม่เริ่ม"
5. Animation ID ของ Roblox ใน §1 และ texture `rbxasset://` ใน §3 ใช้ได้ทุก place โดยไม่ต้องอัปโหลด (ต้องยืนยันใน Studio; ถ้าใช้ไม่ได้ไม่ใช่ blocker)
6. Path เก็บ asset (`ReplicatedStorage.Assets.*`, `SoundService.Audio.*`) เป็นข้อเสนอ — ยึดตาม Deadline contract ของ Systems ถ้าต่างกัน
7. ไม่ใช้ mesh/texture/audio ที่ต้องอัปโหลดเอง (เลี่ยงรอ moderation ก่อนเส้นตาย)
