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
    @FetchRequest(
        entity: ClothingItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ClothingItem.id, ascending: true)],
        animation: .default)
    private var items: FetchedResults<ClothingItem>
    
    @State private var showingAddSheet = false
    @State private var selectedItem: ClothingItem?
    
    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 16)
    ]
    
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            ClothingItemView(item: item)
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
                    .padding()
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
}

struct ClothingItemView: View {
    let item: ClothingItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageData = item.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.category?.isEmpty == false ? item.category! : "No category")
                    .font(.headline)
                    .foregroundColor(item.category?.isEmpty == false ? .primary : .secondary)
                    .lineLimit(1)
                
                Text(item.color?.isEmpty == false ? item.color! : "No color")
                    .font(.subheadline)
                    .foregroundColor(item.color?.isEmpty == false ? .primary : .secondary)
                    .lineLimit(1)
                
                Text(item.season?.isEmpty == false ? item.season! : "No season")
                    .font(.caption)
                    .foregroundColor(item.season?.isEmpty == false ? .primary : .secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: 160, alignment: .leading)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct AddClothingItemView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var category = ""
    private let categories = [
        "Shirt",
        "Pants",
        "Jacket",
        "Dress",
        "Shoes",
        "Accessory"
    ]
    @State private var color = ""
    @State private var season = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem,
                               matching: .images) {
                        if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                }
                
                Section {
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag("")
                        ForEach(categories, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    TextField("Color", text: $color)
                    TextField("Season", text: $season)
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
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
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
        
        guard !category.isEmpty else {
            errorMessage = "Please select a category"
            showingError = true
            return
        }
        
        guard !color.isEmpty else {
            errorMessage = "Please enter a color"
            showingError = true
            return
        }
        
        guard !season.isEmpty else {
            errorMessage = "Please enter a season"
            showingError = true
            return
        }
        
        // Create and save the item
        let newItem = ClothingItem(context: viewContext)
        newItem.id = UUID()
        newItem.category = category
        newItem.color = color
        newItem.season = season
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
    @State private var category: String
    @State private var color: String
    @State private var season: String
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(item: ClothingItem) {
        self.item = item
        _category = State(initialValue: item.category ?? "")
        _color = State(initialValue: item.color ?? "")
        _season = State(initialValue: item.season ?? "")
        _selectedImageData = State(initialValue: item.imageData)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem,
                               matching: .images) {
                        if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                }
                
                Section {
                    TextField("Category", text: $category)
                    TextField("Color", text: $color)
                    TextField("Season", text: $season)
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
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        selectedImageData = data
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
        
        guard !category.isEmpty else {
            errorMessage = "Please enter a category"
            showingError = true
            return
        }
        
        guard !color.isEmpty else {
            errorMessage = "Please enter a color"
            showingError = true
            return
        }
        
        guard !season.isEmpty else {
            errorMessage = "Please enter a season"
            showingError = true
            return
        }
        
        // Update the existing item
        item.category = category
        item.color = color
        item.season = season
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
