using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language
using namespace System.Management.Automation

function AvoidWriteErrorStop {
    <#
    .SYNOPSIS
        AvoidWriteErrorStop

    .DESCRIPTION
        Functions and scripts should avoid using Write-Error Stop to terminate a running command or pipeline. The context of the thrown error is Write-Error.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [CommandAst]$ast
    )

    if ($ast.GetCommandName() -eq 'Write-Error') {
        $parameter = $ast.CommandElements.Where{ $_.ParameterName -like 'ErrorA*' -or $_.ParameterName -eq 'EA' }[0]
        if ($parameter) {
            $argumentIndex = $ast.CommandElements.IndexOf($parameter) + 1
            try {
                $argument = $ast.CommandElements[$argumentIndex].SafeGetValue()

                if ([Enum]::Parse([ActionPreference], $argument) -eq 'Stop') {
                    [DiagnosticRecord]@{
                        Message  = 'Write-Error is used to create a terminating error. throw or $pscmdlet.ThrowTerminatingError should be used.'
                        Extent   = $ast.Extent
                        RuleName = $myinvocation.MyCommand.Name
                        Severity = 'Warning'
                    }
                }
            } catch {
                Write-Debug ('Unable to evaluate ErrorAction argument in statement: {0}' -f $ast.Extent.Tostring())
            }
        }
    }
}
