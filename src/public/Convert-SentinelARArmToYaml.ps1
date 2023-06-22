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

.EXAMPLE
Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseOriginalFilename

.EXAMPLE
Get-Content -Path "C:\Temp\MyRule.json" -Raw | Convert-SentinelARArmToYaml -OutFile "C:\Temp\MyRule.yaml"

.NOTES
  Author: Fabian Bader (https://cloudbrothers.info/)
#>

function Convert-SentinelARArmToYaml {
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

        [Parameter(ParameterSetName = 'UseOriginalFilename')]
        [switch]$UseOriginalFilename,

        [Parameter(ParameterSetName = 'UseDisplayNameAsFilename')]
        [switch]$UseDisplayNameAsFilename,

        [Parameter(ParameterSetName = 'UseIdAsFilename')]
        [switch]$UseIdAsFilename
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
        try {
            if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
                $AnalyticsRuleTemplate = $FullARM | ConvertFrom-Json -Verbose
            } else {
                Write-Verbose "Read file `"$Filename`""
                $AnalyticsRuleTemplate = Get-Content $Filename | ConvertFrom-Json -Verbose
            }
        } catch {
            throw "Could not convert source file. JSON might be corrupted"
        }

        if ($AnalyticsRuleTemplate.resources.Count -ne 1) {
            throw "ARM template must contain exactly one resource"
        }

        # Get the id of the analytic rule
        if ($AnalyticsRuleTemplate.resources.id -match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}") {
            $Id = $Matches[0]
        } else {
            Write-Warning "Error reading current Id. Generating new Id."
            $Id = (New-Guid).Guid
        }

        Write-Verbose "Convert Analytics Rule $($AnalyticsRuleTemplate.resources.properties.displayName) ($($Id)) to YAML file"

        #region Set output filename to defined value if not specified by user
        if ($PsCmdlet.ParameterSetName -in ("UseOriginalFilename", "UseDisplayNameAsFilename", "UseIdAsFilename") ) {
            $FileObject = Get-ChildItem $Filename
            if ($UseOriginalFilename) {
                # Use original filename as new filename
                $NewFileName = $FileObject.Name -replace $FileObject.Extension, ".yaml"
            }
            if ($UseDisplayNameAsFilename) {
                # Use the display name of the Analytics Rule as filename
                $NewFileName = $AnalyticsRuleTemplate.resources.properties.displayName -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                $NewFileName = ((Get-Culture).TextInfo.ToTitleCase($NewFileName) -Replace ' ') + '.yaml'
            }
            if ($UseIdAsFilename) {
                # Use id as of the Analytics Rule filename
                $NewFileName = $Id + '.yaml'
            }
            $OutFile = Join-Path $FileObject.Directory $NewFileName
        }
        #endregion

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
        foreach ($PropertyName in $AnalyticsRuleKeys) {
            # Remove empty properties
            if ( -not [string]::IsNullOrWhiteSpace($AnalyticsRule.$PropertyName) -or ( $AnalyticsRule.$PropertyName -is [array] -and ($AnalyticsRule.$PropertyName.Count -gt 0) ) ) {
                $AnalyticsRuleCleaned.Add($PropertyName, $AnalyticsRule.$PropertyName)
            }
        }

        # Convert the PowerShell object to YAML
        $AnalyticsRuleYAML = $AnalyticsRuleCleaned | ConvertTo-Yaml

        # Write the YAML to a file or return the YAML
        if ($OutFile) {
            $AnalyticsRuleYAML | Out-File $OutFile -Force -Encoding utf8
            Write-Verbose "Output written to file: `"$OutFile`""
        } else {
            return $AnalyticsRuleYAML
        }
    }
}
