#Requires -RunAsAdministrator

    [CmdletBinding(SupportsShouldProcess)]
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


# Show error if current powershell environment does not have LanguageMode set to FullLanguage 
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Write-Host "Error: Win11Debloat 無法在您的系統上運行，powershell 執行受到安全策略的限制" -ForegroundColor Red
    Write-Output ""
    Write-Output "按回車鍵退出..."
    Read-Host | Out-Null
    Exit
}


# Shows application selection form that allows the user to select what apps they want to remove or keep
function ShowAppSelectionForm {
    [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
    [reflection.assembly]::loadwithpartialname("System.Drawing") | Out-Null

    # Initialise form objects
    $form = New-Object System.Windows.Forms.Form
    $label = New-Object System.Windows.Forms.Label
    $button1 = New-Object System.Windows.Forms.Button
    $button2 = New-Object System.Windows.Forms.Button
    $selectionBox = New-Object System.Windows.Forms.CheckedListBox
    $loadingLabel = New-Object System.Windows.Forms.Label
    $onlyInstalledCheckBox = New-Object System.Windows.Forms.CheckBox
    $checkUncheckCheckBox = New-Object System.Windows.Forms.CheckBox
    $initialFormWindowState = New-Object System.Windows.Forms.FormWindowState

    $global:selectionBoxIndex = -1

    # saveButton eventHandler
    $handler_saveButton_Click=
    {
        $global:SelectedApps = $selectionBox.CheckedItems

        # Create file that stores selected apps if it doesn't exist
        if (!(Test-Path "$PSScriptRoot/CustomAppsList")) {
            $null = New-Item "$PSScriptRoot/CustomAppsList"
        }

        Set-Content -Path "$PSScriptRoot/CustomAppsList" -Value $global:SelectedApps

        $form.Close()
    }

    # cancelButton eventHandler
    $handler_cancelButton_Click=
    {
        $form.Close()
    }

    $selectionBox_SelectedIndexChanged=
    {
        $global:selectionBoxIndex = $selectionBox.SelectedIndex
    }

    $selectionBox_MouseDown=
    {
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            if([System.Windows.Forms.Control]::ModifierKeys -eq [System.Windows.Forms.Keys]::Shift) {
                if($global:selectionBoxIndex -ne -1) {
                    $topIndex = $global:selectionBoxIndex

                    if ($selectionBox.SelectedIndex -gt $topIndex) {
                        for(($i = ($topIndex)); $i -le $selectionBox.SelectedIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                    elseif ($topIndex -gt $selectionBox.SelectedIndex) {
                        for(($i = ($selectionBox.SelectedIndex)); $i -le $topIndex; $i++){
                            $selectionBox.SetItemChecked($i, $selectionBox.GetItemChecked($topIndex))
                        }
                    }
                }
            }
            elseif($global:selectionBoxIndex -ne $selectionBox.SelectedIndex) {
                $selectionBox.SetItemChecked($selectionBox.SelectedIndex, -not $selectionBox.GetItemChecked($selectionBox.SelectedIndex))
            }
        }
    }

    $check_All=
    {
        for(($i = 0); $i -lt $selectionBox.Items.Count; $i++){
            $selectionBox.SetItemChecked($i, $checkUncheckCheckBox.Checked)
        }
    }

    $load_Apps=
    {
        # Correct the initial state of the form to prevent the .Net maximized form issue
        $form.WindowState = $initialFormWindowState

        # Reset state to default before loading appslist again
        $global:selectionBoxIndex = -1
        $checkUncheckCheckBox.Checked = $False

        # Show loading indicator
        $loadingLabel.Visible = $true
        $form.Refresh()

        # Clear selectionBox before adding any new items
        $selectionBox.Items.Clear()

        # Set filePath where Appslist can be found
        $appsFile = "$PSScriptRoot/Appslist.txt"
        $listOfApps = ""

        if ($onlyInstalledCheckBox.Checked -and ($global:wingetInstalled -eq $true)) {
            # Attempt to get a list of installed apps via winget, times out after 10 seconds
            $job = Start-Job { return winget list --accept-source-agreements --disable-interactivity }
            $jobDone = $job | Wait-Job -TimeOut 10

            if (-not $jobDone) {
                # Show error that the script was unable to get list of apps from winget
                [System.Windows.MessageBox]::Show('無法透過 winget 載入已安裝的應用程式清單，某些應用程式可能無法顯示在清單中.','Error','Ok','Error')
            }
            else {
                # Add output of job (list of apps) to $listOfApps
                $listOfApps = Receive-Job -Job $job
            }
        }

        # Go through appslist and add items one by one to the selectionBox
        Foreach ($app in (Get-Content -Path $appsFile | Where-Object { $_ -notmatch '^\s*$' } )) {
            $appChecked = $true

            # Remove first # if it exists and set AppChecked to false
            if ($app.StartsWith('#')) {
                $app = $app.TrimStart("#")
                $appChecked = $false
            }
            # Remove any comments from the Appname
            if (-not ($app.IndexOf('#') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf('#'))
            }
            # Remove any remaining spaces from the Appname
            if (-not ($app.IndexOf(' ') -eq -1)) {
                $app = $app.Substring(0, $app.IndexOf(' '))
            }

            $appString = $app.Trim('*')

            # Make sure appString is not empty
            if ($appString.length -gt 0) {
                if ($onlyInstalledCheckBox.Checked) {
                    # onlyInstalledCheckBox is checked, check if app is installed before adding it to selectionBox
                    if (-not ($listOfApps -like ("*$appString*")) -and -not (Get-AppxPackage -Name $app)) {
                        # App is not installed, continue with next item
                        continue
                    }
                    if (($appString -eq "Microsoft.Edge") -and -not ($listOfApps -like "* Microsoft.Edge *")) {
                        # App is not installed, continue with next item
                        continue
                    }
                }

                # Add the app to the selectionBox and set it's checked status
                $selectionBox.Items.Add($appString, $appChecked) | Out-Null
            }
        }

        # Hide loading indicator
        $loadingLabel.Visible = $False

        # Sort selectionBox alphabetically
        $selectionBox.Sorted = $True
    }

    $form.Text = "Win11Debloat 應用程式選擇"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "確認"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "取消"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = '選取您希望刪除的應用程式，取消選取您希望保留的應用程式'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = '載入應用程式...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = '僅顯示已安裝的應用'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = '選中/取消選取全部'
    $checkUncheckCheckBox.add_CheckedChanged($check_All)

    $form.Controls.Add($checkUncheckCheckBox)

    $selectionBox.FormattingEnabled = $True
    $selectionBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $selectionBox.Name = "selectionBox"
    $selectionBox.Location = New-Object System.Drawing.Point(13,43)
    $selectionBox.Size = New-Object System.Drawing.Size(374,424)
    $selectionBox.TabIndex = 3
    $selectionBox.add_SelectedIndexChanged($selectionBox_SelectedIndexChanged)
    $selectionBox.add_Click($selectionBox_MouseDown)

    $form.Controls.Add($selectionBox)

    # Save the initial state of the form
    $initialFormWindowState = $form.WindowState

    # Load apps into selectionBox
    $form.add_Load($load_Apps)

    # Focus selectionBox when form opens
    $form.Add_Shown({$form.Activate(); $selectionBox.Focus()})

    # Show the Form
    return $form.ShowDialog()
}


# Reads list of apps from file and removes them for all user accounts and from the OS image.
function RemoveAppsFromFile {
    param (
        $appsFilePath
    )

    $appsList = @()

    Write-Output "> 刪除預設選擇的應用程式..."

    # Get list of apps from file at the path provided, and remove them one by one
    Foreach ($app in (Get-Content -Path $appsFilePath | Where-Object { $_ -notmatch '^#.*' -and $_ -notmatch '^\s*$' } )) {
        # Remove any spaces before and after the Appname
        $app = $app.Trim()

        # Remove any comments from the Appname
        if (-not ($app.IndexOf('#') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf('#'))
        }
        # Remove any remaining spaces from the Appname
        if (-not ($app.IndexOf(' ') -eq -1)) {
            $app = $app.Substring(0, $app.IndexOf(' '))
        }

        $appString = $app.Trim('*')
        $appsList += $appString
    }

    RemoveApps $appsList
}


# Removes apps specified during function call from all user accounts and from the OS image.
function RemoveApps {
    param (
        $appslist
    )

    Foreach ($app in $appsList) {
        Write-Output "Attempting to remove $app..."

        if (($app -eq "Microsoft.OneDrive") -or ($app -eq "Microsoft.Edge")) {
            # Use winget to remove OneDrive and Edge
            if ($global:wingetInstalled -eq $false) {
                Write-Host "WinGet is either not installed or is outdated, so $app could not be removed" -ForegroundColor Red
            }
            else {
                # Uninstall app via winget
                Strip-Progress -ScriptBlock { winget uninstall --accept-source-agreements --disable-interactivity --id $app } | Tee-Object -Variable wingetOutput

                If (($app -eq "Microsoft.Edge") -and (Select-String -InputObject $wingetOutput -Pattern "93")) {
                    Write-Host "Error: 無法通過 Winget 卸載 Microsoft Edge" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "您想強制卸載 Edge 嗎？不推薦！ (y/n)" ) -eq 'y') {
                        Write-Output ""
                        ForceRemoveEdge
                    }
                }
            }
        }
        else {
            # Use Remove-AppxPackage to remove all other apps
            $app = '*' + $app + '*'

            # Remove installed app for all existing users
            if ($WinVersion -ge 22000){
                # Windows 11 build 22000 or later
                Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers
            }
            else {
                # Windows 10
                Get-AppxPackage -Name $app -PackageTypeFilter Main, Bundle, Resource -AllUsers | Remove-AppxPackage -AllUsers
            }

            # Remove provisioned app from OS image, so the app won't be installed for any new users
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $app } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
        }
    }
}


function ForceRemoveEdge {
    # Based on work from loadstring1 & ave9858
    Write-Output "> 強制卸載 Microsoft Edge..."

    $regView = [Microsoft.Win32.RegistryView]::Registry32
    $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $regView)
    $hklm.CreateSubKey('SOFTWARE\Microsoft\EdgeUpdateDev').SetValue('AllowUninstall', '')

    # Create stub (Creating this somehow allows uninstalling edge)
    $edgeStub = "$env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe"
    New-Item $edgeStub -ItemType Directory | Out-Null
    New-Item "$edgeStub\MicrosoftEdge.exe" | Out-Null

    # Remove edge
    $uninstallRegKey = $hklm.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge')
    if($uninstallRegKey -ne $null) {
        Write-Output "運行卸載程式..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "刪除剩餘檔..."

        $appdata = $([Environment]::GetFolderPath('ApplicationData'))

        $edgePaths = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
        "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
        "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk",
        "$env:PUBLIC\Desktop\Microsoft Edge.lnk",
        "$env:USERPROFILE\Desktop\Microsoft Edge.lnk",
        "$appdata\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Tombstones\Microsoft Edge.lnk",
        "$appdata\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk",
        "$edgeStub"
        )

        foreach ($path in $edgePaths){
            if (Test-Path -Path $path) {
                Remove-Item -Path $path -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "  Removed $path" -ForegroundColor DarkGray
            }
        }

        Write-Output "清理註冊表..."

        # Remove ms edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge 已卸載"
    }
    else {
        Write-Output ""
        Write-Host "Error: 無法強制卸載 Microsoft Edge，找不到卸載程式" -ForegroundColor Red
    }

    Write-Output ""
}


# Execute provided command and strips progress spinners/bars from console output
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = 'Γ?[??]|^\s+[-\\|/]\s+$'

    # Corrected regex pattern for size formatting, ensuring proper capture groups are utilized
    $sizePattern = '(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB) /\s+(\d+(\.\d{1,2})?)\s+(B|KB|MB|GB|TB|PB)'

    & $ScriptBlock 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            "ERROR: $($_.Exception.Message)"
        } else {
            $line = $_ -replace $progressPattern, '' -replace $sizePattern, ''
            if (-not ([string]::IsNullOrWhiteSpace($line)) -and -not ($line.StartsWith('  '))) {
                $line
            }
        }
    }
}


# Import & execute regfile
function RegImport {
    param (
        $message,
        $path
    )

    Write-Output $message


    if (!$global:Params.ContainsKey("Sysprep")) {
        reg import "$PSScriptRoot\Regfiles\$path"
    }
    else {
        reg load "HKU\Default" "C:\Users\Default\NTUSER.DAT" | Out-Null
        reg import "$PSScriptRoot\Regfiles\Sysprep\$path"
        reg unload "HKU\Default" | Out-Null
    }

    Write-Output ""
}


# Restart the Windows Explorer process
function RestartExplorer {
    Write-Output "> 重新啟動 Windows 資源管理員行程以應用程式所有變更...（這可能會導致一些閃爍）"

    # Only restart if the powershell process matches the OS architecture
    # Restarting explorer from a 32bit Powershell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem)
    {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "無法重新啟動Windows資源管理器進程，請手動重新啟動您的PC以應用所有更改."
    }
}


# 從「開始」功能表中清除所有固定的應用.
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ClearStartMenu {
    param (
        $message,
        $applyToAllUsers = $True
    )

    Write-Output $message

    # 開始功能表範本的路徑
    $startmenuTemplate = "$PSScriptRoot/Start/start2.bin"

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startmenuTemplate)) {
        Write-Host "Error: 無法清除開始功能表，文稿資料夾中缺少start2.bin檔。" -ForegroundColor Red
        Write-Output ""
        return
    }

    if ($applyToAllUsers) {
        # 為所有使用者刪除 startmenu 固定的應用
        # 獲取所有使用者配置檔資料夾
        $usersStartMenu = get-childitem -path "C:\Users\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

        # Copy Start menu to all users folders
        ForEach ($startmenu in $usersStartMenu) {
            $startmenuBinFile = $startmenu.Fullname + "\start2.bin"
            $backupBinFile = $startmenuBinFile + ".bak"

            # Check if bin file exists
            if (Test-Path $startmenuBinFile) {
                # Backup current startmenu file
                Move-Item -Path $startmenuBinFile -Destination $backupBinFile -Force

                # Copy template file
                Copy-Item -Path $startmenuTemplate -Destination $startmenu -Force

                Write-Output "Replaced start menu for user $($startmenu.Fullname.Split("\")[2])"
            }
            else {
                # Bin file doesn't exist, indicating the user is not running the correct version of Windows. Exit function
                Write-Host "Error: 無法清除開始功能表，無法為使用者找到start2.bin檔" $startmenu.Fullname.Split("\")[2]  -ForegroundColor Red
                Write-Output ""
                return
            }
        }

        # Also apply start menu template to the default profile

        # Path to default profile
        $defaultProfile = "C:\Users\default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

        # Create folder if it doesn't exist
        if (-not(Test-Path $defaultProfile)) {
            new-item $defaultProfile -ItemType Directory -Force | Out-Null
            Write-Output "為預設用戶創建了 LocalState 資料夾"
        }

        # Copy template to default profile
        Copy-Item -Path $startmenuTemplate -Destination $defaultProfile -Force
        Write-Output "已將開始功能表範本複製到預設使用者資料夾"
        Write-Output ""
    }
    else {
        # Only remove startmenu pinned apps for current logged in user
        $startmenuBinFile = "C:\Users\$([Environment]::UserName)\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        $backupBinFile = $startmenuBinFile + ".bak"

        # Check if bin file exists
        if (Test-Path $startmenuBinFile) {
            # Backup current startmenu file
            Move-Item -Path $startmenuBinFile -Destination $backupBinFile -Force

            # Copy template file
            Copy-Item -Path $startmenuTemplate -Destination $startmenuBinFile -Force

            Write-Output "Replaced start menu for user $([Environment]::UserName)"
            Write-Output ""
        }
        else {
            # Bin 檔不存在，表示使用者未運行正確版本的 Windows。退出功能
            Write-Host "Error: 無法清除開始功能表，無法為使用者找到start2.bin檔 $([Environment]::UserName)" -ForegroundColor Red
            Write-Output ""
            return
        }
    }
}


# Add parameter to script and write to file
function AddParameter {
    param (
        $parameterName,
        $message
    )

    # Add key if it doesn't already exist
    if (-not $global:Params.ContainsKey($parameterName)) {
        $global:Params.Add($parameterName, $true)
    }

    # Create or clear file that stores last used settings
    if (!(Test-Path "$PSScriptRoot/SavedSettings")) {
        $null = New-Item "$PSScriptRoot/SavedSettings"
    }
    elseif ($global:FirstSelection) {
        $null = Clear-Content "$PSScriptRoot/SavedSettings"
    }

    $global:FirstSelection = $false

    # Create entry and add it to the file
    $entry = "$parameterName#- $message"
    Add-Content -Path "$PSScriptRoot/SavedSettings" -Value $entry
}


function PrintHeader {
    param (
        $title
    )

    $fullTitle = " Win11Debloat Script - $title"

    if($global:Params.ContainsKey("Sysprep")) {
        $fullTitle = "$fullTitle (Sysprep mode)"
    }
    else {
        $fullTitle = "$fullTitle (User: $Env:UserName)"
    }

    Clear-Host
    Write-Output "-------------------------------------------------------------------------------------------"
    Write-Output $fullTitle
    Write-Output "-------------------------------------------------------------------------------------------"
}


function PrintFromFile {
    param (
        $path
    )

    Clear-Host

    # Get & print script menu from file
    Foreach ($line in (Get-Content -Path $path )) {
        Write-Output $line
    }
}


function AwaitKeyToExit {
    # Suppress prompt if Silent parameter was passed
    if (-not $Silent) {
        Write-Output ""
        Write-Output "按任意鍵退出..."
        $null = [System.Console]::ReadKey()
    }
}



##################################################################################################################
#                                                                                                                #
#                                                  SCRIPT START                                                  #
#                                                                                                                #
##################################################################################################################



# Check if winget is installed & if it is, check if the version is at least v1.4
if ((Get-AppxPackage -Name "*Microsoft.DesktopAppInstaller*") -and ((winget -v) -replace 'v','' -gt 1.4)) {
    $global:wingetInstalled = $true
}
else {
    $global:wingetInstalled = $false

    # Show warning that requires user confirmation, Suppress confirmation if Silent parameter was passed
    if (-not $Silent) {
        Write-Warning "Winget 未安裝或已過期。這可能會阻止 Win11Debloat 刪除某些應用程式."
        Write-Output ""
        Write-Output "無論如何，按任意鍵繼續..."
        $null = [System.Console]::ReadKey()
    }
}

# Get current Windows build version to compare against features
$WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

# Hide progress bars for app removal, as they block Win11Debloat's output
$ProgressPreference = 'SilentlyContinue'

$global:Params = $PSBoundParameters
$global:FirstSelection = $true
$SPParams = 'WhatIf', 'Confirm', 'Verbose', 'Silent', 'Sysprep'
$SPParamCount = 0

# Count how many SPParams exist within Params
# This is later used to check if any options were selected
foreach ($Param in $SPParams) {
    if ($global:Params.ContainsKey($Param)) {
        $SPParamCount++
    }
}

if ($global:Params.ContainsKey("Sysprep")) {
    # Exit script if default user directory or NTUSER.DAT file cannot be found
    if (-not (Test-Path "C:\Users\Default\NTUSER.DAT")) {
        Write-Host "Error: 無法在 Sysprep 模式下啟動 Win11Debloat，在 找不到預設使用者資料夾 'C:\Users\Default\'" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Host "Error: Windows 10 不支援 Win11Debloat Sysprep 模式" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
}

# Remove SavedSettings file if it exists and is empty
if ((Test-Path "$PSScriptRoot/SavedSettings") -and ([String]::IsNullOrWhiteSpace((Get-content "$PSScriptRoot/SavedSettings")))) {
    Remove-Item -Path "$PSScriptRoot/SavedSettings" -recurse
}

# Only run the app selection form if the 'RunAppConfigurator' parameter was passed to the script
if ($RunAppConfigurator) {
    PrintHeader "App Configurator"

    $result = ShowAppSelectionForm

    # Show different message based on whether the app selection was saved or cancelled
    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
        Write-Host "應用程式設定器已關閉，未保存." -ForegroundColor Red
    }
    else {
        Write-Output "您的應用選擇已保存到腳本根資料夾中的「CustomAppsList」 檔案中."
    }

    AwaitKeyToExit

    Exit
}

# Change script execution based on provided parameters or user input
if ((-not $global:Params.Count) -or $RunDefaults -or $RunWin11Defaults -or ($SPParamCount -eq $global:Params.Count)) {
    if ($RunDefaults -or $RunWin11Defaults) {
        $Mode = '1'
    }
    else {
        # Show menu and wait for user input, loops until valid input is provided
        Do {
            $ModeSelectionMessage = "請選擇一個選項 (1/2/3/0)"

            PrintHeader '功能表'

            Write-Output "(1) 預設模式：應用預設設置"
            Write-Output "(2) 自訂模式：根據您的需要修改腳本"
            Write-Output "(3) 應用程式刪除模式：選擇並刪除應用程式，而不進行其他更改"

            # Only show this option if SavedSettings file exists
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) 應用上次保存的自定義設置"

                $ModeSelectionMessage = "請選擇一個選項 (1/2/3/4/0)"
            }

            Write-Output ""
            Write-Output "(0) 顯示更多資訊"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            # Show information based on user input, Suppress user prompt if Silent parameter was passed
            if ($Mode -eq '0') {
                # Get & print script information from file
                PrintFromFile "$PSScriptRoot/Menus/Info"

                Write-Output ""
                Write-Output "按任意鍵返回..."
                $null = [System.Console]::ReadKey()
            }
            elseif (($Mode -eq '4')-and -not (Test-Path "$PSScriptRoot/SavedSettings")) {
                $Mode = $null
            }
        }
        while ($Mode -ne '1' -and $Mode -ne '2' -and $Mode -ne '3' -and $Mode -ne '4')
    }

    # Add execution parameters based on the mode
    switch ($Mode) {
        # Default mode, loads defaults after confirmation
        '1' {
            # Print the default settings & require userconfirmation, unless Silent parameter was passed
            if (-not $Silent) {
                PrintFromFile "$PSScriptRoot/Menus/DefaultSettings"

                Write-Output ""
                Write-Output "按回車鍵執行腳本，或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot'

            PrintHeader '預設模式'

            # Add default parameters if they don't already exist
            foreach ($ParameterName in $DefaultParameterNames) {
                if (-not $global:Params.ContainsKey($ParameterName)){
                    $global:Params.Add($ParameterName, $true)
                }
            }

            # Only add this option for Windows 10 users, if it doesn't already exist
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -and (-not $global:Params.ContainsKey('Hide3dObjects'))) {
                $global:Params.Add('Hide3dObjects', $Hide3dObjects)
            }
        }

        # Custom mode, show & add options based on user input
        '2' {
            # Get current Windows build version to compare against features
            $WinVersion = Get-ItemPropertyValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' CurrentBuild

            PrintHeader '自訂模式'

            # Show options for removing apps, only continue on valid input
            Do {
                Write-Host "選項：" -ForegroundColor Yellow
                Write-Host " (n) 請勿移除任何應用" -ForegroundColor Yellow
                Write-Host " (1) 僅從「Appslist.txt」中刪除英國媒體報道軟體應用的預設選擇" -ForegroundColor Yellow
                Write-Host " (2) 刪除預設選擇的英國媒體報導應用程式，以及郵件和日曆應用程式，開發人員應用程式和遊戲應用程式"  -ForegroundColor Yellow
                Write-Host " (3) 選擇要刪除的應用以及要保留的應用" -ForegroundColor Yellow
                $RemoveAppsInput = Read-Host "刪除任何預安裝的應用程式？ (n/1/2/3)"

                # Show app selection form if user entered option 3
                if ($RemoveAppsInput -eq '3') {
                    $result = ShowAppSelectionForm

                    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                        # User cancelled or closed app selection, show error and change RemoveAppsInput so the menu will be shown again
                        Write-Output ""
                        Write-Host "已取消應用程式選擇，請重試" -ForegroundColor Red

                        $RemoveAppsInput = 'c'
                    }

                    Write-Output ""
                }
            }
            while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3')

            # Select correct option based on user input
            switch ($RemoveAppsInput) {
                '1' {
                    AddParameter 'RemoveApps' '刪除英國媒體報導軟體應用的預設選擇'
                }
                '2' {
                    AddParameter 'RemoveApps' '刪除英國媒體報導軟體應用的預設選擇'
                    AddParameter 'RemoveCommApps' '拿掉「郵件」、「日曆」和「人脈」應用'
                    AddParameter 'RemoveW11Outlook' '刪除新的 Outlook for Windows 應用'
                    AddParameter 'RemoveDevApps' '拿掉與開發者相關的應用'
                    AddParameter 'RemoveGamingApps' '刪除 Xbox 應用和 Xbox Gamebar'
                    AddParameter 'DisableDVR' '禁用 Xbox 遊戲/螢幕錄製'
                }
                '3' {
                    Write-Output "You have selected $($global:SelectedApps.Count) apps for removal"

                    AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"

                    Write-Output ""

                    if ($( Read-Host -Prompt "禁用Xbox遊戲/螢幕錄製？還會停止遊戲疊加彈出視窗 （y/n）" ) -eq 'y') {
                        AddParameter 'DisableDVR' '禁用 Xbox 遊戲/螢幕錄製'
                    }
                }
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($global:Params.ContainsKey("Sysprep")) {
                    if ($( Read-Host -Prompt "從所有現有使用者和新用戶的開始功能表中刪除所有固定的應用？（是/否）" ) -eq 'y') {
                        AddParameter 'ClearStartAllUsers' '從現有使用者和新使用者的「開始」功能表中刪除所有固定的應用'
                    }
                }
                else {
                    Do {
                        Write-Host "選項：" -ForegroundColor Yellow
                        Write-Host " (n) 不要從「開始」功能表中刪除任何固定的應用" -ForegroundColor Yellow
                        Write-Host " (1) 僅從「開始」功能表中刪除此使用者的所有固定應用 ($([Environment]::UserName))" -ForegroundColor Yellow
                        Write-Host " (2) 從所有現有使用者和新使用者的「開始」功能表中刪除所有固定的應用"  -ForegroundColor Yellow
                        $ClearStartInput = Read-Host "從開始功能表中刪除所有固定的應用程式？這無法恢復 (n/1/2)"
                    }
                    while ($ClearStartInput -ne 'n' -and $ClearStartInput -ne '0' -and $ClearStartInput -ne '1' -and $ClearStartInput -ne '2')

                    # Select correct option based on user input
                    switch ($ClearStartInput) {
                        '1' {
                            AddParameter 'ClearStart' "僅從「開始」功能表中刪除此使用者的所有固定應用"
                        }
                        '2' {
                            AddParameter 'ClearStartAllUsers' "從所有現有使用者和新使用者的「開始」功能表中刪除所有固定的應用"
                        }
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "禁用遙測、診斷數據、活動歷史記錄、應用啟動跟蹤和定向廣告？(y/n)" ) -eq 'y') {
                AddParameter 'DisableTelemetry' '禁用遙測、診斷數據、活動歷史記錄、應用啟動跟蹤和定向廣告'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "在開始、設置、通知、資源管理器和鎖屏中禁用提示、技巧、建議和廣告？ (y/n)" ) -eq 'y') {
                AddParameter 'DisableSuggestions' '在開始、設置、通知和文件資源管理器中禁用提示、技巧、建議和廣告'
                AddParameter 'DisableLockscreenTips' '在鎖屏上禁用提示和技巧'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "在Windows搜索中禁用和刪除bing web搜索，bing AI和cortana？（是/否）" ) -eq 'y') {
                AddParameter 'DisableBing' '在Windows搜索中禁用和刪除bing web搜索，bing AI和Cortana'
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "禁用 Windows Copilot？這適用於所有使用者 （y/n）" ) -eq 'y') {
                    AddParameter 'DisableCopilot' '禁用 Windows 副駕駛'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "禁用 Windows Recall 快照？這適用於所有使用者 （y/n）" ) -eq 'y') {
                    AddParameter 'DisableRecall' '禁用 Windows Recall 快照'
                }
            }

            # Only show this option for Windows 11 users running build 22000 or later
            if ($WinVersion -ge 22000){
                Write-Output ""

                if ($( Read-Host -Prompt "恢復舊的 Windows 10 樣式上下文功能表？（是/否）" ) -eq 'y') {
                    AddParameter 'RevertContextMenu' '恢復舊的 Windows 10 樣式上下文功能表'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "是否要對任務列和相關服務進行任何更改？（是/否）" ) -eq 'y') {
                # Only show these specific options for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   將任務列按鈕與左側對齊？（是/否）" ) -eq 'y') {
                        AddParameter 'TaskbarAlignLeft' '將任務列圖示向左對齊'
                    }

                    # 在任務列上顯示搜索圖示的選項，僅在有效輸入時繼續
                    Do {
                        Write-Output ""
                        Write-Host "   選項：" -ForegroundColor Yellow
                        Write-Host "    (n) No change" -ForegroundColor Yellow
                        Write-Host "    (1) 隱藏任務列中的搜索圖示" -ForegroundColor Yellow
                        Write-Host "    (2) 在任務列上顯示搜尋圖示" -ForegroundColor Yellow
                        Write-Host "    (3) 在任務列上顯示帶有標籤的搜索圖示" -ForegroundColor Yellow
                        Write-Host "    (4) 在任務列上顯示搜索框" -ForegroundColor Yellow
                        $TbSearchInput = Read-Host "   隱藏或更改工作列上的搜尋圖示？ (n/1/2/3/4)"
                    }
                    while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4')

                    # Select correct taskbar search option based on user input
                    switch ($TbSearchInput) {
                        '1' {
                            AddParameter 'HideSearchTb' '隱藏任務列中的搜索圖示'
                        }
                        '2' {
                            AddParameter 'ShowSearchIconTb' '在任務列上顯示搜尋圖示'
                        }
                        '3' {
                            AddParameter 'ShowSearchLabelTb' '在任務列上顯示帶有標籤的搜索圖示'
                        }
                        '4' {
                            AddParameter 'ShowSearchBoxTb' '在任務列上顯示搜索框'
                        }
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   從任務列中隱藏任務檢視按鈕？（是/否）" ) -eq 'y') {
                        AddParameter 'HideTaskview' '從任務列中隱藏任務檢視按鈕'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   禁用小部件服務並從任務欄中隱藏圖示？（是/否）" ) -eq 'y') {
                    AddParameter 'DisableWidgets' '禁用小部件服務並從任務欄中隱藏小部件（新聞和興趣）圖示'
                }

                # Only show this options for Windows users running build 22621 or earlier
                if ($WinVersion -le 22621){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   從任務列中隱藏聊天（立即開會）圖示？（是/否）" ) -eq 'y') {
                        AddParameter 'HideChat' '在任務列中隱藏聊天（立即開會）圖示'
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "是否要對檔案資源管理員進行任何更改？（是/否）" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   顯示隱藏的檔案、資料夾和驅動器？（是/否）" ) -eq 'y') {
                    AddParameter 'ShowHiddenFolders' '顯示隱藏的檔案、資料夾和驅動器'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   顯示已知檔類型的檔擴展名？（是/否）" ) -eq 'y') {
                    AddParameter 'ShowKnownFileExt' '顯示已知檔類型的檔擴展名'
                }

                # Only show this option for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   從檔案資源管理器側面板中隱藏庫部分？（是/否）" ) -eq 'y') {
                        AddParameter 'HideGallery' '從檔案資源管理器側面板中隱藏庫部分'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   在檔案資源管理器側面板中隱藏重複的可移動驅動器條目，以便它們僅顯示在「此電腦」下？（是/否）" ) -eq 'y') {
                    AddParameter 'HideDupliDrive' '在檔案資源管理器側面板中隱藏重複的可移動驅動器條目'
                }

                # Only show option for disabling these specific folders for Windows 10 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "是否要從檔案資源管理器側面板中隱藏任何資料夾？（是/否）" ) -eq 'y') {
                        Write-Output ""

                        if ($( Read-Host -Prompt "   從檔案資源管理器側面板中隱藏 onedrive 資料夾？（是/否）" ) -eq 'y') {
                            AddParameter 'HideOnedrive' '在檔案資源管理器側面板中隱藏 onedrive 資料夾'
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   從檔案資源管理器側面板中隱藏 3D 物件資料夾？（是/否）" ) -eq 'y') {
                            AddParameter 'Hide3dObjects' "在檔案資源管理員中的「這台電腦」下隱藏 3D 物件資料夾"
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   從檔案資源管理器側面板中隱藏音樂資料夾？（是/否）" ) -eq 'y') {
                            AddParameter 'HideMusic' "在檔案資源管理員中的「這台電腦」下隱藏音樂資料夾"
                        }
                    }
                }
            }

            # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $global:Params.ContainsKey('RevertContextMenu')){
                Write-Output ""

                if ($( Read-Host -Prompt "是否要禁用任何上下文功能表選項？（是/否）" ) -eq 'y') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   在上下文功能表中隱藏「包含在庫中」選項？（是/否）" ) -eq 'y') {
                        AddParameter 'HideIncludeInLibrary' "隱藏上下文功能表中的「包含在庫中」 選項"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   在上下文功能表中隱藏「授予訪問許可權」選項？（是/否）" ) -eq 'y') {
                        AddParameter 'HideGiveAccessTo' "隱藏上下文功能表中的「授予訪問許可權」 選項"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   在上下文功能表中隱藏「共享」選項？（是/否）" ) -eq 'y') {
                        AddParameter 'HideShare' "隱藏上下文功能表中的「共用」選項"
                    }
                }
            }

            # Suppress prompt if Silent parameter was passed
            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output ""
                Write-Output "按回車鍵確認您的選擇並執行腳本，或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            PrintHeader 'Custom Mode'
        }

        # App removal, remove apps based on user selection
        '3' {
            PrintHeader "應用移除"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "You have selected $($global:SelectedApps.Count) apps for removal"
                AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"

                # Suppress prompt if Silent parameter was passed
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output "按 Enter 鍵刪除所選應用，或按 CTRL+C 鍵退出..."
                    Read-Host | Out-Null
                    PrintHeader "應用移除"
                }
            }
            else {
                Write-Host "選擇已取消，未刪除任何應用程式！" -ForegroundColor Red
                Write-Output ""
            }
        }

        # Load custom options selection from the "SavedSettings" file
        '4' {
            if (-not $Silent) {
                PrintHeader '自訂模式'
                Write-Output "Win11Debloat 將進行以下更改："

                # Get & print default settings info from file
                Foreach ($line in (Get-Content -Path "$PSScriptRoot/SavedSettings" )) {
                    # Remove any spaces before and after the Appname
                    $line = $line.Trim()

                    # Check if line has # char, show description, add parameter
                    if (-not ($line.IndexOf('#') -eq -1)) {
                        Write-Output $line.Substring(($line.IndexOf('#') + 1), ($line.Length - $line.IndexOf('#') - 1))
                        $paramName = $line.Substring(0, $line.IndexOf('#'))

                        if ($paramName -eq "RemoveAppsCustom") {
                            # If paramName is RemoveAppsCustom, check if CustomAppsFile exists
                            if (Test-Path "$PSScriptRoot/CustomAppsList") {
                                # Apps file exists, print list of apps
                                $appsList = @()

                                # Get apps list from file
                                Foreach ($app in (Get-Content -Path "$PSScriptRoot/CustomAppsList" )) {
                                    # Remove any spaces before and after the app name
                                    $app = $app.Trim()

                                    $appsList += $app
                                }

                                Write-Host $appsList -ForegroundColor DarkGray
                            }
                            else {
                                # Apps file does not exist, print error and continue to next item
                                Write-Host "Error: 無法從檔案載入自定義應用程式清單，不會刪除任何應用程式！" -ForegroundColor Red
                                continue
                            }
                        }

                        if (-not $global:Params.ContainsKey($ParameterName)){
                            $global:Params.Add($paramName, $true)
                        }
                    }
                }

                Write-Output ""
                Write-Output ""
                Write-Output "按回車鍵執行腳本，或按 CTRL+C 退出..."
                Read-Host | Out-Null
            }

            PrintHeader '自訂模式'
        }
    }
}
else {
    PrintHeader '自訂模式'
}


# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $global:Params.Keys.Count) {
    Write-Output "腳本在未進行任何更改的情況下完成."

    AwaitKeyToExit
}
else {
    # Execute all selected/provided parameters
    switch ($global:Params.Keys) {
        'RemoveApps' {
            RemoveAppsFromFile "$PSScriptRoot/Appslist.txt"
            continue
        }
        'RemoveAppsCustom' {
            if (Test-Path "$PSScriptRoot/CustomAppsList") {
                $appsList = @()

                # Get apps list from file
                Foreach ($app in (Get-Content -Path "$PSScriptRoot/CustomAppsList" )) {
                    # Remove any spaces before and after the app name
                    $app = $app.Trim()

                    $appsList += $app
                }

                Write-Output "> Removing $($appsList.Count) apps..."
                RemoveApps $appsList
            }
            else {
                Write-Host "> 無法從檔案載入自訂應用程式清單，未刪除任何應用程式！" -ForegroundColor Red
            }

            Write-Output ""
            continue
        }
        'RemoveCommApps' {
            Write-Output "> 拿掉「郵件」、「日曆」和「人脈」應用..."

            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            RemoveApps $appsList

            Write-Output ""
            continue
        }
        'RemoveW11Outlook' {
            Write-Output "> 刪除新的 Outlook for Windows 應用..."

            $appsList = 'Microsoft.OutlookForWindows'
            RemoveApps $appsList

            Write-Output ""
            continue
        }
        'RemoveDevApps' {
            Write-Output "> 拿掉與開發者相關的應用..."

            $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
            RemoveApps $appsList

            Write-Output ""

            continue
        }
        'RemoveGamingApps' {
            Write-Output "> 刪除與遊戲相關的應用程式..."

            $appsList = 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay'
            RemoveApps $appsList

            Write-Output ""

            continue
        }
        "ForceRemoveEdge" {
            ForceRemoveEdge
            continue
        }
        'DisableDVR' {
            RegImport "> 禁用 Xbox 遊戲/螢幕錄製..." "Disable_DVR.reg"
            continue
        }
        'ClearStart' {
            ClearStartMenu "> 從「開始」功能表中刪除所有固定的應用..." $False
            continue
        }
        'ClearStartAllUsers' {
            ClearStartMenu "> 從所有使用者的「開始」功能表中刪除所有固定的應用..."
            continue
        }
        'DisableTelemetry' {
            RegImport "> 禁用遙測、診斷數據、活動歷史記錄、應用啟動跟蹤和定向廣告..." "Disable_Telemetry.reg"
            continue
        }
        {$_ -in "DisableBingSearches", "DisableBing"} {
            RegImport "> 在 Windows 搜尋中禁用 bing web 搜索、bing AI 和 cortana..." "Disable_Bing_Cortana_In_Search.reg"

            # Also remove the app package for bing search
            $appsList = 'Microsoft.BingSearch'
            RemoveApps $appsList

            Write-Output ""

            continue
        }
        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
            RegImport "> 在鎖屏上禁用提示和技巧..." "Disable_Lockscreen_Tips.reg"
            continue
        }
        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
            RegImport "> 在 Windows 中禁用提示、技巧、建議和廣告..." "Disable_Windows_Suggestions.reg"
            continue
        }
        'RevertContextMenu' {
            RegImport "> 恢復舊的 Windows 10 樣式上下文功能表..." "Disable_Show_More_Options_Context_Menu.reg"
            continue
        }
        'TaskbarAlignLeft' {
            RegImport "> 將任務列按鈕向左對齊..." "Align_Taskbar_Left.reg"

            continue
        }
        'HideSearchTb' {
            RegImport "> 隱藏任務列中的搜索圖示..." "Hide_Search_Taskbar.reg"
            continue
        }
        'ShowSearchIconTb' {
            RegImport "> 將任務列搜索更改為僅圖示..." "Show_Search_Icon.reg"
            continue
        }
        'ShowSearchLabelTb' {
            RegImport "> 將任務列搜索更改為帶標籤的圖示..." "Show_Search_Icon_And_Label.reg"
            continue
        }
        'ShowSearchBoxTb' {
            RegImport "> 將任務列搜索更改為搜索框..." "Show_Search_Box.reg"
            continue
        }
        'HideTaskview' {
            RegImport "> 在任務欄中隱藏 taskview 按鈕..." "Hide_Taskview_Taskbar.reg"
            continue
        }
        'DisableCopilot' {
            RegImport "> 禁用 Windows 副駕駛..." "Disable_Copilot.reg"
            continue
        }
        'DisableRecall' {
            RegImport "> 禁用 Windows Recall 快照..." "Disable_AI_Recall.reg"
            continue
        }
        {$_ -in "HideWidgets", "DisableWidgets"} {
            RegImport "> 禁用小組件服務並從任務欄中隱藏小組件圖示..." "Disable_Widgets_Taskbar.reg"
            continue
        }
        {$_ -in "HideChat", "DisableChat"} {
            RegImport "> 在任務列中隱藏聊天圖示..." "Disable_Chat_Taskbar.reg"
            continue
        }
        'ShowHiddenFolders' {
            RegImport "> 取消隱藏隱藏的檔案、資料夾和驅動器..." "Show_Hidden_Folders.reg"
            continue
        }
        'ShowKnownFileExt' {
            RegImport "> 為已知檔類型啟用檔案擴展名..." "Show_Extensions_For_Known_File_Types.reg"
            continue
        }
        'HideGallery' {
            RegImport "> 從檔案資源管理器導航窗格中隱藏庫部分..." "Hide_Gallery_from_Explorer.reg"
            continue
        }
        'HideDupliDrive' {
            RegImport "> 從檔案資源管理器導航窗格中隱藏重複的可移動驅動器條目..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
            continue
        }
        {$_ -in "HideOnedrive", "DisableOnedrive"} {
            RegImport "> 從檔案資源管理器導航窗格中隱藏 onedrive 資料夾..." "Hide_Onedrive_Folder.reg"
            continue
        }
        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
            RegImport "> 從檔案資源管理器導航窗格中隱藏 3D 物件資料夾..." "Hide_3D_Objects_Folder.reg"
            continue
        }
        {$_ -in "HideMusic", "DisableMusic"} {
            RegImport "> 從檔案資源管理器導航窗格中隱藏音樂資料夾..." "Hide_Music_folder.reg"
            continue
        }
        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
            RegImport "> 在上下文功能表中隱藏「包含在庫中」..." "Disable_Include_in_library_from_context_menu.reg"
            continue
        }
        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
            RegImport "> 在上下文功能表中隱藏“授予訪問許可權”..." "Disable_Give_access_to_context_menu.reg"
            continue
        }
        {$_ -in "HideShare", "DisableShare"} {
            RegImport "> 在上下文功能表中隱藏“共用”..." "Disable_Share_from_context_menu.reg"
            continue
        }
    }

    RestartExplorer

    Write-Output ""
    Write-Output ""
    Write-Output ""
    Write-Output "腳本成功完成！"

    AwaitKeyToExit
}
