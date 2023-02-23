using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function UseExpressionlessArgumentsInTheParameterAttribute {
    <#
    .SYNOPSIS
        UseExpressionlessArgumentsInTheParameterAttribute

    .DESCRIPTION
        Use expressionless arguments for boolean values in the parameter attribute.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [AttributeAst]$ast
    )

    if ($ast.TypeName.FullName -eq 'Parameter') {
        $parameter = [Parameter]::new()

        foreach ($namedArgument in $ast.NamedArguments) {
            if (-not $namedArgument.ExpressionOmitted -and $parameter.($namedArgument.ArgumentName) -is [bool]) {
                [DiagnosticRecord]@{
                    Message  = 'Use an expressionless named argument for {0}.' -f $namedArgument.ArgumentName
                    Extent   = $namedArgument.Extent
                    RuleName = $myinvocation.MyCommand.Name
                    Severity = 'Warning'
                }
            }
        }
    }
}
