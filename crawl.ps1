Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function fetchPage {
    param(
        [string]$url
    )

    try {
        Write-Host "Fetching HTML from $url"
        $html = Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' }
        return $html.Content
    } catch {
        Write-Host "Failed to fetch ${url}: $_"
        return $null
    }
}


function checkMetaType ($htmlContent) {
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
    $htmlDocument.LoadHtml($htmlContent)

    $ogTypeMetaTag = $htmlDocument.DocumentNode.SelectSingleNode('//meta[@property="og:type"]')

    if ($ogTypeMetaTag) {
        $ogTypeValue = $ogTypeMetaTag.GetAttributeValue('content', '')

        if ($ogTypeValue -eq 'article') {
            return $true
        } else {
            return $false
        }

    } else {
        return $false
    }
}

function wordCount($doc) {
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
    $htmlDocument.LoadHtml($doc)

    $textContent = @()
    $tagsToCollect = @('p', 'pre', 'td')
    $wordCount = 0

    foreach ($tag in $tagsToCollect) {
        $nodes = $htmlDocument.DocumentNode.SelectNodes("//$tag")

        if ($nodes) {
            foreach ($node in $nodes) {
                $textContent += $node.InnerHtml
            }

            $text = $textContent -join ' '
            $wordCount = $text.Split(' ').Count
        }
    }

    Write-Host "Word count: $wordCount"
    return $wordCount
}

function mediaNewsCheck($link) {
    $patternsToWatch = @('_video', '_slide', '_gallery', '_powerpoint', '_fashion', '_glamour', '_cloth')

    foreach ($string in $patternsToWatch) {
        if ($link -match $string) {
            return $true
        }
    }

    return $false
}


function CheckIfArticle($link) {
    $html = Invoke-WebRequest -Uri $link -Method Get -Headers @{ 'Accept' = 'text/html' }

    $wordCount = wordCount -doc $html.Content

    if ((checkMetaType $html.Content) -eq $false) {
        Write-Host "Not an article because: og:type is not article"
        return $false
    } elseif ($wordCount -lt 300) {
        Write-Host "Not an article because: low word count"
        return $false
    } elseif ((mediaNewsCheck $link) -eq $true) {
        Write-Host "Not an article because: media url pattern"
        return $false
    } else {
        return $true
    }


    # if ((getTitle -doc $htmlDoc) -ne '') {
    #     Write-Output "Title: $(getTitle -doc $html)"
    # } else {
    #     Write-Output "Title: No title found. Evidence that this is not an article"
    # }
}


# Takes in the HTML content and the URL of the page and returns an array of unique links
function extractLinks($html_content, $url, $uncrawledLinks, $existingArticleLinks, $linksAlreadyCrawled, $keywords) {
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html_content)

    $links = $doc.DocumentNode.SelectNodes("//a[@href]")

    # you have this list of links from the page. but you need to ensure the href associated with each link is not duplicated.
    # that way, you won't need to fetch the same page multiple times.
    $uniqueHrefs = New-Object System.Collections.Generic.HashSet[string]

    Write-Host "Going through the links and finding unique hrefs in $url"

    foreach ($link in $links) {
        $href = $link.GetAttributeValue("href", "")

        # Check if the href is not empty and not already in the HashSet
        if (-not [string]::IsNullOrEmpty($href) -and -not $uniqueHrefs.Contains($href)) {
            Write-Host "Added href: $href to the uniqueHrefs HashSet"
            [void]$uniqueHrefs.Add($href)
        } else {
            Write-Host "Skipping href: $href, already in the uniqueHrefs HashSet"
        }
    }

    Write-Host "All links: $allLinks. This is in the extractLinks function."

    $hrefs = New-Object Collections.Generic.HashSet[string]

    foreach ($href in $uniqueHrefs) {        
        Write-Host "Extracted href: $href"

        if (-not $href -or $href -eq '#' -or $href -eq '/') {
            continue  # Skip empty href attributes or href with value '#' or href with value '/'
        }
        

        if ($href -notlike "http*") { 
            Write-Host "Found a relative URL: $href"
            Write-Host "Converting relative URL to absolute URL"
            $href = $url + $href
            Write-Host "Absolute URL: $href"
        }

        $normalizedHref = normalizeUrl $href
        Write-Host "Evaluating this link: $normalizedHref in $url"


        # Check if the extracted link has the same domain as the base URL
        try {
            $linkUri = [System.Uri]::new($normalizedHref)
            $baseUri = [System.Uri]::new($url)
        }
        catch [System.UriFormatException] {
            Write-Host "Invalid URI: $normalizedHref"
            continue
        }
        

        if ($baseUri.Host -ne $linkUri.Host) {
            Write-Host "Skipping link $normalizedHref (different domain)"
            continue
        }



        # Check if the normalized href has already been added
        if ($allLinks.Contains($normalizedHref)) {
            Write-Host "Skipping link $normalizedHref (already added to allLinks)"
            continue
        }

        if ($hrefs.Contains($normalizedHref)) {
            Write-Host "Skipping link $normalizedHref (already added to current hrefs array)"
            continue
        }

        if ($existingArticleLinks.Contains($normalizedHref)) {
            Write-Host "Skipping link $normalizedHref (already saved in the csv (articles) file)"
            continue
        }


        # make a call to the CheckIfArticle function
        $isArticle = CheckIfArticle $normalizedHref
        Write-Host "Is this an article? $isArticle"
        if (-not $isArticle) {
            Write-Host "Skipping link $normalizedHref (not an article)"
            continue
        } else {
            Write-Host "This is an article"
        }


        # If the links passes all your checks, append the normalized href to the array
        Write-Host "Adding this link to the hrefs array: $normalizedHref"
        [void]$hrefs.Add($normalizedHref)

        # Break the loop if the count of hrefs is 10
        if ($hrefs.Count -eq 10) {
            Write-Host "Reached the limit of 5 hrefs"
            break
        }
    }

    Write-Host "Extracted link count: $($hrefs.Count) links from $url"

    $hrefs = $hrefs | Select-Object -Unique

    $hrefs | ForEach-Object {
        New-Object PSObject -Property @{
            'Href' = $_
        }
    } | Export-Csv -Path 'hrefs.csv' -NoTypeInformation -Append

    Write-Host "Extracted UNIQUE link count: $($hrefs.Count) links from $url"
    return , $hrefs # Return the HashSet as an array
}

function normalizeUrl($url) {
    $url = $url -replace "https?://", "https://"  # Ensure the URL has a scheme (https)
    $url = $url -replace "www\.", ""      # Remove www.
    $url = $url -replace "/$", ""         # Remove trailing slash
    $url = $url.ToLower()                  # Convert to lowercase
    # Write-Host "Normalized URL: $url"
    return $url
}


$newsSources = Get-Content -Path "./sources.json" | ConvertFrom-Json
$coreUrls = $newsSources.sources

$keywords = (Get-Content -Path "./keywords.json" | ConvertFrom-Json).keywords

$maxDepth = 3

Write-Host "Current value of core URLs: $coreUrls"

$linksAlreadyCrawled = @()

$uncrawledLinks = $coreUrls | ForEach-Object {
    normalizeUrl $_
}

# In the future, this will be loaded from the csv file
$existingArticleLinks = (Import-Csv -Path "hrefs.csv").Hrefs # name of the column in the CSV file

for ($depth = 1; $depth -le $maxDepth; $depth++) {
    Write-Host "Crawling depth $depth"

    # Loop through the links at the current depth level
    foreach ($currentLink in $uncrawledLinks) {
        Write-Host "Crawling $currentLink"

        $htmlContent = fetchPage -url $currentLink

        # Extract the links from the current page
        $links = extractLinks -html_content $htmlContent `
                              -url $currentLink `
                              -uncrawledLinks $uncrawledLinks `
                              -existingArticleLinks $existingArticleLinks `
                              -linksAlreadyCrawled $linksAlreadyCrawled `
                              -keywords $keywords

        # Add the extracted links to the list of all links
        $uncrawledLinks += $links
    }
}