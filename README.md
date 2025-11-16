# Nature Image Evaluation

AI-powered photography evaluation tool for macOS using Anthropic's Claude API and advanced Core Image analysis.

## 🆕 Recent Updates

### November 2025
- **Saliency Analysis**: Vision Framework integration for composition pattern detection
- **Smart Folders**: Create dynamic collections with custom criteria
- **Folder Monitoring**: Automatic image discovery with persistent folder access
- **Sort Preferences**: Per-folder sort order and direction persistence
- **Thumbnail System**: Efficient generation and caching for gallery views
- **Data Storage**: Comprehensive evaluation history with saliency maps

## Overview

Nature Image Evaluation helps photographers analyze and score their images based on professional criteria including composition, technical quality, commercial potential, and artistic merit. The app combines AI evaluation with technical image analysis to provide comprehensive feedback on your photography.

## Screenshots

<details>
<summary>View Screenshots</summary>

- Gallery view with evaluation badges and scores
- Detailed evaluation breakdown with AI reasoning
- Visual status indicators during batch evaluation
- Settings panel for API configuration

</details>

## Features

### Core Functionality
- **AI-Powered Evaluation**: Uses Claude 3.5 Sonnet for intelligent image analysis
- **Technical Analysis**: Core Image-based sharpness, noise, and contrast evaluation
- **Saliency Analysis**: Vision Framework-based composition and attention mapping
- **Multi-Criteria Scoring**:
  - Composition (30% weight)
  - Technical Quality (25% weight)
  - Commercial Sellability (25% weight)
  - Artistic Merit (20% weight)
- **Batch Processing**: Queue-based evaluation with visual status indicators
- **Smart Organization**: Sort by date added, evaluation date, overall score, or sellability
- **Commercial Metadata**: SEO-optimized titles, descriptions, keywords for stock photography

### User Experience
- **Visual Evaluation Status**: See which images are being evaluated, queued, or completed
- **Persistent Selection**: Selected images remain highlighted during evaluation
- **Gallery View**: Clean grid layout with score badges and placement indicators
- **Detailed View**: Full evaluation breakdown with technical metrics and AI reasoning
- **Progress Tracking**: Real-time batch progress with per-image status
- **Smart Folders**: Dynamic collections based on customizable criteria
- **Per-Folder Preferences**: Each folder remembers its sort order and direction
- **Saliency Overlays**: Visual heatmaps showing areas of visual attention

## Requirements

- macOS 15.0 (Sequoia) or later
- Anthropic Claude API key
- Metal-capable GPU recommended for optimal performance
- Xcode 16.0+ for development

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/kmichels/nature-image-evaluation.git
   ```
2. Open `Nature Image Evaluation.xcodeproj` in Xcode
3. Build and run (⌘R)
4. Enter your Anthropic API key in Settings
5. Import images via drag & drop or the Import button
6. Select images and click "Evaluate Selected" to begin analysis

## Technical Architecture

### Core Technologies
- **SwiftUI + Observation**: Modern declarative UI with @Observable pattern
- **Core Data**: SQLite-backed persistent storage with evaluation history
- **Core Image + Metal**: GPU-accelerated technical image analysis
- **Vision Framework**: Saliency detection and composition analysis
- **Security-Scoped Bookmarks**: Persistent sandboxed file access

### Key Components
- **EvaluationManager**: Central orchestrator for batch evaluations
- **TechnicalAnalyzer**: Core Image-based sharpness, noise, and quality metrics
- **SaliencyAnalyzer**: Vision Framework-based attention and composition analysis
- **SmartFolderManager**: Dynamic collection management with custom criteria
- **ThumbnailGenerator**: Efficient thumbnail generation and caching
- **AnthropicAPIService**: Claude API integration with retry logic
- **PromptLoader**: Dynamic prompt management supporting versioning
- **ImageProcessor**: High-performance image resizing (max 1568px)

## Project Status

### ✅ Completed Features
- Full AI evaluation pipeline with Claude 3.5 Sonnet
- Technical image analysis (sharpness, noise, contrast)
- Saliency analysis with composition pattern detection
- Smart folders with dynamic criteria-based collections
- Folder monitoring and automatic image discovery
- Per-folder sort preferences (order and direction)
- Batch evaluation with queue management
- Gallery view with sorting and filtering
- Detailed evaluation view with all metrics
- Commercial metadata generation (SEO titles, keywords)
- Visual evaluation status indicators
- Persistent selection during evaluation
- Core Data storage with evaluation history and saliency data
- Efficient thumbnail generation and caching
- Security-scoped bookmark file access
- Intelligent rate limiting and error handling

### 🚧 In Development
- Thematic grouping using Vision Framework
- Advanced composition correlation analysis
- Smart crop suggestions based on saliency

### 📋 Planned Features
- [Image culling mode](https://github.com/kmichels/nature-image-evaluation/issues/1) for similar photo selection
- Export functionality for evaluated images
- Evaluation comparison across prompt versions
- Custom evaluation criteria templates
- Integration with photo editing workflows

## Usage Examples

### Basic Workflow
1. **Import**: Drag images into the gallery or use Import button
2. **Select**: Click images to select (blue checkmark appears)
3. **Evaluate**: Click "Evaluate Selected" to start AI analysis
4. **Review**: Check scores in badges (Artistic/Commercial ratings)
5. **Detail**: Double-click any image for full evaluation details

### Understanding Scores
- **A** (Artistic): Creative and aesthetic merit (1-10)
- **C** (Commercial): Market potential and sellability (1-10)
- **Placement**: PORTFOLIO (artistic), STORE (commercial), BOTH, or ARCHIVE
- **Green tag**: Image has commercial metadata (SEO-optimized)

### Smart Folders
Create dynamic collections that automatically update based on criteria:
- **Portfolio Quality**: Images scoring 8+ overall
- **Needs Review**: Images not yet evaluated
- **High Commercial Value**: Images with high sellability scores
- **Custom Criteria**: Build your own with multiple rules and conditions

### Keyboard Shortcuts
- **⌘I**: Import images
- **⌘E**: Evaluate selected images
- **⌘A**: Select all
- **⌘D**: Delete selected
- **Space**: Quick look at selected image

## Data Storage & Analysis

### Stored Evaluation Data
Each evaluation stores comprehensive metrics:
- **AI Scores**: Composition, quality, sellability, and artistic scores
- **Technical Metrics**: Sharpness, blur type/amount, noise, contrast
- **Saliency Data**: Compressed attention maps and composition patterns
- **Commercial Metadata**: SEO-optimized titles, descriptions, keywords
- **Evaluation History**: Track score changes over time

### Composition Analysis
Saliency data enables advanced insights:
- **Pattern Detection**: Center, rule of thirds, scattered, off-center
- **Visual Weight**: Center of mass and highest attention points
- **Future Correlation**: Track which patterns score highest
- **Smart Suggestions**: Crop recommendations based on attention areas

## Configuration

### Settings
- **API Key**: Stored securely in Keychain
- **Image Resolution**: Default 1568px (configurable 512-2048)
- **Request Delay**: 2-10 seconds between API calls
- **Batch Size**: 5-50 images per batch

### Rate Limiting
- Intelligent queue management with visual feedback
- Automatic retry with exponential backoff on errors
- Real-time progress tracking
- Graceful handling of API rate limits

## Privacy & Security

- **Sandboxed**: Minimal system access, user-granted permissions only
- **Secure Storage**: API keys in Keychain, never in files or logs
- **Local Processing**: All data stored locally, no cloud storage
- **Transparent**: Clear disclosure when images sent to Claude API
- **No Tracking**: No analytics, telemetry, or user tracking

## Troubleshooting

### Common Issues
- **"API Key Invalid"**: Check your Anthropic API key in Settings
- **"Rate Limited"**: Wait a moment, the app will automatically retry
- **Images not importing**: Ensure files are valid image formats (JPEG, PNG, HEIC, etc.)
- **Evaluation fails**: Check console for detailed error messages

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Follow existing code style
4. Add tests for new functionality
5. Submit a pull request

## License

Copyright © 2025 Konrad Michels. All rights reserved.

## Acknowledgments

- Anthropic for the Claude API
- Apple for SwiftUI and Core Image frameworks
- The photography community for feedback and suggestions
