# MVP Components Definition

Minimum Viable Product for Nature Image Evaluation
Version: 1.0

## MVP Goal

Create a functional image evaluation system that allows a photographer to:
1. Import images
2. Resize and process them
3. Send to Anthropic API for evaluation
4. Store results in Core Data
5. View images with scores in a sortable gallery

## Core Components Needed

### 1. Core Data Stack

**Priority**: HIGHEST (foundation for everything)

**Files**:
- `NatureImageEvaluation.xcdatamodeld` - Core Data model
- `PersistenceController.swift` - Core Data stack manager

**Entities Required for MVP**:
- `ImageEvaluation`
  - id: UUID
  - originalFilePath: String (security-scoped bookmark data)
  - processedFilePath: String
  - originalWidth: Int32
  - originalHeight: Int32
  - processedWidth: Int32
  - processedHeight: Int32
  - aspectRatio: Double
  - fileSize: Int64
  - dateAdded: Date
  - dateLastEvaluated: Date
  - thumbnailData: Data (for UI)
  - Relationship: evaluationResults (one-to-many)

- `EvaluationResult`
  - id: UUID
  - evaluationDate: Date
  - compositionScore: Double
  - qualityScore: Double
  - sellabilityScore: Double
  - artisticScore: Double
  - overallWeightedScore: Double
  - primaryPlacement: String
  - strengths: Transformable<[String]>
  - improvements: Transformable<[String]>
  - marketComparison: String
  - rawAIResponse: String (full JSON)
  - tokensUsed: Int32
  - estimatedCost: Double
  - Relationship: imageEvaluation (many-to-one)

- `APIUsageStats` (singleton)
  - id: UUID
  - totalTokensUsed: Int64
  - totalCost: Double
  - totalImagesEvaluated: Int32
  - lastResetDate: Date

**NOT in MVP**:
- ~~StorageStats~~ (Phase 2)
- ~~Archive management~~ (Phase 2)
- ~~Multiple evaluation versions~~ (keep simple - one evaluation per image)

### 2. Image Processing

**Priority**: HIGHEST (needed before API calls)

**Files**:
- `ImageProcessor.swift` - vImage-based resizing

**Capabilities**:
```swift
class ImageProcessor {
    // Resize image to max 1568px on longest edge
    func resizeForEvaluation(image: NSImage, maxDimension: Int = 1568) -> NSImage?

    // Generate thumbnail for gallery (100x100)
    func generateThumbnail(image: NSImage, size: CGSize = CGSize(width: 100, height: 100)) -> NSImage?

    // Convert image to base64 for API
    func imageToBase64(image: NSImage, format: NSBitmapImageRep.FileType = .jpeg) -> String?

    // Get aspect ratio
    func calculateAspectRatio(width: CGFloat, height: CGFloat) -> Double
}
```

**Implementation**:
- Use vImage from Accelerate framework
- Maintain aspect ratio
- High-quality Lanczos resampling
- Error handling for corrupt/unsupported images

### 3. Security-Scoped Bookmark Manager

**Priority**: HIGHEST (needed for persistent file access)

**Files**:
- `BookmarkManager.swift`

**Capabilities**:
```swift
class BookmarkManager {
    // Create bookmark from URL (when user selects file)
    func createBookmark(for url: URL) throws -> Data

    // Resolve bookmark to URL
    func resolveBookmark(from bookmarkData: Data) throws -> URL

    // Start accessing security-scoped resource
    func accessResource(at url: URL, perform: (URL) -> Void) throws

    // Check if bookmark is stale
    func isBookmarkStale(bookmarkData: Data) -> Bool
}
```

**Implementation**:
- Handle stale bookmarks
- Proper start/stop accessing calls
- Error handling for missing/moved files

### 4. Anthropic API Service

**Priority**: HIGHEST (core functionality)

**Files**:
- `AnthropicAPIService.swift`
- `AnthropicModels.swift` (request/response structs)

**Capabilities**:
```swift
class AnthropicAPIService {
    // Send image evaluation request
    func evaluateImage(
        imageBase64: String,
        prompt: String,
        apiKey: String
    ) async throws -> EvaluationResponse

    // Parse JSON response into structured data
    func parseEvaluationResponse(_ json: String) throws -> EvaluationResponse

    // Calculate cost based on tokens and model
    func calculateCost(inputTokens: Int, outputTokens: Int, model: String) -> Double

    // Monitor rate limit headers from response
    func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo

    // Handle 429 errors with exponential backoff
    func retryWithBackoff(operation: () async throws -> EvaluationResponse,
                          maxRetries: Int) async throws -> EvaluationResponse
}

struct EvaluationResponse {
    let compositionScore: Double
    let qualityScore: Double
    let sellabilityScore: Double
    let artisticScore: Double
    let overallScore: Double
    let primaryPlacement: String
    let strengths: [String]
    let improvements: [String]
    let marketComparison: String
    let technicalInnovations: [String]?
    let printSizeRecommendation: String?
    let priceTierSuggestion: String?
    let inputTokens: Int
    let outputTokens: Int
}

struct RateLimitInfo {
    let requestsRemaining: Int
    let inputTokensRemaining: Int
    let outputTokensRemaining: Int
    let requestsReset: Date
    let tokensReset: Date
}
```

**Implementation**:
- Async/await for network calls
- Error handling (429 rate limit, 401 auth, 403 forbidden, network timeout)
- Retry logic with exponential backoff (honor retry-after header)
- Parse rate limit headers from response
- Parse structured JSON from docs/Suggested_AI_Prompt.txt format
- Token bucket awareness (continuous replenishment)

### 5. Keychain Manager (API Key Storage)

**Priority**: HIGH (secure credential storage)

**Files**:
- `KeychainManager.swift`

**Capabilities**:
```swift
class KeychainManager {
    // Save API key securely
    func saveAPIKey(_ key: String) throws

    // Retrieve API key
    func getAPIKey() throws -> String?

    // Delete API key
    func deleteAPIKey() throws

    // Check if API key exists
    func hasAPIKey() -> Bool
}
```

**Implementation**:
- Use Security framework
- Handle Keychain errors gracefully
- Never log keys

### 6. Evaluation Manager (Orchestrator)

**Priority**: HIGH (coordinates everything)

**Files**:
- `EvaluationManager.swift`

**Capabilities**:
```swift
@Observable
class EvaluationManager {
    var isProcessing: Bool = false
    var currentProgress: Double = 0
    var statusMessage: String = ""
    var evaluationQueue: [ImageEvaluation] = []
    var requestDelay: TimeInterval = Constants.defaultRequestDelay
    var maxBatchSize: Int = Constants.maxBatchSize

    // Add images to evaluation queue
    func addImages(urls: [URL]) async

    // Process queue with rate limiting and batching
    func startEvaluation(apiKey: String) async throws

    // Process single image with delay
    func evaluateImage(_ image: ImageEvaluation, apiKey: String) async throws

    // Apply rate limit delay between requests
    func applyRateLimit() async

    // Cancel processing
    func cancelEvaluation()
}
```

**Implementation**:
- @Observable for SwiftUI reactivity
- Batch processing (10-15 images per batch)
- Rate limiting: 2-3 second delay between API calls
- Progress reporting with batch information
- Error handling and recovery
- Pause/resume capability for rate limit errors

### 7. User Interface (SwiftUI)

**Priority**: MEDIUM (can start simple)

**Files**:
- `ContentView.swift` - Main container
- `ImageSelectionView.swift` - Import images
- `GalleryView.swift` - Grid of images with scores
- `DetailView.swift` - Full evaluation details
- `SettingsView.swift` - API key configuration

**MVP UI Flow**:

```
┌─────────────────────────────────────────┐
│         ContentView                     │
│  ┌─────────────────────────────────┐   │
│  │   Sidebar (if multiple views)   │   │
│  │   - Gallery                     │   │
│  │   - Settings                    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Main Content Area:                     │
│  ┌─────────────────────────────────┐   │
│  │   GalleryView                   │   │
│  │   ┌───┬───┬───┬───┐            │   │
│  │   │ 📷│ 📷│ 📷│ 📷│            │   │
│  │   │8.5│7.2│9.1│6.8│            │   │
│  │   └───┴───┴───┴───┘            │   │
│  │                                 │   │
│  │   [+ Import Images] [Evaluate] │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

**GalleryView Requirements**:
- LazyVGrid with thumbnails (100x100)
- Show overall score below each image
- Sort by: date added, score (overall/composition/quality/sellability/artistic)
- Click to open DetailView

**DetailView Requirements**:
- Full image (or thumbnail if processing)
- All scores displayed
- Strengths and improvements lists
- Primary placement (PORTFOLIO/STORE/BOTH/ARCHIVE)
- Token usage and cost
- Date evaluated

**SettingsView Requirements**:
- API key input (secure text field)
- API provider selection (Anthropic Claude / OpenAI GPT-4 Vision)
- Save/test connection button
- Usage stats (total tokens, total cost, images evaluated)
- Rate limiting controls:
  - Request delay slider (1-5 seconds, default: 2)
  - Max batch size (5-25 images, default: 15)
  - Show current rate limit status

### 8. Prompt Loader

**Priority**: MEDIUM (loads evaluation criteria)

**Files**:
- `PromptLoader.swift`

**Capabilities**:
```swift
class PromptLoader {
    // Load evaluation prompt from docs/Suggested_AI_Prompt.txt
    func loadEvaluationPrompt() -> String

    // Get current prompt version
    func getPromptVersion() -> String
}
```

**Implementation**:
- Load from bundle resources
- Cache in memory
- Handle missing file gracefully

## MVP User Flow

### 1. First Launch
1. User opens app
2. Prompted for API key (Settings view)
3. Enter key, save to Keychain
4. Return to Gallery view

### 2. Import & Evaluate
1. Click "Import Images" button
2. NSOpenPanel appears (shift/cmd-select multiple images)
3. Images added to evaluation queue (shows: "15 images queued")
4. For each image:
   - Create ImageEvaluation entity
   - Store security-scoped bookmark
   - Resize to 1568px max
   - Save processed image to Application Support
   - Generate thumbnail
5. Click "Evaluate" button (if >15 images, shows batch info)
6. Progress shown: "Processing 8 of 15 images (batch 1 of 2)..."
7. API calls made sequentially with 2-second delay between calls
8. Rate limit monitoring (pause if 429 error received)
9. Results stored in Core Data after each evaluation
10. Gallery updates incrementally as images complete

### 3. View Results
1. Gallery shows thumbnails with overall scores
2. Click image to see DetailView
3. See full evaluation breakdown
4. Return to gallery

### 4. Sort/Filter
1. Dropdown menu: "Sort by: Overall Score"
2. Gallery re-orders images
3. Find highest scoring images quickly

## Rate Limiting Strategy

### Why Rate Limiting Matters
1. **Anthropic API Limits** - Tier-based rate limits (50 RPM for all tiers)
2. **Cost Control** - Prevents accidental runaway costs
3. **Good API Citizenship** - Don't hammer external services
4. **Better UX** - Realistic progress indication, not instant failures

### Implementation Approach

**Batch Processing:**
- Default batch size: 15 images per evaluation run
- User can adjust in settings (5-25 images)
- Multiple batches processed sequentially
- Clear UI: "Processing batch 1 of 3..."

**Inter-Request Delay:**
- Default: 2 seconds between API calls
- User-configurable (1-5 seconds in settings)
- Prevents hitting 50 RPM limit (120 seconds / 50 = 2.4s minimum)
- Conservative default gives ~25-30 images/minute

**429 Error Handling:**
```swift
// Exponential backoff strategy
if response.statusCode == 429 {
    let retryAfter = response.value(forHTTPHeaderField: "retry-after")
    // Wait retryAfter seconds (or default 30s)
    // Show user: "Rate limit reached, waiting 30 seconds..."
    // Retry request
}
```

**Rate Limit Monitoring:**
- Parse response headers:
  - `anthropic-ratelimit-requests-remaining`
  - `anthropic-ratelimit-input-tokens-remaining`
  - `anthropic-ratelimit-output-tokens-remaining`
- Show in UI: "API requests remaining: 42/50"
- Warn user if approaching limits

### Anthropic API Rate Limits (Current)

**Claude Sonnet 4.x (All Tiers):**
- Requests per minute (RPM): 50
- Input tokens per minute (ITPM): 30,000
- Output tokens per minute (OTPM): 8,000

**Claude Haiku 4.5 (All Tiers):**
- Requests per minute (RPM): 50
- Input tokens per minute (ITPM): 50,000
- Output tokens per minute (OTPM): 10,000

**Token Bucket Algorithm:**
- Capacity continuously replenished (not reset at fixed intervals)
- Can burst up to limit if tokens available
- More forgiving than fixed-window rate limiting

### UI Considerations

**During Evaluation:**
- Progress: "Processing image 8 of 15 (batch 1 of 2)"
- Time estimate: "~2 seconds per image, 14 seconds remaining"
- Pause button: "Pause evaluation" (completes current image)
- Rate limit status: "API: 42/50 requests remaining"

**Rate Limit Hit:**
- Alert: "Rate limit reached. Waiting 30 seconds before continuing..."
- Option: "Cancel evaluation" or "Wait and continue"
- Don't lose progress - resume from where we stopped

**Settings Controls:**
- Request delay slider: "Delay between requests: [2.0] seconds"
- Batch size selector: "Process [15] images per batch"
- Help text: "Lower delays = faster processing but higher risk of rate limits"

## What's NOT in MVP

### Phase 2 Features (Post-MVP)
- ❌ Archive management (external/NAS storage)
- ❌ Storage monitoring and alerts
- ❌ Auto-archive policies
- ❌ Multiple evaluations per image (history tracking)
- ❌ Evaluation version tracking
- ❌ Batch API requests (if Anthropic adds support)
- ❌ Reprocess from original
- ❌ Export functionality
- ❌ Aspect ratio correlation analysis

### Phase 3 Features (Future)
- ❌ Learning/personalization
- ❌ User disagreement tracking
- ❌ Custom criteria weighting
- ❌ ML model training
- ❌ Comparative analysis tools

## File Structure for MVP

```
Nature Image Evaluation/
├── Nature_Image_Evaluation.entitlements
├── Info.plist
├── App/
│   ├── Nature_Image_EvaluationApp.swift (App entry point)
│   └── ContentView.swift
├── Core Data/
│   ├── NatureImageEvaluation.xcdatamodeld
│   └── PersistenceController.swift
├── Services/
│   ├── AnthropicAPIService.swift
│   ├── BookmarkManager.swift
│   ├── ImageProcessor.swift
│   ├── KeychainManager.swift
│   └── PromptLoader.swift
├── Managers/
│   └── EvaluationManager.swift
├── Models/
│   └── AnthropicModels.swift (request/response structs)
├── Views/
│   ├── GalleryView.swift
│   ├── ImageGridCell.swift (custom grid cell)
│   ├── DetailView.swift
│   ├── SettingsView.swift
│   └── ImageSelectionView.swift
├── Utilities/
│   └── Constants.swift (app constants, pricing, etc.)
├── Resources/
│   ├── Suggested_AI_Prompt.txt (bundled resource)
│   └── Assets.xcassets/
└── Tests/
    ├── ImageProcessorTests.swift
    ├── BookmarkManagerTests.swift
    └── AnthropicAPIServiceTests.swift
```

## Development Order (Build in This Sequence)

### Week 1: Foundation
1. ✅ Core Data model and PersistenceController
2. ✅ BookmarkManager (test with sample files)
3. ✅ KeychainManager (test saving/retrieving)
4. ✅ Basic UI shell (ContentView, SettingsView)

### Week 2: Image Processing
5. ✅ ImageProcessor with vImage
6. ✅ Thumbnail generation
7. ✅ File system storage setup
8. ✅ Test image import flow

### Week 3: API Integration
9. ✅ AnthropicAPIService
10. ✅ PromptLoader
11. ✅ Test API calls with sample images
12. ✅ Parse and store responses

### Week 4: Orchestration & UI
13. ✅ EvaluationManager (queue, progress)
14. ✅ GalleryView with LazyVGrid
15. ✅ DetailView
16. ✅ Sorting/filtering

### Week 5: Polish & Testing
17. ✅ Error handling throughout
18. ✅ Unit tests for critical components
19. ✅ UI polish (follow HIG)
20. ✅ End-to-end testing

## Success Criteria for MVP

- [ ] User can import 10+ images at once
- [ ] Images processed and stored correctly
- [ ] API evaluations complete successfully
- [ ] Scores displayed in gallery
- [ ] Sorting by different categories works
- [ ] Detail view shows full evaluation
- [ ] API key stored securely
- [ ] Usage stats tracked accurately
- [ ] No crashes or data loss
- [ ] Follows macOS 26 Tahoe HIG
- [ ] App Store entitlements minimal and justified

## Performance Targets (MVP)

- Image import: < 2 seconds for 10 images
- Image resize: < 100ms per image
- Thumbnail generation: < 50ms per image
- API call: 2-5 seconds per evaluation
- Gallery scroll: 60+ fps with 100 images
- Core Data queries: < 50ms

Last Updated: 2025-10-27 (Added rate limiting strategy and multi-provider architecture prep)
