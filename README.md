# 🔊 speak — Claude Code 快速語音回覆技能

把一段結論／摘要用自然的**台灣中文語音**唸出來，達成「使用者語音輸入 → Claude 語音回覆」的對話循環。全程**行內無視窗播放**，不開任何外部播放器。

> 本 repo 打包了 `speak` 技能本體，以及搭配的「用語音回答」全域偏好設定。

---

## 📦 內容

```
claude-speak-skill/
├── skills/speak/
│   ├── SKILL.md          # 技能說明書（Claude 讀，決定何時觸發、怎麼呼叫）
│   ├── speak.ps1         # 總指揮：三層備援播放
│   └── speak_stream.py   # 串流引擎：邊生成邊播，首聲最快
├── global-setting.md     # 「用語音回答」全域偏好設定
├── index.html            # GitHub Pages 說明頁
└── README.md
```

## 🏗️ 構造：三層備援（fallback chain）

一層失敗自動退到下一層，確保任何環境都能出聲：

```
第 1 層｜串流模式（預設，最快）
  speak.ps1 → speak_stream.py → Edge-TTS 串流 → mpv/ffplay 管道播放
  首聲約 1 秒（mpv）、不落地存檔、無視窗
        │  （沒有 python / 播放器？串流失敗？）
        ▼
第 2 層｜整檔模式
  Edge-TTS 生成 mp3 → MediaPlayer(COM) 行內播放 → 退 WMPlayer(COM)
        │  （沒裝 edge-tts？生成失敗？）
        ▼
第 3 層｜SAPI 離線備援
  Windows 內建 System.Speech 直接唸（零延遲、免網路、機器感重）
```

## ⚙️ 原理

- **TTS 引擎**：微軟 **Edge-TTS**（免費、線上、音質自然）。預設男聲 `zh-TW-YunJheNeural`，女聲 `zh-TW-HsiaoChenNeural`。
- **為什麼快**：`edge_tts.Communicate().stream()` 非同步串流，每吐一塊音訊就立刻塞進 mpv/ffplay 管道，播放器一收到就出聲——不必等整段生成完。
- **為什麼無視窗**：串流走 mpv/ffplay 管道播放器（`--no-video` / `-nodisp`）；整檔走 MediaPlayer/WMPlayer COM 物件；**全程不用 `Start-Process`**。
- **與打字並行**：以背景執行呼叫，語音播放與文字回覆同時發生。

## 🚀 使用

```powershell
# PowerShell 7（pwsh，預設 UTF-8）
pwsh -NoProfile skills/speak/speak.ps1 "要唸的文字"

# 指定女聲
pwsh -NoProfile skills/speak/speak.ps1 "文字" -Voice zh-TW-HsiaoChenNeural

# 存成音檔（走整檔模式）
pwsh -NoProfile skills/speak/speak.ps1 "文字" -Out "D:\回覆.mp3"
```

或直接呼叫串流引擎（需 mpv 或 ffplay）：

```bash
echo "要唸的文字" | python skills/speak/speak_stream.py - zh-TW-YunJheNeural
```

## 📋 環境需求

| 元件 | 用途 | 備援 |
|------|------|------|
| Python + `edge-tts` | 語音生成 | 無 → 退 SAPI |
| `mpv` 或 `ffplay` | 串流管道播放 | 無 → 退整檔 COM 播放 |
| 網路 | Edge-TTS 連線 | 無 → 退 SAPI 離線 |
| PowerShell 7（`pwsh`）| 執行 `speak.ps1` | 見下方相容性註記 |

### ⚠️ 相容性註記

- `speak.ps1` 內含中文。**Windows PowerShell 5.1** 預設用系統 ANSI 讀檔，若檔案為 UTF-8 無 BOM 會解析失敗；請用 **PowerShell 7（pwsh）**，或將 `speak.ps1` 另存為 **UTF-8 with BOM**。
- 只裝了 `ffplay`（沒有 mpv）時可播放，但首聲延遲較長（管道緩衝）；追求「首聲 1 秒」請安裝 mpv。

## 🗣️ 「三師爸」聲音

需要用特定人聲時改用 `voice-clone` 技能（VoxCPM2）。本技能只負責預設台灣中文語音。

---

*本技能為 Claude Code 全域技能，MIT 授權。*
