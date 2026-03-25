# Flutter SDK Installation Script
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.41.5-stable.zip"
$installPath = "C:\src"
$zipPath = "$installPath\flutter.zip"

if (!(Test-Path $installPath)) {
    Write-Host "Creating directory $installPath..."
    New-Item -ItemType Directory -Path $installPath -Force
}

Write-Host "Downloading Flutter SDK (approx 1GB). This may take a while..."
Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath

Write-Host "Extracting Flutter SDK to $installPath..."
# Use tar for extraction as it's built-in on modern Windows
tar -xf $zipPath -C $installPath

Write-Host "Cleaning up zip file..."
Remove-Item $zipPath

Write-Host "Updating User PATH..."
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$flutterBin = "$installPath\flutter\bin"
if ($currentPath -notlike "*$flutterBin*") {
    $newPath = "$currentPath;$flutterBin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Flutter bin added to PATH. Please RESTART your terminal/VS Code for changes to take effect."
} else {
    Write-Host "Flutter bin is already in PATH."
}

Write-Host "Done! Running initial flutter doctor..."
# Try to run from the absolute path immediately
& "$flutterBin\flutter.bat" doctor
