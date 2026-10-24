# Level spec — Midnight Kitchen (Deadline cut)

| | |
|---|---|
| ผู้เขียน | Level Designer |
| วันที่ | 24 ต.ค. 2026 |
| อ้างอิง | GDD v0.5 §1.1, §4.2, §7.6, §8.3–8.6, §8.11 · `docs/ARCHITECTURE.md` §1, §6 · `docs/qa/Checkpoints.md` CP0 ข้อ 7–9 · `docs/assets/ArtAudio-deadline.md` §2, §3.7–3.8, §4.3 |
| สคริปต์สร้างแมพ | `tools/BuildMidnightKitchen.luau` (รันครั้งเดียวใน Command Bar ตอน Edit mode) |
| ผลลัพธ์ | `ServerStorage.Maps.MidnightKitchen` (Model) + `Workspace.Lobby` |

> เอกสารนี้คือสเปกแมพที่ส่งงาน (Deadline cut 160 × 120) ส่วน `docs/levels/MidnightKitchen.md` (แมพเต็ม) เป็นงานหลังส่งงาน

---

## 0. วิธีสร้างแมพ (Boss / agent ที่ต่อ Studio ได้)

1. เปิด place ใน Studio แบบ **Edit mode** (ห้ามรันตอนกด Play)
2. View → Command Bar → วางเนื้อหาทั้งไฟล์ `tools/BuildMidnightKitchen.luau` → Enter (หรือส่งผ่าน MCP `execute_luau`)
3. ดู Output: ต้องขึ้น `RESULT: OK — no problems found` และรายงานความชันของทางลาด 3 อัน
4. รันซ้ำได้ทุกเมื่อ (ลบของเดิมก่อนสร้างใหม่) · กด Ctrl+Z เพื่อย้อนการสร้างทั้งหมด
5. ตัวเลือกบนหัวไฟล์: `SHOW_HIDDEN = true` แสดง wedge/truss/volume/marker แบบโปร่งแสงเพื่อตรวจผัง · `PREVIEW_IN_WORKSPACE = true` ทิ้งแมพไว้ใน Workspace เพื่อเดินดู (ต้องรันใหม่ด้วย `false` ก่อนเทสต์)

สคริปต์ตรวจตัวเองหลังสร้าง (ขณะแมพยังอยู่ใน Workspace): หันด้าน wedge ด้วย raycast (ถ้ากลับด้านจะพลิกให้เอง), ยิง raycast ตาราง 4 studs ทั่วครัวว่าเจอพื้นทุกจุด, ระยะวิทยุ, spawn บนพื้นอยู่ใน NoImpact และ spawn ขอบหน้าต่างต้อง**ไม่**อยู่ใน NoImpact, ความสูงพื้นผิวหลัก, และต้องไม่มี `SpawnLocation` ในแมพ

---

## 1. ระบบพิกัด

- แมพสร้างที่จุดกำเนิดโลก: **พิกัดในเอกสาร = พิกัดโลก**
- **+X = ตะวันออก, +Z = ใต้**: ผนังเหนือ (หน้าต่าง) อยู่ที่ Z = 0 · ผนังใต้ Z = 120 · ผนังตะวันตก X = 0 · ผนังตะวันออก X = 160
- พื้นครัว Y = 0 · สเกล 1 stud = 2 cm · แฮมสเตอร์สูง ~6 studs (รวมหู)
- `KillY = −30` (Attribute บน root) · `Workspace.FallenPartsDestroyHeight = −80` (สคริปต์ตั้งให้)
- ภายนอกหน้าต่างอยู่ที่ Z ติดลบ (กระบะดอกไม้ Z −30..−4)

## 2. ระดับความสูง

| ระดับ | Y (ผิวบน) | พื้นที่ (X × Z) | มีอะไร |
|---|---|---|---|
| พื้นครัว | 0 | 0..160 × 0..120 | spawn ในกรง, วงล้อ, แท่นชาร์จ, ถ่าน 3 โซน |
| เบาะเก้าอี้ (step chair) | +23 | 100..121 × 30..56 | จุดพักระหว่างทางลาด 1 และ 2 |
| เคาน์เตอร์ตัว L | +45 | แขนเหนือ 36..160 × 0..30 · แขนตะวันออก 130..160 × 30..84 | วิทยุ A–D |
| ขอบหน้าต่างด้านใน + ชั้นวางตะวันตก | +61 | 0..110 × 0..10 (ลึก 10) | spawn หลังปลดล็อก ×2 |
| ขอบหน้าต่างด้านนอก | +61 | 42..110 × −12..−4 | ทางเดินไปกระบะดอกไม้ |
| กระบะดอกไม้ (Exit Zone) | +61 | 61..91 × −30..−4 (Exit Zone 64..88 × −28..−4) | Exit Zone, จุดลงของกรง |
| เพดาน (ล่องหน) | 125 | — | — |

ช่องหน้าต่าง: X 46..106, Y 61..111 (60 × 50) แบ่ง 3 บาน บานละ 20: **ตะวันตก 46..66 (เปิด)**, **กลาง 66..86 (เปิด)**, ตะวันออก 86..106 (กระจกตายตัว)

## 3. ผังมุมบน (1 ตัวอักษร = 4 × 4 studs, ทิศเหนืออยู่ด้านบน)

```
x→   0    20   40   60   80   100  120  140
  -32                XXXXXXXX                      ← นอกบ้าน
  -28                XXXXXXXX
  -24                XXXXXXXX
  -20                XXXXXXXX
  -16                XXXXXXXX
  -12           _____XXXXXXXX____
   -8           _____XXXXXXXX____
   -4 ###########wwwwwWWWWWfffff##############     ← ผนังเหนือ + หน้าต่าง
    0 ___________________________=============
    4 _*___________%____%________=============
    8 ...||||||====///////====================
   12 ...||||||====///////================C===
   16 .........=A==///////====================
   20 .........===============================
   24 .........===============B===============
   28 ................<<<<<<<<<hhhhh..========
   32 ................<<<<<<<<<hhhhh..========
   36 .*..............<<<<<<<<<hhhhh..========
   40 ................>>>>>>>>>hhhhh..========
   44 ................>>>>>>>>>hhhhh..========
   48 FFFFFFFFFBB.....>>>>>>>>>hhhhh..========
   52 FFFFFFFFFBB.....>>>>>>>>>hhhhh..====D===
   56 FFFFFFFFF.......................========
   60 FFFFFFFFF.ttttttttttttttt.......========
   64 FFFFFFFFF.ttttttttttttt*t...OO..========
   68 FFFFFFFFF.ttttttttttttttt...OO..========
   72 FFFFFFFFF.ttttttttttttttt...OO..========
   76 FFFFFFFFF.ttttttttttttttt...OO..========
   80 FFFFFFFFF.ttttttttttttttt.......========
   84 ..........ttttttttttttttt...............
   88 ..........tt*tttttttttttt...............
   92 ..........ttttttttttttttt...............
   96 .ccccccc..ttttttttttttttt...............
  100 .c@ccc@c................................
  104 .ccccccc................sssssss.........
  108 .c@ccc@c..............*.sss*sss.........
  112 .ccccccc................sssssss.........
  116 ........................sssssss.........
```

| สัญลักษณ์ | ความหมาย |
|---|---|
| `.` | พื้นครัว Y 0 |
| `=` | เคาน์เตอร์ +45 |
| `_` | ขอบหน้าต่าง/ชั้นวาง +61 (ด้านในและด้านนอก) |
| `X` | กระบะดอกไม้ +61 = Exit Zone |
| `#` / `w` `W` / `f` | ผนังเหนือ / บานตะวันตก, บานกลาง (เปิดได้) / บานตะวันออก (ตายตัว) |
| `\|` | ผ้าม่าน (Truss ซ่อน) พื้น → +61 |
| `/` | ที่คว่ำจาน (ทางลาด 3) +45 → +61 |
| `>` | ทางลาด 1 เขียง พื้น → +23 (ขึ้นไปทางตะวันออก) |
| `<` | ทางลาด 2 ตำราอาหาร +23 → +45 (ขึ้นไปทางตะวันตก) |
| `h` | เบาะ step chair +23 |
| `F` `B` | ตู้เย็น / แท่นชาร์จ (socket) |
| `t` | โต๊ะกินข้าว (เดินลอดใต้ได้, ท็อป +37.5) |
| `O` | วงล้อ (เดินเข้าได้) |
| `c` `@` | กรงที่ล้ม / spawn บนพื้น ×4 |
| `%` | spawn ขอบหน้าต่าง ×2 (หลังปลดล็อก) |
| `A` `B` `C` `D` | วิทยุ (บนเคาน์เตอร์) |
| `*` | ItemSpawn ถ่าน |
| `s` | ชั้นรองเท้า |
| ประตู pantry | แผ่นบนผนังตะวันตก X 0..2, Z 4..44 (บางเกินกว่าจะเห็นในผัง) |

## 4. เส้นทางและความชัน (rig มาตรฐาน: เดิน 16, JumpHeight 7.2 — **ไม่มีเส้นทางไหนต้องกระโดด**)

| ชิ้น | จาก → ถึง | Run × Rise × กว้าง | ความชัน | หมายเหตุ |
|---|---|---|---|---|
| Ramp1 เขียง (`Ramp1_CuttingBoard`) | พื้น (64, 0, 49) → เบาะ (100, 23, 49) | 36 × 23 × 14 | **32.6°** | wedge ล่องหน + แผ่นไม้ภาพวางทับ (Art #15) |
| Step chair seat | X 100..121, Z 30..56 | — | ราบ +23 | ขาเก้าอี้ + พนักฝั่งตะวันออกเป็น prop |
| Ramp2 ตำราอาหาร (`Ramp2_Cookbooks`) | เบาะ (100, 23, 36) → (66, 45, 36) | 34 × 22 × 12 | **32.9°** | วางบน `CookbookStack` (66..100 × 30..42, +23) · ปลายบนอยู่ติดขอบเคาน์เตอร์ Z 30 → ก้าวไปทางเหนือขึ้นเคาน์เตอร์ (ต่างระดับ < 1) |
| Ramp3 ที่คว่ำจาน (`Ramp3_DishRack`) | เคาน์เตอร์ (54, 45, 15) → (80, 61, 15) | 26 × 16 × 10 | **31.6°** | ปลายบนอยู่หน้าบานกลาง → ก้าวไปทางเหนือขึ้นขอบหน้าต่าง +61 (ตรงกับ Art #8) |
| ผ้าม่าน (`Curtain_Truss`) | X 14..36, Z 10..18, Y −1..61 | TrussPart 22 × 62 × 8 | ปีนแนวตั้ง | ปีนได้จาก**พื้น** (หน้าใต้) และจาก**เคาน์เตอร์** (หน้าตะวันออก X 36 สูงกว่าเคาน์เตอร์ 16) · ยอด +61 ต่อกับชั้นวางตะวันตก/ขอบหน้าต่างพอดี |
| ขอบหน้าต่าง → กระบะ | +61 ทั้งหมด | — | ราบ | ขอบใน, ผ่านผนัง (ผิวบนของ `NorthWall_Lower`), ขอบนอก และดินในกระบะสูง +61 เท่ากันทุกชิ้น ไม่มีขอบกั้น |

- รอยต่อทุกจุด (พื้น→ทางลาด, ทางลาด→เบาะ, ทางลาด→เคาน์เตอร์/ขอบหน้าต่าง) ต่างระดับ < 1 stud
- ลงได้เร็ว: กระโดดลงจากขอบเคาน์เตอร์ (45) ได้ เพราะเกมไม่มี fall damage
- ภายนอกมีรั้วล่องหน (Y 61..125, CanQuery false) รอบขอบนอก + กระบะ จึงตกลงไปข้างล่างไม่ได้
- **ทางหลัก** (Ramp3 → บานกลาง) และ **ทางสำรอง** (ผ้าม่าน → ชั้นวางตะวันตก → บานตะวันตก → ขอบนอก) ไม่มีส่วนไหนเป็น CollapseGroup (Deadline ไม่มี RouteCollapse อยู่แล้ว)

## 5. ของในแมพทั้งหมด: tag + Attribute (ตาม `ARCHITECTURE.md` §6)

### 5.1 Gameplay markup

| Instance (path ใน Model) | ชนิด | Tag | Attributes | ตำแหน่ง (center) | หมายเหตุ |
|---|---|---|---|---|---|
| `MidnightKitchen` | Model (root) | — | `KillY = −30` | — | PrimaryPart = `Structure.Floor`, WorldPivot = origin |
| `Objectives.RunWheel` | Model | `ObjectiveAnchor` | `ObjectiveId = "RunWheel"` | PromptPart (116, 2, 72) | `PromptPart` อยู่**ในวงล้อ** สูง 2 (Art #1) · ตัววงล้อ Ø14 × 7 แกนสูง 7.5 ไม่มี collision · ฐาน 10 × 0.5 × 9 · ไดนาโม (116, 2, 82) |
| `Objectives.Charger` | Model | `ObjectiveAnchor` | `ObjectiveId = "DeliverBatteries"` | PromptPart (41, 3.5, 52) | socket ของ Deliver · กล่อง 10 × 2 × 7 + ตัวชาร์จ 6.5 × 1.75 × 4 ข้างมุมตู้เย็น |
| `Objectives.Radio_A` | Model | `ObjectiveAnchor` | `ObjectiveId = "CallForHelp"`, `Part = "A"` | ฐาน (42, 45, 20), PromptPart +2.6 | แดง · ปลายตะวันตกของแขนเหนือ ข้างยอดผ้าม่าน |
| `Objectives.Radio_B` | Model | `ObjectiveAnchor` | `ObjectiveId = "CallForHelp"`, `Part = "B"` | (100, 45, 26) | น้ำเงิน · ข้างซิงก์ |
| `Objectives.Radio_C` | Model | `ObjectiveAnchor` | `ObjectiveId = "CallForHelp"`, `Part = "C"` | (145, 45, 15) | เหลือง · มุมตัว L |
| `Objectives.Radio_D` | Model | `ObjectiveAnchor` | `ObjectiveId = "CallForHelp"`, `Part = "D"` | (145, 45, 55) | เขียว · แขนตะวันออก |
| `Spawns.Spawn_Cage1..4` | Part 4 × 0.2 × 4 | `PlayerSpawn` | `Priority = 2` | (12, 0, 104) (26, 0, 104) (12, 0, 112) (26, 0, 112) | ในกรงที่ล้ม หันไปทางเหนือ (ปากกรง) · MapService เกิดที่ผิวบน + 3 |
| `Spawns.Spawn_Sill1..2` | Part 4 × 0.2 × 4 | `PlayerSpawn` | `Priority = 1`, `EnabledBy = "WindowOpen"` | (56, 61, 5) (76, 61, 5) | หน้าบานตะวันตก/บานกลาง · **ไม่มี NoImpact** (GDD D2) |
| `Volumes.NoImpact_Cage1..4` | Part 12 × 30 × 12 | `NoImpact` | — | ตรงกับ spawn บนพื้นแต่ละจุด, Y −2..28 | ครอบรัศมี 6 (มุมกล่องเผื่อถึง 8.5) · CanCollide/CanQuery false |
| `ItemSpawns.Battery_T1` | Part 2 × 1 × 2 | `ItemSpawn` | `ItemType = "Battery"`, `Zone = "T"` | (52, 0.5, 90) | ใต้โต๊ะ ฝั่งตะวันตกเฉียงใต้ |
| `ItemSpawns.Battery_T2` | 〃 | `ItemSpawn` | `Battery`, `T` | (94, 0.5, 68) | ใต้โต๊ะ ฝั่งตะวันออกเฉียงเหนือ |
| `ItemSpawns.Battery_S1` | 〃 | `ItemSpawn` | `Battery`, `S` | (111, 0.5, 112) | ในช่องล่างของชั้นรองเท้า ระหว่างรองเท้า 2 ข้าง (ช่องสูง 10) |
| `ItemSpawns.Battery_S2` | 〃 | `ItemSpawn` | `Battery`, `S` | (90, 0.5, 112) | ข้างชั้นรองเท้าฝั่งตะวันตก |
| `ItemSpawns.Battery_P1` | 〃 | `ItemSpawn` | `Battery`, `P` | (8, 0.5, 40) | หน้าประตู pantry |
| `ItemSpawns.Battery_P2` | 〃 | `ItemSpawn` | `Battery`, `P` | (6, 0.5, 8) | หลังผ้าม่าน ใต้ชั้นวางตะวันตก |
| `Exit.Window_West` | Model (child `Pane`) | `LockedDoor` | `UnlockedBy = "WindowOpen"` | Pane X 46..66, Y 61..111, Z −2.2..−1.8 | มีแค่บานกระจก server ซ่อน BasePart ทุกชิ้นใน model ตอนปลดล็อก |
| `Exit.Window_Center` | Model (child `Pane`) | `LockedDoor` | `UnlockedBy = "WindowOpen"` | Pane X 66..86 | ทางหลักจากที่คว่ำจาน |
| `Exit.Window_East_Fixed` | Part | — | — | X 86..106 | กระจกตายตัว ไม่เปิด |
| `Exit.ExitZone` | Part 24 × 12 × 24 | `ExitZone` | `Open = false` (server ตั้งเอง) | (76, 67, −16) → X 64..88, Y 61..73, Z −28..−4 | CanCollide false, CanQuery false |
| `Exit.ExitVehicleSpot` | Part 4 × 1 × 4 | `ExitVehicleSpot` | — | (76, 61.5, −16) | กลางกระบะ · `RescueCarrier` (26 × 17 × 18, PrimaryPart `Base`) ลงตรงนี้ ประตูกรงหันเข้าหน้าต่าง (ทิศใต้) |
| `WinCameraPoint` | Part 1 × 1 × 1 (ใต้ root) | — (ใช้ชื่อ) | — | (76, 72, −54) หันไปที่ (76, 63, −8) | กล้องตอนชนะ มองกระบะ + ครัวด้านหลัง (CameraController tween ไปที่ CFrame ของ Part นี้) |

### 5.2 โครงสร้างและ prop (ไม่มี tag)

| กลุ่ม | ชิ้น | ขนาด/ตำแหน่ง | CanCollide / CanQuery |
|---|---|---|---|
| Structure | `Floor` | −4..164 × −4..124, ผิวบน Y 0 | ✔ / ✔ |
| Structure | `InvisWall_W/E/S`, `InvisCeiling` (Y 125) | ขอบครัว | ✔ / **✘** (Transparency 1) |
| Structure | `NorthWall_Lower/Upper/West/East` | Z −4..0 เว้นช่องหน้าต่าง | ✔ / ✔ (มองเห็นได้ ดูข้อ 8-ก) |
| Structure | `CounterN_Cabinet/Top`, `CounterE_Cabinet/Top` | ท็อปหินอ่อน หนา 2, ผิวบน 45 | ✔ / ✔ |
| Structure | `WindowSill_Inner` (36..110 × 0..10, Y 45..61), `WindowSill_WestShelf` (0..36 × 0..10, Y 58..61) | +61 | ✔ / ✔ |
| Structure | `ExteriorSill`, `FlowerBox` (30 × 26, ผิวบน 61), `FlowerBox_Soil` (แผ่นสีดิน) | +61 | ✔ / ✔ (Soil ✘ / ✘) |
| Structure | `Fence_*` ×7 รอบขอบนอก + กระบะ | Y 61..125 | ✔ / ✘ (ล่องหน) |
| Routes | `Ramp1/2/3_Collider` (WedgePart ล่องหน), `CookbookStack`, `StepChair_Seat`, `Curtain_Truss` | ตามข้อ 4 | ✔ / ✔ |
| Routes | `Ramp*_Visual` (แผ่นภาพบนทางลาด) | หนา 0.6 | ✘ / ✘ |
| Props | `Fridge` 35 × 90 × 35 (X 0..35, Z 50..85) | ผนังตะวันตก | ✔ / ✘ |
| Props | `PantryDoor` 2 × 100 × 40 (Z 4..44) | ผนังตะวันตก | ✔ / ✘ |
| Props | `Table_Top` 60 × 1.5 × 40 ที่ +37.5 (X 40..100, Z 62..102) + ขา 2.5 ×4 | กลางห้อง | ✔ / ✘ (เดินลอดใต้ได้) |
| Props | `StepChair_Leg1..4`, `StepChair_Back` (ถึง +45) | | ✔ / ✘ |
| Props | `Cage_TrayWall` (X 4..34, Z 117..118, สูง 20) + `Cage_Bars*` | มุมตะวันตกเฉียงใต้ | ถาด ✔ / ✘ · ซี่กรง ✘ / ✘ |
| Props | `ShoeRack_*` (X 96..126, Z 105..120, สูง 22.5, ชั้นกลาง +10), `Shoe_1..3` | ผนังใต้ | ✔ / ✘ |
| Props | `BackDoor` (X 128..156 ผนังใต้), `Sink` (แผ่นแบน 84..109 × 10..28), `DishRack_Basket`, `Curtain_Pleat1..4`, `Curtain_Rod` | ตกแต่ง | ประตู ✔ / ✘ · ที่เหลือ ✘ / ✘ |
| Lights | `Moonlight` (76, 90, −30) SpotLight เปิด · `RescueLight_Red` (73, 50, −44) / `RescueLight_Blue` (79, 50, −44) SpotLight **ปิดไว้** (`Enabled = false`, Part Transparency 1) · `FridgeLight` (38, 3, 50) · `CageNightLight` (36, 2, 96) | ตาม Art §3.7, §4.3 | ✘ / ✘ |

### 5.3 Lobby (`Workspace.Lobby`)

| ชิ้น | รายละเอียด |
|---|---|
| `Floor` | 60 × 60 กลาง (3000, 0, 0) ผิวบน Y 0 (ตรงกับ `LOBBY_OFFSET_X / LOBBY_Y / LOBBY_SIZE`) |
| `InvisWall_N/S/W/E`, `InvisCeiling` | สูง 40 (`LOBBY_WALL_HEIGHT`), Transparency 1, CanCollide true, **CanQuery false** → CP0-7 ออกไม่ได้ |
| `LobbySpawn1..4` | Part 4 × 0.2 × 4 tag `LobbySpawn` วงรัศมี 8 รอบจุดกลาง (แบบเดียวกับที่ MapService สร้างเอง) |
| `LobbySpawnLocation` | SpawnLocation `Neutral`, `Duration = 0` ที่จุดกลาง → `LoadCharacter()` เกิดใน Lobby ก่อน PivotTo (ไม่โผล่ที่ origin ซึ่งเป็นตำแหน่งแมพ) |
| `ToyBlock_Low/High` | กล่องสูง 3 และ 5.5 ไว้กระโดดเล่น (ต่างระดับไม่เกิน JumpHeight) |

---

## 6. ระยะเดินที่วัดจากพิกัด (เส้นทางเดินจริงที่อ้อมสิ่งกีดขวาง แนวราบ, ความเร็ว 16 studs/s)

จุดอ้างอิง: กลาง spawn (19, 108) ปากกรง (19, 96) · จุดยืนที่แท่นชาร์จ (48, 52) · PromptPart วงล้อ (116, 72) · โคนทางลาด 1 (64, 49) · จุดขึ้นเคาน์เตอร์ (67, 28)

| จาก → ถึง | วัดได้ (studs) | วินาที | GDD §8.3 | ต่าง |
|---|---|---|---|---|
| Spawn → วงล้อ | 114 | 7.1 | 90 | +24 |
| Spawn → โซน T (ใกล้ / ไกล) | 46 / 93 | 2.9 / 5.8 | 40 | ใกล้เคียง |
| Spawn → โซน S (S2 / S1) | 85 / 111 | 5.3 / 6.9 | 50 | +35 |
| Spawn → โซน P (P1 / P2) | 105 / 137 | 6.5 / 8.6 | 60 | +45 (P อยู่มุมตะวันตกเฉียงเหนือ อีกฝั่งของตู้เย็น) |
| ค้นทั่ว 1 โซน (เดินระหว่าง ItemSpawn 2 จุด) | T 47 · S 32 · P 33 | 2–3 | ~80 | สั้นกว่า |
| โซน → แท่นชาร์จ | T 38–49 · S 74–96 · P 42–75 | | T 60 / S 70 / P 50 | ใกล้เคียง |
| แท่นชาร์จ → เคาน์เตอร์ (ทางลาด 2 ช่วง) | 113 (โคนทางลาด 14 + ทางลาด 99) | 7.0 | ~90 | +23 |
| วงล้อ → เคาน์เตอร์ | 167 | 10.4 | — | — |
| จุดขึ้นเคาน์เตอร์ → วิทยุ A / B / C / D | 26 / 34 / 79 / 97 | 1.7 / 2.1 / 5.0 / 6.1 | — | — |
| วิทยุ ↔ วิทยุ (เส้นตรง) | A–B 58 · B–C 46 · C–D **40** · B–D 54 · A–C 103 · A–D 109 | | ≥ 40 | ✔ ทุกคู่ |
| วิทยุ → Exit Zone ผ่านที่คว่ำจาน | A 71 · B 109 · C 154 · D 172 · (จุดขึ้นเคาน์เตอร์ 78) | 4.5–10.8 | ~40 | ยาวกว่า แต่อยู่ใน ETA 60s สบาย |
| เคาน์เตอร์ → Exit Zone ผ่านผ้าม่าน (ปีนจากเคาน์เตอร์ 16) | จากวิทยุ A 82 · จากจุดขึ้นเคาน์เตอร์ 111 + ปีน 16 | ~7–9 | ~120 | สั้นกว่า |
| พื้น (แท่นชาร์จ) → Exit Zone ผ่านผ้าม่าน | 115 + ปีน 61 | ~13 (ปีน ~5.5s ประมาณ) | — | — |

> ความเร็วปีน Truss ของ Roblox ประมาณ 0.7 × WalkSpeed (~11 studs/s) — ตัวเลขนี้ต้องวัดจริงใน playtest

### 6.1 เทียบกับ pacing §8.5 (คำนวณด้วยระยะจริงข้างบน + เวลา action ตาม GDD: วงล้อ 45s, หยิบ+เสียบ 3s, ค้น 10s, วิทยุ 45s, ETA 60s, Departure 10s)

| ทีม | ลำดับงาน (ideal) | ปลดล็อก | จบ | GDD §8.5 |
|---|---|---|---|---|
| 2 คน ideal | P1: เดิน 7.1s + วงล้อ 45s → 0:57 · P2: ถ่าน T (46 + 47 + 49 = 142 studs, 8.9s + 13s) → 0:27, ถ่าน S (74 + 32 + 96 = 201 studs, 12.6s + 13s) → 0:53 · วิทยุ: P1 วงล้อ→B 200 studs 12.5s (1:10), P2 ชาร์จ→A 139 studs 8.7s (1:01) + ประสาน 2s + 45s | **1:57** | **3:07** | 1:50 / 3:00 (+7s) |
| 4 คน ideal | วงล้อ 2 ตัว → 0:35 · ถ่าน T → 0:27, P (212 studs) → 0:31, S (ต่อจาก T) → 0:53 · วิทยุ: คนวงล้อ → D 264 studs (0:51), คนทำ S → C 192 studs (1:05) + ประสาน 8s + 45s | **1:58** | **3:08** | 1:56 / 3:06 (+2s) |
| 2 คน typical | ideal + overhead 78s (§8.5) | ~3:15 | ~4:25 | ~3:08 / ~4:18 |
| 4 คน typical | ideal + 85s | ~3:23 | ~4:33 | ~3:21 / ~4:31 |
| ทีมช้า (overhead ×2) | | ~4:33–4:48 | ~5:43–5:58 | ~4:45 / ~5:55 |

สรุป: ช้ากว่า GDD 2–7 วินาที ทุกทีมยังได้ Active ≥ 60s (ideal 2 คน: 0:45 → 1:57 = 72s) และ Critical ≥ 70s ส่วนเส้นตายปลดล็อก 5:50 ยังเหลือเวลาเผื่อ ~1 นาทีสำหรับทีมช้า **ไม่ต้องแก้ Config** เดินเร็วกว่าที่ GDD ตั้งตรงที่ค้นในโซน (สั้นกว่า) แต่ช้ากว่าตรงที่ขึ้นเคาน์เตอร์ (ทางลาดชันได้ไม่เกิน 35° จึงต้องเดินแนวราบ ≥ 64 studs เพื่อขึ้นสูง 45)

---

## 7. ตรวจกับ Checkpoint / DoD

| รายการ | ทำในแมพอย่างไร |
|---|---|
| CP0-7 กำแพง Lobby | ผนัง 4 ด้าน + เพดาน ล่องหน สูง 40, CanCollide true, CanQuery false |
| CP0-8 เกิดที่มุมกรงที่ล้ม | spawn ×4 อยู่ในกรง (มุมตะวันตกเฉียงใต้) Priority 2 หันออกทางปากกรง |
| CP0-9 เดินได้ทุกเส้นทาง | พื้น → เขียง (32.6°) → เบาะ → ตำราอาหาร (32.9°) → เคาน์เตอร์ → ที่คว่ำจาน (31.6°) → ขอบหน้าต่าง → (บานเปิด) → ขอบนอก → กระบะ · ผ้าม่านปีนได้ทั้งจากพื้นและจากเคาน์เตอร์ · ไม่มีจุดที่ต้องกระโดด |
| CP2-5 / DoD: impact บนพื้น, ทางลาด, เคาน์เตอร์, ขอบหน้าต่าง | ทุกผิวที่เดินได้ CanCollide + CanQuery true (wedge ล่องหนก็ true) · prop ที่บังจากด้านบน (โต๊ะ, ตู้เย็น, ชั้นรองเท้า, ซี่กรง, ม่าน) CanQuery false · ขอบหน้าต่างลึก 10 จึง reroll สำเร็จได้บ่อยพอ |
| E13 / DoD: ไม่มี impact รอบ spawn พื้น / spawn ขอบหน้าต่างโดนได้ | NoImpact เฉพาะ 4 จุดบนพื้น (และ MapService กันรัศมี 6 ให้อีกชั้น) · spawn ขอบหน้าต่างไม่มี NoImpact |
| QA "ตรวจ markup" (Checkpoints หัวข้อ AI-check) | สคริปต์พิมพ์ผลตรวจเองทุกครั้งที่รัน (ข้อ 0) |

---

## 8. จุดที่ต่างจาก GDD/ASCII และเหตุผล

| # | GDD | ในแมพนี้ | เหตุผล |
|---|---|---|---|
| ก | กำแพง/เพดานล่องหน CanQuery false | ผนังเหนือ (ผนังหน้าต่าง) **มองเห็นได้และ CanQuery true** | ต้องมีผนังจริงรอบหน้าต่าง และถ้า CanQuery false กล้อง Roblox จะทะลุออกไปหลังผนังแล้วบังวิว · เป็นผิวแนวตั้ง ray ของ impact ที่ยิงลงจึงไม่ตกบนมัน ผนังอีก 3 ด้านและเพดานล่องหน CanQuery false ตามกฎ |
| ข | ASCII 8.3: ตู้เย็น [B] กลางผนังเหนือ | ตู้เย็นชิดผนังตะวันตก แท่นชาร์จอยู่ที่มุมตู้เย็น | ผนังเหนือเป็นเคาน์เตอร์ยาวต่อเนื่อง (วิทยุต้องเดินถึงกันได้บนเคาน์เตอร์) แท่นชาร์จจึงอยู่กลางค่อนตะวันตก ใกล้ทุกโซนถ่านและโคนทางลาด |
| ค | วิทยุ A x=20, B x=70 | A x=42, B x=100 | มุมตะวันตกเฉียงเหนือ (X 0..36) เป็นช่องผ้าม่าน (ม่านต้องยาวถึงพื้น) แขนเหนือของเคาน์เตอร์จึงเริ่มที่ X 36 · ที่คว่ำจานอยู่หน้าบานกลาง (X 54..80) · ระยะทุกคู่ยัง ≥ 40 |
| ง | ผ้าม่านบน "ผนังตะวันตก" | ม่านอยู่มุมตะวันตกเฉียงเหนือ แนบผนังเหนือ ทางซ้ายของหน้าต่าง + ชั้นวาง +61 ต่อไปยังขอบหน้าต่าง | ทำให้ปีนได้ทั้งจากพื้นและจากเคาน์เตอร์ ตรงกับ 7.3 ("พื้น → ระดับเคาน์เตอร์ → ขอบหน้าต่างฝั่งตะวันตก") |
| จ | Art: Truss (2, 62, 2) + ขั้นเล็กที่ยอด | Truss 22 × 62 × 8 ยอดเสมอ +61 | กว้างกว่าจึงปีนง่ายบนมือถือ และยอดเสมอชั้นวาง ไม่ต้องมีขั้น |
| ฉ | Art: เบาะเก้าอี้ 21 × 21 | step chair 21 × 26 | ทางลาด 1 กว้าง 14 (ตาม Art) + ทางลาด 2 กว้าง 12 ต้องต่อกับเบาะทั้งคู่ |
| ช | Art: แสงจันทร์ Range 90 | Range 60 | SpotLight ของ Roblox ตั้ง Range ได้สูงสุด 60 |
| ซ | ระยะ 8.3 (spawn→วงล้อ 90 ฯลฯ) | ดูข้อ 6 | pacing รวมช้ากว่า 2–7s ยอมรับได้ |
| ฌ | Art: Exit Zone สูง 10 | สูง 12 (Y 61..73) | เผื่อ HRP ตอนกระโดดในโซน ARCHITECTURE ไม่ได้กำหนดความสูง |

---

## 9. เทียบกับ ARCHITECTURE.md (v1, 24 ต.ค.) — ความไม่ตรงกัน / จุดคลุมเครือ

ชื่อ tag/Attribute/โฟลเดอร์ทั้งหมดตรงกับ `Contract.luau` แล้ว (`PlayerSpawn` `Priority` `EnabledBy`, `ObjectiveAnchor` + `PromptPart` `ObjectiveId` `Part`, `ItemSpawn` `ItemType` `Zone`, `LockedDoor` `UnlockedBy`, `ExitZone` `Open`, `ExitVehicleSpot`, `NoImpact`, `LobbySpawn`, `WinCameraPoint`, root `KillY`, `ServerStorage.Maps.MidnightKitchen`) จุดที่ต้องให้ Scripter/Art ยืนยัน:

1. **ตำแหน่งวางกรง `RescueCarrier`**: `ExitVehicleSpot` = Part 4 × 1 × 4 ที่กึ่งกลางอยู่ที่ Y 61.5 (ผิวดิน +61) ส่วน Art บอกว่า `PrimaryPart = Base` อยู่ "กลางฐาน" ถ้า server `PivotTo(spot.CFrame)` ตรงๆ ถาดกรง (สูง 6) จะจมลงไปในกระบะ ~2.5 studs → Scripter ควรวาง `Base` ให้**ก้น**อยู่ที่ `spot.Position.Y − spot.Size.Y/2` (= +61) หรือ Art ตั้ง pivot ไว้ที่ก้นถาด
2. **ไฟกู้ภัย / แสงจันทร์**: ไม่มีชื่อใน contract วางไว้ที่ `Map.MidnightKitchen.Lights.RescueLight_Red / RescueLight_Blue` (SpotLight `Enabled = false`, Part Transparency 1) และ `Lights.Moonlight` — UI/Art ต้องหาด้วยชื่อนี้ (หรือเพิ่มชื่อใน `Contract.Name`)
3. **Bounds ของ `RandomPoint`**: MapService ใช้ `clone:GetBoundingBox()` ซึ่งรวมของนอกบ้าน (`WinCameraPoint` Z −54, ไฟกู้ภัย Z −44, เพดาน Y 127) → bounds = X −4..164, Z −54..124 ราว 1 ใน 5 ของจุดสุ่มจะตกนอกบ้านแล้วไม่เจอพื้น (ข้ามไปเฉยๆ ไม่พัง แต่ของร่วงในครัวน้อยลง) — ถ้าอยากแม่น ใช้ bounds ของ `Structure.Floor` แทน
4. **NoImpact ซ้ำซ้อน**: MapService กันรัศมี 6 รอบ spawn ที่ไม่มี `EnabledBy` ให้อยู่แล้ว แมพยังวาง `NoImpact` 12 × 30 × 12 ตาม GDD (ไม่ขัดกัน มุมกล่องกันกว้างถึง 8.5)
5. **ItemSpawn**: Part 2 × 1 × 2 ที่ก้นอยู่บนพื้น (กึ่งกลาง Y 0.5) — สมมติว่า ItemService วาง item ที่ `ItemSpawn.Position` (ถ่านหนา 0.7 จะลอยจากพื้น 0.15) ถ้า ItemService ใช้ผิวบน + offset ต้องบอก
6. **ProximityPrompt**: แมพไม่สร้าง prompt (ARCHITECTURE §6: server สร้าง `ObjectivePrompt` ใน `PromptPart`) · `PromptPart` และตัววิทยุ/วงล้อ/แท่นชาร์จเป็น CanQuery false จึงไม่บัง `RequiresLineOfSight`
7. **`LockedDoor`**: แต่ละ model มีแค่ `Pane` (server ซ่อน BasePart ทุกชิ้นใน model) กรอบหน้าต่างอย่าใส่ใน model นี้ ส่วนบานตะวันออกเป็น Part ธรรมดา (ไม่เปิด) ตาม Art ("บานกลาง + บานตะวันตก เลื่อนเปิด")
8. **Lobby**: แมพสร้าง `Workspace.Lobby` เอง (ขนาด/ตำแหน่งเดียวกับที่ MapService สร้าง) + `LobbySpawn` ×4 และเพิ่ม `SpawnLocation` แบบ Neutral 1 อัน เพื่อให้ `LoadCharacter()` ลงใน Lobby เสมอ (ไม่มี SpawnLocation ในแมพ)
9. Raycast ของ impact ใช้ `RespectCanCollide = true` (ARCHITECTURE §6) — แมพตั้ง volume/marker เป็น CanCollide false + CanQuery false ทั้งหมด จึงไม่มีทางถูกนับเป็นพื้น

---

## 10. สมมติฐานที่ตั้งเอง

1. Map อยู่ที่ origin, Lobby ที่ X 3000 (ระยะห่าง ~2,900–3,000 studs ตาม GDD 2.1)
2. ใช้ความเร็วเดิน 16 และวัดระยะแนวราบ (ทางลาด Roblox เดินด้วยความเร็วแนวราบใกล้เคียง WalkSpeed)
3. กรงที่ล้มมีถาดเป็นผนังด้านใต้ ซี่กรงไม่มี collision (Art #10) ปากกรงหันไปทางเหนือ
4. ไม่มี counter spawn (Priority 3) เพราะ Deadline override ใช้แค่พื้น ×4 + ขอบหน้าต่าง ×2 (§8.6)
5. ไม่ใช้ `NoBlockingProp`, `CollapseGroup`, `RecoveryPoint`, `VolumeLevel` (Deadline ไม่ใช้) — ถ้า Flood stretch เป็น Go: เพิ่ม `VolumeLevel` Level 0 ที่ Y 0 และ Level สูงสุดที่ Y +9 (§8.7) โดยไม่ต้องย้ายอะไร (ทุก objective บนพื้นทำใต้น้ำได้, เคาน์เตอร์/ขอบหน้าต่างไม่ท่วม)
6. Prop ภาพจริงของ Art วางทับ blockout ได้โดยไม่ต้องย้ายพื้นผิวที่เดิน (ทางลาดเป็น wedge ล่องหนอยู่แล้ว)
7. สคริปต์ผ่าน `luau-compile` (syntax) แล้ว แต่ไม่ได้ type-check กับ Roblox definitions (ไฟล์ใน `tools/` ไม่ถูก Rojo sync) — ยังไม่ได้รันใน Studio จริง ผลตรวจในข้อ 0 คือการยืนยันครั้งแรก
