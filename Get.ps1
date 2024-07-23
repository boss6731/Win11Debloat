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

# �p�G��e powershell ���ҥ��N LanguageMode �]�m�� FullLanguage�A�h��ܿ��~
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
   Write-Host "���~�GWin11Debloat �L�k�b�z���t�ΤW�B�@�C Powershell�������w���ʵ���������" -ForegroundColor Red
   Write-Output ""
   Write-Output "�� Enter �h�X..."
   Read-Host | Out-Null
   Exit
}

Clear-Host
Write-Output "-------------------------------------------------------------------------------------------"
Write-Output " Win11Debloat �}�� - ���"
Write-Output "-------------------------------------------------------------------------------------------"

Write-Output "> �U�� Win11Debloat..."

# �q github �U���̷s������ Win11Debloat �@�� zip �s��
Invoke-WebRequest http://github.com/raphire/win11debloat/archive/master.zip -OutFile "$env:TEMP/win11debloat-temp.zip"

# �R���¤�Z��Ƨ��]�p�G�s�b�^
if(Test-Path "$env:TEMP/Win11Debloat") {
    Write-Output ""
    Write-Output "> �M�z�ª� Win11Debloat ��Ƨ�..."
    Remove-Item -LiteralPath "$env:TEMP/Win11Debloat" -Force -Recurse
}

Write-Output ""
Write-Output "> Unpacking..."

# �����Y��Win11Debloat��Ƨ�
Expand-Archive "$env:TEMP/win11debloat-temp.zip" "$env:TEMP/Win11Debloat"

# Remove archive
Remove-Item "$env:TEMP/win11debloat-temp.zip"

# �C�X�n�ǻ����}�����Ѽ�
$arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {"-$($_.Key)"})

Write-Output ""
Write-Output "> �B�� Win11Debloat..."

# �ϥδ��Ѫ��ѼƹB�� Win11Debloat �}��
$debloatProcess = Start-Process powershell.exe -PassThru -ArgumentList "-executionpolicy bypass -File $env:TEMP\Win11Debloat\Win11Debloat-master\Win11Debloat.ps1 $arguments" -Verb RunAs

# ���ݸӹL�{�����A�M��A�~��
if($debloatProcess -ne $null) {
    $debloatProcess.WaitForExit()
}

Write-Output ""
Write-Output "> �M�z�A�R��Win11Debloat�ؿ�..."

# �M�z�A�R��Win11Debloat�ؿ�
Remove-Item -LiteralPath "$env:TEMP/Win11Debloat" -Force -Recurse

Write-Output ""
