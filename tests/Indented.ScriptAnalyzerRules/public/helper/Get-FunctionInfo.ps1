using namespace System.Management.Automation
using namespace System.Management.Automation.Language
using namespace System.Reflection

function Get-FunctionInfo {
    <#
    .SYNOPSIS
        Get an instance of FunctionInfo.

    .DESCRIPTION
        FunctionInfo does not present a public constructor. This function calls an internal / private constructor on FunctionInfo to create a description of a function from a script block or file containing one or more functions.

    .INPUTS
        System.String

    .EXAMPLE
        Get-ChildItem -Filter *.psm1 | Get-FunctionInfo

        Get all functions declared within the *.psm1 file and construct FunctionInfo.

    .EXAMPLE
        Get-ChildItem C:\Scripts -Filter *.ps1 -Recurse | Get-FunctionInfo

        Get all functions declared in all ps1 files in C:\Scripts.
    #>

    [CmdletBinding(DefaultParameterSetName = 'FromPath')]
    [OutputType([System.Management.Automation.FunctionInfo])]
    param (
        # The path to a file containing one or more functions.
        [Parameter(Position = 1, ValueFromPipelineByPropertyName, ParameterSetName = 'FromPath')]
        [Alias('FullName')]
        [string]$Path,

        # A script block containing one or more functions.
        [Parameter(ParameterSetName = 'FromScriptBlock')]
        [ScriptBlock]$ScriptBlock,

        # By default functions nested inside other functions are ignored. Setting this parameter will allow nested functions to be discovered.
        [Switch]$IncludeNested
    )

    begin {
        $executionContextType = [PowerShell].Assembly.GetType('System.Management.Automation.ExecutionContext')
        $constructor = [FunctionInfo].GetConstructor(
            [BindingFlags]'NonPublic, Instance',
            $null,
            [CallingConventions]'Standard, HasThis',
            ([String], [ScriptBlock], $executionContextType),
            $null
        )
    }

    process {
        if ($pscmdlet.ParameterSetName -eq 'FromPath') {
            try {
                $scriptBlock = [ScriptBlock]::Create((Get-Content $Path -Raw))
            } catch {
                $ErrorRecord = @{
                    Exception = $_.Exception.InnerException
                    ErrorId   = 'InvalidScriptBlock'
                    Category  = 'OperationStopped'
                }
                Write-Error @ErrorRecord
            }
        }

        if ($scriptBlock) {
            $scriptBlock.Ast.FindAll( {
                    param( $ast )

                    $ast -is [FunctionDefinitionAst]
                },
                $IncludeNested
            ) | ForEach-Object {
                $constructor.Invoke(([String]$_.Name, $_.Body.GetScriptBlock(), $null))
            }
        }
    }
}
