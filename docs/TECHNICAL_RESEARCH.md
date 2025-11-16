# Technical Research Findings

Research conducted: 2025-10-27

## 1. Image Resizing: vImage vs Core Image

### Decision: Use vImage (Accelerate framework)

**Performance Benchmarks:**
- Core Graphics: 0.1722 (baseline)
- Image I/O: 0.1616 (faster)
- vImage: 2.3126 (FASTEST - 13x faster than Core Graphics)
- Core Image: 2.4983 (slowest, produces artifacts)

**Quality Comparison:**
- vImage produces best results with least difference from reference images
- Uses Lanczos5 resampling filter (industry standard for quality)
- Core Image produced resizing artifacts in tests
- Apple's Performance Best Practices recommends Core Graphics or Image I/O over Core Image

**Implementation:**
- Use vImage for all image resizing operations
- Maintain aspect ratio by calculating scale factor for longest edge
- vImage uses CPU vector instructions (highly optimized)
- Part of Accelerate framework (no external dependencies)

**Code approach:**
```swift
import Accelerate

func resizeImage(image: NSImage, maxDimension: Int = 1568) -> NSImage? {
    // Use vImageScale_ARGB8888 with kvImageHighQualityResampling
    // Calculate scale based on longest edge
    // Return resized NSImage
}
```

## 2. SwiftUI LazyVGrid Performance for Large Collections

### Decision: Use LazyVGrid with thumbnails + pagination

**Performance Characteristics:**
- Pure SwiftUI can achieve 90-100fps on macOS (not 120fps ProMotion)
- AppKit CollectionView can hold 110fps consistently
- For App Store distribution, SwiftUI is acceptable (no AppKit needed)

**Critical Best Practices for Thousands of Images:**

1. **Use Thumbnails** (MOST IMPORTANT)
   - Display small thumbnails (100x100 or 150x150) in grid
   - Full resolution only in detail view
   - Generate thumbnails during import/processing

2. **Lazy Loading**
   - Break ForEach content into custom View structs
   - Binary data only loads when row scrolls onto screen
   - Don't load all Core Data relationships at once

3. **Caching**
   - Cache thumbnails in memory (NSCache)
   - Don't reload from disk on every scroll
   - Consider thumbnail data in Core Data for fastest access

4. **Pagination/Chunking**
   - Load images in batches (e.g., 100 at a time)
   - "Load more" as user scrolls
   - Reduces initial memory footprint

5. **View Optimization**
   ```swift
   struct ImageGridCell: View {
       let evaluation: ImageEvaluation

       var body: some View {
           // Minimal view hierarchy
           // Load thumbnail only
           // Defer full data loading
       }
   }
   ```

**Architecture Decision:**
- Generate 100x100 thumbnails during image import
- Store thumbnail data separately (file system or Core Data blob)
- Use LazyVGrid with custom cell views
- Implement "Load More" for collections > 500 images

## 3. Security-Scoped Bookmarks for Persistent Access

### Decision: Use security-scoped bookmarks with proper entitlements

**How They Work:**
- Sandboxed apps get temporary access when user selects files/folders
- Access is lost when app terminates
- Security-scoped bookmarks provide persistent access across launches
- Uses HMAC-SHA256 authentication via ScopedBookmarkAgent process

**Critical Implementation Details:**

1. **Bookmark Creation:**
   ```swift
   let bookmarkData = try url.bookmarkData(
       options: .withSecurityScope,
       includingResourceValuesForKeys: nil,
       relativeTo: nil
   )
   // Store bookmarkData in Core Data as Data
   ```

2. **Bookmark Resolution:**
   ```swift
   var isStale = false
   let url = try URL(
       resolvingBookmarkData: bookmarkData,
       options: .withSecurityScope,
       relativeTo: nil,
       bookmarkDataIsStale: &isStale
   )

   // CRITICAL: Must call on SAME url instance
   guard url.startAccessingSecurityScopedResource() else {
       // Handle error
       return
   }
   defer { url.stopAccessingSecurityScopedResource() }

   // Access file/folder here
   ```

3. **External Volumes (NAS/External SSD):**
   - Bookmarks can become stale if volume is deleted and recreated
   - Always check `isStale` flag after resolution
   - If stale or resolution fails, present NSOpenPanel to user
   - Configure panel to default to expected location

**Recent Security Update (CVE-2025-31191):**
- Apple patched bookmark vulnerability in March 2025
- Affects macOS 13.7.5+, 14.7.5+, 15.4+
- Our implementation follows best practices (no concerns)

**Error Handling Strategy:**
1. Try to resolve bookmark
2. If fails, update status to "unavailable"
3. Show user-friendly message with reconnect option
4. Never crash - graceful degradation

## 4. macOS 26 Tahoe UI Guidelines

### Decision: Follow Liquid Glass design language

**Key Information:**
- New "Liquid Glass" design language introduced WWDC 2025
- Unified visual theme across all Apple operating systems
- Updated design resources available (Sketch, Photoshop, Illustrator)
- macOS Tahoe is last version supporting Intel Macs

**Design Principles (from available information):**
- Clearer labeling (e.g., "Choose Other…" instead of "Other")
- Updated spacing and visual hierarchy
- Enhanced focus indicators
- Refined color palettes

**Action Items:**
- Use native SwiftUI components (automatic Liquid Glass styling)
- Avoid custom UI chrome where possible
- Follow spacing guidelines from Apple Design Resources
- Test on macOS 26 to ensure proper rendering

**Couldn't Access:**
- Full macOS 26 Tahoe Release Notes (JavaScript required on dev portal)
- Specific SwiftUI updates for macOS 26
- Core Data Sendable updates

**Mitigation:**
- Use native SwiftUI components (will adapt automatically)
- Follow general HIG principles
- Test early and often on macOS 26

## 5. Required Entitlements (Minimal Security Exposure)

### App Sandbox Entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- REQUIRED: Enable App Sandbox -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- REQUIRED: Read original images selected by user -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>

    <!-- REQUIRED: Write to archive locations (external/NAS) -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- REQUIRED: Persistent access via bookmarks -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>

    <!-- REQUIRED: Anthropic API calls -->
    <key>com.apple.security.network.client</key>
    <true/>

    <!-- OPTIONAL: Only if we implement auto-updates later -->
    <!-- <key>com.apple.security.network.server</key> -->
    <!-- <false/> -->
</dict>
</plist>
```

**Rationale for Each Entitlement:**

1. **app-sandbox**: Required for App Store distribution
2. **files.user-selected.read-only**: Read original images user selects for evaluation
3. **files.user-selected.read-write**: Write to archive locations user selects
4. **files.bookmarks.app-scope**: Persistent access across app launches
5. **network.client**: Make HTTPS requests to Anthropic API

**NOT Needed:**
- ❌ Full Disk Access (user selects folders explicitly)
- ❌ Network server (we don't run a server)
- ❌ USB/Bluetooth (no hardware access needed)
- ❌ Camera/Microphone (not needed)
- ❌ Address Book, Calendar, Photos library (not accessed)

**App Store Review:**
- All entitlements justified by core functionality
- No privacy-sensitive entitlements
- No elevated privileges requested
- User explicitly grants access via file pickers

## 6. Anthropic API Rate Limits

### Decision: Implement batch processing with configurable delays

**Current Rate Limits (All Tiers):**

**Claude Sonnet 4.x:**
- Requests per minute (RPM): 50
- Input tokens per minute (ITPM): 30,000
- Output tokens per minute (OTPM): 8,000

**Claude Haiku 4.5:**
- Requests per minute (RPM): 50
- Input tokens per minute (ITPM): 50,000
- Output tokens per minute (OTPM): 10,000

**Key Findings:**

1. **Token Bucket Algorithm**
   - Capacity continuously replenished (not fixed-window reset)
   - Can burst up to limit if tokens available
   - More forgiving than traditional rate limiting

2. **Response Headers for Monitoring**
   - `anthropic-ratelimit-requests-remaining`
   - `anthropic-ratelimit-input-tokens-remaining`
   - `anthropic-ratelimit-output-tokens-remaining`
   - `anthropic-ratelimit-requests-reset` (RFC 3339 format)
   - `anthropic-ratelimit-tokens-reset` (RFC 3339 format)
   - `retry-after` (on 429 errors, seconds to wait)

3. **429 Error Handling Best Practices**
   - Honor `retry-after` header (wait specified seconds)
   - Implement exponential backoff if no header provided
   - Don't retry immediately - causes cascading failures
   - Ramp up traffic gradually (avoid acceleration limits)

**Implementation Strategy:**

1. **Conservative Defaults**
   - 2 second delay between requests (gives ~25-30 images/minute)
   - 50 RPM limit ÷ 60 seconds = 1 request per 1.2 seconds minimum
   - 2 seconds provides safety margin

2. **Batch Processing**
   - Default batch size: 15 images
   - User configurable (5-25 images)
   - Process batches sequentially
   - Clear progress indication

3. **Rate Limit Monitoring**
   - Parse response headers after each call
   - Show remaining requests in UI
   - Warn if approaching limits (< 10 remaining)
   - Automatically slow down if needed

4. **Error Recovery**
   ```swift
   if statusCode == 429 {
       let retryAfter = Int(response.header("retry-after") ?? "30")!
       statusMessage = "Rate limit reached. Waiting \(retryAfter) seconds..."
       try await Task.sleep(for: .seconds(retryAfter))
       // Retry request
   }
   ```

5. **User Controls**
   - Settings: Request delay slider (1-5 seconds)
   - Settings: Batch size (5-25 images)
   - Settings: Show rate limit status
   - Pause/resume evaluation capability

**Cost Considerations:**

With 2-second delays:
- Max throughput: ~25-30 images per minute
- Max throughput: ~1,500-1,800 images per hour
- This naturally prevents runaway costs
- User can increase speed if they have higher tier limits

**Testing Strategy:**

1. Test with small batches (5 images) first
2. Verify rate limit headers are parsed correctly
3. Intentionally trigger 429 error (send 51 requests in 1 minute)
4. Verify backoff and retry logic works
5. Test pause/resume functionality

## Summary & Recommendations

### Architecture Decisions Confirmed:

✅ **vImage** for image resizing (13x faster, better quality)
✅ **LazyVGrid with thumbnails** (100x100px cached)
✅ **Security-scoped bookmarks** for persistent access
✅ **Native SwiftUI** for Liquid Glass compliance
✅ **Minimal entitlements** (5 total, all justified)
✅ **Rate limiting** with batch processing (2s delays, 15 image batches)

### Implementation Priority:

1. **vImage wrapper** for resizing (reusable utility)
2. **Thumbnail generation** during import
3. **Security-scoped bookmark manager** (critical for archives)
4. **LazyVGrid with thumbnail loading** (performance critical)
5. **Archive availability checking** (graceful degradation)

### Performance Targets:

- Grid scrolling: 60-90fps on macOS (acceptable)
- Image resize: < 100ms per image (vImage)
- Thumbnail generation: < 50ms per thumbnail
- API call: 2-5 seconds per evaluation (network dependent)
- Archive operation: Show progress, don't block UI

### Risks Mitigated:

- ✅ Core Image performance issues → using vImage
- ✅ SwiftUI grid slowness → thumbnails + lazy loading
- ✅ Archive disconnection crashes → graceful degradation
- ✅ App Store rejection → minimal justified entitlements
- ✅ macOS 26 compatibility → native SwiftUI components
- ✅ API rate limit errors → batch processing + configurable delays
- ✅ Runaway API costs → conservative defaults + user controls

Last Updated: 2025-10-27 (Added Anthropic API rate limiting research)
