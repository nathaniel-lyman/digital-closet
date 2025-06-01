import SwiftUI
import CoreData

struct OutfitBuilderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        entity: ClothingItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ClothingItem.title, ascending: true)],
        animation: .default)
    private var allItems: FetchedResults<ClothingItem>
    
    @State private var outfitName = ""
    @State private var selectedItems: [String: ClothingItem] = [:] // Category -> Item
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let categories = ["Shirt", "Pants", "Jacket", "Dress", "Shoes", "Accessory"]
    private let layerOrder = ["Shoes", "Pants", "Dress", "Shirt", "Jacket", "Accessory"] // Bottom to top
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Outfit Name
                    VStack(alignment: .leading) {
                        Text("Outfit Name")
                            .font(.headline)
                        TextField("Enter outfit name", text: $outfitName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // Preview Section
                    VStack {
                        Text("Preview")
                            .font(.headline)
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 400)
                            
                            if isGenerating {
                                ProgressView()
                                    .scaleEffect(1.5)
                            } else if let generatedImage = generatedImage {
                                Image(uiImage: generatedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 400)
                            } else {
                                VStack {
                                    Image(systemName: "tshirt")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                    Text("Select items below to preview outfit")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Button(action: generateOutfitPreview) {
                            Label("Generate Preview", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedItems.isEmpty || isGenerating)
                    }
                    
                    // Item Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select Items")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(categories, id: \.self) { category in
                            VStack(alignment: .leading) {
                                Text(category)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        // Option to not select anything for this category
                                        Button(action: {
                                            selectedItems.removeValue(forKey: category)
                                            generateOutfitPreview()
                                        }) {
                                            VStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedItems[category] == nil ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text("None")
                                                            .font(.caption)
                                                            .foregroundColor(.gray)
                                                    )
                                                Text("No \(category)")
                                                    .font(.caption2)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        ForEach(itemsForCategory(category)) { item in
                                            ItemThumbnail(item: item, isSelected: selectedItems[category] == item) {
                                                selectedItems[category] = item
                                                generateOutfitPreview()
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 80) // Space for button
                }
            }
            .navigationTitle("Build Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveOutfit()
                    }
                    .disabled(outfitName.isEmpty || generatedImage == nil)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            generateOutfitPreview()
        }
    }
    
    private func itemsForCategory(_ category: String) -> [ClothingItem] {
        allItems.filter { $0.category == category }
    }
    
    private func generateOutfitPreview() {
        guard !selectedItems.isEmpty else {
            generatedImage = nil
            return
        }
        
        isGenerating = true
        
        Task {
            do {
                let image = try await generateOutfitImage()
                await MainActor.run {
                    generatedImage = image
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to generate outfit preview: \(error.localizedDescription)"
                    showingError = true
                    isGenerating = false
                }
            }
        }
    }
    
    private func generateOutfitImage() async throws -> UIImage {
        // Create a canvas size (portrait orientation for outfit)
        let canvasSize = CGSize(width: 600, height: 800)
        
        // Create the renderer
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        let image = renderer.image { context in
            // Fill with white background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            
            // Draw items in layer order
            for category in layerOrder {
                guard let item = selectedItems[category],
                      let imageData = item.imageData,
                      let itemImage = UIImage(data: imageData) else {
                    continue
                }
                
                // Calculate position and size based on category
                let frame = frameForCategory(category, canvasSize: canvasSize, imageSize: itemImage.size)
                
                // Draw the image
                itemImage.draw(in: frame)
            }
        }
        
        return image
    }
    
    private func frameForCategory(_ category: String, canvasSize: CGSize, imageSize: CGSize) -> CGRect {
        // Define relative positions and scales for each category
        let categoryFrames: [String: (center: CGPoint, maxSize: CGSize)] = [
            "Shoes": (CGPoint(x: 0.5, y: 0.9), CGSize(width: 0.4, height: 0.2)),
            "Pants": (CGPoint(x: 0.5, y: 0.65), CGSize(width: 0.7, height: 0.4)),
            "Dress": (CGPoint(x: 0.5, y: 0.5), CGSize(width: 0.8, height: 0.6)),
            "Shirt": (CGPoint(x: 0.5, y: 0.35), CGSize(width: 0.7, height: 0.4)),
            "Jacket": (CGPoint(x: 0.5, y: 0.35), CGSize(width: 0.75, height: 0.45)),
            "Accessory": (CGPoint(x: 0.5, y: 0.15), CGSize(width: 0.3, height: 0.2))
        ]
        
        guard let config = categoryFrames[category] else {
            // Default positioning
            return CGRect(x: canvasSize.width * 0.25, y: canvasSize.height * 0.25,
                         width: canvasSize.width * 0.5, height: canvasSize.height * 0.5)
        }
        
        // Calculate max size
        let maxWidth = canvasSize.width * config.maxSize.width
        let maxHeight = canvasSize.height * config.maxSize.height
        
        // Calculate aspect ratio preserving size
        let aspectRatio = imageSize.width / imageSize.height
        var finalWidth: CGFloat
        var finalHeight: CGFloat
        
        if aspectRatio > maxWidth / maxHeight {
            // Image is wider than the max box
            finalWidth = maxWidth
            finalHeight = maxWidth / aspectRatio
        } else {
            // Image is taller than the max box
            finalHeight = maxHeight
            finalWidth = maxHeight * aspectRatio
        }
        
        // Calculate position (centered at the config point)
        let x = (canvasSize.width * config.center.x) - (finalWidth / 2)
        let y = (canvasSize.height * config.center.y) - (finalHeight / 2)
        
        return CGRect(x: x, y: y, width: finalWidth, height: finalHeight)
    }
    
    private func saveOutfit() {
        guard let image = generatedImage else { return }
        
        // Compress the image for efficient storage
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to compress outfit image"
            showingError = true
            return
        }
        
        // Create the outfit entity
        let outfit = Outfit(context: viewContext)
        outfit.id = UUID()
        outfit.name = outfitName
        outfit.createdDate = Date()
        outfit.imageData = imageData
        outfit.itemIds = selectedItems.values.compactMap { $0.id }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save outfit: \(error.localizedDescription)"
            showingError = true
        }
    }
}

struct ItemThumbnail: View {
    let item: ClothingItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                Text(item.title ?? "Untitled")
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    OutfitBuilderView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 