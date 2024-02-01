# Add HtmlAgilityPack.dll to the PowerShell session
Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function Save-WebPage {
    param (
        [string]$url,
        [string]$localFilePath
    )

    Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' } -OutFile $localFilePath
}

function Get-CleanHrefList {
    param (
        [System.Collections.Generic.List[string]]$links,
        [string]$url
    )

    $cleanHrefList = @()

    foreach ($link in $links) {
        $href = $link.GetAttributeValue('href', '')

        if ($href -match '^/') {
            $href = $url + $href
        }

        if ($href -notmatch "^$([regex]::Escape($url))") {
            continue
        }

        $cleanHrefList += $href
    }

    $cleanHrefList | Sort-Object -Unique
}

function Save-Article {
    param (
        [string]$href,
        [int]$maxArticles,
        [ref]$articleCounter
    )

    if ($articleCounter.Value -ge $maxArticles) {
        Write-Output "Maximum number of articles reached."
        return $true
    }

    $hrefSafe = [System.Web.HttpUtility]::UrlEncode($href)
    $localFilePath = "C:\Users\brand\Documents\$hrefSafe.html"

    try {
        $response = Invoke-WebRequest -Uri $href -Method Get -Headers @{ 'Accept' = 'text/html' }
        
        # Check if the response contains the <article> tag using HtmlAgilityPack
        $htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
        $htmlDoc.LoadHtml($response.Content)
        $articleNodes = $htmlDoc.DocumentNode.SelectNodes("//article")
        
        if ($articleNodes -ne $null) {
            Save-ArticleContent $articleNodes $href $localFilePath
            $articleCounter.Value++
            Write-Output "$($articleCounter.Value) articles saved"
        } else {
            Write-Output "Skipping $href - Does not contain <article> tag"
        }
    } catch {
        Write-Output "Failed to fetch ${href}"
    }

    return $false
}

function Save-ArticleContent {
    param (
        [System.Collections.Generic.List[string]]$articleNodes,
        [string]$href,
        [string]$localFilePath
    )

    foreach ($articleNode in $articleNodes) {
        $articleContent = $articleNode.InnerText

        if ($articleContent.Length -lt 1000) {
            Write-Output "Skipping $href - Article content is too short"
        } else {
            $articleNode.InnerText | Out-File -FilePath $localFilePath -Force
            Write-Output "Successfully fetched and saved $href"
        }
    }
}

function Crawl-And-Save-Articles {
    param (
        [string]$url,
        [System.Collections.Generic.HashSet[string]]$visitedLinks,
        [int]$maxArticles = 10
    )

    $filename = "article_$((Get-Date).ToString('yyyyMMdd_HHmmss'))"
    $localFilePath = "C:\Users\brand\Documents\$filename.html"

    Save-WebPage -url $url -localFilePath $localFilePath

    $htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
    $htmlDoc.Load($localFilePath)

    $links = $htmlDoc.DocumentNode.SelectNodes("//a[@href]")

    $cleanHrefList = Get-CleanHrefList -links $links -url $url

    Write-Output "Found $($cleanHrefList.Count) links on $url"

    $articleCounter = 0

    foreach ($href in $cleanHrefList) {
        if (Save-Article -href $href -maxArticles $maxArticles -articleCounter ([ref]$articleCounter)) {
            break
        }
    }
}

# Example usage
Crawl-And-Save-Articles -url "https://www.cnn.com"
