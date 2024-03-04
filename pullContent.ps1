Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function Find-Content {
    param (
        [Parameter(Mandatory=$true)]
        [string]$html,

        [Parameter(Mandatory=$true)]
        [string]$url
    )
    
    $doc = New-Object HtmlAgilityPack.HtmlDocument
    $doc.LoadHtml($html)
    
    $pElements = $doc.DocumentNode.SelectNodes("//p")
    
    $pTexts = foreach ($p in $pElements) {
        $p.InnerText
    }
    
    $combinedText = $pTexts -join ' '
    
    return @{
        url = $url
        content = $combinedText
    }

}
