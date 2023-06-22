using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Collections.Generic
using namespace System.Management.Automation.Language

function AvoidSmartQuotes {
    <#
    .SYNOPSIS
        AvoidSmartQuotes

    .DESCRIPTION
        Avoid smart quotes.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [StringConstantExpressionAst]$ast
    )

    if ($ast.StringConstantType -eq 'BareWord') {
        return
    }

    $normalQuotes = @(
        "'"
        '"'
    )

    if ($ast.StringConstantType -in 'DoubleQuotedHereString', 'SingleQuotedHereString') {
        $startQuote, $endQuote = $ast.Extent.Text[1, -2]
    } else {
        $startQuote, $endQuote = $ast.Extent.Text[0, -1]
    }

    if ($startQuote -notin $normalQuotes -or $endQuote -notin $normalQuotes) {
        if ($ast.StringConstantType -in 'SingleQuoted', 'SingleQuotedHereString') {
            $quoteCharacter = "'"
        } else {
            $quoteCharacter = '"'
        }

        if ($ast.StringConstantType -like '*HereString') {
            $startColumnNumber = $ast.Extent.StartColumnNumber + 1
            $endColumNumber = $ast.Extent.EndColumnNumber - 2
        } else {
            $startColumnNumber = $ast.Extent.StartColumnNumber
            $endColumNumber = $ast.Extent.EndColumnNumber - 1
        }

        $corrections = [List[CorrectionExtent]]::new()
        if ($startQuote -notin $normalQuotes) {
            $corrections.Add(
                [CorrectionExtent]::new(
                    $ast.Extent.StartLineNumber,
                    $ast.Extent.StartLineNumber,
                    $startColumnNumber,
                    $startColumnNumber + 1,
                    $quoteCharacter,
                    'Replace start smart quotes'
                )
            )
        }
        if ($endQuote -notin $normalQuotes) {
            $corrections.Add(
                [CorrectionExtent]::new(
                    $ast.Extent.EndLineNumber,
                    $ast.Extent.EndLineNumber,
                    $endColumNumber,
                    $endColumNumber + 1,
                    $quoteCharacter,
                    'Replace end smart quotes'
                )
            )
        }

        [DiagnosticRecord]@{
            Message              = 'Avoid smart quotes, always use " or ''.'
            Extent               = $ast.Extent
            RuleName             = $myinvocation.MyCommand.Name
            Severity             = 'Warning'
            SuggestedCorrections = $corrections
        }
    }
}
