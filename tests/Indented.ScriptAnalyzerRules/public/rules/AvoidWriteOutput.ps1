using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidWriteOutput {
    <#
    .SYNOPSIS
        AvoidWriteOutput

    .DESCRIPTION
        Write-Output does not add significant value to a command.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [CommandAst]$ast
    )

    if ($ast.GetCommandName() -eq 'Write-Output') {
        [DiagnosticRecord]@{
            Message  = 'Write-Output is not necessary. Unassigned statements are sent to the output pipeline by default.'
            Extent   = $ast.Extent
            RuleName = $myinvocation.MyCommand.Name
            Severity = 'Warning'
        }
    }
}
