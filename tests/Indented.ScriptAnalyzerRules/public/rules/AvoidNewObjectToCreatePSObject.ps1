using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidNewObjectToCreatePSObject {
    <#
    .SYNOPSIS
        AvoidNewObjectToCreatePSObject

    .DESCRIPTION
        Functions and scripts should use [PSCustomObject] to create PSObject instances with named properties.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [CommandAst]$ast
    )

    if ($ast.GetCommandName() -eq 'New-Object') {
        $isPSObject = $ast.CommandElements.Value -contains 'PSObject'

        if ($isPSObject) {
            [DiagnosticRecord]@{
                Message  = 'New-Object is used to create a custom object. Use [PSCustomObject] instead.'
                Extent   = $ast.Extent
                RuleName = $myinvocation.MyCommand.Name
                Severity = 'Warning'
            }
        }
    }
}
