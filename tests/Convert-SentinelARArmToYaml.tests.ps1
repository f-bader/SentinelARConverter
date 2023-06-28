param(
    [Parameter()]
    [String]
    $exampleFilePath = "$PSScriptRoot/examples/Scheduled.json",
    [Parameter()]
    [String]
    $exampleMultipleFilePath = "$PSScriptRoot/examples/Scheduled.json",
    [Parameter()]
    [Switch]
    $RetainTestFiles = $false
)

BeforeAll {

    # Import the module for the tests
    $ModuleRoot = $PSScriptRoot | Split-Path -Parent
    Import-Module -Name "$ModuleRoot/src/SentinelARConverter.psd1"

    # Create a test output folder
    New-Item -ItemType Directory -Path "$PSScriptRoot/testOutput" -Force | Out-Null

    # Do fileconversion
    # Single ART
    $convertedExampleFilePath = $exampleFilePath -replace "\.json$", ".yaml"
    $ARMTemplateContent = Get-Content $exampleFilePath -Raw
    $outputPath = $convertedExampleFilePath -replace "/examples/", "/testOutput/"
    $convertedExampleFilePath -match "\w*\.yaml$"
    $convertedExampleFileName = $matches[0]
}

Describe "Convert-SentinelARArmToYaml" {

    BeforeEach {
        Get-ChildItem $PSScriptRoot/testOutput/ | Remove-Item -Recurse -Force
        Get-ChildItem $PSScriptRoot/examples -Filter *.yaml | Remove-Item -Force
    }
    
    AfterEach {
        if (-not $RetainTestFiles){
            Get-ChildItem $PSScriptRoot/testOutput/ | Remove-Item -Recurse -Force
            Get-ChildItem -Path $PSScriptRoot/examples -Filter *.yaml | Remove-Item -Force
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
            } | Should -Throw "This template contains no Analytics Rules"
        }
    }

    Context "When other resourcetypes are present in the passed ARM template" -Tag Unit {

        It "Throws an error" {
            $notAnAlertRuleTemplate = @{
                "type" = 'Microsoft.Logic/workflows'
            }

            {
                $template = $ARMTemplateContent |
                    ConvertFrom-Json -Depth 99 -AsHashtable
                $template.resources += $notAnAlertRuleTemplate
                
                $template |
                    ConvertTo-Json -Depth 99 |
                    Convert-SentinelARArmToYaml -OutFile $outputPath
            } | Should -Throw "This template contains resources other than Analytics Rules"
        }
    }

    Context "If an invalid template id is provided in the analytics rule resources block" -Tag Unit {
        #TODO: Uses a specific file reference
        It "Creates a new guid" {
            Convert-SentinelARArmToYaml -Filename "$PSScriptRoot/examples/ScheduledBadGuid.json" -OutFile $outputPath

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

        BeforeEach {
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

}

Describe "Single File Testcases" {

    BeforeEach {
        Get-ChildItem $PSScriptRoot/testOutput/ | Remove-Item -Recurse -Force
        Get-ChildItem $PSScriptRoot/examples -Filter *.yaml | Remove-Item -Force
    }
    
    AfterEach {
        if (-not $RetainTestFiles){
            Get-ChildItem $PSScriptRoot/testOutput/ | Remove-Item -Recurse -Force
            Get-ChildItem -Path $PSScriptRoot/examples -Filter *.yaml | Remove-Item -Force
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
            } | Should -Throw "This template contains no Analytics Rules"
        }
    }

    Context "When converting a Sentinel Alert Rule ARM template to YAML" -Tag Integration {
        It "Should convert a Scheduled Query Alert Sentinel Alert Rule ARM template to a YAML-file" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = $exampleFilePath
                OutFile  = "$PSScriptRoot/testOutput/$convertedExampleFileName"
            }
    
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            Get-Content $convertSentinelARArmToYamlSplat.OutFile | Should -Not -BeNullOrEmpty
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
    
    Context "If UseDisplayNameAsFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template with the display name as filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename                 = "$PSScriptRoot/examples/Scheduled.json"
                UseDisplayNameAsFilename = $true
            }
    
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
    
            "$PSScriptRoot/examples/AzureWAFMatchingForLog4jVulnCVE202144228.yaml" | Should -Exist
            Remove-Item "$PSScriptRoot/examples/AzureWAFMatchingForLog4jVulnCVE202144228.yaml" -Force
        }
    
    }
    
    Context "If UseIdAsFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template with the id as filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename        = "$PSScriptRoot/examples/Scheduled.json"
                UseIdAsFilename = $true
            }
    
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
    
            "$PSScriptRoot/examples/6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.yaml" | Should -Exist
            Remove-Item "$PSScriptRoot/examples/6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.yaml" -Force
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
    
            Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml -OutFile $outputPath
    
            Test-Path -Path $outputPath | Should -Be $True
        }
    }
}

Describe "Multi File Testcases" {
<#
# Use cases

# Old

- Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -OutFile "C:\Temp\MyRule.yaml"
- Expect single file: MyRule.yaml
- Works

- Get-Content -Path "C:\Temp\MyRule.json" -Raw | Convert-SentinelARArmToYaml -OutFile "C:\Temp\MyRule.yaml"
- Expect single file: MyRule.yaml
- Works

- Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseOriginalFilename
- Expect single file: MyRule.yaml
- Works

- Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseDisplayNameAsFilename
- Expect single file: Displayname1.yaml
- Works

- Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseIdAsFilename
- Expect single file: 734075d4-1974-4318-b262-5268e36e4f35.yaml
- Works

# Multiple

- Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -OutFile "C:\Temp\MyRule.yaml"
- Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -OutFile "C:\Temp\MyRule.yaml"
- Expect multiple files: MyRule.yaml, MyRule_1.yaml, MyRule_2.yaml etc.
- Works

- Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseOriginalFilename
- Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -UseOriginalFilename
- Expect multiple files: Multiple.yaml, Multiple_1.yaml, Multiple_2.yaml
- Works

- Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -UseDisplayNameAsFilename
- Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -UseDisplayNameAsFilename
- Expect multiple files: Displayname1.yaml, Displayname2.yaml, Displayname3.yaml
- Works

- Convert-SentinelARArmToYaml -Filename "C:\Temp\MyRule.json" -UseIdAsFilename
- Convert-SentinelARArmToYaml -Filename "C:\Temp\Multiple.json" -UseDisplayNameAsFilename
- Expect multiple files: 734075d4-1974-4318-b262-5268e36e4f35.yaml, 734075d4-1974-4318-b262-5268e36e4f34.yaml, Displayname3.yaml
- Works

- Get-Content -Path "C:\Temp\MyRule.json" -Raw | Convert-SentinelARArmToYaml -OutFile "C:\Temp\MyRule.yaml"
- Get-Content -Path "C:\Temp\Multiple.json" -Raw | Convert-SentinelARArmToYaml -OutFile "C:\Temp\MyRule.yaml"
- Expect multiple files: MyRule.yaml, MyRule_1.yaml, MyRule_2.yaml etc.
- Works



- Get-Content -Path "C:\Temp\MyRule.json" -Raw | Convert-SentinelARArmToYaml -Directory "C:\Temp\"  -UseDisplayNameAsFilename
- Expect single file: Displayname1.yaml
- Works

- Get-Content -Path "C:\Temp\MyRule.json" -Raw | Convert-SentinelARArmToYaml -Directory "C:\Temp\" -UseIdAsFilename
- Expect single file: 734075d4-1974-4318-b262-5268e36e4f35.yaml
- Works

- Get-Content -Path "C:\Temp\Multiple.json" -Raw | Convert-SentinelARArmToYaml -Directory "C:\Temp\"  -UseDisplayNameAsFilename
- Expect single file: Displayname1.yaml
- Works

- Get-Content -Path "C:\Temp\Multiple.json" -Raw | Convert-SentinelARArmToYaml -Directory "C:\Temp\" -UseIdAsFilename
- Expect single file: 734075d4-1974-4318-b262-5268e36e4f35.yaml
- Works


# get-content /workspaces/SentinelARConverter/tests/examples/Scheduled.json -Raw | 
#     Convert-SentinelARArmToYaml -Directory /workspaces/SentinelARConverter/tests/testOutput/ -UseIdAsFilename -Verbose

# get-content /workspaces/SentinelARConverter/tests/examples/Scheduled.json -Raw | 
#     Convert-SentinelARArmToYaml -Directory /workspaces/SentinelARConverter/tests/testOutput/ -UseDisplayNameAsFilename -Verbose


# get-content /workspaces/SentinelARConverter/tests/examples/ScheduledMultiple.json -Raw | 
#     Convert-SentinelARArmToYaml -Directory /workspaces/SentinelARConverter/tests/testOutput/ -UseIdAsFilename -Verbose

# get-content /workspaces/SentinelARConverter/tests/examples/ScheduledMultiple.json -Raw | 
#     Convert-SentinelARArmToYaml -Directory /workspaces/SentinelARConverter/tests/testOutput/ -UseDisplayNameAsFilename -Verbose

#>

    BeforeEach {
        Get-ChildItem $PSScriptRoot/testOutput/ | Remove-Item -Recurse -Force
        Get-ChildItem $PSScriptRoot/examples -Filter *.yaml | Remove-Item -Force
    }
    
    AfterEach {
        if (-not $RetainTestFiles){
            Get-ChildItem $PSScriptRoot/testOutput/ | Remove-Item -Recurse -Force
            Get-ChildItem -Path $PSScriptRoot/examples -Filter *.yaml | Remove-Item -Force
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
            } | Should -Throw "This template contains no Analytics Rules"
        }
    }

    Context "When converting a Sentinel Alert Rule ARM template to YAML" -Tag Integration {
        It "Should convert a Scheduled Query Alert Sentinel Alert Rule ARM template to a YAML-file" {
            $convertSentinelARArmToYamlSplat = @{
                Filename = $exampleFilePath
                OutFile  = "$PSScriptRoot/testOutput/$convertedExampleFileName"
            }
    
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
            Get-Content $convertSentinelARArmToYamlSplat.OutFile | Should -Not -BeNullOrEmpty
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
    
    Context "If UseDisplayNameAsFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template with the display name as filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename                 = "$PSScriptRoot/examples/Scheduled.json"
                UseDisplayNameAsFilename = $true
            }
    
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
    
            "$PSScriptRoot/examples/AzureWAFMatchingForLog4jVulnCVE202144228.yaml" | Should -Exist
            Remove-Item "$PSScriptRoot/examples/AzureWAFMatchingForLog4jVulnCVE202144228.yaml" -Force
        }
    
    }
    
    Context "If UseIdAsFilename was passed" -Tag Integration {
        It "Creates a yaml file in the same folder as the ARM template with the id as filename" {
            $convertSentinelARArmToYamlSplat = @{
                Filename        = "$PSScriptRoot/examples/Scheduled.json"
                UseIdAsFilename = $true
            }
    
            Convert-SentinelARArmToYaml @convertSentinelARArmToYamlSplat
    
            "$PSScriptRoot/examples/6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.yaml" | Should -Exist
            Remove-Item "$PSScriptRoot/examples/6bb8e22c-4a5f-4d27-8a26-b60a7952d5af.yaml" -Force
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
    
            Get-Content -Path $convertSentinelARArmToYamlSplat.Filename -Raw | Convert-SentinelARArmToYaml -OutFile $outputPath
    
            Test-Path -Path $outputPath | Should -Be $True
        }
    }
}

AfterAll {
    if (-not $RetainTestFiles) {
        Remove-Item -Path "$PSScriptRoot/testOutput/" -Recurse -Force
    }
}

