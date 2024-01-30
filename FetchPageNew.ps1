# To run the script, enter the following command in the terminal:
# .\FetchPageNew.ps1

Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

# Function to crawl a given URL and save articles
function Crawl-And-Save-Articles {
    param (
        [string]$url,
        [int]$maxArticles,
        [System.Collections.Generic.HashSet[string]]$visitedLinks
    )

    # Check if the maximum number of articles has been reached
    if ($visitedLinks.Count -ge $maxArticles) {
        Write-Output "You reached the max number of articles"
        return
    }

    # Fetch HTML content from the current URL
    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"

    $html = Invoke-WebRequest -Uri $url -TimeoutSec 10 -Headers @{ "User-Agent" = $userAgent } -ErrorAction Stop

    # Check if the current page is an article
    if (Is-Article -html $html) {
        # if True, save the raw HTML content to a local file
        $filename = "article_$((Get-Date).ToString('yyyyMMdd_HHmmss')).html"
        $html.Content | Out-File -FilePath "C:\Users\brand\Documents\$filename" -Encoding UTF8
        Write-Output "Article saved: $filename"
    }

    # Extract all links from the current page
    $links = Get-Links -html $html
    Write-Output "Found $($links.Count) links on $url"
    Write-Output "Found these links: $($links -join ', ')"

    # Visit each link if not already visited
    foreach ($link in $links) {
        if (-not $visitedLinks.Contains($link)) {
            $visitedLinks.Add($link) # Add link to 'visited' links list
            Crawl-And-Save-Articles -url $link -maxArticles $maxArticles -visitedLinks $visitedLinks
        }
    }
}

# Function to check if a given HTML content represents an article
function Is-Article {
    param (
        [string]$html
    )

    # Check if the HTML contains the <article> element
    $isArticle = $html -match '<article\b[^>]*>.*?</article>'
    
    if ($isArticle) {
        return "This page is an article."
    } else {
        return "This page is not an article."
    }
}

# Function to extract all links from HTML content
function Get-Links {
    param (
        [string]$html
    )

    # Load HTML content into HtmlDocument
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html)

    # Extract all links from the HTML document
    $links = $doc.DocumentNode.SelectNodes('//a[@href]') | ForEach-Object { $_.Attributes['href'].Value }
    
    return $links
}

# Set the starting URL and maximum number of articles to collect
$startUrl = "https://www.cnn.com"
$maxArticles = 10

# Create a HashSet to store visited links
$visitedLinks = New-Object "System.Collections.Generic.HashSet[string]"

# Start crawling
Crawl-And-Save-Articles -url $startUrl -maxArticles $maxArticles -visitedLinks $visitedLinks
