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

# function wordCount($doc) {
#     $textContent = @()
#     $tagsToCollect = @('p', 'pre', 'td')
#     $wordCount = 0

#     foreach ($tag in $tagsToCollect) {
#         $nodes = $doc.DocumentNode.SelectNodes("//$tag")

#         if ($nodes) {
#             foreach ($node in $nodes) {
#                 $textContent += $node.InnerHtml
#             }

#             $text = $textContent -join ' '
#             $wordCount = $text.Split(' ').Count
#         }
#     }

#     return $wordCount
# }


function CheckIfArticle($link) {
    $html = Invoke-WebRequest -Uri $link -Method Get -Headers @{ 'Accept' = 'text/html' }

    if ((checkMetaType $html.Content) -eq $true) {
        return $true
    } else {
        return $false
    }

    # $wordCount = wordCount -doc $html

    # if ($wordCount -gt 500) {
    #     Write-Output "This page has MORE than 500 words, evidence of an article."

    # } else {
    #     Write-Output "This page has LESS than 500 words."
    # }

    # if ((mediaNewsCheck -fileName $fileName) -eq $true) {
    #     Write-Output "This page is a media/news page, most likely not an article."
    # } else {
    #     Write-Output "This page is NOT a media/news page."
    # }

    # if ((getTitle -doc $htmlDoc) -ne '') {
    #     Write-Output "Title: $(getTitle -doc $html)"
    # } else {
    #     Write-Output "Title: No title found. Evidence that this is not an article"
    # }
}


# Takes in the HTML content and the URL of the page and returns an array of unique links
function extractLinks($html_content, $url, $allLinks) {
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html_content)

    $links = $doc.DocumentNode.SelectNodes("//a[@href]")

    # you have this list of links from the page. but you need to ensure the href associated with each link is not duplicated.
    # that way, you won't need to fetch the same page multiple times.
    $uniqueHrefs = New-Object System.Collections.Generic.HashSet[string]

    Write-Host "Going through the links and finding unique hrefs"

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
    }

    Write-Host "Extracted link count: $($hrefs.Count) links from $url"

    $hrefs = $hrefs | Select-Object -Unique

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

# function crawl($coreUrls) {
#     $urlsVisited = New-Object Collections.Generic.HashSet[string]

#     # Will be sites like cnn.com, bbc.com, etc.
#     foreach ($coreUrl in $coreUrls) {
#         Write-Host "Starting crawl process for core URL: $coreUrl"
#         $normalizedCoreUrl = normalizeUrl $coreUrl
#         [void]$urlsVisited.Add($normalizedCoreUrl)

#         # Fetch the HTML content of the core URL
#         $html = fetchPage $normalizedCoreUrl

#         # Extract links from the core URL's HTML content
#         # FYI: Level 1 links are links on the home page of the news site
#         $level_1_links = extractLinks $html $normalizedCoreUrl
#         Write-Host "Extracted level 1 links:" $level_1_links

#         Write-Host "Starting to crawl through level 1 links..."
#         foreach ($link in $level_1_links) {
#             Write-Host "About to normalize this link: $link"
#             $normalizedLink = normalizeUrl $link
#             Write-Host "Normalized link: $normalizedLink"

#             Write-Host "Checking if $normalizedLink has been visited."
#             if (-not $urlsVisited.Contains($normalizedLink)) {
#                 Write-Host "List of urlsVisited: $($urlsVisited.Keys -join ', ')"
#                 Write-Host "This link is not in the urlsVisited list: $normalizedLink"

#                 # Export level 1 links to CSV
#                 $csvPath = "links.csv"
#                 $level_1_links | ForEach-Object {
#                     [PSCustomObject]@{
#                         Link = $_
#                     }
#                 } | Export-Csv -Path $csvPath -NoTypeInformation -Append

#                 Write-Host "Level 1 links exported to $csvPath"

#                 [void]$urlsVisited.Add($normalizedLink)

#                 $level_2_links = extractLinks (fetchPage $normalizedLink) $normalizedLink

#                 foreach ($link2 in $level_2_links) {
#                     $normalizedLink2 = normalizeUrl $link2
#                     if (-not $urlsVisited.Contains($normalizedLink2)) {
#                         Write-Host "urlsVisited: $($urlsVisited.Keys -join ', ')"
#                         Write-Host "Found new link: $normalizedLink2"

#                         # Append level 2 links to the CSV file
#                         $level_2_links | ForEach-Object {
#                             [PSCustomObject]@{
#                                 Link = $_
#                             }
#                         } | Export-Csv -Path $csvPath -NoTypeInformation -Append

#                         Write-Host "Level 2 links appended to $csvPath"

#                         [void]$urlsVisited.Add($normalizedLink2)
#                     } else {
#                         Write-Host "Already visited $normalizedLink2"
#                     }
#                 }

#             } else {
#                 Write-Host "Already visited $normalizedLink"
#             }
#         }

#         Write-Host "Finished crawling $coreUrl"
#     }
# }


$newsSources = Get-Content -Path "./sources.json" | ConvertFrom-Json
$coreUrls = $newsSources.sources

$maxDepth = 3

$allLinks = @($coreUrls)
Write-Host "Current value of all links: $allLinks"

# Convert each link in $allLInks to a normalized URL
$allLinks = $allLinks | ForEach-Object {
    normalizeUrl $_
}

for ($depth = 1; $depth -le $maxDepth; $depth++) {
    Write-Host "Crawling depth $depth"

    # Loop through the links at the current depth level
    foreach ($currentLink in $allLinks) {
        Write-Host "Crawling $currentLink"

        $htmlContent = fetchPage -url $currentLink

        # Extract the links from the current page
        $links = extractLinks -html_content $htmlContent -url $currentLink -allLinks $allLinks

        # Add the extracted links to the list of all links
        $allLinks += $links
    }
}