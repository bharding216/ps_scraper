Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function ShouldExcludeChildText($node) {
    return $node.ChildNodes.Count -gt 0
}
function Get-P-And-H-Tags($htmlNode) {
    $pAndHTags = @()

    if ($htmlNode.Name -eq 'p' -or $htmlNode.Name -match '^h[1-6]$') {
        $innerText = $htmlNode.InnerText.Trim()

        # Check if the node is a heading tag and whether to exclude text from child elements
        if ($htmlNode.Name -match '^h[1-6]$' -and -not (ShouldExcludeChildText $htmlNode)) {
            $tagContent = "<$($htmlNode.Name)>$($innerText)</$($htmlNode.Name)>"
            $pAndHTags += $tagContent
        }
        elseif ($htmlNode.Name -ne 'h1' -and $htmlNode.Name -ne 'h2' -and $htmlNode.Name -ne 'h3' -and $htmlNode.Name -ne 'h4' -and $htmlNode.Name -ne 'h5' -and $htmlNode.Name -ne 'h6') {
            $tagContent = "<$($htmlNode.Name)>$($innerText)</$($htmlNode.Name)>"
            $pAndHTags += $tagContent
        }
    }

    foreach ($childNode in $htmlNode.ChildNodes) {
        $pAndHTags += Get-P-And-H-Tags $childNode
    }

    return $pAndHTags
}

$htmlContent = Get-Content -Path 'C:\Users\brand\Projects\IBTS\scraper\ps_scraper\html_test_1.html' -Raw
$htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
$htmlDocument.LoadHtml($htmlContent)

$pAndHTags = Get-P-And-H-Tags $htmlDocument.DocumentNode

Write-Host "Final result:"
Write-Host ($pAndHTags -join "`r`n`n")