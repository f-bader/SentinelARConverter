function Invoke-SortJSONObject {
    param (
        [Parameter()]
        $object
    )

    if ($object -is [PSCustomObject]) {
        $hash = [ordered]@{}
        foreach ($property in $object.PSObject.Properties | Sort-Object Name) {
            if ($property.TypeNameOfValue -eq "System.Object[]" -or $property -is [System.Collections.ArrayList]) {
                $hash[$property.Name] = @(Invoke-SortJSONObject $property.Value)
            } else {
                $hash[$property.Name] = Invoke-SortJSONObject $property.Value
            }
        }
        return $hash
    } elseif ($object -is [System.Collections.IDictionary]) {
        $hash = [ordered]@{}
        foreach ($key in $object.Keys | Sort-Object) {
            $hash[$key] = Invoke-SortJSONObject $object[$key]
        }
        return $hash
    } elseif ($object -is [System.Collections.IEnumerable] -and $object -isnot [string]) {
        $array = @()
        foreach ($item in $object) {
            $array += Invoke-SortJSONObject $item
        }
        return $array
    } else {
        return $object
    }
}
