import Foundation
import CoreML

protocol CoreMLModelProviding {
    func prediction(
        modelName: String,
        inputFeatures: [String: Double],
        outputKey: String
    ) -> Double?
}

/// Generic model provider for dynamically loaded .mlmodelc bundles.
/// The app can ship without compiled models; callers should always provide a fallback score path.
struct DefaultCoreMLModelProvider: CoreMLModelProviding {
    func prediction(
        modelName: String,
        inputFeatures: [String: Double],
        outputKey: String
    ) -> Double? {
        guard let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlmodelc"),
              let model = try? MLModel(contentsOf: modelURL) else {
            return nil
        }

        let valueMap = inputFeatures.mapValues { MLFeatureValue(double: $0) }
        guard let inputProvider = try? MLDictionaryFeatureProvider(dictionary: valueMap),
              let output = try? model.prediction(from: inputProvider) else {
            return nil
        }

        if let outputValue = output.featureValue(for: outputKey)?.doubleValue {
            return outputValue
        }

        // Fallback in case the model exposes only one feature under a different key.
        return output.featureNames.compactMap { output.featureValue(for: $0)?.doubleValue }.first
    }
}
