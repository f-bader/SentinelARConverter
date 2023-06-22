param(
    [Parameter()]
    [String]
    $exampleFilePath = "$PSScriptRoot/examples/MicrosoftSecurityIncidentCreation.json"
)

BeforeAll {
    . "$PSScriptRoot\..\src\public\Convert-SentinelARArmToYaml.ps1"

    New-Item -ItemType Directory -Path "$PSScriptRoot/testOutput" -Force | Out-Null

    $convertedExampleFilePath = $exampleFilePath -replace "\.json$", ".yaml"
    $ARMTemplateContent = Get-Content $exampleFilePath -Raw
    $outputPath = $convertedExampleFilePath -replace "/examples/", "/testOutput/"
    $convertedExampleFilePath -match "\w*\.yaml$"
    $convertedExampleFileName = $matches[0]
}

Describe "Convert-SentinelARArmToYaml" {
    BeforeEach {
        if (Test-Path "$PSScriptRoot\examples\$convertedExampleFileName") {
            Remove-Item "$PSScriptRoot/examples/$convertedExampleFileName"
        }
    }
    AfterEach {
        if (Test-Path $convertedExampleFilePath) {
            Remove-Item $convertedExampleFilePath
        }
    }
    Context "When no valid path was passed" -Tag Integration {
        It "Throws an error" {
            { Convert-SentinelARArmToYaml -Filename "C:\Not\A\Real\File.json" } | Should -Throw "File not found"
        }
    }
    Context "If UseOriginalFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template" {
            $convertSentinelARArmToYamlSplat = @{
                Filename            = $exampleFilePath
                UseOriginalFilename = $true
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat

            $convertedExampleFilePath | Should -Exist
        }

        It "Should use the original filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename            = $exampleFilePath
                UseOriginalFilename = $true
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat

            $path = $convertSentinelARArmToYamlSplat.Filename -replace "\.json$", ".yaml"

            Get-ChildItem $convertedExampleFilePath | Should -Match $convertedExampleFileName
        }

    }
    Context "If neither OutFile or UseOriginalFilename is passed" -Tag Integration {
        It "Outputs YAML to the console" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = $exampleFilePath
            }

            $output = (Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml)
            $output | Should -Not -BeNullOrEmpty
            Get-ChildItem -Path $PSScriptRoot -Recurse -Filter $convertedExampleFileName | Should -BeNullOrEmpty
        }
    }
    Context "If an ARM template file content is passed via pipeline" -Tag Integration {

        It "Should convert a Scheduled Query Alert Sentinel Alert Rule ARM template to a YAML file" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = $exampleFilePath
                OutFile  = $convertedExampleFileName
            }

            Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml -OutFile $convertSentinelARArmToYamlSplat.OutFile

            $path = $convertSentinelARArmToYamlSplat.Filename -replace "\.json$", ".yaml"
            Test-Path -Path $path | Should -Be $True
        }

    }

    Context "When no resources are present in the passed ARM template" -Tag Unit {

        It "Throws an error" {
            {
                $ARMTemplateContent |
                ConvertFrom-Json -Depth 99 |
                Select-Object "`$schema", "contentVersion", "parameters" |
                ConvertTo-Json -Depth 99 |
                Convert-SentinelARArmToYaml -OutFile $outputPath
            } | Should -Throw "ARM template must contain exactly one resource"
        }
    }
    Context "If an invalid template id is provided in the analytics rule resources block" -Tag Unit {
        It "Creates a new guid" {

            Get-Content -Path "$PSScriptRoot/examples/ScheduledBadGuid.json" | Convert-SentinelARArmToYaml -OutFile $outputPath

            $outputPath | Should -Not -FileContentMatch 'id: z-4a5f-4d27-8a26-b60a7952d5af'
        }
    }
    Context "If redundant ARM Properties are present in the rules" -Tag Unit {
        It "Removes the redundant ARM properties" {
            $outputPath = "$PSScriptRoot/testOutput/$convertedExampleFileName"

            $ARMTemplateContent | Convert-SentinelARArmToYaml -OutFile $outputPath

            $outputPath | Should -Not -FileContentMatch '^enabled: true'
        }
    }
    Context "When the template contains timespan values" -Tag Unit {

        It "Properly converts the units" {
            $outputPath = "$PSScriptRoot/testOutput/$convertedExampleFileName"

            $ARMTemplateContent | Convert-SentinelARArmToYaml -OutFile $outputPath

            $outputPath | Should -Not -FileContentMatch '^suppressionDuration: PT'
            $outputPath | Should -Not -FileContentMatch '^queryPeriod: PT'
            $outputPath | Should -Not -FileContentMatch '^queryFrequency: PT'
        }
    }
    Context "When specific propertynames/comparison properties are found on AR objects" -Tag Unit {
        BeforeDiscovery {
            $convertedJSON = Get-Content -Path $exampleFilePath -Raw | ConvertFrom-Json -Depth 99 -AsHashtable
            foreach ($resource in $convertedJSON["resources"]) {
                if (-not $resource.properties.ContainsKey("triggerOperator")) {
                    Write-Warning "This template does not contain a triggerOperator property. Cannot test conversion of comparison operators."
                    $CannotCheckComparisonOperators = $true
                }
            }
        }
        BeforeAll {
            $ARMTemplateContent = Get-Content -Path $exampleFilePath -Raw
            $ARMTemplateContent | Convert-SentinelARArmToYaml -OutFile $outputPath
        }
        It "Properly converts the propertynames" {

            $outputPath | Should -Not -FileContentMatch '^displayName'
            $outputPath | Should -Not -FileContentMatch '^alertRuleTemplateName'
            $outputPath | Should -Not -FileContentMatch '^templateVersion'
            $outputPath | Should -Not -FileContentMatch '^techniques'
        }
        It "Properly converts the comparison operators" -Skip:$CannotCheckComparisonOperators {
            $outputPath | Should -Not -FileContentMatch 'GreaterThan$'
            $outputPath | Should -Not -FileContentMatch 'Equals$'
            $outputPath | Should -Not -FileContentMatch 'GreaterThanOrEqual$'
            $outputPath | Should -Not -FileContentMatch 'LessThan$'
            $outputPath | Should -Not -FileContentMatch 'LessThanOrEqual$'
        }
    }
    Context "When converting a Sentinel Alert Rule ARM template to YAML" -Tag Integration {
        It "Should convert a Scheduled Query Alert Sentinel Alert Rule ARM template to a YAML-file" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = $exampleFilePath
                OutFile  = "$PSScriptRoot/testOutput/$convertedExampleFileName"
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            Get-Content $convertSentinelARArmToYamlSplat.OutFile  | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    Remove-Item -Path "$PSScriptRoot\testOutput" -Recurse -Force
}

