Param (
  [string]$Username,
  [string]$Password,
  [string]$Package,
  #Versioned is optional and will default to false if you're not trying for a specific version.
  [switch]$Versioned = $false,
  [switch]$RequirementsFile = $false
)
# param must be the first line of the script to work
 
# Load the system web assembly to do URL encoding
Add-Type -AssemblyName System.Web
 
 
function loop-till-success () {
    $propy="C:\PROGRA~1\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\python.exe"
    Set-Alias -Name propy -Value "C:\PROGRA~1\ArcGIS\Pro\bin\Python\envs\arcgispro-py3\python.exe"
    if (-not (Test-Path -Path $propy)) {
        Write-Host "Propy3 executable not found, is ArcGIS Pro installed?"
    }
    $password_encoded=[System.Web.HttpUtility]::UrlEncode($Password)
    $proxy_string1 = -join("http://", $Username, ":", $password_encoded, "@proxy.com:8080")
    $proxy_string2 = -join("http://", $Username, ":", $password_encoded, "@proxy.com:8080")
 
    if ($Versioned) {
        $string_of_command1="propy -m pip install --proxy=$proxy_string1 --retries=1 --timeout=5 --disable-pip-version-check -I $Package"
        $string_of_command2="propy -m pip install --proxy=$proxy_string2 --retries=1 --timeout=5 --disable-pip-version-check -I $Package"
    }
    elseif ($RequirementsFile) {
        $string_of_command1="propy -m pip install --proxy=$proxy_string1 --retries=1 --timeout=5 --disable-pip-version-check -r ./requirements.txt"
        $string_of_command2="propy -m pip install --proxy=$proxy_string2 --retries=1 --timeout=5 --disable-pip-version-check -r ./requirements.txt"
    }
    elseif ( -not($Versioned) ) {
        $string_of_command1="propy -m pip install --proxy=$proxy_string1 --retries=1 --timeout=5 --disable-pip-version-check $Package"
        $string_of_command2="propy -m pip install --proxy=$proxy_string2 --retries=1 --timeout=5 --disable-pip-version-check $Package"
 
    }
 
    $success=0
    while ( $success -eq 0 ) {
        Write-Host "Running command $string_of_command1"
        
        if ($Versioned) { propy -m pip install --proxy=$proxy_string1 --retries=1 --timeout=5 --disable-pip-version-check -I $Package }
        elseif ($RequirementsFile) { propy -m pip install --proxy=$proxy_string1 --retries=1 --timeout=5 --disable-pip-version-check -r ./requirements.txt }
        elseif ( -not($Versioned) ) { propy -m pip install --proxy=$proxy_string1 --retries=1 --timeout=5 --disable-pip-version-check $Package }
 
        if ($?) { $success=1 }
        else {
            Write-Host "Running command $string_of_command2"

            if ($Versioned) { propy -m pip install --proxy=$proxy_string2 --retries=1 --timeout=5 --disable-pip-version-check -I $Package }
            elseif ($RequirementsFile) { propy -m pip install --proxy=$proxy_string2 --retries=1 --timeout=5 --disable-pip-version-check -r ./requirements.txt }
            elseif ( -not($Versioned) ) { propy -m pip install --proxy=$proxy_string2 --retries=1 --timeout=5 --disable-pip-version-check $Package }
 
            if ($?) { $success=1 }
            }
     }
}
loop-till-success
