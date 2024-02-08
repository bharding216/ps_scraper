Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function checkMetaType ($doc) {
    $ogTypeMetaTag = $doc.DocumentNode.SelectSingleNode('//meta[@property="og:type"]')

    if ($ogTypeMetaTag) {
        $ogTypeValue = $ogTypeMetaTag.GetAttributeValue('content', '')
        Write-Output "og:type value: $ogTypeValue"

        if ($ogTypeValue -eq 'article') {
            Write-Output "This is an article page."
            return $true

        } else {
            Write-Output "This is not an article page."
            return $false
        }

    } else {
        Write-Output "og:type meta property not found on the page."
        return $false
    }
}

function wordCount($doc) {
    $textContent = @()
    $tagsToCollect = @('p', 'pre', 'td')
    $wordCount = 0

    foreach ($tag in $tagsToCollect) {
        $nodes = $doc.DocumentNode.SelectNodes("//$tag")

        if ($nodes) {
            foreach ($node in $nodes) {
                $textContent += $node.InnerHtml
            }

            $text = $textContent -join ' '
            $wordCount = $text.Split(' ').Count
        }
    }

    return $wordCount
}

function mediaNewsCheck($fileName) {
    $patternsToWatch = @('_video', '_slide', '_gallery', '_powerpoint', '_fashion', '_glamour', '_cloth')

    foreach ($string in $patternsToWatch) {
        if ($fileName -match $string) {
            return $true
        }
    }

    return $false
}

function getTitle ($doc) {
    $title = $doc.DocumentNode.SelectSingleNode('//title')

    if (-not $title) {
        $title = ''
        return $title
    }

    return $title.InnerText
}


$directory = "C:\Users\brand\Documents"
$htmlFiles = Get-ChildItem -Path $directory -Filter "*.html"

foreach ($file in $htmlFiles) {
    $htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
    $htmlDoc.Load($file.FullName)

    Write-Output "Document loaded successfully: $($file.Name)"
    $fileName = $file.Name

    if ((checkMetaType -doc $htmlDoc) -eq $true) {
        Write-Output "This page has type = article."
    } else {
        Write-Output "This page DOES NOT have type = article."
    }

    $wordCount = wordCount -doc $htmlDoc

    if ($wordCount -gt 500) {
        Write-Output "This page has MORE than 500 words, evidence of an article."

    } else {
        Write-Output "This page has LESS than 500 words."
    }

    if ((mediaNewsCheck -fileName $fileName) -eq $true) {
        Write-Output "This page is a media/news page, most likely not an article."
    } else {
        Write-Output "This page is NOT a media/news page."
    }

    if ((getTitle -doc $htmlDoc) -ne '') {
        Write-Output "Title: $(getTitle -doc $htmlDoc)"
    } else {
        Write-Output "Title: No title found. Evidence that this is not an article"
    }
}

Write-Output "Program completed."