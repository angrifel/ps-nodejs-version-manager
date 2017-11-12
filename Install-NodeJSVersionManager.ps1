[string] $NodeJSRoot = 'c:\env\nodejs'
[string] $DefaultNodeJSCurrentVersion = "$NodeJSRoot\current"

function Test-PathEnvironmentVariable([string] $Path, [EnvironmentVariableTarget] $Target) {
    [string[]] $components = $path.Split(';', [StringSplitOptions]::None)
    [int] $found = -1
    while ($index -lt $components.Length) {
         if ($components[$index].StartsWith($Path, [StringComparison]::OrdinalIgnoreCase)) {
             return $true
         }
         
         $index += 1
    }

    return $false
}

[string] $nodejsCurrentDirectory = "$DefaultNodeJSCurrentVersion\$env:USERNAME"
[string] $installLocation = "$HOME\Documents\WindowsPowerShell\Modules"
[string] $uri = 'https://raw.githubusercontent.com/angrifel/ps-nodejs-version-manager/master/NodeJSVersionManager.psm1'
[string] $moduleLocation = Join-Path -Path $installLocation -ChildPath "NodeJSVersionManager"

if (-not (Test-Path -Path $moduleLocation -PathType Container)) {
    [void](New-Item -Path $moduleLocation -ItemType Directory -Force)
}

Invoke-WebRequest -Uri $uri -OutFile (Join-Path -Path $moduleLocation -ChildPath "NodeJSVersionManager.psm1")

if (-not (Test-PathEnvironmentVariable -Path $nodejsCurrentDirectory -Target User)) {
    [string] $path = [System.Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
    $path = "$nodejsCurrentDirectory;$path"
    [void][System.Environment]::SetEnvironmentVariable('PATH', $path, [EnvironmentVariableTarget]::User)
    [void][System.Environment]::SetEnvironmentVariable('ENV_NODEJS_ROOT', $NodeJSRoot, [EnvironmentVariableTarget]::User)
}