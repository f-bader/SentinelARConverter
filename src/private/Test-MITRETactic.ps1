<#
.SYNOPSIS
    Tests whether a given MITRE ATT&CK® Tactic Name is valid.

.DESCRIPTION
    The Test-MITRETactic function checks if a provided Tactic Name is valid according to the MITRE ATT&CK framework.
    It compares the Tactic Name against a list of valid Tactic Names and returns a boolean value indicating whether the Tactic Name is valid or not.

.PARAMETER TacticName
    Specifies the Tactic Name to be tested. This parameter is mandatory and accepts a non-empty string value.

.OUTPUTS
    System.Boolean
    The function returns $true if the Tactic Name is valid, and $false otherwise.

.EXAMPLE
    Test-MITRETactic -TacticName "CommandAndControl"
    Returns: True

.EXAMPLE
    Test-MITRETactic -TacticName "BunnyHopping"
    Returns: False
.NOTES
© 2023 The MITRE Corporation. This work is reproduced and distributed with the permission of The MITRE Corporation."
#>
function Test-MITRETactic {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$TacticName
    )

    process {
        $ValidTactics = @(
            'Collection',
            'CommandAndControl',
            'CredentialAccess',
            'DefenseEvasion',
            'Discovery',
            'Execution',
            'Exfiltration',
            'Impact',
            'ImpairProcessControl',
            'InhibitResponseFunction',
            'InitialAccess',
            'LateralMovement',
            'Persistence',
            'PreAttack',
            'PrivilegeEscalation',
            'Reconnaissance',
            'ResourceDevelopment'
        )

        if ($TacticName -in $ValidTactics) {
            return $true
        } else {
            return $false
        }

    }
}