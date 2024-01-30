# To run the script, enter the following command in the terminal:
# .\FetchPageNew2.ps1

# Add HtmlAgilityPack.dll to the PowerShell session
Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function crawlAndSaveArticles {
    param (
        [string]$url,
        [System.Collections.Generic.HashSet[string]]$visitedLinks
    )

    $filename = "article_$((Get-Date).ToString('yyyyMMdd_HHmmss'))"

    $localFilePath = "C:\Users\brand\Documents\$filename.html"

    Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' } -OutFile $localFilePath

    $htmlDoc = New-Object HtmlAgilityPack.HtmlDocument

    $htmlDoc.Load($localFilePath)

    $cleanHrefList = New-Object System.Collections.Generic.List[string]

    # Collect all the links from the home page given the class name(s) above
    $links = $htmlDoc.DocumentNode.SelectNodes("//a[@href]")

    # Clean up the links
    foreach ($link in $links) {
        $href = $link.GetAttributeValue('href', '')

        if ($href -match '^/') {
            $href = $url + $href
        }

        # Check if the url starts with $url
        if ($href -notmatch "^$([regex]::Escape($url))") {
            continue
        }

        $cleanHrefList.Add($href)
    }

    Write-Output "Found $($cleanHrefList.Count) links on $url"

    # Remove duplicates from the cleanHrefList
    $cleanHrefList = $cleanHrefList | Sort-Object -Unique

    # For each link in hrefList, go to that page and save the page source to a local file
    foreach ($href in $cleanHrefList) {
        # Convert href to url safe string
        $hrefSafe = [System.Web.HttpUtility]::UrlEncode($href)
        $localFilePath = "C:\Users\brand\Documents\$hrefSafe.html"

        try {
            $response = Invoke-WebRequest -Uri $href -Method Get -Headers @{ 'Accept' = 'text/html' }
            
            # Check if the response contains the <article> tag
            if ($response.Content -match '<article\b[^>]*>[\s\S]*?</article>') {
                $response.Content | Out-File -FilePath $localFilePath -Force
                Write-Output "Successfully fetched and saved $href"
            } else {
                Write-Output "Skipping $href - Does not contain <article> tag"
            }
        } catch {
            Write-Output "Failed to fetch ${href}: $_"            
            # The $_ variable contains the error message
        }
    }
}

# Set the starting URL and maximum number of articles to collect
$startUrl = "https://www.cnn.com"

# Create a HashSet to store visited links
$visitedLinks = New-Object "System.Collections.Generic.HashSet[string]"

# Start crawling
crawlAndSaveArticles -url $startUrl -visitedLinks $visitedLinks
