//
//  ViewController.swift
//  DailyMemories
//
//  Created by Meghan Kane on 9/3/17.
//  Copyright © 2017 Meghan Kane. All rights reserved.
//

import UIKit
import Vision
import CoreML



class ViewController: UIViewController {

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var captionLabel: UILabel!
    @IBOutlet var cameraButton: UIButton!
    
    let imagePickerController = UIImagePickerController()
    let formatter = DateFormatter()
    
    let tintColor = UIColor(red: 255/255, green: 8/255, blue: 127/255, alpha: 1)
    
    var currentDateString: String {
        let now = Date()
        return formatter.string(from:now)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.layer.cornerRadius = 10
        imagePickerController.delegate = self
        
        formatter.dateFormat = "MMM dd, YYYY"
        
        cameraButton.backgroundColor = tintColor
        cameraButton.layer.cornerRadius = 50
        
        imageView.layer.cornerRadius = 10
        imageView.clipsToBounds = true
        
        captionLabel.font = UIFont(name: "ArialRoundedMTBold", size: 20)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        dateLabel.text = ""
    }
    
    
    @IBAction func takePhoto() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            imagePickerController.sourceType = .camera
            imagePickerController.cameraDevice = .rear
        }
        
        imagePickerController.allowsEditing = true
        present(imagePickerController, animated: true, completion: nil)
    }
    
    // 👀🤖 VISION + CORE ML WORK STARTS HERE
    private func classifyScene(from image: UIImage) {
        
        let model = GoogLeNetPlaces()
        guard let visionCoreMLModel = try? VNCoreMLModel(for: model.model) else { return }
        
        let sceneClassificationRequest = VNCoreMLRequest(model: visionCoreMLModel, completionHandler: handleClassificationResults)
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: handleFaceDetectionResults)
        
        guard let cgImage = image.cgImage else {
            fatalError("Unable to convert \(image) to CGImage.")
        }
        
        let cgImageOrientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))!
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgImageOrientation)
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([faceDetectionRequest, sceneClassificationRequest])
            } catch {
                print("Error performing scene classification")
            }
        }
    }
    
    private func handleFaceDetectionResults(request: VNRequest, error: Error?) {
        
        DispatchQueue.main.async {
            self.imageView.subviews.forEach { $0.removeFromSuperview() }
            request.results?.flatMap { $0 as? VNFaceObservation }.forEach { self.addFaceBoxView(faceBoundingBox: $0.boundingBox) }
        }
    }
    
    
    
    private func addFaceBoxView(faceBoundingBox: CGRect) {
        let boxViewFrame = transformRect(visionRect: faceBoundingBox, imageViewRect: imageView.frame).insetBy(dx: -20, dy: -20)
        let borderFrame = CGRect(x: 0, y: 0, width: boxViewFrame.width, height: boxViewFrame.height)
        
        let border = CAShapeLayer()
        border.strokeColor = tintColor.cgColor
        border.lineCap = kCALineCapRound
        border.lineJoin = kCALineJoinRound
        border.lineWidth = 5
        border.lineDashPattern = [5, 10]
        border.frame = borderFrame
        border.fillColor = nil
        border.path = UIBezierPath(ovalIn: borderFrame).cgPath
        
        let faceBoxView = UIView()
        faceBoxView.frame = boxViewFrame
        faceBoxView.layer.addSublayer(border)
        
        imageView.addSubview(faceBoxView)
    }
    
    private func transformRect(visionRect: CGRect , imageViewRect: CGRect) -> CGRect {
        
        var mappedRect = CGRect()
        mappedRect.size.width = visionRect.size.width * imageViewRect.size.width
        mappedRect.size.height = visionRect.size.height * imageViewRect.size.height
        mappedRect.origin.y = imageViewRect.height - imageViewRect.height * visionRect.origin.y
        mappedRect.origin.y  = mappedRect.origin.y -  mappedRect.size.height
        mappedRect.origin.x =  visionRect.origin.x * imageViewRect.size.width
        
        return mappedRect
    }
    
    // 5. Do something with the results
    // - Update the caption label
    // - Ensure that it is dispatched on the main queue, because we are updating the UI
    private func handleClassificationResults(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let classifications = request.results as? [VNClassificationObservation],
                classifications.isEmpty != true else {
                    self.captionLabel.text = "Unable to classify scene.\n\(error!.localizedDescription)"
                    return
            }
            self.updateCaptionLabel(classifications)
        }
    }
    
    private func showRecognitionFailureAlert() {
        let alertController = UIAlertController.init(title: "Recognition Failure", message: "Please try another image.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction.init(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // MARK: Helper methods
    
    private func updateCaptionLabel(_ classifications: [VNClassificationObservation]) {
        let topTwoClassifications = [classifications.first!, classifications.last!]

        let descriptions = [
            "Probably a \(topTwoClassifications[0].identifier.replacingOccurrences(of: "_", with: " ")) 🤔",
            "Not a \(topTwoClassifications[1].identifier.replacingOccurrences(of: "_", with: " ")) 🤷‍♀️"
        ]
        captionLabel.text = descriptions.joined(separator: "\n")
    }
    
    private func convertToCGImageOrientation(from uiImage: UIImage) -> CGImagePropertyOrientation {
        let cgImageOrientation = CGImagePropertyOrientation(rawValue: UInt32(uiImage.imageOrientation.rawValue))!
        return cgImageOrientation
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let imageSelected = info[UIImagePickerControllerEditedImage] as? UIImage {
            self.imageView.image = imageSelected
            
            // Kick off Vision + Core ML task with image as input 🚀
            classifyScene(from: imageSelected)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}
