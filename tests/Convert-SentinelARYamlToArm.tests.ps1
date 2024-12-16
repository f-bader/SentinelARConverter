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
    [String]
    $exampleScheduledTTPFilePath = "./tests/examples/TTPWithTacticsNTechniques.yaml",
    [Parameter()]
    [String]
    $exampleScheduledWithVariablesFilePath = "./tests/examples/ScheduledParam.yaml",
    [Parameter()]
    [String]
    $exampleScheduledParameterFilePath = "./tests/examples/ScheduledParam.params.yaml",
    [Parameter()]
    [String]
    $exampleIncidentConfigurationMissingFilePath = "./tests/examples/IncidentConfigurationMissing.yaml",
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
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "NRT.json"
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/NRT.yaml" -UseDisplayNameAsFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "NRTModifiedDomainFederationTrustSettings.json"
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/NRT.yaml" -UseIdAsFilename
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
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
            $APIVersion = "2022-09-01-preview"
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -APIVersion $APIVersion
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
            $YAMLSourceContent = Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | ConvertFrom-Yaml
            $SortedPropertiesNames = $armTemplate.resources[0].properties | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Sort-Object
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

        Context "ARM template resource properties" {

            It "Should have the correct kind" {
                $armTemplate.resources[0].kind | Should -Be "Scheduled"
            }

            It "Should have the correct severity" {
                $armTemplate.resources[0].properties.severity | Should -Be $YAMLSourceContent.severity
            }


            It "Should have the correct display name" {
                $armTemplate.resources[0].properties.displayName | Should -Be $YAMLSourceContent.name
            }

            It "Should have the correct description" {
                $armTemplate.resources[0].properties.description | Should -Be $YAMLSourceContent.description
            }

            It "Should have the correct tactics" {
                $armTemplate.resources[0].properties.tactics | Should -Be $YAMLSourceContent.tactics
            }

            It "Should have the correct queryFrequency" {
                $armTemplate.resources[0].properties.queryFrequency | Should -Be "PT6H"
            }

            It "Should have the correct queryPeriod" {
                $armTemplate.resources[0].properties.queryPeriod | Should -Be "PT6H"
            }

            # should have the correct api version
            It "Should have the correct api version" {
                $armTemplate.resources[0].apiVersion | Should -Be "2022-09-01-preview"
            }

            It "Should be in alphabetical order" {
                $armTemplate.resources[0].properties.psobject.members | Where-Object MemberType -EQ "NoteProperty" | Select-Object -ExpandProperty Name | Should -Be @($SortedPropertiesNames)
            }

        }
    }

    Context "Scheduled with parameter NamePrefix" -Tag Integration {
        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            $NamePrefix = "TestPrefix "
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -NamePrefix $NamePrefix
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the prefix at the start of the displayname" {
            $armTemplate.resources[0].properties.displayName | Should -Match "^TestPrefix "
        }

        It "Should have the prefix at the start of the displayname" {
            $armTemplate.resources[0].properties.displayName | Should -Be "TestPrefix Azure WAF matching for Log4j vuln(CVE-2021-44228)"
        }
    }

    Context "Scheduled with parameter Severity" -Tag Integration {
        BeforeDiscovery {
            $AllowedSeverities = @("Informational", "Low", "Medium", "High")
        }

        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -Severity "Informational"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the provided severity of Informational" {
            $armTemplate.resources[0].properties.severity | Should -Be "Informational"
        }

        It "Should work with severity <_>" -ForEach $AllowedSeverities {
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled-Severity.json" -Severity $_
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Should -HaveCount 1
            Get-ChildItem -Path "TestDrive:/" -Filter *.json | Select-Object -ExpandProperty Name | Should -Be "Scheduled-Severity.json"
        }

        It "Should fail when invalid severity is used" {
            { Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled-WrongSeverity.json" -Severity "SUPERIMPORTANT" } | Should -Throw
        }
    }

    Context "Scheduled with StartRunningAt parameter" {
        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            [datetime]$StartRunningAt = "2022-01-01T00:00:00Z"
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -StartRunningAt $StartRunningAt
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the correct startRunningAt" {
            ([datetime]$armTemplate.resources[0].properties.startTimeUtc).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") | Should -Be "2022-01-01T00:00:00Z"
        }

        It "Should abort on invalid startRunningAt format" {
            { Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -StartRunningAt "Tomorrow" } | Should -Throw
        }
    }

    Context "Scheduled with TTP sub-techniques and invalid techniques using old API" -Tag Integration {
        BeforeAll {
            Copy-Item -Path $exampleScheduledTTPFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -APIVersion "2023-10-01-preview"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
            $YAMLSourceContent = Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | ConvertFrom-Yaml
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.yaml -Force
            }
        }

        It "Should not have empty MITRE techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Not -BeNullOrEmpty -Because "Source YAML file has techniques defined"
        }

        It "Should have MITRE sub-techniques removed from techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Be "T1078" -Because "Microsoft Sentinel does not support sub-techniques in techniques property"
        }

        It "Should not contain obviously invalid MITRE techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Not -Contain "Z1001" -Because "Z1001 is not a valid technique"
        }

        It "Should not contain non-existent MITRE techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Not -Contain "T9912" -Because "T9912 is not an existend technique"
        }

        It "Should be of type array" {
            $armTemplate.resources[0].properties.techniques -is [System.Array] | Should -Be $true
        }
    }

    Context "Scheduled with TTP sub-techniques and invalid techniques supporting sub-techniques" -Tag Integration {
        BeforeAll {
            Copy-Item -Path $exampleScheduledTTPFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -APIVersion "2023-12-01-preview"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
            $YAMLSourceContent = Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | ConvertFrom-Yaml
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.yaml -Force
            }
        }

        It "Should not have empty MITRE techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Not -BeNullOrEmpty -Because "Source YAML file has techniques defined"
        }

        It "Should have MITRE sub-techniques removed from techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Be "T1078" -Because "Microsoft sub-techniques have their own property"
        }

        It "Should have MITRE sub-techniques" {
            $armTemplate.resources[0].properties.subTechniques | Should -Contain "T1078.003" -Because "Z1001.02 is not a valid sub-technique"
            $armTemplate.resources[0].properties.subTechniques | Should -Contain "T1078.004" -Because "Z1001.02 is not a valid sub-technique"
        }

        It "Should not contain obviously invalid MITRE techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Not -Contain "Z1001" -Because "Z1001 is not a valid technique"
        }

        It "Should not contain non-existent MITRE techniques" {
            $armTemplate.resources[0].properties.techniques | Should -Not -Contain "T9912" -Because "T9912 is not an existing technique"
        }

        It "Should be of type array" {
            $armTemplate.resources[0].properties.techniques -is [System.Array] | Should -Be $true
        }
    }

    Context "Scheduled with TTP invalid tactics" -Tag Integration {
        BeforeAll {
            Copy-Item -Path $exampleScheduledTTPFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
            $YAMLSourceContent = Get-Content -Path "TestDrive:/Scheduled.yaml" -Raw | ConvertFrom-Yaml
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.yaml -Force
            }
        }

        It "Should not have empty MITRE tactic" {
            $armTemplate.resources[0].properties.tactics | Should -Not -BeNullOrEmpty -Because "Source YAML file has tactics defined"
        }

        It "Should have MITRE sub-techniques removed" {
            $armTemplate.resources[0].properties.tactics | Should -Be "Persistence" -Because "Microsoft Sentinel only supports valid tactics"
        }

        It "Should not contain non-existent MITRE tactics" {
            $armTemplate.resources[0].properties.tactics | Should -Not -Contain "SneakySquirrel" -Because "Sneaky Squirrel is not an officially recognized tactic"
        }

        It "Should be of type array" {
            $armTemplate.resources[0].properties.tactics -is [System.Array] | Should -Be $true
        }
    }

    Context "Scheduled with disabled incident creation" {
        BeforeAll {
            Copy-Item -Path $exampleScheduledFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -DisableIncidentCreation
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the incident creation disabled" {
            $armTemplate.resources[0].properties.incidentConfiguration.createIncident | Should -Be $false
        }
    }

    Context "Scheduled with disabled incident creation and incidentConfiguration container missing" {
        BeforeAll {
            Copy-Item -Path $exampleIncidentConfigurationMissingFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -DisableIncidentCreation
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the incident creation disabled" {
            $armTemplate.resources[0].properties.incidentConfiguration.createIncident | Should -Be $false
        }

        It "Should not fail when incidentConfiguration is missing" {
            { Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -DisableIncidentCreation } | Should -Not -Throw
        }
    }

    Context "Scheduled with parameter file provided" {
        BeforeAll {
            Copy-Item -Path $exampleScheduledWithVariablesFilePath -Destination "TestDrive:/Scheduled.yaml" -Force
            Copy-Item -Path $exampleScheduledParameterFilePath -Destination "TestDrive:/ScheduledParam.params.yaml" -Force
            Convert-SentinelARYamlToArm -Filename "TestDrive:/Scheduled.yaml" -OutFile "TestDrive:/Scheduled.json" -ParameterFile "TestDrive:/ScheduledParam.params.yaml"
            $armTemplate = Get-Content -Path "TestDrive:/Scheduled.json" -Raw | ConvertFrom-Json
        }

        AfterEach {
            if ( -not $RetainTestFiles) {
                Remove-Item -Path "TestDrive:/*" -Include *.json -Force
            }
        }

        It "Should have the correct replaced parameter values" {
            $armTemplate.resources.properties.queryPeriod | Should -Be "PT1H"
            $armTemplate.resources.properties.queryFrequency | Should -Be "PT1H"
            $armTemplate.resources.properties.description | Should -Match "'403' or '404'"
        }

        It "Should have all new properties from parameter file" {
            $armTemplate.resources.properties.customDetails | Should -Not -BeNullOrEmpty
        }

        It "Should have the correct added query values" {
            $armTemplate.resources.properties.query | Should -Match "// Example description. Will be added to the beginning of the query."
            $armTemplate.resources.properties.query | Should -Match "// Example text that will be added to the end of the query."
        }

        It "Should have the correct variables replaced" {
            $armTemplate.resources.properties.query | Should -Match 'where Message in \("403","404"\)'
            $armTemplate.resources.properties.query | Should -Match 'where NumberOfErrors > 200'
        }
    }

    AfterAll {
        Remove-Module SentinelARConverter -Force
    }
}
