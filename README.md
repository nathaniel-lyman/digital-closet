# Digital Closet

An iOS SwiftUI app to manage your wardrobe. The project includes a Core Data model to store clothing items and allows adding, editing, and deleting pieces from your collection.

## Setup
1. Clone the repository.
2. Open `digital-closet.xcodeproj` in Xcode.
3. Provide your API keys using environment variables `OPENAI_KEY` and `REMBG_KEY`, or add them in `digital-closet/Secrets.xcconfig` by replacing the placeholders.
4. Build and run on a simulator or device running iOS 18.5 or later.

## Development
User-specific Xcode data and build artifacts are ignored using `.gitignore`. The project uses SwiftUI and Core Data only. Basic unit tests are included in `digital-closetTests`.
