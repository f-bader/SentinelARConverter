using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function UseSyntacticallyCorrectExamples {
    <#
    .SYNOPSIS
        UseSyntacticallyCorrectExamples

    .DESCRIPTION
        Examples should use parameters described by the function correctly.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'hasTriggered')]
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [FunctionDefinitionAst]$ast
    )

    if ($ast.Parent.Parent.IsClass) {
        return
    }

    $definition = [ScriptBlock]::Create($ast.Extent.ToString())
    $functionInfo = Get-FunctionInfo -ScriptBlock $definition

    if ($functionInfo.CmdletBinding) {
        $helpContent = $ast.GetHelpContent()

        for ($i = 0; $i -lt $helpContent.Examples.Count; $i++) {
            $example = $helpContent.Examples[$i]
            $exampleNumber = $i + 1

            $exampleAst = [Parser]::ParseInput(
                $example,
                [Ref]$null,
                [Ref]$null
            )

            $exampleAst.FindAll(
                {
                    param ( $ast )

                    $ast -is [CommandAst]
                },
                $false
            ) | Where-Object {
                $_.GetCommandName() -eq $ast.Name
            } | ForEach-Object {
                $hasTriggered = $false

                # Non-existant parameters
                $_.CommandElements | Where-Object {
                    $_ -is [CommandParameterAst] -and $_.ParameterName -notin $functionInfo.Parameters.Keys
                } | ForEach-Object {
                    $hasTriggered = $true

                    [DiagnosticRecord]@{
                        Message  = 'Example {0} in function {1} uses invalid parameter {2}.' -f @(
                            $exampleNumber
                            $ast.Name
                            $_.ParameterName
                        )
                        Extent   = $ast.Extent
                        RuleName = $myinvocation.MyCommand.Name
                        Severity = 'Warning'
                    }
                }

                # Only trigger this test if the command includes valid parameters.
                if (-not $hasTriggered) {
                    # Ambiguous parameter set use
                    try {
                        $parameterName = $_.CommandElements | Where-Object { $_ -is [CommandParameterAst] } | ForEach-Object ParameterName
                        $null = Resolve-ParameterSet -CommandInfo $functionInfo -ParameterName $parameterName -ErrorAction Stop
                    } catch {
                        Write-Debug $_.Exception.Message

                        [DiagnosticRecord]@{
                            Message  = 'Unable to determine parameter set used by example {0} for the function {1}' -f @(
                                $exampleNumber
                                $ast.Name
                            )
                            Extent   = $ast.Extent
                            RuleName = $myinvocation.MyCommand.Name
                            Severity = 'Warning'
                        }
                    }
                }
            }
        }
    }
}
