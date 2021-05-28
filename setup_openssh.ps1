#Requires -RunAsAdministrator
# setup_openssh.ps1
# Documentation on openssh for windows: https://github.com/PowerShell/Win32-OpenSSH/wiki/OpenSSH-utility-scripts-to-fix-file-permissions
# Docs on the repair scripts: https://github.com/PowerShell/Win32-OpenSSH/wiki/OpenSSH-utility-scripts-to-fix-file-permissions
param (
    [switch]$use_proxy
)

# Stop if anything fails, default value is "Continue"
$ErrorActionPreference = "Stop"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if ( $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -eq $false )
{
    Write-Host "This script requires administrative privileges, please rerun in an administrative window."
    Exit 1
}

if ( [System.Environment]::OSVersion.Version.Major -lt 10 )
{
    Write-Host "Windows version must be 10 or greater for this script to run!"    
}

if ($use_proxy -eq $true) {
    if ($ENV:HTTP_PROXY -eq $null -or $ENV:HTTPS_PROXY -eq $null)
    {
    	Write-Host "Please declare your proxy env strings! See: https://phila.city/pages/viewpage.action?pageId=22151443"
    	Exit 1
    }
}


# Nothing I do to download via the proxy works in powershell. The city is crippled by the proxy.
# Download the installer yourself.
#$password = Read-Host -Prompt 'Input your AD password'

#$source = "https://chocolatey.org/install.ps1'"
#$dest = "~/chocolatey-install.ps1"
#$WebClient = New-Object System.Net.WebClient
#$WebProxy = New-Object System.Net.WebProxy("http://proxy.phila.gov:8080",$true)
#$Credentials = New-Object Net.NetworkCredential("roland.macdavid",$password,"domain.local")
#$Credentials = $Credentials.GetCredential("http://proxy.phila.gov","8080", "KERBEROS");
#$WebProxy.Credentials = $Credentials
#$WebClient.Proxy = $WebProxy
#$WebClient.DownloadFile($source,$dest)

#Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# Test to see if this fails.
$(Get-Command choco.exe).Name
if($? -eq $false) {
	Write-Host "Choco is not installed!"
	Exit 1
}

# Disable confirmations
choco feature enable -n=allowGlobalConfirmation

choco install openssh
# This installs .NET 4.8
choco install dotnetfx

refreshenv

cd C:\PROGRA~1\OpenSSH-Win64
./install-sshd.ps1

# Host keys are stored here:
if ( -Not $(Test-Path C:\ProgramData\ssh) )
{
    Write-Host "Populating host keys in C:\ProgramData\ssh.."
    mkdir C:\ProgramData\ssh
    cd C:\ProgramData\ssh
    C:\PROGRA~1\OpenSSH-Win64\ssh-keygen.exe -A
    C:\PROGRA~1\OpenSSH-Win64\ssh-add.exe C:\ProgramData\ssh\ssh_host_ed25519_key
}

Write-Host "Configuring SSH configs.."
cd C:\PROGRA~1\OpenSSH-Win64
cp .\OpenSSHUtils.psm1 C:\Windows\System32\WindowsPowerShell\v1.0\Modules\
Import-Module C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OpenSSHUtils.psm1
Repair-SshdHostKeyPermission -FilePath C:\ProgramData\ssh\ssh_host_ed25519_key -Confirm:$false

./FixHostFilePermissions.ps1 -Confirm:$false

# You'll need to make your own sshd_config and service. There is no sshd_config by default, and the existing sshd service doesn't reference a config file.
# See my customized options below
if ( -Not $(Test-Path C:\PROGRA~1\OpenSSH-Win64\sshd_config) )
{
    cp sshd_config_default sshd_config
    Repair-SshdConfigPermission -filepath C:\PROGRA~1\OpenSSH-Win64\sshd_config -Confirm:$false
    # Find the passwordauth line and disable it
    $line = Get-Content C:\PROGRA~1\OpenSSH-Win64\sshd_config | Select-String "PasswordAuthentication" | Select-Object -ExpandProperty Line
    $content = Get-Content C:\PROGRA~1\OpenSSH-Win64\sshd_config
    $content | ForEach-Object {$_ -replace $line,"PasswordAuthencation no"} | Set-Content C:\PROGRA~1\OpenSSH-Win64\sshd_config
}

#We're logging in as gisscripts, which is an adminstrative user
# so opensshd will use this file:  __PROGRAMDATA__/ssh/administrators_authorized_keys
# So place your public key in there, then you must fix permissions otherwise it'll still refuse to use it. Do these commands:
#Import-Module C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OpenSSHUtils.psm1
#Repair-SshdConfigPermission -filepath C:\programdata\ssh\administrators_authorized_keys -Confirm:$false

# Can also add in an " -E C:\ProgramData\ssh\logs\sshd.log" to get logs, remember to remove it after.
# To remove a service, you must do it from an admin cmd.exe, "sc delete openssh_custom"
Write-Host "Creating SSH service config and starting.."
try {
    $(Get-service opensshd_custom).Name
}
catch {
    New-Service -Name "opensshd_custom" -BinaryPathName "C:\PROGRA~1\OpenSSH-Win64\sshd.exe -f C:\PROGRA~1\OpenSSH-Win64\sshd_config"
}

Start-Service opensshd_custom
Set-Service –Name opensshd_custom –StartupType "Automatic" 
Start-service ssh-agent

Get-service ssh*

New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Service sshd -Enabled True -Direction Inbound -Protocol TCP -Action Allow -Profile Domain

Write-Host "OpenSSH installed! Please place your public key for your administrative user here: C:\ProgramData\ssh\administrators_authorized_keys"
Write-Host "Once you've done that, properly set permissions by running: 'Repair-SshdConfigPermission -filepath C:\programdata\ssh\administrators_authorized_keys' -Confirm:$false"
# Reenable choco confirmations
choco feature disable -n=allowGlobalConfirmation
cd ~
