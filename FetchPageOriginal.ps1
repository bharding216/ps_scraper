# To run the script, enter the following command in the terminal:
# .\FetchPage.ps1

# Add HtmlAgilityPack.dll to the PowerShell session
Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

# Load the JSON file and convert it to a PowerShell object
$json = Get-Content -Path './newsSources.json' | ConvertFrom-Json
$newsSources = $json.newsSources

$currentYear = (Get-Date).Year

$newsSources | ForEach-Object { $_.urlPatternRequired = $_.urlPatternRequired -replace '{currentYear}', $currentYear }

$urlPatternToAvoid = ($newsSources | ForEach-Object { $_.urlPatternToAvoid }) -join '|'
$urlPatternRequired = ($newsSources | ForEach-Object { $_.urlPatternRequired }) -join '|'

foreach ($source in $newsSources) {
    $url = $source.url

    $name = $source.name
    $requiredClasses = $source.requiredClasses
    $eitherOrClasses = $source.eitherOrClasses

    $localFilePath = "C:\Users\brand\Documents\$name.html"

    # Save the home page source to a local file
    Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' } -OutFile $localFilePath

    $htmlDoc = New-Object HtmlAgilityPack.HtmlDocument

    $htmlDoc.Load($localFilePath)

    if ($eitherOrClasses -ne $null -and $eitherOrClasses.Count -gt 0) {
        $eitherOrClassesExpressions = $eitherOrClasses | ForEach-Object { "contains(@class, '$_')" }
        $eitherOrClassesJoined = $eitherOrClassesExpressions -join " or "
        $classExpression = "contains(@class, '$requiredClasses') and ($eitherOrClassesJoined)"
    } else {
        $classExpression = "contains(@class, '$requiredClasses')"
    }

    # A placeholder for the list of links to be fetched
    $hrefList = New-Object System.Collections.Generic.List[string]

    # Collect all the links from the home page given the class name(s) above
    $links = $htmlDoc.DocumentNode.SelectNodes("//a[$classExpression]")

    foreach ($link in $links) {
        $href = $link.GetAttributeValue('href', '')

        if ($href -match $urlPatternToAvoid) {
            continue
        }

        if ($href -notmatch $urlPatternRequired) {
            continue
        }

        if ($href -match '^/') {
            $href = $url + $href
        }

        # Check if the url starts with $url
        if ($href -notmatch "^$([regex]::Escape($url))") {
            continue
        }

        # Add href to the list
        $hrefList.Add($href)
    }

    # Remove duplicates from the hrefList
    $hrefList = $hrefList | Sort-Object -Unique

    # Save the hrefList to a local file
    $hrefList | Out-File -FilePath "C:\Users\brand\Documents\$name.txt"

    # For each link in hrefList, go to that page and save the page source to a local file
    foreach ($href in $hrefList) {
        # Convert href to url safe string
        $hrefSafe = [System.Web.HttpUtility]::UrlEncode($href)
        $localFilePath = "C:\Users\brand\Documents\$name-$hrefSafe.html"
        try {
            Invoke-WebRequest -Uri $href -Method Get -Headers @{ 'Accept' = 'text/html' } -OutFile $localFilePath
        } catch {
            Write-Output "Failed to fetch ${href}: $_"
            # The $_ variable contains the error message
        }
    }

    # Clear the hrefList
    $hrefList.Clear()

    Write-Output "Completed fetching for $name!"
}

Write-Output 'All sites have been fetched!'