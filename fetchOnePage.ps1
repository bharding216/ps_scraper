Import-Module Selenium

$url = "https://www.bbc.com/worklife/article/20240311-evs-lost-their-luxury-status-symbol-reputation"

$delaySeconds = 5

$driverPath = "C:\Users\brand\Downloads\chromedriver-win32\chromedriver-win32"

try {
    # Create a new Chrome WebDriver
    $driver = New-Object OpenQA.Selenium.Chrome.ChromeDriver($driverPath)

    $driver.Navigate().GoToUrl($url)

    Start-Sleep -Seconds $delaySeconds

    $htmlContent = $driver.PageSource

    $htmlContent | Out-File -FilePath "C:\Users\brand\Projects\IBTS\scraper\ps_scraper\html_test_5_selenium.html" -Force

    Write-Host "HTML Content:"
    Write-Host $htmlContent
} catch {
    # Handle any exceptions
    Write-Host "Error: $_"
}
finally {
    # Close the WebDriver if it was successfully created
    if ($null -ne $driver) {
        $driver.Quit()
    }
}