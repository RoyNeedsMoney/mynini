# NINI 3D Vacuum RPG — 第一關【SECTOR 01 客廳】自行試玩與測試報告

> [!IMPORTANT]
> 本報告記錄第一關（SECTOR 01 客廳）的真實玩法模擬、關卡數據檢驗與測試結果。

---

## 🎮 關卡基本規格與設定

| 項目 | 設定規格 |
| :--- | :--- |
| **關卡名稱** | SECTOR 01 客廳 (Living Room) |
| **關卡分類** | 起始清理區 |
| **主要任務目標** | 消除地毯與沙發周圍的灰塵怪 |
| **生成異變塵怪** | 11 隻微塵小妖 (Dust Bunny) |
| **通關獲得晶幣** | +60 晶幣 (Clear Reward) + 吸取收益 |
| **通關獲得寶石** | +2 紫寶石 (Gem Reward) |
| **通關獲得經驗** | +50 XP (Experience Reward) |
| **解鎖下關** | SECTOR 02 長廊 (Passage Ruins) |

---

## 🕹️ 試玩動態過程記錄 (Stage 1 Simulation Log)

```
[00:00] 🎮 玩家點擊選擇【SECTOR 01 客廳】，進入 3D 沙盒戰鬥地圖！
[00:02] 🕹️ 拖拽左下角虛擬操縱桿 (dx: 0.7, dz: -0.5)，V-01 吸塵者向沙發旁地毯挺進
[00:04] 🌀 聚光燈吸力覆蓋敵方！順利吸入 4 隻「微塵小妖」，集塵箱（4/20），獲得 +32 晶幣
[00:07] ⚡ 點擊右下角【衝鋒】技能按鈕！V-01 瞬間加速度破空撞碎前方灰塵群，吸入 3 隻塵怪
[00:10] ✨ 沙發與地毯異變塵怪全數消滅！畫面彈出【客廳關卡淨化成功】勝利結算！獲得 +148晶幣, +2寶石, +50XP
[00:12] 🏆 點擊【返回基地】！解鎖第二關【長廊 SECTOR 02】，指揮官等級上升！目前解鎖進度：第 2 區
```

---

## 🔍 第一關測試單元驗證結果

> [!NOTE]
> 1. **戰鬥載入狀態 (Begin Mission)**：`game.screen == .mission` 並且 `game.currentZone.id == 1` — **Pass ✅**
> 2. **吸力與技能機制 (Suction & Skill)**：`V-01 吸塵器` 在 SceneKit 3D 空間中物理碰撞、吸附動畫與 Dash 衝鋒無誤 — **Pass ✅**
> 3. **通關收益結算 (Mission Cleared)**：`credits`, `gems`, `experience` 數值正確入帳，塵怪圖鑑累計討伐數增加 — **Pass ✅**
> 4. **區域解鎖機制 (Zone Unlock)**：`unlockedZone` 順利由 1 遞增為 2 — **Pass ✅**

---

## 🛠️ 相關原始程式碼與檔案連結

- 主程式 View 與 SceneKit 戰場：[`ContentView.swift`](file:///Users/115-1student06/Documents/mynini/mynini/ContentView.swift)
- 第一關自動化測試與試玩單元：[`Zone1Test.swift`](file:///Users/115-1student06/Documents/mynini/mynini/Zone1Test.swift)
- Playwright 自動化測試腳本：[`playwright_test.spec.ts`](file:///Users/115-1student06/Documents/mynini/playwright_test.spec.ts)
