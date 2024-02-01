# To run the script, enter the following command in the terminal:
# .\FetchPageNew2.ps1

# Add HtmlAgilityPack.dll to the PowerShell session
Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function Save-HomePage {
    param (
        [string]$url,
        [string]$localFilePath
    )

    Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' } -OutFile $localFilePath
}

function Crawl-And-Save-Articles {
    param (
        [string]$url,
        [System.Collections.Generic.HashSet[string]]$visitedLinks,
        [int]$maxArticles = 10
    )

    $filename = "homepage_$url_$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
    $localFilePath = "C:\Users\brand\Documents\$filename.html"

    Save-HomePage -url $url -localFilePath $localFilePath

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

    # Counter to keep track of the number of articles saved
    $articleCounter = 0

    # For each link in hrefList, go to that page and save the page source to a local file
    foreach ($href in $cleanHrefList) {
        if ($articleCounter -ge $maxArticles) {
            Write-Output "Maximum number of articles reached for $sourceUrl."
            break
        }

        # Convert href to url-safe string
        $hrefSafe = [System.Web.HttpUtility]::UrlEncode($href)
        $localFilePath = "C:\Users\brand\Documents\$hrefSafe.html"

        try {
            $response = Invoke-WebRequest -Uri $href -Method Get -Headers @{ 'Accept' = 'text/html' }
            
            # Check if the response contains the <article> tag using HtmlAgilityPack
            $htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
            $htmlDoc.LoadHtml($response.Content)
            $articleNodes = $htmlDoc.DocumentNode.SelectNodes("//article")
            $sectionNodes = $htmlDoc.DocumentNode.SelectNodes("//section")
        
            # If the response contains the <article> tag, save the response to a local file
            if ($articleNodes -ne $null) {
                Write-Output "Found <article> tag within: $href"

                foreach ($articleNode in $articleNodes) {
                    $articleContent = $articleNode.InnerText
                    Write-Output "Found article within $href with content length: $($articleContent.Length)"

                    if ($articleContent.Length -lt 1000) {
                        Write-Output "Skipping $href - Article content is too short"
                    } else {
                        $response.Content | Out-File -FilePath $localFilePath -Force
                        Write-Output "Successfully fetched and saved $href"
                        $articleCounter++
                        Write-Output "$articleCounter articles saved" 
                    }
                }

            } elseif ($sectionNodes -ne $null) {
                Write-Output "Found <section> tag within: $href"

                foreach ($sectionNode in $sectionNodes) {
                    $sectionContent = $sectionNode.InnerText
                    Write-Output "Found section within $href with content length: $($sectionContent.Length)"

                    if ($sectionContent.Length -lt 1000) {
                        Write-Output "Skipping $href - Section content is too short"
                    } else {
                        $response.Content | Out-File -FilePath $localFilePath -Force
                        Write-Output "Successfully fetched and saved $href"
                        $articleCounter++
                        Write-Output "$articleCounter articles saved" 
                    }
                }
            } else {
                Write-Output "Skipping $href - Does not contain <article> tag"
            }
        } catch {
            Write-Output "Failed to fetch ${href}"
        }
    }
}

# Read URLs from sources.json
$jsonContent = Get-Content -Path "./sources.json" | ConvertFrom-Json
$sources = $jsonContent.sources

# Create a HashSet to store visited links
$visitedLinks = New-Object "System.Collections.Generic.HashSet[string]"

# Start crawling
foreach ($sourceUrl in $sources) {
    Write-Output "Searching for articles from $sourceUrl..."
    Crawl-And-Save-Articles -url $sourceUrl -visitedLinks $visitedLinks -maxArticles 10
    Write-Output "Completed fetching for $sourceUrl!"
}