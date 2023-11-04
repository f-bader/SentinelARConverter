param(
    [Parameter()]
    [String]
    $exampleFilePath = "./tests/examples/Scheduled.json",
    [Parameter()]
    [String]
    $exampleMultipleFilePath = "./tests/examples/ScheduledMultiple.json",
    [Parameter()]
    [String]
    $NRTexampleFilePath = "./tests/examples/NRT.json",
    [Parameter()]
    [String]
    $mixedMultipleExampleFilePath = "./tests/examples/ScheduledNRTMultiple.json",
    [Parameter()]
    [String]
    $scheduledBadGuidExampleFilePath = "./tests/examples/ScheduledBadGuid.json",
    [Parameter()]
    [Switch]
    $RetainTestFiles = $false
)

BeforeDiscovery {
    if (Get-Module SentinelARConverter) {
        Remove-Module SentinelARConverter -Force
    }
    # Import the module for the tests
    $ModuleRoot = Split-Path -Path ./tests -Parent
    Import-Module -Name "$ModuleRoot/src/SentinelARConverter.psd1"

    # Single ART
    $ExampleFileName = Get-ChildItem $exampleFilePath | Select-Object -ExpandProperty Name
    $convertedExampleFilePath = "TestDrive:/$ExampleFileName" -replace "\.json$", ".yaml"
    $ARMTemplateContent = Get-Content $exampleFilePath -Raw
    $convertedExampleFileName = $ExampleFileName -replace "\.json$", ".yaml"

    # Multiple ART
    $exampleMultipleFileName = Get-ChildItem $exampleMultipleFilePath | Select-Object -ExpandProperty Name
    $exampleMultipleFileBaseName = Get-ChildItem $exampleMultipleFilePath | Select-Object -ExpandProperty BaseName
    $convertedMultipleExampleFilePath = "TestDrive:/$exampleMultipleFileName" -replace "\.json$", ".yaml"
    $MultipleExampleFile = Get-Item $exampleMultipleFilePath
    $convertedMultipleExampleFileName = $exampleMultipleFileName -replace "\.json$", ".yaml"
    $DiscoveryConvertedMultipleTemplateContent = Get-Content $exampleMultipleFilePath -Raw | ConvertFrom-Json
}

BeforeAll {
    # Import the module for the tests
    $ModuleRoot = Split-Path -Path ./tests -Parent
    Import-Module -Name "$ModuleRoot/src/SentinelARConverter.psd1"
}

Describe "Convert-SentinelARArmToYaml" {
    BeforeAll {
        Copy-Item -Path $exampleFilePath -Destination TestDrive:/ -Force
        Copy-Item -Path $scheduledBadGuidExampleFilePath -Destination TestDrive:/ -Force
    }

    AfterEach {
        Remove-Item -Path "TestDrive:/*" -Include *.yaml -Force
    }

    Context "When no valid path was passed" -Tag Unit {
        It "Throws an error" {
            { Convert-SentinelARArmToYaml -Filename "C:\Not\A\Real\File.json" } | Should -Throw "File not found"
        }
    }

    Context "When no resources are present in the passed ARM template" -Tag Unit {

        It "Throws an error" {
            {
                $ARMTemplateContent |
                ConvertFrom-Json |
                Select-Object "`$schema", "contentVersion", "parameters" |
                ConvertTo-Json -Depth 99 |
                Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath
            } | Should -Throw "This template contains no Analytics Rules or resources"
        }
    }

    Context "If an invalid template id is provided in the analytics rule resources block" -Tag Unit {
        It "Creates a new guid" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/ScheduledBadGuid.json" -OutFile $convertedExampleFilePath

            $convertedExampleFilePath | Should -Not -FileContentMatch 'id: z-4a5f-4d27-8a26-b60a7952d5af'
        }
    }

    Context "If redundant ARM Properties are present in the rules" -Tag Unit {
        It "Removes the redundant ARM properties" {
            $convertedExampleFilePath = "TestDrive:/$convertedExampleFileName"

            $ARMTemplateContent | Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath

            $convertedExampleFilePath | Should -Not -FileContentMatch '^enabled: true'
        }
    }

    Context "When the template contains timespan values" -Tag Unit {

        It "Properly converts the units" {
            $convertedExampleFilePath = "TestDrive:/$convertedExampleFileName"

            $ARMTemplateContent | Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath

            $convertedExampleFilePath | Should -Not -FileContentMatch '^suppressionDuration: PT'
            $convertedExampleFilePath | Should -Not -FileContentMatch '^queryPeriod: PT'
            $convertedExampleFilePath | Should -Not -FileContentMatch '^queryFrequency: PT'
        }
    }

    Context "When specific propertynames/comparison properties are found on AR objects" -Tag Unit {

        BeforeDiscovery {
            $convertedJSON = Get-Content -Path $exampleFilePath -Raw | ConvertFrom-Json
            foreach ($resource in $convertedJSON["resources"]) {
                if (-not $resource.properties.ContainsKey("triggerOperator")) {
                    Write-Warning "This template does not contain a triggerOperator property. Cannot test conversion of comparison operators."
                    $CannotCheckComparisonOperators = $true
                }
            }
        }

        BeforeEach {
            $ARMTemplateContent = Get-Content -Path "TestDrive:/$ExampleFileName" -Raw
            $ARMTemplateContent | Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath
        }

        It "Properly converts the propertynames" {

            $convertedExampleFilePath | Should -Not -FileContentMatch '^displayName'
            $convertedExampleFilePath | Should -Not -FileContentMatch '^alertRuleTemplateName'
            $convertedExampleFilePath | Should -Not -FileContentMatch '^templateVersion'
            $convertedExampleFilePath | Should -Not -FileContentMatch '^techniques'
        }

        It "Properly converts the comparison operators" -Skip:$CannotCheckComparisonOperators {
            $convertedExampleFilePath | Should -Not -FileContentMatch 'GreaterThan$'
            $convertedExampleFilePath | Should -Not -FileContentMatch 'Equals$'
            $convertedExampleFilePath | Should -Not -FileContentMatch 'GreaterThanOrEqual$'
            $convertedExampleFilePath | Should -Not -FileContentMatch 'LessThan$'
            $convertedExampleFilePath | Should -Not -FileContentMatch 'LessThanOrEqual$'
        }
    }
    Context "Properly handles Force situations" -Tag Unit {
        BeforeEach {
            "this is not an ART" | Out-File -FilePath $convertedExampleFilePath -Force
        }

        It "Shouldn't overwrites existing files when Force is not used" {
            { Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath -Filename "TestDrive:/$ExampleFileName" } | Should -Throw
            $convertedExampleFilePath | Should -FileContentMatch "^this is not an ART"
        }
        It "Shouldn't overwrites existing files when Force is not used and throw an exception" {
            { Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath -Filename "TestDrive:/$ExampleFileName" } | Should -Throw
        }
        It "Should overwrites existing files when Force is used and shouldn't throw an exception" {
            { Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath -Filename "TestDrive:/$ExampleFileName" -Force } | Should -Not -Throw
            $convertedExampleFilePath | Should -Not -FileContentMatch "^this is not an ART"
        }
        It "Should overwrites existing files when Force is used and shouldn't throw an exception" {
            { Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath -Filename "TestDrive:/$ExampleFileName" -Force } | Should -Not -Throw
        }
    }
}

Describe "Single File Testcases" {

    BeforeAll {
        Copy-Item -Path $exampleFilePath -Destination TestDrive:/ -Force
    }

    AfterEach {
        Remove-Item -Path "TestDrive:/*" -Include *.yaml -Force
    }

    Context "When converting a Sentinel Alert Rule ARM template to YAML" -Tag Integration {
        It "Converts a Scheduled Query Alert Sentinel Alert Rule ARM template to a YAML-file" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = "TestDrive:/$ExampleFileName"
                OutFile  = "TestDrive:/$convertedExampleFileName"
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            Get-Content $convertSentinelARArmToYamlSplat.OutFile | Should -Not -BeNullOrEmpty
        }
    }

    Context "If UseOriginalFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template" {
            $convertSentinelARArmToYamlSplat = @{
                Filename            = "TestDrive:/$ExampleFileName"
                UseOriginalFilename = $true
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            $convertedExampleFilePath | Should -Exist
        }

        It "Should use the original filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename            = "TestDrive:/$ExampleFileName"
                UseOriginalFilename = $true
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat

            $path = $convertSentinelARArmToYamlSplat.Filename -replace "\.json$", ".yaml"

            Get-ChildItem $convertedExampleFilePath | Should -Match $convertedExampleFileName
        }
    }

    Context "If UseDisplayNameAsFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template with the display name as filename" {
            Copy-Item -Path $exampleFilePath -Destination "TestDrive:\Scheduled.json" -Force
            $convertSentinelARArmToYamlSplat = @{
                Filename                 = "TestDrive:/Scheduled.json"
                UseDisplayNameAsFilename = $true
            }
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat

            "TestDrive:/AzureWAFMatchingForLog4jVulnCVE202144228.yaml" | Should -Exist
        }
    }

    Context "If UseIdAsFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template with the id as filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename        = "TestDrive:/Scheduled.json"
                UseIdAsFilename = $true
            }

            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat

            "TestDrive:/6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.yaml" | Should -Exist
            Remove-Item "TestDrive:/6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.yaml" -Force
        }
    }
    Context "If an ARM template file content is passed via pipeline" -Tag Integration {
        It "Should convert a Scheduled Query Alert Sentinel Alert Rule ARM template to a YAML file" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = "TestDrive:/$ExampleFileName"
                OutFile  = $convertedExampleFileName
            }
            Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml -OutFile $convertedExampleFilePath
            Test-Path -Path $convertedExampleFilePath | Should -Be $True
        }
    }

    Context "If neither OutFile or UseOriginalFilename is passed" -Tag Integration {
        It "Outputs YAML to the console" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = "TestDrive:/$ExampleFileName"
            }

            $output = (Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml)
            $output | Should -Not -BeNullOrEmpty
            Get-ChildItem -Path "TestDrive:/" -Recurse -Filter $convertedExampleFileName | Should -BeNullOrEmpty
        }
    }

    Context "If neither OutFile or UseOriginalFilename is passed" -Tag Integration {
        It "Outputs YAML to the console (single alert)" {
            $output = (Get-Content -Path "TestDrive:/$ExampleFileName" -Raw | Convert-SentinelARArmToYaml)
            $output | Should -Not -BeNullOrEmpty
            Get-ChildItem -Path TestDrive:/ -Recurse -Filter $convertedExampleFileName | Should -BeNullOrEmpty
        }
    }
}

Describe "Multi File Testcases" -Skip:(($DiscoveryConvertedMultipleTemplateContent.resources).Count -lt 2) {

    BeforeEach {
        Get-ChildItem TestDrive:/ -Filter *.yaml | Remove-Item -Recurse -Force
        Copy-Item -Path $exampleMultipleFilePath -Destination TestDrive:/ -Force
    }
    AfterEach {
        if (-not $RetainTestFiles) {
            Get-ChildItem TestDrive:/ | Remove-Item -Recurse -Force
        }
    }

    Context "When converting a Sentinel Alert Rule ARM template with multiple alerts to YAML" -Tag Integration {
        BeforeDiscovery {
            # There always will be at least once file created, but we don't name the first one with a suffix
            # By subtracting 1 from the amount of resources, we can use that as a range for the expected amount of files
            $DiscoveryExpectedFilesAmount = (0..($DiscoveryConvertedMultipleTemplateContent.resources.Count - 1))
        }
        BeforeEach {
            $convertSentinelARArmToYamlSplat = @{
                Filename = "TestDrive:/$exampleMultipleFileName"
                OutFile  = "TestDrive:/$convertedMultipleExampleFileName"
            }
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
        }
        It "Converts to multiple YAML-file with the specified suffix (Alert #<_>)" -ForEach $DiscoveryExpectedFilesAmount {
            if ($_ -eq 0) {
                Get-Content ($convertSentinelARArmToYamlSplat.OutFile -replace "\.yaml$", ".yaml") | Should -Not -BeNullOrEmpty
            } else {
                Get-Content ($convertSentinelARArmToYamlSplat.OutFile -replace "\.yaml$", "_$_.yaml") | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "If UseOriginalFilename was passed" -Tag Integration {
        BeforeDiscovery {
            # There always will be at least one file created, but we don't name the first one with a suffix
            # By subtracting 1 from the amount of resources, we can use that as a range for the expected amount of files
            $DiscoveryExpectedFilesAmount = (0..($DiscoveryConvertedMultipleTemplateContent.resources.Count - 1))

            $Discoveryfilenames = @(foreach ($entry in ($DiscoveryExpectedFilesAmount -NE 0)) {
                    $exampleMultipleFileBaseName + "_$entry" + ".yaml"
                }
            )
            $Discoveryfilenames += $exampleMultipleFileBaseName + ".yaml"
        }

        BeforeEach {
            $convertSentinelARArmToYamlSplat = @{
                Filename            = "TestDrive:/$exampleMultipleFileName"
                UseOriginalFilename = $true
            }
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            $exampleParent = "TestDrive:/$exampleMultipleFileName" | Split-Path -Parent
        }

        AfterAll {
            if (-not $RetainTestFiles) {
                Get-ChildItem TestDrive:/ | Remove-Item -Recurse -Force
            }
        }
        It "Creates a yaml file in the same folder as the ARM template (<_>)" -ForEach $Discoveryfilenames {
            Get-Content (Join-Path -Path $exampleParent -ChildPath $_) | Should -Not -BeNullOrEmpty
        }

        It "Should use the original filename (<_>)" -ForEach $Discoveryfilenames {
            (Get-ChildItem $exampleParent -Filter *.yaml ).Name | Should -Match "^$($MultipleExampleFile.BaseName)"
        }

        It "Should suffix the original filename with a number if multiple yaml files are created (<_>)" -ForEach $Discoveryfilenames {
            (Get-ChildItem $exampleParent/* -Filter *.yaml -Exclude $convertedMultipleExampleFileName).Name | Should -Match "^$($MultipleExampleFile.BaseName)"
        }
    }

    Context "If UseDisplayNameAsFilename was passed" -Tag Integration {
        BeforeDiscovery {
            $DiscoveryfileNames = foreach ($displayname in $DiscoveryConvertedMultipleTemplateContent.resources.properties.displayName) {
                # Use the display name of the Analytics Rule as filename
                $FileName = $displayname -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                ((Get-Culture).TextInfo.ToTitleCase($FileName) -Replace ' ') + '.yaml'
            }
        }

        BeforeEach {
            $convertSentinelARArmToYamlSplat = @{
                Filename                 = "TestDrive:/$exampleMultipleFileName"
                UseDisplayNameAsFilename = $true
            }
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            $exampleParent = "TestDrive:/"

            $fileNames = foreach ($displayname in $DiscoveryConvertedMultipleTemplateContent.resources.properties.displayName) {
                # Use the display name of the Analytics Rule as filename
                $FileName = $displayname -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                ((Get-Culture).TextInfo.ToTitleCase($FileName) -Replace ' ') + '.yaml'
            }
        }

        It "Creates yaml files in the same folder as the ARM template with the display name as filename (<_>)" -ForEach $DiscoveryfileNames {
            (Get-ChildItem $exampleParent/* -Filter *.yaml -Exclude $convertedMultipleExampleFileName).Name | Should -BeIn $fileNames
        }
    }
    Context "If UseIdAsFilename was passed" -Tag Integration {
        BeforeDiscovery {
            $DiscoveryfileNames = foreach ($displayname in $DiscoveryConvertedMultipleTemplateContent.resources.properties.displayName) {
                # Use the display name of the Analytics Rule as filename
                $FileName = $displayname -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                ((Get-Culture).TextInfo.ToTitleCase($FileName) -Replace ' ')
            }
        }
        BeforeEach {
            $convertSentinelARArmToYamlSplat = @{
                Filename        = "TestDrive:/$exampleMultipleFileName"
                UseIdAsFilename = $true
            }
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            $exampleParent = "TestDrive:/"
            [string[]]$ids = @(
                foreach ($resource in $DiscoveryConvertedMultipleTemplateContent.resources) {
                    $resource.id -match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | Out-Null
                    $matches[0]
                }
            )
        }
        It "Creates a yaml file in the same folder as the ARM template with the id as filename (<_>)" -ForEach $DiscoveryfileNames {
            (Get-ChildItem -Path $exampleParent -Filter *.yaml).BaseName | Should -BeIn $ids
        }
    }

    Context "If an ARM template file content, containing multiple ARTs, is passed via pipeline using OutFile" -Tag Integration {

        BeforeDiscovery {
            # There always will be at least once file created, but we don't name the first one with a suffix
            # By subtracting 1 from the amount of resources, we can use that as a range for the expected amount of files
            $DiscoveryExpectedFilesAmount = (0..($DiscoveryConvertedMultipleTemplateContent.resources.Count - 1))
        }
        BeforeEach {
            $convertSentinelARArmToYamlSplat = @{
                Filename = "TestDrive:/$exampleMultipleFileName"
                OutFile  = "TestDrive:/$convertedMultipleExampleFileName"
            }
            Get-Content $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml -OutFile $convertSentinelARArmToYamlSplat.OutFile -Force
        }
        It "Converts to multiple YAML-file with the specified suffix (Alert #<_> <convertedMultipleExampleFileName>)" -ForEach $DiscoveryExpectedFilesAmount {
            if ($_ -eq 0) {
                Get-Content ($convertSentinelARArmToYamlSplat.OutFile -replace "\.yaml$", ".yaml") | Should -Not -BeNullOrEmpty
            } else {
                Get-Content ($convertSentinelARArmToYamlSplat.OutFile -replace "\.yaml$", "_$_.yaml") | Should -Not -BeNullOrEmpty
            }
        }
    }
    Context "If an ARM template file content, containing multiple ARTs, is passed via pipeline using UseDisplayNameAsFilename" -Tag Integration {

        BeforeDiscovery {
            $DiscoveryfileNames = foreach ($displayname in $DiscoveryConvertedMultipleTemplateContent.resources.properties.displayName) {
                # Use the display name of the Analytics Rule as filename
                $FileName = $displayname -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                ((Get-Culture).TextInfo.ToTitleCase($FileName) -Replace ' ') + '.yaml'
            }
        }
        BeforeEach {
            $testOutputPath = "TestDrive:/"
            Get-Content "TestDrive:/$exampleMultipleFileName" -Raw | Convert-SentinelARArmToYaml -UseDisplayNameAsFilename -Directory $testOutputPath

            $fileNames = foreach ($displayname in $DiscoveryConvertedMultipleTemplateContent.resources.properties.displayName) {
                # Use the display name of the Analytics Rule as filename
                $FileName = $displayname -Replace '[^0-9A-Z]', ' '
                # Convert To CamelCase
                ((Get-Culture).TextInfo.ToTitleCase($FileName) -Replace ' ') + '.yaml'
            }
        }
        It "Creates yaml files in the same folder as the ARM template with the display name as filename (<_>)" -ForEach $DiscoveryfileNames {
            (Get-ChildItem $testOutputPath/* -Filter *.yaml -Exclude $convertedMultipleExampleFileName).Name | Should -BeIn $fileNames
        }
    }

    Context "If an ARM template file content, containing multiple ARTs, is passed via pipeline using UseIdAsFilename" -Tag Integration {

        BeforeDiscovery {
            $DiscoveryfileNames = foreach ($resourcesId in $DiscoveryConvertedMultipleTemplateContent.resources.id) {
                if ($resourcesId -match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}") {
                    $ID = $Matches[0]
                }
                $ID
            }
        }
        BeforeEach {
            $testOutputPath = "TestDrive:/"
            Get-Content "TestDrive:/$exampleMultipleFileName" -Raw | Convert-SentinelARArmToYaml -UseIdAsFilename -Directory $testOutputPath

            [string[]]$ids = @(
                foreach ($resource in $DiscoveryConvertedMultipleTemplateContent.resources) {
                    $resource.id -match "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" | Out-Null
                    $matches[0]
                }
            )
        }
        It "Creates yaml files in the same folder as the ARM template with the display name as filename (<_>)" -ForEach $DiscoveryfileNames {
            (Get-ChildItem $testOutputPath/* -Filter *.yaml -Exclude $convertedMultipleExampleFileName).BaseName | Should -BeIn $ids
        }
    }

    Context "If neither OutFile or UseOriginalFilename is passed" -Tag Integration {
        It "Outputs YAML to the console (multi alert)" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = "TestDrive:/$exampleMultipleFileName"
            }
            $output = (Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml)
            $output[0] | Should -Not -BeNullOrEmpty
            $output[1] | Should -Not -BeNullOrEmpty
            Get-ChildItem -Path TestDrive:/ -Recurse -Filter $convertedExampleFileName | Should -BeNullOrEmpty
        }
    }
}

Describe "Simple example tests" {
    Context "Single example tests" -Tag Integration {
        BeforeAll {
            New-Item TestDrive:/Single/ -ItemType Directory | Out-Null
            Copy-Item -Path $exampleFilePath -Destination TestDrive:/Single/ -Force
        }
        AfterEach {
            Remove-Item -Path "TestDrive:/Single/*" -Include *.yaml -Force
        }
        It "No Pipeline and OutFile" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Single/Scheduled.json" -OutFile "TestDrive:/Single/Scheduled.yaml"
            Get-ChildItem -Path "TestDrive:/Single/*" -Include *.yaml | Should -HaveCount 1
        }
        It "No Pipeline and UseOriginalFilename" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Single/Scheduled.json" -UseOriginalFilename
            Get-ChildItem -Path "TestDrive:/Single/*" -Include *.yaml | Should -HaveCount 1
        }
        It "Pipeline and OutFile" {
            Get-Content -Path "TestDrive:/Single/Scheduled.json" -Raw | Convert-SentinelARArmToYaml -OutFile "TestDrive:/Single/Scheduled.yaml"
            Get-ChildItem -Path "TestDrive:/Single/*" -Include *.yaml | Should -HaveCount 1
        }
    }
    Context "Multiple example tests" -Tag Integration {
        BeforeAll {
            New-Item TestDrive:/Multiple/ -ItemType Directory | Out-Null
            Copy-Item -Path $exampleMultipleFilePath -Destination TestDrive:/Multiple/ -Force
        }
        AfterEach {
            Remove-Item -Path "TestDrive:/Multiple/*" -Include *.yaml -Force
        }
        It "No Pipeline and Outfile" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Multiple/ScheduledMultiple.json" -OutFile "TestDrive:/Multiple/ScheduledMultiple.yaml"
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
        It "No Pipeline and UseOriginalFilename" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Multiple/ScheduledMultiple.json" -UseOriginalFilename
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
        It "No Pipeline and UseDisplayNameAsFilename" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Multiple/ScheduledMultiple.json" -UseDisplayNameAsFilename
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
        It "No Pipeline and UseIdAsFilename" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Multiple/ScheduledMultiple.json" -UseIdAsFilename
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
        It "Pipeline and OutFile" {
            Get-Content -Path "TestDrive:/Multiple/ScheduledMultiple.json" -Raw | Convert-SentinelARArmToYaml -OutFile "TestDrive:/Multiple/ScheduledMultiple.yaml"
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
        It "Pipeline and UseDisplayNameAsFilename" {
            Get-Content -Path "TestDrive:/Multiple/ScheduledMultiple.json" -Raw | Convert-SentinelARArmToYaml -UseDisplayNameAsFilename -Directory "TestDrive:/Multiple/"
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
        It "Pipeline and UseIdAsFilename" {
            Get-Content -Path "TestDrive:/Multiple/ScheduledMultiple.json" -Raw | Convert-SentinelARArmToYaml -UseIdAsFilename -Directory "TestDrive:/Multiple/"
            Get-ChildItem -Path "TestDrive:/Multiple/*" -Include *.yaml | Should -HaveCount 2
        }
    }
    Context "Content tests" -Tag Integration {
        BeforeAll {
            New-Item TestDrive:/Content/ -ItemType Directory | Out-Null
            Copy-Item -Path $exampleFilePath -Destination TestDrive:/Content/ -Force
            Copy-Item -Path $NRTexampleFilePath -Destination TestDrive:/Content/ -Force
            Copy-Item -Path $mixedMultipleExampleFilePath -Destination TestDrive:/Content/ -Force
        }
        AfterEach {
            Remove-Item -Path "TestDrive:/Content/*" -Include *.yaml -Force
        }
        It "Converts a Scheduled Query Rule Sentinel Alert Rule ARM template to a YAML-file" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Content/Scheduled.json" -OutFile "TestDrive:/Content/Scheduled.yaml"
            Get-ChildItem -Path "TestDrive:/Content/*" -Include *.yaml | Should -HaveCount 1
            'TestDrive:/Content/Scheduled.yaml' | Should -FileContentMatch 'kind: Scheduled'
        }
        It "Converts a Near Real Time Alert Sentinel Alert Rule ARM template to a YAML-file" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Content/NRT.json" -OutFile "TestDrive:/Content/NRT.yaml"
            Get-ChildItem -Path "TestDrive:/Content/*" -Include *.yaml | Should -HaveCount 1
            'TestDrive:/Content/NRT.yaml' | Should -FileContentMatch 'kind: NRT'
        }
        It "Converts a mixed export of NRT and Scheduled to seperate YAML-files" {
            Convert-SentinelARArmToYaml -Filename "TestDrive:/Content/ScheduledNRTMultiple.json" -UseIdAsFilename
            Get-ChildItem -Path "TestDrive:/Content/*" -Include *.yaml | Should -HaveCount 2
            'TestDrive:/Content/1baffb8f-9fc6-468e-aff6-91da707ec37d.yaml' | Should -FileContentMatch 'kind: Scheduled'
            'TestDrive:/Content/4a4364e4-bd26-46f6-a040-ab14860275f8.yaml' | Should -FileContentMatch 'kind: NRT'
        }
    }
}

AfterAll {
    if (-not $RetainTestFiles) {
        Remove-Item -Path "TestDrive:/" -Recurse -Force
        Remove-PSDrive TestDrive -Force
    }
    if ( Get-Module -Name SentinelARConverter ) {
        Remove-Module -Name SentinelARConverter -Force
    }
}

