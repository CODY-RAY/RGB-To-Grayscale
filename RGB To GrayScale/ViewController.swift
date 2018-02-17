//
//  ViewController.swift
//  RGB To GrayScale
//
//  Created by cody's macbook on 10/5/17.
//  Copyright © 2017 crank llc. All rights reserved.
//

import UIKit
import Metal
import MetalKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    lazy var device: MTLDevice! = {MTLCreateSystemDefaultDevice()}()
    lazy var defaultLibrary: MTLLibrary! = {self.device.makeDefaultLibrary()}()
    lazy var commandQueue: MTLCommandQueue! = {return self.device.makeCommandQueue()}()
    let queue = DispatchQueue(label: "Com.Ray.Cody")
    var bytesPerPixel = 4
    @IBOutlet weak var imageView: UIImageView!
    var colorImage:UIImage? = nil
    var colorFlag = false
    var pipelineState: MTLComputePipelineState!
    var inTexture: MTLTexture!
    var outTexture: MTLTexture!
    var threadGroups = MTLSizeMake(1, 1, 1)
    let threadGroupSize = MTLSizeMake(16, 16, 1)
    
    @IBOutlet weak var colorButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        queue.async {self.setUp()}
    }

    func setUp() {// Pipeline set up
        if let kernelFunction = defaultLibrary.makeFunction(name: "rgbToGrayScale") {
            do {pipelineState = try device?.makeComputePipelineState(function: kernelFunction) }
            catch {fatalError("wrong name for kernal")}
        }
    }
    
    @IBAction func addImageToView(_ sender: UIButton) {//Actoin to Add pic
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        self.present(picker, animated: true)
        
    }
    @IBAction func rgbToGrayScale(_ sender: UIButton) { // Action for gpu grayscale
        if colorFlag != true {
        if (imageView.image != nil) {
            texture(from: imageView.image!)
            threadGroups = MTLSizeMake(inTexture.width/threadGroupSize.width + 1, inTexture.height/threadGroupSize.height + 1, 1)
            queue.async {
                self.runFilter()
                let finalResult = self.image(from: self.outTexture)
                    DispatchQueue.main.async {
                        self.imageView.image = finalResult
                        self.colorButton.setTitle("color", for: .normal)
                        self.colorFlag = true
                    }
            }}}else{
            imageView.image = colorImage!
            self.colorButton.setTitle("Grayscale", for: .normal)
            colorFlag = false
            }
        
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {// Didn't pick pic
       picker.dismiss(animated: true)
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {// Did pick pic
        if let image = info[UIImagePickerControllerEditedImage] as? UIImage
        {
            imageView.image = image
            colorImage = image
        }
        picker.dismiss(animated: true)
    }
    
    func texture(from image: UIImage)  {// Init in and out texture
        let textureLoader = MTKTextureLoader(device: self.device!)
        do {inTexture = try textureLoader.newTexture(cgImage: image.cgImage!)
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: inTexture.pixelFormat, width: inTexture.width, height: inTexture.height, mipmapped: false)
            device.makeTexture(descriptor: textureDescriptor)
            outTexture = try textureLoader.newTexture(cgImage: image.cgImage!)
            let textureDescriptorOut = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: outTexture.pixelFormat, width: outTexture.width, height: outTexture.height, mipmapped: false)
            device.makeTexture(descriptor: textureDescriptorOut)
        }
        catch {fatalError("Can't load texture")}
    }
    func image(from texture: MTLTexture) -> UIImage { //Texture to image
        let imageByteCount = texture.width * texture.height * bytesPerPixel
        let bytesPerRow = texture.width * bytesPerPixel
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        let region = MTLRegionMake2D(0, 0, texture.width, texture.height)
        texture.getBytes(&src, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerComponent = 8
        let context = CGContext(data: &src, width: texture.width, height: texture.height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow,space: colorSpace,bitmapInfo: bitmapInfo.rawValue)
        let dstImageFilter = context?.makeImage()
        return UIImage(cgImage: dstImageFilter!, scale: 0.0, orientation: UIImageOrientation.up)
    }
    func runFilter() { // Commit to gpu
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        commandEncoder.setComputePipelineState(pipelineState)
        commandEncoder.setTexture(inTexture, index: 0)
        commandEncoder.setTexture(outTexture, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
