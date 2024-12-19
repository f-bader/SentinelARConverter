<#
.SYNOPSIS
Converts an Azure Sentinel Analytics Rule ARM template to YAML

.DESCRIPTION
Converts an Azure Sentinel Analytics Rule ARM template to YAML.
The ARM template can be provided as a file or as a string.
The YAML file can be saved to the same directory as the ARM template file.

.PARAMETER Filename
The path to the Analytics Rule ARM template file

.PARAMETER Data
The ARM template data as a string

.PARAMETER OutFile
The path to the output YAML file

.PARAMETER UseOriginalFilename
If set, the output file will be saved with the original filename of the ARM template file
The extension will be replaced with .yaml

.PARAMETER UseDisplayNameAsFilename
If set, the output file will be saved with the display name of the Analytics Rule as filename
The extension will be replaced with .yaml

.PARAMETER UseIdAsFilename
If set, the output file will be saved with the id of the Analytics Rule as filename
The extension will be replaced with .yaml

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -OutFile "C:\Temp\MyRule.yaml"
Will convert a the file with a single ART to a single YAML-file

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseOriginalFilename
Will convert a the file with a single ART to a single YAML-file, with the same basename as the supplied JSON (ARM).

.EXAMPLE
Get-Content -Path "C:\Temp\MyRule.json" -Raw | Convert-SentinelARArmToYaml -OutFile "C:\Temp\MyRule.yaml"
Will convert JSON ARM-text in the pipeline containg a single ART to a single YAML-file, saved in the supplied filename.

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MultipleRules.json" -OutFile "C:\Temp\MultipleRules.yaml"
Will create multiple files, one per alert in the file: MultipleRules.yaml, MultipleRules_1.yaml, MultipleRules_2.yaml etc.

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MultipleRules.json" -UseOriginalFilename
Will create multiple files in the same directory, one per alert in the file names as: MultipleRules.yaml, MultipleRules_1.yaml and MultipleRules_2.yaml.

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -UseDisplayNameAsFilename
Will create multiple files in the same directory, one per alert in the file names as: Displaynameofalert1.yaml, Displaynameofalert2.yaml, Displayname3.yaml

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseIdAsFilename
Will create multiple files in the same directory, one per alert in the file, with the names: 734075d4-1974-4318-b262-5268e36e4f35.yaml, 734075d4-1974-4318-b262-5268e36e4f34.yaml etc.

.EXAMPLE
Get-Content -Path "C:\Temp\Multiple.json" -Raw | Convert-SentinelARArmToYaml -OutFile "C:\Temp\MyRule.yaml"
Will create multiple files in the supplied directory, with the prefix mentioned in OutFile, one per alert in the file, with the names: MyRule.yaml, MyRule_1.yaml etc.

.EXAMPLE
Get-Content -Path "C:\Temp\Multiple.json" -Raw | Convert-SentinelARArmToYaml -Directory "C:\Temp\"  -UseDisplayNameAsFilename
Will create multiple files in the supplied directory, one per alert in the file, with the names: Displaynameofalert1.yaml, Displaynameofalert2.yaml, Displayname3.yaml

.EXAMPLE
Get-Content -Path "C:\Temp\Multiple.json" -Raw | Convert-SentinelARArmToYaml -Directory "C:\Temp\" -UseIdAsFilename
Will create multiple files in the supplied directory, one per alert in the file, with the names: 734075d4-1974-4318-b262-5268e36e4f35.yaml, 734075d4-1974-4318-b262-5268e36e4f34.yaml etc.

.NOTES
  Author: Fabian Bader (https://cloudbrothers.info/)
#>

function Convert-SentinelARArmToYaml {
    [CmdletBinding(DefaultParameterSetName = 'StdOut')]
    param (
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = 'Path')]
        [Parameter(
            Position = 0,
            ParameterSetName = 'UseOriginalFilename')]
        [Parameter(
            Position = 0,
            ParameterSetName = 'UseDisplayNameAsFilename')]
        [Parameter(
            Position = 0,
            ParameterSetName = 'UseIdAsFilename')]
        [Parameter(
            Position = 0,
            ParameterSetName = 'StdOut')]
        [string]$Filename,

        [Alias('Yaml')]
        [Parameter(Mandatory,
            ValueFromPipeline,
            ParameterSetName = 'Pipeline',
            Position = 0)]
        [array]$Data,

        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'Pipeline')]
        [string]$OutFile,

        [Parameter(ParameterSetName = 'UseOriginalFilename')]
        [switch]$UseOriginalFilename,

        [Parameter(ParameterSetName = 'Pipeline')]
        [Parameter(ParameterSetName = 'UseDisplayNameAsFilename')]
        [switch]$UseDisplayNameAsFilename,

        [Parameter(ParameterSetName = 'Pipeline')]
        [Parameter(ParameterSetName = 'UseIdAsFilename')]
        [switch]$UseIdAsFilename,

        [Parameter(ParameterSetName = 'Pipeline')]
        [string]$Directory = $PWD,

        [Parameter(
            ParameterSetName = 'Path')]
        [Parameter(
            ParameterSetName = 'UseOriginalFilename')]
        [Parameter(
            ParameterSetName = 'UseDisplayNameAsFilename')]
        [Parameter(
            ParameterSetName = 'UseIdAsFilename')]
        [Parameter(
            ParameterSetName = 'StdOut')]
        [Parameter(
            ParameterSetName = 'Pipeline')]
        [switch]$Force = $false
    )

    process {

        #region common

        if ($PsCmdlet.ParameterSetName -ne "Pipeline" ) {
            try {
                if (-not (Test-Path $Filename)) {
                    Write-Error -Exception
                }
            } catch {
                throw "File not found"
            }
        }


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

        # Default sort order, naming is before key rename
        $DefaultSortOrderInYAML = @(
            "id"
            "alertRuleTemplateName", # id
            "displayName", # name
            "version",
            "templateVersion", #version
            "kind",
            "description",
            "severity",
            "requiredDataConnectors",
            "queryFrequency",
            "queryPeriod",
            "triggerOperator",
            "triggerThreshold",
            "tactics",
            "techniques", #relevantTechniques
            "query"
        )

        # Use pipeline data and create a variable containing all parsed strings
        if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
            $FullARM += $Data
        }

        # Use parsed pipeline data if no file was specified (default)
        try {
            if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
                if ($PSVersionTable.PSEdition -ne "Core") {
                    $AnalyticsRuleTemplate = $FullARM | ConvertFrom-Json -Verbose
                } else {
                    $AnalyticsRuleTemplate = $FullARM | ConvertFrom-Json -Depth 99
                }
            } else {
                Write-Verbose "Read file `"$Filename`""

                if ($PSVersionTable.PSEdition -ne "Core") {
                    $AnalyticsRuleTemplate = Get-Content $Filename | ConvertFrom-Json -Verbose
                } else {
                    $AnalyticsRuleTemplate = Get-Content $Filename | ConvertFrom-Json -Depth 99 -Verbose
                }
            }
        } catch {
            throw "Could not convert source file. JSON might be corrupted"
        }

        try {
            if ( (-not $AnalyticsRuleTemplate.resources) ) {
                throw "This template contains no Analytics Rules or resources"
            }
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        #endregion common

        #region ART
        $resourceCounter = 0

        foreach ($resource in ( $AnalyticsRuleTemplate.resources | Where-Object { $_.type -eq "Microsoft.OperationalInsights/workspaces/providers/alertRules" } ) ) {
            if ( $resource.kind -notin @("Scheduled", "NRT") ) {
                Write-Warning "Analytics Rule $($resource.properties.displayName) is using an unsupported type `"$($resource.kind)`". Only type `"Scheduled`", `"NRT`" are supported."
                Continue
            } elseif ($resource.kind -eq "NRT") {
                # List of values to always remove for a NRT
                $RemoveArmValues = @(
                    "enabled",
                    "startTimeUtc",
                    "queryFrequency",
                    "queryPeriod",
                    "triggerOperator",
                    "triggerThreshold"
                )
            } else {
                # List of values to always remove
                $RemoveArmValues = @(
                    "enabled"
                )
            }

            # Get the id of the analytic rule
            if ($resource.id -match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}") {
                $Id = $Matches[0]
            } else {
                Write-Warning "Error reading current Id. Generating new Id."
                $Id = (New-Guid).Guid
            }

            Write-Verbose "Convert Analytics Rule: $($resource.properties.displayName) ($($Id)) to YAML file"

            #region Set output filename to defined value if not specified by user
            if ($PsCmdlet.ParameterSetName -in ("UseOriginalFilename", "UseDisplayNameAsFilename", "UseIdAsFilename") ) {
                $FileObject = Get-ChildItem $Filename
                if ($UseOriginalFilename) {
                    # Use original filename as new filename
                    if ($resourceCounter -eq 0) {
                        $NewFileName = $FileObject.Name -replace $FileObject.Extension, ".yaml"
                    } else {
                        $NewFileName = $FileObject.BaseName + "_$resourceCounter" + ".yaml"
                    }
                }
                if ($UseDisplayNameAsFilename) {
                    # Use the display name of the Analytics Rule as filename
                    $NewFileName = $resource.properties.displayName -Replace '[^0-9A-Z]', ' '
                    # Convert To CamelCase
                    $NewFileName = ((Get-Culture).TextInfo.ToTitleCase($NewFileName) -Replace ' ') + '.yaml'
                }
                if ($UseIdAsFilename) {
                    # Use id as of the Analytics Rule filename
                    $NewFileName = $Id + '.yaml'
                }

                $OutFilePath = Join-Path $FileObject.Directory $NewFileName
            } elseif ( $PsCmdlet.ParameterSetName -in ("Pipeline", "Path") -and $OutFile ) {
                $DirectoryName = [System.IO.Path]::GetDirectoryName($OutFile)
                $FileExtension = [System.IO.Path]::GetExtension($OutFile)
                $FileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($OutFile)
                if ($resourceCounter -gt 0) {
                    $NewFileName = "$($FileNameWithoutExtension)_$($resourceCounter)$($FileExtension)"
                    $OutFilePath = Join-Path $DirectoryName $NewFileName
                } else {
                    $OutFilePath = Join-Path $DirectoryName ([System.IO.Path]::GetFileName($OutFile))
                }
            } elseif ($PsCmdlet.ParameterSetName -in ("Pipeline") -and ($UseDisplayNameAsFilename -or $UseIdAsFilename)) {
                if ($UseDisplayNameAsFilename) {
                    # Use the display name of the Analytics Rule as filename
                    $NewFileName = $resource.properties.displayName -Replace '[^0-9A-Z]', ' '
                    # Convert To CamelCase
                    $NewFileName = ((Get-Culture).TextInfo.ToTitleCase($NewFileName) -Replace ' ') + '.yaml'
                }
                if ($UseIdAsFilename) {
                    # Use id as of the Analytics Rule filename
                    $NewFileName = $Id + '.yaml'
                }
                $OutFilePath = Join-Path -Path $Directory -ChildPath $NewFileName
            }
            #endregion

            # Get the properties of the analytic rule
            $AnalyticsRule = $resource | Select-Object -ExpandProperty properties
            # Add the id and kind from the ARM template
            $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "id" -Value $Id -PassThru -Force
            $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "kind" -Value $resource.kind -PassThru -Force
            # Add version if not present
            if ( [string]::IsNullOrWhiteSpace($resource.properties.templateVersion) ) {
                $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "version" -Value "1.0.0" -PassThru -Force
            }
            # Remove values that are not needed
            foreach ($RemoveArmValue in $RemoveArmValues) {
                $AnalyticsRule.PSObject.Properties.Remove($RemoveArmValue) | Out-Null
            }

            $JSON = $AnalyticsRule | ConvertTo-Json -Depth 100
            # Use ISO8601 format for timespan values
            $JSON = $JSON -replace '"PT([0-9]+)M"', '"$1m"' -replace '"PT([0-9]+)H"', '"$1h"' -replace '"P([0-9]+)D"', '"$1d"'

            # Convert the compare operators to the names used in the YAML
            foreach ($Arm2Yaml in $CompareOperatorArm2Yaml.Keys) {
                $JSON = $JSON -replace "`"$Arm2Yaml`"", "`"$($CompareOperatorArm2Yaml[$Arm2Yaml])`""
            }

            # Convert the JSON to a PowerShell object
            $AnalyticsRule = $JSON | ConvertFrom-Json

            # Use custom sort order of YAML
            $ErrorActionPreference = "SilentlyContinue"
            $AnalyticsRuleKeys = $AnalyticsRule.PSObject.Properties.Name | Sort-Object { $i = $DefaultSortOrderInYAML.IndexOf($_) ; if ( $i -eq -1 ) { 100 } else { $i } }
            $ErrorActionPreference = "Continue"
            # Create ordered hashtable
            $AnalyticsRuleCleaned = [ordered]@{}
            foreach ($PropertyName in $AnalyticsRuleKeys) {
                # Remove empty properties
                if ( -not [string]::IsNullOrWhiteSpace($AnalyticsRule.$PropertyName) -or ( $AnalyticsRule.$PropertyName -is [array] -and ($AnalyticsRule.$PropertyName.Count -gt 0) ) ) {
                    # Change the name of the value if needed
                    $KeyName = $ValueNameMappingArm2Yaml[$PropertyName]
                    # If the name is not in the mapping, use the original name
                    if ([string]::IsNullOrWhiteSpace($KeyName)) {
                        $KeyName = $PropertyName
                    }
                    # Special case for subTechniques since we cannot add duplicate keys to $ValueNameMappingArm2Yaml
                    # We must merge all techniques since (relevant)techniques could contain values not preset in subTechniques
                    if ($PropertyName -like "*techniques") {
                        foreach ($value in $AnalyticsRule.$PropertyName) {
                            $KeyName = "relevantTechniques"
                            $technique = $value -replace "(T\d{4})\.\d{3}", '$1'
                            # Create an empty key
                            if ( -not $AnalyticsRuleCleaned.Contains($KeyName) ) {
                                $AnalyticsRuleCleaned.Add($KeyName, @())
                            }
                            # Add subTechnique if the mainTechnique is not already present
                            if (-not($AnalyticsRuleCleaned[$KeyName].contains($technique))) {
                                $AnalyticsRuleCleaned[$KeyName] += $value
                                # Replace mainTechnique with subTechnique
                            } else {
                                $AnalyticsRuleCleaned[$KeyName][$AnalyticsRuleCleaned[$KeyName].indexOf($technique)] = $value
                            }
                        }
                    }
                    if ( -not $AnalyticsRuleCleaned.Contains($KeyName)) {
                        $AnalyticsRuleCleaned.Add($KeyName, $AnalyticsRule.$PropertyName)
                    }
                }
            }

            # Bugfix for broken powershell-yaml - https://github.com/cloudbase/powershell-yaml/issues/177
            $AnalyticsRuleCleaned = $AnalyticsRuleCleaned | ConvertTo-Json -Depth 99 | ConvertFrom-Json
            # Convert the PowerShell object to YAML
            $AnalyticsRuleYAML = $AnalyticsRuleCleaned | ConvertTo-Yaml

            #endregion ART

            # Write the YAML to a file or return the YAML
            if ($OutFilePath) {
                $AnalyticsRuleYAML | Out-File $OutFilePath -NoClobber:(-not $Force) -Encoding utf8
                Write-Verbose "Output written to file: `"$OutFilePath`""
            } else {
                $AnalyticsRuleYAML
            }

            $resourceCounter++
        }
    }
}

