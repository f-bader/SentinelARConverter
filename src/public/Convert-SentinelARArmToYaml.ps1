<#
.SYNOPSIS
Converts an Azure Sentinel Analytics Rule ARM template to YAML

.DESCRIPTION
Converts an Azure Sentinel Analytics Rule ARM template to YAML.
The ARM template can be provided as a file or as a string.
The YAML file can be saved to the same directory as the ARM template file.

.PARAMETER Filename
The path to the ARM template file

.PARAMETER Data
The ARM template data as a string

.PARAMETER OutFile
The path to the output YAML file

.PARAMETER UseOriginalFilename
If set, the output file will be saved with the same name as the ARM template file, but with a .yaml extension

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -OutFile "C:\Temp\MyRule.yaml"

.NOTES
  Author: Fabian Bader (https://cloudbrothers.info/)
#>

function Convert-SentinelARArmToYaml {
    [CmdletBinding(DefaultParameterSetName = 'Pipeline')]
    param (
        [Parameter(Mandatory = $true,
            ParameterSetName = 'Path')]
        [Parameter(Mandatory = $true,
            ParameterSetName = 'UseOriginalFilename')]
        [string]$Filename,

        [Alias('Yaml')]
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true,
            ParameterSetName = 'Pipeline',
            Position = 0)]
        [array]$Data,

        [Parameter(Mandatory = $false,
            ParameterSetName = 'Path')]
        [Parameter(Mandatory = $false,
            ParameterSetName = 'Pipeline')]
        [string]$OutFile,

        [Parameter(Mandatory = $true,
            ParameterSetName = 'UseOriginalFilename')]
        [switch]$UseOriginalFilename
    )


    begin {
        if ($PsCmdlet.ParameterSetName -in ("Path", "UseOriginalFilename") ) {
            if (-not (Test-Path $Filename) ) {
                throw "File not found"
            }
            if ($UseOriginalFilename) {
                $FileObject = Get-ChildItem $Filename
                $NewFileName = $FileObject.Name -replace $FileObject.Extension, ".yaml"
                $OutFile = Join-Path $FileObject.Directory $NewFileName
            }
        }
    }

    process {
        # Use pipeline data and create a variable containing all parsed strings
        if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
            $FullARM += $Data
        }
    }

    end {
        # Mapping of Arm property names to YAML when different
        $ValueNameMappingArm2Yaml = [ordered]@{
            "displayName"           = "name"
            "alertRuleTemplateName" = "id"
            "templateVersion"       = "version"
            "techniques"            = "relevantTechniques"
        }

        # Mapping of Arm operator names to YAML when different
        $CompareOperatorArm2Yaml = @{
            "Equals"             = "eq"
            "GreaterThan"        = "gt"
            "GreaterThanOrEqual" = "ge"
            "LessThan"           = "lt"
            "LessThanOrEqual"    = "le"
        }

        # List of values to always remove
        $RemoveArmValues = @(
            "enabled"
        )

        $DefaultSortOrderInYAML = @(
            "id",
            "name",
            "version",
            "kind",
            "description",
            "severity",
            "requiredDataConnectors",
            "queryFrequency",
            "queryPeriod",
            "triggerOperator",
            "triggerThreshold",
            "tactics",
            "relevantTechniques",
            "query"
        )

        # Use parsed pipeline data if no file was specified (default)
        if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
            $AnalyticsRuleTemplate = $FullARM | ConvertFrom-Json -Verbose
        } else {
            Write-Verbose "Read file `"$Filename`""
            $AnalyticsRuleTemplate = Get-Content $Filename | ConvertFrom-Json -Verbose
        }

        if ($AnalyticsRuleTemplate.resources.Count -ne 1) {
            throw "ARM template must contain exactly one resource"
        }

        # Get the id of the analytic rule
        if ($AnalyticsRuleTemplate.resources.id -match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}") {
            $Id = $Matches[0]
        } else {
            Write-Verbose "Error reading current Id. Generating new Id."
            $Id = (New-Guid).Guid
        }

        # Get the properties of the analytic rule
        $AnalyticsRule = $AnalyticsRuleTemplate.resources | Select-Object -ExpandProperty properties
        # Add the id and kind from the ARM template
        $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "id" -Value $Id -PassThru -Force
        $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "kind" -Value $AnalyticsRuleTemplate.resources.kind -PassThru -Force
        # Remove values that are not needed
        foreach ($RemoveArmValue in $RemoveArmValues) {
            $AnalyticsRule.PSObject.Properties.Remove($RemoveArmValue) | Out-Null
        }

        $JSON = $AnalyticsRule | ConvertTo-Json -Depth 100
        # Use ISO8601 format for timespan values
        $JSON = $JSON -replace '"PT([0-9]+)M"', '"$1m"' -replace '"PT([0-9]+)H"', '"$1h"' -replace '"P([0-9]+)D"', '"$1d"'

        # Convert the names of the properties to the names used in the YAML
        foreach ($Arm2Yaml in $ValueNameMappingArm2Yaml.Keys) {
            $JSON = $JSON -replace $Arm2Yaml, $ValueNameMappingArm2Yaml[$Arm2Yaml]
        }

        # Convert the compare operators to the names used in the YAML
        foreach ($Arm2Yaml in $CompareOperatorArm2Yaml.Keys) {
            $JSON = $JSON -replace $Arm2Yaml, $CompareOperatorArm2Yaml[$Arm2Yaml]
        }

        # Convert the JSON to a PowerShell object
        $AnalyticsRule = $JSON | ConvertFrom-Json

        # Use custom sort order of YAML
        $ErrorActionPreference = "SilentlyContinue"
        $AnalyticsRuleKeys = $AnalyticsRule.PSObject.Properties.Name | Sort-Object { $i = $DefaultSortOrderInYAML.IndexOf($_) ; if ( $i -eq -1 ) { 100 } else { $i } }
        $ErrorActionPreference = "Continue"
        # Create ordered hashtable
        $AnalyticsRuleCleaned = [ordered]@{}
        foreach ($Property in $AnalyticsRuleKeys) {
            # Remove empty properties
            if ( -not [string]::IsNullOrWhiteSpace($AnalyticsRule.$Property) -or ( $AnalyticsRule.$Property -is [array] -and ($AnalyticsRule.$Property.Count -gt 0) ) ) {
                $AnalyticsRuleCleaned.Add($Property, $AnalyticsRule.$Property)
            }
        }

        # Convert the PowerShell object to YAML
        $AnalyticsRuleYAML = $AnalyticsRuleCleaned | ConvertTo-Yaml

        # Write the YAML to a file or return the YAML
        if ($OutFile -or $UseOriginalFilename) {
            $AnalyticsRuleYAML | Out-File $OutFile -Force -Encoding utf8
            Write-Verbose "Output written to file: `"$OutFile`""
        } else {
            return $AnalyticsRuleYAML
        }
    }
}
# SIG # Begin signature block
# MIIoBAYJKoZIhvcNAQcCoIIn9TCCJ/ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAILhbsqC5wwx5x
# zlVmlm1ijiUB/i8tOXSc4oErnAE3DaCCIQcwggWNMIIEdaADAgECAhAOmxiO+dAt
# 5+/bUOIIQBhaMA0GCSqGSIb3DQEBDAUAMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQK
# EwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNV
# BAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9vdCBDQTAeFw0yMjA4MDEwMDAwMDBa
# Fw0zMTExMDkyMzU5NTlaMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2Vy
# dCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lD
# ZXJ0IFRydXN0ZWQgUm9vdCBHNDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAL/mkHNo3rvkXUo8MCIwaTPswqclLskhPfKK2FnC4SmnPVirdprNrnsbhA3E
# MB/zG6Q4FutWxpdtHauyefLKEdLkX9YFPFIPUh/GnhWlfr6fqVcWWVVyr2iTcMKy
# unWZanMylNEQRBAu34LzB4TmdDttceItDBvuINXJIB1jKS3O7F5OyJP4IWGbNOsF
# xl7sWxq868nPzaw0QF+xembud8hIqGZXV59UWI4MK7dPpzDZVu7Ke13jrclPXuU1
# 5zHL2pNe3I6PgNq2kZhAkHnDeMe2scS1ahg4AxCN2NQ3pC4FfYj1gj4QkXCrVYJB
# MtfbBHMqbpEBfCFM1LyuGwN1XXhm2ToxRJozQL8I11pJpMLmqaBn3aQnvKFPObUR
# WBf3JFxGj2T3wWmIdph2PVldQnaHiZdpekjw4KISG2aadMreSx7nDmOu5tTvkpI6
# nj3cAORFJYm2mkQZK37AlLTSYW3rM9nF30sEAMx9HJXDj/chsrIRt7t/8tWMcCxB
# YKqxYxhElRp2Yn72gLD76GSmM9GJB+G9t+ZDpBi4pncB4Q+UDCEdslQpJYls5Q5S
# UUd0viastkF13nqsX40/ybzTQRESW+UQUOsxxcpyFiIJ33xMdT9j7CFfxCBRa2+x
# q4aLT8LWRV+dIPyhHsXAj6KxfgommfXkaS+YHS312amyHeUbAgMBAAGjggE6MIIB
# NjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTs1+OC0nFdZEzfLmc/57qYrhwP
# TzAfBgNVHSMEGDAWgBRF66Kv9JLLgjEtUYunpyGd823IDzAOBgNVHQ8BAf8EBAMC
# AYYweQYIKwYBBQUHAQEEbTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQwYIKwYBBQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcnQwRQYDVR0fBD4wPDA6oDigNoY0
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNybDARBgNVHSAECjAIMAYGBFUdIAAwDQYJKoZIhvcNAQEMBQADggEBAHCgv0Nc
# Vec4X6CjdBs9thbX979XB72arKGHLOyFXqkauyL4hxppVCLtpIh3bb0aFPQTSnov
# Lbc47/T/gLn4offyct4kvFIDyE7QKt76LVbP+fT3rDB6mouyXtTP0UNEm0Mh65Zy
# oUi0mcudT6cGAxN3J0TU53/oWajwvy8LpunyNDzs9wPHh6jSTEAZNUZqaVSwuKFW
# juyk1T3osdz9HNj0d1pcVIxv76FQPfx2CWiEn2/K2yCNNWAcAgPLILCsWKAOQGPF
# mCLBsln1VWvPJ6tsds5vIy30fnFqI2si/xK4VC0nftg62fC2h5b9W9FcrBjDTZ9z
# twGpn1eqXijiuZQwggauMIIElqADAgECAhAHNje3JFR82Ees/ShmKl5bMA0GCSqG
# SIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMx
# GTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRy
# dXN0ZWQgUm9vdCBHNDAeFw0yMjAzMjMwMDAwMDBaFw0zNzAzMjIyMzU5NTlaMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBSU0E0MDk2IFNIQTI1NiBUaW1lU3RhbXBpbmcg
# Q0EwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGhjUGSbPBPXJJUVXH
# JQPE8pE3qZdRodbSg9GeTKJtoLDMg/la9hGhRBVCX6SI82j6ffOciQt/nR+eDzMf
# UBMLJnOWbfhXqAJ9/UO0hNoR8XOxs+4rgISKIhjf69o9xBd/qxkrPkLcZ47qUT3w
# 1lbU5ygt69OxtXXnHwZljZQp09nsad/ZkIdGAHvbREGJ3HxqV3rwN3mfXazL6IRk
# tFLydkf3YYMZ3V+0VAshaG43IbtArF+y3kp9zvU5EmfvDqVjbOSmxR3NNg1c1eYb
# qMFkdECnwHLFuk4fsbVYTXn+149zk6wsOeKlSNbwsDETqVcplicu9Yemj052FVUm
# cJgmf6AaRyBD40NjgHt1biclkJg6OBGz9vae5jtb7IHeIhTZgirHkr+g3uM+onP6
# 5x9abJTyUpURK1h0QCirc0PO30qhHGs4xSnzyqqWc0Jon7ZGs506o9UD4L/wojzK
# QtwYSH8UNM/STKvvmz3+DrhkKvp1KCRB7UK/BZxmSVJQ9FHzNklNiyDSLFc1eSuo
# 80VgvCONWPfcYd6T/jnA+bIwpUzX6ZhKWD7TA4j+s4/TXkt2ElGTyYwMO1uKIqjB
# Jgj5FBASA31fI7tk42PgpuE+9sJ0sj8eCXbsq11GdeJgo1gJASgADoRU7s7pXche
# MBK9Rp6103a50g5rmQzSM7TNsQIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHQ4EFgQUuhbZbU2FL3MpdpovdYxqII+eyG8wHwYDVR0jBBgwFoAU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggIBAH1ZjsCTtm+YqUQiAX5m1tghQuGwGC4QTRPPMFPOvxj7x1Bd
# 4ksp+3CKDaopafxpwc8dB+k+YMjYC+VcW9dth/qEICU0MWfNthKWb8RQTGIdDAiC
# qBa9qVbPFXONASIlzpVpP0d3+3J0FNf/q0+KLHqrhc1DX+1gtqpPkWaeLJ7giqzl
# /Yy8ZCaHbJK9nXzQcAp876i8dU+6WvepELJd6f8oVInw1YpxdmXazPByoyP6wCeC
# RK6ZJxurJB4mwbfeKuv2nrF5mYGjVoarCkXJ38SNoOeY+/umnXKvxMfBwWpx2cYT
# gAnEtp/Nh4cku0+jSbl3ZpHxcpzpSwJSpzd+k1OsOx0ISQ+UzTl63f8lY5knLD0/
# a6fxZsNBzU+2QJshIUDQtxMkzdwdeDrknq3lNHGS1yZr5Dhzq6YBT70/O3itTK37
# xJV77QpfMzmHQXh6OOmc4d0j/R0o08f56PGYX/sr2H7yRp11LB4nLCbbbxV7HhmL
# NriT1ObyF5lZynDwN7+YAN8gFk8n+2BnFqFmut1VwDophrCYoCvtlUG3OtUVmDG0
# YgkPCr2B2RP+v6TR81fZvAT6gt4y3wSJ8ADNXcL50CN/AAvkdgIm2fBldkKmKYcJ
# RyvmfxqkhQ/8mJb2VVQrH4D6wPIOK+XW+6kvRBVK5xMOHds3OBqhK/bt1nz8MIIG
# sDCCBJigAwIBAgIQCK1AsmDSnEyfXs2pvZOu2TANBgkqhkiG9w0BAQwFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjEwNDI5MDAwMDAwWhcNMzYwNDI4MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0IDIwMjEgQ0ExMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA1bQvQtAorXi3XdU5WRuxiEL1M4zr
# PYGXcMW7xIUmMJ+kjmjYXPXrNCQH4UtP03hD9BfXHtr50tVnGlJPDqFX/IiZwZHM
# gQM+TXAkZLON4gh9NH1MgFcSa0OamfLFOx/y78tHWhOmTLMBICXzENOLsvsI8Irg
# nQnAZaf6mIBJNYc9URnokCF4RS6hnyzhGMIazMXuk0lwQjKP+8bqHPNlaJGiTUyC
# EUhSaN4QvRRXXegYE2XFf7JPhSxIpFaENdb5LpyqABXRN/4aBpTCfMjqGzLmysL0
# p6MDDnSlrzm2q2AS4+jWufcx4dyt5Big2MEjR0ezoQ9uo6ttmAaDG7dqZy3SvUQa
# khCBj7A7CdfHmzJawv9qYFSLScGT7eG0XOBv6yb5jNWy+TgQ5urOkfW+0/tvk2E0
# XLyTRSiDNipmKF+wc86LJiUGsoPUXPYVGUztYuBeM/Lo6OwKp7ADK5GyNnm+960I
# HnWmZcy740hQ83eRGv7bUKJGyGFYmPV8AhY8gyitOYbs1LcNU9D4R+Z1MI3sMJN2
# FKZbS110YU0/EpF23r9Yy3IQKUHw1cVtJnZoEUETWJrcJisB9IlNWdt4z4FKPkBH
# X8mBUHOFECMhWWCKZFTBzCEa6DgZfGYczXg4RTCZT/9jT0y7qg0IU0F8WD1Hs/q2
# 7IwyCQLMbDwMVhECAwEAAaOCAVkwggFVMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFGg34Ou2O/hfEYb7/mF7CIhl9E5CMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# AzB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# HAYDVR0gBBUwEzAHBgVngQwBAzAIBgZngQwBBAEwDQYJKoZIhvcNAQEMBQADggIB
# ADojRD2NCHbuj7w6mdNW4AIapfhINPMstuZ0ZveUcrEAyq9sMCcTEp6QRJ9L/Z6j
# fCbVN7w6XUhtldU/SfQnuxaBRVD9nL22heB2fjdxyyL3WqqQz/WTauPrINHVUHmI
# moqKwba9oUgYftzYgBoRGRjNYZmBVvbJ43bnxOQbX0P4PpT/djk9ntSZz0rdKOtf
# JqGVWEjVGv7XJz/9kNF2ht0csGBc8w2o7uCJob054ThO2m67Np375SFTWsPK6Wrx
# oj7bQ7gzyE84FJKZ9d3OVG3ZXQIUH0AzfAPilbLCIXVzUstG2MQ0HKKlS43Nb3Y3
# LIU/Gs4m6Ri+kAewQ3+ViCCCcPDMyu/9KTVcH4k4Vfc3iosJocsL6TEa/y4ZXDlx
# 4b6cpwoG1iZnt5LmTl/eeqxJzy6kdJKt2zyknIYf48FWGysj/4+16oh7cGvmoLr9
# Oj9FpsToFpFSi0HASIRLlk2rREDjjfAVKM7t8RhWByovEMQMCGQ8M4+uKIw8y4+I
# Cw2/O/TOHnuO77Xry7fwdxPm5yg/rBKupS8ibEH5glwVZsxsDsrFhsP2JjMMB0ug
# 0wcCampAMEhLNKhRILutG4UI4lkNbcoFUCvqShyepf2gpx8GdOfy1lKQ/a+FSCH5
# Vzu0nAPthkX0tGFuv2jiJmCG6sivqf6UHedjGzqGVnhOMIIGwDCCBKigAwIBAgIQ
# DE1pckuU+jwqSj0pB4A9WjANBgkqhkiG9w0BAQsFADBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTIyMDkyMTAw
# MDAwMFoXDTMzMTEyMTIzNTk1OVowRjELMAkGA1UEBhMCVVMxETAPBgNVBAoTCERp
# Z2lDZXJ0MSQwIgYDVQQDExtEaWdpQ2VydCBUaW1lc3RhbXAgMjAyMiAtIDIwggIi
# MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDP7KUmOsap8mu7jcENmtuh6BSF
# dDMaJqzQHFUeHjZtvJJVDGH0nQl3PRWWCC9rZKT9BoMW15GSOBwxApb7crGXOlWv
# M+xhiummKNuQY1y9iVPgOi2Mh0KuJqTku3h4uXoW4VbGwLpkU7sqFudQSLuIaQyI
# xvG+4C99O7HKU41Agx7ny3JJKB5MgB6FVueF7fJhvKo6B332q27lZt3iXPUv7Y3U
# TZWEaOOAy2p50dIQkUYp6z4m8rSMzUy5Zsi7qlA4DeWMlF0ZWr/1e0BubxaompyV
# R4aFeT4MXmaMGgokvpyq0py2909ueMQoP6McD1AGN7oI2TWmtR7aeFgdOej4TJEQ
# ln5N4d3CraV++C0bH+wrRhijGfY59/XBT3EuiQMRoku7mL/6T+R7Nu8GRORV/zbq
# 5Xwx5/PCUsTmFntafqUlc9vAapkhLWPlWfVNL5AfJ7fSqxTlOGaHUQhr+1NDOdBk
# +lbP4PQK5hRtZHi7mP2Uw3Mh8y/CLiDXgazT8QfU4b3ZXUtuMZQpi+ZBpGWUwFjl
# 5S4pkKa3YWT62SBsGFFguqaBDwklU/G/O+mrBw5qBzliGcnWhX8T2Y15z2LF7OF7
# ucxnEweawXjtxojIsG4yeccLWYONxu71LHx7jstkifGxxLjnU15fVdJ9GSlZA076
# XepFcxyEftfO4tQ6dwIDAQABo4IBizCCAYcwDgYDVR0PAQH/BAQDAgeAMAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwIAYDVR0gBBkwFzAIBgZn
# gQwBBAIwCwYJYIZIAYb9bAcBMB8GA1UdIwQYMBaAFLoW2W1NhS9zKXaaL3WMaiCP
# nshvMB0GA1UdDgQWBBRiit7QYfyPMRTtlwvNPSqUFN9SnDBaBgNVHR8EUzBRME+g
# TaBLhklodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRS
# U0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3JsMIGQBggrBgEFBQcBAQSBgzCB
# gDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMFgGCCsGAQUF
# BzAChkxodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# RzRSU0E0MDk2U0hBMjU2VGltZVN0YW1waW5nQ0EuY3J0MA0GCSqGSIb3DQEBCwUA
# A4ICAQBVqioa80bzeFc3MPx140/WhSPx/PmVOZsl5vdyipjDd9Rk/BX7NsJJUSx4
# iGNVCUY5APxp1MqbKfujP8DJAJsTHbCYidx48s18hc1Tna9i4mFmoxQqRYdKmEIr
# UPwbtZ4IMAn65C3XCYl5+QnmiM59G7hqopvBU2AJ6KO4ndetHxy47JhB8PYOgPvk
# /9+dEKfrALpfSo8aOlK06r8JSRU1NlmaD1TSsht/fl4JrXZUinRtytIFZyt26/+Y
# siaVOBmIRBTlClmia+ciPkQh0j8cwJvtfEiy2JIMkU88ZpSvXQJT657inuTTH4YB
# ZJwAwuladHUNPeF5iL8cAZfJGSOA1zZaX5YWsWMMxkZAO85dNdRZPkOaGK7DycvD
# +5sTX2q1x+DzBcNZ3ydiK95ByVO5/zQQZ/YmMph7/lxClIGUgp2sCovGSxVK05iQ
# RWAzgOAj3vgDpPZFR+XOuANCR+hBNnF3rf2i6Jd0Ti7aHh2MWsgemtXC8MYiqE+b
# vdgcmlHEL5r2X6cnl7qWLoVXwGDneFZ/au/ClZpLEQLIgpzJGgV8unG1TnqZbPTo
# ntRamMifv427GFxD9dAq6OJi7ngE273R+1sKqHB+8JeEeOMIA11HLGOoJTiXAdI/
# Otrl5fbmm9x+LMz/F0xNAKLY1gEOuIvu5uByVYksJxlh9ncBjDCCB0gwggUwoAMC
# AQICEAqCMJBHqzYjysMfsj2s65owDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBU
# cnVzdGVkIEc0IENvZGUgU2lnbmluZyBSU0E0MDk2IFNIQTM4NCAyMDIxIENBMTAe
# Fw0yMjA1MTgwMDAwMDBaFw0yNTA1MTcyMzU5NTlaME0xCzAJBgNVBAYTAkRFMRAw
# DgYDVQQHEwdIYW1idXJnMRUwEwYDVQQKEwxGYWJpYW4gQmFkZXIxFTATBgNVBAMT
# DEZhYmlhbiBCYWRlcjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAMEj
# xUm2ziBQmPNov//zacCKh7+xiQg6o7vgiYO0wKIw1dgg0s+9qjdj2I1eWp34f43i
# VRrQOwawnilpC81R/T+KVudo7hIcEXu327+7Pj5KU4SwXcEF4fyRxF6SL/Yy5Dhh
# 92Ma8aCEuW3Z8yn7slK/KifyflOmvUoJDpBTTOqRhxRmNk7EQPMDI03aYWBkyn+f
# OYR+Jg+/xqtXW+9iEA6aKCl2D2aG0PiwLi7Rf0YE1R9WLYP+tZndvKVd+UMmbowH
# HKGCY4A1s3nMezu3HWLsAJbD34ei/mBVTsfS8rmlRUIOsOt3tQzWBILiJj5erVrQ
# DDh5oF8XeGuMPx9Lb1JKozh+SuHVOAlpnCEp5HYdrHRzcMfII32Ht08KVsZRTlNR
# xGnuhwDRerVbSMlYUEcEuydQzSTtSiDhmQwYSoYj5Ja9e1jJ0eXmBAjnXGnJBw0/
# cmSd0B5E9BjGtyp2UkeekYTm8+zR/JZSUUmf9sswzjwIYhTqyo2T2GC/EeduPGZM
# TsW0yVqU4Vud3SjzOm/TaLaoiVua7uHjlatMo0jHbTy7bUALuhxLTSiNfdAIr+Vz
# z0GDMiNTx1S2ObFe6Zt+oSKWORFttx5ybN9NuAIheORTdZsR5VJJu3PgmLDQG58k
# SZSHFMhddtWpBTVbhkFMGyEJ7ZkKGv5MXf76WNqRAgMBAAGjggIGMIICAjAfBgNV
# HSMEGDAWgBRoN+Drtjv4XxGG+/5hewiIZfROQjAdBgNVHQ4EFgQU9QqUwn2Wwx5W
# 7kpA5piphcoCDjkwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMD
# MIG1BgNVHR8Ega0wgaowU6BRoE+GTWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNIQTM4NDIwMjFDQTEu
# Y3JsMFOgUaBPhk1odHRwOi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVz
# dGVkRzRDb2RlU2lnbmluZ1JTQTQwOTZTSEEzODQyMDIxQ0ExLmNybDA+BgNVHSAE
# NzA1MDMGBmeBDAEEATApMCcGCCsGAQUFBwIBFhtodHRwOi8vd3d3LmRpZ2ljZXJ0
# LmNvbS9DUFMwgZQGCCsGAQUFBwEBBIGHMIGEMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wXAYIKwYBBQUHMAKGUGh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNENvZGVTaWduaW5nUlNBNDA5NlNI
# QTM4NDIwMjFDQTEuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIB
# AAnByFUoYIEa6FQ8Yvkg3yTqlTNmfdk9uWL/MclhjFJteGxhDgYJ3x4iFCZivQaZ
# tJP4Z2BKVeSJZfP0X9tJfsr5cE49ZuLLdka+HPOEUhpq1vN5pGMTIYOWC7S4mXWn
# zQnJLvftunYGed+yu2A4RriHloO9PFXIQJwxG/ApYqljGC8OieL2oEPdROXpj6au
# xYQ7NqjTBJZ641lC40JGERpQ38NtgHKbLQqxAZHPtfFmZegQ9jsNQ9cITFej9eO9
# mYE3KOj3KfASoa6qKFF6tgg8GFyW/4hTcEZ7uwrO/LvnZS7vrFzcbGxrj0/SIPuT
# rwtRYhzHjmuGkvB2UqU27uMPHHJS/RHV6pYFVxQtj5Q4q/9lvVY/bOrYkqd4XZR+
# 3SDuRREIfCS63TxcCl2fHa4Lz9ujH9dYwr8pDPkEJvY4Qf1YQJ8IrJIFKHSJH6Md
# EYybQkJDU9aF6iVRK8AapfyFUFDUAke0O3wPFNo1PBQU5GK8lEAEGiBKsWr93Phq
# jPeE4dwuRb6zruAlNvPx2bk42WQgT+7NhFv/+G0VEEp1weJmrM1Efv/Efm1/vsnx
# /zrtR0C+WhqPati9+qGlRY2jNvNsNacxQBFH9I4KVJAXiThVHhb4q2FsqnsfqCsM
# vFc4LPgSnexTkoS2u8AmotX432L6TuxsW6XWCampzTJgMYIGUzCCBk8CAQEwfTBp
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMT
# OERpZ2lDZXJ0IFRydXN0ZWQgRzQgQ29kZSBTaWduaW5nIFJTQTQwOTYgU0hBMzg0
# IDIwMjEgQ0ExAhAKgjCQR6s2I8rDH7I9rOuaMA0GCWCGSAFlAwQCAQUAoIGEMBgG
# CisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcC
# AQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIE
# IPY80uy0qyh/sL6Mvdn8dWvRSc8cyKjGDLf3vson8wzbMA0GCSqGSIb3DQEBAQUA
# BIICAB6yk3J0dQGnzoYIWQsj8htDZP+HuLEVLd9/u4HLPn6ExBNL/nSimtgEdmBI
# xf6c0hbmY3CBkjOrMTI1eDZyROU5bJtnhnRlm0d9upWJA3b6r+xJVd4/EVaqWLlg
# EkeVfUCGdy8e2I+yv60mcC8jhiZGsgk6fmawz6qXqTYSdzjOobDn4pLI1TjKn4J8
# 6KDtHRlcEGc7SbqTklTbNy7j9N3GoHzbACdUjrHL/o/LyzFqLJsxBDk9iDdEvEHG
# nV7MniX3kdfrqbJLnlnZBRiv9rnNTIKy0TM0mEvW689W4PaYXHjACm+nDC9EfwK8
# Ohx2f5/6hH37zUc7yGrKmjzdbnDU8m+LoESyBFmTmZ+FqC7EpPojTHPjH9pARfGJ
# eh2xWB1QEI/MU6xnRa2mwkFxlq7zWK4MxjUCA9XYK64c5DaqEmhq1zz4UXKQvRka
# g8w+ipZCFK9YrRRpgXSccYXvvxJUqJ7hHwOjYngnitcFxogPqVkjcU76WL3RuVgo
# KvrOP3lUHfg+HspsTACRABRo8khIEbmj+J43eY70RXdJ+EenYEiYhHi19B7QsDi7
# EbNK7LghH7+l6DcAJxl0yyJfymW7C8QBU2FYDtY8pM0VHqZMmwurl+NqDUzAE9Ny
# xLgbgxr/aswm5U5BWOSknM+ffTKG2W8pOuR+t7ZFnT82CzGloYIDIDCCAxwGCSqG
# SIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRp
# Z2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVkIEc0IFJTQTQw
# OTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwqSj0pB4A9WjANBglg
# hkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJKoZIhvcN
# AQkFMQ8XDTIzMDIyMDIwMzAzNFowLwYJKoZIhvcNAQkEMSIEIEvZ2ZqhDXXoNDJY
# HangmFlCfWUkazooXA8XfDtidZQKMA0GCSqGSIb3DQEBAQUABIICAMTJJ+O9k8K/
# ZFx7fhQwp351p7IPDMMhS+flBPKXb2qmGDsimChI/s5YmmJN3uKTBpI8Gy/i0Jfw
# gHlaqAPMAwXFB80ZVpVFRtUBoHCWj9/ZfWE74pCSN6lKaNnSH/YHqnwhCtZeAv7f
# 6HPwdV0VLWrt4X8mqe0QyR7gEF/LaLpivydvK7dsg1CtmC7tWpVAoaz3YAGzAOi5
# R8x9Zt1Ma+01i43/Ii4K++2OtnrcR330b2pYihQHvBKmhYcstKkYHMVxxwgwSpoc
# 7gVnJe0WDo7K6eXW1bGu3ji8yJblcbrCNoLqeGKiyPAUjMeY4Zd6v1fCb5IuCkrf
# OoiXJs3AzmiLq+UzlB6G9v+VLOZbfMrxu+AbFWJcL9s5e17v3SNc7mR1DQzYm1md
# h7OnFrwmLT0TItzz8MuhtWPPYl9dinrILYGWghjC4kv3FeyCLqLsfdaCfO09TXAC
# MsVj0kc6uQv2RGRsm1ht1PsORQQefMsOQkCzdjVtkx10RXEwsAxXPOsV/MhAwWK5
# VoP2rbQ922EPwNVMWd9B29JtUyGIf1yHvwu25uv0km6wDf7W8grgLuoKpqKWn/Pq
# l5NCsD4X4Sts8FOI0rULaRlukkgmo8i74b1ygR9lpZv3+k3/LYj0kBdb5bUyUxp/
# gs/14X2ZfD19eYlpy0J2retTAGuvCjzd
# SIG # End signature block
