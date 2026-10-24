# HUD — Deadline build (UI/UX)

สถานะ: โค้ดครบตาม GDD §8.6 (HUD 8 ชิ้น + Rescue Moment + ปุ่มซ่อน HUD) · ผ่าน `luau-lsp analyze` (--!strict, ไม่มี type error) + `selene` (0 warning) · **ยังไม่ได้เทสต์ใน Studio**

## วิธีเปิดใช้ (บรรทัดเดียว)

ใน `src/client/Main.client.luau` (ไฟล์นี้ยังไม่มี — Scripter หรือ UI สร้างได้):

```lua
require(script.Parent.UI.UIController).start()
```

`start()` เรียกซ้ำได้ (ครั้งที่ 2 ไม่ทำอะไร) และไม่ yield

## ไฟล์ (`src/client/UI/`)

| ไฟล์ | หน้าที่ |
|---|---|
| `UIController` | จุดเริ่ม `start()`: ซ่อนแถบ Health ของ Roblox, ปิดปุ่ม Reset (retry), สร้าง HUD |
| `HudController` | ประกอบทุก widget, refresh 10 ครั้ง/วินาที, สร้าง Banner จากการเปลี่ยน state |
| `StateAdapter` | **ที่เดียว**ที่อ่าน Attribute / tag / Remote — ใช้ชื่อจาก `Contract.luau` + ค่าจาก `Config` |
| `HudRoot` | ScreenGui 3 ชั้น + UIScale สำหรับมือถือ |
| `HudToggle` | ปุ่ม **H** (PC) + ปุ่ม 👁 มุมขวาบน (มือถือ) ซ่อน/แสดง HUD และ marker |
| `MarkerController` | BillboardGui AlwaysOnTop + ระยะ (objective ของ Step ปัจจุบัน, Exit, เพื่อนที่มึน) |
| `CameraController` | กล้องตอนชนะ (tween ไป `WinCameraPoint` 3s) + กล้องตามเพื่อนตอน Poofed |
| `Widgets/StageTimer` | (1) Stage สี + เวลาถึง Collapse (กะพริบแดง < 30s ใน Critical) + ชื่อภัย |
| `Widgets/ObjectiveList` | (2) "Step 1/2" + รายการ objective: % / "2/3" / "Held 1/2" / Override / Locked / Last chance |
| `Widgets/HealthBar` | (5) แถบ HP จาก Attribute `HP` + สั่น + "Bonk!" ตอนโดน |
| `Widgets/StatusOverlay` | (6) Downed "Bonk!" + bleed-out + แถบ revive · "Poofed!" + นับถอยหลัง respawn · Escaped |
| `Widgets/ExtractionPanel` | (7) Rescue ETA · "Get in the carrier! 1/2 inside" · Leaving in 7 · หยุดชั่วคราว · Last call |
| `Widgets/LobbyStatus` | "Waiting for players (1/2)" · "Match starts in 0:25" · เข้ามากลาง Match · AFK |
| `Widgets/ResultScreen` | (8) ชนะ/แพ้ + เหตุผล, ภัย, เวลา, รายชื่อที่หนีได้, revive/มึน, นับกลับ Lobby |
| `Widgets/Banner` | ป้ายกลางจอ (ชื่อภัย, Step complete, หน้าต่างเปิด, กรงมาแล้ว, Last call ...) |
| `Strings` / `Style` / `UIUtil` | ข้อความทั้งหมด (ธีม B เปลี่ยนแค่ไฟล์นี้) / สี ฟอนต์ ขนาด / ตัวช่วยสร้าง GUI |

(4) Billboard บน anchor = marker ตัวเดียวกัน: progress, "Held 2/3", "Spot A: free/taken", "Override engaged"

## ผังจอ

ซ้ายบน = objective · กลางบน = Stage/เวลา → Extraction หรือ Lobby · ขวาบน = ปุ่ม 👁 (มือถือ) · กลางค่อนบน = Banner · กลาง = Downed/Poofed/Result · **ล่างกลาง = HP** (ไม่ทับจอยซ้ายและปุ่มกระโดดขวา)

มือถือ: วางด้วย Scale anchor + `UIScale` = clamp(min(ด้านสั้น/520, กว้าง/1000), 0.7, 1.35) · ชั้นปุ่มไม่ต่ำกว่า 0.85 → ปุ่ม 52px ≥ **44px** · ใช้ `ScreenInsets = CoreUISafeInsets` (ไม่ทับ topbar/รอยบาก) · `ResetOnSpawn = false` ทุกชั้น

## ชื่อที่ใช้ (ตาม `docs/ARCHITECTURE.md` v1 ทั้งหมด)

- RoundState §3: `Phase` (รวม `Ending`), `PhaseEndsAt`, `PlayersReady/Needed`, `MaxPlayers`, `MatchId`, `MatchEndsAt`, `Stage`, `DisasterName/Hint`, `MissionName`, `StepIndex/Count/Name`, `LastChance`, `ExitOpen`, `CarrierArrivesAt`, `CarrierArrived`, `DepartureRunning/EndsAt/Remaining`, `ZoneCount/Needed`, `LastCall`, `ResultWin/Reason/Time/Disaster/Escaped`
- Objectives §4 (Configuration + anchor), Player §5 (`State`, `HP`, `MaxHP`, `Inactive`, `MoveMode`, `BleedOutEndsAt`, `ReviveProgress`, `RespawnAt`, `ReviveCount`, `DownedCount`), tag `ObjectiveAnchor`/`ExitZone`, `PromptPart`, `WinCameraPoint`
- Remote: `HudBanner` (ผ่าน `Remotes.get`, รอแบบไม่ block) — banner ที่ server ส่งกับที่ HUD สร้างเองใช้ `key` เดียวกัน จึงไม่ขึ้นซ้ำ (จำ key 8s)
- Config: `BLEED_OUT_TIME`, `DEPARTURE_COUNTDOWN`, `WIN_CINEMATIC_TIME`, `BRIEFING_TIME`, `WARNING_BANNER_MIN`, `MIN_PLAYERS_TO_START`, `MAX_PLAYERS`, `MAX_HP`

## สมมติฐานที่ตั้งเอง

1. Departure "หยุดชั่วคราว" = กรงมาแล้ว + `DepartureRunning = false` + `DepartureRemaining > 0`
2. กล้องตอนชนะเริ่มเมื่อ `Phase = Ending` (หรือ `Result` + `ResultWin` ถ้ายังไม่เล่น) · ไม่มี `WinCameraPoint` → ข้ามช็อต · HUD ซ่อนระหว่าง tween 3s
3. กล้องตามเพื่อนตอน Eliminated ทำใน UI (`CameraController`) — ถ้า Scripter ทำซ้ำใน Controllers ให้ลบอันใดอันหนึ่ง
4. Billboard อยู่ใน Folder `WRIT_Markers` ใน PlayerGui (ไม่ใช่ใน ScreenGui) · ไอคอนใช้ emoji (ไม่ต้องอัปโหลด asset)
5. ข้อความทั้งหมดเป็นภาษาอังกฤษ (GDD assumption 6)

## เช็กลิสต์เทสต์ (Boss / QA)

- [ ] 1 client บน live: ขึ้น **"Waiting for players (1/2)"** ไม่เริ่มเอง
- [ ] 2 clients: Intermission นับ → Briefing banner → Stage/เวลา/objective ขึ้น → ถ่าน "x/N", วิทยุ "Held 1/2"
- [ ] `/dbg setHP 0` → overlay "Bonk!" + เพื่อนเห็น marker 💫 พร้อมระยะ → revive → แถบเขียว
- [ ] ปล่อย bleed-out หมด → "Poofed!" นับ 15 → กล้องตามเพื่อน
- [ ] `/dbg unlockExit` → banner หน้าต่างเปิด + Rescue ETA + marker 🏁 → กรงมา → "1/2 inside" → Leaving in 10 → ออกโซน = "Wait! Everyone back in!"
- [ ] ชนะ → กล้องไป `WinCameraPoint` 3s → Result · แพ้ (`/dbg endMatch lose`) → Result สีแดง
- [ ] กด **H** → HUD + marker หายหมด / กดอีกครั้งกลับมา · มือถือแตะ 👁 ได้
- [ ] Device Emulator: iPhone SE / iPhone 14 แนวนอน / iPad — ไม่มีอะไรทับกันหรือหลุดจอ
