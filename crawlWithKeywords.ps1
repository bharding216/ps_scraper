Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function fetchPage {
    param(
        [string]$url,
        [int]$delayInSeconds = 3
    )

    try {
        # Write-Host "Fetching HTML from $url"
        $html = Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' } -ErrorAction Stop
        $startSleep = Get-Date
        Write-Host "Time fell asleep: $startSleep"
        Start-Sleep -Seconds $delayInSeconds
        $endSleep = Get-Date
        Write-Host "Time woke up: $endSleep"
        return $html.Content
    } catch {
        Write-Host "Failed to fetch ${url}. This page threw an error: $($_.Exception.Message)"
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

    # Write-Host "Word count: $wordCount"
    return $wordCount
}

function mediaNewsCheck($link) {
    $patternsToWatch = @('/video/?', '/slide/?', '/gallery/?', '/powerpoint/?', '/fashion/?', '/glamour/?', '/cloth/?', '/live/?', '/podcast/?', '/reel/?', '/audio/?', '/profile/?', '/photo/?', '/terms/?', '/privacy/?', '/cookie/?', '/about/?', '/contact/?', '/advert/?', '/subscribe/?', '/subscription/?', '/shop/?', '/store/?', '/buy/?', '/purchase/?', '/donate/?', '/support/?', '/help/?', '/faq/?', '/feedback/?', '/survey/?', '/poll/?', '/quiz/?', '/competition/?', '/contest/?', '/sweepstake/?', '/sweepstakes/?', '/lottery/?', '/bet/?', '/gamble/?', '/casino/?', '/poker/?', '/bingo/?', '/slot/?', '/roulette/?', '/blackjack/?', '/craps/?', '/baccarat/?', '/keno/?', '/scratch/?', '/scratchcard/?', '/scratchcard/?', '/lotto/?')
    
    foreach ($string in $patternsToWatch) {
        if ($link -match $string) {
            Write-Host "Media URL pattern found: $string"
            return $true
        }
    }

    return $false
}


function CheckIfArticle($html, $newLink) {

    $wordCount = wordCount -doc $html.Content

    if ((checkMetaType $html.Content) -eq $false) {
        # Write-Host "Not an article because: og:type is not article"
        return $false
    } elseif ($wordCount -lt 300) {
        # Write-Host "Not an article because: low word count"
        return $false
    } elseif ((mediaNewsCheck $newLink) -eq $true) {
        # Write-Host "Not an article because: media url pattern"
        return $false
    } else {
        return $true
    }
}


function CheckIfPageContainsKeywords($html, $keywords) {
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
    $htmlDocument.LoadHtml($html.Content)

    $textContent = New-Object System.Text.StringBuilder
    $tagsToCollect = @('p', 'pre', 'th', 'td', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'title')

    foreach ($tag in $tagsToCollect) {
        $nodes = $htmlDocument.DocumentNode.SelectNodes("//$tag")

        if ($nodes) {
            foreach ($node in $nodes) {
                $null = $textContent.Append($node.InnerText.ToLower())
            }

        }
    }

    # Write-Host "Text in html for keyword match: $($textContent.ToString())"

    foreach ($keyword in $keywords) {
        if ($textContent.ToString().Contains($keyword)) {
            # Write-Host "Found keyword: $keyword"
            return $true
        }
    }
    return $false
}



function normalizeUrl($url) {
    $url = $url -replace "https?://", "https://"  # Ensure the URL has a scheme (https)
    $url = $url -replace "www\.", ""      # Remove www.
    $url = $url -replace "/$", ""         # Remove trailing slash
    $url = $url.ToLower()                  # Convert to lowercase
    # Write-Host "Normalized URL: $url"
    return $url
}



# Takes in the HTML content and the URL of the page and returns an array of unique links
function extractLinks($html_content, $url, $linksToCrawl, $existingArticleLinks, $linksAlreadyCrawled, $keywords, $linksAlreadyCheckedIfArticle) {
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html_content)

    $newLinks = @()

    $links = $doc.DocumentNode.SelectNodes("//a[@href]")

    # A set of unique hrefs in the HTML document
    $uniqueHrefs = New-Object System.Collections.Generic.HashSet[string]
    
    Write-Host "Going through the <a>s in the HTML and finding unique hrefs in $url"
    foreach ($link in $links) {
        $href = $link.GetAttributeValue("href", "")

        # Check if the href is not empty and not already in the HashSet
        if (-not [string]::IsNullOrEmpty($href) -and -not $uniqueHrefs.Contains($href) -and -not $linksAlreadyCheckedIfArticle.Contains($href)) {
            [void]$uniqueHrefs.Add($href)
            # Write-Host "Added href: $href to the uniqueHrefs HashSet"
        } else {
            # Write-Host "Skipping href: $href, already in the uniqueHrefs HashSet or linksAlreadyCheckedIfArticle array"
        }
    }

    # Go through the unique hrefs and handle the blanks and relative urls.
    foreach ($href in $uniqueHrefs) {        
        if (-not $href -or $href -eq '#' -or $href -eq '/') {
            continue  # Skip empty href attributes or href with value '#' or href with value '/'
        }
        
        if ($href -notlike "http*") { 
            # Write-Host "Converting relative URL to absolute URL"
            $urlBase = [System.Uri]::new($url)
            $href = New-Object System.Uri($urlBase, $href)
        }

        # Normalize each href
        $normalizedHref = normalizeUrl $href


        # Write-Host "Evaluating this link: $normalizedHref in $url"
        # Check if the extracted link has the same domain as the base URL
        try {
            $linkUri = [System.Uri]::new($normalizedHref)
            $baseUri = [System.Uri]::new($url)
        }
        catch [System.UriFormatException] {
            # Write-Host "Invalid URI: $normalizedHref"
            continue
        }
        
        if ($baseUri.Host -ne $linkUri.Host) {
            # Write-Host "Skipping link $normalizedHref (different domain)"
            continue
        }

        # Check if the normalized href has already been added
        if ($linksToCrawl.Contains($normalizedHref)) {
            # Write-Host "Skipping link $normalizedHref (already added to linksToCrawl array)"
            continue
        }
        

        if ($existingArticleLinks.Contains($normalizedHref)) {
            # Write-Host "Skipping link $normalizedHref (already saved in the csv (articles) file)"
            continue
        }

        # Write-Host "Adding link $normalizedHref to linksToCrawl array"
        $newLinks += $normalizedHref
    }

    # Write-Host "Returning newLinks array"
    return , $newLinks
}


# Definitions:
# - uncrawledLinks: links where you have not made a web requrest to get the html and pull the <a> hrefs for.
# - linksAlreadyCheckedIfArticle: links that you have made a web request and pulled the html for.
# - existingArticleLinks: links where you have deemed them as an article containing at least one keyword.


$newsSources = Get-Content -Path "./sources.json" | ConvertFrom-Json
$coreUrls = $newsSources.sources

# Write-Host "Current value of core URLs: $coreUrls"

$keywords = (Get-Content -Path "./keywords.json" | ConvertFrom-Json).keywords

$articleCount = 0
$numberOfArticlesToCollectUntilNewDomain = 15
$linksAlreadyCheckedIfArticle = (Import-Csv -Path "linksAlreadyCheckedIfArticle.csv").checked_if_article # name of the column in the CSV file
$linksAlreadyCrawled = @()

# Long-term, this will be loaded from a csv or database.
$linksToCrawl = $coreUrls | ForEach-Object {
    normalizeUrl $_
}

# In the future, this will be loaded from the provided csv file
$existingArticleLinks = (Import-Csv -Path "articles.csv").Articles # name of the column in the CSV file

$currentDomain = 'politico.com'

$startTime = Get-Date
"Start Time: $startTime" | Out-File -FilePath "timeElapsed.txt" -Append

while ($linksToCrawl.Count -gt 0) {
    $linksToCrawl = $linksToCrawl | Get-Random -Count $linksToCrawl.Count
    Write-Host "linksToCrawl contains this many links: $($linksToCrawl.Count)"
    # Write-Host "Current value of linksToCrawl array: $linksToCrawl"
    $link = $linksToCrawl | Where-Object { $_ -notlike "*$currentDomain*" } | Select-Object -First 1

    # Write-Host "Fetching page from link: $link in the linksToCrawl array"
    # Write-Host "This should be a different domain than $currentDomain."
    $html = fetchPage -url $link

    if (-not $html) {
        Write-Host "Tried fetching $link, but it returned an error. Going to the next link in linksToCrawl array."
        $linksToCrawl = $linksToCrawl | Where-Object { $_ -ne $link }
        continue
    }

    $newLinks = extractLinks `
        -html_content $html `
        -url $link `
        -linksToCrawl $linksToCrawl `
        -existingArticleLinks $existingArticleLinks `
        -linksAlreadyCrawled $linksAlreadyCrawled `
        -linksAlreadyCheckedIfArticle $linksAlreadyCheckedIfArticle


    $linksToCrawl += $newLinks

    $linksToCrawl = $linksToCrawl | Select-Object -Unique

    $articleCount = 0

    foreach ($newLink in $newLinks) {
        # if $newLink is not in $linksAlreadyCheckedIfArticle
        if ($linksAlreadyCheckedIfArticle.Contains($newLink)) {
            # Write-Host "Skipping $newLink because it's already in linksAlreadyCheckedIfArticle array"
            continue
        }

        # Write-Host "Adding $newLink to linksAlreadyCheckedIfArticle array"
        $linksAlreadyCheckedIfArticle += $newLink
        
        ##########
        # Checking if article and if it contains keywords

        try {
            $html = Invoke-WebRequest -Uri $newLink -Method Get -Headers @{ 'Accept' = 'text/html' } -ErrorAction Stop
            Start-Sleep -Seconds 3
        } 
        catch {
            Write-Host "Tried to fetch ${newLink}, but it returned an error. Skipping this link."
            continue
        }

        # Write-Host "Checking if $newLink is an article"
        $isArticle = CheckIfArticle $html, $newLink
        # Write-Host "Checking if $newLink contains keywords"

        if ($isArticle -eq $true) {
            $containsKeywords = CheckIfPageContainsKeywords $html $keywords
        } else {
            $containsKeywords = $false
        }  


        ##########

        # Write-Host "Adding $newLink to linksAlreadyCheckedIfArticle csv"
        $linksAlreadyCheckedIfArticle += $newLink
        New-Object PSObject -Property @{
            'checked_if_article' = $newLink
        } | Export-Csv -Path 'linksAlreadyCheckedIfArticle.csv' -NoTypeInformation -Append

        if ($isArticle -eq $true -and $containsKeywords -eq $true) {
            Write-Host "Found an article that contains keywords!"
            $existingArticleLinks += $newLink
            $articleCount++
            Write-Host "New article count: $articleCount"

            # Write-Host "Adding $newLink to articles.csv"
            New-Object PSObject -Property @{
                'Articles' = $newLink
            } | Export-Csv -Path 'articles.csv' -NoTypeInformation -Append
        }

        $currentDomain = [System.Uri]::new($newLink).Host
        # Write-Host "Current domain: $currentDomain"

        if ($articleCount -eq $numberOfArticlesToCollectUntilNewDomain) {
            Write-Host "Article count reached the limit of $numberOfArticlesToCollectUntilNewDomain"            
            # $endTime = Get-Date
            # "End Time: $endTime" | Out-File -FilePath "timeElapsed.txt" -Append
            # $timeElapsed = $endTime - $startTime
            # Write-Host "Total time elapsed: $timeElapsed"
            # "Total time elapsed: $timeElapsed" | Out-File -FilePath "timeElapsed.txt" -Append
            break
        }
    }

    # Write-Host "Removing $link from linksToCrawl array"
    $linksToCrawl = $linksToCrawl | Where-Object { $_ -ne $link }
}

# may not need
$linksToCrawl | ForEach-Object {
    New-Object PSObject -Property @{
        'Href' = $_
    }
} | Export-Csv -Path 'linksToCrawl.csv' -NoTypeInformation -Append