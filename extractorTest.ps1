Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'
Add-Type -AssemblyName System.Web

function Get-Article-Content($htmlNode, $MIN_P_TEXT_LENGTH, $MIN_HEADING_TEXT_LENGTH) {
    $content = @()

    try {
        Write-Host "HTML Content:"
        Write-Host $htmlNode.OuterHtml

        # Collect <p> tags
        $paragraphs = $htmlNode.SelectNodes('//*[self::p]')

        if ($null -ne $paragraphs) {
            foreach ($paragraph in $paragraphs) {
                $content += $paragraph.InnerText
            }
        }

        # Collect <h1>, <h2>, <h3>, etc., tags
        for ($i = 1; $i -le 6; $i++) {
            $headings = $htmlNode.SelectNodes("//*[self::h$i]")
            if ($null -ne $headings) {
                foreach ($heading in $headings) {
                    $content += $heading.InnerText
                }
            }
        }

    } catch {
        Write-Host "Error: $_"
    }


    return $content
}



function Get-Title($htmlNode) {
    $title = Find-Title-Tag -htmlNode $htmlNode
    if ($title.Length -gt 0) {
        return $title
    }

    $h1 = Find-H1-Tag -htmlNode $htmlNode
    if ($h1.Length -gt 0) {
        return $h1
    }
}


function Find-Title-Tag($htmlNode) {
    $title = ''
    $title_elements = $htmlNode.SelectNodes('//title')

    # no title found
    if ($null -eq $title_elements -or $title_elements.Count -eq 0) {
        return $title
    }
    
    # If title is found, you can extract its text content using HTML Agility Pack
    $title = $title_elements[0].InnerText
    return $title
}


function Find-H1-Tag($htmlNode) {
    $h1 = ''
    $h1_elements = $htmlNode.SelectNodes('//h1')

    if ($null -eq $h1_elements -or $h1_elements.Count -eq 0) {
        return $h1
    }

    # select the longest h1 tag
    $h1_elements = $h1_elements | Sort-Object -Property InnerText -Descending
    $h1 = $h1_elements[0].InnerText
    return $h1
}



$path_to_html = "C:\Users\brand\Projects\IBTS\scraper\ps_scraper\html_test_4.html"
$MIN_P_TEXT_LENGTH = 25
$MIN_HEADING_TEXT_LENGTH = 25

$htmlContent = Get-Content -Path $path_to_html -Raw -Encoding UTF8
$htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
$htmlDocument.LoadHtml($htmlContent)

# $title = [System.Web.HttpUtility]::HtmlDecode((Get-Title -htmlNode $htmlDocument.DocumentNode))
$content = Get-Article-Content -htmlNode $htmlDocument.DocumentNode -MIN_P_TEXT_LENGTH $MIN_P_TEXT_LENGTH -MIN_HEADING_TEXT_LENGTH $MIN_HEADING_TEXT_LENGTH

# Write-Host "HERE IS YOUR TITLE:"
# Write-Host ($title -join "`r`n`n")

# Write-Host "`r`n"

Write-Host "HERE IS YOUR CONTENT:"
Write-Host ($content -join "`r`n`n")