# Project Structure Plan

## Current Xcode Boilerplate (What Exists)

```
Nature Image Evaluation/
├── Nature Image Evaluation/
│   ├── Nature_Image_EvaluationApp.swift      ✅ KEEP (modify)
│   ├── ContentView.swift                      ✅ KEEP (rewrite)
│   ├── Persistence.swift                      ✅ KEEP (rename to PersistenceController.swift)
│   ├── Assets.xcassets/                       ✅ KEEP
│   └── Nature_Image_Evaluation.xcdatamodeld/  ✅ KEEP (modify entities)
├── Nature Image EvaluationTests/              ✅ KEEP
└── Nature Image EvaluationUITests/            ❌ DELETE (not needed for MVP)
```

## Proposed Final Structure

```
Nature Image Evaluation/
├── .git/
├── .gitignore
├── README.md (to be created)
├── CLAUDE.md (exists)
├── sample-CLAUDE.md (exists)
│
├── docs/
│   ├── CLAUDE.md (symlink or copy from root)
│   ├── TECHNICAL_RESEARCH.md
│   ├── ENTITLEMENTS.md
│   ├── MVP_COMPONENTS.md
│   ├── PROJECT_STRUCTURE.md (this file)
│   ├── Suggested_AI_Prompt.txt
│   └── Suggested_commercial_potential_criteria.txt
│
├── Nature Image Evaluation.xcodeproj/
│
├── Nature Image Evaluation/  (Main Target)
│   │
│   ├── App/
│   │   ├── Nature_Image_EvaluationApp.swift
│   │   └── Info.plist
│   │
│   ├── Core Data/
│   │   ├── Nature_Image_Evaluation.xcdatamodeld/
│   │   └── PersistenceController.swift (renamed from Persistence.swift)
│   │
│   ├── Services/
│   │   ├── AnthropicAPIService.swift (NEW)
│   │   ├── BookmarkManager.swift (NEW)
│   │   ├── ImageProcessor.swift (NEW)
│   │   ├── KeychainManager.swift (NEW)
│   │   └── PromptLoader.swift (NEW)
│   │
│   ├── Managers/
│   │   └── EvaluationManager.swift (NEW)
│   │
│   ├── Models/
│   │   └── AnthropicModels.swift (NEW)
│   │
│   ├── Views/
│   │   ├── ContentView.swift (rewrite)
│   │   ├── GalleryView.swift (NEW)
│   │   ├── ImageGridCell.swift (NEW)
│   │   ├── DetailView.swift (NEW)
│   │   ├── SettingsView.swift (NEW)
│   │   └── Components/
│   │       └── LoadingView.swift (NEW - reusable)
│   │
│   ├── Utilities/
│   │   └── Constants.swift (NEW)
│   │
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   ├── Suggested_AI_Prompt.txt (copy from docs)
│   │   └── Suggested_commercial_potential_criteria.txt (copy from docs)
│   │
│   └── Nature_Image_Evaluation.entitlements (NEW)
│
└── Nature Image EvaluationTests/
    ├── ImageProcessorTests.swift (NEW)
    ├── BookmarkManagerTests.swift (NEW)
    ├── AnthropicAPIServiceTests.swift (NEW)
    └── PersistenceControllerTests.swift (NEW)
```

## Actions Required

### 1. Delete Boilerplate

```bash
# Delete UI tests (not needed for MVP)
rm -rf "Nature Image EvaluationUITests"
```

### 2. Reorganize Existing Files

```bash
# Create directory structure
mkdir -p "Nature Image Evaluation/App"
mkdir -p "Nature Image Evaluation/Core Data"
mkdir -p "Nature Image Evaluation/Services"
mkdir -p "Nature Image Evaluation/Managers"
mkdir -p "Nature Image Evaluation/Models"
mkdir -p "Nature Image Evaluation/Views/Components"
mkdir -p "Nature Image Evaluation/Utilities"
mkdir -p "Nature Image Evaluation/Resources"

# Move existing files
mv "Nature Image Evaluation/Nature_Image_EvaluationApp.swift" "Nature Image Evaluation/App/"
mv "Nature Image Evaluation/Persistence.swift" "Nature Image Evaluation/Core Data/PersistenceController.swift"
mv "Nature Image Evaluation/ContentView.swift" "Nature Image Evaluation/Views/"
mv "Nature Image Evaluation/Nature_Image_Evaluation.xcdatamodeld" "Nature Image Evaluation/Core Data/"
mv "Nature Image Evaluation/Assets.xcassets" "Nature Image Evaluation/Resources/"

# Copy evaluation prompts to Resources
cp "docs/Suggested_AI_Prompt.txt" "Nature Image Evaluation/Resources/"
cp "docs/Suggested_commercial_potential_criteria.txt" "Nature Image Evaluation/Resources/"
```

### 3. Update Xcode Project References

After moving files, update Xcode project to reflect new folder structure:
- Remove old references
- Add files in new locations
- Create groups matching folder structure

### 4. Create New Files

#### Core Data Model Updates
Update `Nature_Image_Evaluation.xcdatamodeld`:
- Delete existing "Item" entity
- Add ImageEvaluation entity
- Add EvaluationResult entity
- Add APIUsageStats entity

#### Service Layer
Create empty template files:
- AnthropicAPIService.swift
- BookmarkManager.swift
- ImageProcessor.swift
- KeychainManager.swift
- PromptLoader.swift

#### Manager Layer
- EvaluationManager.swift

#### Models
- AnthropicModels.swift

#### Views
- GalleryView.swift
- ImageGridCell.swift
- DetailView.swift
- SettingsView.swift
- Components/LoadingView.swift

#### Utilities
- Constants.swift

#### Tests
- ImageProcessorTests.swift
- BookmarkManagerTests.swift
- AnthropicAPIServiceTests.swift
- PersistenceControllerTests.swift

### 5. Create Entitlements File

Create `Nature_Image_Evaluation.entitlements` with minimal permissions.

### 6. Create .gitignore

```
# Xcode
xcuserdata/
*.xcuserstate
*.xcworkspace/xcuserdata/

# macOS
.DS_Store

# Build
build/
DerivedData/

# Documentation (except README)
*.md
!README.md

# Claude Code
.claude/settings.local.json

# API Keys (never commit)
*.key
*.pem
*_key.txt
```

### 7. Create README.md

Basic project README with:
- Project description
- Features
- Requirements
- Setup instructions
- License

## File Templates

### Constants.swift Template

```swift
//
//  Constants.swift
//  Nature Image Evaluation
//

import Foundation

struct Constants {
    // Anthropic API
    static let anthropicAPIURL = "https://api.anthropic.com/v1/messages"
    static let defaultModel = "claude-3-5-sonnet-20241022"

    // Image Processing
    static let maxImageDimension: Int = 1568
    static let thumbnailSize: CGSize = CGSize(width: 100, height: 100)

    // Pricing (per million tokens)
    static let inputTokenCostPerMillion = 3.00  // $3 per million input tokens
    static let outputTokenCostPerMillion = 15.00 // $15 per million output tokens

    // File Storage
    static let appSupportFolder = "Nature Image Evaluation"
    static let processedImagesFolder = "ProcessedImages"
    static let databaseFolder = "Database"

    // Keychain
    static let keychainServiceName = "com.konradmichels.natureimageevaluation"
    static let keychainAPIKeyAccount = "anthropic_api_key"

    // Evaluation Weights
    static let compositionWeight = 0.30
    static let qualityWeight = 0.25
    static let sellabilityWeight = 0.25
    static let artisticWeight = 0.20
}
```

## Xcode Project Settings to Verify

### Build Settings
- Deployment Target: macOS 15.0
- Swift Language Version: Swift 6
- Code Signing: Sign to Run Locally (for development)

### Info.plist Additions
```xml
<key>CFBundleDisplayName</key>
<string>Nature Image Evaluation</string>

<key>LSMinimumSystemVersion</key>
<string>15.0</string>

<key>NSHumanReadableCopyright</key>
<string>Copyright © 2025 Konrad Michels. All rights reserved.</string>
```

### Capabilities
- App Sandbox: ON
- Outgoing Connections (Client): ON
- User Selected Files: Read/Write

## Next Steps After Structure Creation

1. ✅ Delete boilerplate (UITests)
2. ✅ Create folder structure
3. ✅ Move existing files
4. ✅ Update Xcode project references
5. ✅ Create entitlements file
6. ✅ Update Core Data model (delete Item entity, add our entities)
7. ✅ Create empty service files (with class stubs)
8. ✅ Create empty view files (with struct stubs)
9. ✅ Create Constants.swift
10. ✅ Create .gitignore
11. ✅ Create README.md
12. ✅ Rewrite ContentView.swift (simple MVP shell)
13. ✅ Update PersistenceController.swift (remove Item references)

## Implementation Order After Structure

1. Week 1: Core Data + BookmarkManager + KeychainManager
2. Week 2: ImageProcessor + File storage
3. Week 3: AnthropicAPIService + PromptLoader
4. Week 4: EvaluationManager + UI (Gallery, Detail, Settings)
5. Week 5: Polish + Testing

Last Updated: 2025-10-27
