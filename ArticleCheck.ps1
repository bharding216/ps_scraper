Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

# Function to check if a given HTML document seems to be an article
function IsArticle([string]$htmlContent) {
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($htmlContent)

    # Define criteria for determining an article
    $articleCriteria = @(
        'article', 'content', 'post', 'entry', 'blog', 'story'
    )

    # Check if any of the criteria are present in the HTML structure
    foreach ($criteria in $articleCriteria) {
        $nodes = $doc.DocumentNode.SelectNodes("//*[contains(@class, '$criteria')]")
        if ($nodes -ne $null) {
            return $true
        }
    }

    # If no criteria match, it may not be an article
    return $false
}


$htmlContent = Get-Content -Path "C:\Users\brand\Documents\cnn_homepage.html" -Raw

if (IsArticle $htmlContent) {
    Write-Host "The document seems to be an article."
} else {
    Write-Host "The document may not be an article."
}
