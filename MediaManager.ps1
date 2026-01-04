# ============================================
#  MEDIA MANAGER - HIGH SUCCESS SUITE (V8.4)
# ============================================

$TMDB_Token = "".Trim()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ "Authorization" = "Bearer $TMDB_Token"; "accept" = "application/json" }

# --- HELPER: Improved Match Logic ---
function Test-IsCorrectGuess {
    param([string]$UserGuess, [string]$ActualTitle)
    if ([string]::IsNullOrWhiteSpace($UserGuess)) { return $false }
    
    # Remove all punctuation and normalize spaces
    $cleanGuess = ($UserGuess -replace '[^a-zA-Z0-9\s]', '').ToLower().Trim()
    $cleanActual = ($ActualTitle -replace '[^a-zA-Z0-9\s]', '').ToLower().Trim()
    
    # Check 1: Exact match after cleaning
    if ($cleanGuess -eq $cleanActual) { return $true }
    
    # Check 2: Handle titles with colons (e.g. "Bambi: The Reckoning") 
    # If guess matches the part before or after a colon
    if ($ActualTitle -match ":") {
        foreach ($part in ($ActualTitle -split ":")) {
            $cleanPart = ($part -replace '[^a-zA-Z0-9\s]', '').ToLower().Trim()
            if ($cleanGuess -eq $cleanPart -and $cleanGuess.Length -gt 3) { return $true }
        }
    }
    
    return $false
}

# --- HELPER: Detects Quality/Audio/Source/Edition Tags ---
function Get-MediaTags {
    param([string]$OriginalName)
    $pattern = "(?i)\b(2160p|1080p|720p|480p|4k|8k|hdr|dv|dolby|vision|atmos|dts-?hd|dts:?x|dts|truehd|aac|ac3|eac3|flac|remux|web-?dl|webrip|bluray|blu-?ray|dvdrip|h\.?26[45]|hevc|x26[45]|10bit|extended|director'?s\s?cut|unrated|theatrical|criterion|imax|open\s?matte)\b"
    $matches = [Regex]::Matches($OriginalName, $pattern)
    if ($matches.Count -gt 0) {
        $tags = ($matches | ForEach-Object { $_.Value }) -join ' '
        return " [$tags]" 
    }
    return ""
}

# --- MOVIE PROCESSING FUNCTIONS (1-4) ---
function Invoke-MovieSearch {
    param([string]$Title, [Nullable[int]]$Year)
    $encodedTitle = [uri]::EscapeDataString($Title)
    $yParam = if ($Year) { "&year=$Year" } else { "" }
    $url = "https://api.themoviedb.org/3/search/movie?query=$encodedTitle$yParam&include_adult=false&language=en-US&page=1"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
        if ($resp.results.Count -gt 0) { return $resp.results[0] }
    } catch { return $null }
    return $null
}

function Invoke-SeriesSearch {
    param([string]$Title, [Nullable[int]]$Year)
    $encodedTitle = [uri]::EscapeDataString($Title)
    $yParam = if ($Year) { "&first_air_date_year=$Year" } else { "" }
    $url = "https://api.themoviedb.org/3/search/tv?query=$encodedTitle$yParam&include_adult=false&language=en-US&page=1"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -ErrorAction Stop
        if ($resp.results.Count -gt 0) { return $resp.results[0] }
    } catch { return $null }
    return $null
}

function Process-Movie {
    param($Item, $ForceRename, $AllowLooseFiles)
    if ($Item.Name -eq "MediaManager.ps1" -or $Item.Extension -eq ".ps1") { return }
    $targetFolder = $Item
    if (-not $Item.PSIsContainer) {
        if ($AllowLooseFiles) {
            Write-Host "`n[FILE] Organizing: $($Item.Name)" -ForegroundColor Cyan
            $targetFolder = New-Item -Path $Item.DirectoryName -Name $Item.BaseName.Trim() -ItemType Directory -Force
            Move-Item -LiteralPath $Item.FullName -Destination $targetFolder.FullName -Force -ErrorAction SilentlyContinue
        } else { return }
    }
    if ($targetFolder.Name -match '^\({3}.*\){3}$') { return }
    Write-Host "`nProcessing Movie: $($targetFolder.Name)" -ForegroundColor Cyan
    $yrMatch = if ($targetFolder.Name -match '(?<!\d)(19|20)\d{2}(?!\d)') { [int]$Matches[0] } else { $null }
    $clean = if ($yrMatch) { ($targetFolder.Name -split "$yrMatch")[0] } else { $targetFolder.Name }
    $clean = ($clean -replace '[\{\(\[].*?[\}\)\]]', '' -replace '[\._\(\)\[\]\{\}]', ' ').Trim(" -_")
    $selected = Invoke-MovieSearch -Title $clean -Year $yrMatch
    if ($selected) {
        $ext = try { Invoke-RestMethod -Uri "https://api.themoviedb.org/3/movie/$($selected.id)/external_ids" -Method Get -Headers $headers } catch { $null }
        $xml = "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><movie><title>$($selected.title -replace '&', '&amp;')</title><uniqueid type='tmdb' default='true'>$($selected.id)</uniqueid><uniqueid type='imdb'>$($ext.imdb_id)</uniqueid></movie>"
        $xml | Set-Content -LiteralPath (Join-Path $targetFolder.FullName "tmdb_link.nfo") -Encoding utf8
        Write-Host "   [SUCCESS] NFO Created." -ForegroundColor Green
        if ($ForceRename) {
            $yr = if($selected.release_date){$selected.release_date.Substring(0,4)}else{""}
            $tags = Get-MediaTags -OriginalName $targetFolder.Name
            $newName = ($selected.title -replace '[:\/\*\?"<>\|]', '-') + " ($yr)$tags"
            if ($targetFolder.Name -ne $newName) { 
                Rename-Item -LiteralPath $targetFolder.FullName -NewName $newName -ErrorAction SilentlyContinue 
                Write-Host "   [RENAMED] -> $newName" -ForegroundColor Green
            }
        }
    }
}

function Process-Series {
    param($Folder, $ForceRename)
    if ($Folder.Name -match '^\({3}.*\){3}$') { return }
    Write-Host "`nProcessing Series: $($Folder.Name)" -ForegroundColor Cyan
    $yrMatch = if ($Folder.Name -match '(?<!\d)(19|20)\d{2}(?!\d)') { [int]$Matches[0] } else { $null }
    $clean = if ($yrMatch) { ($Folder.Name -split "$yrMatch")[0] } else { $Folder.Name }
    $clean = ($clean -replace '[\{\(\[].*?[\}\)\]]', '' -replace '[\._\(\)\[\]\{\}]', ' ').Trim(" -_")
    $selected = Invoke-SeriesSearch -Title $clean -Year $yrMatch
    if ($selected) {
        $ext = try { Invoke-RestMethod -Uri "https://api.themoviedb.org/3/tv/$($selected.id)/external_ids" -Method Get -Headers $headers } catch { $null }
        $yr = if($selected.first_air_date){$selected.first_air_date.Substring(0,4)}else{""}
        $xml = "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><tvshow><title>$($selected.name -replace '&', '&amp;')</title><uniqueid type='tmdb' default='true'>$($selected.id)</uniqueid><uniqueid type='imdb'>$($ext.imdb_id)</uniqueid><uniqueid type='tvdb'>$($ext.tvdb_id)</uniqueid></tvshow>"
        $xml | Set-Content -LiteralPath (Join-Path $Folder.FullName "tmdb_link.nfo") -Encoding utf8
        Write-Host "   [SUCCESS] NFO Created." -ForegroundColor Green
        if ($ForceRename) {
            $idStr = if ($ext.tvdb_id) { " {tvdb-$($ext.tvdb_id)}" } else { " {tmdb-$($selected.id)}" }
            if ($ext.imdb_id) { $idStr += " {imdb-$($ext.imdb_id)}" }
            $newName = ($selected.name -replace '[:\/\*\?"<>\|]', '-') + " ($yr)$idStr"
            if ($Folder.Name -ne $newName) { 
                Rename-Item -LiteralPath $Folder.FullName -NewName $newName -ErrorAction SilentlyContinue 
                Write-Host "   [RENAMED] -> $newName" -ForegroundColor Green
            }
        }
    }
}

# --- GAME MODES (6-8) ---
function Start-DisneyGame {
    Write-Host "`n--- DISNEY MOVIE GUESSING GAME ---" -ForegroundColor Magenta
    $page = Get-Random -Minimum 1 -Maximum 10
    $url = "https://api.themoviedb.org/3/discover/movie?with_companies=2&language=en-US&page=$page"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $target = $resp.results | Where-Object { $_.overview -ne "" } | Get-Random
        Write-Host "`nHINT (Release Year): $($target.release_date.Substring(0,4))" -ForegroundColor Yellow
        Write-Host "PLOT: $($target.overview)" -ForegroundColor Gray
        $guess = Read-Host "`nGuess the Disney Movie Title"
        if (Test-IsCorrectGuess -UserGuess $guess -ActualTitle $target.title) {
            Write-Host "CORRECT! It was $($target.title)." -ForegroundColor Green
        } else { Write-Host "Incorrect. It was: $($target.title)" -ForegroundColor Red }
    } catch { Write-Host "Error connecting to Game Server." -ForegroundColor Red }
}

function Start-SuperheroGame {
    Write-Host "`n--- SUPERHERO GUESSING GAME ---" -ForegroundColor Cyan
    $page = Get-Random -Minimum 1 -Maximum 10
    # Keywords: Superhero (9715), Marvel (180547), DC (207268)
    $url = "https://api.themoviedb.org/3/discover/movie?with_keywords=9715|180547|207268&language=en-US&page=$page"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $target = $resp.results | Where-Object { $_.overview -ne "" } | Get-Random
        Write-Host "`nHINT ($($target.release_date.Substring(0,4))):" -ForegroundColor Yellow
        Write-Host "PLOT: $($target.overview)" -ForegroundColor Gray
        $guess = Read-Host "`nGuess the Superhero Movie"
        if (Test-IsCorrectGuess -UserGuess $guess -ActualTitle $target.title) {
            Write-Host "AVENGERS LEVEL INTELLECT! Correct: $($target.title)." -ForegroundColor Green
        } else { Write-Host "Incorrect. It was: $($target.title)" -ForegroundColor Red }
    } catch { Write-Host "Error connecting to Game Server." -ForegroundColor Red }
}

function Start-HorrorGame {
    Write-Host "`n--- GUESS THE HORROR MOVIE ---" -ForegroundColor Red
    $page = Get-Random -Minimum 1 -Maximum 20
    # Genre: Horror (27)
    $url = "https://api.themoviedb.org/3/discover/movie?with_genres=27&include_adult=true&language=en-US&page=$page"
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $target = $resp.results | Where-Object { $_.overview -ne "" } | Get-Random
        Write-Host "`nHINT (Release Year): $($target.release_date.Substring(0,4))" -ForegroundColor Yellow
        Write-Host "PLOT: $($target.overview)" -ForegroundColor Gray
        $guess = Read-Host "`nWhat horror movie is this?"
        if (Test-IsCorrectGuess -UserGuess $guess -ActualTitle $target.title) {
            Write-Host "CORRECT! You survived. It was $($target.title)." -ForegroundColor Green
        } else { Write-Host "You died! It was: $($target.title)" -ForegroundColor Red }
    } catch { Write-Host "Error connecting to Game Server." -ForegroundColor Red }
}

# --- MAIN MENU ---
while ($true) {
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "      MEDIA MANAGER - FULL SUITE (V8.4)" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "1) Loose Movie Files -> Folders + Clean + Tags + NFO"
    Write-Host "2) Series Rename + XML NFO (Appends IDs)"
    Write-Host "3) Movie XML NFO ONLY"
    Write-Host "4) Series XML NFO ONLY"
    Write-Host "5) Update/Clear API Token"
    Write-Host "6) Play 'Guess the Disney Movie'"
    Write-Host "7) Play 'Guess the Superhero Movie'"
    Write-Host "8) Play 'Guess the Horror Movie'"
    Write-Host "Q) Exit"
    Write-Host "------------------------------------------------"
    $opt = Read-Host "Choice"
    if ($opt -eq 'q') { break }
    
    if ($opt -eq '5') { 
        $inputToken = (Read-Host "Enter new Token (or type 'clear')").Trim()
        $TMDB_Token = if ($inputToken -eq "clear") { "" } else { $inputToken }
        $headers["Authorization"] = "Bearer $TMDB_Token"
        $scriptPath = $MyInvocation.MyCommand.Path
        if (Test-Path $scriptPath) {
            (Get-Content $scriptPath) -replace '^\$TMDB_Token = ".*"', "`$TMDB_Token = `"$TMDB_Token`"" | Set-Content $scriptPath -Encoding UTF8
            Write-Host "   [SAVED] Token updated in file." -ForegroundColor Green
        }
        continue 
    }
    
    if ($opt -eq '6') { Start-DisneyGame; continue }
    if ($opt -eq '7') { Start-SuperheroGame; continue }
    if ($opt -eq '8') { Start-HorrorGame; continue }
    
    $items = Get-ChildItem | Where-Object { $_.Name -notmatch '^\(\(.*\)\)$' -and $_.Extension -ne ".ps1" }
    foreach ($i in $items) {
        switch ($opt) {
            "1" { Process-Movie -Item $i -ForceRename $true -AllowLooseFiles $true }
            "2" { if($i.PSIsContainer){ Process-Series -Folder $i -ForceRename $true } }
            "3" { if($i.PSIsContainer){ Process-Movie -Item $i -ForceRename $false -AllowLooseFiles $false } }
            "4" { if($i.PSIsContainer){ Process-Series -Folder $i -ForceRename $false } }
        }
    }
    Read-Host "`nTask Complete. Press Enter."
}
