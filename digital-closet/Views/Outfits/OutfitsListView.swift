import SwiftUI
import CoreData

struct OutfitsListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: Outfit.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Outfit.createdDate, ascending: false)],
        animation: .default)
    private var outfits: FetchedResults<Outfit>
    
    @State private var showingOutfitBuilder = false
    @State private var selectedOutfit: Outfit?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if outfits.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No outfits yet")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Tap the + button to create your first outfit")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(outfits) { outfit in
                            OutfitItemView(outfit: outfit)
                                .onTapGesture {
                                    selectedOutfit = outfit
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteOutfit(outfit)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Outfits")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingOutfitBuilder = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingOutfitBuilder) {
                OutfitBuilderView()
            }
            .sheet(item: $selectedOutfit) { outfit in
                OutfitDetailView(outfit: outfit)
            }
        }
    }
    
    private func deleteOutfit(_ outfit: Outfit) {
        withAnimation {
            viewContext.delete(outfit)
            
            do {
                try viewContext.save()
            } catch {
                print("Failed to delete outfit: \(error)")
            }
        }
    }
}

struct OutfitItemView: View {
    let outfit: Outfit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = outfit.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 200)
                    .overlay(
                        Image(systemName: "person.crop.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(outfit.name ?? "Untitled Outfit")
                    .font(.headline)
                    .lineLimit(1)
                
                if let date = outfit.createdDate {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 160, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct OutfitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    let outfit: Outfit
    
    @FetchRequest private var items: FetchedResults<ClothingItem>
    
    init(outfit: Outfit) {
        self.outfit = outfit
        
        // Create a fetch request for the items in this outfit
        let itemIds = outfit.itemIds ?? []
        let predicate = NSPredicate(format: "id IN %@", itemIds)
        _items = FetchRequest<ClothingItem>(
            entity: ClothingItem.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \ClothingItem.category, ascending: true)],
            predicate: predicate
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Outfit Image
                    if let imageData = outfit.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                    
                    // Outfit Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items in this outfit")
                            .font(.headline)
                        
                        ForEach(items) { item in
                            HStack {
                                if let imageData = item.imageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(item.title ?? "Untitled")
                                        .font(.body)
                                    Text("\(item.category ?? "") - \(item.subcategory ?? "")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle(outfit.name ?? "Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    OutfitsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
} 