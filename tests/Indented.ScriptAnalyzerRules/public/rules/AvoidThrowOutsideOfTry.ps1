using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidThrowOutsideOfTry {
    <#
    .SYNOPSIS
        AvoidThrowOutsideOfTry

    .DESCRIPTION
        Advanced functions and scripts should not use throw, except within a try / catch block. Throw is affected by ErrorAction.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [FunctionDefinitionAst]$ast
    )

    $isAdvanced = $null -ne $ast.Body.Find(
        {
            param ( $ast )

            $ast -is [AttributeAst] -and
            $ast.TypeName.Name -in 'CmdletBinding', 'Parameter'
        },
        $false
    )

    if (-not $isAdvanced) {
        return
    }

    $namedBlocks = $ast.Body.Find(
        {
            param ( $ast )

            $ast -is [NamedBlockAst]
        },
        $false
    )

    foreach ($namedBlock in $namedBlocks) {
        $throwStatements = $namedBlock.FindAll(
            {
                param ( $ast )

                $ast -is [ThrowStatementAst]
            },
            $false
        )

        if (-not $throwStatements) {
            return
        }

        $tryStatements = $namedBlock.FindAll(
            {
                param ( $ast )

                $ast -is [TryStatementAst]
            },
            $false
        )

        foreach ($throwStatement in $throwStatements) {
            if ($tryStatements) {
                $isWithinExtentOfTry = $false

                foreach ($tryStatement in $tryStatements) {
                    $isStatementWithinExtentOfTry = (
                        $throwStatement.Extent.StartOffset -gt $tryStatement.Extent.StartOffset -and
                        $throwStatement.Extent.EndOffset -lt $tryStatement.Extent.EndOffset
                    )

                    if ($isStatementWithinExtentOfTry) {
                        $isWithinExtentOfTry = $true
                    }
                }
            } else {
                $isWithinExtentOfTry = $false
            }

            if (-not $isWithinExtentOfTry) {
                [DiagnosticRecord]@{
                    Message  = 'throw is used to terminate a function outside of try in the function {0}.' -f $ast.name
                    Extent   = $throwStatement.Extent
                    RuleName = $myinvocation.MyCommand.Name
                    Severity = 'Error'
                }
            }
        }
    }
}
