using namespace Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic
using namespace System.Management.Automation.Language

function AvoidUsingRedirection {
    <#
    .SYNOPSIS
        AvoidUsingRedirection

    .DESCRIPTION
        Avoid using redirection to write to files.
    #>

    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param (
        [FileRedirectionAst]$ast
    )

    [DiagnosticRecord]@{
        Message  = 'File redirection is being used to write file content in {0}.' -f $ast.Extent.File
        Extent   = $ast.Extent
        RuleName = $myinvocation.MyCommand.Name
        Severity = 'Warning'
    }
}
