@{
    ExcludeRules   = @( "UseSyntacticallyCorrectExamples" )
    CustomRulePath = @(
        'tests/Indented.ScriptAnalyzerRules/Indented.ScriptAnalyzerRules.psm1'
    )
    Rules          = @{
        PSUseCompatibleSyntax = @{
            # This turns the rule on (setting it to false will turn it off)
            Enable         = $true

            # List the targeted versions of PowerShell here
            TargetVersions = @(
                '5.1',
                '7.2'
            )
        }
    }
}
