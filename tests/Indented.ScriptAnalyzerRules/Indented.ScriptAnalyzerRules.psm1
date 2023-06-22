$public = Get-ChildItem $psscriptroot\public -Filter *.ps1 -Recurse
foreach ($item in $public) {
    . $item.FullName
}