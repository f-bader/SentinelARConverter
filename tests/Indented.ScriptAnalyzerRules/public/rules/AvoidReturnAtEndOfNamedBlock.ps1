using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidReturnAtEndOfNamedBlock {
    <#
    .SYNOPSIS
        AvoidReturnAtEndOfNamedBlock

    .DESCRIPTION
        Avoid using return at the end of a named block, when it is the only return statement in a named block.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [NamedBlockAst]$ast
    )

    if ($ast.Parent.Parent.Parent.Parent.IsClass) {
        return
    }

    $returnStatements = $ast.FindAll(
        {
            param ( $ast )

            $ast -is [ReturnStatementAst]
        },
        $false
    )

    if ($returnStatements.Count -eq 1) {
        $returnStatement = $returnStatements[0]

        if ($returnStatement -eq $ast.Statements[-1]) {
            [DiagnosticRecord]@{
                Message  = 'Avoid using return when an early end to a named block is not necessary.'
                Extent   = $ast.Extent
                RuleName = $myinvocation.MyCommand.Name
                Severity = 'Warning'
            }
        }
    }
}
