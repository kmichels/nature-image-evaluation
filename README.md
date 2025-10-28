# Nature Image Evaluation

AI-powered nature photography evaluation tool for macOS using Anthropic's Claude API and OpenAI's GPT-4 Vision.

## Overview

Nature Image Evaluation helps photographers analyze and score their nature, landscape, and wildlife images based on professional criteria including composition, technical quality, commercial potential, and artistic merit.

## Features

- **AI-Powered Evaluation**: Send images to Claude or GPT-4 Vision for comprehensive analysis
- **Multi-Criteria Scoring**: Get detailed scores for composition, quality, sellability, and artistic merit
- **Batch Processing**: Evaluate multiple images with intelligent rate limiting
- **Smart Organization**: Sort and filter by scores to find your best work
- **Persistent Storage**: Core Data-backed storage with evaluation history
- **Security-First**: Sandboxed app with minimal entitlements, API keys stored in Keychain

## Requirements

- macOS 15.0 (Sequoia) or later
- macOS 26 Tahoe recommended for best experience
- Anthropic Claude API key or OpenAI API key
- Xcode 26.0 for development

## Setup

1. Clone the repository
2. Open `Nature Image Evaluation.xcodeproj` in Xcode
3. Build and run the app
4. Enter your API key in Settings
5. Start evaluating images!

## Architecture

- **Native SwiftUI**: Modern macOS UI following Apple's HIG
- **Core Data**: Persistent storage for images and evaluations
- **vImage (Accelerate)**: High-performance image resizing
- **Security-Scoped Bookmarks**: Persistent file access across launches
- **Modular API Providers**: Support for Anthropic Claude and OpenAI GPT-4 Vision

## Documentation

See the `docs/` directory for detailed documentation:
- `CLAUDE.md` - AI assistant guidelines and architecture overview
- `TECHNICAL_RESEARCH.md` - Technology decisions and rationale
- `MVP_COMPONENTS.md` - Component specifications and implementation plan
- `ENTITLEMENTS.md` - Security and privacy documentation
- `PROJECT_STRUCTURE.md` - Codebase organization

## Development Status

Currently in active development (MVP phase).

### Completed
- ✅ Architecture design
- ✅ Technology research
- ✅ Project structure setup

### In Progress
- 🔄 Core Data model implementation
- 🔄 Image processing with vImage
- 🔄 API service layer

### Planned
- 📋 UI implementation
- 📋 Rate limiting and batch processing
- 📋 Testing and polish

## Rate Limiting

The app includes intelligent rate limiting to prevent API quota issues:
- Default: 2 seconds between requests
- Batch size: 15 images (configurable)
- Automatic 429 error handling with exponential backoff
- Real-time rate limit status display

## Privacy & Security

- **Sandboxed**: App uses minimal entitlements
- **User Control**: All file access explicitly granted by user
- **Secure Storage**: API keys stored in macOS Keychain
- **No Cloud Storage**: All data stored locally on your Mac
- **Transparent**: Images sent to third-party APIs (disclosed)

## License

Copyright © 2025 Konrad Michels. All rights reserved.

## Contributing

This is a personal project. If you have suggestions or find bugs, please open an issue.

## Acknowledgments

- Anthropic for the Claude API
- OpenAI for GPT-4 Vision API
- Apple for excellent development tools and frameworks
