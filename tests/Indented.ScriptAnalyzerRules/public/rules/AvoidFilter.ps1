using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidFilter {
    <#
    .SYNOPSIS
        AvoidFilter

    .DESCRIPTION
        Avoid the Filter keyword when creating a function
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [FunctionDefinitionAst]$ast
    )

    if ($ast.IsFilter) {
        [DiagnosticRecord]@{
            Message  = 'Avoid the Filter keyword when creating a function'
            Extent   = $ast.Extent
            RuleName = $myinvocation.MyCommand.Name
            Severity = 'Warning'
        }
    }
}
