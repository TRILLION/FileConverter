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
    
    var inputPath : URL?
    var outputPath : URL?
    
    var count = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.window?.delegate = self

        openPanel.message = "Choose File to Convert..."
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
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        let cb = self.view.window?.standardWindowButton(.closeButton)
        
        cb?.target = self
        cb?.action = #selector(closeAPP)
    }
    
    @objc func closeAPP() {
        NSApp.terminate(self)
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
                    self.inputPath = url
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
                    self.outputPath = url
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
        
        if ((inputPath == nil) || (outputPath == nil)) {
            //输入 输出 如果有一个路径没有 弹出提示
            guard let window = view.window else { return }

            let alert = NSAlert()
            alert.addButton(withTitle: "检查一下")
            alert.messageText = "请检查输入输出文件夹路径，是否成功设置"
            alert.informativeText = "文件夹路径错误"
            alert.beginSheetModal(for: window, completionHandler: nil)
            
            //并返回函数
            return
        }

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
        
        fileName = self.fileList[0].components(separatedBy: ".")[0]
        
        let outputName = fileName + "." + format
        
        let tOutputURL = self.outputPathControl.url!.appendingPathComponent(outputName)
        
        print("tOutputURL : \(tOutputURL)")
        
        self.convert(inputURL: inputURL,
                     outputURL: tOutputURL,
                     options: options,
                     completion:
            { success in
                self.indicator.doubleValue = (self.count - self.fileList.count) / Double(self.count)

                //let str:String = String.init(format:"%.2f", self.indicator.doubleValue)
                //print("总文件数：\(self.count) 剩余文件数：\(self.fileList.count) 完成进度：\(str)%")
                //print("inputURL : \(inputURL)")
                //print("outputURL : \(tOutputURL)")

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
            
            errorList.removeAll()
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
