//
//  ContentView.swift
//  Dicom2DTest
//
//  Created by Davide Castaldi on 09/12/24.
//

import SwiftUI
import UIKit
import DcmSwift

// MARK: - Extend DataSet for PixelData Access
extension DataSet {
    func pixelData() -> Data? {
        guard let element = element(forTagName: "PixelData") else { return nil }
        return element.data
    }
}

struct ContentView: View {
    
    @State private var datasets: [(dataset: DataSet, filename: String)] = []
    @State private var currentIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var errorMessage: String? = nil
    
    
    var body: some View {
        VStack {
            if datasets.isEmpty {
                Text("No DICOM files found")
                    .padding()
            } else {
                
                VStack {

                    if let currentDataset = datasets[safe: currentIndex]?.dataset,
                       let pixelData = currentDataset.pixelData(),
                       let dicomImageLeft = imageFromPixelDataLeft(pixelData: pixelData, dataset: currentDataset), let dicomImageRight = imageFromPixelDataRight(pixelData: pixelData, dataset: currentDataset){
                        HStack(spacing: 0) {
                            Image(uiImage: dicomImageLeft).resizable()
                            Image(uiImage: dicomImageRight).resizable()
                        }
                        .frame(height: 400)
                        .aspectRatio(2, contentMode: .fit)
                        
                    } else {
                        Image(systemName: "doc.text.image")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding()
                        
                        Text("Unable to display DICOM image")
                    }
                    
                    if let currentFileName = datasets[safe: currentIndex]?.filename {
                        Text("File: \(currentFileName)")
                            .font(.headline)
                            .padding()
                    }
                    
                    if let currentDataset = datasets[safe: currentIndex]?.dataset {
                        Text(extractMetadata(dataset: currentDataset))
                            .padding()
                    }
                }
                .onAppear {
                    startVideoLoop()
                }
                .onDisappear {
                    stopVideoLoop()
                }
            }
        }
        .onAppear {
            loadDicomFiles()
        }
    }
    
    //MARK: - Utility to Extract Metadata
    @MainActor
    func extractMetadata(dataset: DataSet) -> String {
        let patientName = dataset.string(forTag: "PatientName") ?? "Unknown"
        let modality = dataset.string(forTag: "Modality") ?? "Unknown"
        let studyDate = dataset.string(forTag: "StudyDate") ?? "Unknown"
        
        return """
        Patient Name: \(patientName)
        Modality: \(modality)
        Study Date: \(studyDate)
        """
    }
    
    //MARK: - PixelData Rendering (Left)
    @MainActor
    func imageFromPixelDataLeft(pixelData: Data, dataset: DataSet) -> UIImage? {
        let rows = dataset.integer16(forTag: "Rows") ?? 0
        let columns = dataset.integer16(forTag: "Columns") ?? 0
                
        guard rows > 0, columns > 0 else {
            fatalError("Invalid dimensions")
        }
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let provider = CGDataProvider(data: pixelData as CFData)
        
        guard let cgImage = CGImage(
            width: Int(columns),
            height: Int(rows),
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: Int(columns) * 2,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo,
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    //MARK: - PixelData Rendering (Right)
    @MainActor
    func imageFromPixelDataRight(pixelData: Data, dataset: DataSet) -> UIImage? {
        let rows = dataset.integer16(forTag: "Rows") ?? 0
        let columns = dataset.integer16(forTag: "Columns") ?? 0
        
        guard rows > 0, columns > 0 else {
            fatalError("Invalid dimensions")
        }
        
        
        
        let halfColumns = columns / 2
        
        let rightPixelData = pixelData.subdata(in: Int(halfColumns) * 2..<pixelData.count)
        

        let provider = CGDataProvider(data: rightPixelData as CFData)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let cgImage = CGImage(
            width: Int(halfColumns) * 2,
            height: Int(rows),
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: Int(halfColumns) * 4,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: bitmapInfo,
            provider: provider!,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    //MARK: - Video Loop Control
    func startVideoLoop() {
        stopVideoLoop()
        timer = Timer.scheduledTimer(withTimeInterval: 1/6, repeats: true) { _ in
            currentIndex = (currentIndex + 1) % datasets.count
        }
    }
    
    func stopVideoLoop() {
        timer?.invalidate()
        timer = nil
    }
    
    //MARK: - Load Multiple DICOM Files
    @MainActor
    func loadDicomFiles() {
        guard let folderPath = Bundle.main.resourcePath else {
            errorMessage = "DICOM folder not found"
            return
        }
        
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: folderPath)
            let dicomFiles = files.filter { $0.hasSuffix(".dcm") }
            
            let sortedFiles = dicomFiles.sorted { (file1, file2) -> Bool in
                let number1 = extractNumber(from: file1)
                let number2 = extractNumber(from: file2)
                return number1 < number2
            }
            
            for file in sortedFiles {
                let filePath = (folderPath as NSString).appendingPathComponent(file)
                let inputStream = DicomInputStream(filePath: filePath)
                
                do {
                    if let dataset = try inputStream.readDataset() {
                        datasets.append((dataset, file))
                    } else {
                        Logger.warning("Dataset is nil or empty for file: \(file)")
                    }
                } catch {
                    Logger.error("Error reading DICOM dataset: \(error)")
                }
            }
        } catch {
            Logger.error("Error reading directory: \(error)")
        }
    }
    
    //MARK: - Extract Number from Filename (e.g., "1-01.dcm" -> 1)
    func extractNumber(from filename: String) -> Int {
        let components = filename.split(separator: "-")
        if components.count > 1, let number = Int(components[1].split(separator: ".")[0]) {
            return number
        }
        return 0
    }
    
    @MainActor
    func retrieveDataSet() -> DataSet {
        guard let filePath = Bundle.main.path(
            forResource: "1-01",
            ofType: "dcm"
        ) else {
            Logger.error("File not found")
            return DataSet()
        }
        
        let inputStream = DicomInputStream(filePath: filePath)
        
        do {
            if let dataset = try inputStream.readDataset() {
                Logger.info("Dataset successfully read")
                return dataset
            } else {
                Logger.warning("Dataset is nil or empty")
            }
        } catch {
            Logger.error("Error reading DICOM dataset: \(error)")
        }
        return DataSet()
    }
}

//MARK: - Safe Array Indexing
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
