using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidParameterAttributeDefaultValues {
    <#
    .SYNOPSIS
        AvoidParameterAttributeDefaultValues

    .DESCRIPTION
        Avoid including default values in the Parameter attribute.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [AttributeAst]$ast
    )

    if ($ast.TypeName.FullName -eq 'Parameter') {
        $default = [Parameter]::new()

        foreach ($namedArgument in $ast.NamedArguments) {
            if (-not $namedArgument.ExpressionOmitted -and $namedArgument.Argument.SafeGetValue() -eq $default.($namedArgument.ArgumentName)) {
                [DiagnosticRecord]@{
                    Message  = 'Avoid including default values for {0} in the Parameter attribute.' -f $namedArgument.ArgumentName
                    Extent   = $namedArgument.Extent
                    RuleName = $myinvocation.MyCommand.Name
                    Severity = 'Warning'
                }
            }
        }
    }
}
