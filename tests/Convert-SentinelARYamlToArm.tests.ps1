param(
    [Parameter()]
    [String]
    $exampleScheduledFilePath = "./tests/examples/Scheduled.yaml",
    [Parameter()]
    [String]
    $exampleScheduledBadFilePath = "./tests/examples/ScheduledBadGuid.yaml",
    [Parameter()]
    [String]
    $NRTexampleScheduledFilePath = "./tests/examples/NRT.yaml",
    [Parameter()]
    [Switch]
    $RetainTestFiles = $false
)

BeforeAll {
    # Remove the module if it is already loaded
    if (Get-Module SentinelARConverter) {
        Remove-Module SentinelARConverter -Force
    }
    # Import the module for the tests
    $ModuleRoot = Split-Path -Path ./tests -Parent
    Import-Module -Name "$ModuleRoot/src/SentinelARConverter.psd1"
}

Describe "Convert-SentinelARYamlToArm" {

    Context "When no valid path was passed" -Tag Unit {
        It "Throws an error" {
            { Convert-SentinelARYamlToArm -Filename "C:\Not\A\Real\File.yaml" } | Should -Throw "File not found"
        }
    }

    Context "Scheduled example tests" -Tag Integration {
        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
        }
        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }
        It "No Pipeline and OutFile" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json"
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "Scheduled.json"
        }
        It "No Pipeline and UseOriginalFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -UseOriginalFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.yaml | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "Scheduled.json"
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -UseDisplayNameAsFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.yaml | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "AzureWAFMatchingForLog4jVulnCVE202144228.json"
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -UseIdAsFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.yaml | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.json"
        }
        It "Pipeline and OutFile" {
            Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | Convert-SentinelARYamlToArm -OutFile "TestDrive:/Scheduled.json"
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
        }
    }

    Context "If an invalid template id is provided in the analytics rule resources block" -Tag Unit {
        BeforeAll {
            Copy-Item -Path $exampleScheduledBadFilePath -Destination "TestDrive:/ScheduledBadGuid.json" -Force
        }
        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.yaml -Force
            }
        }
        It "Creates a new guid when a bad GUID is provided" {
            $convertedExampleFilePath = "TestDrive:/ScheduledBadGuid.yaml"
            Convert-SentinelARYamlToArm -Filename "TestDrive:/ScheduledBadGuid.json" -OutFile $convertedExampleFilePath

            $convertedExampleFilePath | Should -Not -FileContentMatch 'alertRules/z-4a5f-4d27-8a26-b60a7952d5af'
        }
    }

    Context "NRT example tests" -Tag Integration {
        BeforeAll {
            Copy-Item -Path $NRTexampleScheduledFilePath -Destination "TestDrive:/NRT.yaml" -Force
        }
        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }
        It "No Pipeline and OutFile" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/NRT.yaml" -OutFile "TestDrive:/NRT.json"
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "NRT.json"
        }
        It "No Pipeline and UseOriginalFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/NRT.yaml" -UseOriginalFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.yaml | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "NRT.json"
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/NRT.yaml" -UseDisplayNameAsFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.yaml | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "NRTModifiedDomainFederationTrustSettings.json"
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/NRT.yaml" -UseIdAsFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.yaml | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "4a4364e4-bd26-46f6-a040-ab14860275f8.json"
        }
    }

    Context "Validate JSON format of resulting ARM template" {
        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
            $YAMLSourceContent = Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | ConvertFrom-Yaml
        }
        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should not be null or empty" {
            $armTemplate | Should -Not -BeNullOrEmpty
        }

        It "Should have the correct properties" {
            $armTemplate | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Should -Be @(
                "`$schema"
                "contentVersion"
                "parameters"
                "resources"
            )
        }

        It "Should have the correct property types" {
            $armTemplate | Should -BeOfType [System.Management.Automation.PSCustomObject]
            $armTemplate.'$schema' | Should -BeOfType [string]
            $armTemplate.contentVersion | Should -BeOfType [string]
            $armTemplate.parameters | Should -BeOfType [System.Management.Automation.PSCustomObject]
            $armTemplate.resources -is [System.Array] | Should -Be $true # Don't know why Should -BeOfType [System.Array] doesn't work
        }

        It "Should have the correct schema version" {
            $armTemplate.'$schema' | Should -Be "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
        }

        It "Should only have one resource" {
            $armTemplate.resources | Should -HaveCount 1
        }
    }

    Context "Validate integrity of resulting ARM template" {
        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
            $YAMLSourceContent = Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | ConvertFrom-Yaml
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the correct resource type" {
            $armTemplate.resources[0].type | Should -Be "Microsoft.OperationalInsights/workspaces/providers/alertRules"
        }

        It "Should have a non null template version" {
            $armTemplate.resources[0].properties.templateVersion | Should -Not -BeNullOrEmpty
        }

        It "Should match the query from the YAML file" {
            $armTemplate.resources[0].properties.query | Should -Be $YAMLSourceContent.query
        }
    }

    AfterAll {
        Remove-Module SentinelARConverter -Force
    }
}
