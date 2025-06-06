//
//  ContentView.swift
//  digital-closet
//
//  Created by Nate Lyman on 6/1/25.
//

import SwiftUI
import CoreData
import PhotosUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        TabView {
            ClosetView()
                .tabItem {
                    Label("Closet", systemImage: "tshirt")
                }
            
            OutfitsListView()
                .tabItem {
                    Label("Outfits", systemImage: "person.crop.rectangle.stack")
                }
        }
    }
}

struct ClosetView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClothingItem.category, ascending: true)],
        animation: .default)
    private var items: FetchedResults<ClothingItem>
    
    @State private var showingAddSheet = false
    @State private var selectedItem: ClothingItem?
    
    // Group items by category and subcategory
    private var groupedItems: [(key: String, items: [ClothingItem])] {
        let grouped = Dictionary(grouping: items) { item in
            "\(item.category ?? "Unknown") - \(item.subcategory ?? "Other")"
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (key: $0.key, items: sortItemsByColor($0.value)) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if items.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tshirt")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No clothing items yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Tap the + button to add your first item")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(groupedItems, id: \.key) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                // Category header
                                HStack {
                                    Text(group.key)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(group.items.count) item\(group.items.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                
                                // Carousel for items
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(group.items) { item in
                                            ClothingItemCard(item: item)
                                                .onTapGesture {
                                                    selectedItem = item
                                                }
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        deleteItem(item)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Digital Closet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddClothingItemView()
            }
            .sheet(item: $selectedItem) { item in
                EditClothingItemView(item: item)
            }
        }
    }
    
    private func deleteItem(_ item: ClothingItem) {
        withAnimation {
            viewContext.delete(item)
            
            do {
                try viewContext.save()
            } catch {
                // Handle the error appropriately in production
                print("Failed to delete item: \(error)")
            }
        }
    }
    
    // Define color order as a static property to avoid compilation issues
    private static let colorOrder: [String] = [
        "white", "cream", "beige", "tan", "brown",
        "gray", "grey", "black",
        "red", "pink", "orange", "yellow",
        "green", "blue", "navy", "purple",
        "multi", "pattern", "other"
    ]
    
    // Sort items by color using a predefined color order
    private func sortItemsByColor(_ items: [ClothingItem]) -> [ClothingItem] {
        return items.sorted { item1, item2 in
            let color1 = item1.color?.lowercased() ?? "other"
            let color2 = item2.color?.lowercased() ?? "other"
            
            // Find the index of each color in the order array
            let index1 = Self.colorOrder.firstIndex(where: { color1.contains($0) }) ?? Self.colorOrder.count
            let index2 = Self.colorOrder.firstIndex(where: { color2.contains($0) }) ?? Self.colorOrder.count
            
            if index1 == index2 {
                // If same color category, sort alphabetically by title
                let title1 = item1.title ?? ""
                let title2 = item2.title ?? ""
                return title1 < title2
            }
            return index1 < index2
        }
    }
}

struct ClothingItemCard: View {
    let item: ClothingItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 180)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    // Color indicator
                    Circle()
                        .fill(colorForName(item.color ?? "gray"))
                        .frame(width: 12, height: 12)
                    
                    Text(item.color ?? "No color")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
    
    // Helper function to convert color names to SwiftUI colors
    private func colorForName(_ colorName: String) -> Color {
        let name = colorName.lowercased()
        
        // Check for common color names
        if name.contains("red") { return .red }
        if name.contains("blue") || name.contains("navy") { return .blue }
        if name.contains("green") { return .green }
        if name.contains("yellow") { return .yellow }
        if name.contains("orange") { return .orange }
        if name.contains("purple") { return .purple }
        if name.contains("pink") { return .pink }
        if name.contains("brown") || name.contains("tan") { return .brown }
        if name.contains("gray") || name.contains("grey") { return .gray }
        if name.contains("black") { return .black }
        if name.contains("white") || name.contains("cream") { return Color(.systemGray6) }
        
        return .gray
    }
}

struct AddClothingItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isProcessingImage = false
    @State private var title = ""
    @State private var category: ClothingCategory?
    private let categories = ClothingCategory.allCases
    @State private var subcategory = ""
    @State private var color = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var subcategories: [String] {
        category?.subcategories ?? []
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem,
                               matching: .images) {
                        if isProcessingImage {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Processing image...")
                            }
                            .frame(maxWidth: .infinity, maxHeight: 200)
                        } else if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                    .disabled(isProcessingImage)
                }
                
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag(nil as ClothingCategory?)
                        ForEach(categories) { option in
                            Text(option.rawValue).tag(Optional(option))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: category) { _, _ in
                        // Reset subcategory when category changes
                        subcategory = ""
                    }
                    if category != nil {
                        Picker("Type", selection: $subcategory) {
                            Text("Select Type").tag("")
                            ForEach(subcategories, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField("Color", text: $color)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(isProcessingImage)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let newItem = newItem else { return }
                    
                    isProcessingImage = true
                    defer { isProcessingImage = false }

                    do {
                        // 1. Load original image data
                        guard let originalImageData = try await newItem.loadTransferable(type: Data.self) else {
                            errorMessage = "Failed to load image data."
                            showingError = true
                            return
                        }

                        // 2. Convert to UIImage and then to JPEG data
                        guard let uiImage = UIImage(data: originalImageData),
                              let jpegImageData = uiImage.jpegData(compressionQuality: 0.8) else {
                            errorMessage = "Failed to convert image to JPEG format."
                            showingError = true
                            return
                        }
                        
                        var dataForAnalysis: Data
                        var finalSelectedImageData: Data = jpegImageData // Default to converted JPEG

                        // 3. Attempt background removal with JPEG data
                        do {
                            let processedDataFromRemBg = try await RemBgService.shared.removeBackground(from: jpegImageData)
                            finalSelectedImageData = processedDataFromRemBg
                            dataForAnalysis = processedDataFromRemBg
                            print("Background removal successful.")
                        } catch {
                            print("Background removal failed: \\(error.localizedDescription). Using original image (converted to JPEG) for analysis and saving.")
                            errorMessage = "Background removal failed. Using original image. You can try a different photo for better results." // Inform user
                            showingError = true // Let user know, but proceed with jpegImageData
                            dataForAnalysis = jpegImageData
                            // finalSelectedImageData is already jpegImageData
                        }
                        
                        selectedImageData = finalSelectedImageData // Update the @State for preview and saving

                        // 4. Analyze the clothing with OpenAI using dataForAnalysis
                        do {
                            let analysis = try await OpenAIService.shared.analyzeClothing(imageData: dataForAnalysis)
                            withAnimation {
                                title = analysis.title
                                category = ClothingCategory(rawValue: analysis.category)
                                if let cat = category {
                                    // Try exact match first
                                    if let normalized = cat.subcategories.first(where: { $0.caseInsensitiveCompare(analysis.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }) {
                                        subcategory = normalized
                                    } else {
                                        // Try contains (for plurals, dashes, etc)
                                        let lowerAI = analysis.subcategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                        if let fuzzy = cat.subcategories.first(where: { lowerAI.contains($0.lowercased()) || $0.lowercased().contains(lowerAI) }) {
                                            subcategory = fuzzy
                                        } else {
                                            // Optionally, fallback to "Other"
                                            subcategory = cat.subcategories.contains("Other") ? "Other" : ""
                                        }
                                    }
                                } else {
                                    subcategory = ""
                                }
                                color = analysis.color
                            }
                        } catch {
                            print("AI analysis failed: \\(error)")
                            errorMessage = "AI analysis failed: \\(error.localizedDescription)"
                            showingError = true
                            // Fields remain empty if analysis fails
                        }
                    } catch { // This catch is for errors from loadTransferable or other unexpected errors
                        print("Error processing image: \\(error.localizedDescription)")
                        errorMessage = "Failed to process image: \\(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveItem() {
        // Validate inputs
        guard let imageData = selectedImageData else {
            errorMessage = "Please select a photo"
            showingError = true
            return
        }
        
        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            showingError = true
            return
        }
        
        guard let category = category else {
            errorMessage = "Please select a category"
            showingError = true
            return
        }
        
        guard !subcategory.isEmpty else {
            errorMessage = "Please select a type"
            showingError = true
            return
        }
        
        guard !color.isEmpty else {
            errorMessage = "Please enter a color"
            showingError = true
            return
        }
        
        // Create and save the item
        let newItem = ClothingItem(context: viewContext)
        newItem.id = UUID()
        newItem.title = title
        newItem.category = category.rawValue
        newItem.subcategory = subcategory
        newItem.color = color
        newItem.imageData = imageData
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save item: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct EditClothingItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let item: ClothingItem
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isProcessingImage = false
    @State private var title: String
    @State private var category: ClothingCategory?
    private let categories = ClothingCategory.allCases
    @State private var subcategory: String
    @State private var color: String
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var subcategories: [String] {
        category?.subcategories ?? []
    }
    
    init(item: ClothingItem) {
        self.item = item
        _title = State(initialValue: item.title ?? "")
        _category = State(initialValue: ClothingCategory(rawValue: item.category ?? ""))
        _subcategory = State(initialValue: item.subcategory ?? "")
        _color = State(initialValue: item.color ?? "")
        _selectedImageData = State(initialValue: item.imageData)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem,
                               matching: .images) {
                        if isProcessingImage {
                            HStack {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Processing image...")
                            }
                            .frame(maxWidth: .infinity, maxHeight: 200)
                        } else if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                    .disabled(isProcessingImage)
                }
                
                Section {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag(nil as ClothingCategory?)
                        ForEach(categories) { option in
                            Text(option.rawValue).tag(Optional(option))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: category) { _, _ in
                        // Reset subcategory when category changes
                        subcategory = ""
                    }
                    if category != nil {
                        Picker("Type", selection: $subcategory) {
                            Text("Select Type").tag("")
                            ForEach(subcategories, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    TextField("Color", text: $color)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateItem()
                    }
                    .disabled(isProcessingImage)
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    guard let newItem = newItem else { return }
                    
                    isProcessingImage = true
                    defer { isProcessingImage = false }

                    do {
                        // 1. Load original image data
                        guard let originalImageData = try await newItem.loadTransferable(type: Data.self) else {
                            errorMessage = "Failed to load image data."
                            showingError = true
                            return
                        }

                        // 2. Convert to UIImage and then to JPEG data
                        guard let uiImage = UIImage(data: originalImageData),
                              let jpegImageData = uiImage.jpegData(compressionQuality: 0.8) else {
                            errorMessage = "Failed to convert image to JPEG format."
                            showingError = true
                            return
                        }
                        
                        var dataForAnalysis: Data
                        var finalSelectedImageData: Data = jpegImageData // Default to converted JPEG

                        // 3. Attempt background removal with JPEG data
                        do {
                            let processedDataFromRemBg = try await RemBgService.shared.removeBackground(from: jpegImageData)
                            finalSelectedImageData = processedDataFromRemBg
                            dataForAnalysis = processedDataFromRemBg
                            print("Background removal successful.")
                        } catch {
                            print("Background removal failed: \\(error.localizedDescription). Using original image (converted to JPEG) for analysis and saving.")
                            errorMessage = "Background removal failed. Using original image. You can try a different photo for better results." // Inform user
                            showingError = true // Let user know, but proceed with jpegImageData
                            dataForAnalysis = jpegImageData
                            // finalSelectedImageData is already jpegImageData
                        }
                        
                        selectedImageData = finalSelectedImageData // Update the @State for preview and saving
                        
                        // 4. Only analyze if fields are empty (user might be just changing the photo)
                        if title.isEmpty || category == nil || subcategory.isEmpty || color.isEmpty {
                            do {
                                let analysis = try await OpenAIService.shared.analyzeClothing(imageData: dataForAnalysis)
                                withAnimation {
                                    if title.isEmpty { title = analysis.title }
                                    if category == nil { category = ClothingCategory(rawValue: analysis.category) }
                                    if subcategory.isEmpty { subcategory = analysis.subcategory }
                                    if color.isEmpty { color = analysis.color }
                                }
                            } catch {
                                print("AI analysis failed: \\(error)")
                                errorMessage = "AI analysis failed: \\(error.localizedDescription)"
                                showingError = true
                            }
                        }
                    } catch { // This catch is for errors from loadTransferable or other unexpected errors
                        print("Error processing image: \\(error.localizedDescription)")
                        errorMessage = "Failed to process image: \\(error.localizedDescription)"
                        showingError = true
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func updateItem() {
        // Validate inputs
        guard let imageData = selectedImageData else {
            errorMessage = "Please select a photo"
            showingError = true
            return
        }
        
        guard !title.isEmpty else {
            errorMessage = "Please enter a title"
            showingError = true
            return
        }
        
        guard let category = category else {
            errorMessage = "Please select a category"
            showingError = true
            return
        }
        
        guard !subcategory.isEmpty else {
            errorMessage = "Please select a type"
            showingError = true
            return
        }
        
        guard !color.isEmpty else {
            errorMessage = "Please enter a color"
            showingError = true
            return
        }
        
        // Update the existing item
        item.title = title
        item.category = category.rawValue
        item.subcategory = subcategory
        item.color = color
        item.imageData = imageData
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to update item: \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
