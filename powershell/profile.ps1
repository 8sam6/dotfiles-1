﻿#
# Profile.ps1 - main powershell profile script
# 
# Applies to all hosts, so only put things here that are global
#

# Setup the $home directory correctly
if (-not $global:home) { $global:home = (resolve-path ~) }

# if (Test-Path variable:\hostinvocation) {
# 	$FullPath=$hostinvocation.MyCommand.Path
# }	Else {
# 	$FullPath=(get-variable myinvocation -scope script).value.Mycommand.Definition
# }	
# write-host "Profile.ps1 source directory is $FullPath" -foregroundColor $([ConsoleColor]::Red)
 
# A couple of directory variables for convenience
$dotfiles = resolve-path ~/dotfiles/
$scripts = join-path $dotfiles "powershell"

$outputencoding = [System.Text.Encoding]::GetEncoding("utf-8")

# Update module path to include mine
$global:PSDefaultModulePath = $env:PSModulePath
$myModulePath = (join-path $scripts modules)
$env:PSModulePath = $myModulePath + ";" + $env:PSModulePath

# Load in support modules
# Import-Module "PowerTab" -ArgumentList (join-path $scripts PowerTabConfig.xml)
Import-Module "Posh-Git"
# Import-Module "Posh-Hg"
# Import-Module "Posh-Svn"
Import-Module "Pscx" -arg (join-path $scripts "Pscx.UserPreferences.ps1")

# Some helpers for working with the filesystem
function remove-allChildItems([string] $glob) { remove-item -recurse -force $glob }
function get-childfiles { get-childitem | ? { -not $_.PsIsContainer } }
function get-childcontainers { get-childitem | ? { $_.PsIsContainer } }

# A "set" function that behaves more like the same
# command in cmd and bash.
function set-variableEx
{
	if ($args.Count -eq 0) { get-variable }
	elseif ($args.Count -eq 1) { get-variable $args[0] }
	else { invoke-expression "set-variable $args" }
}

# Source: http://paradisj.blogspot.com/2010/03/powershell-how-to-get-script-directory.html       
function get-scriptdirectory {   
	if (Test-Path variable:\hostinvocation) {
		$FullPath=$hostinvocation.MyCommand.Path
	}	Else {
		$FullPath=(get-variable myinvocation -scope script).value.Mycommand.Definition
	}

	if (Test-Path $FullPath) {
		return (Split-Path $FullPath)
	} Else {
		$FullPath=(Get-Location).path
		Write-Warning ("Get-ScriptDirectory: Powershell Host <" + $Host.name + "> may not be compatible with this function, the current directory <" + $FullPath + "> will be used.")
		return $FullPath
	}
}

function get-isAdminUser() {
	$id = [Security.Principal.WindowsIdentity]::GetCurrent()
	$wp = new-object Security.Principal.WindowsPrincipal($id)
	return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$global:promptTheme = @{
	prefixColor = (?: { get-isAdminUser } { [ConsoleColor]::Red } { [ConsoleColor]::DarkGray })
	pathColor = [ConsoleColor]::Green
	pathBracesColor = [ConsoleColor]::DarkGray
	hostNameColor = [ConsoleColor]::Yellow
}

function prompt {
	$prefix = " ω "
	$hostName = [net.dns]::GetHostName().ToLower()
	$shortPath = (get-location)

	write-host ([Environment]::UserName) -noNewLine -foregroundColor $promptTheme.hostNameColor
    write-host $prefix -noNewLine -foregroundColor $promptTheme.prefixColor
	# write-host ' · ' -noNewLine -foregroundColor $promptTheme.pathBracesColor
	write-host $shortPath -noNewLine -foregroundColor $promptTheme.pathColor
	write-vcsStatus # from posh-git, posh-hg and posh-svn
	write-host ' λ' -noNewLine -foregroundColor $promptTheme.prefixColor
	return ' '
}

# UNIX friendly environment variables
$env:EDITOR = "gvim"
$env:VISUAL = $env:EDITOR
$env:GIT_EDITOR = $env:EDITOR
$env:TERM = "cygwin" # Set to cygwin to fix tmux via SSH

# Global aliases
. (join-path $scripts "Aliases.ps1")

# Add PS1 scripts directory to path
Add-PathVariable $scripts

# Add ST3 directories to path
Set-Alias subl $(join-path $env:ProgramFiles "Sublime Text 3\sublime_text.exe")

# I use curl.exe and wget.exe instead of the alias 'curl'.
remove-item alias:curl
remove-item alias:wget
