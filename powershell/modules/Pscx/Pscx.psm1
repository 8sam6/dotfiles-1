﻿# -----------------------------------------------------------------------
# Desc: This is the PSCX initialization module script that loads nested 
#       modules.  Which nested modules are loaded is controlled via
#       $Pscx:Preferences.ModulesToImport.  You can override the default
#       settings by passing either a file containing the appropriate 
#       settings in hashtable form as shown in Pscx.Options.ps1 or you
#       can pass in a hashtable with the appropriate settings directly.
# -----------------------------------------------------------------------
Set-StrictMode -Version Latest

# -----------------------------------------------------------------------
# Displays help usage
# -----------------------------------------------------------------------
function WriteUsage([string]$msg)
{
    $moduleNames = $Pscx:Preferences.ModulesToImport.Keys | Sort

    if ($msg) { Write-Host $msg }
    
    $OFS = ','
    Write-Host @"
 
To load all PSCX modules using the default PSCX preferences execute: 

    Import-Module Pscx
    
To load all PSCX modules except a few, pass in a hashtable containing
a nested hashtable called ModulesToImport.  In this nested hashtable
add the module name you want to suppress and set its value to false e.g.: 

    Import-Module Pscx -args @{ModulesToImport = @{DirectoryServices = $false}}
    
To have complete control over which PSCX modules load as well as the PSCX 
options, copy the Pscx.UserPreferences.ps1 file to your home dir. Edit this
file and modify the settings as desired.  Then pass the path to this file as
an argument to Import-Module as shown below:

    Import-Module Pscx -arg ~\Pscx.UserPreferences.ps1

The nested module names are:

$moduleNames
 
"@
}

# -----------------------------------------------------------------------
# Overwrites the default PSCX preferences with user specified preferences
# -----------------------------------------------------------------------
function UpdateDefaultPreferencesWithUserPreferences([hashtable]$userPreferences)
{
    # Walk the user specified settings and overwrite the defaults with them
    foreach ($key in $userPreferences.Keys)
    {
        if (!$Pscx:Preferences.ContainsKey($key))
        {
            Write-Warning "$key is not a recognized PSCX preference"
            continue
        }

        if ($key -eq 'ModulesToImport')
        {
            foreach ($modkey in $userPreferences.ModulesToImport.Keys)
            {	
                if ($Pscx:Preferences.ModulesToImport.ContainsKey($modkey))
                {
                    $Pscx:Preferences.ModulesToImport.$modkey = $userPreferences.ModulesToImport.$modkey
                }
                else
                {
                    Write-Warning "$modkey is not a recognized PSCX nested module"
                }
            }
        }
        else
        {
            $Pscx:Preferences.$key = $userPreferences.$key		
        }
    }
}

# -----------------------------------------------------------------------
# Process module arguments - allows user to override the default options 
# using Import-Module -args
# -----------------------------------------------------------------------
if ($args.Length -gt 0) 
{
    if ($args[0] -eq 'help') 
    {
        # Display help/usage info
        WriteUsage
        return	
    }
    elseif ($args[0] -is [hashtable])
    {
        # Hashtable of settings passed directly
        UpdateDefaultPreferencesWithUserPreferences $args[0]
    }
    elseif (Test-Path $args[0])
    {
        # Attempt to load the user specified settings by executing the specified script
        $userPreferences = & $args[0]	
        if ($userPreferences -isnot [hashtable]) 
        {
            WriteUsage "'$($args[0])' must return a hashtable instead of a $($userPreferences.GetType().FullName)"
            return
        }

        UpdateDefaultPreferencesWithUserPreferences $userPreferences
    }
    else
    {
        # Display help/usage info
        WriteUsage "'$($args[0])' is not recognized as either a hashtable or a valid path"
        return		
    }
}	

# -----------------------------------------------------------------------
# Cmdlet aliases
# -----------------------------------------------------------------------
Set-Alias gtn   Get-TypeName    -Description "PSCX alias"
Set-Alias fhex  Format-Hex      -Description "PSCX alias"
Set-Alias cvxml Convert-Xml     -Description "PSCX alias"
Set-Alias fxml  Format-Xml      -Description "PSCX alias"
Set-Alias gcb   Get-Clipboard   -Description "PSCX alias"
Set-Alias ocb   Out-Clipboard   -Description "PSCX alias"
Set-Alias lorem Get-LoremIpsum  -Description "PSCX alias"
Set-Alias ln    New-HardLink    -Description "PSCX alias"
Set-Alias touch Set-FileTime    -Description "PSCX alias"
Set-Alias tail  Get-FileTail    -Description "PSCX alias"
Set-Alias skip  Skip-Object     -Description "PSCX alias"

# Compatibility alias
Set-Alias Resize-Bitmap Set-BitmapSize -Description "PSCX alias"

# -----------------------------------------------------------------------
# Load nested modules selected by user
# -----------------------------------------------------------------------
$stopWatch = new-object System.Diagnostics.StopWatch
$keys = @($Pscx:Preferences.ModulesToImport.Keys)
if ($Pscx:Preferences.ShowModuleLoadDetails) 
{ 
    Write-Host "PowerShell Community Extensions $($Pscx:Version)`n"
    $totalModuleLoadTimeMs = 0
    $stopWatch.Reset()
    $stopWatch.Start()
    $keys = @($keys | Sort)
}

foreach ($key in $keys)
{
    if ($Pscx:Preferences.ShowModuleLoadDetails) 
    {
        $stopWatch.Reset()
        $stopWatch.Start()
        Write-Host " $key $(' ' * (20 - $key.length))[ " -NoNewline
    }
    
    if (!$Pscx:Preferences.ModulesToImport.$key) 
    { 	
        # Not selected for loading by user 
        if ($Pscx:Preferences.ShowModuleLoadDetails) 
        {	
            Write-Host "Skipped" -nonew
        }		
    }
    else 
    {
        $subModuleBasePath = "$PSScriptRoot\Modules\{0}\Pscx.{0}" -f $key
        
        # Check for PSD1 first
        $path = "$subModuleBasePath.psd1"
        if (!(Test-Path -PathType Leaf $path)) 
        {
            # Assume PSM1 only
            $path = "$subModuleBasePath.psm1"
            if (!(Test-Path -PathType Leaf $path))
            {
                # Missing/invalid module
                if ($Pscx:Preferences.ShowModuleLoadDetails) 
                {
                    Write-Host "Module $path is missing ]"
                } 
                else 
                {
                    Write-Warning "Module $path is missing."
                }			
                continue
            }
        }
        
        try 
        {
            # Don't complain about non-standard verbs with nested imports but
            # we will still have one complaint for the final global scope import
            Import-Module $path -DisableNameChecking 
            
            if ($Pscx:Preferences.ShowModuleLoadDetails) 
            { 
                $stopWatch.Stop()
                $totalModuleLoadTimeMs += $stopWatch.ElapsedMilliseconds
                $loadTimeMsg = "Loaded in {0,4} mS" -f $stopWatch.ElapsedMilliseconds
                Write-Host $loadTimeMsg -nonew
            }
        } 
        catch 
        {
            # Problem in module
            if ($Pscx:Preferences.ShowModuleLoadDetails) 
            {
                Write-Host "Module $key load error: $_" -nonew 
            } 
            else 
            {
                Write-Warning "Module $key load error: $_"
            }
        }		
    } 
    
    if ($Pscx:Preferences.ShowModuleLoadDetails) 
    { 
        Write-Host " ]" 
    }
}

if ($Pscx:Preferences.ShowModuleLoadDetails) 
{ 
    Write-Host "`nTotal module load time: $totalModuleLoadTimeMs mS"
}

Remove-Item Function:\WriteUsage
Remove-Item Function:\UpdateDefaultPreferencesWithUserPreferences
Export-ModuleMember -Alias * -Function * -Cmdlet *
# SIG # Begin signature block
# MIIfUwYJKoZIhvcNAQcCoIIfRDCCH0ACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUpU+OtkLkOYMdSIWcu26Irybd
# 8uSgghqFMIIGajCCBVKgAwIBAgIQA5/t7ct5W43tMgyJGfA2iTANBgkqhkiG9w0B
# AQUFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVk
# IElEIENBLTEwHhcNMTMwNTIxMDAwMDAwWhcNMTQwNjA0MDAwMDAwWjBHMQswCQYD
# VQQGEwJVUzERMA8GA1UEChMIRGlnaUNlcnQxJTAjBgNVBAMTHERpZ2lDZXJ0IFRp
# bWVzdGFtcCBSZXNwb25kZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQC6aUqBTW+lFBaqis1nvku/xmmPWBzgeegenVgmmNpc1Hyj+dsrjBI2w/z5ZAax
# u8KomAoXDeGV60C065ZtmL+mj3nPvIqSe22cGAZR2KUYUzIBJxlh6IRB38bw6Mr+
# d61f2J57jGBvhVxGvWvnD4DO5wPDfDHPt2VVxvvgmQjkc1r7l9rQTL60tsYPfyaS
# qbj8OO605DqkSNBM6qlGJ1vPkhGTnBan/tKtHyLFHqzBce+8StsBCUTfmBwtZ7qo
# igMzyVG19wJNCaRN/oBexddFw30IqgEzzDPYTzAW5P8iMi7rfjvw+R4y65Ul0vL+
# bVSEutXl1NHdG6+9WXuUhTABAgMBAAGjggM1MIIDMTAOBgNVHQ8BAf8EBAMCB4Aw
# DAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCCAb8GA1UdIASC
# AbYwggGyMIIBoQYJYIZIAYb9bAcBMIIBkjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkA
# IAB1AHMAZQAgAG8AZgAgAHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUA
# IABjAG8AbgBzAHQAaQB0AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAA
# bwBmACAAdABoAGUAIABEAGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEA
# bgBkACAAdABoAGUAIABSAGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIA
# ZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkA
# bABpAHQAeQAgAGEAbgBkACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUA
# ZAAgAGgAZQByAGUAaQBuACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjALBglg
# hkgBhv1sAxUwHwYDVR0jBBgwFoAUFQASKxOYspkH7R7for5XDStnAs0wHQYDVR0O
# BBYEFGMvyd95knu1I8q74aTuM37j4p36MH0GA1UdHwR2MHQwOKA2oDSGMmh0dHA6
# Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3JsMDig
# NqA0hjJodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURD
# QS0xLmNybDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEQ0EtMS5jcnQwDQYJKoZIhvcNAQEFBQAD
# ggEBAKt0vUAATHYVJVc90xwD/31FyEUSZucoZWDY3zuz+g3BrDOP9IG5YfGd+5hV
# 195HQ7qAPfFIzD9nMFYfzvTQTIS9h6SexeEPqAZd0C9uXtwZ6PCH6uBOrz1sII5z
# b37WhxjghtOa/J7qjHLpQQ+4cbU4LPgpstUcop0b7F8quNw3IOHLu/DQbGyls8uf
# SvZU4yY0PS64wSsct/bDPf7RLR5Q9JTI+P3uc9tJtRv09f+lkME5FBvY7XEbapj7
# +kCaRKkpDlVeeLi3pIPDcAHwZkDlrnk04StNA6Et5ttUYhjt1QmLoqrWDMhPGr6Z
# JXhpmYnUWYne34jw02dedKWdpkQwggabMIIFg6ADAgECAhAK3lreshTkdg4UkQS9
# ucecMA0GCSqGSIb3DQEBBQUAMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNVBAMTJURp
# Z2lDZXJ0IEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTEwHhcNMTMwOTEwMDAw
# MDAwWhcNMTYwOTE0MTIwMDAwWjBnMQswCQYDVQQGEwJVUzELMAkGA1UECBMCQ08x
# FTATBgNVBAcTDEZvcnQgQ29sbGluczEZMBcGA1UEChMQNkw2IFNvZnR3YXJlIExM
# QzEZMBcGA1UEAxMQNkw2IFNvZnR3YXJlIExMQzCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAI/YYNDd/Aw4AcjlGyyL+qjbxgXi1x6uw7Qmsjst/Z1yx0ES
# BQb29HmGeka3achcbRPgmBTt3Jn6427FDhvKOXhk7dPJ2mFxfv3NACa+Knvq/sz9
# xClrULvhpyOba8lOgXm5A9zWWBmUgYISVYz0jiS+/jl8x3yEEzplkTYrDsaiFiA0
# 9HSpKCqvdnhBjIL6MGJeS13rFXjlY5KlfwPJAV5txn4WM8/6cjGRDa550Cg7dygd
# SyDv7oDH7+AFqKakiE6Z+4yuBGhWQEBFnL9MZvlp3hkGK6Wlqy0Dfg3qkgqggcGx
# MS+CpdbfXF+pdCbSpuYu4FrCuDb+ae1TbyTiTBECAwEAAaOCAzkwggM1MB8GA1Ud
# IwQYMBaAFHtozimqwBe+SXrh5T/Wp/dFjzUyMB0GA1UdDgQWBBTpFzY/nfuGUb9f
# L83BlRNclRNsizAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMw
# cwYDVR0fBGwwajAzoDGgL4YtaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL2Fzc3Vy
# ZWQtY3MtMjAxMWEuY3JsMDOgMaAvhi1odHRwOi8vY3JsNC5kaWdpY2VydC5jb20v
# YXNzdXJlZC1jcy0yMDExYS5jcmwwggHEBgNVHSAEggG7MIIBtzCCAbMGCWCGSAGG
# /WwDATCCAaQwOgYIKwYBBQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3Nz
# bC1jcHMtcmVwb3NpdG9yeS5odG0wggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5
# ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABl
# ACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAg
# AG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABh
# AG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwBy
# AGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBp
# AGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABl
# AGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wgYIG
# CCsGAQUFBwEBBHYwdDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEwGCCsGAQUFBzAChkBodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURDb2RlU2lnbmluZ0NBLTEuY3J0MAwGA1UdEwEB/wQCMAAw
# DQYJKoZIhvcNAQEFBQADggEBAANu3/2PhW9plSTLJBR7SZBv4XqKxMzAJOw9GzNB
# uj4ihsyn/cRt1HV/ey7J9vM2mKZ5dZhU6rpb/cRnnKzEHDSSYnaogUDWbnBAw43P
# 6q6T9xKktrCpWhZRqbCRquix/VZN4dphqkdwpS//b/YnKnHi2da3MB1GqzQw6PQd
# mCWGHm+/CZWWI6GWZxdnRrDSkpMbkPYwdupQMVFFqQWWl/vJddLSM6bim0GD/XlU
# sz8hvYdOnOUT9g8+I3SegouqnrAOqu9Yj046iM29/6tkwyOCOKKeVl+uulpXnJRi
# nRkpczbl0OMMmIakVF1OTG/A/g2PPd6Xp4NDAWIKnsCdh64wggajMIIFi6ADAgEC
# AhAPqEkGFdcAoL4hdv3F7G29MA0GCSqGSIb3DQEBBQUAMGUxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0xMTAy
# MTExMjAwMDBaFw0yNjAyMTAxMjAwMDBaMG8xCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xLjAsBgNV
# BAMTJURpZ2lDZXJ0IEFzc3VyZWQgSUQgQ29kZSBTaWduaW5nIENBLTEwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCcfPmgjwrKiUtTmjzsGSJ/DMv3SETQ
# PyJumk/6zt/G0ySR/6hSk+dy+PFGhpTFqxf0eH/Ler6QJhx8Uy/lg+e7agUozKAX
# EUsYIPO3vfLcy7iGQEUfT/k5mNM7629ppFwBLrFm6aa43Abero1i/kQngqkDw/7m
# JguTSXHlOG1O/oBcZ3e11W9mZJRru4hJaNjR9H4hwebFHsnglrgJlflLnq7MMb1q
# WkKnxAVHfWAr2aFdvftWk+8b/HL53z4y/d0qLDJG2l5jvNC4y0wQNfxQX6xDRHz+
# hERQtIwqPXQM9HqLckvgVrUTtmPpP05JI+cGFvAlqwH4KEHmx9RkO12rAgMBAAGj
# ggNDMIIDPzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAwwCgYIKwYBBQUHAwMwggHD
# BgNVHSAEggG6MIIBtjCCAbIGCGCGSAGG/WwDMIIBpDA6BggrBgEFBQcCARYuaHR0
# cDovL3d3dy5kaWdpY2VydC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5Lmh0bTCCAWQG
# CCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAgAHQAaABpAHMA
# IABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0AHUAdABlAHMA
# IABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABEAGkAZwBpAEMA
# ZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABSAGUAbAB5AGkA
# bgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3AGgAaQBjAGgA
# IABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBkACAAYQByAGUA
# IABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBuACAAYgB5ACAA
# cgBlAGYAZQByAGUAbgBjAGUALjASBgNVHRMBAf8ECDAGAQH/AgEAMHkGCCsGAQUF
# BwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMG
# CCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRB
# c3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMDqgOKA2
# hjRodHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290
# Q0EuY3JsMB0GA1UdDgQWBBR7aM4pqsAXvkl64eU/1qf3RY81MjAfBgNVHSMEGDAW
# gBRF66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAe3IdZP+I
# yDrBt+nnqcSHu9uUkteQWTP6K4feqFuAJT8Tj5uDG3xDxOaM3zk+wxXssNo7ISV7
# JMFyXbhHkYETRvqcP2pRON60Jcvwq9/FKAFUeRBGJNE4DyahYZBNur0o5j/xxKqb
# 9to1U0/J8j3TbNwj7aqgTWcJ8zqAPTz7NkyQ53ak3fI6v1Y1L6JMZejg1NrRx8iR
# ai0jTzc7GZQY1NWcEDzVsRwZ/4/Ia5ue+K6cmZZ40c2cURVbQiZyWo0KSiOSQOiG
# 3iLCkzrUm2im3yl/Brk8Dr2fxIacgkdCcTKGCZlyCXlLnXFp9UH/fzl3ZPGEjb6L
# HrJ9aKOlkLEM/zCCBs0wggW1oAMCAQICEAb9+QOWA63qAArrPye7uhswDQYJKoZI
# hvcNAQEFBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZ
# MBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNz
# dXJlZCBJRCBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTIxMTExMDAwMDAwMFow
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBD
# QS0xMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6IItmfnKwkKVpYBz
# QHDSnlZUXKnE0kEGj8kz/E1FkVyBn+0snPgWWd+etSQVwpi5tHdJ3InECtqvy15r
# 7a2wcTHrzzpADEZNk+yLejYIA6sMNP4YSYL+x8cxSIB8HqIPkg5QycaH6zY/2DDD
# /6b3+6LNb3Mj/qxWBZDwMiEWicZwiPkFl32jx0PdAug7Pe2xQaPtP77blUjE7h6z
# 8rwMK5nQxl0SQoHhg26Ccz8mSxSQrllmCsSNvtLOBq6thG9IhJtPQLnxTPKvmPv2
# zkBdXPao8S+v7Iki8msYZbHBc63X8djPHgp0XEK4aH631XcKJ1Z8D2KkPzIUYJX9
# BwSiCQIDAQABo4IDejCCA3YwDgYDVR0PAQH/BAQDAgGGMDsGA1UdJQQ0MDIGCCsG
# AQUFBwMBBggrBgEFBQcDAgYIKwYBBQUHAwMGCCsGAQUFBwMEBggrBgEFBQcDCDCC
# AdIGA1UdIASCAckwggHFMIIBtAYKYIZIAYb9bAABBDCCAaQwOgYIKwYBBQUHAgEW
# Lmh0dHA6Ly93d3cuZGlnaWNlcnQuY29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0w
# ggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgA
# aQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQA
# ZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcA
# aQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwA
# eQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkA
# YwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEA
# cgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIA
# eQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJYIZIAYb9bAMVMBIGA1UdEwEB/wQI
# MAYBAf8CAQAweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2Nz
# cC5kaWdpY2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2lj
# ZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwgYEGA1UdHwR6MHgw
# OqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJ
# RFJvb3RDQS5jcmwwOqA4oDaGNGh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwHQYDVR0OBBYEFBUAEisTmLKZB+0e36K+
# Vw0rZwLNMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA0GCSqGSIb3
# DQEBBQUAA4IBAQBGUD7Jtygkpzgdtlspr1LPUukxR6tWXHvVDQtBs+/sdR90OPKy
# XGGinJXDUOSCuSPRujqGcq04eKx1XRcXNHJHhZRW0eu7NoR3zCSl8wQZVann4+er
# Ys37iy2QwsDStZS9Xk+xBdIOPRqpFFumhjFiqKgz5Js5p8T1zh14dpQlc+Qqq8+c
# dkvtX8JLFuRLcEwAiR78xXm8TBJX/l/hHrwCXaj++wc4Tw3GXZG5D2dFzdaD7eeS
# DY2xaYxP+1ngIw/Sqq4AfO6cQg7PkdcntxbuD8O9fAqg7iwIVYUiuOsYGk38KiGt
# STGDR5V3cdyxG0tLHBCcdxTBnU8vWpUIKRAmMYIEODCCBDQCAQEwgYMwbzELMAkG
# A1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRp
# Z2ljZXJ0LmNvbTEuMCwGA1UEAxMlRGlnaUNlcnQgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EtMQIQCt5a3rIU5HYOFJEEvbnHnDAJBgUrDgMCGgUAoHgwGAYKKwYB
# BAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAc
# BgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8GEI
# DWrKa6ZAu2PBB7cPgLenfZowDQYJKoZIhvcNAQEBBQAEggEAUGX7WWN8yvGkuMtc
# RksMoEphjmFmnWwN6WwOh5bIya9kvre0og5jsUMXc8kznbLI19EGvcl2capjOnCk
# hZ9ezpkFRFN9bWflyYKGCjAcv816SQPn9kz3I0kdjMrkpMPhN2ltqgdL8Lj0ITRW
# xikynFqw3wPZ/GTuy7i6cp4f85NHPSVs98BxpKaO/ZoQc3GcaMEUEwW5DmzM3liU
# 89FuiZIqZ2PLIW+XTr8uGmxwbaHilT8fejCMD4TuhCQTkmhalsD2dDxivFFS8/YR
# CP7YpIY62SiS17MPwcW9z8hKmsrXDHEJyRs6l8dRPLp5vcjacx3KtCVv9yHY4+7w
# q+PFSKGCAg8wggILBgkqhkiG9w0BCQYxggH8MIIB+AIBATB2MGIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IEFzc3VyZWQgSUQgQ0EtMQIQA5/t7ct5
# W43tMgyJGfA2iTAJBgUrDgMCGgUAoF0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEH
# ATAcBgkqhkiG9w0BCQUxDxcNMTMxMDE3MTQyNzQxWjAjBgkqhkiG9w0BCQQxFgQU
# LLygf2FrLeS3XDZlkNJebfgAh40wDQYJKoZIhvcNAQEBBQAEggEAn/Yv1eE3IZ4Z
# 1E7fyfTKca2Q3njwd0Kd7TeYxiE87uGqysGZEv8C6OS6zFMmMFl3niSuv0MO+Ku3
# whZ+YYfooBAlWCZqTvw/0M3NAWwP9tZtZAiVenJeThiO1+0D3jkU3a9vPAlMWDcW
# lpBAQoIjunZ3d+TTGnmMfLnQucqrjNgHD0WlU9oijLAF0TYU0tfrAW/N9HQ7zyUJ
# X0mn/hmqhp/cuNPj8TpH9PkFo7LJ/x/XzFq7afu4vBJsd641egf7/RGkRTXQb2u3
# e8GTHX2847uARyEIcCsx6YsOC/ShiYz+ZXGJoHtW2Q18YD+9zQpdTP29cytOcDUX
# j/yyxFiMtw==
# SIG # End signature block
