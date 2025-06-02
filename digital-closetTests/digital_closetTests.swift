//
//  digital_closetTests.swift
//  digital-closetTests
//
//  Created by Nate Lyman on 6/1/25.
//

import Testing
@testable import digital_closet

struct digital_closetTests {

    @Test func categorySubcategories() throws {
        for category in ClothingCategory.allCases {
            #expect(!category.subcategories.isEmpty)
        }
    }

}
