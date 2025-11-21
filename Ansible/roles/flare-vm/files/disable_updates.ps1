Start-Transcript -path C:\ludus\disable-updates-log.txt -append
$ErrorActionPreference = "SilentlyContinue"

# Stop the service and disable it
Stop-Service -Name wuauserv
Set-Service -Name wuauserv -StartupType Disabled

# Notify before download
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUOptions" -Value 2 -Type DWord -Force

# Turn the whole thing off
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate" -Name "DisableWindowsUpdateAccess" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoUpdate" -Value 1 -Type DWord -Force

# Disable the update prompt scheduled tasks
try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker_Display" -ErrorAction SilentlyContinue | Disable-ScheduledTask
} catch {
    Write-Host "No task \Microsoft\Windows\UpdateOrchestrator\USO_UxBroker_Display"
}
try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\UpdateOrchestrator\MusUx_UpdateInterval" -ErrorAction SilentlyContinue | Disable-ScheduledTask
} catch {
    Write-Host "No task \Microsoft\Windows\UpdateOrchestrator\MusUx_UpdateInterval"
}
try {
    Get-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\sih" -ErrorAction SilentlyContinue | Disable-ScheduledTask
} catch {
    Write-Host "No task \Microsoft\Windows\WindowsUpdate\sih"
}
