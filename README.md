![SentinelARConverter Banner](/images/banner.png)

# Sentinel Analytics Rule converter

[![PSGallery Version](https://img.shields.io/powershellgallery/v/SentinelARConverter.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/SentinelARConverter) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/SentinelARConverter.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/SentinelARConverter)

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

```PowerShell
Convert-SentinelARYamlToArm -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" -ParameterFile "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.params.yaml" -UseOriginalFilename 
```

In this case the yaml file is converted and saved with the original file name (`Azure_Sentinel_analytic_rule.json`) but in the process of converting the file additional changes, according to the parameter file are applied.

## Parameter file

There are four different types of parametrization you can use. Each must be defined in it's own subsection.

There is no validation of the values provided, which can result in invalid arm templates.

Only [valid properties](https://learn.microsoft.com/en-us/azure/templates/microsoft.securityinsights/alertrules?pivots=deployment-language-arm-template#scheduledalertruleproperties-1) should be added.

```yaml
OverwriteProperties:
  queryFrequency: 1h
  queryPeriod: 1h
PrependQuery: |
  // Example description. Will be added to the beginning of the query.
AppendQuery: |
  // Example text that will be added to the end of the query.
ReplaceQueryVariables:
  NumberOfErrors: 200
  ErrorCodes:
    - "403"
    - "404"
```

### OverwriteProperties

Every key found in this section is used to either replace the existing key or is added as a new key to the resulting ARM template. Make sure to use the correct spacing to ensure that the correct keys are overwritten.

```yaml
OverwriteProperties:
  queryFrequency: 1h
  queryPeriod: 1h
```

In this example the `queryFrequency` and the `queryPeriod` are adjusted.

### PrependQuery

This text will be added to the beginning of the KQL query. If `PrependQuery: |` is used, a newline will be added automatically. If you use `PrependQuery: |-` no newline will be written.

```yaml
PrependQuery: |
  // Example description. Will be added to the beginning of the query.
```

This example adds a description at the top of the KQL query and adds a newline.

### AppendQuery

Add text at the end of the KQL query. This ways you can extend the query, add additional filters or rename certain fields.

```yaml
AppendQuery: |
  | extend TimeGenerated = StartTime
```

Adds the line to the end of the query and adds a new column named `TimeGenerated` based on value of the `StartTime` column.

### ReplaceQueryVariables

This section allows you to use variable names in your original YAML file. They will be replaced by the value provided in the parameter file. There is support for simple string replacement and arrays.

All variables must be named using two percent sign at the beginning and the end e.g. `%%VARIABLENAME%%`.

* String values are replaced as is.
* Array values are joined together using `","` and a single `"` is added at the start and end. The resulting string is used to replace the variable.

```yaml
ReplaceQueryVariables:
  NumberOfErrors: 200
  ErrorCodes:
    - 403
    - 404
```

* The variable `%%NumberOfErrors%%` will be replaced by the string value `200`
* Before the variable `%%ErrorCodes%%` will be replaced, the `ErrorCodes` array will be converted into a single string `"403","404"`

This way the following KQL query will be converted...

```kql
| where Message in (%%ErrorCodes%%)
| summarize StartTime = min(TimeGenerated), EndTime = max(TimeGenerated), NumberOfErrors = dcount(SourceIP) by HostName, SourceIP
| where NumberOfErrors > %%NumberOfErrors%%
```
...to this result:

```kql
| where Message in ("403","404")
| summarize StartTime = min(TimeGenerated), EndTime = max(TimeGenerated), NumberOfErrors = dcount(SourceIP) by HostName, SourceIP
| where NumberOfErrors > 200
```

## Changelog

### 2.4.1
 * FIX: Handle error if `incidentConfiguration` section is missing from source YAML in `Convert-SentinelARYamlToArm` when using `-DisableIncidentCreation`

### 2.4.0
 * FEATURE: Support for MITRE sub-Techniques and update default ARM version to `2024-01-01-preview`
   Thanks to [@Konverto-MartinGasser)](https://github.com/Konverto-MartinGasser) SentinelARConverter now supports MITRE sub-techniques which were introduced in ARM template version `2023-12-01-preview`.

### 2.3.0
 * FEATURE: Add the option to specify a parameter file. This gives a maximum of flexbility to manipulate existing YAML files.

### v2.2.3

 * FEATURE: Add validation and auto-correction of invalid MITRE ATT&CK® tactics and techniques when converting YAML files to ARM templates
 * FEATURE: Add new parameter `-StartRunningAt` for `Convert-SentinelARYamlToArm` to allow the user to change the start time of a newly deployed rule. (Sentinel Preview feature)
 * MINOR:   Update default APIVersion to '2023-02-01-preview'

### v2.2.2

 * FEATURE: Add new parameter `-Severity` for `Convert-SentinelARYamlToArm` to allow the user to change the severity of the ANR

### v2.2.1

 * FEATURE: Add new parameter `-NamePrefix` for `Convert-SentinelARYamlToArm` to allow the user to add a prefix to the ANR name

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
