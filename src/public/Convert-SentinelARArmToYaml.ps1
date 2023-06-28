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
        [string]$Directory,

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


        # Use pipeline data and create a variable containing all parsed strings
        if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
            $FullARM += $Data
        }

        # Use parsed pipeline data if no file was specified (default)
        try {
            if ($PsCmdlet.ParameterSetName -eq "Pipeline") {
                $AnalyticsRuleTemplate = $FullARM | ConvertFrom-Json -Depth 99 -Verbose
            } else {
                Write-Verbose "Read file `"$Filename`""
                $AnalyticsRuleTemplate = Get-Content $Filename | ConvertFrom-Json -Depth 99 -Verbose
            }
        } catch {
            throw "Could not convert source file. JSON might be corrupted"
        }    

        try {
            if ((-not $AnalyticsRuleTemplate.resources) -or (($AnalyticsRuleTemplate.resources).Count -lt 1)) {
                throw "This template contains no Analytics Rules"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        try {
            if ($AnalyticsRuleTemplate.resources.type -ne "Microsoft.OperationalInsights/workspaces/providers/alertRules") {
                throw "This template contains resources other than Analytics Rules"
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        #endregion common

        #region ART
        $resourceCounter = 0

        foreach ($resource in $AnalyticsRuleTemplate.resources) {

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
                
                $OutFile = Join-Path $FileObject.Directory $NewFileName
            } elseif ($PsCmdlet.ParameterSetName -in ("Path") -or ($PsCmdlet.ParameterSetName -in ("Pipeline") -and $OutFile -and -not $Directory)) {
                if ($resourceCounter -gt 0) {
                    $OutFile = $OutFile -replace ".yaml", "_$resourceCounter.yaml"
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
                $OutFile = Join-Path -Path $Directory -ChildPath $NewFileName
            }
            #endregion
        
            # Get the properties of the analytic rule
            $AnalyticsRule = $resource | Select-Object -ExpandProperty properties
            # Add the id and kind from the ARM template
            $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "id" -Value $Id -PassThru -Force
            $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "kind" -Value $AnalyticsRuleTemplate.resources.kind -PassThru -Force
            # Add version if not present
            if ( [string]::IsNullOrWhiteSpace($AnalyticsRuleTemplate.resources.properties.templateVersion) ) {
                $AnalyticsRule = $AnalyticsRule | Add-Member -MemberType NoteProperty -Name "version" -Value "1.0.0" -PassThru -Force
            }
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

            #endregion ART

            # Write the YAML to a file or return the YAML
            if ($OutFile) {
                # if (-not (Test-Path $OutFile)) {
                $AnalyticsRuleYAML | Out-File $OutFile -NoClobber:(-not $Force) -Encoding utf8
                Write-Verbose "Output written to file: `"$OutFile`""
                # } else {
                #     Write-Warning "Duplicate filename Skipping writing to file: `"$OutFile`""
                #} 
            } else {
                $AnalyticsRuleYAML
            }

            $resourceCounter++
        }
    }
}

