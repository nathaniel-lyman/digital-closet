# Models Directory

This directory contains the data models and Core Data definitions for the Digital Closet app.

## Contents

- **ClothingCategory.swift** - Enum defining clothing categories and their subcategories
  - Provides structured categorization for clothing items
  - Used throughout the app for consistent categorization

- **ClothingItem.xcdatamodeld/** - Core Data model definition
  - Defines the `ClothingItem` entity with attributes:
    - `id`: UUID
    - `title`: String
    - `category`: String
    - `subcategory`: String
    - `color`: String
    - `imageData`: Binary (stores the clothing image)
  - Defines the `Outfit` entity for storing outfit combinations 