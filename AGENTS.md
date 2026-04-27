# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) and gemini when working with code in this repository. Read Serena's initial Instructions for more details.

## Project Overview

CATIE-TV is a tvOS application that displays digital signage content including weather, events, status indicators, carousels, and streaming content. It connects to a server via WebSocket for real-time updates and supports both landscape and portrait orientations with custom UI layouts.

## MCP

- Use swift mcp as much as possible

## Build and Development Commands

### Prerequisites

- Xcode 16.3.0+
- Swift 5.9.2
- SwiftFormat (`brew install swiftformat`)

- Periphery (`brew install periphery`)

### Build Commands

```bash
# Format Swift code
swiftformat .

# Find unused code
periphery scan
```

### Project Structure

- **CATIE-TV.xcodeproj**: Main Xcode project (no workspace file)
- **Target**: CATIE-TV (tvOS app)
- **Dependencies**: Managed via Swift Package Manager
  - Starscream v4.0.8 (WebSocket client)
  - CocoaLumberjack/Swift v3.8.5 (logging)

## Architecture Overview

### Core Architecture Pattern

The app follows an MVP (Model-View-Presenter) pattern with additional view models for SwiftUI components:

- **Model Layer**: Core Data entities, data handlers, and business logic models
- **Presenter Layer**: View controllers that manage UI logic and coordinate between models and views
- **View Layer**: Storyboard-based UIKit views (landscape) and SwiftUI views (portrait)

### Key Components

#### 1. Data Management

- **Core Data**: Primary persistence layer with entities for Weather, Events, StatusIndicators, etc.
- **DataHandler.swift**: Centralized data operations and Core Data management
- **Thread-Safe Globals**: Custom wrapper for managing shared state across threads

#### 2. Network Communication

- **SocketConnection.swift**: WebSocket client using Starscream for real-time server communication
- **Registration**: Device registration system with server
- **Data Models**: JSON parsing and API response models (WeatherModel, EventsModel, etc.)

#### 3. UI Architecture

- **Landscape Mode**: UIKit-based with Main.storyboard, collection views, and custom cells
- **Portrait Mode**: SwiftUI-based with PortraitView as root and modular sub-views
- **MainScreenViewController**: Primary controller coordinating data flow between models and views
- **Combine Publishers**: Used for reactive data binding between MainViewController and SwiftUI views

#### 4. Media and Content

- **Carousel Management**: Image carousel with rotation and custom sizing
- **Audio Player**: Radio streaming and narration audio playback
- **Dynamic Content**: Server-driven UI updates with custom themes and layouts
- **Status Indicators**: Character limit of 45 characters for both title and description fields

#### 5. Carousel Aspect Ratios

- **UI Type 1**: 16:9 (Landscape)
- **UI Type 2**: 16:9 (Landscape)
- **UI Type 3**: 9:16 (Portrait)
- **UI Type 4**: 1:1  (Portrait)
- **UI Type 5**: 21:9 (Landscape)
- **UI Type 6**: 9:16 (Portrait)

### Critical Patterns

#### Global State Management

```swift
// Thread-safe global variables using ThreadSafeGlobals wrapper
var communicationStatus: String? {
    get { ThreadSafeGlobals.communicationStatus }
    set { ThreadSafeGlobals.communicationStatus = newValue }
}
```

#### SwiftUI Data Binding

```swift
// Combine publishers for reactive updates
let temperatureSubject = CurrentValueSubject<String?, Never>(nil)
let eventListArraySubject = CurrentValueSubject<[(String, String, String, String, String, Bool)], Never>([])
```

#### Error Handling

- Uses SwiftTryCatch for Objective-C style exception handling
- CocoaLumberjack for structured logging with DDLogDebug statements
- Graceful fallbacks for network and data loading failures

## File Structure Details

### Core Directories

- **CATIE-TV/**: Main application source code
  - **Presenter/**: View controllers and presentation logic
    - **Utils/**: Utility classes (ThreadSafeDictionary, SwiftTryCatch, RegistrationTapHandler)
  - **Model/**: Data models and business logic
    - **CoreData/**: Core Data entities and generated classes
  - **View/**: UI components
    - **Landscape/**: UIKit-based landscape views and storyboards
    - **Portrait/**: SwiftUI-based portrait views
  - **Utils/**: Application utilities (DataFetchingUtility, ScrollDurationCalculator, ThreadSafeGlobals)
  - **Assets/**: Images, colors, fonts, and app icons

### Configuration Files

- **.swift-version**: Swift version (5.9.2)
- **.swiftformat**: SwiftFormat configuration
- **.swiftlint.yml**: SwiftLint rules
- **.periphery.yml**: Periphery unused code detection settings
- **fastlane/**: Deployment automation scripts

## Development Guidelines

### Code Formatting

- SwiftFormat should be run before commits, use `swiftformat` command
- Follow existing patterns for logging and error handling

### Testing

- UI tests are located in CATIE-TVUITests/
- Run tests through Xcode or use `xcodebuild test` commands
- Portrait view has dedicated UI tests in PortraitViewUITests.swift
- Main UI tests in CATIE_TVUITests.swift

### Custom Fonts

The app includes custom fonts in Assets/Fonts/:

- **Poppins**: Regular, Medium, Bold variants
- **Roboto**: Regular, Medium, Light variants

### Deployment

- **FastLane Integration**: Automated build and TestFlight deployment
- **App Store Connect**: Configured with API key for automated uploads
- **TestFlight Groups**: Beta and Release Candidate testing groups
- **Version Management**: Follow semantic versioning (e.g., 25.06.0-1.0.0)

### Debugging

- Extensive logging throughout the application using DDLogDebug
- Socket connection has detailed state logging for troubleshooting
- Network reachability monitoring for connection issues

## UI Type Data Fetching Rules & Timer Management

The app optimizes data fetching and timer management based on UI type to prevent unnecessary network requests and processing for hidden components:

### Data Fetching Requirements by UI Type

| UI Type | Layout    | Weather   | Events    | Status Indicators | Radio Data                  | Description                                       |
|---------|-----------|-----------|-----------|-------------------|-----------------------------|---------------------------------------------------|
| **1**   | Landscape | ✅ Always | ✅ Always | ✅ Always         | ✅ Always                   | Full content layout                               |
| **2**   | Landscape | ✅ Always | ❌ Skip   | ✅ Always         | ✅ Always                   | No events / weather scroll, shows time date layout|
| **3**   | Portrait  | ✅ Always | ✅ Always | ✅ Always         | ✅ Always                   | Full content portrait                             |
| **4**   | Portrait  | ✅ Always | ❌ Skip   | ❌ Skip           | ✅ Always                   | Full screen portrait image                        |
| **5**   | Landscape | ✅ Always | ❌ Skip   | ❌ Skip           | ⚠️ Only if `tvRadioFlag=1`  | Carousel-only wide                                |
| **6**   | Portrait  | ✅ Always | ❌ Skip   | ❌ Skip           | ⚠️ Only if `tvRadioFlag=1`  | Carousel-only padded                              |

### Timer Management Rules

The following timers should be conditionally managed based on UI type:

#### Event-Related Timers

- **Event Animation Timer** (15s interval): Only active for landscape UI type 1
- **Ongoing Event Schedule Timer**: Only active for UI types 1, 3 (events are not shown in UI types 2, 4)

#### Status Indicator Timers  

- **Status Animation Timer** (10s interval): Only active for landscape UI types 1,2 (portrait UI type 3 uses own logic, UI type 4 has no status indicators), 5 and 6 (no status indicators)

#### Weather Timers

- **Weather Display Timer** (10s interval): Active for UI type 1 (only when no events present), skip for UI types 2-6 (UI type 3 uses portrait logic, others use basic display only)

#### Layout-Specific Timers

- **Scrollbar Timer** (4s interval): Only active for landscape layouts (UI types 1, 2, 5) - portrait modes use separate logic

#### Radio-Related Timers

- **Radio Resume Timer** (60s interval): Active for UI types 1-4 (always), UI types 5-6 (only if `tvRadioFlag=1`)

#### Always Active Timers

- **Carousel Timer**: Dynamic intervals based on content (audio duration, server config, defaults) - always active regardless of UI type
- **Time Timer**: Always active to update date/time display in top right corner across all UI types
- **SARA Alert Flash Timer**: Always active when SARA alerts are present

### Implementation Notes

- **DataFetchingUtility.shouldFetchData()** determines what data to fetch based on UI type
- **Radio Flag Logic**: For UI types 5-6, radio data/functionality depends on `tvRadioFlag` (1=show, 0=hide)
- **Always Fetched**: Carousel images, site logo, scrolling messages, SARA alerts, and **Clock API** are fetched for all UI types
- **Clock API**: Determines whether to display full-screen clock overlay and should always be checked regardless of UI type
- **Timer Efficiency**: Unnecessary timers should be stopped to conserve resources and prevent unwanted UI updates

### Weather View Visibility Rules

The detailed weather views are conditionally shown/hidden based on UI type:

#### Detailed Weather Views

- **detailedWeatherView**: Shows current weather details (temperature, feels like, pressure, humidity, etc.)
- **fourDayWeatherView**: Shows 4-day weather forecast

#### Visibility by UI Type

| UI Type | detailedWeatherView | fourDayWeatherView | Description |
|---------|--------------------|--------------------|-------------|
| **1**   | ✅ Conditional      | ✅ Conditional      | Shows when no events present, alternates between detailed/forecast |
| **2**   | ❌ Always Hidden    | ❌ Always Hidden    | Clock-only layout, no detailed weather |
| **3**   | ❌ Always Hidden    | ❌ Always Hidden    | Portrait mode uses different weather display |
| **4**   | ❌ Always Hidden    | ❌ Always Hidden    | Full-screen image, minimal weather in header only |
| **5**   | ❌ Always Hidden    | ❌ Always Hidden    | Carousel-focused, basic weather in header only |
| **6**   | ❌ Always Hidden    | ❌ Always Hidden    | Portrait carousel, basic weather in header only |

#### Implementation Details

- **UI Type 1**: Weather views toggle between detailed/forecast when no events are present
- **All Other Types**: Weather views are always hidden, only basic weather shown in header
- **Weather Data Processing**:
  - Basic weather data (temperature, location, weather icon) is fetched and processed for ALL UI types
  - Header weather display is updated across all UI types for consistent weather information
  - Weather data publishers are updated for SwiftUI portrait components (UI Types 3, 4)
- **Weather Table Management**:
  - Detailed weather tables (`detailedWeatherTable`, `fourDayWeatherTable`) are only reloaded for UI Type 1
  - UI Types 2, 3, 4, 5, 6 skip table reloading since they don't use landscape weather table views
  - Portrait modes (UI Types 3, 4) use SwiftUI weather components instead of landscape tables
- **Timer Integration**: Weather display timer only active for UI type 1 when no events present

### Layout Switching and Constraint Management

The app implements dynamic layout switching for carousel and SARA alert components based on UI type:

#### Carousel Layout Switching

- **UI Types 1, 2**: Normal layout with proper margins for side content (events, status indicators)
- **UI Types 5, 6**: Full-width layout expanding to use maximum available space
- **Implementation**: Uses comprehensive constraint deactivation before applying new constraints to prevent conflicts

#### SARA Alert Layout Switching  

- **UI Types 1, 2**: Normal layout positioned in left side with standard margins
- **UI Types 5, 6**: Full-width layout expanding to match carousel behavior
- **Implementation**: Mirrors carousel constraint management pattern with comprehensive deactivation

#### Constraint Management Pattern

- **Setup Phase**: Capture original Interface Builder constraints before any modifications
- **Layout Switch**: Deactivate ALL existing constraints from all possible superviews before applying new ones
- **Restoration**: Restore original storyboard constraints when switching back to normal layouts
- **Comprehensive Search**: Constraints are found and managed across centerView, superview, and main view hierarchies

This ensures smooth layout transitions without "Unable to simultaneously satisfy constraints" errors.

## Advertisement Carousel Integration

The app supports advertisement slides integrated with normal carousel content for enhanced monetization and promotional capabilities.

### Carousel Slide Types

The carousel system supports three distinct slide types:

1. **carouselType: 0** - Normal carousel slides
   - Uses global `slotTime` from carousel response
   - Rotates as part of normal slide sequence

2. **carouselType: 1** - Ingage slides
   - Uses per-slide custom `timeout` from `slideDetails`
   - Treated as normal slides in rotation logic
   - Allows different display duration for each slide

3. **carouselType: 2** - Advertisement slides
   - Uses global `slotTime` from carousel response
   - Inserted at 4:1 ratio (1 ad after every 4 normal slides)

### Advertisement Slide Structure

Advertisement slides follow the same JSON structure as normal slides but are distinguished by:

- **carouselType**: `2` (indicates advertisement slide)
- **Data Source**: Same API endpoint and database structure as normal slides
- **Rendering**: Uses identical image loading and display logic

### Integration Pattern

- **Frequency**: 1 advertisement slide shown after every 4 normal slides
- **Normal Slide Loop**: Continues indefinitely in original order (includes both type 0 and type 1 slides)
- **Advertisement Insertion**: Dynamically inserted between normal slides without affecting the base sequence
- **Controller Logic**: Splits slides into two separate arrays (normal and advertisement) for independent management
- **State Tracking**: Uses `normalSlideCount`, `normalIndex`, and `advertisementIndex` to manage rotation

### Implementation Details for carousel

1. **Data Separation**: Parse carousel response to separate normal (`carouselType: 0, 1`) and advertisement (`carouselType: 2`) slides
2. **Display Logic**: Maintain separate tracking for normal slide progression and advertisement insertion points via `advanceToNextSlideWithAdvertisements()`
3. **Timing**: Each slide type uses its stored `slotTime` value:
   - Type 0 & 2: Global carousel `slotTime`
   - Type 1: Individual slide `timeout`
4. **Audio Support**: All slide types support audio narration with `audioFlag` and `audioPath` properties
5. **UI Compatibility**: Works across all UI types (1-6) following existing carousel display rules
6. **Offline Mode**: Advertisement rotation logic is preserved when network is unavailable
