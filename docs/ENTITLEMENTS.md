# Entitlements Documentation

App: Nature Image Evaluation
Target: macOS 26 Tahoe (minimum macOS 15 Sequoia)
Distribution: App Store

## Required Entitlements

### Nature_Image_Evaluation.entitlements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Enable App Sandbox (Required for App Store) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Read-only access to user-selected files -->
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>

    <!-- Read-write access to user-selected files and folders -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>

    <!-- Security-scoped bookmarks for persistent access -->
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>

    <!-- Outgoing network connections (Anthropic API) -->
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

## Entitlement Justifications (for App Store Review)

### 1. com.apple.security.app-sandbox
**Purpose**: Enables App Sandbox for security and privacy
**Justification**: Required for all Mac App Store applications
**User Benefit**: Protects user data by restricting app access to only necessary resources

### 2. com.apple.security.files.user-selected.read-only
**Purpose**: Read access to user-selected image files
**Justification**: App evaluates images selected by user via NSOpenPanel
**User Control**: User explicitly selects which images to evaluate
**Usage**:
- Read original images for evaluation
- Access metadata (dimensions, EXIF)
- Generate processed copies for API submission

### 3. com.apple.security.files.user-selected.read-write
**Purpose**: Write access to user-selected folders (archive locations)
**Justification**: App archives processed images to user-selected external/NAS locations
**User Control**: User explicitly selects archive destinations
**Usage**:
- Write processed images to archive folders
- Copy images to/from archive locations
- Manage archived image files

### 4. com.apple.security.files.bookmarks.app-scope
**Purpose**: Persistent access to user-selected files/folders across app launches
**Justification**: Maintain access to original images and archive locations without re-prompting user
**User Control**: User granted access via NSOpenPanel; can revoke by deleting app data
**Usage**:
- Remember original image locations
- Maintain archive location access
- Access images for re-evaluation

### 5. com.apple.security.network.client
**Purpose**: Outgoing HTTPS connections
**Justification**: Send images and prompts to Anthropic Claude API for evaluation
**User Control**: User provides API key; can disable by removing key
**Usage**:
- POST requests to api.anthropic.com
- Upload base64-encoded images
- Receive JSON evaluation responses
**Privacy**: Images sent to third-party API (Anthropic); disclosed in privacy policy

## Entitlements NOT Requested

### Why We Don't Need Full Disk Access
❌ **NOT NEEDED**: `com.apple.security.temporary-exception.files.absolute-path.read-write`

**Reason**: User explicitly selects files/folders via NSOpenPanel
- App only accesses user-selected items
- No need for unrestricted file system access
- More secure and privacy-friendly
- Passes App Store review more easily

### Why We Don't Need Other Network Entitlements
❌ **NOT NEEDED**: `com.apple.security.network.server`

**Reason**: App is a client-only application
- No incoming network connections
- No local server needed
- Only makes outgoing HTTPS requests

### Why We Don't Need Device Access
❌ **NOT NEEDED**: Camera, Microphone, USB, Bluetooth, Location

**Reason**: App evaluates existing image files only
- No camera capture needed
- No hardware device interaction
- No location services required

### Why We Don't Need Other Data Access
❌ **NOT NEEDED**: Address Book, Calendar, Photos Library, Music Library

**Reason**: App works with user-selected files only
- No system library integration
- User explicitly selects images via file picker
- More privacy-friendly approach

## App Store Review Strategy

### Compliance Points

1. **Minimal Entitlements**: Only 5 entitlements, all directly necessary for core functionality
2. **User Control**: Every file/folder access explicitly granted by user
3. **No Privacy Invasive**: No camera, contacts, location, or system library access
4. **Documented Purpose**: Clear justification for each entitlement
5. **Privacy Policy**: Disclose third-party API usage (Anthropic)

### Expected Review Questions & Answers

**Q: Why do you need read-write access to user-selected files?**
A: Users can archive processed images to external storage (NAS/SSD) they select. Read-only would prevent this core feature.

**Q: Why do you need bookmarks for persistent access?**
A: Users evaluate hundreds of images over time. Without bookmarks, they would need to re-select archive locations on every app launch.

**Q: What data do you send over the network?**
A: Resized images (max 1568px) and evaluation prompts to Anthropic's Claude API. Users provide their own API key. Disclosed in privacy policy.

**Q: Why not use the Photos library entitlement?**
A: Our users (professional photographers) work with RAW files in their own folder structures, not the Photos library. File picker provides more flexibility.

**Q: Do you store user images in the cloud?**
A: No. All processed images stored locally in Application Support folder or user-selected archive locations. API calls are transient (no cloud storage).

## Implementation Notes

### Security Best Practices

1. **API Key Storage**:
   - Store in macOS Keychain (never in UserDefaults or file)
   - Never log API keys
   - Clear from memory after use

2. **Bookmark Storage**:
   - Store bookmark Data in Core Data
   - Check `isStale` flag on resolution
   - Handle stale/invalid bookmarks gracefully

3. **Network Security**:
   - HTTPS only (TLS 1.2+)
   - Certificate pinning for Anthropic API (optional but recommended)
   - Timeout handling for network failures

4. **File Access**:
   - Always call `startAccessingSecurityScopedResource()`
   - Match with `defer { stopAccessingSecurityScopedResource() }`
   - Handle access denial gracefully

### Testing Checklist

- [ ] App functions without any system folder access
- [ ] NSOpenPanel appears for all file/folder selections
- [ ] Bookmarks persist across app restarts
- [ ] Archive locations accessible after app restart
- [ ] Graceful handling when archive location unavailable
- [ ] Network calls only to api.anthropic.com
- [ ] No crashes when user denies file access
- [ ] API key never logged or exposed

### Privacy Policy Requirements

Must disclose:
- App sends images to third-party API (Anthropic)
- User provides their own API key
- Images not stored by us in cloud
- Local storage only (user's Mac or selected external drives)
- No analytics or tracking

Last Updated: 2025-10-27
