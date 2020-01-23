# Installation script for development (PowerShell, Windows OS)
#
# it creates symbolic links in the HOME directory pointing to local files
#

Write-Host "*** Installation for Development***`n"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$prj_name = "capPin2Part"
$auto_load_scr = "capPin2PartInit.tcl"

If (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    Break
}

Write-host "Source directory: $dir"

Function Make-SymbolLink {
    Param (
        [string]$source,
        [string]$target
    )
    Process {
        if (Test-Path $target -PathType leaf)
        {
            Write-Host "`nWARNING: File/Link already exists: " $target
            Write-Host "Exit without creating link!`n"
        } else
        {
            New-Item -ItemType SymbolicLink -Value $source -Path $target
        }
    }
}

Function Make-DirLink {
    Param (
        [string]$source,
        [string]$target
    )
    Process {
        if (Test-Path $target -PathType Container)
        {
            Write-Host "`nWARNING: Directory/Link already exists: " $target
            Write-Host "Exit without creating link!`n"
        } else
        {
            New-Item -ItemType Junction -Value $source -Path $target
        }
    }
}

$tclscripts = (Join-path $env:Sigrity_EDA_DIR "tools\capture\tclscripts")
Write-Host "Cadence scripts directory: $tclscripts`n"

Make-DirLink (Join-path $dir $prj_name) (Join-path $tclscripts $prj_name)

Make-SymbolLink (Join-path (Join-path $tclscripts $prj_name) $auto_load_scr) (Join-path (Join-path $tclscripts "capAutoLoad") $auto_load_scr)

Write-Host ""
pause
