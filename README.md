![SentinelARConverter Banner](/images/banner.png)

# Sentinel Analytics Rule converter

## Installation

```PowerShell
Install-Module SentinelARConverter
```

## How to convert?

You can convert a Sentinel Analytics rule in the [YAML format](https://github.com/Azure/Azure-Sentinel/wiki/Query-Style-Guide) to an [Azure ARM template](https://learn.microsoft.com/en-us/azure/templates/microsoft.insights/alertrules?pivots=deployment-language-arm-template) or vice versa.

For more information about this cmdlet, please refer to my blog post.

### ARM to YAML

```PowerShell
Convert-SentinelARArmToYaml -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" -UseOriginalFilename
```

This will create a new file named `Azure_Sentinel_analytic_rule.yaml` without any other interaction.


```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" | Convert-SentinelARArmToYaml -OutFile "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml"
```

In this case you can pipe the ARM template content to the cmdlet, but you must define a output file if it should be written to disk

```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json" | Convert-SentinelARArmToYaml
```

If no output file path is given, the output will be send to `stdout`

### YAML to ARM

```PowerShell
Convert-SentinelARYamlToArm -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" -UseOriginalFilename
```

This will create a new file named `Azure_Sentinel_analytic_rule.json` without any other interaction.


```PowerShell
Get-Content -Filename "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" | Convert-SentinelARYamlToArm -OutFile "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.json"
```

In this case you can pipe the YAML content to the cmdlet, but you must define a output file if it should be written to disk.

```PowerShell
Get-Content "C:\Users\User\Downloads\Azure_Sentinel_analytic_rule.yaml" | Convert-SentinelARArmToYaml
```

If no output file path is given, the output will be send to `stdout`

## Known limitations

Currently it's not possible to convert a ARM template file that contains more than one Analytics Rule to YAML.
