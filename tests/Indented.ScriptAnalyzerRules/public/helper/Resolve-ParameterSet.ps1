using namespace System.Management.Automation

function Resolve-ParameterSet {
    <#
    .SYNOPSIS
        Resolve a set of parameter names to a parameter set.

    .DESCRIPTION
        Resolve-ParameterSet attempts to discover the parameter set used by a set of named parameters.

    .EXAMPLE
        Resolve-ParameterSet -CommandName Invoke-Command -ParameterName ScriptBlock, NoNewScope

        Find the parameter set name Invoke-Command uses when ScriptBlock and NoNewScope are parameters.

    .EXAMPLE
        Resolve-ParameterSet -CommandName Get-Process -ParameterName IncludeUserName

        Find the parameter set name Get-Process uses when the IncludeUserName parameter is defined.

    .EXAMPLE
        Resolve-ParameterSet -CommandName Invoke-Command -ParameterName Session, ArgumentList

        Writes a non-terminating error noting that no parameter sets matched.
    #>

    [CmdletBinding(DefaultParameterSetName = 'FromCommandInfo')]
    param (
        # Attempt to resolve the parameter set for the specified command name.
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'FromCommandName')]
        [string]$CommandName,

        # Attempt to resolve the parameter set for the specified CommandInfo.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'FromCommandInfo')]
        [CommandInfo]$CommandInfo,

        # The parameter names which would be supplied.
        [AllowEmptyCollection()]
        [string[]]$ParameterName = @()
    )

    begin {
        if ($pscmdlet.ParameterSetName -eq 'FromCommandName') {
            Get-Command $CommandName | Resolve-ParameterSet -ParameterName $ParameterName
        }
    }

    process {
        if ($pscmdlet.ParameterSetName -eq 'FromCommandInfo') {
            try {
                $candidateSets = for ($i = 0; $i -lt $commandInfo.ParameterSets.Count; $i++) {
                    $parameterSet = $commandInfo.ParameterSets[$i]

                    Write-Debug ('Analyzing {0}' -f $parameterSet.Name)

                    $isCandidateSet = $true
                    foreach ($parameter in $parameterSet.Parameters) {
                        if ($parameter.IsMandatory -and -not ($ParameterName -contains $parameter.Name)) {
                            Write-Debug ('  Discarded {0}: Missing mandatory parameter {1}' -f $parameterSet.Name, $parameter.Name)

                            $isCandidateSet = $false
                            break
                        }
                    }
                    if ($isCandidateSet) {
                        foreach ($name in $ParameterName) {
                            if ($name -notin $parameterSet.Parameters.Name) {
                                Write-Debug ('  Discarded {0}: Parameter {1} is not within set' -f $parameterSet.Name, $parameter.Name)

                                $isCandidateSet = $false
                                break
                            }
                        }
                    }
                    if ($isCandidateSet) {
                        Write-Debug ('  Discovered candidate set {0} at index {1}' -f $parameterSet.Name, $i)

                        [PSCustomObject]@{
                            Name  = $parameterSet.Name
                            Index = $i
                        }
                    }
                }

                if (@($candidateSets).Count -eq 1) {
                    return $candidateSets.Name
                } elseif (@($candidateSets).Count -gt 1) {
                    foreach ($parameterSet in $candidateSets) {
                        if ($CommandInfo.ParameterSets[$parameterSet.Index].IsDefault) {
                            return $parameterSet.Name
                        }
                    }

                    $errorRecord = [ErrorRecord]::new(
                        [InvalidOperationException]::new(
                            ('{0}: Ambiguous parameter set: {1}' -f
                                $CommandInfo.Name,
                                ($candidateSets.Name -join ', ')
                            )
                        ),
                        'AmbiguousParameterSet',
                        'InvalidOperation',
                        $ParameterName
                    )
                    throw $errorRecord
                } else {
                    $errorRecord = [ErrorRecord]::new(
                        [InvalidOperationException]::new('{0}: Unable to match parameters to a parameter set' -f $CommandInfo.Name),
                        'CouldNotResolveParameterSet',
                        'InvalidOperation',
                        $ParameterName
                    )
                    throw $errorRecord
                }
            } catch {
                Write-Error -ErrorRecord $_
            }
        }
    }
}
