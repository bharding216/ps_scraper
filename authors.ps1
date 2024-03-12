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

    return $Authors

}