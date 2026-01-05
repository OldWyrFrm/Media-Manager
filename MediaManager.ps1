<#
    .SYNOPSIS
    Media Manager V9.0.0 - Comprehensive movie and TV show organization script with advanced TMDB integration

    .DESCRIPTION
    A sophisticated PowerShell script for organizing and managing media files using The Movie Database (TMDB) API.
    
    KEY FEATURES:
    • Smart file renaming with dual delimiter support (Media_Title-ReleaseYear-Resolution-AudioCodec)
    • Comprehensive NFO generation with cast, crew, and metadata
    • Bulk processing capabilities for entire collections
    • Smart change detection - only shows actual changes needed
    • Trailing media tag removal for cleaner movie title matching
    • Secure TMDB token storage using Windows DPAPI encryption
    • Customizable naming schemes and folder organization
    • Interactive entertainment features (movie guessing games)
    
    DUAL DELIMITER SYSTEM:
    The script supports an advanced dual delimiter naming system:
    - First delimiter (e.g., _): Used for spaces within movie titles
    - Second delimiter (e.g., -): Used to separate metadata components
    Example: "Home Alone (1990) 720p aac.mkv" → "Home_Alone-1990-720p-aac.mkv"
    
    SMART PROCESSING:
    • Automatically detects and removes trailing media tags from titles
    • Extracts year, language, and quality information from filenames
    • Compares existing vs proposed changes to avoid unnecessary operations
    • Handles both individual file processing and bulk collection management
    
    .PARAMETER None
    This script is menu-driven and does not accept command-line parameters.
    All configuration is handled through the interactive menu system.
    
    .EXAMPLE
    .\MediaManager.ps1
    
    Launches the interactive menu system for media file management.
    
    .INPUTS
    • Media files (MKV, MP4, AVI, MOV, WMV, FLV, WEBM)
    • TMDB API Read Access Token
    • User selections through interactive menus
    
    .OUTPUTS
    • Renamed media files and folders
    • NFO metadata files with comprehensive movie information
    • MediaManagerConfig.json configuration file
    • Console progress and status updates
    
    .NOTES
    Author: slyfox250-code
    Contributor: OldWyrFrm
    Version: 9.0.0
    PowerShell: 5.1+ Required
    
    Dependencies:
    - TMDB API Read Access Token (free registration at https://www.themoviedb.org/settings/api)
    - PowerShell 5.1 or later
    - Internet connection for TMDB API access
    - Windows Forms for file/folder dialogs
    - Windows DPAPI for secure token storage
    
    Security Features:
    - TMDB tokens encrypted using Windows DPAPI (user-specific)
    - Input validation and sanitization
    - Path validation to prevent directory traversal
    - Error handling with graceful failure recovery
    
    Configuration:
    The script creates and maintains a MediaManagerConfig.json file containing:
    - Encrypted TMDB API token
    - Default movie and TV show folders
    - Customizable naming schemes for files and folders
    - Backward compatibility with legacy configuration formats
    
    .LINK
    https://www.themoviedb.org/settings/api - TMDB API Registration
    
    .LINK
    https://www.themoviedb.org/documentation/api - TMDB API Documentation

#>

#region Configuration Management Functions
# ============================================================================
# These functions handle the creation, reading, and updating of the
# MediaManagerConfig.json configuration file that stores user preferences
# and settings including encrypted TMDB tokens and naming schemes.
# ============================================================================

function Initialize-Config {
    <#
    .SYNOPSIS
    Initializes the MediaManagerConfig.json configuration file with default settings.
    
    .DESCRIPTION
    Creates a new configuration file in the same directory as the script if one doesn't exist.
    The configuration file stores user preferences including TMDB tokens, default folders,
    and naming schemes for both movies and TV shows.
    
    .PARAMETER ScriptPath
    The full path to the MediaManager.ps1 script file, used to determine the config location.
    
    .OUTPUTS
    Returns the full path to the configuration file.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)][string]$ScriptPath
    )

    # Construct the config file path in the same directory as the script
    $configPath = Join-Path (Split-Path $ScriptPath -Parent) "MediaManagerConfig.json"
    
    # Only create the config file if it doesn't already exist
    if (-not (Test-Path $configPath)) {
        Write-Host "Creating MediaManagerConfig.json..." -ForegroundColor Yellow

        # Define default configuration with Media_Title naming scheme
        # This provides a sensible starting point for new users
        $defaultConfig = @{
            TMDBToken = $null                               # Encrypted TMDB API token (set via menu option 2)
            MovieFolder = $null                            # Default movie directory (set via menu option 3)
            ShowFolder = $null                             # Default TV show directory (set via menu option 4)
            MovieFileFormat = "Media_Title-ReleaseYear"     # File naming scheme for movies
            ShowFileFormat = "Media_Title-ReleaseYear"      # File naming scheme for TV shows
            MovieFolderFormat = "Media_Title-ReleaseYear"   # Folder naming scheme for movies
            ShowFolderFormat = "Media_Title-ReleaseYear"    # Folder naming scheme for TV shows
        }

        # Write the default configuration to disk as JSON with UTF-8 encoding
        $defaultConfig | ConvertTo-Json -Depth 2 | Set-Content -Path $configPath -Encoding UTF8

        Write-Host "Config file created at: $configPath" -ForegroundColor Green
    }

    # Return the config file path for use by other functions
    return $configPath
}

function Get-Config {
    <#
    .SYNOPSIS
    Reads and validates the MediaManagerConfig.json configuration file.
    
    .DESCRIPTION
    Loads the configuration file and ensures backward compatibility by adding
    missing properties and migrating legacy configuration keys to the current format.
    Automatically updates the config file if changes are made.
    
    .PARAMETER ConfigPath
    The full path to the MediaManagerConfig.json file.
    
    .OUTPUTS
    Returns a PSCustomObject containing the configuration settings.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)][string]$ConfigPath
    )

    try {
        # Read and parse the JSON configuration file
        $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
        
        # Add missing properties for backward compatibility with older config versions
        # These properties were added in later versions and may not exist in legacy configs
        if (-not $config.PSObject.Properties.Name -contains "MovieFileFormat") {
            $config | Add-Member -MemberType NoteProperty -Name "MovieFileFormat" -Value "Title_ReleaseYear"
        }
        if (-not $config.PSObject.Properties.Name -contains "ShowFileFormat") {
            $config | Add-Member -MemberType NoteProperty -Name "ShowFileFormat" -Value "Title_ReleaseYear"
        }
        if (-not $config.PSObject.Properties.Name -contains "MovieFolderFormat") {
            $config | Add-Member -MemberType NoteProperty -Name "MovieFolderFormat" -Value "Title_ReleaseYear"
        }
        if (-not $config.PSObject.Properties.Name -contains "ShowFolderFormat") {
            $config | Add-Member -MemberType NoteProperty -Name "ShowFolderFormat" -Value "Title_ReleaseYear"
        }
        
        # Migrate legacy naming scheme keys to new format keys
        # This ensures compatibility with configurations from earlier versions
        if ($config.PSObject.Properties.Name -contains "MovieNamingScheme" -and -not $config.PSObject.Properties.Name -contains "MovieFileFormat") {
            $config | Add-Member -MemberType NoteProperty -Name "MovieFileFormat" -Value $config.MovieNamingScheme
        }
        if ($config.PSObject.Properties.Name -contains "ShowNamingScheme" -and -not $config.PSObject.Properties.Name -contains "ShowFileFormat") {
            $config | Add-Member -MemberType NoteProperty -Name "ShowFileFormat" -Value $config.ShowNamingScheme
        }
        
        # Save the updated configuration back to file if any migrations occurred
        # This ensures the config file stays current with the latest format
        $config | ConvertTo-Json -Depth 2 | Set-Content -Path $ConfigPath -Encoding UTF8
        
        return $config
    } catch {
        # If there's any error reading the config file, return safe defaults
        Write-Host "Error reading config file. Using defaults." -ForegroundColor Red
        return [pscustomobject]@{
            TMDBToken = $null
            MovieFolder = $null
            ShowFolder = $null
            MovieFileFormat = "Title_ReleaseYear"
            ShowFileFormat = "Title_ReleaseYear"
            MovieFolderFormat = "Title_ReleaseYear"
            ShowFolderFormat = "Title_ReleaseYear"
        }
    }
}

function Set-ConfigValue {
    <#
    .SYNOPSIS
    Updates a specific configuration value in the MediaManagerConfig.json file.
    
    .DESCRIPTION
    Safely updates a configuration setting by first loading the current config,
    modifying the specified key-value pair, and saving the updated configuration.
    Handles both new properties and existing property updates.
    
    .PARAMETER ConfigPath
    The full path to the MediaManagerConfig.json file.
    
    .PARAMETER Key
    The configuration property name to update (e.g., "TMDBToken", "MovieFolder").
    
    .PARAMETER Value
    The new value to assign to the specified configuration key.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)][string]$ConfigPath,
        [parameter(Mandatory=$true)][string]$Key,
        [parameter(Mandatory=$true)][string]$Value
    )

    try {
        # Load the current configuration using our Get-Config function
        $config = Get-Config -ConfigPath $ConfigPath
        
        # Check if the property already exists in the configuration
        if (-not $config.PSObject.Properties.Name -contains $Key) {
            # Add new property if it doesn't exist
            $config | Add-Member -MemberType NoteProperty -Name $Key -Value $Value
        } else {
            # Update existing property by removing and re-adding with new value
            # This approach ensures proper type handling and avoids reference issues
            $config.PSObject.Properties.Remove($Key)
            $config | Add-Member -MemberType NoteProperty -Name $Key -Value $Value
        }
        
        # Save the updated configuration back to the JSON file
        $config | ConvertTo-Json -Depth 2 | Set-Content -Path $ConfigPath -Encoding UTF8
        Write-Host "Configuration updated: $Key" -ForegroundColor Green
    } catch {
        # Log any errors that occur during the update process
        Write-Host "Error updating config file: $_" -ForegroundColor Red
    }
}

function Get-TMDBToken {
    <#
    .SYNOPSIS
    Retrieves and decrypts the TMDB API token from the configuration.
    
    .DESCRIPTION
    Safely retrieves the encrypted TMDB API token from the configuration and
    decrypts it using Windows DPAPI. The token is stored encrypted for security
    and can only be decrypted by the same user account that encrypted it.
    
    .PARAMETER Config
    The configuration object containing the encrypted TMDB token.
    
    .OUTPUTS
    Returns a SecureString containing the decrypted TMDB token, or $null if not configured.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]$Config
    )

    # Check if a TMDB token has been configured
    if ($Config.TMDBToken) {
        try {
            # Decrypt the token using Windows DPAPI (Data Protection API)
            # This ensures the token can only be decrypted by the same user who encrypted it
            $secureToken = ConvertTo-SecureString $Config.TMDBToken
            return $secureToken
        } catch {
            # If decryption fails, the token may be corrupted or from a different user
            Write-Host "Error decrypting TMDB token." -ForegroundColor Red
            return $null
        }
    }
    else {
        # No token has been configured yet - user needs to set it via menu option 2
        Write-Host "TMDBToken not set in configuration." -ForegroundColor Yellow
        return $null
    }
}

#endregion

#region User Interface Helper Functions
# ============================================================================
# These functions provide Windows Forms-based dialogs for user interaction
# including folder selection, file selection, and GUI-based input.
# ============================================================================

function Show-FolderBrowser {
    <#
    .SYNOPSIS
    Displays a Windows Forms folder browser dialog for directory selection.
    
    .DESCRIPTION
    Creates and displays a folder browser dialog that allows users to select
    a directory. This is used for setting movie and TV show folders in the configuration.
    
    .PARAMETER Description
    The description text shown at the top of the folder browser dialog.
    
    .OUTPUTS
    Returns the selected folder path as a string, or $null if cancelled.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$false)][string]$Description = "Select a folder"
    )

    # Load Windows Forms for GUI dialog support
    Add-Type -AssemblyName System.Windows.Forms
    
    # Create and configure the folder browser dialog
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = $Description
    $folderDialog.ShowNewFolderButton = $true  # Allow users to create new folders
    
    # Display the dialog and return the selected path if OK was clicked
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderDialog.SelectedPath
    }

    # Return null if user cancelled the dialog
    return $null
}

function Format-NamingScheme {
    <#
    .SYNOPSIS
    Ensures naming schemes include the Media_Title prefix for consistency.
    
    .DESCRIPTION
    Analyzes user-provided naming schemes and automatically prepends "Media_Title"
    if not already present. This ensures all schemes follow the dual delimiter
    format for consistent file organization.
    
    .PARAMETER Scheme
    The naming scheme to format (e.g., "ReleaseYear-Resolution").
    
    .OUTPUTS
    Returns the formatted naming scheme with Media_Title prefix if needed.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)][string]$Scheme
    )
    
    # Split the scheme by valid delimiters to analyze its components
    $parts = $Scheme -split '[-_\.]'
    
    # Check if "Media" is already present in the scheme
    if ($parts -notcontains 'Media') {
        # Auto-detect the delimiter being used in the existing scheme
        # Priority: underscore, hyphen, period (most to least common)
        $delimiter = if ($Scheme -match '_') { '_' } elseif ($Scheme -match '-') { '-' } else { '.' }
        
        # Prepend Media_Title using the detected delimiter for consistency
        return "Media_Title$delimiter$Scheme"
    }
    
    # Return the original scheme if it already contains Media
    return $Scheme
}

function Show-FileDialog {
    <#
    .SYNOPSIS
    Displays a Windows Forms file selection dialog for media file selection.
    
    .DESCRIPTION
    Creates and displays a file selection dialog with filters for common media
    file types. Used for selecting individual media files for processing.
    
    .PARAMETER Title
    The title text displayed in the file dialog window.
    
    .PARAMETER Filter
    The file filter string defining which file types are shown.
    
    .OUTPUTS
    Returns the selected file path as a string, or $null if cancelled.
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$false)][string]$Title = "Select a media file",
        [parameter(Mandatory=$false)][string]$Filter = "Media Files (*.mkv;*.mp4;*.avi;*.mov;*.wmv;*.flv;*.webm)|*.mkv;*.mp4;*.avi;*.mov;*.wmv;*.flv;*.webm|All Files (*.*)|*.*"
    )

    # Load Windows Forms for GUI dialog support
    Add-Type -AssemblyName System.Windows.Forms
    
    # Create and configure the file selection dialog
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = $Title
    $fileDialog.Filter = $Filter  # Filter for common video file extensions
    $fileDialog.RestoreDirectory = $true  # Remember the last used directory
    
    # Display the dialog and return the selected file path if OK was clicked
    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileDialog.FileName
    }

    # Return null if user cancelled the dialog
    return $null
}

#endregion

#region Media Information Processing Functions
# ============================================================================
# These functions handle the extraction, cleaning, and processing of media
# information from filenames and folders, including tag removal and
# metadata detection for improved TMDB matching.
# ============================================================================

function Remove-TrailingMediaTags {
    <#
    .SYNOPSIS
    Removes trailing media quality tags from movie titles for cleaner TMDB matching.
    
    .DESCRIPTION
    Analyzes movie titles and removes trailing media tags like resolution (720p),
    audio codecs (aac, dts), and other technical specifications that can interfere
    with TMDB database lookups. Only removes tags from the end of titles to
    preserve intentional naming.
    
    .PARAMETER Title
    The movie title string to clean of trailing media tags.
    
    .OUTPUTS
    Returns the cleaned title string with trailing media tags removed.
    
    .EXAMPLE
    Remove-TrailingMediaTags "Home Alone 720p aac"
    Returns: "Home Alone"
    
    .EXAMPLE
    Remove-TrailingMediaTags "The Matrix 1999 1080p DTS BluRay"
    Returns: "The Matrix 1999"
    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory=$true)][string]$Title
    )
    
    # Define comprehensive regex pattern for media tags
    # This pattern matches common resolution, audio, video, and source tags
    $tagPattern = "(2160p|1440p|1080p|720p|540p|480p|360p|4k|8k|uhd|fhd|hd|hdr10\+?|hdr|dv|dolby|vision|atmos|dts-hd|dtshd|dts-x|dtsx|dts|truehd|ddp|dd\+|lpcm|aac|ac3|eac3|flac|opus|5\.1|7\.1|remux|web-dl|webdl|webrip|bluray|blu-ray|bdrip|dvdrip|hdtv|pdtv|h\.?26[45]|hevc|av1|vp9|xvid|x26[45]|10bit|extended|directors\.cut|director\.cut|unrated|theatrical|criterion|imax|open\.matte|remaster|remastered|special\.edition|final\.cut|proper|repack)"
    
    # Start with trimmed title and split into words for analysis
    $cleanTitle = $Title.Trim()
    $words = $cleanTitle -split '\s+'
    
    # Work backwards from the end to find the last non-tag word
    # This preserves movie titles that may contain year numbers or other data
    $lastValidIndex = $words.Length - 1
    for ($i = $words.Length - 1; $i -ge 0; $i--) {
        # Check if current word matches any media tag pattern
        if ($words[$i] -match "(?i)^$tagPattern$") {
            $lastValidIndex = $i - 1  # Mark previous word as last valid
        } else {
            break  # Stop at first non-tag word from the end
        }
    }
    
    # Reconstruct the title using only the valid (non-tag) words
    if ($lastValidIndex -ge 0) {
        return ($words[0..$lastValidIndex] -join ' ').Trim()
    } else {
        # Edge case: if all words are tags, return the original title
        # This prevents returning an empty string
        return $Title.Trim()
    }
}

function Extract-MovieInfo {
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)][string]$FilePath
    )

    $file = Get-Item -Path $FilePath
    $fileName = $file.BaseName
    $folderName = $file.Directory.Name
    
    # Initialize result object
    $result = [PSCustomObject]@{
        Title = $null
        Year = $null
        Language = $null
        Tags = $null
        OriginalExtension = $file.Extension
    }
    
    # Get media tags
    $result.Tags = Get-MediaTags -File $fileName
    
    # Try to extract year from filename first, then folder
    $yearPattern = '(?<!\d)(19|20)\d{2}(?!\d)'
    $yearMatch = if ($fileName -match $yearPattern) { [int]$Matches[0] } 
                elseif ($folderName -match $yearPattern) { [int]$Matches[0] } 
                else { $null }
    $result.Year = $yearMatch
    
    # Try to extract language (look for common language codes)
    $langPattern = '\b(EN|FR|DE|ES|IT|RU|JA|KO|ZH|PT|NL|PL|SV|NO|DA|FI|TR|AR|HE|HI|TH|VI|CS|HU|RO|BG|HR|SK|SL|ET|LV|LT|MT|EL|CY|GA|EU|CA|GL|SQ|MK|SR|BS|ME|AL|IS|FO)\b'
    $langMatch = if ($fileName -match $langPattern) { $Matches[0] } else { $null }
    $result.Language = $langMatch
    
    # Extract title - try filename first, then folder
    $titleFromFile = $fileName
    $titleFromFolder = $folderName
    
    # Clean filename to extract title
    if ($yearMatch) {
        $titleFromFile = ($titleFromFile -split "$yearMatch")[0]
    }
    $titleFromFile = $titleFromFile -replace '[\{\(\[].*?[\}\)\]]', '' -replace '[\._\-\(\)\[\]\{\}]', ' '
    $titleFromFile = ($titleFromFile -replace '\b(EN|FR|DE|ES|IT|RU|JA|KO|ZH|PT|NL|PL|SV|NO|DA|FI|TR|AR|HE|HI|TH|VI|CS|HU|RO|BG|HR|SK|SL|ET|LV|LT|MT|EL|CY|GA|EU|CA|GL|SQ|MK|SR|BS|ME|AL|IS|FO)\b', '').Trim()
    
    # Remove trailing media tags from title
    $titleFromFile = Remove-TrailingMediaTags -Title $titleFromFile
    
    # Clean folder name to extract title  
    if ($yearMatch) {
        $titleFromFolder = ($titleFromFolder -split "$yearMatch")[0]
    }
    $titleFromFolder = $titleFromFolder -replace '[\{\(\[].*?[\}\)\]]', '' -replace '[\._\-\(\)\[\]\{\}]', ' '
    $titleFromFolder = ($titleFromFolder -replace '\b(EN|FR|DE|ES|IT|RU|JA|KO|ZH|PT|NL|PL|SV|NO|DA|FI|TR|AR|HE|HI|TH|VI|CS|HU|RO|BG|HR|SK|SL|ET|LV|LT|MT|EL|CY|GA|EU|CA|GL|SQ|MK|SR|BS|ME|AL|IS|FO)\b', '').Trim()
    
    # Remove trailing media tags from folder-based title too
    $titleFromFolder = Remove-TrailingMediaTags -Title $titleFromFolder
    
    # Choose the better title (prefer longer, more descriptive one)
    $result.Title = if ($titleFromFile.Length -gt $titleFromFolder.Length -and $titleFromFile.Length -gt 3) {
        $titleFromFile.Trim(" -_")
    } elseif ($titleFromFolder.Length -gt 3) {
        $titleFromFolder.Trim(" -_")
    } else {
        # Fallback to filename if both are too short
        $titleFromFile.Trim(" -_")
    }
    
    # Ensure we have at least something for title
    if ([string]::IsNullOrWhiteSpace($result.Title)) {
        $result.Title = $file.BaseName -replace '[\._\-\(\)\[\]\{\}]', ' '
    }
    
    return $result
}

#endregion

#region Filename and Folder Management Functions
# ============================================================================
# These functions handle the construction of new filenames and folder names
# based on user-defined naming schemes, supporting both legacy Title formats
# and advanced Media_Title dual delimiter formats.
# ============================================================================

function Build-NewFileName {
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)]$MovieData,
        [parameter(Mandatory=$true)]$Tags,
        [parameter(Mandatory=$true)][string]$FileFormat,
        [parameter(Mandatory=$true)][string]$Extension
    )
    
    $parts = $FileFormat -split '[-_\.]'
    
    # Detect if using Media_Title format
    $hasMediaTitle = $FileFormat -match 'Media[_\-\.]Title'
    
    if ($hasMediaTitle) {
        # Extract delimiters: first for title spaces, second for parts
        $mediaMatch = [regex]::Match($FileFormat, 'Media([_\-\.])Title')
        $titleDelimiter = $mediaMatch.Groups[1].Value
        
        # Get main delimiter by removing the Media_Title part and checking remaining pattern
        $remainingFormat = $FileFormat -replace 'Media[_\-\.]Title', 'Title'
        $mainDelimiter = if ($remainingFormat -match '_') { '_' } elseif ($remainingFormat -match '-') { '-' } else { '.' }
        
        # Split and process parts
        $parts = $remainingFormat -split '[-_\.]'
        $newNameParts = @()
        
        foreach ($part in $parts) {
            switch ($part) {
                'Title' { 
                    $cleanTitle = $MovieData.title -replace '[:\/\*\?"<>\|]', $titleDelimiter -replace '\s+', $titleDelimiter
                    # Clean up consecutive delimiters
                    $escapedDelimiter = [regex]::Escape($titleDelimiter)
                    $cleanTitle = $cleanTitle -replace "$escapedDelimiter{2,}", $titleDelimiter
                    $newNameParts += $cleanTitle
                }
                'ReleaseYear' { 
                    if ($MovieData.release_date) {
                        $newNameParts += $MovieData.release_date.Substring(0,4)
                    }
                }
                'Resolution' { if ($Tags.Resolution) { $newNameParts += $Tags.Resolution } }
                'Technology' { if ($Tags.Technology) { $newNameParts += $Tags.Technology } }
                'AudioCodec' { if ($Tags.AudioCodec) { $newNameParts += $Tags.AudioCodec } }
                'VideoCodec' { if ($Tags.VideoCodec) { $newNameParts += $Tags.VideoCodec } }
                'Source' { if ($Tags.Source) { $newNameParts += $Tags.Source } }
                'ReleaseType' { if ($Tags.ReleaseType) { $newNameParts += $Tags.ReleaseType } }
            }
        }
        
        return ($newNameParts -join $mainDelimiter) + $Extension
    }
    else {
        # Original logic for Title-based formats
        $delimiter = if ($FileFormat -match '_') { '_' } elseif ($FileFormat -match '-') { '-' } else { '.' }
        
        $newNameParts = @()
        
        foreach ($part in $parts) {
            switch ($part) {
                'Title' { 
                    $cleanTitle = $MovieData.title -replace '[:\/\*\?"<>\|]', '-' -replace '\s+', $delimiter
                    $newNameParts += $cleanTitle
                }
                'ReleaseYear' { 
                    if ($MovieData.release_date) {
                        $newNameParts += $MovieData.release_date.Substring(0,4)
                    }
                }
                'Resolution' { if ($Tags.Resolution) { $newNameParts += $Tags.Resolution } }
                'Technology' { if ($Tags.Technology) { $newNameParts += $Tags.Technology } }
                'AudioCodec' { if ($Tags.AudioCodec) { $newNameParts += $Tags.AudioCodec } }
                'VideoCodec' { if ($Tags.VideoCodec) { $newNameParts += $Tags.VideoCodec } }
                'Source' { if ($Tags.Source) { $newNameParts += $Tags.Source } }
                'ReleaseType' { if ($Tags.ReleaseType) { $newNameParts += $Tags.ReleaseType } }
            }
        }
        
        return ($newNameParts -join $delimiter) + $Extension
    }
}

function Process-SingleMovie {
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)][string]$FilePath,
        [parameter(Mandatory=$true)]$Config,
        [parameter(Mandatory=$false)][switch]$RenameOnly,
        [parameter(Mandatory=$false)][switch]$NFOOnly,
        [parameter(Mandatory=$false)][switch]$Both
    )

    Write-Host "`nProcessing: $FilePath" -ForegroundColor Cyan
    
    # Extract movie info from file
    $movieInfo = Extract-MovieInfo -FilePath $FilePath
    Write-Host "Detected Title: $($movieInfo.Title)" -ForegroundColor Yellow
    if ($movieInfo.Year) { Write-Host "Detected Year: $($movieInfo.Year)" -ForegroundColor Yellow }
    if ($movieInfo.Language) { Write-Host "Detected Language: $($movieInfo.Language)" -ForegroundColor Yellow }
    
    # Search for movie
    $searchParams = @{ Title = $movieInfo.Title }
    if ($movieInfo.Year) { $searchParams.Year = $movieInfo.Year }
    if ($movieInfo.Language) { $searchParams.Language = $movieInfo.Language }
    
    $movieData = Invoke-MovieSearch @searchParams
    
    if (-not $movieData) {
        Write-Host "Movie not found in TMDB database." -ForegroundColor Red
        return
    }
    
    Write-Host "Found: $($movieData.title) ($($movieData.release_date.Substring(0,4)))" -ForegroundColor Green
    
    $file = Get-Item -Path $FilePath
    $currentFolder = $file.Directory
    
    if ($RenameOnly -or $Both) {
        # Generate new filename
        $newFileName = Build-NewFileName -MovieData $movieData -Tags $movieInfo.Tags -FileFormat $Config.MovieFileFormat -Extension $movieInfo.OriginalExtension
        
        # Generate new folder name using folder format
        $hasMediaTitle = $Config.MovieFolderFormat -match 'Media[_\-\.]Title'
        
        if ($hasMediaTitle) {
            # Extract delimiters: first for title spaces, second for parts
            $mediaMatch = [regex]::Match($Config.MovieFolderFormat, 'Media([_\-\.])Title')
            $titleDelimiter = $mediaMatch.Groups[1].Value
            
            # Get main delimiter by removing the Media_Title part and checking remaining pattern
            $remainingFormat = $Config.MovieFolderFormat -replace 'Media[_\-\.]Title', 'Title'
            $folderDelimiter = if ($remainingFormat -match '_') { '_' } elseif ($remainingFormat -match '-') { '-' } else { '.' }
            
            $folderParts = $remainingFormat -split '[-_\.]'
            $newFolderParts = @()
            foreach ($part in $folderParts) {
                switch ($part) {
                    'Title' { 
                        $cleanTitle = $movieData.title -replace '[:\/\*\?"<>\|]', $titleDelimiter -replace '\s+', $titleDelimiter
                        # Clean up consecutive delimiters
                        $escapedDelimiter = [regex]::Escape($titleDelimiter)
                        $cleanTitle = $cleanTitle -replace "$escapedDelimiter{2,}", $titleDelimiter
                        $newFolderParts += $cleanTitle
                    }
                    'ReleaseYear' { 
                        if ($movieData.release_date) {
                            $newFolderParts += $movieData.release_date.Substring(0,4)
                        }
                    }
                }
            }
            $newFolderName = $newFolderParts -join $folderDelimiter
        }
        else {
            # Original logic for Title-based folder formats
            $folderParts = $Config.MovieFolderFormat -split '[-_\.]'
            $folderDelimiter = if ($Config.MovieFolderFormat -match '_') { '_' } elseif ($Config.MovieFolderFormat -match '-') { '-' } else { '.' }
            
            $newFolderParts = @()
            foreach ($part in $folderParts) {
                switch ($part) {
                    'Title' { 
                        $cleanTitle = $movieData.title -replace '[:\/\*\?"<>\|]', '-' -replace '\s+', $folderDelimiter
                        $newFolderParts += $cleanTitle
                    }
                    'ReleaseYear' { 
                        if ($movieData.release_date) {
                            $newFolderParts += $movieData.release_date.Substring(0,4)
                        }
                    }
                }
            }
            $newFolderName = $newFolderParts -join $folderDelimiter
        }
        
        # Compare current vs proposed to determine what actually needs changing
        $fileNeedsRename = $file.Name -ne $newFileName
        $folderNeedsRename = $currentFolder.Name -ne $newFolderName
        $hasChangesToShow = $fileNeedsRename -or $folderNeedsRename
        
        # Check NFO status for display purposes
        $nfoPath = Join-Path $file.Directory.FullName "movie.nfo"
        $nfoExists = Test-Path $nfoPath
        $nfoNeedsUpdate = $false
        
        if ($NFOOnly -or $Both) {
            if ($nfoExists) {
                # Compare existing NFO content with what would be generated
                try {
                    $existingNfoContent = Get-Content -Path $nfoPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    
                    # Get detailed movie data for comparison
                    $searchParams = @{ 
                        Title = $movieInfo.Title
                        DetailedInfo = $true
                    }
                    if ($movieInfo.Year) { $searchParams.Year = $movieInfo.Year }
                    $validLanguageCodes = @("AR", "BG", "BN", "CA", "CH", "CN", "CS", "CY", "DA", "DE", "EL", "EN", "EO", "ES", "ET", "EU", "FA", "FI", "FR", "GA", "GL", "HE", "HI", "HU", "ID", "IT", "JA", "KA", "KK", "KO", "LT", "LV", "MS", "NB", "NL", "NO", "PL", "PT", "RO", "RU", "SK", "SL", "SQ", "SR", "SV", "TH", "TR", "UK", "VI", "ZH")
                    if ($movieInfo.Language -and $movieInfo.Language -in $validLanguageCodes) { 
                        $searchParams.Language = $movieInfo.Language 
                    }
                    
                    $detailedMovieData = Invoke-MovieSearch @searchParams
                    if ($detailedMovieData) {
                        # Generate the proposed NFO content (same as what would be created)
                        $proposedXml = "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>`n<movie>`n"
                        $proposedXml += "  <title>$($detailedMovieData.title -replace '&', '&amp;')</title>`n"
                        $proposedXml += "  <uniqueid type='tmdb' default='true'>$($detailedMovieData.id)</uniqueid>`n"
                        
                        if ($detailedMovieData.external_ids -and $detailedMovieData.external_ids.imdb_id) {
                            $proposedXml += "  <uniqueid type='imdb'>$($detailedMovieData.external_ids.imdb_id)</uniqueid>`n"
                        }
                        if ($detailedMovieData.overview) {
                            $proposedXml += "  <plot>$($detailedMovieData.overview -replace '&', '&amp;')</plot>`n"
                        }
                        if ($detailedMovieData.release_date) {
                            $proposedXml += "  <year>$($detailedMovieData.release_date.Substring(0,4))</year>`n"
                            $proposedXml += "  <premiered>$($detailedMovieData.release_date)</premiered>`n"
                        }
                        if ($detailedMovieData.runtime) {
                            $proposedXml += "  <runtime>$($detailedMovieData.runtime)</runtime>`n"
                        }
                        if ($detailedMovieData.genres) {
                            foreach ($genre in $detailedMovieData.genres) {
                                $proposedXml += "  <genre>$($genre.name)</genre>`n"
                            }
                        }
                        if ($detailedMovieData.production_companies) {
                            foreach ($studio in $detailedMovieData.production_companies) {
                                $proposedXml += "  <studio>$($studio.name -replace '&', '&amp;')</studio>`n"
                            }
                        }
                        if ($detailedMovieData.vote_average) {
                            $proposedXml += "  <rating>$($detailedMovieData.vote_average)</rating>`n"
                        }
                        if ($detailedMovieData.tagline) {
                            $proposedXml += "  <tagline>$($detailedMovieData.tagline -replace '&', '&amp;')</tagline>`n"
                        }
                        
                        if ($detailedMovieData.credits -and $detailedMovieData.credits.cast) {
                            foreach ($actor in ($detailedMovieData.credits.cast | Select-Object -First 10)) {
                                $proposedXml += "  <actor>`n"
                                $proposedXml += "    <name>$($actor.name -replace '&', '&amp;')</name>`n"
                                $proposedXml += "    <role>$($actor.character -replace '&', '&amp;')</role>`n"
                                if ($actor.profile_path) {
                                    $proposedXml += "    <thumb>https://image.tmdb.org/t/p/original$($actor.profile_path)</thumb>`n"
                                }
                                $proposedXml += "  </actor>`n"
                            }
                        }
                        
                        if ($detailedMovieData.credits -and $detailedMovieData.credits.crew) {
                            $directors = $detailedMovieData.credits.crew | Where-Object { $_.job -eq "Director" }
                            foreach ($director in $directors) {
                                $proposedXml += "  <director>$($director.name -replace '&', '&amp;')</director>`n"
                            }
                            
                            $writers = $detailedMovieData.credits.crew | Where-Object { $_.job -in @("Writer", "Screenplay", "Story") }
                            foreach ($writer in $writers) {
                                $proposedXml += "  <credits>$($writer.name -replace '&', '&amp;')</credits>`n"
                            }
                        }
                        
                        $proposedXml += "</movie>"
                        
                        # Compare the full content
                        $nfoNeedsUpdate = $existingNfoContent.Trim() -ne $proposedXml.Trim()
                    } else {
                        $nfoNeedsUpdate = $true
                    }
                } catch {
                    $nfoNeedsUpdate = $true
                }
            } else {
                $nfoNeedsUpdate = $true
            }
        }
        
        # Only show proposed changes if there are actual changes to make
        if ($hasChangesToShow) {
            Write-Host "`nProposed Changes:" -ForegroundColor Yellow
            if ($fileNeedsRename) {
                Write-Host "  New filename: $newFileName" -ForegroundColor Cyan
                Write-Host "  Current file: $($file.Name)" -ForegroundColor Gray
            }
            if ($folderNeedsRename) {
                Write-Host "  New folder: $newFolderName" -ForegroundColor Cyan
                Write-Host "  Current folder: $($currentFolder.Name)" -ForegroundColor Gray
            }
        } elseif ($RenameOnly) {
            Write-Host "`nNo file or folder changes needed." -ForegroundColor Green
            return
        }
        
        # Show NFO status
        if ($NFOOnly -or $Both) {
            if (-not $nfoExists) {
                Write-Host "`nNFO file will be created." -ForegroundColor Yellow
            } elseif ($nfoNeedsUpdate) {
                Write-Host "`nNFO file will be updated." -ForegroundColor Yellow
            } else {
                # NFO is up to date, check if there are any other changes
                if (-not $hasChangesToShow) {
                    Write-Host "Proposed Changes: None" -ForegroundColor Green
                    return  # Nothing to do
                }
            }
        }
        
        # Only ask for confirmation if there are actual changes to make
        if ($hasChangesToShow) {
            do {
                $confirmation = Read-Host "`nDo you want to proceed with these changes? (Y/N)"
                $confirmation = $confirmation.ToUpper()
                if ($confirmation -eq "Y" -or $confirmation -eq "YES") {
                    $proceedWithRename = $true
                    break
                } elseif ($confirmation -eq "N" -or $confirmation -eq "NO") {
                    $proceedWithRename = $false
                    Write-Host "Rename operation cancelled by user." -ForegroundColor Yellow
                    break
                } else {
                    Write-Host "Please enter Y (Yes) or N (No)." -ForegroundColor Red
                }
            } while ($true)
        } else {
            $proceedWithRename = $false  # No rename needed
        }
        
        if ($proceedWithRename -and $hasChangesToShow) {
            # Step 1: Determine target paths
            $targetFolder = $null
            $finalFolderPath = $null
            
            if ($currentFolder.Name -eq "Movie" -or $currentFolder.Name -eq "Movies") {
                # Create new folder case - we're moving from a generic Movie/Movies folder
                $finalFolderPath = Join-Path $currentFolder.FullName $newFolderName
                $targetFolder = New-Item -Path $finalFolderPath -ItemType Directory -Force -ErrorAction SilentlyContinue
                Write-Host "Created new folder: $($targetFolder.FullName)" -ForegroundColor Green
                
                # Move and rename file to new folder
                $newFilePath = Join-Path $finalFolderPath $newFileName
                try {
                    if ($fileNeedsRename -or $folderNeedsRename) {
                        Move-Item -LiteralPath $file.FullName -Destination $newFilePath -Force -ErrorAction Stop
                        Write-Host "Moved file to: $newFileName" -ForegroundColor Green
                        # Update file reference to new location
                        $file = Get-Item -LiteralPath $newFilePath -ErrorAction Stop
                    }
                } catch {
                    Write-Host "Error moving file: $_" -ForegroundColor Red
                    Write-Host "Will use original file location" -ForegroundColor Yellow
                }
            } else {
                # Rename existing folder case - we need to rename the current folder
                $finalFolderPath = Join-Path $currentFolder.Parent.FullName $newFolderName
                
                # Step 2a: Rename file first (within same folder)
                $newFilePath = Join-Path $currentFolder.FullName $newFileName
                try {
                    if ($fileNeedsRename) {
                        Move-Item -LiteralPath $file.FullName -Destination $newFilePath -Force -ErrorAction Stop
                        Write-Host "Renamed file to: $newFileName" -ForegroundColor Green
                        # Update file reference to new location
                        $file = Get-Item -LiteralPath $newFilePath -ErrorAction Stop
                    }
                } catch {
                    Write-Host "Error renaming file: $_" -ForegroundColor Red
                    Write-Host "Will use original file location" -ForegroundColor Yellow
                }
                
                # Step 2b: Rename folder (after file is renamed)
                if ($folderNeedsRename) {
                    try {
                        Rename-Item -LiteralPath $currentFolder.FullName -NewName $newFolderName -ErrorAction Stop
                        Write-Host "Renamed folder to: $newFolderName" -ForegroundColor Green
                        # Update file reference to new folder path
                        $file = Get-Item -LiteralPath (Join-Path $finalFolderPath $newFileName) -ErrorAction SilentlyContinue
                        if (-not $file) {
                            $file = Get-Item -LiteralPath $newFilePath -ErrorAction SilentlyContinue
                        }
                    } catch {
                        Write-Host "Error renaming folder: $_" -ForegroundColor Red
                    }
                }
            }
        } else {
            # If user declined rename in a "Both" operation, skip NFO generation too
            if ($Both -and $hasChangesToShow) {
                Write-Host "All operations cancelled by user." -ForegroundColor Yellow
                return
            }
        }
    }
    
    if (($NFOOnly -or $Both) -and $nfoNeedsUpdate) {
        # Generate NFO with enhanced data if available
        $searchParams = @{ 
            Title = $movieInfo.Title
            DetailedInfo = $true
        }
        if ($movieInfo.Year) { $searchParams.Year = $movieInfo.Year }
        
        # Only add Language if it's a valid code
        $validLanguageCodes = @("AR", "BG", "BN", "CA", "CH", "CN", "CS", "CY", "DA", "DE", "EL", "EN", "EO", "ES", "ET", "EU", "FA", "FI", "FR", "GA", "GL", "HE", "HI", "HU", "ID", "IT", "JA", "KA", "KK", "KO", "LT", "LV", "MS", "NB", "NL", "NO", "PL", "PT", "RO", "RU", "SK", "SL", "SQ", "SR", "SV", "TH", "TR", "UK", "VI", "ZH")
        if ($movieInfo.Language -and $movieInfo.Language -in $validLanguageCodes) { 
            $searchParams.Language = $movieInfo.Language 
        }
        
        $movieData = Invoke-MovieSearch @searchParams
        
        if (-not $movieData) {
            Write-Host "Movie not found in TMDB database for NFO generation." -ForegroundColor Red
            return
        }
        
        $headers = @{ "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR((Get-TMDBToken -Config $Config))))" }
        
        # Build comprehensive NFO XML
        $xml = "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>`n<movie>`n"
        $xml += "  <title>$($movieData.title -replace '&', '&amp;')</title>`n"
        $xml += "  <uniqueid type='tmdb' default='true'>$($movieData.id)</uniqueid>`n"
        
        # Add external IDs if available
        if ($movieData.external_ids) {
            if ($movieData.external_ids.imdb_id) {
                $xml += "  <uniqueid type='imdb'>$($movieData.external_ids.imdb_id)</uniqueid>`n"
            }
        }
        
        # Add enhanced metadata if available
        if ($movieData.overview) {
            $xml += "  <plot>$($movieData.overview -replace '&', '&amp;')</plot>`n"
        }
        if ($movieData.release_date) {
            $xml += "  <year>$($movieData.release_date.Substring(0,4))</year>`n"
            $xml += "  <premiered>$($movieData.release_date)</premiered>`n"
        }
        if ($movieData.runtime) {
            $xml += "  <runtime>$($movieData.runtime)</runtime>`n"
        }
        if ($movieData.genres) {
            foreach ($genre in $movieData.genres) {
                $xml += "  <genre>$($genre.name)</genre>`n"
            }
        }
        if ($movieData.production_companies) {
            foreach ($studio in $movieData.production_companies) {
                $xml += "  <studio>$($studio.name -replace '&', '&amp;')</studio>`n"
            }
        }
        if ($movieData.vote_average) {
            $xml += "  <rating>$($movieData.vote_average)</rating>`n"
        }
        if ($movieData.tagline) {
            $xml += "  <tagline>$($movieData.tagline -replace '&', '&amp;')</tagline>`n"
        }
        
        # Add cast information if available
        if ($movieData.credits -and $movieData.credits.cast) {
            foreach ($actor in ($movieData.credits.cast | Select-Object -First 10)) {
                $xml += "  <actor>`n"
                $xml += "    <name>$($actor.name -replace '&', '&amp;')</name>`n"
                $xml += "    <role>$($actor.character -replace '&', '&amp;')</role>`n"
                if ($actor.profile_path) {
                    $xml += "    <thumb>https://image.tmdb.org/t/p/original$($actor.profile_path)</thumb>`n"
                }
                $xml += "  </actor>`n"
            }
        }
        
        # Add crew information if available  
        if ($movieData.credits -and $movieData.credits.crew) {
            $directors = $movieData.credits.crew | Where-Object { $_.job -eq "Director" }
            foreach ($director in $directors) {
                $xml += "  <director>$($director.name -replace '&', '&amp;')</director>`n"
            }
            
            $writers = $movieData.credits.crew | Where-Object { $_.job -in @("Writer", "Screenplay", "Story") }
            foreach ($writer in $writers) {
                $xml += "  <credits>$($writer.name -replace '&', '&amp;')</credits>`n"
            }
        }
        
        $xml += "</movie>"
        
        $nfoPath = Join-Path $file.Directory.FullName "movie.nfo"
        $xml | Set-Content -Path $nfoPath -Encoding utf8
        Write-Host "Enhanced NFO created: $nfoPath" -ForegroundColor Green
    }
}

function Test-NamingScheme {
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)][string]$Scheme
    )
    
    # Valid options and delimiters
    $validOptions = @('Media', 'ReleaseYear', 'Resolution', 'Technology', 'AudioCodec', 'VideoCodec', 'Source', 'ReleaseType')
    $validDelimiters = @('-', '_', '.')
    
    # First, replace Media<delimiter>Title patterns with just Media for validation
    $schemeForValidation = $Scheme -replace 'Media[_\-\.]Title', 'Media'
    
    # Split by valid delimiters
    $parts = $schemeForValidation -split '[-_\.]'
    
    # Check if all parts are valid options
    foreach ($part in $parts) {
        if ($part -notin $validOptions) {
            return $false
        }
    }
    
    # Check if only valid delimiters are used in original scheme
    $delimiterPattern = "[^a-zA-Z" + ($validDelimiters -join '') + "]"
    if ($Scheme -match $delimiterPattern) {
        return $false
    }
    
    return $true
}

function Test-IsCorrectGuess {
    [cmdletbinding()]

    param(
        [parameter(Mandatory=$true)][string]$UserGuess,
        [parameter(Mandatory=$true)][string]$ActualTitle
    )
    
    if ([string]::IsNullOrWhiteSpace($UserGuess)) { return $false }
    
    # Remove all punctuation and normalize spaces
    $cleanGuess = ($UserGuess -replace '[^a-zA-Z0-9\s]', '').ToLower().Trim()
    $cleanActual = ($ActualTitle -replace '[^a-zA-Z0-9\s]', '').ToLower().Trim()
    
    # Check 1: Exact match after cleaning
    if ($cleanGuess -eq $cleanActual) {
        return $true
    }
    
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

function Get-MediaTags {
    param([string]$File)
    $pattern = "(?i)(2160p|1440p|1080p|720p|540p|480p|360p|4k|8k|uhd|fhd|hd|hdr10\+?|hdr|dv|dolby|vision|atmos|dts-hd|dtshd|dts-x|dtsx|dts|truehd|ddp|dd\+|lpcm|aac|ac3|eac3|flac|opus|5\.1|7\.1|remux|web-dl|webdl|webrip|bluray|blu-ray|bdrip|dvdrip|hdtv|pdtv|h\.?26[45]|hevc|av1|vp9|xvid|x26[45]|10bit|extended|directors\.cut|director\.cut|unrated|theatrical|criterion|imax|open\.matte|remaster|remastered|special\.edition|final\.cut|proper|repack)"
    $matches = [Regex]::Matches($File, $pattern)
    
    # Initialize arrays for each category
    $resolution = @()
    $technology = @()
    $audioCodec = @()
    $videoCodec = @()
    $source = @()
    $releaseType = @()
    
    foreach ($match in $matches) {
        $value = $match.Value.ToLower()
        switch -Regex ($value) {
            '^(2160p|1440p|1080p|720p|540p|480p|360p|4k|8k|uhd|fhd|hd)$' { 
                $resolution += $match.Value 
            }
            '^(hdr10\+?|hdr|dv|dolby|vision|10bit)$' { 
                $technology += $match.Value 
            }
            '^(atmos|dts-hd|dtshd|dts-x|dtsx|dts|truehd|ddp|dd\+|lpcm|aac|ac3|eac3|flac|opus|5\.1|7\.1)$' { 
                $audioCodec += $match.Value 
            }
            '^(h\.?26[45]|hevc|av1|vp9|xvid|x26[45])$' { 
                $videoCodec += $match.Value 
            }
            '^(remux|web-dl|webdl|webrip|bluray|blu-ray|bdrip|dvdrip|hdtv|pdtv)$' { 
                $source += $match.Value 
            }
            '^(extended|directors\.cut|director\.cut|unrated|theatrical|criterion|imax|open\.matte|remaster|remastered|special\.edition|final\.cut|proper|repack)$' { 
                $releaseType += $match.Value 
            }
        }
    }
    
    return [PSCustomObject]@{
        Resolution = ($resolution | Sort-Object -Unique) -join '_'
        Technology = ($technology | Sort-Object -Unique) -join '_'
        AudioCodec = ($audioCodec | Sort-Object -Unique) -join '_'
        VideoCodec = ($videoCodec | Sort-Object -Unique) -join '_'
        Source = ($source | Sort-Object -Unique) -join '_'
        ReleaseType = ($releaseType | Sort-Object -Unique) -join '_'
    }
}

function Invoke-MovieSearch {
    [cmdletbinding()]

    param(
        [Parameter(mandatory=$true)][string]$Title,
        [Parameter(mandatory=$false)][Nullable[int]]$Year,
        [Parameter(mandatory=$false)][switch]$DetailedInfo,
        [Parameter(mandatory=$false)]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $boundParameters)
            
            $languages = @{
                "AR" = "Arabic"
                "BG" = "Bulgarian" 
                "BN" = "Bengali"
                "CA" = "Catalan"
                "CH" = "Chinese"
                "CN" = "Mandarin Chinese"
                "CS" = "Czech"
                "CY" = "Welsh"
                "DA" = "Danish"
                "DE" = "German"
                "EL" = "Greek"
                "EN" = "English"
                "EO" = "Esperanto"
                "ES" = "Spanish"
                "ET" = "Estonian"
                "EU" = "Basque"
                "FA" = "Persian"
                "FI" = "Finnish"
                "FR" = "French"
                "GA" = "Irish"
                "GL" = "Galician"
                "HE" = "Hebrew"
                "HI" = "Hindi"
                "HU" = "Hungarian"
                "ID" = "Indonesian"
                "IT" = "Italian"
                "JA" = "Japanese"
                "KA" = "Georgian"
                "KK" = "Kazakh"
                "KO" = "Korean"
                "LT" = "Lithuanian"
                "LV" = "Latvian"
                "MS" = "Malay"
                "NB" = "Norwegian"
                "NL" = "Dutch"
                "NO" = "Norwegian"
                "PL" = "Polish"
                "PT" = "Portuguese"
                "RO" = "Romanian"
                "RU" = "Russian"
                "SK" = "Slovak"
                "SL" = "Slovenian"
                "SQ" = "Albanian"
                "SR" = "Serbian"
                "SV" = "Swedish"
                "TH" = "Thai"
                "TR" = "Turkish"
                "UK" = "Ukrainian"
                "VI" = "Vietnamese"
                "ZH" = "Chinese"
            }
            
            $completions = $languages.GetEnumerator() | Where-Object {
                $_.Key -like "*$wordToComplete*" -or $_.Value -like "*$wordToComplete*"
            } | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_.Key,
                    "$($_.Key) ($($_.Value))",
                    'ParameterValue',
                    "$($_.Key) ($($_.Value))"
                )
            }
            
            return $completions
        })]
        [ValidateScript({
            $validCodes = @("AR", "BG", "BN", "CA", "CH", "CN", "CS", "CY", "DA", "DE", "EL", "EN", "EO", "ES", "ET", "EU", "FA", "FI", "FR", "GA", "GL", "HE", "HI", "HU", "ID", "IT", "JA", "KA", "KK", "KO", "LT", "LV", "MS", "NB", "NL", "NO", "PL", "PT", "RO", "RU", "SK", "SL", "SQ", "SR", "SV", "TH", "TR", "UK", "VI", "ZH")
            if ($_ -in $validCodes) { return $true }
            throw "Invalid language code. Use tab completion to see available options."
        })]
        [string]$Language = "EN"
    )

    $encodedTitle = [uri]::EscapeDataString($Title)
    $yParam = if ($Year) { "&year=$Year" } else { "" }
    $langParam = "&language=" + $Language.ToLower() + "-" + $Language.ToUpper()
    $secureToken = Get-TMDBToken -Config $config
    $headers = @{ "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)))" }
    
    # Step 1: Search for the movie
    $searchUrl = "https://api.themoviedb.org/3/search/movie?query=$encodedTitle$yParam&include_adult=true$langParam&page=1"
    
    try {
        $searchResp = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers $headers -ErrorAction Stop
        
        if ($searchResp.results.Count -gt 0) {
            $movieResult = $searchResp.results[0]
            
            # Step 2: If detailed info requested, get full movie details
            if ($DetailedInfo) {
                $movieId = $movieResult.id
                # Append additional data: credits (cast/crew), keywords, videos, images, external_ids
                $detailUrl = "https://api.themoviedb.org/3/movie/$movieId$langParam&append_to_response=credits,keywords,videos,images,external_ids"
                
                try {
                    $detailedResp = Invoke-RestMethod -Uri $detailUrl -Method Get -Headers $headers -ErrorAction Stop
                    return $detailedResp
                } catch {
                    Write-Warning "Could not fetch detailed info, returning basic search result"
                    return $movieResult
                }
            } else {
                return $movieResult
            }
        }
    } catch {
        return $null
    }
}

function Start-DisneyGame {
    [cmdletbinding()]

    param()

    Write-Host "`n--- DISNEY MOVIE GUESSING GAME ---" -ForegroundColor Magenta
    $page = Get-Random -Minimum 1 -Maximum 10
    $url = "https://api.themoviedb.org/3/discover/movie?with_companies=2&language=en-US&page=$page"

    try {
        $secureToken = Get-TMDBToken -Config $config
        $headers = @{ "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)))" }
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $target = $resp.results | Where-Object { $_.overview -ne "" } | Get-Random
        Write-Host "`nHINT (Release Year): $($target.release_date.Substring(0,4))" -ForegroundColor Yellow
        Write-Host "PLOT: $($target.overview)" -ForegroundColor Gray
        $guess = Read-Host "`nGuess the Disney Movie Title"

        if (Test-IsCorrectGuess -UserGuess $guess -ActualTitle $target.title) {
            Write-Host "CORRECT! It was $($target.title)." -ForegroundColor Green
        } else {
            Write-Host "Incorrect. It was: $($target.title)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error connecting to Game Server." -ForegroundColor Red
    }
}

function Start-SuperheroGame {
    [cmdletbinding()]

    param()

    Write-Host "`n--- SUPERHERO GUESSING GAME ---" -ForegroundColor Cyan
    $page = Get-Random -Minimum 1 -Maximum 10
    # Keywords: Superhero (9715), Marvel (180547), DC (207268)
    $url = "https://api.themoviedb.org/3/discover/movie?with_keywords=9715|180547|207268&language=en-US&page=$page"
    
    try {
        $secureToken = Get-TMDBToken -Config $config
        $headers = @{ "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)))" }
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $target = $resp.results | Where-Object { $_.overview -ne "" } | Get-Random
        Write-Host "`nHINT ($($target.release_date.Substring(0,4))):" -ForegroundColor Yellow
        Write-Host "PLOT: $($target.overview)" -ForegroundColor Gray
        $guess = Read-Host "`nGuess the Superhero Movie"

        if (Test-IsCorrectGuess -UserGuess $guess -ActualTitle $target.title) {
            Write-Host "AVENGERS LEVEL INTELLECT! Correct: $($target.title)." -ForegroundColor Green
        } else {
            Write-Host "Incorrect. It was: $($target.title)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error connecting to Game Server." -ForegroundColor Red
    }
}

function Start-HorrorGame {
    [cmdletbinding()]

    param()

    Write-Host "`n--- GUESS THE HORROR MOVIE ---" -ForegroundColor Red
    $page = Get-Random -Minimum 1 -Maximum 20
    # Genre: Horror (27)
    $url = "https://api.themoviedb.org/3/discover/movie?with_genres=27&include_adult=true&language=en-US&page=$page"
    
    try {
        $secureToken = Get-TMDBToken -Config $config
        $headers = @{ "Authorization" = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)))" }
        $resp = Invoke-RestMethod -Uri $url -Method Get -Headers $headers
        $target = $resp.results | Where-Object { $_.overview -ne "" } | Get-Random
        Write-Host "`nHINT (Release Year): $($target.release_date.Substring(0,4))" -ForegroundColor Yellow
        Write-Host "PLOT: $($target.overview)" -ForegroundColor Gray
        $guess = Read-Host "`nWhat horror movie is this?"
        
        if (Test-IsCorrectGuess -UserGuess $guess -ActualTitle $target.title) {
            Write-Host "CORRECT! You survived. It was $($target.title)." -ForegroundColor Green
        } else {
            Write-Host "You died! It was: $($target.title)" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error connecting to Game Server." -ForegroundColor Red
    }
}

#endregion

# ============================================================================
# MAIN SCRIPT EXECUTION
# ============================================================================
# This section initializes the configuration, loads settings, and starts
# the interactive menu system for media file management.
# ============================================================================

# Initialize the configuration system
# This creates the MediaManagerConfig.json file if it doesn't exist
# and returns the path for use throughout the script
$configPath = Initialize-Config -ScriptPath $MyInvocation.MyCommand.Path
$config = Get-Config -ConfigPath $configPath

# Main menu loop - continues until user selects Exit (option 1)
do {
    # Small delay to ensure output buffer is properly flushed before clearing screen
    Start-Sleep -Milliseconds 100
    
    # Clear screen for clean menu display
    cls
    
    # Display main menu header with version information
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "      MEDIA MANAGER - FULL SUITE (V9.0.0)" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    
    # Display menu options with clear descriptions
    Write-Host "1)  Exit"                                    # Exit the application
    Write-Host "2)  Set TMDB API Token"                      # Configure TMDB API access
    Write-Host "3)  Set Movie Folder"                        # Set default movie directory
    Write-Host "4)  Set Show Folder"                         # Set default TV show directory
    Write-Host "5)  Set Movie File Format"                   # Configure movie naming scheme
    Write-Host "6)  Set Show File Format"                    # Configure TV show naming scheme
    Write-Host "7)  Update Single Movie"                     # Process individual movie files
    Write-Host "8)  Update All Movies"                       # Bulk process movie collection
    Write-Host "9)  Update Single Show (work in progress)"   # Individual TV show processing (coming soon)
    Write-Host "10) Update All Shows (work in progress)"     # Bulk TV show processing (coming soon)
    Write-Host "11) Play 'Guess the Disney Movie'"           # Disney movie guessing game
    Write-Host "12) Play 'Guess the Superhero Movie'"        # Superhero movie guessing game
    Write-Host "13) Play 'Guess the Horror Movie'"           # Horror movie guessing game
    Write-Host "------------------------------------------------"
    
    # Get user's menu choice
    $Choice = Read-Host -Prompt "Choice"

    # Process the user's menu selection
    switch ($Choice) {
        '1' {
            # Exit the application gracefully
            Write-Host "Exiting..." -ForegroundColor Yellow
            break
        }

        '2' {
            # Configure TMDB API token with secure input and encryption
            Write-Host "`nSetting TMDB API token..." -ForegroundColor Cyan
            Write-Host "Please enter your TMDB API token (input will be hidden):"
            $secureToken = Read-Host -AsSecureString
            
            # Validate that a token was actually entered
            if ($secureToken.Length -gt 0) {
                # Encrypt the token using Windows DPAPI for secure storage
                # This ensures only the current user can decrypt and use the token
                $encryptedToken = ConvertFrom-SecureString $secureToken
                Set-ConfigValue -ConfigPath $configPath -Key "TMDBToken" -Value $encryptedToken
                
                # Reload configuration to reflect the updated token
                $config = Get-Config -ConfigPath $configPath
                
                Write-Host "TMDB API token has been securely stored." -ForegroundColor Green
            } else {
                Write-Host "No token entered. Configuration unchanged." -ForegroundColor Yellow
            }
        }
    
        '3' {
            # Configure default movie folder using GUI folder browser
            Write-Host "`nSelecting movie folder..." -ForegroundColor Cyan
            $selectedFolder = Show-FolderBrowser -Description "Select the folder where your movies are stored"
            
            if ($selectedFolder) {
                # Save the selected folder to configuration
                Set-ConfigValue -ConfigPath $configPath -Key "MovieFolder" -Value $selectedFolder
                
                # Reload configuration to reflect the updated folder
                $config = Get-Config -ConfigPath $configPath
                
                Write-Host "Movie folder set to: $selectedFolder" -ForegroundColor Green
            } else {
                Write-Host "No folder selected. Configuration unchanged." -ForegroundColor Yellow
            }
        }

        '4' {
            Write-Host "`nSelecting show folder..." -ForegroundColor Cyan
            $selectedFolder = Show-FolderBrowser -Description "Select the folder where your TV shows are stored"
            
            if ($selectedFolder) {
                Set-ConfigValue -ConfigPath $configPath -Key "ShowFolder" -Value $selectedFolder
                
                # Reload config to get updated values
                $config = Get-Config -ConfigPath $configPath
                
                Write-Host "Show folder set to: $selectedFolder" -ForegroundColor Green
            } else {
                Write-Host "No folder selected. Configuration unchanged." -ForegroundColor Yellow
            }
        }

        '5' {
            Write-Host "`nMovie file naming scheme configuration" -ForegroundColor Cyan
            Write-Host "=========================================" -ForegroundColor Cyan
            Write-Host "Available options:"
            Write-Host "  - Media<delimiter>Title (use Media_Title, Media-Title, or Media.Title)"
            Write-Host "  - ReleaseYear"
            Write-Host "  - Resolution"
            Write-Host "  - Technology"
            Write-Host "  - AudioCodec"
            Write-Host "  - VideoCodec"
            Write-Host "  - Source"
            Write-Host "  - ReleaseType"
            Write-Host ""
            Write-Host "Valid delimiters: hyphen (-), underscore (_), period (.)"
            Write-Host "Examples:"
            Write-Host "  Media_Title-ReleaseYear-Resolution-AudioCodec (dual delimiters)"
            Write-Host "  Media.Title.ReleaseYear.Resolution.AudioCodec (single delimiter)"
            Write-Host ""
            Write-Host "Current file format: $($config.MovieFileFormat)"
            Write-Host "Current folder format: $($config.MovieFolderFormat)"
            
            do {
                $scheme = Read-Host "Enter new movie file naming scheme"
                if (Test-NamingScheme -Scheme $scheme) {
                    $formattedScheme = Format-NamingScheme -Scheme $scheme
                    
                    # Extract delimiter from file format to use for folder format
                    if ($formattedScheme -match 'Media[_\-\.]Title') {
                        # For Media_Title format, use same pattern for folder
                        $mediaMatch = [regex]::Match($formattedScheme, 'Media([_\-\.])Title')
                        $titleDelimiter = $mediaMatch.Groups[1].Value
                        $remainingFormat = $formattedScheme -replace 'Media[_\-\.]Title.*', ''
                        $mainDelimiter = if ($formattedScheme -match "Media[_\-\.]Title([_\-\.]).*") { $Matches[1] } else { $titleDelimiter }
                        $folderFormat = "Media" + $titleDelimiter + "Title" + $mainDelimiter + "ReleaseYear"
                    } else {
                        # Original Title format
                        $folderDelimiter = if ($formattedScheme -match '_') { '_' } elseif ($formattedScheme -match '-') { '-' } else { '.' }
                        $folderFormat = "Title" + $folderDelimiter + "ReleaseYear"
                    }
                    
                    Set-ConfigValue -ConfigPath $configPath -Key "MovieFileFormat" -Value $formattedScheme
                    Set-ConfigValue -ConfigPath $configPath -Key "MovieFolderFormat" -Value $folderFormat
                    
                    # Reload config to get updated values
                    $config = Get-Config -ConfigPath $configPath
                    
                    Write-Host "Movie file format updated to: $formattedScheme" -ForegroundColor Green
                    Write-Host "Movie folder format updated to: $folderFormat" -ForegroundColor Green
                    break
                } else {
                    Write-Host "Invalid scheme! Please use only valid options and delimiters." -ForegroundColor Red
                }
            } while ($true)
        }

        '6' {
            Write-Host "`nShow file naming scheme configuration" -ForegroundColor Cyan
            Write-Host "======================================" -ForegroundColor Cyan
            Write-Host "Available options:"
            Write-Host "  - Media<delimiter>Title (use Media_Title, Media-Title, or Media.Title)"
            Write-Host "  - ReleaseYear"
            Write-Host "  - Resolution"
            Write-Host "  - Technology"
            Write-Host "  - AudioCodec"
            Write-Host "  - VideoCodec"
            Write-Host "  - Source"
            Write-Host "  - ReleaseType"
            Write-Host ""
            Write-Host "Valid delimiters: hyphen (-), underscore (_), period (.)"
            Write-Host "Examples:"
            Write-Host "  Media_Title-ReleaseYear-Resolution-Source (dual delimiters)"
            Write-Host "  Media.Title.ReleaseYear.Resolution.Source (single delimiter)"
            Write-Host ""
            Write-Host "Current file format: $($config.ShowFileFormat)"
            Write-Host "Current folder format: $($config.ShowFolderFormat)"
            
            do {
                $scheme = Read-Host "Enter new show file naming scheme"
                if (Test-NamingScheme -Scheme $scheme) {
                    $formattedScheme = Format-NamingScheme -Scheme $scheme
                    
                    # Extract delimiter from file format to use for folder format
                    if ($formattedScheme -match 'Media[_\-\.]Title') {
                        # For Media_Title format, use same pattern for folder
                        $mediaMatch = [regex]::Match($formattedScheme, 'Media([_\-\.])Title')
                        $titleDelimiter = $mediaMatch.Groups[1].Value
                        $remainingFormat = $formattedScheme -replace 'Media[_\-\.]Title.*', ''
                        $mainDelimiter = if ($formattedScheme -match "Media[_\-\.]Title([_\-\.]).*") { $Matches[1] } else { $titleDelimiter }
                        $folderFormat = "Media" + $titleDelimiter + "Title" + $mainDelimiter + "ReleaseYear"
                    } else {
                        # Original Title format
                        $folderDelimiter = if ($formattedScheme -match '_') { '_' } elseif ($formattedScheme -match '-') { '-' } else { '.' }
                        $folderFormat = "Title" + $folderDelimiter + "ReleaseYear"
                    }
                    
                    Set-ConfigValue -ConfigPath $configPath -Key "ShowFileFormat" -Value $formattedScheme
                    Set-ConfigValue -ConfigPath $configPath -Key "ShowFolderFormat" -Value $folderFormat
                    
                    # Reload config to get updated values
                    $config = Get-Config -ConfigPath $configPath
                    
                    Write-Host "Show file format updated to: $formattedScheme" -ForegroundColor Green
                    Write-Host "Show folder format updated to: $folderFormat" -ForegroundColor Green
                    break
                } else {
                    Write-Host "Invalid scheme! Please use only valid options and delimiters." -ForegroundColor Red
                }
            } while ($true)
        }

        '7' {
            do {
                cls
                Write-Host "`n================================================" -ForegroundColor Magenta
                Write-Host "         UPDATE SINGLE MOVIE MENU" -ForegroundColor Magenta
                Write-Host "================================================" -ForegroundColor Magenta
                Write-Host "1)  Main Menu"
                Write-Host "2)  Rename File & Folder"
                Write-Host "3)  Generate .NFO"
                Write-Host "4)  Rename & Generate"
                Write-Host "------------------------------------------------"
                $subChoice = Read-Host -Prompt "Choice"

                switch ($subChoice) {
                    '1' {
                        Write-Host "Returning to main menu..." -ForegroundColor Yellow
                        break
                    }

                    '2' {
                        Write-Host "`nSelect media file to rename..." -ForegroundColor Cyan
                        $selectedFile = Show-FileDialog -Title "Select media file to rename"
                        
                        if ($selectedFile) {
                            Process-SingleMovie -FilePath $selectedFile -Config $config -RenameOnly
                        } else {
                            Write-Host "No file selected." -ForegroundColor Yellow
                        }
                        
                        continue
                    }

                    '3' {
                        # Check for TMDB token before processing
                        $tmdbToken = Get-TMDBToken -Config $config
                        if (-not $tmdbToken) {
                            Write-Host "TMDB API token not configured. Please set your token first (option 2 from main menu)." -ForegroundColor Red
                            continue
                        }
                        
                        Write-Host "`nSelect media file to generate NFO..." -ForegroundColor Cyan
                        $selectedFile = Show-FileDialog -Title "Select media file to generate NFO"
                        
                        if ($selectedFile) {
                            Process-SingleMovie -FilePath $selectedFile -Config $config -NFOOnly
                        } else {
                            Write-Host "No file selected." -ForegroundColor Yellow
                        }
                        
                        continue
                    }

                    '4' {
                        # Check for TMDB token before processing
                        $tmdbToken = Get-TMDBToken -Config $config
                        if (-not $tmdbToken) {
                            Write-Host "TMDB API token not configured. Please set your token first (option 2 from the main menu)." -ForegroundColor Red
                            continue
                        }
                        
                        Write-Host "`nSelect media file to rename and generate NFO..." -ForegroundColor Cyan
                        $selectedFile = Show-FileDialog -Title "Select media file to rename and generate NFO"
                        
                        if ($selectedFile) {
                            Process-SingleMovie -FilePath $selectedFile -Config $config -Both
                        } else {
                            Write-Host "No file selected." -ForegroundColor Yellow
                        }
                        
                        continue
                    }

                    default {
                        Write-Host "Invalid choice. Please select a valid option." -ForegroundColor Red
                        continue
                    }
                }
                break
            } while ($true)
        }

        '8' {
            do {
                cls
                Write-Host "`n================================================" -ForegroundColor Green
                Write-Host "         UPDATE ALL MOVIES MENU" -ForegroundColor Green
                Write-Host "================================================" -ForegroundColor Green
                Write-Host "1)  Main Menu"
                Write-Host "2)  Rename Files & Folders"
                Write-Host "3)  Generate .NFOs"
                Write-Host "4)  Rename & Generate"
                Write-Host "------------------------------------------------"
                $subChoice = Read-Host -Prompt "Choice"

                switch ($subChoice) {
                    '1' {
                        Write-Host "Returning to main menu..." -ForegroundColor Yellow
                        break
                    }

                    '2' {
                        if (-not $config.MovieFolder) {
                            Write-Host "Movie folder not set. Please configure it first." -ForegroundColor Red
                            continue
                        }
                        
                        Write-Host "`nScanning for video files in: $($config.MovieFolder)" -ForegroundColor Cyan
                        $videoExtensions = @("*.mkv", "*.mp4", "*.avi", "*.mov", "*.wmv", "*.flv", "*.webm")
                        $allVideoFiles = @()
                        
                        foreach ($ext in $videoExtensions) {
                            $allVideoFiles += Get-ChildItem -Path $config.MovieFolder -Filter $ext -Recurse -File | Where-Object { $_.Name -notmatch "sample" }
                        }
                        
                        if ($allVideoFiles.Count -eq 0) {
                            Write-Host "No video files found." -ForegroundColor Yellow
                            continue
                        }
                        
                        Write-Host "Found $($allVideoFiles.Count) video files to process." -ForegroundColor Green
                        $confirmation = Read-Host "Do you want to proceed? (Y/N)"
                        
                        if ($confirmation -eq "Y" -or $confirmation -eq "YES") {
                            foreach ($videoFile in $allVideoFiles) {
                                Process-SingleMovie -FilePath $videoFile.FullName -Config $config -RenameOnly
                            }
                            Write-Host "`nBatch rename operation completed!" -ForegroundColor Green
                        } else {
                            Write-Host "Operation cancelled." -ForegroundColor Yellow
                        }
                        
                        continue
                    }

                    '3' {
                        if (-not $config.MovieFolder) {
                            Write-Host "Movie folder not set. Please configure it first." -ForegroundColor Red
                            continue
                        }
                        
                        # Check for TMDB token before processing
                        $tmdbToken = Get-TMDBToken -Config $config
                        if (-not $tmdbToken) {
                            Write-Host "TMDB API token not configured. Please set your token first (option 2 from main menu)." -ForegroundColor Red
                            continue
                        }
                        
                        Write-Host "`nScanning for video files in: $($config.MovieFolder)" -ForegroundColor Cyan
                        $videoExtensions = @("*.mkv", "*.mp4", "*.avi", "*.mov", "*.wmv", "*.flv", "*.webm")
                        $allVideoFiles = @()
                        
                        foreach ($ext in $videoExtensions) {
                            $allVideoFiles += Get-ChildItem -Path $config.MovieFolder -Filter $ext -Recurse -File | Where-Object { $_.Name -notmatch "sample" }
                        }
                        
                        if ($allVideoFiles.Count -eq 0) {
                            Write-Host "No video files found." -ForegroundColor Yellow
                            continue
                        }
                        
                        Write-Host "Found $($allVideoFiles.Count) video files to process." -ForegroundColor Green
                        $confirmation = Read-Host "Do you want to proceed? (Y/N)"
                        
                        if ($confirmation -eq "Y" -or $confirmation -eq "YES") {
                            foreach ($videoFile in $allVideoFiles) {
                                Process-SingleMovie -FilePath $videoFile.FullName -Config $config -NFOOnly
                            }
                            Write-Host "`nBatch NFO generation completed!" -ForegroundColor Green
                        } else {
                            Write-Host "Operation cancelled." -ForegroundColor Yellow
                        }
                        
                        continue
                    }

                    '4' {
                        if (-not $config.MovieFolder) {
                            Write-Host "Movie folder not set. Please configure it first." -ForegroundColor Red
                            continue
                        }
                        
                        # Check for TMDB token before processing
                        $tmdbToken = Get-TMDBToken -Config $config
                        if (-not $tmdbToken) {
                            Write-Host "TMDB API token not configured. Please set your token first (option 2 from main menu)." -ForegroundColor Red
                            continue
                        }
                        
                        Write-Host "`nScanning for video files in: $($config.MovieFolder)" -ForegroundColor Cyan
                        $videoExtensions = @("*.mkv", "*.mp4", "*.avi", "*.mov", "*.wmv", "*.flv", "*.webm")
                        $allVideoFiles = @()
                        
                        foreach ($ext in $videoExtensions) {
                            $allVideoFiles += Get-ChildItem -Path $config.MovieFolder -Filter $ext -Recurse -File | Where-Object { $_.Name -notmatch "sample" }
                        }
                        
                        if ($allVideoFiles.Count -eq 0) {
                            Write-Host "No video files found." -ForegroundColor Yellow
                            continue
                        }
                        
                        Write-Host "Found $($allVideoFiles.Count) video files to process." -ForegroundColor Green
                        $confirmation = Read-Host "Do you want to proceed? (Y/N)"
                        
                        if ($confirmation -eq "Y" -or $confirmation -eq "YES") {
                            foreach ($videoFile in $allVideoFiles) {
                                Process-SingleMovie -FilePath $videoFile.FullName -Config $config -Both
                            }
                            Write-Host "`nBatch rename and NFO generation completed!" -ForegroundColor Green
                        } else {
                            Write-Host "Operation cancelled." -ForegroundColor Yellow
                        }
                        
                        continue
                    }

                    default {
                        Write-Host "Invalid choice. Please select a valid option." -ForegroundColor Red
                        continue
                    }
                }
                break
            } while ($true)
        }

        '9' {
            Write-Host "Update single show - coming soon!" -ForegroundColor Yellow
            Read-Host "`nPress any key to continue"
        }

        '10' {
            Write-Host "Update all shows - coming soon!" -ForegroundColor Yellow
            Read-Host "`nPress any key to continue"
        }

        '11' {
            Start-DisneyGame
            continue
        }

        '12' {
            Start-SuperheroGame
            continue
        }

        '13' {
            Start-HorrorGame
            continue
        }

        default {
            Write-Host -ForegroundColor Red "Invalid choice. Please select a valid option."
        }
    }

    # ========================================
    # Post-Processing and Cleanup
    # ========================================
    
    # Clean up variables after each menu interaction to prevent memory leaks
    # and ensure fresh state for next operation
    $selectedFile = $null
    $movieData = $null
    $movieInfo = $null

    # Pause before returning to menu (unless user is exiting)
    # This allows users to read any status messages or results
    if ($Choice -ne 1) {
        Read-Host "`nPress any key to return to menu"
        # Note: Screen will be cleared at the start of next loop iteration
    }
} while ($Choice -ne '1')  # Continue until user chooses to exit

# ============================================================================
# END OF MEDIA MANAGER V9.0.0
# ============================================================================