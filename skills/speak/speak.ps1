# speak.ps1 — 快速語音回覆（預設串流：邊生成邊播；備援整檔；再備援 SAPI）
# 用法：
#   pwsh speak.ps1 "要唸的文字"
#   pwsh speak.ps1 -File 講稿.txt
#   pwsh speak.ps1 "文字" -Voice zh-TW-HsiaoChenNeural
#   pwsh speak.ps1 "文字" -Out "D:\專案\回覆.mp3"   # 指定 -Out 時走整檔模式並保留音檔
param(
  [Parameter(Position = 0)][string]$Text,
  [string]$File,
  [string]$Voice = "zh-TW-YunJheNeural",
  [string]$Out,
  [switch]$NoStream
)
$ErrorActionPreference = "Stop"

if ($File) { $Text = Get-Content $File -Raw }
if (-not $Text) { throw "沒有要唸的文字（positional 或 -File 擇一）" }

function Invoke-SapiFallback([string]$t) {
  Add-Type -AssemblyName System.Speech
  $sp = New-Object System.Speech.Synthesis.SpeechSynthesizer
  $sp.Speak($t)
  "已唸完（SAPI 離線備援，未產生音檔）"
}

# ============ 1. 串流模式（預設）：首聲約 1 秒 ============
$py = Get-Command python -ErrorAction SilentlyContinue
$hasPlayer = (Get-Command mpv -ErrorAction SilentlyContinue) -or (Get-Command ffplay -ErrorAction SilentlyContinue)
if (-not $NoStream -and -not $Out -and $py -and $hasPlayer) {
  $streamScript = Join-Path $PSScriptRoot "speak_stream.py"
  $result = $Text | & $py.Source $streamScript - $Voice 2>$null
  if ($LASTEXITCODE -eq 0) {
    "已唸完（Edge-TTS 串流／$Voice）｜$($result -join '｜')"
    return
  }
  # 串流失敗 → 往下走整檔模式
}

# ============ 2. 整檔模式：生成 mp3 後行內播放（無視窗） ============
$edge = Get-Command edge-tts -ErrorAction SilentlyContinue
if (-not $edge) { Invoke-SapiFallback $Text; return }

if (-not $Out) {
  $dir = Join-Path $env:TEMP "claude-speak"
  New-Item -ItemType Directory -Force $dir | Out-Null
  $Out = Join-Path $dir ("speak_{0:yyyyMMdd_HHmmss}.mp3" -f (Get-Date))
}
& $edge.Source --text $Text --voice $Voice --write-media $Out
if (-not (Test-Path $Out)) { Invoke-SapiFallback $Text; return }

$played = $false
try {
  Add-Type -AssemblyName PresentationCore
  $mp = New-Object System.Windows.Media.MediaPlayer
  $mp.Volume = 1.0
  $mp.Open([Uri](Resolve-Path $Out).Path)
  $tries = 0
  while (-not $mp.NaturalDuration.HasTimeSpan -and $tries -lt 100) { Start-Sleep -Milliseconds 100; $tries++ }
  $mp.Play()
  if ($mp.NaturalDuration.HasTimeSpan) {
    Start-Sleep -Seconds ([math]::Ceiling($mp.NaturalDuration.TimeSpan.TotalSeconds) + 1)
  } else { Start-Sleep -Seconds 60 }
  $mp.Close()
  $played = $true
} catch {
  try {
    $p = New-Object -ComObject WMPlayer.OCX.7
    $p.settings.volume = 100
    $p.URL = (Resolve-Path $Out).Path
    $p.controls.play()
    Start-Sleep -Milliseconds 600
    while ($p.playState -in 6, 9, 11) { Start-Sleep -Milliseconds 200 }
    while ($p.playState -eq 3) { Start-Sleep -Milliseconds 300 }
    $p.close()
    $played = $true
  } catch { }
}

if ($played) { "已唸完（Edge-TTS 整檔／$Voice），音檔：$Out" }
else { Invoke-SapiFallback $Text }
