# Function to find ImageMagick installation
function Find-ImageMagick {
    # First check specific paths
    $possiblePaths = @(
        "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe",
        "C:\Program Files\ImageMagick-7.1.0-Q16-HDRI\magick.exe",
        "C:\Program Files\ImageMagick-7.0.11-Q16-HDRI\magick.exe",
        "C:\Program Files (x86)\ImageMagick-7.1.1-Q16-HDRI\magick.exe",
        "C:\Program Files (x86)\ImageMagick-7.1.0-Q16-HDRI\magick.exe",
        "C:\Program Files (x86)\ImageMagick-7.0.11-Q16-HDRI\magick.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    # If not found in specific paths, try to find any version in standard locations
    $programFiles = @(
        "C:\Program Files\ImageMagick-*\magick.exe",
        "C:\Program Files (x86)\ImageMagick-*\magick.exe"
    )

    foreach ($pattern in $programFiles) {
        $found = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    # As last resort, check if it's in the PATH
    try {
        $magickInPath = Get-Command "magick" -ErrorAction SilentlyContinue
        if ($magickInPath) {
            return $magickInPath.Source
        }
    }
    catch {
        # Command not found in path
    }
    
    return $null
}

# Find ImageMagick
$magickPath = Find-ImageMagick
if (-not $magickPath) {
    Write-Host "ImageMagick not found. Please install it from https://imagemagick.org/script/download.php"
    Write-Host "Common installation paths checked:"
    Write-Host "- C:\Program Files\ImageMagick-*"
    Write-Host "- C:\Program Files (x86)\ImageMagick-*"
    Write-Host "- System PATH"
    exit 1
}

Write-Host "Found ImageMagick at: $magickPath"

# Create output directories
$outputDirs = @(
    "windows\runner\Resources\",
    "android\app\src\main\res\mipmap-xxxhdpi\",
    "android\app\src\main\res\mipmap-xxhdpi\",
    "android\app\src\main\res\mipmap-xhdpi\",
    "android\app\src\main\res\mipmap-hdpi\",
    "android\app\src\main\res\mipmap-mdpi\",
    "ios\Runner\Assets.xcassets\AppIcon.appiconset\"
)

$totalDirs = $outputDirs.Count
$currentDir = 0

foreach ($dir in $outputDirs) {
    $currentDir++
    Write-Host "[$currentDir/$totalDirs] Checking directory: $dir"
    if (-not (Test-Path $dir)) {
        Write-Host "  Creating directory: $dir" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            Write-Host "  Directory created successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "  Error creating directory $dir : $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "  Directory already exists" -ForegroundColor Green
    }
}

# Check if logo exists
$logoPath = "assets\images\CloudToLocalLLM_logo.jpg"
if (-not (Test-Path $logoPath)) {
    Write-Host "Logo not found at: $logoPath" -ForegroundColor Red
    Write-Host "Please ensure the logo file exists at the specified path" -ForegroundColor Yellow
    exit 1
}

Write-Host "Generating icons from: $logoPath" -ForegroundColor Cyan

# Function to generate icon with error handling
function New-Icon {
    param (
        [string]$inputPath,
        [string]$outputPath,
        [string]$size
    )
    
    try {
        Write-Host "  Generating $size icon: $outputPath"
        & $magickPath convert $inputPath -resize $size $outputPath
        if ($LASTEXITCODE -ne 0) {
            throw "ImageMagick returned error code: $LASTEXITCODE"
        }
        Write-Host "  Success" -ForegroundColor Green
    }
    catch {
        Write-Host "  Error generating $size icon: $_" -ForegroundColor Red
        exit 1
    }
}

# Generate icons with progress tracking
$iconSets = @(
    @{ Name = "Windows"; Icons = @(
        @{ Path = "windows\runner\Resources\app_icon_256.png"; Size = "256x256" },
        @{ Path = "windows\runner\Resources\app_icon_64.png"; Size = "64x64" },
        @{ Path = "windows\runner\Resources\app_icon_32.png"; Size = "32x32" },
        @{ Path = "windows\runner\Resources\app_icon_16.png"; Size = "16x16" }
    )},
    @{ Name = "Android"; Icons = @(
        @{ Path = "android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"; Size = "192x192" },
        @{ Path = "android\app\src\main\res\mipmap-xxhdpi\ic_launcher.png"; Size = "144x144" },
        @{ Path = "android\app\src\main\res\mipmap-xhdpi\ic_launcher.png"; Size = "96x96" },
        @{ Path = "android\app\src\main\res\mipmap-hdpi\ic_launcher.png"; Size = "72x72" },
        @{ Path = "android\app\src\main\res\mipmap-mdpi\ic_launcher.png"; Size = "48x48" }
    )},
    @{ Name = "iOS"; Icons = @(
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-1024x1024@1x.png"; Size = "1024x1024" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@3x.png"; Size = "180x180" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@2x.png"; Size = "120x120" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-87x87@1x.png"; Size = "87x87" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@2x.png"; Size = "80x80" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-60x60@1x.png"; Size = "60x60" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@2x.png"; Size = "58x58" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-40x40@1x.png"; Size = "40x40" },
        @{ Path = "ios\Runner\Assets.xcassets\AppIcon.appiconset\Icon-App-29x29@1x.png"; Size = "29x29" }
    )}
)

$totalSets = $iconSets.Count
$currentSet = 0

foreach ($set in $iconSets) {
    $currentSet++
    $totalIcons = $set.Icons.Count
    $currentIcon = 0
    
    Write-Host ""
    Write-Host "[$currentSet/$totalSets] Generating $($set.Name) icons..." -ForegroundColor Cyan
    
    foreach ($icon in $set.Icons) {
        $currentIcon++
        Write-Host "  [$currentIcon/$totalIcons] Processing $($icon.Size) icon"
        New-Icon $logoPath $icon.Path $icon.Size
    }
    
    Write-Host "$($set.Name) icons generated successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host "All icons generated successfully!" -ForegroundColor Green 