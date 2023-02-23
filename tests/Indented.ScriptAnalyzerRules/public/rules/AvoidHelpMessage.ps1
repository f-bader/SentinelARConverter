using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidHelpMessage {
    <#
    .SYNOPSIS
        AvoidHelpMessage

    .DESCRIPTION
        Avoid arguments for boolean values in the parameter attribute.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [AttributeAst]$ast
    )

    if ($ast.TypeName.FullName -eq 'Parameter') {
        foreach ($namedArgument in $ast.NamedArguments) {
            if ($namedArgument.ArgumentName -eq 'HelpMessage') {
                [DiagnosticRecord]@{
                    Message  = 'Avoid using HelpMessage.'
                    Extent   = $namedArgument.Extent
                    RuleName = $myinvocation.MyCommand.Name
                    Severity = 'Warning'
                }
            }
        }
    }
}
