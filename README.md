# CATIE TV

CATIE TV source code for tvOS

To create a build and upload in TestFlight

## Prerequisite

If you already have these installed, you can skip and go to Step 1.

1. Homebrew
2. FastLane (```brew install fastlane```)

### Step 1

You need to change the app version in the project, to the desired version.

 Example: 25.06.0-1.0.0

### Step 2

To build and deploy tvOS apps (IPA file) for testing, you need to run the following command in the terminal in the root folder of the project.

Run the following command in the terminal in the root folder of the project.

```fastlane beta```

### Step 3

1. Monitor the script and check if tvOS build creation processes are failing.
2. If build creation is failed you need to stop the script using the command (ctrl+z) on macOS and resolve the build issue manually.

Dev Environment
-

```
Processor -  Apple M1
macOS     -  v15.7.5 (Sequoia) 
Xcode     -  v26.2 (17C52)
fastlane  -  v2.231.1
```

3rd party libraries
-

```
Starscream            - v3.1.1
CocoaLumberjack/Swift - v3.8.5
```

## Tools setup

### 1. SwiftFormat

SwiftFormat is a code library and command-line tool for reformatting Swift code.

```bash
brew install swiftformat
```

Github: [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)

### 2. SwiftLint

SwiftLint is a tool to enforce Swift style and conventions, loosely based on GitHub's Swift Style Guide.

```bash
brew install swiftlint
```

Github: [SwiftLint](https://github.com/realm/SwiftLint)

### 3. Periphery

Periphery is a tool to discover unused code in Swift projects.

```bash
brew install periphery
```

Github: [Periphery](https://github.com/peripheryapp/periphery)

## MCP Servers
This project uses Model Context Protocol (MCP) servers for enhanced development capabilities:

### 1. Context7
Provides up-to-date documentation and code examples for libraries.
```bash
npx -y @upstash/context7-mcp@latest
```
Github: [Context7 MCP](https://github.com/upstash/context7-mcp)

### 2. SwiftLens
AI-powered Swift intelligence engine for semantic understanding of Swift codebases.
```bash
uvx swiftlens
```
Github: [SwiftLens](https://github.com/swiftlens/swiftlens)

### 3. Serena
Professional coding agent with semantic coding tools for intelligent codebase analysis.
```bash
uvx --from git+https://github.com/oraios/serena serena-mcp-server
```

To index the project for better semantic analysis:
```bash
uvx --from git+https://github.com/oraios/serena serena project index
```

Github: [Serena](https://github.com/oraios/serena)

## Environment Setup

### Bun setup for ccusage

```bash
curl -fsSL https://bun.com/install | bash
```

### Gemini API Key
To use AI-powered features, you need to set up your Gemini API key:

1. Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Add your API key to the `.gemini/.env` file in the root directory. Never use the already present key.
