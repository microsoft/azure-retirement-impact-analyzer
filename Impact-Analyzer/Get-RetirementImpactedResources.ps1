	
# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

$QueriesFile = "queries.txt"
$OutputFile = "impactedresources.csv"

# Pre-install resource-graph extension silently
az extension add -n resource-graph --only-show-errors 2>$null
az config set extension.dynamic_install_allow_preview=true --only-show-errors 2>$null

$Queries = Get-Content $QueriesFile
$TempDir = if ($env:TEMP) { $env:TEMP } else { "/tmp" }
$TempFile = Join-Path $TempDir "arg-query-temp.kql"
$QueryNumber = 1
$AllResults = @()

foreach ($Query in $Queries) {
    if ([string]::IsNullOrWhiteSpace($Query)) { continue }
    $Query = $Query.Trim()

    # Extract RetiringFeature from query
    $RetiringFeature = "Unknown"
    if ($Query -match 'RetiringFeature\s*=\s*"([^"]+)"') {
        $RetiringFeature = $Matches[1]
    }

    Write-Host ""
    Write-Host "=========== RetiringFeature : `"$RetiringFeature`" ===========" -ForegroundColor Cyan
    Write-Host $Query
    Write-Host "----------------------------------------------------------------"

    [System.IO.File]::WriteAllText($TempFile, $Query)
    
    # Fetch all results with pagination
    $AllQueryResults = @()
    $SkipToken = $null
    
    do {
        $QueryArgs = @("-q", "@$TempFile", "-o", "json")
        if ($SkipToken) {
            $QueryArgs += "--skip-token", $SkipToken
        }
        
        $Result = az graph query @QueryArgs 2>$null | ConvertFrom-Json
        if ($Result.data) {
            $AllQueryResults += $Result.data
        }
        $SkipToken = $Result.skip_token
        
    } while ($SkipToken)
    
    if ($AllQueryResults.Count -eq 0) {
        Write-Host "No resources impacted" -ForegroundColor Green
    }
    else {
        Write-Host "$($AllQueryResults.Count) resources impacted" -ForegroundColor Green
        $AllQueryResults | Format-Table -AutoSize
        
        # Add metadata to each result for tracking
        foreach ($item in $AllQueryResults) {
            $item | Add-Member -NotePropertyName "RetiringFeature" -NotePropertyValue $RetiringFeature -Force
            $subId = ""
            if ($item.id -match '/subscriptions/([^/]+)/') { $subId = $Matches[1] }
            $item | Add-Member -NotePropertyName "subscriptionId" -NotePropertyValue $subId -Force
            $AllResults += $item
        }
    }

    $QueryNumber++
}

Remove-Item $TempFile -ErrorAction SilentlyContinue

# Export results if output file specified
if ($OutputFile -and $AllResults.Count -gt 0) {
    # Convert nested objects/arrays to JSON strings to preserve them in CSV
    $ExportResults = @()
    foreach ($result in $AllResults) {
        $ExportObj = New-Object PSObject
        foreach ($prop in $result.PSObject.Properties) {
            $value = $prop.Value
            
            # Check if value is an object or array (not string or primitive)
            if (($value -is [System.Collections.IDictionary]) -or 
                ($value -is [System.Collections.IEnumerable] -and $value -isnot [string]) -or
                ($value -is [PSObject] -and $value -isnot [string])) {
                # Convert to JSON string to preserve structure
                $value = $value | ConvertTo-Json -Compress -Depth 10
            }
            
            $ExportObj | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $value
        }
        $ExportResults += $ExportObj
    }
    
    $ExportResults | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    Write-Host ""
    Write-Host "Results exported to: $OutputFile" -ForegroundColor Cyan
    Write-Host "Total resources: $($ExportResults.Count)" -ForegroundColor Cyan
}