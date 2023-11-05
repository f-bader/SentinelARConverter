![SentinelARConverter Banner](/images/banner.png)

# Sentinel Analytics Rule converter

## Installation

```PowerShell
Install-Module SentinelARConverter
```

## How to convert?

You can convert a Sentinel Analytics rule in the [YAML format](https://github.com/Azure/Azure-Sentinel/wiki/Query-Style-Guide) to an [Azure ARM template](https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/alertrules?pivots=deployment-language-arm-template) or vice versa.

For more information about this cmdlet, please [read my blog post](https://cloudbrothers.info/en/convert-sentinel-analytics-rules/).

### ARM to YAML

```PowerShell
Convert-SentinelARArmToYaml -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" -UseOriginalFilename
```

This will create a new file named `Azure_Sentinel_analytic_rule.yaml` without any other interaction.

```PowerShell
Convert-SentinelARArmToYaml -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" -UseDisplayNameAsFilename
```

This will create a new file named `DisplayNameOfTheAnalyticsRule.yaml` without any other interaction.

```PowerShell
Convert-SentinelARArmToYaml -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" -UseIdAsFilename
```

This will create a new file named `UUID-OfTheAnalyticsRule.yaml` without any other interaction.

```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" | Convert-SentinelARArmToYaml -OutFile "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml"
```

In this case you can pipe the ARM template content to the cmdlet, but you must define a output file if it should be written to disk

```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" | Convert-SentinelARArmToYaml
```

If no output file path is given, the output will be send to `stdout`

All those work regardless of the content of the ARM file. If the ARM template contains is more than one Analytics Rule all rules are converted. \
If you use the `-UseOriginalFilename` or `-OutFile` all analytics rules after the first are named `filename_n.yaml`

![Workflow to export multiple Analytic Rules from Sentinel and convert them to YAML in one go.](/images/Convert-SentinelARArmToYaml-Multiple.gif)

### YAML to ARM

```PowerShell
Convert-SentinelARYamlToArm -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" -UseOriginalFilename
```

This will create a new file named `Azure_Sentinel_analytic_rule.json` without any other interaction.


```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" | Convert-SentinelARYamlToArm -OutFile "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json"
```

In this case you can pipe the YAML content to the cmdlet, but you must define a output file if it should be written to disk.

```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" | Convert-SentinelARArmToYaml
```

If no output file path is given, the output will be send to `stdout`

## Changelog

### v2.2.0

* FEATURE: Sort all properties in the resulting JSON file by property name. \
  This allows to use the resulting JSON/ARM file to be used in any CI/CD pipeline without commits based on sort order.

### v2.1.0

* FIX: Fixed major flaw in conversion that could corrupt YAML files because of wrong Name translation. \
  To check if you are affected by this bug please verify your converted YAML files. The following words could be corrupted.
  * Renamed `displayName` to `name`
  * Renamed `alertRuleTemplateName` to `id`
  * Renamed `templateVersion` to `version`
  * Renamed `techniques` to `relevantTechniques`
* FEATURE: Added support for NRT rule conversion

### v2.0.2

* FIX: Fixed Windows PowerShell support

### v2.0.1

* FIX: Updated ARM API version to 2022-11-01-preview

### v2.0.0 

* FEATURE: Adds processing of multiple analytic rules per ARM-template
* BREAKING: Changes behavior from OutFile from a filename to a prefix when converting multiple resources

### v1.2.2

* FEATURE: Always add a version property. Default 1.0.0
