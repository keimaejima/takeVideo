//
//  SelectFilterViewController.swift
//  PortLounge
//
//  Created by 前島恵 on 2015/10/10.
//  Copyright © 2015年 keimaejima. All rights reserved.
//

import UIKit
import GPUImage
import AssetsLibrary
import AVFoundation

class EditVideoViewController: UIViewController, AVAudioPlayerDelegate {
    //フィルターの種類を定義
    //TODO:この時点で動画を連結させる仕様にする
    var firstAsset: AVAsset?
    var secondAsset: AVAsset?
    var thirdAsset: AVAsset?
    
    let operationQueue = NSOperationQueue()
    var operation: NSBlockOperation!
    
    let filters = TakeMovieHelper.getFilters()
    let bgms = TakeMovieHelper.getBgm()
    
    var movieFile:GPUImageMovie!
    
    var fileView = GPUImageView()
    
    private var myController = UIView()
    let controller1: SelectFilterViewController = SelectFilterViewController()
    let controller2: SelectBgmViewController = SelectBgmViewController()
    
    var myAudioPlayer : AVAudioPlayer!
    
    var filterNum = 0
    var bgmNum = 0
    
    var mergedPath: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.blackColor()
        
        //ナビゲーションバーの設定
        self.navigationController?.navigationBar.barTintColor = Colors.baseColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.title = "動画編集"
        
        let nextBtn:UIButton = UIButton(type: UIButtonType.Custom)
        nextBtn.frame = CGRectMake(0, 0, 30, 30)
        nextBtn.setTitle("次へ＞", forState: .Normal)
        nextBtn.addTarget(self, action: "pushNext", forControlEvents: .TouchUpInside)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: nextBtn)
        
        //==動画マージ関連
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        let filePath : String! = "\(documentsDirectory)/video0.mp4"
        firstAsset =  (AVURLAsset(URL: NSURL(fileURLWithPath: filePath)))
        let filePath2 : String! = "\(documentsDirectory)/video1.mp4"
        secondAsset = (AVURLAsset(URL: NSURL(fileURLWithPath: filePath2)))
        let filePath3 : String! = "\(documentsDirectory)/video2.mp4"
        thirdAsset = (AVURLAsset(URL: NSURL(fileURLWithPath: filePath3)))
        self.mergedPath = merge()
        //==動画マージ関連
        
        let navBarHeight = self.navigationController?.navigationBar.frame.size.height
        //動画表示用ビュー
        fileView.frame = CGRectMake(0, navBarHeight!, self.view.frame.width, self.view.frame.width)
        
        //動画ソース
        self.operation = NSBlockOperation {
            let mediaURL : NSURL = NSURL(fileURLWithPath: self.mergedPath)
            self.movieFile = GPUImageMovie(URL: mediaURL)
            self.movieFile.playAtActualSpeed = true
            
            //初期のフィルター番号を定義
            let filter = self.filters[0]
            filter.removeAllTargets()
            filter.addTarget(self.fileView)
            self.movieFile.removeAllTargets()
            self.movieFile.addTarget(filter)
            self.movieFile.shouldRepeat = true
            self.movieFile.startProcessing()
        }
        
        //ビューに追加
        self.view.addSubview(fileView)
        
        //再生する音源のURLを生成.
        let soundFilePath : NSString = NSBundle.mainBundle().pathForResource(bgms[0], ofType: "mp3")!
        let fileURL : NSURL = NSURL(fileURLWithPath: soundFilePath as String)
        myAudioPlayer = try? AVAudioPlayer(contentsOfURL: fileURL)
        myAudioPlayer.delegate = self
        myAudioPlayer.play()
        //個別のタブを生成
        controller1.title = "フィルター"
        controller1.parent = self
        controller2.title = "BGM"
        controller2.parent = self
        
        // 表示する配列を作成する.
        let myArray: NSArray = ["フィルター","BGM"]
        
        // SegmentedControlを作成する.
        let mySegcon: UISegmentedControl = UISegmentedControl(items: myArray as [AnyObject])
        mySegcon.frame = CGRectMake(0, navBarHeight! + self.view.frame.width + 20, self.view.frame.width, 50)
        mySegcon.backgroundColor = UIColor.blackColor()
        mySegcon.tintColor = UIColor.whiteColor()
        // イベントを追加する.
        mySegcon.addTarget(self, action: "segconChanged:", forControlEvents: UIControlEvents.ValueChanged)
        mySegcon.selectedSegmentIndex = 0
        myController.frame = CGRectMake(0,navBarHeight! + self.view.frame.width + 70, self.view.frame.width, 200)
        myController.addSubview(controller1.view)
        controller2.view.hidden = true
        myController.addSubview(controller2.view)
        
        // Viewに追加する.
        self.view.addSubview(mySegcon)
        self.view.addSubview(myController)
    }
    
    internal func segconChanged(segcon: UISegmentedControl){
        
        switch segcon.selectedSegmentIndex {
        case 0:
            controller1.view.hidden = false
            controller2.view.hidden = true

        case 1:
            controller1.view.hidden = true
            controller2.view.hidden = false
            
        default:
            print("Error")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func pushNext() {
        myAudioPlayer.pause()
        let controller = MergeVideoViewController()
        controller.filterNum = self.filterNum
        controller.bgmNum = self.bgmNum
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func pushFilter(filterNum: Int) {
        let filter = filters[filterNum]
        filter.removeAllTargets()
        filter.addTarget(fileView)
        movieFile.removeAllTargets()
        movieFile.addTarget(filter)
        self.filterNum = filterNum
    }
    
    func pushBgm(bgmNum: Int) {
        myAudioPlayer.pause()
        let soundFilePath : NSString = NSBundle.mainBundle().pathForResource(bgms[bgmNum], ofType: "mp3")!
        let fileURL : NSURL = NSURL(fileURLWithPath: soundFilePath as String)
        myAudioPlayer = try? AVAudioPlayer(contentsOfURL: fileURL)
        myAudioPlayer.delegate = self
        myAudioPlayer.play()
        self.bgmNum = bgmNum
    }
    
    //デコード中にエラーが起きた時に呼ばれるメソッド.
    func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {
        print("Error")
    }
    
    //＝＝ビデオマージ関連
    func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
        var assetOrientation = UIImageOrientation.Up
        var isPortrait = false
        if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
            assetOrientation = .Right
            isPortrait = true
        } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
            assetOrientation = .Left
            isPortrait = true
        } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
            assetOrientation = .Up
        } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
            assetOrientation = .Down
        }
        return (assetOrientation, isPortrait)
    }
    
    func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset) -> AVMutableVideoCompositionLayerInstruction {
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        
        let transform = assetTrack.preferredTransform
        let assetInfo = orientationFromTransform(transform)
        
        //var scaleToFitRatio = UIScreen.mainScreen().bounds.width / assetTrack.naturalSize.width
        let scaleToFitRatio = CGFloat(1)
        if assetInfo.isPortrait {
            let scaleToFitRatio = CGFloat(1)
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            instruction.setTransform(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor),
                atTime: kCMTimeZero)
        } else {
            let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
            var concat = CGAffineTransformConcat(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor), CGAffineTransformMakeTranslation(0, 0))
            if assetInfo.orientation == .Down {
                let fixUpsideDown = CGAffineTransformMakeRotation(CGFloat(M_PI))
                let yFix = assetTrack.naturalSize.height
                let centerFix = CGAffineTransformMakeTranslation(assetTrack.naturalSize.width, yFix)
                concat = CGAffineTransformConcat(CGAffineTransformConcat(fixUpsideDown, centerFix), scaleFactor)
            }
            instruction.setTransform(concat, atTime: kCMTimeZero)
        }
        
        return instruction
    }
    
    
    func merge() -> String {
        var savePath:String!
        if let firstAsset = firstAsset, secondAsset = secondAsset, thirdAsset = thirdAsset {
            //activityMonitor.startAnimating()
            print(secondAsset)
            let mixComposition = AVMutableComposition()
            
            // 2 - Create two video tracks
            let firstTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            do {
                try firstTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration),
                    ofTrack: firstAsset.tracksWithMediaType(AVMediaTypeVideo)[0] ,
                    atTime: kCMTimeZero)
            } catch _ {
            }
            
            let secondTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            do {
                try secondTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, secondAsset.duration),
                    ofTrack: secondAsset.tracksWithMediaType(AVMediaTypeVideo)[0] ,
                    atTime: firstAsset.duration)
            } catch _ {
            }
            
            let thirdTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo,
                preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            do {
                try thirdTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, thirdAsset.duration),
                    ofTrack: thirdAsset.tracksWithMediaType(AVMediaTypeVideo)[0] ,
                    atTime: CMTimeAdd(firstAsset.duration ,secondAsset.duration))
            } catch _ {
            }
            
            
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, CMTimeAdd(secondAsset.duration, thirdAsset.duration)))
            
            let firstInstruction = videoCompositionInstructionForTrack(firstTrack, asset: firstAsset)
            let secondInstruction = videoCompositionInstructionForTrack(secondTrack, asset: secondAsset)
            let thirdInstruction = videoCompositionInstructionForTrack(thirdTrack, asset: thirdAsset)
            
            mainInstruction.layerInstructions = [firstInstruction, secondInstruction, thirdInstruction]
            let mainComposition = AVMutableVideoComposition()
            mainComposition.instructions = [mainInstruction]
            mainComposition.frameDuration = CMTimeMake(1, 30)
            let videoSize = firstTrack.naturalSize
            mainComposition.renderSize = videoSize
            
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            savePath = (documentDirectory as NSString).stringByAppendingPathComponent("mergeVideo.mp4")
            print(savePath)
            unlink(savePath)
            let url = NSURL(fileURLWithPath: savePath)
            
            //let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
            let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
            exporter!.timeRange = CMTimeRangeMake(kCMTimeZero, CMTimeAdd(firstAsset.duration, CMTimeAdd(secondAsset.duration, thirdAsset.duration)))
            exporter!.outputURL = url
            //exporter!.outputFileType = AVFileTypeQuickTimeMovie
            exporter!.outputFileType = AVFileTypeMPEG4
            exporter!.shouldOptimizeForNetworkUse = true
            exporter!.videoComposition = mainComposition
            
            exporter!.exportAsynchronouslyWithCompletionHandler() {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    print("proseed!")
                    self.exportDidFinish(exporter!)
                })
            }
        }
        return savePath
    }
    
    func exportDidFinish(session: AVAssetExportSession) {
//        if session.status == AVAssetExportSessionStatus.Completed {
//            let outputURL = session.outputURL
//            let library = ALAssetsLibrary()
//            if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL) {
//                library.writeVideoAtPathToSavedPhotosAlbum(outputURL,
//                    completionBlock: { (assetURL:NSURL!, error:NSError!) -> Void in
//                        var title = ""
//                        var message = ""
//                        if error != nil {
//                            title = "Error"
//                            message = "Failed to save video"
//                        } else {
//                            title = "Success"
//                            message = "Video saved"
//                        }
//                        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
//                        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
//                        self.presentViewController(alert, animated: true, completion: nil)
//                        self.operationQueue.addOperation(self.operation)
//                })
//            }
//        }
        self.operationQueue.addOperation(self.operation)
        firstAsset = nil
        secondAsset = nil
        thirdAsset = nil
    }
}
