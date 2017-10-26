[string] $SourcesRoot = 'https://nodejs.org/dist'
[string[]] $SupportedArchitectures = @('x86', 'x64')

function Set-NodeJSVersion(
    [Parameter(Mandatory=$true)] [string] $Version, 
    [Parameter(Mandatory=$true)] [string] $Architecture) {
    [string] $nodeVersionDirectory = Get-NodeJSVersionDirectory $Version $Architecture
    if (-not (Test-Path -Path $nodeVersionDirectory -PathType Container)) {
        throw "nodejs version not found at $nodeVersionDirectory"
    }

    SetPathEnvironmentToNodeVersion $nodeVersionDirectory
}

function Get-NodeJSVersionDirectory(
    [Parameter(Mandatory=$true)] [string] $Version, 
    [Parameter(Mandatory=$true)] [string] $Architecture) {
    [string] $root = Get-NodeJSDistributionDirectory
    [string] $nodeVersionDirectory = "$root\node-v$Version-win-$Architecture"
    return  $nodeVersionDirectory
}

function Get-NodeJSDistributionDirectory {
    return "c:\env\nodejs\dist"
}

function Get-NodeJSVersionIdentifier([string] $Version, [string] $Architecture) {
    return "node-v$Version-win-$Architecture"
}

function Get-NodeJSVersionSource([string] $Version, [string] $Architecture) {
    [string] $fileName = "$(Get-NodeJSVersionIdentifier $Version $Architecture).zip"
    return "$SourcesRoot/v$Version/$fileName"
}

function Test-NodeJSVersionExists([string] $Version, [string] $Architecture) {
    [int] $statusCode
    try { 
        $statusCode = (Invoke-WebRequest -Uri (Get-NodeJSVersionSource $Version $Architecture) -Method 'Head').StatusCode
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.Value
    }

    return $statusCode -eq 200
}

function Get-NodeJSAvailableVersion() {
    $versions = (Invoke-WebRequest -Uri $SourcesRoot).Links | `
                 Where-Object { $_.href -match '^v[0-9]+\.[0-9]+\.[0-9]+\/$' } | `
                 Where-Object { $_.href -notmatch '^v0.[0-9]+\.[0-9]+\/$' } | ` # this version is known to not contain any version of windows zipped
                 ForEach-Object { $_.href.Substring(1, $_.href.Length - 2) }
    
                            
    [System.Collections.ArrayList] $versionsWithArchitectures = New-Object System.Collections.ArrayList
    foreach ($version in $versions) {
        foreach ($arch in $SupportedArchitectures) {
            [void]($versionsWithArchitectures.Add(@{ Version = $version; Architecture = $arch }))
        }
    }

    return $versionsWithArchitectures  | `
            Where-Object { (Test-NodeJSVersionExists $_.Version $_.Architecture) -eq $true } | `
            ForEach-Object { (Get-NodeJSVersionIdentifier $_.Version $_.Architecture) }
}

function Get-NodeJSInstalledVersion {
    [string] $root = Get-NodeJSDistributionDirectory
    return Get-ChildItem -Path $Root | ForEach-Object {$_.Name}
}

<#
.SYNOPSIS
Installs NodeJS

.DESCRIPTION
The Install-NodeJS cmdlet downloads a specific NodeJS version from nodejs.org and unzips it
at the nodejs root location.

.PARAMETER Version
The version of nodejs to install, example 8.2.1

.PARAMETER Architecture
The architectecture to install, it can be x86 o x64
#>
function Install-NodeJS(
    [Parameter(Mandatory=$true)] [string] $Version,
    [Parameter(Mandatory=$true)] [string] $Architecture) {
    if (Test-Path -Path (Get-NodeJSVersionDirectory $Version $Architecture) -PathType Container) {
        Write-Host 'Already installed'
        return
    }

    [string] $fileName = "node-v$Version-win-$Architecture.zip"
    [string] $tempDownloadDirectory = [System.IO.Path]::GetTempPath() + "\" + [System.IO.Path]::GetRandomFileName()
    [string] $source = "$SourcesRoot/v$Version/$fileName"
    [string] $tempDestination = "$tempDownloadDirectory\$fileName"
    [string] $extractionDirectory = Get-NodeJSDistributionDirectory
    
    try {
        [void](Add-Type -AssemblyName System.IO.Compression.FileSystem)
        [void](New-Item -Path $tempDownloadDirectory -ItemType Container)
        [void](Start-BitsTransfer -Source $source -Destination $tempDestination -DisplayName "NodeJS v$Version-$Architecture" -Description "Getting NodeJS v$Version-$Architecture")
        [void](Expand-Archive -Path $tempDestination -DestinationPath $extractionDirectory)
    }
    finally {
        if (Test-Path -Path $tempDownloadDirectory -PathType Container) {
            Remove-Item -Path $tempDownloadDirectory -Recurse
        }
    }
}

function GetNodeJsRoot() {
    return "c:\env\nodejs"
}

function Get-NodeJSVersion([switch] $Local, [switch] $Remote) {
    if ($Local) {
        [string] $root = Get-NodeJSDistributionDirectory
        return Get-ChildItem -Path $Root | ForEach-Object {$_.Name}
    }
    
    if ($Remote) {
        $versions = (Invoke-WebRequest -Uri $SourcesRoot).Links | `
            Where-Object { $_.href -match '^v[0-9]+\.[0-9]+\.[0-9]+\/$' } | `
            Where-Object { $_.href -notmatch '^v0.[0-9]+\.[0-9]+\/$' } | ` # version v0.x.x is known to not contain any version of windows zipped
            ForEach-Object { $_.href.Substring(1, $_.href.Length - 2) }

                   
        [System.Collections.ArrayList] $versionsWithArchitectures = New-Object System.Collections.ArrayList
        foreach ($version in $versions) {
            foreach ($arch in $SupportedArchitectures) {
                [void]($versionsWithArchitectures.Add(@{ Version = $version; Architecture = $arch }))
            }
        }

        return $versionsWithArchitectures  | `
            Where-Object { (Test-NodeJSVersionExists $_.Version $_.Architecture) -eq $true } | `
            ForEach-Object { (Get-NodeJSVersionIdentifier $_.Version $_.Architecture) }
    }

    [string] $location = (cmd /c where node.exe).Split([System.Environment]::NewLine)[0];
    [string] $dist = Get-NodeJSDistributionDirectory
    [string] $matchString = "$($dist.Replace('\', '\\'))\\node-(v[0-9]+\.[0-9]+\.[0-9]+-win-(x86|x64))\\node.exe$"
    if ($location -eq $null -or $location -eq '') {
        return 'NodeJS could not be found in the PATH'
    }

    if ($location -match $matchString) {
        return $location -replace $matchString, '$1'
    }
    else {
        return "NodeJS found outside distribution directory: $location"
    }
}

function SetPathEnvironmentToNodeVersion([string] $newVersionRoot) {
    [string] $root = Get-NodeJSDistributionDirectory
    [string] $path = [System.Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
    [string[]] $components = $path.Split(';', [StringSplitOptions]::None)
    [int] $index = 0
    [int] $found = -1
    while ($index -lt $components.Length) {
         if ($components[$index].StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
             $found = $index
         }
         
         $index += 1
    }

    [string] $newPath = ""

    if ($found -eq -1) {
        $newPath = "$newVersionRoot;$path"
    }
    else {
        $components[$found] = $newVersionRoot
        $newPath = [string]::Join(';', $components)
    }
    
    [string] $nodeREPLHistory = "$newVersionRoot\.node_repl_history"
    [void][System.Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::User)
    [void][System.Environment]::SetEnvironmentVariable('NODE_REPL_HISTORY', $nodeREPLHistory, [EnvironmentVariableTarget]::User)
}

Export-ModuleMember -Function Set-NodeJSVersion
Export-ModuleMember -Function Get-NodeJSVersion
Export-ModuleMember -Function Get-NodeJSVersionDirectory
Export-ModuleMember -Function Get-NodeJSDistributionDirectory
Export-ModuleMember -Function Install-NodeJS
