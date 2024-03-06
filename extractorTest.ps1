Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function ShouldExcludeChildText($node) {
    return $node.Name -notmatch '^h[1-6]$' -and $node.ChildNodes.Count -gt 0
}

function Get-P-And-H-Tags($htmlNode, $MIN_P_TEXT_LENGTH, $MIN_HEADING_TEXT_LENGTH) {
    $pAndHTags = @()

    if ($htmlNode.Name -eq 'p' -or $htmlNode.Name -match '^h[1-6]$') {
        $innerText = [System.Web.HttpUtility]::HtmlDecode($htmlNode.InnerText.Trim())

        # Check if the node is a heading tag and whether to exclude text from child elements
        if ($htmlNode.Name -match '^h[1-6]$' -and -not (ShouldExcludeChildText $htmlNode) -and $innerText.Length -ge $MIN_HEADING_TEXT_LENGTH) {
            $tagContent = "<$($htmlNode.Name)>$($innerText)</$($htmlNode.Name)>"
            $pAndHTags += $tagContent
        }
        elseif (
            $htmlNode.Name -ne 'h1' -and
            $htmlNode.Name -ne 'h2' -and
            $htmlNode.Name -ne 'h3' -and
            $htmlNode.Name -ne 'h4' -and
            $htmlNode.Name -ne 'h5' -and
            $htmlNode.Name -ne 'h6' -and
            $htmlNode.Name -eq 'p' -and
            $innerText.Length -ge $MIN_P_TEXT_LENGTH
        ) {
            $tagContent = "<$($htmlNode.Name)>$($innerText)</$($htmlNode.Name)>"
            $pAndHTags += $tagContent
        }
    }

    foreach ($childNode in $htmlNode.ChildNodes) {
        $pAndHTags += Get-P-And-H-Tags -htmlNode $childNode -MIN_P_TEXT_LENGTH $MIN_P_TEXT_LENGTH -MIN_HEADING_TEXT_LENGTH $MIN_HEADING_TEXT_LENGTH
    }

    return $pAndHTags
}

function Split-Byline {
    param (
        [string]$searchStr
    )

    # Write-Host "Entering Split-Byline function"

    # Remove HTML tags and other non-name text
    $searchStr = $searchStr -replace '<[^<]+?>', ''
    $searchStr = $searchStr -replace '[bB][yY][\:\s]|[fF]rom[\:\s]', ''
    $searchStr = $searchStr.Trim()
    # Write-Host "searchStr: $searchStr"

    # Split the line into tokens using non-alphanumeric characters as delimiters
    $nameTokens = $searchStr -split "[^\w\'\-\.]"
    $nameTokens = $nameTokens | ForEach-Object { $_.Trim() }
    # Write-Host "nameTokens: $nameTokens"

    # Extracted author names from the tokens
    $authors = @()

    # Temporarily store the current name tokens
    $curName = @()

    # Delimiters that separate author names
    $delimiters = @('and', ',')

    # Iterate through the tokens and build the author names
    foreach ($token in $nameTokens) {
                
        # Check if the current token is a delimiter
        if ($delimiters -contains $token) {
                        
            # Check if there are name tokens stored in $curName
            if ($curName.Count -gt 0) {
                # Write-Host "curName count is greater than 0"
          
                # Join the name tokens in $curName and add to the $authors array
                $authors += $curName -join ' '
                $curName = @()
            }
        }
                
        # Check if the current token does not contain digits (avoid numeric tokens)
        elseif ($token -notmatch '\d') {
            $curName += $token
        }
    }

    # Check if there is a valid name in $curName (at least two name tokens)
    $validName = ($curName.Count -ge 2)
    if ($validName) {
        # Write-Host "validName is true"

        # Join the name tokens in $curName and add to the $authors array
        $authors += $curName -join ' '
    }

    # Write-Host "authors from split-byline function: $authors"

    return $authors
}


function Get-Author-Names($htmlNode) {
    # Write-Host "GETTING AUTHOR NAMES"
    $Attrs = @('name', 'rel', 'itemprop', 'class', 'id', '*')
    $Vals = @('author', 'byline', 'dc.creator', 'byl', 'story-meta__authors', 'byline-name')
    $Matched = @()
    $Authors = @()

    foreach ($Attr in $Attrs) {
        foreach ($Val in $Vals) {
            $Found = $htmlNode.SelectNodes("//*[@$Attr='$Val']")
            foreach ($node in $Found) {
                Write-Host "Found element: $($node.OuterHtml)"
            }
            $Matched += $Found
        }
    }

    foreach ($Match in $Matched) {
        $Content = ''
        if ($Match.Name -eq 'meta') {
            # Write-Host "Match is a meta tag"
            $Content = $Match.GetAttributeValue('content', '')
            # Write-Host "Content: $Content"
        } elseif ($Match.Name -eq 'p') {

            # Check if there is an author name within the anchor tag
            $AuthorName = $Match.SelectSingleNode('.//span[@class="vcard"]/a')
            
            if ($null -ne $AuthorName) {
                $Content = $AuthorName.InnerText
            }

        } elseif ($Match.Name -eq 'span') {
            $Content = $Match.InnerText

        } else {
            # Couldn't find a match ...
            $Content = $Match.innerText -or ''
        }

        if ($Content.Length -gt 0) {
            Write-Host "Passing this Content to Split-Byline: $Content"
            $Authors += Split-Byline $Content
        }
    
    }

    ##################################

    # $authorPattern = "By (.+?) (.+?)"

    # $matchingNodes = $htmlDocument.DocumentNode.SelectNodes("//*[contains(translate(text(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz'), '$authorPattern')]")

    # if ($null -eq $matchingNodes) {
    #     Write-Host "No matching nodes found."
    #     return
    # }

    # foreach ($node in $matchingNodes) {
    #     $textContent = $node.InnerText
    #     if ($textContent -match $authorPattern) {
    #         $authorString = $Matches[0]
    #         $authors = $authorString -split ',\s*and|\s*,\s*'

    #         foreach ($author in $authors) {
    #             $author -match $authorPattern
    #             $firstName = $Matches[1]
    #             $lastName = $Matches[2]
    #             Write-Host "Author found using method 2: $firstName $lastName"
    #         }
    #     }
    # }

    ##################################


    return $Authors

}

function Get-Title($htmlNode) {
    $titleNode = $htmlNode.SelectSingleNode('//*[self::h1 or self::h2 or self::h3 or self::h4 or self::h5 or self::h6][contains(@class, "headline")]')
    if ($null -ne $titleNode) {
        $title = $titleNode.InnerText.Trim()
        return $title
    }

    return $null
}


$path_to_html = "C:\Users\brand\Projects\IBTS\scraper\ps_scraper\html_test_3.html"
$MIN_P_TEXT_LENGTH = 25
$MIN_HEADING_TEXT_LENGTH = 25

$htmlContent = Get-Content -Path $path_to_html -Raw -Encoding UTF8
$htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
$htmlDocument.LoadHtml($htmlContent)

$pAndHTags = Get-P-And-H-Tags -htmlNode $htmlDocument.DocumentNode -MIN_P_TEXT_LENGTH $MIN_P_TEXT_LENGTH -MIN_HEADING_TEXT_LENGTH $MIN_HEADING_TEXT_LENGTH

$authorNames = Get-Author-Names -htmlNode $htmlDocument.DocumentNode

$title = Get-Title -htmlNode $htmlDocument.DocumentNode

Write-Host "HERE IS YOUR TITLE:"
Write-Host ($title -join "`r`n`n")

Write-Host "`r`n"

Write-Host "HERE IS YOUR CONTENT:"
Write-Host ($pAndHTags -join "`r`n`n")

Write-Host "`r`n"

Write-Host "HERE IS YOUR AUTHOR(S):"
Write-Host ($authorNames -join "`r`n`n")