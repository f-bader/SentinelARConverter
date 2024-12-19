<#
.SYNOPSIS
Converts an Azure Sentinel Analytics Rule YAML file to ARM template

.DESCRIPTION
Converts an Azure Sentinel Analytics Rule YAML file to ARM template.
The YAML file can be provided as a file or as a string.
The ARM template file can be saved to the same directory as the YAML file.

.PARAMETER Filename
The path to the Analytics Rule YAML file

.PARAMETER Data
The YAML data as a string

.PARAMETER OutFile
The path to the output ARM template file

.PARAMETER UseOriginalFilename
If set, the output file will be saved with the original filename of the ARM template file
The extension will be replaced with .json

.PARAMETER UseDisplayNameAsFilename
If set, the output file will be saved with the display name of the Analytics Rule as filename
The extension will be replaced with .json

.PARAMETER UseIdAsFilename
If set, the output file will be saved with the id of the Analytics Rule as filename
The extension will be replaced with .json

.PARAMETER APIVersion
Set API version of the ARM template. Default is "2024-01-01-preview"

.PARAMETER NamePrefix
Set prefix for the name of the ARM template. Default is none

.PARAMETER Severity
Overwrite the severity of the provided YAML file with a custom one. Default is emtpy

.PARAMETER StartRunningAt
Set the startTimeUtc property of the ARM template. Default is empty
To successfully deploy the ARM template the startTimeUtc property must be set to a future date.
Start time must be between 10 minutes and 30 days from now. This is not validated by the cmdlet.

.PARAMETER DisableIncidentCreation
If set, the incidentCreation property of the ARM template will be set to false. Default is to keep the value from the YAML file.

.EXAMPLE
Convert-SentinelARYamlToArm -Filename "C:\Temp\MyRule.yaml" -OutFile "C:\Temp\MyRule.json"

.NOTES
  Author: Fabian Bader (https://cloudbrothers.info/)
#>

function Convert-SentinelARYamlToArm {
    [CmdletBinding(DefaultParameterSetName = 'StdOut')]
    param (
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = 'Path')]
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = 'UseOriginalFilename')]
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = 'UseDisplayNameAsFilename')]
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = 'UseIdAsFilename')]
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = 'StdOut')]
        [string]$Filename,

        [Alias('Json')]
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

        [Parameter(ParameterSetName = 'UseDisplayNameAsFilename')]
        [switch]$UseDisplayNameAsFilename,

        [Parameter(ParameterSetName = 'UseIdAsFilename')]
        [switch]$UseIdAsFilename,

        [ValidatePattern('^\d{4}-\d{2}-\d{2}(-preview)?$')]
        [Parameter()]
        [string]$APIVersion = "2024-01-01-preview",

        [Parameter()]
        [string]$NamePrefix,

        [ValidateSet("Informational", "Low", "Medium", "High")]
        [Parameter()]
        [string]$Severity,

        [Parameter()]
        [string]$ParameterFile,

        [Parameter()]
        [datetime]$StartRunningAt,

        [Parameter()]
        [switch]$DisableIncidentCreation
    )

    begin {
        if ($PsCmdlet.ParameterSetName -ne "Pipeline" ) {
            try {
                if (-not (Test-Path $Filename)) {
                    Write-Error -Exception
                }
            } catch {
                throw "File not found"
            }
        }

        if ($ParameterFile) {
            try {
                if (-not (Test-Path $ParameterFile)) {
                    Write-Error -Exception
                }
            } catch {
                throw "Parameters file not found"
            }
        }
    }

    process {
        # Use pipeline data and create a variable containing all parsed strings
        if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
            $FullYaml += $Data
        }
    }

    end {

        $PowerShellYAMLModuleVersion = Get-Module -Name powershell-yaml | Select-Object -ExpandProperty Version
        if ( $PowerShellYAMLModuleVersion -ge [version]"0.4.8" -and $PowerShellYAMLModuleVersion -le [version]"0.4.9" ) {
            Write-Warning "The powershell-yaml module version $($PowerShellYAMLModuleVersion) has known issues. Please update to the latest version of the module."
        }

        try {
            # Use parsed pipeline data if no file was specified (default)
            if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
                $analyticRule = $FullYaml | ConvertFrom-Yaml
            } else {
                Write-Verbose "Read file `"$Filename`""
                $analyticRule = Get-Content $Filename | ConvertFrom-Yaml
            }
        } catch {
            throw "Could not convert source file. YAML might be corrupted"
        }

        try {
            if ($ParameterFile) {
                Write-Verbose "Read parameters file `"$ParameterFile`""
                $Parameters = Get-Content $ParameterFile | ConvertFrom-Yaml
            } else {
                Write-Verbose "No parameters file provided"
            }
        } catch {
            throw "Could not convert parameters file. YAML might be corrupted"
        }

        #region Parameter file handling
        if ($Parameters) {
            #region Overwrite values from parameters file
            if ($Parameters.OverwriteProperties) {
                foreach ($Key in $Parameters.OverwriteProperties.Keys) {
                    if ($analyticRule.ContainsKey($Key)) {
                        Write-Verbose "Overwriting property $Key with $($Parameters.OverwriteProperties[$Key])"
                        $analyticRule[$Key] = $Parameters.OverwriteProperties[$Key]
                    } else {
                        Write-Verbose "Add new property $Key with $($Parameters.OverwriteProperties[$Key])"
                        $analyticRule.Add($Key, $Parameters.OverwriteProperties[$Key])
                    }
                }
            } else {
                Write-Verbose "No properties to overwrite in provided parameters file"
            }
            #endregion Overwrite values from parameters file

            #region Prepend KQL query with data from parameters file
            if ($Parameters.PrependQuery) {
                $analyticRule.query = $Parameters.PrependQuery + $analyticRule.query
            } else {
                Write-Verbose "No query to prepend in provided parameters file"
            }
            #endregion Prepend KQL query with data from parameters file

            #region Append KQL query with data from parameters file
            if ($Parameters.AppendQuery) {
                $analyticRule.query = $analyticRule.query + $Parameters.AppendQuery
            } else {
                Write-Verbose "No query to append in provided parameters file"
            }
            #endregion Append KQL query with data from parameters file

            #region Replace variables in KQL query with data from parameters file
            if ($Parameters.ReplaceQueryVariables) {
                foreach ($Key in $Parameters.ReplaceQueryVariables.Keys) {
                    if ($Parameters.ReplaceQueryVariables[$Key].Count -gt 1) {
                        # Join array values with comma and wrap in quotes
                        $ReplaceValue = $Parameters.ReplaceQueryVariables[$Key] -join '","'
                        $ReplaceValue = '"' + $ReplaceValue + '"'
                    } else {
                        # Use single value
                        $ReplaceValue = $Parameters.ReplaceQueryVariables[$Key]
                    }
                    Write-Verbose "Replacing variable %%$Key%% with $($ReplaceValue)"
                    $analyticRule.query = $analyticRule.query -replace "%%$($Key)%%", $ReplaceValue
                }
            } else {
                Write-Verbose "No variables to replace in provided parameters file"
            }
            #endregion Replace variables in KQL query with data from parameters file

            Write-Verbose "$($analyticRule | ConvertTo-Json -Depth 99)"
        }
        #endregion Parameter file handling

        if ( [string]::IsNullOrWhiteSpace($analyticRule.name) -or [string]::IsNullOrWhiteSpace($analyticRule.id) ) {
            throw "Analytics Rule name or id is empty. YAML might be corrupted"
        }

        # Generate new guid if id is not a valid guid
        if ($analyticRule.id -notmatch "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}") {
            Write-Warning "Error reading current Id. Generating new Id."
            $analyticRule.id = (New-Guid).Guid
        }

        # Add prefix to name if specified
        if ($NamePrefix) {
            $analyticRule.name = $NamePrefix + $analyticRule.name
        }

        # Overwrite severity with custom severity
        if (-not [string]::IsNullOrWhiteSpace($Severity) ) {
            $analyticRule.severity = $Severity
        }

        Write-Verbose "Convert Analytics Rule $($analyticRule.name) ($($analyticRule.id)) to ARM template"

        #region Set output filename to defined value if not specified by user
        if ($PsCmdlet.ParameterSetName -in ("UseOriginalFilename", "UseDisplayNameAsFilename", "UseIdAsFilename") ) {
            $FileObject = Get-ChildItem $Filename
            if ($UseOriginalFilename) {
                # Use original filename as new filename
                $NewFileName = $FileObject.Name -replace $FileObject.Extension, ".json"
            }
            if ($UseDisplayNameAsFilename) {
                # Use the display name of the Analytics Rule as filename
                $NewFileName = $analyticRule.name -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                $NewFileName = ((Get-Culture).TextInfo.ToTitleCase($NewFileName) -Replace ' ') + '.json'
            }
            if ($UseIdAsFilename) {
                # Use id as of the Analytics Rule filename
                $NewFileName = $analyticRule.id + '.json'
            }
            $OutFile = Join-Path $FileObject.Directory $NewFileName
        }
        #endregion

        $Template = @'
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "workspace": {
            "type": "String"
        }
    },
    "resources": [
        {
            "id": "[concat(resourceId('Microsoft.OperationalInsights/workspaces/providers', parameters('workspace'), 'Microsoft.SecurityInsights'),'/alertRules/<TEMPLATEID>')]",
            "name": "[concat(parameters('workspace'),'/Microsoft.SecurityInsights/<TEMPLATEID>')]",
            "type": "Microsoft.OperationalInsights/workspaces/providers/alertRules",
            "kind": "<RULEKIND>",
            "apiVersion": "<APIVERSION>",
            "properties": <PROPERTIES>
        }
    ]
}
'@

        # Replace API version with specified version
        $Template = $Template.Replace('<APIVERSION>', $APIVersion)

        $SkipYamlValues = @(
            "metadata",
            "kind",
            "requiredDataConnectors"
        )

        # Mapping of Arm template names to YAML name when different
        $ValueNameMappingYaml2Arm = [ordered]@{
            "name"               = "displayName"
            "id"                 = "alertRuleTemplateName"
            "version"            = "templateVersion"
            "relevantTechniques" = "techniques"
        }

        $CompareOperatorYaml2Arm = @{
            "eq" = "Equals"
            "gt" = "GreaterThan"
            "ge" = "GreaterThanOrEqual"
            "lt" = "LessThan"
            "le" = "LessThanOrEqual"
        }

        $ARMTemplate = [ordered]@{}
        foreach ($Item in $analyticRule.Keys) {
            # Skip certain values, because they are not needed in the ARM template
            if ( $Item -notin $SkipYamlValues ) {
                # Change the name of the value if needed
                $KeyName = $ValueNameMappingYaml2Arm[$Item]
                # If the name is not in the mapping, use the original name
                if ([string]::IsNullOrWhiteSpace($KeyName)) {
                    $KeyName = $Item
                }

                # Change values of compare operators
                if ( $analyticRule[$Item] -in $CompareOperatorYaml2Arm.Keys ) {
                    $Value = $CompareOperatorYaml2Arm[$analyticRule[$Item]]
                } else {
                    $Value = $analyticRule[$Item]
                }
                # Add value to hashtable
                if ($KeyName -notin $ARMTemplate.keys) {
                    $ARMTemplate.Add($KeyName, $Value)
                }
            }
        }

        # Add required parameters if missing with default values
        $RequiredParameters = @{
            "suppressionDuration" = "PT1H"
            "suppressionEnabled"  = $false
            "enabled"             = $true
            "customDetails"       = $null
            "entityMappings"      = $null
            "templateVersion"     = "1.0.0"
        }
        foreach ( $KeyName in $RequiredParameters.Keys ) {
            if (  $KeyName -notin $ARMTemplate.Keys ) {
                $ARMTemplate.Add($KeyName, $RequiredParameters[$KeyName])
            }
        }
        # Minimum API version that supports MITRE sub-techniques
        if (([datetime]::parseexact($APIVersion, 'yyyy-MM-dd-preview', $null)) -ge [datetime]"2023-12-01") {
            $ARMTemplate.subTechniques = @($ARMTemplate.techniques | Where-Object { $_ -match "(T\d{4})\.\d{3}" })
        }

        # Remove any sub-techniques from the techniques array
        if ($ARMTemplate.techniques) {
            $ARMTemplate.techniques = $ARMTemplate.techniques -replace "(T\d{4})\.\d{3}", '$1'
        }

        # Remove any invalid or non-existent techniques from the techniques array
        if ($ARMTemplate.techniques) {
            $ARMTemplate.techniques = $ARMTemplate.techniques | Where-Object { Test-MITRETechnique $_ }
        }

        # Remove duplicate techniques
        if ($ARMTemplate.techniques) {
            $ARMTemplate.techniques = @($ARMTemplate.techniques | Sort-Object -Unique)
        }

        # Remove any invalid or non-existent tactics from the tactics array
        if ($ARMTemplate.tactics) {
            $ARMTemplate.tactics = $ARMTemplate.tactics | Where-Object { Test-MITRETactic $_ }
        }

        # Remove duplicate tactics
        if ($ARMTemplate.tactics) {
            $ARMTemplate.tactics = @($ARMTemplate.tactics | Sort-Object -Unique)
        }

        # Add startRunningAt property if specified
        if ($StartRunningAt -and $analyticRule.kind -eq "Scheduled") {
            # Remove existing startTimeUtc property
            if ("startTimeUtc" -in $ARMTemplate.Keys) {
                $ARMTemplate.Remove("startTimeUtc")
            }
            # Add new startTimeUtc property
            $ARMTemplate.Add("startTimeUtc", $StartRunningAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"))
        } elseif ($StartRunningAt) {
            Write-Warning "StartRunningAt parameter is only supported for scheduled rules. Ignoring parameter."
        }

        # Disable incident creation if specified
        if ($DisableIncidentCreation) {
            # Remove existing createIncident property
            if ("createIncident" -in $ARMTemplate.incidentConfiguration.Keys) {
                $ARMTemplate.incidentConfiguration.Remove("createIncident")
            }
            # Check if incidentConfiguration container is present and if not create it
            if (-not $ARMTemplate.incidentConfiguration) {
                $ARMTemplate.Add("incidentConfiguration", [ordered]@{})
            }
            $ARMTemplate.incidentConfiguration.Add("createIncident", $false)
        }

        # Convert hashtable to JSON
        $JSON = $ARMTemplate | ConvertTo-Json -Depth 99
        # Use ISO8601 format for timespan values
        $JSON = $JSON -replace '"([0-9]+)m"', '"PT$1M"' -replace '"([0-9]+)h"', '"PT$1H"' -replace '"([0-9]+)d"', '"P$1D"'

        if ($analyticRule.kind -eq "Scheduled") {
            $ScheduleKind = "Scheduled"
        } elseif ($analyticRule.kind -eq "Nrt") {
            $ScheduleKind = "NRT"
        } else {
            $ScheduleKind = $analyticRule.kind.substring(0, 1).toupper() + $analyticRule.kind.substring(1).tolower()
        }

        $Result = $Template.Replace("<PROPERTIES>", $JSON)
        $Result = $Result.Replace("<TEMPLATEID>", $analyticRule.id)
        $Result = $Result.Replace("<RULEKIND>", $ScheduleKind)

        # Sort all property keys in ARM template and convert to JSON string object
        $Result = Invoke-SortJSONObject -object ( $Result | ConvertFrom-Json )
        $Result = $Result | ConvertTo-Json -Depth 99

        if ($OutFile) {
            $Result | Out-File $OutFile -Force
            Write-Verbose "Output written to file: `"$OutFile`""
        } else {
            return $Result
        }
    }
}