# Nature Image Evaluation

AI-powered photography evaluation tool for macOS using Anthropic's Claude API and advanced Core Image analysis.

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
- **Vision Framework**: Advanced image understanding and face detection
- **Security-Scoped Bookmarks**: Persistent sandboxed file access

### Key Components
- **EvaluationManager**: Central orchestrator for batch evaluations
- **TechnicalAnalyzer**: Core Image-based sharpness, noise, and quality metrics
- **AnthropicAPIService**: Claude API integration with retry logic
- **PromptLoader**: Dynamic prompt management supporting versioning
- **ImageProcessor**: High-performance image resizing (max 1568px)

## Project Status

### ✅ Completed Features
- Full AI evaluation pipeline with Claude 3.5 Sonnet
- Technical image analysis (sharpness, noise, contrast)
- Batch evaluation with queue management
- Gallery view with sorting and filtering
- Detailed evaluation view with all metrics
- Commercial metadata generation (SEO titles, keywords)
- Visual evaluation status indicators
- Persistent selection during evaluation
- Core Data storage with evaluation history
- Security-scoped bookmark file access
- Intelligent rate limiting and error handling

### 🚧 In Development
- Collection/folder management UI
- Sidebar navigation with smart folders
- Saliency maps for composition analysis

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

### Keyboard Shortcuts
- **⌘I**: Import images
- **⌘E**: Evaluate selected images
- **⌘A**: Select all
- **⌘D**: Delete selected
- **Space**: Quick look at selected image

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
