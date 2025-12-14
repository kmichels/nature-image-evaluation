# Archived UI Components

This folder contains UI components that were archived during the December 2025 UI rebuild. These files are preserved for reference but are no longer actively used in the application.

## Why These Files Were Archived

The application experienced fundamental architectural issues with the NSViewRepresentable approach for collection views, including:
- Scroll position jumping when selecting items
- 60+ unnecessary view updates per interaction
- View recreation instead of updates despite stable IDs
- Bidirectional binding feedback loops

After extensive debugging, we decided to rebuild the UI layer using pure SwiftUI components.

## Archived Files

### UI_Components/
- **NativeFolderCollectionView.swift**: NSCollectionView wrapper for folder-based galleries
- **NativeImageCollectionView.swift**: NSCollectionView wrapper for evaluated images
- **SharedImageCollectionViewItem.swift**: Shared collection view item for consistent display
- **FolderGalleryView.swift**: Main folder browsing view using NativeFolderCollectionView
- **GalleryView.swift**: Quick Analysis gallery using NativeImageCollectionView

## What These Files Contain

### Useful Reference Material
- Selection handling patterns (single, multiple, range)
- Thumbnail loading and caching logic
- Score display formatting
- Context menu implementations
- Double-click handling
- Keyboard navigation concepts

### Problems to Avoid
- NSViewRepresentable with complex state
- Bidirectional bindings between SwiftUI and AppKit
- Manual scroll position management
- View recreation on state changes
- Excessive coordinator complexity

## Status

These files are **archived** and **not in use**. The new implementation uses pure SwiftUI components as documented in `Docs/UI_Rebuild_Plan.md`.

If you need to reference how a feature was implemented, these files can provide guidance, but be aware they contain the architectural issues that led to the rebuild.

## See Also

- `Docs/UI_Rebuild_Plan.md`: Complete rebuild strategy and new architecture
- New `Browser/` module: Fresh implementation (once created)

---

*Archived: December 2025*
*Reason: Architectural rebuild for better SwiftUI integration*