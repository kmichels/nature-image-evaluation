# Thematic Grouping Feature Specification

## Overview
Leverage Vision Framework and Core Image metadata to automatically group and analyze photographs thematically, helping photographers understand their style, discover patterns, and organize their portfolio more effectively.

## Data Sources

### Vision Framework Capabilities
- **Scene Classification**: Beach, mountain, forest, urban, indoor, outdoor
- **Object Detection**: Animals, vehicles, buildings, people, plants
- **Face Detection**: Number of faces, portrait vs landscape photography
- **Landmark Recognition**: Famous places and monuments
- **Text Detection**: Signs, documents, text in images
- **Image Feature Vectors**: High-dimensional embeddings for similarity matching
- **Saliency Analysis**: Already implemented, identifies visually important regions

### Core Image/EXIF Metadata
- **Time of Day**: Golden hour, blue hour, night, midday (from EXIF timestamp)
- **Season**: Derived from date and potentially color analysis
- **Camera Settings**:
  - Shutter speed (long exposures, action shots)
  - Aperture (depth of field, bokeh shots)
  - ISO (low light photography)
  - Focal length (wide angle, telephoto, macro)
- **Color Analysis**:
  - Dominant colors
  - Color temperature (warm/cool)
  - Saturation levels (vibrant/muted)
  - Monochrome detection
- **Location Data**: GPS coordinates for geographic grouping

## Feature Implementation Ideas

### 1. Automatic Smart Collections
Automatically create and maintain collections based on detected themes:

#### Subject-Based Collections
- Wildlife Photography (animals detected)
- Portrait Photography (faces detected)
- Landscape Photography (no faces, outdoor scenes)
- Architecture (buildings detected)
- Street Photography (urban scenes with people)
- Nature Macro (close focal length, nature subjects)

#### Technical Collections
- Long Exposures (shutter speed > 1 second)
- Night Photography (high ISO, dark scenes)
- Black & White (low saturation)
- Golden Hour (time-based from EXIF)
- High Key / Low Key (histogram analysis)

#### Style Collections
- Minimalist (low object count, simple composition)
- Busy/Complex (high object count, complex scenes)
- Symmetrical Compositions (using saliency analysis)
- Rule of Thirds (saliency region placement)

### 2. Similar Image Discovery
Find images similar to a selected photo based on:
- Visual similarity (Vision feature vectors)
- Color palette matching
- Composition similarity (saliency patterns)
- Subject matter (same detected objects/scenes)
- Technical settings (similar camera parameters)

### 3. Photography Analytics Dashboard
Provide insights into shooting patterns and preferences:

#### Subject Analytics
- Most photographed subjects over time
- Subject diversity score
- Unexplored subjects (compared to typical photographer portfolio)

#### Technical Analytics
- Preferred camera settings distribution
- Most successful settings (correlated with high scores)
- Technical variety score

#### Temporal Analytics
- Preferred shooting times
- Seasonal patterns
- Activity over time (images per month/season)

#### Geographic Analytics
- Heat map of shooting locations
- Most productive locations (images and scores)
- Travel photography detection

### 4. Smart Suggestions Engine
Proactive recommendations based on patterns:

#### Shooting Suggestions
- "You haven't photographed wildlife in 3 months"
- "Your sunset photos consistently score highest"
- "Try more vertical compositions - 90% of your shots are horizontal"
- "Your macro shots have improved 20% this quarter"

#### Portfolio Gaps
- "Your portfolio lacks urban/street photography"
- "Consider adding more black & white work"
- "No winter scenes in your collection"

#### Technical Experiments
- "Try longer exposures - your sharp shots score well"
- "Your portraits at f/2.8 outperform those at f/5.6"
- "Golden hour yields your best landscapes"

## Technical Architecture

### Data Model Additions

```swift
ImageAnalysis (Entity)
├── id: UUID
├── imageEvaluation: ImageEvaluation (one-to-one)
├── analysisDate: Date
├── visionVersion: String

// Scene & Object Detection
├── primaryScene: String
├── sceneConfidences: Transformable<[String: Float]>
├── detectedObjects: Transformable<[String]>
├── objectBoundingBoxes: Transformable<[CGRect]>

// Faces & People
├── faceCount: Int16
├── faceLocations: Transformable<[CGRect]>

// Visual Features
├── featureVector: Data (Vision embedding)
├── dominantColors: Transformable<[String]>
├── colorDistribution: Transformable<[String: Float]>
├── averageSaturation: Float
├── averageBrightness: Float
├── isMonochrome: Bool

// Saliency
├── saliencyMapData: Data (compressed)
├── saliencyHotspots: Transformable<[CGRect]>
├── compositionPattern: String (center/thirds/diagonal/etc)

// Technical Metadata
├── shutterSpeed: Float
├── aperture: Float
├── iso: Int32
├── focalLength: Float
├── captureTime: Date
├── timeOfDay: String (golden/blue/night/day)
├── season: String

// Location
├── latitude: Double
├── longitude: Double
├── locationName: String
└── country: String

ThematicGroup (Entity)
├── id: UUID
├── name: String
├── type: String (auto/manual)
├── criteria: String (JSON rules)
├── memberImages: [ImageEvaluation] (many-to-many)
├── dateCreated: Date
├── dateUpdated: Date
└── iconName: String
```

### Processing Pipeline

1. **On Image Import**:
   - Run Vision analysis (scenes, objects, faces)
   - Extract EXIF metadata
   - Generate feature embeddings
   - Analyze colors and composition
   - Store in ImageAnalysis entity

2. **Background Processing**:
   - Periodically update thematic groups
   - Calculate similarity scores
   - Generate suggestions
   - Update analytics

3. **On-Demand Processing**:
   - Similar image search
   - Deep composition analysis
   - Detailed comparisons

## Implementation Phases

### Phase 1: Foundation (Current Focus)
- Store saliency data in Core Data
- Create ImageAnalysis entity
- Basic Vision framework integration
- Store scene classification results

### Phase 2: Core Features
- Automatic thematic collections
- Basic similarity search
- Color and composition analysis
- EXIF metadata extraction

### Phase 3: Advanced Features
- Photography analytics dashboard
- Smart suggestions engine
- Geographic visualization
- Trend analysis over time

### Phase 4: Intelligence Layer
- Machine learning for personalized grouping
- Style transfer suggestions
- Predictive scoring based on themes
- Portfolio optimization recommendations

## User Interface Concepts

### Explore View
- Grid of thematic groups with preview thumbnails
- Filter by theme type (subject/technical/style)
- Quick access to similar images
- Visual statistics and charts

### Analytics View
- Dashboard with shooting statistics
- Temporal and geographic visualizations
- Progress tracking
- Comparative analysis with goals

### Smart Suggestions Panel
- Contextual recommendations
- Gap analysis visualization
- Experiment ideas
- Achievement tracking

## Privacy Considerations
- All analysis happens locally on device
- No data sent to external services
- User control over which analyses to run
- Option to disable automatic grouping

## Performance Considerations
- Batch processing during idle time
- Incremental analysis updates
- Efficient caching of results
- Background queue management
- Lazy loading of analysis data

## Future Enhancements
- Integration with photo editing workflows
- Export themed collections
- Social sharing of analytics
- Comparison with photographer community averages
- AI-powered composition suggestions
- Style matching with famous photographers