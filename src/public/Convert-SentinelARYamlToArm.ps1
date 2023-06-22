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
Set API version of the ARM template. Default is "2022-11-01"

.EXAMPLE
Convert-SentinelARYamlToArm -Filename "C:\Temp\MyRule.yaml" -OutFile "C:\Temp\MyRule.json"

.NOTES
  Author: Fabian Bader (https://cloudbrothers.info/)
#>

function Convert-SentinelARYamlToArm {
    [CmdletBinding(DefaultParameterSetName = 'StdOut')]
    param (
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'Path')]
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'UseOriginalFilename')]
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'UseDisplayNameAsFilename')]
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'UseIdAsFilename')]
        [Parameter(Mandatory = $true,
            Position = 0,
            ParameterSetName = 'StdOut')]
        [string]$Filename,

        [Alias('Json')]
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

        [Parameter(ParameterSetName = 'UseOriginalFilename')]
        [switch]$UseOriginalFilename,

        [Parameter(ParameterSetName = 'UseDisplayNameAsFilename')]
        [switch]$UseDisplayNameAsFilename,

        [Parameter(ParameterSetName = 'UseIdAsFilename')]
        [switch]$UseIdAsFilename,

        [ValidatePattern('^\d{4}-\d{2}-\d{2}(-preview)?$')]
        [Parameter(Mandatory = $false)]
        [string]$APIVersion = "2022-11-01"
    )

    begin {
        if ($PsCmdlet.ParameterSetName -ne "Pipeline" ) {
            if (-not (Test-Path $Filename) ) {
                throw "File not found"
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

        if ( [string]::IsNullOrWhiteSpace($analyticRule.name) -or [string]::IsNullOrWhiteSpace($analyticRule.id) ) {
            throw "Analytics Rule name or id is empty. YAML might be corrupted" 
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

        # Only include the following keys in ARM template
        $DefaultSortOrderInArmTemplate = @(
            "displayName",
            "description",
            "severity",
            "enabled",
            "query",
            "queryFrequency",
            "queryPeriod",
            "triggerOperator",
            "triggerThreshold",
            "suppressionDuration",
            "suppressionEnabled",
            "tactics",
            "techniques",
            "alertRuleTemplateName",
            "incidentConfiguration",
            "eventGroupingSettings",
            "alertDetailsOverride",
            "customDetails",
            "entityMappings",
            "sentinelEntitiesMappings"
        )

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

        # Sort by custom order
        $ARMTemplateOrdered = [ordered]@{}
        $ErrorActionPreference = "SilentlyContinue"
        $AnalyticsRuleKeys = $ARMTemplate.Keys | Sort-Object { $i = $DefaultSortOrderInArmTemplate.IndexOf($_) ; if ( $i -eq -1 ) { 100 } else { $i } }
        $ErrorActionPreference = "Continue"
        foreach ($PropertyName in $AnalyticsRuleKeys) {
            $ARMTemplateOrdered.Add($PropertyName, $ARMTemplate.$PropertyName)
        }

        # Convert hashtable to JSON
        $JSON = $ARMTemplateOrdered | ConvertTo-Json -Depth 99
        # Use ISO8601 format for timespan values
        $JSON = $JSON -replace '"([0-9]+)m"', '"PT$1M"' -replace '"([0-9]+)h"', '"PT$1H"' -replace '"([0-9]+)d"', '"P$1D"'

        $ScheduleKind = $analyticRule.kind.substring(0, 1).toupper() + $analyticRule.kind.substring(1).tolower()

        $Result = $Template.Replace("<PROPERTIES>", $JSON)
        $Result = $Result.Replace("<TEMPLATEID>", $analyticRule.id)
        $Result = $Result.Replace("<RULEKIND>", $ScheduleKind)
        if ( $PSVersionTable.PSVersion -ge [version]'7.0.0' ) {
            # Beautify in PowerShell 7 and above
            $Result = $Result | ConvertFrom-Json | ConvertTo-Json -Depth 99
        }

        if ($OutFile) {
            $Result | Out-File $OutFile -Force
            Write-Verbose "Output written to file: `"$OutFile`""
        } else {
            return $Result
        }
    }
}
