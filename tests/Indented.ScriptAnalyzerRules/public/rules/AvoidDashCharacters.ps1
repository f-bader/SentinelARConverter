using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidDashCharacters {
    <#
    .SYNOPSIS
        AvoidDashCharacters

    .DESCRIPTION
        Avoid en-dash, em-dash, and horizontal bar outside of strings.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [ScriptBlockAst]$ast
    )

    $ast.FindAll(
        {
            param ( $ast )

            $shouldCheckAst = (
                $ast -is [System.Management.Automation.Language.BinaryExpressionAst] -or
                $ast -is [System.Management.Automation.Language.CommandParameterAst] -or
                $ast -is [System.Management.Automation.Language.AssignmentStatementAst]
            )

            if ($shouldCheckAst) {
                if ($ast.ErrorPosition.Text[0] -in 0x2013, 0x2014, 0x2015) {
                    return $true
                }
            }
            if ($ast -is [System.Management.Automation.Language.CommandAst] -and
                $ast.GetCommandName() -match '\u2013|\u2014|\u2015') {

                return $true
            }
        },
        $false
    ) | ForEach-Object {
        [DiagnosticRecord]@{
            Message              = 'Avoid en-dash, em-dash, and horizontal bar outside of strings.'
            Extent               = $_.Extent
            RuleName             = $myinvocation.MyCommand.Name
            Severity             = 'Error'
            SuggestedCorrections = [CorrectionExtent[]]@(
                [CorrectionExtent]::new(
                    $_.Extent.StartLineNumber,
                    $_.Extent.EndLineNumber,
                    $_.Extent.StartColumnNumber,
                    $_.Extent.EndColumnNumber,
                    ($_.Extent.Text -replace '\u2013|\u2014|\u2015', '-'),
                    'Replace dash character'
                )
            )
        }
    }
}
