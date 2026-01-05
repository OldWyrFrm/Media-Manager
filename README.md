# 🎬 Media Manager V9.0.0

> **A comprehensive PowerShell suite for organizing and managing your media collection with The Movie Database (TMDB) integration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)](https://docs.microsoft.com/en-us/powershell/)
[![TMDB](https://img.shields.io/badge/TMDB-API%20v3-green)](https://www.themoviedb.org/documentation/api)
[![License](https://img.shields.io/badge/License-Free-brightgreen)](LICENSE)

---

## 📋 Table of Contents

- [✨ Features](#-features)
- [🚀 Quick Start](#-quick-start)
- [⚙️ Configuration](#️-configuration)
- [🎯 Core Functionality](#-core-functionality)
- [🔧 Advanced Features](#-advanced-features)
- [📂 File Organization](#-file-organization)
- [🎮 Entertainment Features](#-entertainment-features)
- [🛠️ Technical Details](#️-technical-details)
- [📖 Usage Examples](#-usage-examples)
- [⚠️ Troubleshooting](#️-troubleshooting)

---

## ✨ Features

### 🎯 **Core Media Management**
- **Smart File Renaming** with dual delimiter support (`Media_Title-ReleaseYear-Resolution-AudioCodec`)
- **Comprehensive NFO Generation** with cast, crew, and metadata
- **Bulk Processing** for entire movie collections
- **Smart Change Detection** - only shows actual changes needed
- **Folder Organization** with customizable naming schemes

### 🔍 **Advanced Detection**
- **Automatic Title Extraction** from filenames and folders
- **Trailing Media Tag Removal** (removes tags like "720p", "aac" from titles)
- **Year, Language & Quality Detection** from file/folder names
- **Resolution, Codec & Source Recognition** for proper tagging

### 🎨 **Naming Flexibility**
- **Dual Delimiter System**: Use `_` for spaces in titles, `-` for separating tags
- **Customizable Formats**: Choose from multiple naming schemes
- **Media_Title Support**: Enhanced naming with `Media_Title-ReleaseYear-Resolution`
- **Legacy Title Support**: Backwards compatible with `Title-ReleaseYear` formats

### 🎮 **Entertainment**
- **Disney Movie Guessing Game**
- **Superhero Movie Guessing Game**
- **Horror Movie Guessing Game**

---

## 🚀 Quick Start

### Prerequisites
- **PowerShell 5.1** or later
- **Internet connection** for TMDB API access
- **TMDB API Token** ([Free registration required](https://www.themoviedb.org/settings/api))

### Installation
1. Download `MediaManager.ps1` to your desired location
2. Right-click and select "Run with PowerShell" **OR**
3. Open PowerShell and navigate to the script location:
   ```powershell
   cd "C:\Path\To\Your\Script"
   .\MediaManager.ps1
   ```

### First Run Setup
1. **Set TMDB API Token** (Option 2)
2. **Set Movie Folder** (Option 3) - Optional but recommended
3. **Configure File Format** (Option 5) - Choose your preferred naming scheme
4. **You're ready to organize!**

---

## ⚙️ Configuration

### 🔑 **TMDB API Token Setup**
1. Create a free account at [TMDB](https://www.themoviedb.org/)
2. Navigate to Settings → API
3. Copy your **API Read Access Token** (not the API Key)
4. Use **Option 2** in the main menu to securely store your token

> **🔒 Security**: Tokens are encrypted using Windows DPAPI for the current user only

### 📂 **Folder Configuration**
- **Movie Folder** (Option 3): Set your main movies directory
- **Show Folder** (Option 4): Set your TV shows directory *(Coming Soon)*

### 🎨 **Naming Scheme Configuration**

#### **Movie File Format (Option 5)**

**Available Components:**
- `Media` + `Title` (use `Media_Title`, `Media-Title`, or `Media.Title`)
- `ReleaseYear` - Movie release year
- `Resolution` - Video quality (720p, 1080p, 4K, etc.)
- `Technology` - HDR, HDR10+, Dolby Vision, etc.
- `AudioCodec` - Audio format (AAC, DTS, Atmos, etc.)
- `VideoCodec` - Video codec (H264, H265, AV1, etc.)
- `Source` - Release source (BluRay, WEB-DL, etc.)
- `ReleaseType` - Extended, Director's Cut, etc.

**Valid Delimiters:** `-` (hyphen), `_` (underscore), `.` (period)

**Examples:**
```
Media_Title-ReleaseYear-Resolution-AudioCodec
Media.Title.ReleaseYear.Resolution
Title-ReleaseYear-Source
```

#### **Dual Delimiter System**
The `Media_Title` format uses **two different delimiters**:
- **First delimiter** (after Media): Used for spaces within movie titles
- **Second delimiter**: Used to separate metadata components

**Example:**
- Format: `Media_Title-ReleaseYear-Resolution-AudioCodec`
- File: `Home Alone (1990) 720p aac.mkv`
- Result: `Home_Alone-1990-720p-aac.mkv`

---

## 🎯 Core Functionality

### **📋 Main Menu Options**

| Option | Function | Description |
|--------|----------|-------------|
| **1** | Exit | Close the application |
| **2** | Set TMDB Token | Configure API access (required) |
| **3** | Set Movie Folder | Choose movies directory |
| **4** | Set Show Folder | Choose TV shows directory |
| **5** | Movie File Format | Configure movie naming scheme |
| **6** | Show File Format | Configure show naming scheme |
| **7** | Update Single Movie | Process individual movie files |
| **8** | Update All Movies | Bulk process movie collection |
| **9** | Update Single Show | *Work in Progress* |
| **10** | Update All Shows | *Work in Progress* |
| **11-13** | Games | Entertainment features |

### **🎬 Single Movie Menu (Option 7)**

| Sub-Option | Function | Description |
|------------|----------|-------------|
| **1** | Main Menu | Return to main menu |
| **2** | Rename File & Folder | Rename without NFO generation |
| **3** | Generate .NFO | Create NFO without renaming |
| **4** | Rename & Generate | Complete processing (rename + NFO) |

### **📦 Bulk Processing Menu (Option 8)**

| Sub-Option | Function | Description |
|------------|----------|-------------|
| **1** | Main Menu | Return to main menu |
| **2** | Rename Files & Folders | Batch rename entire collection |
| **3** | Generate .NFOs | Batch create NFO files |
| **4** | Rename & Generate | Complete batch processing |

---

## 🔧 Advanced Features

### **🧠 Smart Change Detection**
The script intelligently determines what actually needs changing:
- **File Comparison**: Compares current filename with proposed filename
- **Folder Comparison**: Checks if folder rename is needed
- **NFO Analysis**: Compares existing NFO content with proposed content
- **Change Summary**: Only shows changes that will actually be made

### **🏷️ Trailing Media Tag Removal**
Automatically cleans movie titles by removing trailing media tags:

**Detected Tags:**
- **Resolution**: 720p, 1080p, 4K, UHD, etc.
- **Audio**: AAC, DTS, Atmos, 5.1, 7.1, etc.
- **Video**: H264, H265, HEVC, AV1, etc.
- **Source**: BluRay, WEB-DL, DVDRip, etc.
- **Release Type**: Extended, Director's Cut, Remastered, etc.

**Example:**
```
Input:  "Home Alone 1990 720p aac"
Output: "Home Alone"  (tags removed)
```

### **📄 Enhanced NFO Generation**
Creates comprehensive NFO files with:

**Basic Information:**
- Title, Year, Plot Summary
- TMDB and IMDB IDs
- Runtime, Rating, Tagline
- Genres, Production Companies

**Cast & Crew:**
- Top 10 cast members with roles and photos
- Directors and writers
- Character names and actor photos

**External Data:**
- High-resolution poster links
- Backdrop images
- Keywords and collections

### **🔄 Bulk Processing Intelligence**
- **Recursive File Discovery**: Finds all video files in subdirectories
- **Safety Confirmations**: Prompts before batch operations
- **Progress Tracking**: Shows processing status
- **Error Handling**: Continues processing despite individual file errors
- **Supported Formats**: MKV, MP4, AVI, MOV, WMV, FLV, WEBM

---

## 📂 File Organization

### **🎯 Folder Structure Management**

#### **Generic to Specific Conversion**
```
Before:
Movie/
├── Home Alone.mkv
└── Die Hard.mkv

After:
Movie/
├── Home_Alone-1990/
│   ├── Home_Alone-1990-720p-aac.mkv
│   └── movie.nfo
└── Die_Hard-1988/
    ├── Die_Hard-1988-1080p-dts.mkv
    └── movie.nfo
```

#### **Existing Folder Renaming**
```
Before:
Home.Alone.1990.720p/
└── Home.Alone.1990.720p.mkv

After:
Home_Alone-1990/
├── Home_Alone-1990-720p.mkv
└── movie.nfo
```

### **🏗️ Processing Order**
1. **File Analysis**: Extract title, year, and media tags
2. **TMDB Lookup**: Search and match movie data
3. **Change Detection**: Compare current vs proposed names
4. **User Confirmation**: Show only actual changes needed
5. **Execution**: Rename files/folders and generate NFO
6. **Validation**: Verify successful completion

---

## 🎮 Entertainment Features

### **🏰 Disney Movie Game (Option 11)**
- Random Disney movie selection from TMDB
- Year hint and plot provided
- Test your Disney knowledge!

### **🦸 Superhero Movie Game (Option 12)**
- Marvel, DC, and superhero movie database
- Plot-based guessing challenge
- "Avengers level intellect" scoring

### **👻 Horror Movie Game (Option 13)**
- Horror genre movie selection
- Survival-themed scoring system
- "You died!" vs "You survived" results

---

## 🛠️ Technical Details

### **🔍 Movie Information Extraction**

#### **Title Detection Priority:**
1. **Filename Analysis**: Extract from base filename
2. **Folder Name Fallback**: Use parent folder if filename insufficient
3. **Cleaning Process**: Remove brackets, special characters, media tags
4. **Language Detection**: Identify language codes (EN, FR, DE, etc.)

#### **Year Extraction:**
```regex
Pattern: (?<!\d)(19|20)\d{2}(?!\d)
Sources: Filename → Folder → Manual entry
```

#### **Media Tag Recognition:**
```regex
Resolution: (2160p|1440p|1080p|720p|540p|480p|360p|4k|8k|uhd|fhd|hd)
Audio: (atmos|dts-hd|dts|truehd|aac|ac3|5\.1|7\.1)
Video: (h\.?26[45]|hevc|av1|vp9|xvid|x26[45])
Source: (remux|web-dl|bluray|bdrip|dvdrip|hdtv)
```

### **🎨 Filename Construction**

#### **Media_Title Format Processing:**
```powershell
# Detect format components
$mediaMatch = [regex]::Match($format, 'Media([_\-\.])Title')
$titleDelimiter = $mediaMatch.Groups[1].Value  # For title spaces
$mainDelimiter = # Detected from remaining format    # For tag separation

# Clean title and apply delimiters
$cleanTitle = $title -replace '\s+', $titleDelimiter
$finalName = ($parts -join $mainDelimiter) + $extension
```

#### **Consecutive Delimiter Cleanup:**
```powershell
# Remove multiple consecutive delimiters
$escapedDelimiter = [regex]::Escape($delimiter)
$cleanName = $name -replace "$escapedDelimiter{2,}", $delimiter
```

### **🔐 Security Features**

#### **Token Storage:**
- **DPAPI Encryption**: Windows Data Protection API
- **User-Specific**: Only current user can decrypt
- **Secure Handling**: Never stored in plain text

#### **Input Validation:**
- **Path Validation**: Verify file/folder existence
- **Format Validation**: Check naming scheme syntax
- **API Validation**: Verify token before requests

#### **Error Handling:**
- **Graceful Failures**: Continue processing on individual errors
- **User Feedback**: Clear error messages and recovery options
- **State Management**: Maintain consistent file system state

---

## 📖 Usage Examples

### **🎬 Single Movie Processing**

```powershell
# Example: Process "Home Alone (1990) 720p aac.mkv"

1. Script detects:
   - Title: "Home Alone" (after removing "720p aac")
   - Year: 1990
   - Tags: Resolution=720p, AudioCodec=aac

2. TMDB Search:
   - Finds: "Home Alone" (1990)
   - Downloads: Cast, crew, plot, etc.

3. Proposed Changes:
   - New filename: "Home_Alone-1990-720p-aac.mkv"
   - New folder: "Home_Alone-1990/"
   - NFO creation: movie.nfo with full metadata

4. User confirms and processing completes
```

### **📦 Bulk Collection Processing**

```powershell
# Example: Process entire movie collection

Input Directory:
Movies/
├── Action Movie (2020) 1080p.mkv
├── Comedy Film 2019 720p dts.mkv
└── Drama Series Movie 4K HDR.mkv

Output Directory:
Movies/
├── Action_Movie-2020/
│   ├── Action_Movie-2020-1080p.mkv
│   └── movie.nfo
├── Comedy_Film-2019/
│   ├── Comedy_Film-2019-720p-dts.mkv
│   └── movie.nfo
└── Drama_Series_Movie-2021/
    ├── Drama_Series_Movie-2021-4K-HDR.mkv
    └── movie.nfo
```

### **🎨 Naming Scheme Examples**

#### **Conservative Approach:**
```powershell
Format: "Title-ReleaseYear"
Input:  "The Matrix Reloaded (2003) 1080p.mkv"
Output: "The-Matrix-Reloaded-2003.mkv"
```

#### **Detailed Approach:**
```powershell
Format: "Media_Title-ReleaseYear-Resolution-AudioCodec"
Input:  "The Matrix Reloaded (2003) 1080p DTS.mkv"
Output: "The_Matrix_Reloaded-2003-1080p-DTS.mkv"
```

#### **Comprehensive Approach:**
```powershell
Format: "Media_Title-ReleaseYear-Resolution-Technology-AudioCodec-Source"
Input:  "Avatar The Way of Water (2022) 4K HDR DTS Atmos BluRay.mkv"
Output: "Avatar_The_Way_of_Water-2022-4K-HDR-DTS_Atmos-BluRay.mkv"
```

---

## ⚠️ Troubleshooting

### **🔧 Common Issues**

#### **"Movie not found in TMDB database"**
**Causes:**
- Unusual or foreign movie titles
- Typos in filenames
- Trailing media tags confusing the search

**Solutions:**
1. Check filename for accuracy
2. Try manual search with corrected title
3. Verify release year is correct
4. Remove excessive tags from filename

#### **"TMDB API token not set"**
**Causes:**
- Token not configured
- Token expired or invalid
- Network connectivity issues

**Solutions:**
1. Verify token in TMDB account settings
2. Reconfigure using Option 2
3. Check internet connection
4. Ensure token is "Read Access Token" not "API Key"

#### **"Error renaming file/folder"**
**Causes:**
- File in use by another program
- Insufficient permissions
- Target name already exists
- Path too long

**Solutions:**
1. Close media players/browsers
2. Run PowerShell as Administrator
3. Check for duplicate names
4. Use shorter naming schemes

### **🔍 Debug Information**

#### **File Processing Details:**
```powershell
# Check what the script detects:
Detected Title: "Home Alone"
Detected Year: 1990
Detected Language: EN
Detected Tags: Resolution=720p, AudioCodec=aac
```

#### **Configuration Check:**
```powershell
# Verify current settings:
Movie Folder: C:\Movies
File Format: Media_Title-ReleaseYear-Resolution-AudioCodec
Folder Format: Media_Title-ReleaseYear
TMDB Token: [Configured]
```

### **📞 Support**

For additional support or feature requests:
1. Check that you're using the latest version (V8.4)
2. Verify all prerequisites are met
3. Review the troubleshooting section
4. Check TMDB API status at [TMDB Status Page](https://status.themoviedb.org/)

---

## 📋 Requirements Summary

| Component | Requirement | Status |
|-----------|-------------|--------|
| **OS** | Windows 10/11 | ✅ Required |
| **PowerShell** | 5.1 or later | ✅ Required |
| **Internet** | Stable connection | ✅ Required |
| **TMDB Account** | Free registration | ✅ Required |
| **Storage** | Write permissions | ✅ Required |

---

**🎬 Happy organizing! Transform your chaotic media collection into a perfectly organized library with Media Manager V8.4!**

> **💡 Pro Tip**: Start with a small test folder before processing your entire collection to get familiar with the naming schemes and options.
