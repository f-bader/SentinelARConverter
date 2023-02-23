using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidCreatingObjectsFromAnEmptyString {
    <#
    .SYNOPSIS
        AvoidCreatingObjectsFromAnEmptyString

    .DESCRIPTION
        Objects should not be created by piping an empty string to Select-Object.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [PipelineAst]$ast
    )

    if ($ast.PipelineElements.Count -gt 1) {
        $isMatchingCase = (
            $ast.PipelineElements[0].Expression -is [StringConstantExpressionAst] -and
            $ast.PipelineElements[0].Expression.SafeGetValue().Trim() -eq '' -and
            $ast.PipelineElements[1] -is [CommandAst] -and
            $ast.PipelineElements[1].GetCommandName() -in 'select', 'Select-Object'
        )

        if ($isMatchingCase) {
            [DiagnosticRecord]@{
                Message  = 'An empty string is used to create an object with Select-Object in file {0}.' -f $ast.Extent.File
                Extent   = $ast.Extent
                RuleName = $myinvocation.MyCommand.Name
                Severity = 'Warning'
            }
        }
    }
}
