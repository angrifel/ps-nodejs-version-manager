# PS NodeJS Version Manager

PS NodeJS Version Manager is a version manager for NodeJS written in Windows Powershell.


## Installing

In order to install the version manager for windows run the following line in a powershell prompt.

``` powershell
(Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/angrifel/ps-nodejs-version-manager/master/Install-NodeJSVersionManager.ps1').Content | iex
```

## Usage

Once the NodeJS version manager is installed you can run the following cmdlets

``` powershell
Install-NodeJS -Version 'major.minor.revision' -Architecture 'x86|x64' # Downloads the specified NodeJS Version to the distribution directory.
```

``` powershell
Get-NodeJSVersion # Get the current NodeJS version
                  # if invoked with the -Local switch it will list the version installed locally.
                  # if invoked with the -Remote switch it will list the version available for install.
```

``` powershell
Set-NodeJSVersion -Version 'major.minor.revision' -Architecture 'x86|x64' # Adjust the PATH variable to include the specified NodeJS version.
                                                                          # NOTE: the specified version must be installed.
```
``` powershell
Clear-NodeJSVersion # Removes the current NodeJS version from the PATH.
```


NOTE: NodeJS Version Manager is designed to run on wndows only. 
