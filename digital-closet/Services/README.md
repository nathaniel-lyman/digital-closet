# Services Directory

This directory contains service classes that handle external API integrations.

## Services

- **OpenAIService.swift** - Handles communication with OpenAI API for clothing item analysis
  - Analyzes uploaded images to automatically detect clothing type, color, and category
  - Uses GPT-4 Vision for image understanding

- **RemBgService.swift** - Handles background removal using remove.bg API
  - Processes clothing images to remove backgrounds
  - Provides clean product-style images for the closet

## Configuration

Both services use API keys stored in `Configuration/SecureConfig.swift`. 
Environment variables are checked first for better security:
- `OPENAI_KEY` for OpenAI
- `REMBG_KEY` for remove.bg 