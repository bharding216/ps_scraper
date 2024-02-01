# To run the script, enter the following command in the terminal:
# .\FetchPage.ps1

function Save-Page {
    param (
        [string]$url,
        [string]$fileStoragePath
    )

    # Check if the directory exists; if not, create it
    $directory = Split-Path $fileStoragePath
    if (-not (Test-Path -Path $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force
    }

    Invoke-WebRequest -Uri $url -Method Get -Headers @{ 'Accept' = 'text/html' } -OutFile $fileStoragePath
}

function Fetch-Page {
    param (
        [string]$url
    )

    $filename = "${url}"
    $extension = ".html"

    # Replace characters that are not suitable for a file path
    $filename = $filename -replace '[\\/:*?"<>|]', '_'

    # Check if the filename already ends with .html
    if (-not $filename.EndsWith($extension)) {
        $filename += $extension
    }

    ########################################
    # Change this to the actual path to be used for file storage
    $fileStoragePath = "C:\Users\brand\Documents\$filename"
    ########################################

    Save-Page -url $url -fileStoragePath $fileStoragePath
}

$jsonContent = Get-Content -Path "./articles.json" | ConvertFrom-Json
$articleUrls = $jsonContent.articleUrls

# Infinite loop to continuously fetch pages
while ($true) {
    foreach ($url in $articleUrls) {
        Write-Output "Beginning crawl process for $url..."
        Fetch-Page -url $url
        Write-Output "Completed process for $url!"
    }

    # Add a delay to control the frequency of execution
    Start-Sleep -Seconds 10  # 300 seconds = 5 minutes

    Write-Output "I'm done sleeping. Let's fetch the pages again!"
}