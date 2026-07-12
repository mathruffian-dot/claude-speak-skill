# 「用語音回答」全域偏好設定

以下設定放在 `~/.claude/CLAUDE.md`，讓 Claude 在偵測到語音回覆意圖時自動改用 `speak` 技能。

```markdown
## 語音回覆偏好（speak 技能）
- 當使用者說「用語音回答」「唸出來」「唸給我聽」「用語音講結論」時，一律使用全域 speak 技能
  （`~/.claude/skills/speak/speak.ps1`）：Edge-TTS 生成台灣中文＋行內無視窗播放
- 不要用 `Start-Process` 開外部播放器
- 三師爸（或其他指名）的聲音 → 只在使用者明確指名時才改用 voice-clone 技能
  （VoxCPM2 較慢，不當預設）
- 講稿口語化、100–250 字、數字用中文；細節留在文字回覆，語音只講結論與下一步
```

## 運作方式

1. 使用者說「用語音回答」等觸發語。
2. Claude 依 `SKILL.md` 撰寫口語化短講稿（100–250 字，數字用中文）。
3. 以**背景執行**呼叫 `speak.ps1`，緊接著開始寫文字回覆——語音與打字並行。
4. 播放結束後回報首聲延遲（`first_sound_s`）與總時長（`total_s`）。

## 安裝

```bash
# 1. 放技能
cp -r skills/speak ~/.claude/skills/speak

# 2. 把上面的「語音回覆偏好」區塊貼進 ~/.claude/CLAUDE.md
```
