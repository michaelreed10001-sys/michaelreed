//
//  StoredPDF+CoreDataProperties.swift
//  PDFReader
//
//  Created by Admin on 10/03/2026.
//
//

public import Foundation
public import CoreData


public typealias StoredPDFCoreDataPropertiesSet = NSSet

extension StoredPDF {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<StoredPDF> {
        return NSFetchRequest<StoredPDF>(entityName: "StoredPDF")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var fileName: String?
    @NSManaged public var fileSize: Double
    @NSManaged public var fileURL: String?
    @NSManaged public var id: UUID?
    @NSManaged public var lastOpened: Date?
    @NSManaged public var pageCount: Int16
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var isFavorite: Bool

}

extension StoredPDF : Identifiable {

}
