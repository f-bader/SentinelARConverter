function Invoke-CustomScriptAnalyzerRule {
    <#
    .SYNOPSIS
        Invoke a specific coding convention rule.

    .DESCRIPTION
        Invoke a specific coding convention rule against a defined file, script block, or command name.

    .EXAMPLE
        Invoke-CustomScriptAnalyzerRule -Path C:\Script.ps1 -RuleName AvoidNestedFunctions

        Invoke the rule AvoidNestedFunctions against the script in the specified path.
    #>

    [CmdletBinding(DefaultParameterSetName = 'FromPath')]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [Parameter(Mandatory, ParameterSetName = 'FromString')]
        [string]$String,

        [Parameter(Mandatory, ParameterSetName = 'FromPath')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'FromScriptBlock')]
        [ScriptBlock]$ScriptBlock,

        [Parameter(Mandatory, ParameterSetName = 'FromCommandName')]
        [string]$CommandName,

        [Parameter(Mandatory, Position = 2)]
        [string]$RuleName
    )

    $ast = switch ($pscmdlet.ParameterSetName) {
        'FromString' {
            [System.Management.Automation.Language.Parser]::ParseInput(
                $String,
                [ref]$null,
                [ref]$null
            )
        }
        'FromPath' {
            $Path = $pscmdlet.GetUnresolvedProviderPathFromPSPath($Path)

            [System.Management.Automation.Language.Parser]::ParseFile(
                $Path,
                [ref]$null,
                [ref]$null
            )
        }
        'FromScriptBlock' {
            $ScriptBlock.Ast
        }
        'FromCommandName' {
            try {
                $command = Get-Command $CommandName -ErrorAction Stop
                if ($command.CommandType -notin 'ExternalScript', 'Function') {
                    throw [InvalidOperationException]::new('The command "{0}" is not a script or function.' -f $CommandName)
                }
                $command.ScriptBlock.Ast
            } catch {
                $pscmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        $_.Exception,
                        'InvalidCommand',
                        'OperationStopped',
                        $CommandName
                    )
                )
            }
        }
    }

    # Acquire the type to test
    try {
        $astType = (Get-Command $RuleName -ErrorAction Stop).Parameters['ast'].ParameterType
    } catch {
        $pscmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [InvalidOperationException]::new('The name "{0}" is not a valid rule' -f $RuleName, $_.Exception),
                'InvalidRuleName',
                'OperationStopped',
                $RuleName
            )
        )
    }

    $predicate = [ScriptBlock]::Create(('param ( $ast ); $ast -is [{0}]' -f $astType.FullName))
    foreach ($node in $ast.FindAll($predicate, $true)) {
        & $RuleName -Ast $node
    }
}
