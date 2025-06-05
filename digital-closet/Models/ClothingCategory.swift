import Foundation

enum ClothingCategory: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case shirt = "Shirt"
    case pants = "Pants"
    case jacket = "Jacket"
    case dress = "Dress"
    case shoes = "Shoes"
    case accessory = "Accessory"

    var subcategories: [String] {
        switch self {
        case .shirt:
            return ["Button-Down", "T-Shirt", "Polo", "Tank Top", "Blouse", "Other"]
        case .pants:
            return ["Jeans", "Chinos", "Shorts", "Sweatpants", "Dress Pants", "Other"]
        case .jacket:
            return ["Bomber", "Denim", "Leather", "Blazer", "Puffer", "Windbreaker", "Other"]
        case .dress:
            return ["Casual", "Formal", "Maxi", "Mini", "Midi", "Other"]
        case .shoes:
            return ["Sneakers", "Boots", "Dress Shoes", "Sandals", "Heels", "Loafers", "Other"]
        case .accessory:
            return ["Hat", "Bag", "Belt", "Scarf", "Jewelry", "Watch", "Other"]
        }
    }
}
