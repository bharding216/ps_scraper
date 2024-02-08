Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function nodesToCheck($doc) {
    Write-Output "Checking nodes..."
    $nodesToCheck = @()
    $tags = 'p', 'pre', 'td'
    foreach ($tag in $tags) {
        $items = $doc.DocumentNode.SelectNodes("//${tag}")
        if ($items -ne $null) {
            $nodesToCheck += $items
        }
    }
    return $nodesToCheck
}

function getText($node) {
    $txts = @() # Array to store text from each node
    foreach ($i in $node.ChildNodes) {
        if ($i.NodeType -eq [HtmlAgilityPack.HtmlNodeType]::Text) {
            $txts += $i.InnerText
        }
    }
    return ($txts -join ' ').Trim()
}

function getStopwordCount {
    param (
        [string]$text
    )

    # Your list of stop words
    $stopwords = "a", "an", "the", "and", "or", "but", "is", "are", "was", "were", "it", "he", "she", "they", "we", "you", "in", "on", "at", "to"
    $stopwords = $stopwords | ForEach-Object { $_.ToLower() }

    # Split the text into words
    $words = $text -split "\s+"

    # Count the stop words
    $stopwordCount = 0
    foreach ($word in $words) {
        $word = $word.ToLower()

        if ($stopwords -contains $word) {
            $stopwordCount++
        }
    }

    return $stopwordCount
}



function isHighLinkDensity($node, $full_node_content) {
    # Checks the density of links ** within a node ** , if there is a high
    # link to text ratio, then the text is less likely to be relevant

    # Write-Output "Checking link density..."

    # Get all links within the node
    $nodeObject = New-Object HtmlAgilityPack.HtmlDocument
    $nodeObject.LoadHtml($full_node_content)
    $links = $nodeObject.DocumentNode.SelectNodes('//a')
    $linkCount = $links.Count

    # Write-Output "Link count: $linkCount"

    if ($linkCount -eq 0) {
        # Write-Output "No links found in this node... likely an article."
        return $false
    }

    # Determine the amount of text within node.
    $text = getText($node)
    # Write-Output "Text: $text"

    $words = $text.Split() | Where-Object { $_ -match '^\w+$' }
    if (!$words) {
        # Write-Output "No words found in this node... likely not an article."
        return $true
    }
    # Write-Output "Words: $($words.Count)"
    $words_number = $words.Count

    $sb = @() # String builder to store the text from each link
    foreach ($link in $links) {
        $sb += getText($link)
    }

    # Write-Output "Link text string builder: $sb"

    $link_text = $sb -join ' '
    # Write-Output "Link text: $link_text"

    # Words in <a> tags.
    $link_words = $link_text.Split()
    # Write-Output "Link words: $link_words"

    $num_link_words = $link_words.Count
    # Write-Output "Number of link words: $num_link_words"

    # (Number of words in links vs. Non-link words) * Number of links
    $score = ($num_link_words / $words_number) * $linkCount
    # Write-Output "Score: $score"

    if ($score -ge 1.0) {
        # Write-Output "High link density detected... likely not an article."
        return $true
    }
    # Write-Output "Low link density detected... likely an article."
    return $false
}

# Determine if the cleaned document is an article
function calculateBestNode($doc) {
    Write-Output "Calculating best node..."
    $top_node = $null
    $nodesToCheck = nodesToCheck($doc)
    $starting_boost = 1.0
    $cnt = 0
    $i = 0
    $parent_nodes = @()
    $nodes_with_text = @()

    Write-Output "Nodes to check: $($nodesToCheck.Count)"

    # Print each node in nodesToCheck
    # foreach ($node in $nodesToCheck) {
    #     Write-Output "Node full content: $($node.OuterHtml)"
    # }

    foreach ($node in $nodesToCheck) {
        Write-Output "Checking node $i..."

        $text_node = getText $node

        # Skip nodes with empty or whitespace-only text
        if ($text_node -match '\S') {
            # Write-Output "Text within node: $text_node"
            Write-Output "Node $i has non-empty text."
            
            # Write-Output "Calling getStopwordCount function..."
            $countOfStopWords = getStopwordCount $text_node
            Write-Output "Stopword count for node ${i}: $countOfStopWords"

            # $nodes_with_text += $node

            # Write-Output "The content of full_node_content is: $($node.OuterHtml)"
            # Analyze the frequency of links <a> in the node's full content (not just the text)
            # isHighLinkDensity -node $node -full_node_content $node.OuterHtml

            $high_link_density = isHighLinkDensity -node $node -full_node_content $node.OuterHtml
            Write-Output "High link density: $high_link_density for node $i"
            if (($countOfStopWords -gt 2) -and -not $high_link_density) {
                Write-Output "Node $i is a candidate for the top node."
                $nodes_with_text += $node

            } else {
                Write-Output "Node $i is not a candidate for the top node."
            }

        } else {
            Write-Output "Skipping node $i due to empty or whitespace-only text."
        }

        $i++
    }

    Write-Output "Nodes with text: $($nodes_with_text.Count)"

    $filePath = "C:/Users/brand/Documents/test.html"

    foreach ($node in $nodes_with_text) {
        "$($node.OuterHtml)" | Out-File -FilePath $filePath -Append
    }
}


$htmlDoc = New-Object HtmlAgilityPack.HtmlDocument
$htmlDoc.Load("C:/Users/brand/Documents/https___www.cnn.com_2024_01_30_politics_biden-middle-east-war-analysis_index.html")

Write-Output "Document loaded successfully!"

calculateBestNode -doc $htmlDoc

Write-Output "Program completed."


# If it is an article, extract the title, author, body, etc.
    # Get title
    # Get authors
    # Get keywords
    # Get publish date

    # This is done by the backend.