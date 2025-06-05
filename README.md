# Digital Closet

An iOS SwiftUI app to manage your wardrobe. The project includes a Core Data model to store clothing items and allows adding, editing, and deleting pieces from your collection.

## Features
- 📸 Automatic clothing recognition using AI (OpenAI GPT-4 Vision)
- 🎨 Background removal for clean product images
- 👔 Organized closet view by category and color
- 👗 Outfit builder to create and save outfit combinations
- 🏷️ Smart categorization with subcategories

## Project Structure

```
digital-closet/
├── DigitalClosetApp.swift    # App entry point
├── Assets.xcassets/          # Image assets and app icons
├── Configuration/            # App configuration
│   └── SecureConfig.swift    # API keys configuration
├── Models/                   # Data models
│   ├── ClothingCategory.swift
│   └── ClothingItem.xcdatamodeld/
├── Services/                 # External API services
│   ├── OpenAIService.swift   # AI clothing analysis
│   └── RemBgService.swift    # Background removal
└── Views/                    # SwiftUI views
    ├── ClothingItems/        # Clothing management views
    │   └── ContentView.swift
    ├── Outfits/              # Outfit management views
    │   ├── OutfitBuilderView.swift
    │   └── OutfitsListView.swift
    └── Components/           # Reusable UI components
```

## Setup
1. Clone the repository.
2. Open `digital-closet.xcodeproj` in Xcode.
3. Provide your API keys using environment variables `OPENAI_KEY` and `REMBG_KEY`, or add them in `digital-closet/Configuration/SecureConfig.swift` by replacing the placeholders.
4. Build and run on a simulator or device running iOS 18.5 or later.

## Development
User-specific Xcode data and build artifacts are ignored using `.gitignore`. The project uses SwiftUI and Core Data only. Basic unit tests are included in `digital-closetTests`.
