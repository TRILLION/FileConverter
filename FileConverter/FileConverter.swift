//
//  FileConverter
//
//  Created by Ryan Francesconi, revision history on Githbub.
//  Copyright © 2017 Ryan Francesconi. All rights reserved.
//

import AudioKit
import Cocoa

/// Simple interface to show AKConverter
class FileConverter: NSViewController {
    @IBOutlet var inputPathControl: NSPathControl!
    @IBOutlet weak var outputPathControl: NSPathControl!
    @IBOutlet var formatPopUp: NSPopUpButton!
    @IBOutlet var sampleRatePopUp: NSPopUpButton!
    @IBOutlet var bitDepthPopUp: NSPopUpButton!
    @IBOutlet var bitRatePopUp: NSPopUpButton!
    @IBOutlet var channelsPopUp: NSPopUpButton!
    let openPanel = NSOpenPanel()
    let savePanel = NSSavePanel()

    @IBOutlet weak var indicator: NSProgressIndicator!
    @IBOutlet weak var convertBtn: NSButton!
    
    var fileList = Array<String>()
    var errorList = Array<String>()

    var count = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.window?.delegate = self

        openPanel.message = "Choose File to Convert..."
        //openPanel.allowedFileTypes = AKConverter.inputFormats
        openPanel.canChooseDirectories = true

        for outType in AKConverter.outputFormats {
            formatPopUp.addItem(withTitle: outType)
        }

        savePanel.message = "Save As..."
        savePanel.allowedFileTypes = AKConverter.outputFormats
        savePanel.isExtensionHidden = false

        sampleRatePopUp.selectItem(withTitle: "44100")
        
        self.indicator.startAnimation(nil)
    }

    @IBAction func openDocument(_ sender: Any) {
        chooseAudio(sender)
    }

    @IBAction func chooseAudio(_ sender: Any) {
        guard let window = view.window else { return }

        openPanel.beginSheetModal(for: window, completionHandler: { response in
            if response == NSApplication.ModalResponse.OK {
                if let url = self.openPanel.url {
                    self.inputPathControl.url = url
                }
            }
        })
    }

    @IBAction func chooseOutput(_ sender: Any) {
        guard let window = view.window else { return }
        
        openPanel.beginSheetModal(for: window, completionHandler: { response in
            if response == NSApplication.ModalResponse.OK {
                if let url = self.openPanel.url {
                    self.outputPathControl.url = url
                }
            }
        })
        
    }
    
    @IBAction func handleFormatSelection(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        let isCompressed = title == "m4a"
        bitDepthPopUp.isHidden = isCompressed
        bitRatePopUp.isHidden = !isCompressed
    }

    @IBAction func convertAudio(_ sender: NSButton) {

        if FileManager.default.fileExists(atPath: inputPathControl.url!.path) {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: inputPathControl.url!.path)
                if files.count > 0 {
                    fileList = files
                    if fileList.contains(".DS_Store") {
                        let index = fileList.firstIndex(of: ".DS_Store")
                        fileList.remove(at: index!)
                    }
                    self.count = fileList.count;
                    print("fileList:  \(fileList)")
                }
                self.covertPro()
            } catch {
            }
        }

    }

    func covertPro() {
        
        self.convertBtn.isEnabled = false
        
        var options = AKConverter.Options()

        guard let format = formatPopUp.selectedItem?.title else { return }
        options.format = format

        if let sampleRate = sampleRatePopUp.selectedItem?.title {
            options.sampleRate = Double(sampleRate)
        }
        if let bitDepth = bitDepthPopUp.selectedItem?.title {
            options.bitDepth = UInt32(bitDepth)
        }
        if let bitRate = bitRatePopUp.selectedItem?.title {
            let br = UInt32(bitRate) ?? 256
            options.bitRate = br * 1_000
        }
        if let channels = channelsPopUp.selectedItem?.title {
            options.channels = UInt32(channels)
        }

        var fileName = self.fileList[0]

        guard let inputURL = inputPathControl.url?.appendingPathComponent(fileName) else { return }

//        let basepath = inputURL.deletingPathExtension().deletingLastPathComponent()
        //let basename = inputURL.deletingPathExtension().lastPathComponent

        fileName = self.fileList[0].components(separatedBy: ".")[0]

//        savePanel.directoryURL = basepath
//        savePanel.nameFieldStringValue = fileName + "." + format
        
        let outputName = fileName + "." + format
        
        let tOutputURL = self.outputPathControl.url!.appendingPathComponent(outputName)
        
        print("tOutputURL : \(tOutputURL)")
        
        self.convert(inputURL: inputURL,
                     outputURL: tOutputURL,
                     options: options,
                     completion:
            { success in
                self.indicator.doubleValue = (self.count - self.fileList.count) / Double(self.count)

                let str:String = String.init(format:"%.2f", self.indicator.doubleValue)

                print("总文件数：\(self.count) 剩余文件数：\(self.fileList.count) 完成进度：\(str)%")
                
                print("inputURL : \(inputURL)")
                print("outputURL : \(tOutputURL)")
                if success {
                    print(tOutputURL.lastPathComponent + " - has been OK")
                } else {
                    print(tOutputURL.lastPathComponent + " - fail")
                    self.errorList.append(tOutputURL.lastPathComponent)
                }
                self.fileList.remove(at: 0)
                if self.fileList.count > 0 {
                    self.covertPro()
                } else {
                    self.indicator.doubleValue = 1
                    self.convertBtn.isEnabled = true
                    self.showErrors()
                }
        })
//            }
//        })

    }

    private func convert(inputURL: URL, outputURL: URL, options: AKConverter.Options,
                         completion: @escaping (Bool) -> Void) {

        DispatchQueue.global().async {
            let converter = AKConverter(inputURL: inputURL, outputURL: outputURL, options: options)

            converter.start(completionHandler: { error in

                var success = true

                if let error = error {
                    AKLog("Error during convertion: \(error)")
                    success = false
                } else {
                    //AKLog("Conversion Complete!")
                }

                DispatchQueue.main.async {
                    completion(success)
                }
            })
        }
    }
    
    func showErrors() {
        print("error for : \(errorList)")
        
        if errorList.count > 0 {
            (errorList as NSArray).write(to: (outputPathControl.url?.appendingPathComponent("error.plist"))!, atomically: true)
            
            guard let window = view.window else { return }

            let alert = NSAlert()
            alert.addButton(withTitle: "OK")
            alert.messageText = "呜呜呜 有文件转码错误 请查看 error.plist"
            alert.informativeText = "个别文件错误"
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
}

/// Handle Window Events
extension FileConverter: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // AudioKit.stop()
        exit(0)
    }
}

////
////  FileConverter
////
////  Created by Ryan Francesconi, revision history on Githbub.
////  Copyright © 2017 Ryan Francesconi. All rights reserved.
////
//
//import AudioKit
//import Cocoa
//
///// Simple interface to show AKConverter
//class FileConverter: NSViewController {
//    @IBOutlet var inputPathControl: NSPathControl!
//    @IBOutlet var formatPopUp: NSPopUpButton!
//    @IBOutlet var sampleRatePopUp: NSPopUpButton!
//    @IBOutlet var bitDepthPopUp: NSPopUpButton!
//    @IBOutlet var bitRatePopUp: NSPopUpButton!
//    @IBOutlet var channelsPopUp: NSPopUpButton!
//    let openPanel = NSOpenPanel()
//    let savePanel = NSSavePanel()
//
//    var fileList = Array<String>()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.window?.delegate = self
//
//        openPanel.message = "Choose File to Convert..."
//        //openPanel.allowedFileTypes = AKConverter.inputFormats
//        openPanel.canChooseDirectories = true
//
//        for outType in AKConverter.outputFormats {
//            formatPopUp.addItem(withTitle: outType)
//        }
//
//        savePanel.message = "Save As..."
//        savePanel.allowedFileTypes = AKConverter.outputFormats
//        savePanel.isExtensionHidden = false
//
//        sampleRatePopUp.selectItem(withTitle: "44100")
//    }
//
//    @IBAction func openDocument(_ sender: Any) {
//        chooseAudio(sender)
//    }
//
//    @IBAction func chooseAudio(_ sender: Any) {
//        guard let window = view.window else { return }
//
//        openPanel.beginSheetModal(for: window, completionHandler: { response in
//            if response == NSApplication.ModalResponse.OK {
//                if let url = self.openPanel.url {
//                    self.inputPathControl.url = url
//                }
//            }
//        })
//    }
//
//    @IBAction func handleFormatSelection(_ sender: NSPopUpButton) {
//        guard let title = sender.selectedItem?.title else { return }
//        let isCompressed = title == "m4a"
//        bitDepthPopUp.isHidden = isCompressed
//        bitRatePopUp.isHidden = !isCompressed
//    }
//
//    @IBAction func convertAudio(_ sender: NSButton) {
//
//        if FileManager.default.fileExists(atPath: self.openPanel.url!.path) {
//            do {
//                let files = try FileManager.default.contentsOfDirectory(atPath: self.openPanel.url!.path)
//                if files.count > 0 {
//                    fileList = files
//                    if fileList.contains(".DS_Store") {
//                        let index = fileList.firstIndex(of: ".DS_Store")
//                        fileList.remove(at: index!)
//                    }
//                    print("fileList:  \(fileList)")
//                }
//                self.covertPro()
//            } catch {
//            }
//        }
//
//    }
//
//    func covertPro() {
////            guard let window = view.window else { return }
//
////        print("fileName is : \(fileName)")
////
////        print("self.savePanel.url is : \(self.savePanel.url)")
//
////        //let basepath = inputURL.deletingPathExtension().deletingLastPathComponent()
////        //let basename = inputURL.deletingPathExtension().lastPathComponent
////        let basepath = inputURL.appendingPathComponent(self.fileList[0])
////
////        print("basepath : \(basepath)")
////
//////        savePanel.directoryURL = basepath
////        //savePanel.nameFieldStringValue = basename + "_converted." + format
////
////        let fileName = self.fileList[0].components(separatedBy: ".")[0] + "." + format
////
////        print("fileName : \(fileName)")
////
////        let outputPath = inputURL.appendingPathComponent(fileName)
////
////        print("outputPath : \(outputPath)")
//
////        let tInputURL = URL.init(fileURLWithPath: "/Users/trillion/Desktop/convertTest/chuang_cut_A3.wav")
////        let tOutputURL = URL.init(fileURLWithPath: "/Users/trillion/Desktop/convertTest/chuang_cut_A3_converted.m4a")
////
////        self.convert(inputURL: tInputURL, outputURL: tOutputURL, options: options)
//
//
//
//
//        savePanel.begin { response in
//            self.actionFunc()
//        }
//
//    }
//    func actionFunc() {
//        var options = AKConverter.Options()
//
//        guard let format = formatPopUp.selectedItem?.title else { return }
//        options.format = format
//
//        if let sampleRate = sampleRatePopUp.selectedItem?.title {
//            options.sampleRate = Double(sampleRate)
//        }
//        if let bitDepth = bitDepthPopUp.selectedItem?.title {
//            options.bitDepth = UInt32(bitDepth)
//        }
//        if let bitRate = bitRatePopUp.selectedItem?.title {
//            let br = UInt32(bitRate) ?? 256
//            options.bitRate = br * 1_000
//        }
//        if let channels = channelsPopUp.selectedItem?.title {
//            options.channels = UInt32(channels)
//        }
//
//        var fileName = self.fileList[0]
//
//        guard let inputURL = inputPathControl.url?.appendingPathComponent(fileName) else { return }
//
//        let basepath = inputURL.deletingPathExtension().deletingLastPathComponent()
//        //let basename = inputURL.deletingPathExtension().lastPathComponent
//
//        fileName = self.fileList[0].components(separatedBy: ".")[0]
//
//        savePanel.directoryURL = basepath
//        savePanel.nameFieldStringValue = fileName + "." + format
//
//        if let url = self.savePanel.url {
//
//            self.convert(inputURL: inputURL, outputURL: url, options: options, completion: {
//                success in
//
//                print("inputURL : \(inputURL)")
//                print("outputURL : \(self.savePanel.url!)")
//                if success {
//                    print(self.savePanel.url!.lastPathComponent + " - has been OK")
//                } else {
//                    print(self.savePanel.url!.lastPathComponent + " - fail")
//                }
//                self.fileList.remove(at: 0)
//                if self.fileList.count > 0 {
//                    self.actionFunc()
//                }
//            })
//
//        }
//    }
//
//    private func convert(inputURL: URL, outputURL: URL, options: AKConverter.Options,
//                         completion: @escaping (Bool) -> Void) {
//
//        DispatchQueue.global().async {
//            let converter = AKConverter(inputURL: inputURL, outputURL: outputURL, options: options)
//
//            converter.start(completionHandler: { error in
//
//                var success = true
//
//                if let error = error {
//                    AKLog("Error during convertion: \(error)")
//                    success = false
//                } else {
//                    //AKLog("Conversion Complete!")
//                }
//
//                DispatchQueue.main.async {
//                    completion(success)
//                }
//            })
//        }
//    }
//}
//
///// Handle Window Events
//extension FileConverter: NSWindowDelegate {
//    func windowWillClose(_ notification: Notification) {
//        // AudioKit.stop()
//        exit(0)
//    }
//}
