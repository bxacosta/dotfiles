# Version Fox
Invoke-Expression "$(vfox activate pwsh)"

# Starship
Invoke-Expression (&starship init powershell)


# Functions
Function Set-Projects-Location {Set-Location -Path D:\PROJECTS}
Function New-File { param ($FileName) New-Item $FileName }


# Alias
Set-Alias -Name cdp -Value Set-Projects-Location
Set-Alias -Name touch -Value New-File
