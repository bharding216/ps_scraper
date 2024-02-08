Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function fetchPage($url) {
    try {
        # Retrieve the HTML content of the $url
        Write-Host "Fetching $url"
        $html = Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' }
        return $html.Content
    } catch {
        Write-Host "Failed to fetch ${url}: $_"
        return $null
    }

}

function extractLinks($html_content, $url) {
    # Extract <a> links from the HTML content
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html_content)

    $links = $doc.DocumentNode.SelectNodes("//a[@href]") # Select all <a> nodes with an href attribute

    $hrefs = foreach ($link in $links) {
        $href = $link.GetAttributeValue("href", "")

        if (-not $href) {
            continue  # Skip empty href attributes
        }

        if ($href -notlike "http*") {
            # Convert relative URL to absolute URL using the base URL
            $href = [System.Uri]::new($url, $href).AbsoluteUri
        }

        $href
    }

    Write-Host "Extracted link count: $($hrefs.Count) links from $url"
    return $hrefs
}

function normalizeUrl($url) {
    $url = $url -replace "https?://", "https://"  # Ensure the URL has a scheme (https)
    $url = $url -replace "www\.", ""      # Remove www.
    $url = $url -replace "/$", ""         # Remove trailing slash
    $url = $url.ToLower()                  # Convert to lowercase
    return $url
}

function crawl($coreUrls) {
    $urlsVisited = @{}

    foreach ($coreUrl in $coreUrls) {
        Write-Host "Starting crawl process for $coreUrl"
        $normalizedCoreUrl = normalizeUrl $coreUrl
        $urlsVisited[$normalizedCoreUrl] = $true

        # fetch the page
        $html = fetchPage $normalizedCoreUrl

        # extract links
        $level_1_links = extractLinks $html $normalizedCoreUrl

        foreach ($link in $level_1_links) {
            $normalizedLink = normalizeUrl $link
            if (-not $urlsVisited.ContainsKey($normalizedLink)) {
                Write-Host "urlsVisited: $($urlsVisited.Keys -join ', ')"
                Write-Host "Found new link: $normalizedLink"
                $urlsVisited[$normalizedLink] = $true

                $level_2_links = extractLinks (fetchPage $normalizedLink) $normalizedLink

                foreach ($link2 in $level_2_links) {
                    $normalizedLink2 = normalizeUrl $link2
                    if (-not $urlsVisited.ContainsKey($normalizedLink2)) {
                        Write-Host "urlsVisited: $($urlsVisited.Keys -join ', ')"
                        Write-Host "Found new link: $normalizedLink2"
                        $urlsVisited[$normalizedLink2] = $true
                    } else {
                        Write-Host "Already visited $normalizedLink2"
                    }
                }
            } else {
                Write-Host "Already visited $normalizedLink"
            }
        }

        Write-Host "Finished crawling $coreUrl"
    }
}

$newsSources = Get-Content -Path "./sources.json" | ConvertFrom-Json
$coreUrls = $newsSources.sources

crawl -coreUrls $coreUrls
