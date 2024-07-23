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
    Write-Host "Error: Win11Debloat �L�k�b�z���t�ΤW�B��Apowershell �������w������������" -ForegroundColor Red
    Write-Output ""
    Write-Output "���^����h�X..."
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
                [System.Windows.MessageBox]::Show('�L�k�z�L winget ���J�w�w�˪����ε{���M��A�Y�����ε{���i��L�k��ܦb�M�椤.','Error','Ok','Error')
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

    $form.Text = "Win11Debloat ���ε{�����"
    $form.Name = "appSelectionForm"
    $form.DataBindings.DefaultDataSourceUpdateMode = 0
    $form.ClientSize = New-Object System.Drawing.Size(400,502)
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $False

    $button1.TabIndex = 4
    $button1.Name = "saveButton"
    $button1.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $button1.UseVisualStyleBackColor = $True
    $button1.Text = "�T�{"
    $button1.Location = New-Object System.Drawing.Point(27,472)
    $button1.Size = New-Object System.Drawing.Size(75,23)
    $button1.DataBindings.DefaultDataSourceUpdateMode = 0
    $button1.add_Click($handler_saveButton_Click)

    $form.Controls.Add($button1)

    $button2.TabIndex = 5
    $button2.Name = "cancelButton"
    $button2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $button2.UseVisualStyleBackColor = $True
    $button2.Text = "����"
    $button2.Location = New-Object System.Drawing.Point(129,472)
    $button2.Size = New-Object System.Drawing.Size(75,23)
    $button2.DataBindings.DefaultDataSourceUpdateMode = 0
    $button2.add_Click($handler_cancelButton_Click)

    $form.Controls.Add($button2)

    $label.Location = New-Object System.Drawing.Point(13,5)
    $label.Size = New-Object System.Drawing.Size(400,14)
    $Label.Font = 'Microsoft Sans Serif,8'
    $label.Text = '����z�Ʊ�R�������ε{���A��������z�Ʊ�O�d�����ε{��'

    $form.Controls.Add($label)

    $loadingLabel.Location = New-Object System.Drawing.Point(16,46)
    $loadingLabel.Size = New-Object System.Drawing.Size(300,418)
    $loadingLabel.Text = '���J���ε{��...'
    $loadingLabel.BackColor = "White"
    $loadingLabel.Visible = $false

    $form.Controls.Add($loadingLabel)

    $onlyInstalledCheckBox.TabIndex = 6
    $onlyInstalledCheckBox.Location = New-Object System.Drawing.Point(230,474)
    $onlyInstalledCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $onlyInstalledCheckBox.Text = '����ܤw�w�˪�����'
    $onlyInstalledCheckBox.add_CheckedChanged($load_Apps)

    $form.Controls.Add($onlyInstalledCheckBox)

    $checkUncheckCheckBox.TabIndex = 7
    $checkUncheckCheckBox.Location = New-Object System.Drawing.Point(16,22)
    $checkUncheckCheckBox.Size = New-Object System.Drawing.Size(150,20)
    $checkUncheckCheckBox.Text = '�襤/�����������'
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

    Write-Output "> �R���w�]��ܪ����ε{��..."

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
                    Write-Host "Error: �L�k�q�L Winget ���� Microsoft Edge" -ForegroundColor Red
                    Write-Output ""

                    if ($( Read-Host -Prompt "�z�Q�j����� Edge �ܡH�����ˡI (y/n)" ) -eq 'y') {
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
    Write-Output "> �j����� Microsoft Edge..."

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
        Write-Output "�B������{��..."
        $uninstallString = $uninstallRegKey.GetValue('UninstallString') + ' --force-uninstall'
        Start-Process cmd.exe "/c $uninstallString" -WindowStyle Hidden -Wait

        Write-Output "�R���Ѿl��..."

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

        Write-Output "�M�z���U��..."

        # Remove ms edge from autostart
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run" /v "Microsoft Edge Update" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C" /f *>$null
        reg delete "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" /v "Microsoft Edge Update" /f *>$null

        Write-Output "Microsoft Edge �w����"
    }
    else {
        Write-Output ""
        Write-Host "Error: �L�k�j����� Microsoft Edge�A�䤣������{��" -ForegroundColor Red
    }

    Write-Output ""
}


# Execute provided command and strips progress spinners/bars from console output
function Strip-Progress {
    param(
        [ScriptBlock]$ScriptBlock
    )

    # Regex pattern to match spinner characters and progress bar patterns
    $progressPattern = '�F?[??]|^\s+[-\\|/]\s+$'

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
    Write-Output "> ���s�Ұ� Windows �귽�޲z����{�H���ε{���Ҧ��ܧ�...�]�o�i��|�ɭP�@�ǰ{�{�^"

    # Only restart if the powershell process matches the OS architecture
    # Restarting explorer from a 32bit Powershell window will fail on a 64bit OS
    if ([Environment]::Is64BitProcess -eq [Environment]::Is64BitOperatingSystem)
    {
        Stop-Process -processName: Explorer -Force
    }
    else {
        Write-Warning "�L�k���s�Ұ�Windows�귽�޲z���i�{�A�Ф�ʭ��s�Ұʱz��PC�H���ΩҦ����."
    }
}


# �q�u�}�l�v�\����M���Ҧ��T�w������.
# Credit: https://lazyadmin.nl/win-11/customize-windows-11-start-menu-layout/
function ClearStartMenu {
    param (
        $message,
        $applyToAllUsers = $True
    )

    Write-Output $message

    # �}�l�\���d�������|
    $startmenuTemplate = "$PSScriptRoot/Start/start2.bin"

    # Check if template bin file exists, return early if it doesn't
    if (-not (Test-Path $startmenuTemplate)) {
        Write-Host "Error: �L�k�M���}�l�\���A��Z��Ƨ����ʤ�start2.bin�ɡC" -ForegroundColor Red
        Write-Output ""
        return
    }

    if ($applyToAllUsers) {
        # ���Ҧ��ϥΪ̧R�� startmenu �T�w������
        # ����Ҧ��ϥΪ̰t�m�ɸ�Ƨ�
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
                Write-Host "Error: �L�k�M���}�l�\���A�L�k���ϥΪ̧��start2.bin��" $startmenu.Fullname.Split("\")[2]  -ForegroundColor Red
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
            Write-Output "���w�]�Τ�ЫؤF LocalState ��Ƨ�"
        }

        # Copy template to default profile
        Copy-Item -Path $startmenuTemplate -Destination $defaultProfile -Force
        Write-Output "�w�N�}�l�\���d���ƻs��w�]�ϥΪ̸�Ƨ�"
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
            # Bin �ɤ��s�b�A��ܨϥΪ̥��B�楿�T������ Windows�C�h�X�\��
            Write-Host "Error: �L�k�M���}�l�\���A�L�k���ϥΪ̧��start2.bin�� $([Environment]::UserName)" -ForegroundColor Red
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
        Write-Output "�����N��h�X..."
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
        Write-Warning "Winget ���w�˩Τw�L���C�o�i��|���� Win11Debloat �R���Y�����ε{��."
        Write-Output ""
        Write-Output "�L�צp��A�����N���~��..."
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
        Write-Host "Error: �L�k�b Sysprep �Ҧ��U�Ұ� Win11Debloat�A�b �䤣��w�]�ϥΪ̸�Ƨ� 'C:\Users\Default\'" -ForegroundColor Red
        AwaitKeyToExit
        Exit
    }
    # Exit script if run in Sysprep mode on Windows 10
    if ($WinVersion -lt 22000) {
        Write-Host "Error: Windows 10 ���䴩 Win11Debloat Sysprep �Ҧ�" -ForegroundColor Red
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
        Write-Host "���ε{���]�w���w�����A���O�s." -ForegroundColor Red
    }
    else {
        Write-Output "�z�����ο�ܤw�O�s��}���ڸ�Ƨ������uCustomAppsList�v �ɮפ�."
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
            $ModeSelectionMessage = "�п�ܤ@�ӿﶵ (1/2/3/0)"

            PrintHeader '�\���'

            Write-Output "(1) �w�]�Ҧ��G���ιw�]�]�m"
            Write-Output "(2) �ۭq�Ҧ��G�ھڱz���ݭn�ק�}��"
            Write-Output "(3) ���ε{���R���Ҧ��G��ܨçR�����ε{���A�Ӥ��i���L���"

            # Only show this option if SavedSettings file exists
            if (Test-Path "$PSScriptRoot/SavedSettings") {
                Write-Output "(4) ���ΤW���O�s���۩w�q�]�m"

                $ModeSelectionMessage = "�п�ܤ@�ӿﶵ (1/2/3/4/0)"
            }

            Write-Output ""
            Write-Output "(0) ��ܧ�h��T"
            Write-Output ""
            Write-Output ""

            $Mode = Read-Host $ModeSelectionMessage

            # Show information based on user input, Suppress user prompt if Silent parameter was passed
            if ($Mode -eq '0') {
                # Get & print script information from file
                PrintFromFile "$PSScriptRoot/Menus/Info"

                Write-Output ""
                Write-Output "�����N���^..."
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
                Write-Output "���^�������}���A�Ϋ� CTRL+C �h�X..."
                Read-Host | Out-Null
            }

            $DefaultParameterNames = 'RemoveApps','DisableTelemetry','DisableBing','DisableLockscreenTips','DisableSuggestions','ShowKnownFileExt','DisableWidgets','HideChat','DisableCopilot'

            PrintHeader '�w�]�Ҧ�'

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

            PrintHeader '�ۭq�Ҧ�'

            # Show options for removing apps, only continue on valid input
            Do {
                Write-Host "�ﶵ�G" -ForegroundColor Yellow
                Write-Host " (n) �ФŲ�����������" -ForegroundColor Yellow
                Write-Host " (1) �ȱq�uAppslist.txt�v���R���^��C����D�n�����Ϊ��w�]���" -ForegroundColor Yellow
                Write-Host " (2) �R���w�]��ܪ��^��C��������ε{���A�H�ζl��M������ε{���A�}�o�H�����ε{���M�C�����ε{��"  -ForegroundColor Yellow
                Write-Host " (3) ��ܭn�R�������ΥH�έn�O�d������" -ForegroundColor Yellow
                $RemoveAppsInput = Read-Host "�R������w�w�˪����ε{���H (n/1/2/3)"

                # Show app selection form if user entered option 3
                if ($RemoveAppsInput -eq '3') {
                    $result = ShowAppSelectionForm

                    if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
                        # User cancelled or closed app selection, show error and change RemoveAppsInput so the menu will be shown again
                        Write-Output ""
                        Write-Host "�w�������ε{����ܡA�Э���" -ForegroundColor Red

                        $RemoveAppsInput = 'c'
                    }

                    Write-Output ""
                }
            }
            while ($RemoveAppsInput -ne 'n' -and $RemoveAppsInput -ne '0' -and $RemoveAppsInput -ne '1' -and $RemoveAppsInput -ne '2' -and $RemoveAppsInput -ne '3')

            # Select correct option based on user input
            switch ($RemoveAppsInput) {
                '1' {
                    AddParameter 'RemoveApps' '�R���^��C����ɳn�����Ϊ��w�]���'
                }
                '2' {
                    AddParameter 'RemoveApps' '�R���^��C����ɳn�����Ϊ��w�]���'
                    AddParameter 'RemoveCommApps' '�����u�l��v�B�u���v�M�u�H�ߡv����'
                    AddParameter 'RemoveW11Outlook' '�R���s�� Outlook for Windows ����'
                    AddParameter 'RemoveDevApps' '�����P�}�o�̬���������'
                    AddParameter 'RemoveGamingApps' '�R�� Xbox ���ΩM Xbox Gamebar'
                    AddParameter 'DisableDVR' '�T�� Xbox �C��/�ù����s'
                }
                '3' {
                    Write-Output "You have selected $($global:SelectedApps.Count) apps for removal"

                    AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"

                    Write-Output ""

                    if ($( Read-Host -Prompt "�T��Xbox�C��/�ù����s�H�ٷ|����C���|�[�u�X���� �]y/n�^" ) -eq 'y') {
                        AddParameter 'DisableDVR' '�T�� Xbox �C��/�ù����s'
                    }
                }
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($global:Params.ContainsKey("Sysprep")) {
                    if ($( Read-Host -Prompt "�q�Ҧ��{���ϥΪ̩M�s�Τ᪺�}�l�\����R���Ҧ��T�w�����ΡH�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'ClearStartAllUsers' '�q�{���ϥΪ̩M�s�ϥΪ̪��u�}�l�v�\����R���Ҧ��T�w������'
                    }
                }
                else {
                    Do {
                        Write-Host "�ﶵ�G" -ForegroundColor Yellow
                        Write-Host " (n) ���n�q�u�}�l�v�\����R������T�w������" -ForegroundColor Yellow
                        Write-Host " (1) �ȱq�u�}�l�v�\����R�����ϥΪ̪��Ҧ��T�w���� ($([Environment]::UserName))" -ForegroundColor Yellow
                        Write-Host " (2) �q�Ҧ��{���ϥΪ̩M�s�ϥΪ̪��u�}�l�v�\����R���Ҧ��T�w������"  -ForegroundColor Yellow
                        $ClearStartInput = Read-Host "�q�}�l�\����R���Ҧ��T�w�����ε{���H�o�L�k��_ (n/1/2)"
                    }
                    while ($ClearStartInput -ne 'n' -and $ClearStartInput -ne '0' -and $ClearStartInput -ne '1' -and $ClearStartInput -ne '2')

                    # Select correct option based on user input
                    switch ($ClearStartInput) {
                        '1' {
                            AddParameter 'ClearStart' "�ȱq�u�}�l�v�\����R�����ϥΪ̪��Ҧ��T�w����"
                        }
                        '2' {
                            AddParameter 'ClearStartAllUsers' "�q�Ҧ��{���ϥΪ̩M�s�ϥΪ̪��u�}�l�v�\����R���Ҧ��T�w������"
                        }
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "�T�λ����B�E�_�ƾڡB���ʾ��v�O���B���αҰʸ��ܩM�w�V�s�i�H(y/n)" ) -eq 'y') {
                AddParameter 'DisableTelemetry' '�T�λ����B�E�_�ƾڡB���ʾ��v�O���B���αҰʸ��ܩM�w�V�s�i'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "�b�}�l�B�]�m�B�q���B�귽�޲z���M��̤��T�δ��ܡB�ޥ��B��ĳ�M�s�i�H (y/n)" ) -eq 'y') {
                AddParameter 'DisableSuggestions' '�b�}�l�B�]�m�B�q���M���귽�޲z�����T�δ��ܡB�ޥ��B��ĳ�M�s�i'
                AddParameter 'DisableLockscreenTips' '�b��̤W�T�δ��ܩM�ޥ�'
            }

            Write-Output ""

            if ($( Read-Host -Prompt "�bWindows�j�����T�ΩM�R��bing web�j���Abing AI�Mcortana�H�]�O/�_�^" ) -eq 'y') {
                AddParameter 'DisableBing' '�bWindows�j�����T�ΩM�R��bing web�j���Abing AI�MCortana'
            }

            # Only show this option for Windows 11 users running build 22621 or later
            if ($WinVersion -ge 22621){
                Write-Output ""

                if ($( Read-Host -Prompt "�T�� Windows Copilot�H�o�A�Ω�Ҧ��ϥΪ� �]y/n�^" ) -eq 'y') {
                    AddParameter 'DisableCopilot' '�T�� Windows �ƾr�p'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "�T�� Windows Recall �ַӡH�o�A�Ω�Ҧ��ϥΪ� �]y/n�^" ) -eq 'y') {
                    AddParameter 'DisableRecall' '�T�� Windows Recall �ַ�'
                }
            }

            # Only show this option for Windows 11 users running build 22000 or later
            if ($WinVersion -ge 22000){
                Write-Output ""

                if ($( Read-Host -Prompt "��_�ª� Windows 10 �˦��W�U��\���H�]�O/�_�^" ) -eq 'y') {
                    AddParameter 'RevertContextMenu' '��_�ª� Windows 10 �˦��W�U��\���'
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "�O�_�n����ȦC�M�����A�ȶi�������H�]�O/�_�^" ) -eq 'y') {
                # Only show these specific options for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   �N���ȦC���s�P��������H�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'TaskbarAlignLeft' '�N���ȦC�ϥܦV�����'
                    }

                    # �b���ȦC�W��ܷj���ϥܪ��ﶵ�A�Ȧb���Ŀ�J���~��
                    Do {
                        Write-Output ""
                        Write-Host "   �ﶵ�G" -ForegroundColor Yellow
                        Write-Host "    (n) No change" -ForegroundColor Yellow
                        Write-Host "    (1) ���å��ȦC�����j���ϥ�" -ForegroundColor Yellow
                        Write-Host "    (2) �b���ȦC�W��ܷj�M�ϥ�" -ForegroundColor Yellow
                        Write-Host "    (3) �b���ȦC�W��ܱa�����Ҫ��j���ϥ�" -ForegroundColor Yellow
                        Write-Host "    (4) �b���ȦC�W��ܷj����" -ForegroundColor Yellow
                        $TbSearchInput = Read-Host "   ���éΧ��u�@�C�W���j�M�ϥܡH (n/1/2/3/4)"
                    }
                    while ($TbSearchInput -ne 'n' -and $TbSearchInput -ne '0' -and $TbSearchInput -ne '1' -and $TbSearchInput -ne '2' -and $TbSearchInput -ne '3' -and $TbSearchInput -ne '4')

                    # Select correct taskbar search option based on user input
                    switch ($TbSearchInput) {
                        '1' {
                            AddParameter 'HideSearchTb' '���å��ȦC�����j���ϥ�'
                        }
                        '2' {
                            AddParameter 'ShowSearchIconTb' '�b���ȦC�W��ܷj�M�ϥ�'
                        }
                        '3' {
                            AddParameter 'ShowSearchLabelTb' '�b���ȦC�W��ܱa�����Ҫ��j���ϥ�'
                        }
                        '4' {
                            AddParameter 'ShowSearchBoxTb' '�b���ȦC�W��ܷj����'
                        }
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   �q���ȦC�����å����˵����s�H�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'HideTaskview' '�q���ȦC�����å����˵����s'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   �T�Τp����A�Ȩñq�����椤���ùϥܡH�]�O/�_�^" ) -eq 'y') {
                    AddParameter 'DisableWidgets' '�T�Τp����A�Ȩñq�����椤���äp����]�s�D�M����^�ϥ�'
                }

                # Only show this options for Windows users running build 22621 or earlier
                if ($WinVersion -le 22621){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   �q���ȦC�����ò�ѡ]�ߧY�}�|�^�ϥܡH�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'HideChat' '�b���ȦC�����ò�ѡ]�ߧY�}�|�^�ϥ�'
                    }
                }
            }

            Write-Output ""

            if ($( Read-Host -Prompt "�O�_�n���ɮ׸귽�޲z���i�������H�]�O/�_�^" ) -eq 'y') {
                Write-Output ""

                if ($( Read-Host -Prompt "   ������ê��ɮסB��Ƨ��M�X�ʾ��H�]�O/�_�^" ) -eq 'y') {
                    AddParameter 'ShowHiddenFolders' '������ê��ɮסB��Ƨ��M�X�ʾ�'
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   ��ܤw�������������X�i�W�H�]�O/�_�^" ) -eq 'y') {
                    AddParameter 'ShowKnownFileExt' '��ܤw�������������X�i�W'
                }

                # Only show this option for Windows 11 users running build 22000 or later
                if ($WinVersion -ge 22000){
                    Write-Output ""

                    if ($( Read-Host -Prompt "   �q�ɮ׸귽�޲z�������O�����îw�����H�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'HideGallery' '�q�ɮ׸귽�޲z�������O�����îw����'
                    }
                }

                Write-Output ""

                if ($( Read-Host -Prompt "   �b�ɮ׸귽�޲z�������O�����í��ƪ��i�����X�ʾ����ءA�H�K���̶���ܦb�u���q���v�U�H�]�O/�_�^" ) -eq 'y') {
                    AddParameter 'HideDupliDrive' '�b�ɮ׸귽�޲z�������O�����í��ƪ��i�����X�ʾ�����'
                }

                # Only show option for disabling these specific folders for Windows 10 users
                if (get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'"){
                    Write-Output ""

                    if ($( Read-Host -Prompt "�O�_�n�q�ɮ׸귽�޲z�������O�����å����Ƨ��H�]�O/�_�^" ) -eq 'y') {
                        Write-Output ""

                        if ($( Read-Host -Prompt "   �q�ɮ׸귽�޲z�������O������ onedrive ��Ƨ��H�]�O/�_�^" ) -eq 'y') {
                            AddParameter 'HideOnedrive' '�b�ɮ׸귽�޲z�������O������ onedrive ��Ƨ�'
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   �q�ɮ׸귽�޲z�������O������ 3D �����Ƨ��H�]�O/�_�^" ) -eq 'y') {
                            AddParameter 'Hide3dObjects' "�b�ɮ׸귽�޲z�������u�o�x�q���v�U���� 3D �����Ƨ�"
                        }

                        Write-Output ""

                        if ($( Read-Host -Prompt "   �q�ɮ׸귽�޲z�������O�����í��ָ�Ƨ��H�]�O/�_�^" ) -eq 'y') {
                            AddParameter 'HideMusic' "�b�ɮ׸귽�޲z�������u�o�x�q���v�U���í��ָ�Ƨ�"
                        }
                    }
                }
            }

            # Only show option for disabling context menu items for Windows 10 users or if the user opted to restore the Windows 10 context menu
            if ((get-ciminstance -query "select caption from win32_operatingsystem where caption like '%Windows 10%'") -or $global:Params.ContainsKey('RevertContextMenu')){
                Write-Output ""

                if ($( Read-Host -Prompt "�O�_�n�T�Υ���W�U��\���ﶵ�H�]�O/�_�^" ) -eq 'y') {
                    Write-Output ""

                    if ($( Read-Host -Prompt "   �b�W�U��\������áu�]�t�b�w���v�ﶵ�H�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'HideIncludeInLibrary' "���äW�U��\������u�]�t�b�w���v �ﶵ"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   �b�W�U��\������áu�¤��X�ݳ\�i�v�v�ﶵ�H�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'HideGiveAccessTo' "���äW�U��\������u�¤��X�ݳ\�i�v�v �ﶵ"
                    }

                    Write-Output ""

                    if ($( Read-Host -Prompt "   �b�W�U��\������áu�@�ɡv�ﶵ�H�]�O/�_�^" ) -eq 'y') {
                        AddParameter 'HideShare' "���äW�U��\������u�@�Ρv�ﶵ"
                    }
                }
            }

            # Suppress prompt if Silent parameter was passed
            if (-not $Silent) {
                Write-Output ""
                Write-Output ""
                Write-Output ""
                Write-Output "���^����T�{�z����ܨð���}���A�Ϋ� CTRL+C �h�X..."
                Read-Host | Out-Null
            }

            PrintHeader 'Custom Mode'
        }

        # App removal, remove apps based on user selection
        '3' {
            PrintHeader "���β���"

            $result = ShowAppSelectionForm

            if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
                Write-Output "You have selected $($global:SelectedApps.Count) apps for removal"
                AddParameter 'RemoveAppsCustom' "Remove $($global:SelectedApps.Count) apps:"

                # Suppress prompt if Silent parameter was passed
                if (-not $Silent) {
                    Write-Output ""
                    Write-Output "�� Enter ��R���ҿ����ΡA�Ϋ� CTRL+C ��h�X..."
                    Read-Host | Out-Null
                    PrintHeader "���β���"
                }
            }
            else {
                Write-Host "��ܤw�����A���R���������ε{���I" -ForegroundColor Red
                Write-Output ""
            }
        }

        # Load custom options selection from the "SavedSettings" file
        '4' {
            if (-not $Silent) {
                PrintHeader '�ۭq�Ҧ�'
                Write-Output "Win11Debloat �N�i��H�U���G"

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
                                Write-Host "Error: �L�k�q�ɮ׸��J�۩w�q���ε{���M��A���|�R���������ε{���I" -ForegroundColor Red
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
                Write-Output "���^�������}���A�Ϋ� CTRL+C �h�X..."
                Read-Host | Out-Null
            }

            PrintHeader '�ۭq�Ҧ�'
        }
    }
}
else {
    PrintHeader '�ۭq�Ҧ�'
}


# If the number of keys in SPParams equals the number of keys in Params then no modifications/changes were selected
#  or added by the user, and the script can exit without making any changes.
if ($SPParamCount -eq $global:Params.Keys.Count) {
    Write-Output "�}���b���i������諸���p�U����."

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
                Write-Host "> �L�k�q�ɮ׸��J�ۭq���ε{���M��A���R���������ε{���I" -ForegroundColor Red
            }

            Write-Output ""
            continue
        }
        'RemoveCommApps' {
            Write-Output "> �����u�l��v�B�u���v�M�u�H�ߡv����..."

            $appsList = 'Microsoft.windowscommunicationsapps', 'Microsoft.People'
            RemoveApps $appsList

            Write-Output ""
            continue
        }
        'RemoveW11Outlook' {
            Write-Output "> �R���s�� Outlook for Windows ����..."

            $appsList = 'Microsoft.OutlookForWindows'
            RemoveApps $appsList

            Write-Output ""
            continue
        }
        'RemoveDevApps' {
            Write-Output "> �����P�}�o�̬���������..."

            $appsList = 'Microsoft.PowerAutomateDesktop', 'Microsoft.RemoteDesktop', 'Windows.DevHome'
            RemoveApps $appsList

            Write-Output ""

            continue
        }
        'RemoveGamingApps' {
            Write-Output "> �R���P�C�����������ε{��..."

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
            RegImport "> �T�� Xbox �C��/�ù����s..." "Disable_DVR.reg"
            continue
        }
        'ClearStart' {
            ClearStartMenu "> �q�u�}�l�v�\����R���Ҧ��T�w������..." $False
            continue
        }
        'ClearStartAllUsers' {
            ClearStartMenu "> �q�Ҧ��ϥΪ̪��u�}�l�v�\����R���Ҧ��T�w������..."
            continue
        }
        'DisableTelemetry' {
            RegImport "> �T�λ����B�E�_�ƾڡB���ʾ��v�O���B���αҰʸ��ܩM�w�V�s�i..." "Disable_Telemetry.reg"
            continue
        }
        {$_ -in "DisableBingSearches", "DisableBing"} {
            RegImport "> �b Windows �j�M���T�� bing web �j���Bbing AI �M cortana..." "Disable_Bing_Cortana_In_Search.reg"

            # Also remove the app package for bing search
            $appsList = 'Microsoft.BingSearch'
            RemoveApps $appsList

            Write-Output ""

            continue
        }
        {$_ -in "DisableLockscrTips", "DisableLockscreenTips"} {
            RegImport "> �b��̤W�T�δ��ܩM�ޥ�..." "Disable_Lockscreen_Tips.reg"
            continue
        }
        {$_ -in "DisableSuggestions", "DisableWindowsSuggestions"} {
            RegImport "> �b Windows ���T�δ��ܡB�ޥ��B��ĳ�M�s�i..." "Disable_Windows_Suggestions.reg"
            continue
        }
        'RevertContextMenu' {
            RegImport "> ��_�ª� Windows 10 �˦��W�U��\���..." "Disable_Show_More_Options_Context_Menu.reg"
            continue
        }
        'TaskbarAlignLeft' {
            RegImport "> �N���ȦC���s�V�����..." "Align_Taskbar_Left.reg"

            continue
        }
        'HideSearchTb' {
            RegImport "> ���å��ȦC�����j���ϥ�..." "Hide_Search_Taskbar.reg"
            continue
        }
        'ShowSearchIconTb' {
            RegImport "> �N���ȦC�j����אּ�ȹϥ�..." "Show_Search_Icon.reg"
            continue
        }
        'ShowSearchLabelTb' {
            RegImport "> �N���ȦC�j����אּ�a���Ҫ��ϥ�..." "Show_Search_Icon_And_Label.reg"
            continue
        }
        'ShowSearchBoxTb' {
            RegImport "> �N���ȦC�j����אּ�j����..." "Show_Search_Box.reg"
            continue
        }
        'HideTaskview' {
            RegImport "> �b�����椤���� taskview ���s..." "Hide_Taskview_Taskbar.reg"
            continue
        }
        'DisableCopilot' {
            RegImport "> �T�� Windows �ƾr�p..." "Disable_Copilot.reg"
            continue
        }
        'DisableRecall' {
            RegImport "> �T�� Windows Recall �ַ�..." "Disable_AI_Recall.reg"
            continue
        }
        {$_ -in "HideWidgets", "DisableWidgets"} {
            RegImport "> �T�Τp�ե�A�Ȩñq�����椤���äp�ե�ϥ�..." "Disable_Widgets_Taskbar.reg"
            continue
        }
        {$_ -in "HideChat", "DisableChat"} {
            RegImport "> �b���ȦC�����ò�ѹϥ�..." "Disable_Chat_Taskbar.reg"
            continue
        }
        'ShowHiddenFolders' {
            RegImport "> �����������ê��ɮסB��Ƨ��M�X�ʾ�..." "Show_Hidden_Folders.reg"
            continue
        }
        'ShowKnownFileExt' {
            RegImport "> ���w���������ҥ��ɮ��X�i�W..." "Show_Extensions_For_Known_File_Types.reg"
            continue
        }
        'HideGallery' {
            RegImport "> �q�ɮ׸귽�޲z���ɯ赡�椤���îw����..." "Hide_Gallery_from_Explorer.reg"
            continue
        }
        'HideDupliDrive' {
            RegImport "> �q�ɮ׸귽�޲z���ɯ赡�椤���í��ƪ��i�����X�ʾ�����..." "Hide_duplicate_removable_drives_from_navigation_pane_of_File_Explorer.reg"
            continue
        }
        {$_ -in "HideOnedrive", "DisableOnedrive"} {
            RegImport "> �q�ɮ׸귽�޲z���ɯ赡�椤���� onedrive ��Ƨ�..." "Hide_Onedrive_Folder.reg"
            continue
        }
        {$_ -in "Hide3dObjects", "Disable3dObjects"} {
            RegImport "> �q�ɮ׸귽�޲z���ɯ赡�椤���� 3D �����Ƨ�..." "Hide_3D_Objects_Folder.reg"
            continue
        }
        {$_ -in "HideMusic", "DisableMusic"} {
            RegImport "> �q�ɮ׸귽�޲z���ɯ赡�椤���í��ָ�Ƨ�..." "Hide_Music_folder.reg"
            continue
        }
        {$_ -in "HideIncludeInLibrary", "DisableIncludeInLibrary"} {
            RegImport "> �b�W�U��\������áu�]�t�b�w���v..." "Disable_Include_in_library_from_context_menu.reg"
            continue
        }
        {$_ -in "HideGiveAccessTo", "DisableGiveAccessTo"} {
            RegImport "> �b�W�U��\������á��¤��X�ݳ\�i�v��..." "Disable_Give_access_to_context_menu.reg"
            continue
        }
        {$_ -in "HideShare", "DisableShare"} {
            RegImport "> �b�W�U��\������á��@�Ρ�..." "Disable_Share_from_context_menu.reg"
            continue
        }
    }

    RestartExplorer

    Write-Output ""
    Write-Output ""
    Write-Output ""
    Write-Output "�}�����\�����I"

    AwaitKeyToExit
}
