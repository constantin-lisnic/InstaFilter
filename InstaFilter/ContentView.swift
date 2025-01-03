//
//  ContentView.swift
//  InstaFilter
//
//  Created by Constantin Lisnic on 16/12/2024.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import StoreKit
import SwiftUI

struct ContentView: View {
    @State private var processedImage: Image?
    @State private var filterIntensity = 0.5
    @State private var radiusAmount = 100.0
    @State private var scaleAmount = 50.0
    @State private var selectedItem: PhotosPickerItem?

    @State private var showingFilters = false

    @AppStorage("filterCount") var filterCount = 0
    @Environment(\.requestReview) var requestReview

    @State private var currentFilter: CIFilter = CIFilter.sepiaTone()
    let context = CIContext()
    
    var isProcessedImageAvailable: Bool {
        processedImage != nil
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                PhotosPicker(selection: $selectedItem) {
                    if let processedImage {
                        processedImage
                            .resizable()
                            .scaledToFit()
                    } else {
                        ContentUnavailableView(
                            "No Picture", systemImage: "photo.badge.plus",
                            description: Text("Import a photo to get started"))
                    }
                }
                .buttonStyle(.plain)
                .onChange(of: selectedItem, loadImage)

                HStack {
                    Text("Intensity")
                    Slider(value: $filterIntensity)
                        .onChange(of: filterIntensity, applyProcessing)
                        .disabled(!currentFilter.inputKeys.contains(kCIInputIntensityKey) || !isProcessedImageAvailable)
                }
                .padding(.vertical)
                
                HStack {
                    Text("Radius")
                    Slider(value: $radiusAmount, in: 0...200)
                        .onChange(of: radiusAmount, applyProcessing)
                        .disabled(!currentFilter.inputKeys.contains(kCIInputRadiusKey) || !isProcessedImageAvailable)
                }
                .padding(.vertical)
                
                HStack {
                    Text("Scale")
                    Slider(value: $scaleAmount, in: 0...100)
                        .onChange(of: radiusAmount, applyProcessing)
                        .disabled(!isProcessedImageAvailable || !currentFilter.inputKeys.contains(kCIInputScaleKey))
                }
                .padding(.vertical)

                HStack {
                    Button("Change Filter", action: changeFilter)
                        .disabled(!isProcessedImageAvailable)
                }

                Spacer()

                if let processedImage {
                    ShareLink(
                        item: processedImage,
                        preview: SharePreview(
                            "InstaFilter image", image: processedImage))
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("InstaFilter")
            .confirmationDialog("Select a filter", isPresented: $showingFilters)
            {
                Button("Crystallize") { setFilter(CIFilter.crystallize()) }
                Button("Edges") { setFilter(CIFilter.edges()) }
                Button("Gaussian Blur") { setFilter(CIFilter.gaussianBlur()) }
                Button("Pixellate") { setFilter(CIFilter.pixellate()) }
                Button("Sepia Tone") { setFilter(CIFilter.sepiaTone()) }
                Button("Unsharp Mask") { setFilter(CIFilter.unsharpMask()) }
                Button("Vignette") { setFilter(CIFilter.vignette()) }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    func changeFilter() {
        showingFilters = true
    }

    func loadImage() {
        Task {
            guard
                let imageData = try await selectedItem?.loadTransferable(
                    type: Data.self)
            else { return }

            guard let inputImage = UIImage(data: imageData) else { return }

            let beginImage = CIImage(image: inputImage)
            currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
            applyProcessing()
        }
    }

    func applyProcessing() {
        let inputKeys = currentFilter.inputKeys

        if inputKeys.contains(kCIInputIntensityKey) {
            currentFilter.setValue(
                filterIntensity, forKey: kCIInputIntensityKey)
        }
        if inputKeys.contains(kCIInputRadiusKey) {
            currentFilter.setValue(
                radiusAmount, forKey: kCIInputRadiusKey)
        }
        if inputKeys.contains(kCIInputScaleKey) {
            currentFilter.setValue(
                scaleAmount, forKey: kCIInputScaleKey)
        }

        guard let outputImage = currentFilter.outputImage else { return }
        guard
            let cgImage = context.createCGImage(
                outputImage, from: outputImage.extent)
        else { return }

        let uiImage = UIImage(cgImage: cgImage)
        processedImage = Image(uiImage: uiImage)
    }

    @MainActor func setFilter(_ filter: CIFilter) {
        currentFilter = filter
        loadImage()

        filterCount += 1

        if filterCount >= 20 {
            requestReview()

            filterCount = 0
        }
    }
}

#Preview {
    ContentView()
}
