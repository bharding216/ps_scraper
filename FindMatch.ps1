# To run the script, enter the following command in the terminal:
# .\FindMatch.ps1

# Add HtmlAgilityPack.dll to the PowerShell session
Add-Type -Path 'C:\Users\brand\HtmlAgilityPack.1.11.57\lib\netstandard2.0\HtmlAgilityPack.dll'

function SearchHtmlFiles {
    param (
        [string]$directory,
        [string[]]$keywords
    )

    # Check if the directory exists
    if (-not (Test-Path $directory -PathType Container)) {
        Write-Host "Directory not found: $directory"
        return
    }

    # Get all HTML files in the specified directory
    $htmlFiles = Get-ChildItem -Path $directory -Filter *.html

    # Initialize an empty list to store files containing keywords
    $matchingFiles = @()

    # Loop through each HTML file
    foreach ($htmlFile in $htmlFiles) {
        # Load HTML content using HTML Agility Pack
        $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument
        $htmlDocument.Load($htmlFile.FullName)

        # Check if any keyword is found in the HTML content
        $containsKeyword = $keywords | ForEach-Object {
            $htmlDocument.DocumentNode.InnerText -match $_
        }

        # If at least one keyword is found, add the file to the list
        if ($containsKeyword) {
            $matchingFiles += $htmlFile.FullName
        }
    }

    # Return the list of matching HTML files
    return $matchingFiles
}

# Prompt the user for the directory and keywords
$directory = Read-Host "Enter the directory path containing HTML files"
$keywords = Read-Host "Enter keywords (comma-separated) for search" -Split ','

# Invoke the function and get the list of matching files
$matchingHtmlFiles = SearchHtmlFiles -directory $directory -keywords $keywords

# Display the matching HTML files
if ($matchingHtmlFiles.Count -gt 0) {
    Write-Host "Matching HTML files:"
    $matchingHtmlFiles | ForEach-Object { Write-Host $_ }
} else {
    Write-Host "No matching HTML files found."
}