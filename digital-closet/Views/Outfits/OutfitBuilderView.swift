import SwiftUI
import CoreData
import UIKit

// MARK: - View Model
@MainActor
class OutfitBuilderViewModel: ObservableObject {
    @Published var outfitName = ""
    @Published var selectedItems: [String: ClothingItem] = [:]
    @Published var generatedImage: UIImage?
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var showingError = false
    
    private let viewContext: NSManagedObjectContext
    private var previewDebounceTask: Task<Void, Never>?
    private var cachedSelection: [String: UUID] = [:]
    
    let categories = ClothingCategory.allCases.map { $0.rawValue }
    public let layerOrder = ["Shoes", "Pants", "Dress", "Shirt", "Jacket", "Accessory"]
    
    init(context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    // MARK: - Public Methods
    
    func selectItem(_ item: ClothingItem?, for category: String) {
        if let item = item {
            selectedItems[category] = item
        } else {
            selectedItems.removeValue(forKey: category)
        }
        schedulePreviewGeneration()
    }
    
    func saveOutfit() async -> Bool {
        guard let validationError = validateOutfit() else {
            do {
                try await performSave()
                return true
            } catch {
                await showError("Failed to save outfit: \(error.localizedDescription)")
                return false
            }
        }
        
        await showError(validationError)
        return false
    }
    
    func generateInitialPreview() {
        schedulePreviewGeneration()
    }
    
    // MARK: - Private Methods
    
    private func schedulePreviewGeneration() {
        previewDebounceTask?.cancel()
        
        guard !selectedItems.isEmpty else {
            generatedImage = nil
            cachedSelection = [:]
            return
        }
        
        let currentSelection = selectedItems.compactMapValues { $0.id }
        guard currentSelection != cachedSelection else { return }
        
        previewDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            self.cachedSelection = currentSelection
            await generatePreview()
        }
    }
    
    private func generatePreview() async {
        isGenerating = true
        
        do {
            let image = try await generateOutfitImage()
            generatedImage = image
        } catch {
            await showError("Failed to generate preview: \(error.localizedDescription)")
        }
        
        isGenerating = false
    }
    
    private func generateOutfitImage() async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached(priority: .utility) {
                let image = await self.createOutfitImage()
                continuation.resume(returning: image)
            }
        }
    }
    
    private func createOutfitImage() async -> UIImage {
        let canvasSize = CGSize(width: 600, height: 800)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        format.preferredRange = .standard

        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        
        return renderer.image { context in
            UIColor.systemBackground.setFill()
            context.fill(CGRect(origin: .zero, size: canvasSize))
            
            for category in layerOrder {
                guard let item = selectedItems[category],
                      let imageData = item.imageData,
                      let itemImage = UIImage(data: imageData) else {
                    continue
                }
                
                let frame = frameForCategory(category, canvasSize: canvasSize, imageSize: itemImage.size)
                itemImage.draw(in: frame)
            }
        }
    }
    
    private func frameForCategory(_ category: String, canvasSize: CGSize, imageSize: CGSize) -> CGRect {
        let layout = CategoryLayout.layout(for: category)
        
        let maxWidth = canvasSize.width * layout.maxSize.width
        let maxHeight = canvasSize.height * layout.maxSize.height
        
        let aspectRatio = imageSize.width / imageSize.height
        let finalSize: CGSize
        
        if aspectRatio > maxWidth / maxHeight {
            finalSize = CGSize(width: maxWidth, height: maxWidth / aspectRatio)
        } else {
            finalSize = CGSize(width: maxHeight * aspectRatio, height: maxHeight)
        }
        
        let position = CGPoint(
            x: (canvasSize.width * layout.center.x) - (finalSize.width / 2),
            y: (canvasSize.height * layout.center.y) - (finalSize.height / 2)
        )
        
        return CGRect(origin: position, size: finalSize)
    }
    
    private func validateOutfit() -> String? {
        let trimmedName = outfitName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return "Outfit name cannot be empty"
        }
        
        if trimmedName.count > 50 {
            return "Outfit name is too long (max 50 characters)"
        }
        
        if isOutfitNameTaken(trimmedName) {
            return "An outfit with this name already exists"
        }
        
        if generatedImage == nil {
            return "Please generate a preview before saving"
        }
        
        return nil
    }
    
    private func isOutfitNameTaken(_ name: String) -> Bool {
        let request: NSFetchRequest<Outfit> = Outfit.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        
        return (try? viewContext.count(for: request)) ?? 0 > 0
    }
    
    private func performSave() async throws {
        guard let image = generatedImage else {
            throw OutfitBuilderError.missingPreview
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw OutfitBuilderError.imageCompressionFailed
        }
        
        let outfit = Outfit(context: viewContext)
        outfit.id = UUID()
        outfit.name = outfitName.trimmingCharacters(in: .whitespacesAndNewlines)
        outfit.createdDate = Date()
        outfit.imageData = imageData
        // Store the item IDs instead of trying to create a relationship
        outfit.itemIds = selectedItems.values.compactMap { $0.id }
        
        try viewContext.save()
    }
    
    private func showError(_ message: String) async {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Supporting Types

enum OutfitBuilderError: LocalizedError {
    case missingPreview
    case imageCompressionFailed
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingPreview:
            return "Please generate a preview before saving"
        case .imageCompressionFailed:
            return "Failed to process outfit image"
        case .saveFailed(let error):
            return "Could not save outfit: \(error.localizedDescription)"
        }
    }
}

public struct CategoryLayout {
    let center: CGPoint
    let maxSize: CGSize
    let zIndex: Double
    
    static func layout(for category: String) -> CategoryLayout {
        let layouts: [String: CategoryLayout] = [
            "Shoes": CategoryLayout(center: CGPoint(x: 0.5, y: 0.85), maxSize: CGSize(width: 0.4, height: 0.2), zIndex: 1),
            "Pants": CategoryLayout(center: CGPoint(x: 0.5, y: 0.6), maxSize: CGSize(width: 0.7, height: 0.4), zIndex: 2),
            "Dress": CategoryLayout(center: CGPoint(x: 0.5, y: 0.45), maxSize: CGSize(width: 0.8, height: 0.6), zIndex: 2),
            "Shirt": CategoryLayout(center: CGPoint(x: 0.5, y: 0.35), maxSize: CGSize(width: 0.7, height: 0.4), zIndex: 3),
            "Jacket": CategoryLayout(center: CGPoint(x: 0.5, y: 0.35), maxSize: CGSize(width: 0.75, height: 0.45), zIndex: 4),
            "Accessory": CategoryLayout(center: CGPoint(x: 0.5, y: 0.15), maxSize: CGSize(width: 0.3, height: 0.2), zIndex: 5)
        ]
        
        return layouts[category] ?? CategoryLayout(
            center: CGPoint(x: 0.5, y: 0.5),
            maxSize: CGSize(width: 0.5, height: 0.5),
            zIndex: 0
        )
    }
}

// MARK: - Main View

struct OutfitBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: OutfitBuilderViewModel
    
    init(context: NSManagedObjectContext) {
        self._viewModel = StateObject(wrappedValue: OutfitBuilderViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    OutfitNameSection(name: $viewModel.outfitName)
                    
                    OutfitPreviewSection(
                        generatedImage: viewModel.generatedImage,
                        isGenerating: viewModel.isGenerating,
                        hasSelectedItems: !viewModel.selectedItems.isEmpty,
                        selectedItems: viewModel.selectedItems,
                        onGeneratePreview: viewModel.generateInitialPreview
                    )
                    
                    CategorySelectionSection(
                        categories: viewModel.categories,
                        selectedItems: viewModel.selectedItems,
                        onItemSelected: viewModel.selectItem
                    )
                    
                    Spacer(minLength: 80)
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
                        Task {
                            if await viewModel.saveOutfit() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            viewModel.generateInitialPreview()
        }
    }
    
    private var canSave: Bool {
        !viewModel.outfitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        viewModel.generatedImage != nil &&
        !viewModel.isGenerating
    }
}

// MARK: - Component Views

struct OutfitNameSection: View {
    @Binding var name: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Outfit Name")
                .font(.headline)
            
            TextField("Enter outfit name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("Outfit name")
                .accessibilityHint("Enter a name for your outfit")
        }
        .padding(.horizontal)
    }
}

struct OutfitPreviewSection: View {
    let generatedImage: UIImage?
    let isGenerating: Bool
    let hasSelectedItems: Bool
    let selectedItems: [String: ClothingItem]
    let onGeneratePreview: () -> Void
    
    @State private var previewStyle: PreviewStyle = .stacked
    
    enum PreviewStyle: String, CaseIterable {
        case stacked = "Stacked"
        case flatLay = "Flat Lay"
        
        var icon: String {
            switch self {
            case .stacked: return "square.stack"
            case .flatLay: return "grid"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Preview")
                    .font(.headline)
                
                Spacer()
                
                // Style toggle
                Picker("Preview Style", selection: $previewStyle) {
                    ForEach(PreviewStyle.allCases, id: \.self) { style in
                        Label(style.rawValue, systemImage: style.icon)
                            .tag(style)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 160)
            }
            .padding(.horizontal)
            
            Group {
                switch previewStyle {
                case .stacked:
                    PreviewCanvas(
                        image: generatedImage,
                        isGenerating: isGenerating,
                        hasSelectedItems: hasSelectedItems
                    )
                case .flatLay:
                    FlatLayPreview(
                        selectedItems: selectedItems,
                        hasSelectedItems: hasSelectedItems
                    )
                }
            }
            
            if previewStyle == .stacked {
                Button(action: onGeneratePreview) {
                    Label("Generate Preview", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasSelectedItems || isGenerating)
                .accessibilityLabel("Generate outfit preview")
                .accessibilityHint("Creates a preview image of your selected items")
            }
        }
    }
}

struct PreviewCanvas: View {
    let image: UIImage?
    let isGenerating: Bool
    let hasSelectedItems: Bool
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay {
                    Group {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(1.5)
                                .accessibilityLabel("Generating preview")
                        } else if let image = image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel("Outfit preview")
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "tshirt")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text(hasSelectedItems ? "Tap Generate Preview" : "Select items below to preview outfit")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .accessibilityLabel(hasSelectedItems ? "Tap generate preview to see your outfit" : "Select items below to preview outfit")
                        }
                    }
                }
        }
        .frame(height: min(400, UIScreen.main.bounds.height * 0.4))
        .padding(.horizontal)
    }
}

struct CategorySelectionSection: View {
    let categories: [String]
    let selectedItems: [String: ClothingItem]
    let onItemSelected: (ClothingItem?, String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Items")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(categories, id: \.self) { category in
                CategoryRow(
                    category: category,
                    selectedItem: selectedItems[category],
                    onItemSelected: { item in
                        onItemSelected(item, category)
                    }
                )
            }
        }
    }
}

struct CategoryRow: View {
    let category: String
    let selectedItem: ClothingItem?
    let onItemSelected: (ClothingItem?) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    NoneSelectionButton(
                        category: category,
                        isSelected: selectedItem == nil,
                        onSelect: { onItemSelected(nil) }
                    )
                    
                    ForEach(itemsForCategory) { item in
                        ItemThumbnail(
                            item: item,
                            isSelected: selectedItem == item,
                            onSelect: { onItemSelected(item) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(category) selection")
    }
    
    private var itemsForCategory: [ClothingItem] {
        let request: NSFetchRequest<ClothingItem> = ClothingItem.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClothingItem.title, ascending: true)]
        
        return (try? viewContext.fetch(request)) ?? []
    }
}

struct NoneSelectionButton: View {
    let category: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 2)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    )
                
                Text("No \(category)")
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("No \(category)")
        .accessibilityHint("Select to not include any \(category.lowercased()) in this outfit")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ItemThumbnail: View {
    let item: ClothingItem
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Group {
                    if let imageData = item.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                Text(item.title ?? "Untitled")
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 80)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(item.title ?? "Untitled item")
        .accessibilityHint("Double tap to add this item to your outfit")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// New Flat Lay Preview Component
struct FlatLayPreview: View {
    let selectedItems: [String: ClothingItem]
    let hasSelectedItems: Bool
    
    // Define a custom grid layout for flat lay style
    private let gridItems = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .overlay {
                if hasSelectedItems {
                    LazyVGrid(columns: gridItems, spacing: 20) {
                        ForEach(sortedItems, id: \.key) { category, item in
                            FlatLayItemView(
                                item: item,
                                category: category
                            )
                        }
                    }
                    .padding(24)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("Select items to see flat lay preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(height: 300)
            .padding(.horizontal)
    }
    
    // Sort items by priority for better visual arrangement
    private var sortedItems: [(key: String, value: ClothingItem)] {
        let priorityOrder = ["Dress", "Jacket", "Shirt", "Pants", "Shoes", "Accessory"]
        
        return selectedItems.sorted { first, second in
            let firstIndex = priorityOrder.firstIndex(of: first.key) ?? priorityOrder.count
            let secondIndex = priorityOrder.firstIndex(of: second.key) ?? priorityOrder.count
            return firstIndex < secondIndex
        }
    }
}

// Individual item view for flat lay
struct FlatLayItemView: View {
    let item: ClothingItem
    let category: String
    
    var body: some View {
        VStack(spacing: 8) {
            Group {
                if let imageData = item.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: categoryIcon(for: category))
                                .font(.title2)
                                .foregroundColor(.secondary)
                        )
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            VStack(spacing: 2) {
                Text(item.title ?? "Untitled")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
        .accessibilityLabel("\(item.title ?? "Untitled") - \(category)")
    }
    
    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Dress": return "dress"
        case "Jacket": return "suit.jacket"
        case "Shirt": return "tshirt"
        case "Pants": return "pants"
        case "Shoes": return "shoe"
        case "Accessory": return "bag"
        default: return "tshirt"
        }
    }
}

// MARK: - Preview

#Preview {
    OutfitBuilderView(context: PersistenceController.preview.container.viewContext)
}
