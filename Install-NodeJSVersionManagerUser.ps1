[string] $installLocation = "$HOME\Documents\WindowsPowerShell\Modules"
[string] $uri = 'https://raw.githubusercontent.com/angrifel/ps-nodejs-version-manager/master/NodeJSVersionManager.psm1'
[string] $moduleLocation = Join-Path -Path $installLocation -ChildPath "NodeJSVersionManager"

if (-not (Test-Path -Path $moduleLocation -PathType Container)) {
    [void](New-Item -Path $moduleLocation -ItemType Directory -Force)
}

Invoke-WebRequest -Uri $uri -OutFile (Join-Path -Path $moduleLocation -ChildPath "NodeJSVersionManager.psm1")
