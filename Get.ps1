param (
    [switch]$Silent,
    [switch]$Sysprep,
    [switch]$RunAppConfigurator,
    [switch]$RunDefaults, [switch]$RunWin11Defaults,
    [switch]$RemoveApps, 
    [switch]$RemoveAppsCustom,
    [switch]$RemoveGamingApps,
    [switch]$RemoveCommApps,
    [switch]$RemoveDevApps,
    [switch]$RemoveW11Outlook,
    [switch]$ForceRemoveEdge,
    [switch]$DisableDVR,
    [switch]$DisableTelemetry,
    [switch]$DisableBingSearches, [switch]$DisableBing,
    [switch]$DisableLockscrTips, [switch]$DisableLockscreenTips,
    [switch]$DisableWindowsSuggestions, [switch]$DisableSuggestions,
    [switch]$ShowHiddenFolders,
    [switch]$ShowKnownFileExt,
    [switch]$HideDupliDrive,
    [switch]$TaskbarAlignLeft,
    [switch]$HideSearchTb, [switch]$ShowSearchIconTb, [switch]$ShowSearchLabelTb, [switch]$ShowSearchBoxTb,
    [switch]$HideTaskview,
    [switch]$DisableCopilot,
    [switch]$DisableRecall,
    [switch]$DisableWidgets,
    [switch]$HideWidgets,
    [switch]$DisableChat,
    [switch]$HideChat,
    [switch]$ClearStart,
    [switch]$ClearStartAllUsers,
    [switch]$RevertContextMenu,
    [switch]$HideGallery,
    [switch]$DisableOnedrive, [switch]$HideOnedrive,
    [switch]$Disable3dObjects, [switch]$Hide3dObjects,
    [switch]$DisableMusic, [switch]$HideMusic,
    [switch]$DisableIncludeInLibrary, [switch]$HideIncludeInLibrary,
    [switch]$DisableGiveAccessTo, [switch]$HideGiveAccessTo,
    [switch]$DisableShare, [switch]$HideShare
)

# 如果當前 powershell 環境未將 LanguageMode 設置為 FullLanguage，則顯示錯誤
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
   Write-Host "錯誤：Win11Debloat 無法在您的系統上運作。 Powershell執行受到安全性策略的限制" -ForegroundColor Red
   Write-Output ""
   Write-Output "按 Enter 退出..."
   Read-Host | Out-Null
   Exit
}

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat 腳本 - 獲取"
Write-Output "-------------------------------------------------------------------------------------------"

Write-Output "> 下載 Win11Debloat..."

# 從 github 下載最新版本的 Win11Debloat 作為 zip 存檔
Invoke-WebRequest http://github.com/raphire/win11debloat/archive/master.zip -OutFile "$env:TEMP/win11debloat-temp.zip"

# 刪除舊文稿資料夾（如果存在）
if(Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ""
    Write-Output "> 清理舊的 Win11Debloat 資料夾..."
    Remove-Item -LiteralPath "$env:TEMP/Win11Debloat" -Force -Recurse
}

Write-Output ""
Write-Output "> Unpacking..."

# 解壓縮到Win11Debloat資料夾
Expand-Archive "$env:TEMP/win11debloat-temp.zip" "$env:TEMP/Win11Debloat"

# Remove archive
Remove-Item "$env:TEMP/win11debloat-temp.zip"

# 列出要傳遞給腳本的參數
$arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key)"})

Write-Output ""
Write-Output "> 運行 Win11Debloat..."

# 使用提供的參數運行 Win11Debloat 腳本
$debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File $env:TEMP\Win11Debloat\Win11Debloat-master\Win11Debloat.ps1 $arguments" -Verb RunAs

# 等待該過程完成，然後再繼續
if($debloatProcess -ne $null) {
    $debloatProcess.WaitForExit()
}

Write-Output ""
Write-Output "> 清理，刪除Win11Debloat目錄..."

# 清理，刪除Win11Debloat目錄
Remove-Item -LiteralPath "$env:TEMP/Win11Debloat" -Force -Recurse

Write-Output ""
