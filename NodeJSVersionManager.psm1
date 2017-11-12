[string] $SourcesRoot = 'https://nodejs.org/dist'
[string[]] $SupportedArchitectures = @('x86', 'x64')

function New-Junction([string] $Link, [string] $Target) {
    [void](cmd /c mklink /J """$Link""" """$Target""")
}

function Remove-Junction([string] $Link) {
    [void](Remove-Item -Path $Link -Force -Recurse)
}

function Get-NodeJSVersionDirectory(
    [Parameter(Mandatory=$true)] [string] $Version, 
    [Parameter(Mandatory=$true)] [string] $Architecture) {
    [string] $root = Get-NodeJSDistributionsRootDirectory
    [string] $nodeVersionDirectory = "$root\node-v$Version-win-$Architecture"
    return  $nodeVersionDirectory
}


function Get-NodeJSCurrentVersionDirectory {
    return "$([System.Environment]::GetEnvironmentVariable('ENV_NODEJS_ROOT', [EnvironmentVariableTarget]::User))\current\$env:USERNAME"
}
function Get-NodeJSDistributionsRootDirectory {
    return "$([System.Environment]::GetEnvironmentVariable('ENV_NODEJS_ROOT', [EnvironmentVariableTarget]::User))\dist"
}

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

function Get-NodeJSVersionIdentifier([string] $Version, [string] $Architecture) {
    return "node-v$Version-win-$Architecture"
}

function Get-NodeJSVersionSource([string] $Version, [string] $Architecture) {
    [string] $fileName = "$(Get-NodeJSVersionIdentifier $Version $Architecture).zip"
    return "$SourcesRoot/v$Version/$fileName"
}

# function Test-NodeJSVersionExists([string] $Version, [string] $Architecture) {
#     [int] $statusCode
#     try { 
#         $statusCode = (Invoke-WebRequest -Uri (Get-NodeJSVersionSource $Version $Architecture) -Method 'Head').StatusCode
#     }
#     catch {
#         $statusCode = $_.Exception.Response.StatusCode.Value
#     }

#     return $statusCode -eq 200
# }

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
    [string] $extractionDirectory = Get-NodeJSDistributionsRootDirectory
    
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

function Clear-NodeJSVersion {
    [string] $currentVersion = Get-NodeJSCurrentVersionDirectory
    if (Test-Path -Path $currentVersion -PathType Container) {
        Remove-Junction -Link $currentVersion
    }
}

function Set-NodeJSVersion(
    [Parameter(Mandatory=$true)] [string] $Version, 
    [Parameter(Mandatory=$true)] [string] $Architecture) {
    [string] $nodeVersionDirectory = Get-NodeJSVersionDirectory $Version $Architecture
    if (-not (Test-Path -Path $nodeVersionDirectory -PathType Container)) {
        throw "nodejs version not found at $nodeVersionDirectory"
    }

    [string] $currentVersion = Get-NodeJSCurrentVersionDirectory
    
    if (Test-Path -Path $currentVersion -PathType Container) {
        Remove-Junction -Link $currentVersion
    }

    New-Junction -Link $currentVersion -Target $nodeVersionDirectory
}

function Get-NodeJSVersion([switch] $Local, [switch] $Remote) {
    if ($Local) {
        [string] $root = Get-NodeJSDistributionsRootDirectory
        return Get-ChildItem -Path $Root | ForEach-Object {$_.Name}
    }
    
    if ($Remote) {
        $versions = (Invoke-WebRequest -Uri $SourcesRoot).Links | `
            Where-Object { $_.href -match '^v[0-9]+\.[0-9]+\.[0-9]+\/$' } | `
            Where-Object { $_.href -notmatch '^v0.[0-9]+\.[0-9]+\/$' } | ` # version v0.x.x is known to not contain any version of windows zipped
            Where-Object { $_.href -notmatch '^v4.[0-4]+\.[0-9]+\/$' } | ` # version v4.0.x to v4.4.x is known to not contain any version of windows zipped
            Where-Object { $_.href -notmatch '^v5.[0-9]+\.[0-9]+\/$' } | ` # version v5.x.x is known to not contain any version of windows zipped
            Where-Object { $_.href -notmatch '^v6.[0-1]+\.[0-9]+\/$' } | ` # version v6.0.x to v6.1.x is known to not contain any version of windows zipped
            ForEach-Object { $_.href.Substring(1, $_.href.Length - 2) }

                   
        [System.Collections.ArrayList] $versionsWithArchitectures = New-Object System.Collections.ArrayList
        foreach ($version in $versions) {
            foreach ($arch in $SupportedArchitectures) {
                [void]($versionsWithArchitectures.Add(@{ Version = $version; Architecture = $arch }))
            }
        }

        return $versionsWithArchitectures  | `
            # Where-Object { (Test-NodeJSVersionExists $_.Version $_.Architecture) -eq $true } | `
            ForEach-Object { (Get-NodeJSVersionIdentifier $_.Version $_.Architecture) }
    }

    [string] $currentVersion = Get-NodeJSCurrentVersionDirectory
    
    [System.IO.DirectoryInfo] $dir = Get-Item $currentVersion
    if ($dir -ne $null) {
        return [System.IO.Path]::GetFileName($dir.Target)
    }
    
    [string] $locations = (cmd /c where node.exe).Split([System.Environment]::NewLine);
    if ($location.Length -gt 0) {
        return "NodeJS found outside distribution directory: $($locations[0])"
    }

    return 'NodeJS could not be found in the PATH'
}


Export-ModuleMember -Function Install-NodeJS
Export-ModuleMember -Function Set-NodeJSVersion
Export-ModuleMember -Function Clear-NodeJSVersion
Export-ModuleMember -Function Get-NodeJSVersion
