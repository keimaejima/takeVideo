//
//  MergeVideoViewController.swift
//  PortLounge
//
//  Created by 前島恵 on 2015/10/11.
//  Copyright © 2015年 keimaejima. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import AssetsLibrary
import MediaPlayer
import CoreMedia
import GPUImage
import SpriteKit
import MBCircularProgressBar

class MergeVideoViewController: UIViewController {
    var firstAsset: AVAsset?
    var audioAsset: AVAsset?
    var loadingAssetOne = false
    
    //== フィルター関連
    var movieWriter:GPUImageMovieWriter!
    var movieFile:GPUImageMovie!
    var newFilePath : String!
    //==
    
    var filterNum: Int!
    var bgmNum: Int!
    let filters = TakeMovieHelper.getFilters()
    let bgms = TakeMovieHelper.getBgm()
    
    var fileView = GPUImageView()
    
    var myProgressView: UIProgressView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        //ナビゲーションバーの設定
        self.navigationController?.navigationBar.barTintColor = Colors.baseColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]
        self.title = "動画書き出し中"
        
        self.view.backgroundColor = UIColor.blackColor()
        
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let filePath = (documentDirectory as NSString).stringByAppendingPathComponent("mergeVideo.mp4")
        firstAsset =  (AVURLAsset(URL: NSURL(fileURLWithPath: filePath)))
        audioAsset = (AVAsset(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource(bgms[bgmNum], ofType: "mp3")!)))
        
        myProgressView = UIProgressView(frame: CGRectMake(self.view.frame.width / 2 - (view.frame.width * 2 / 3 / 2), self.view.frame.width / 2, self.view.frame.width * 2 / 3, 10))
        merge()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func savedPhotosAvailable() -> Bool {
        if UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum) == false {
            let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
            return false
        }
        return true
    }
    
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
    
    
    func merge() {
        if let firstAsset = firstAsset {
            //activityMonitor.startAnimating()
            
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
            
            let mainInstruction = AVMutableVideoCompositionInstruction()
            mainInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
            
            let firstInstruction = videoCompositionInstructionForTrack(firstTrack, asset: firstAsset)
            
            mainInstruction.layerInstructions = [firstInstruction]
            let mainComposition = AVMutableVideoComposition()
            mainComposition.instructions = [mainInstruction]
            mainComposition.frameDuration = CMTimeMake(1, 30)
            let videoSize = firstTrack.naturalSize
            mainComposition.renderSize = videoSize
            
            if let loadedAudioAsset = audioAsset {
                let audioTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: 0)
                do {
                    try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, firstAsset.duration),
                        ofTrack: loadedAudioAsset.tracksWithMediaType(AVMediaTypeAudio)[0] ,
                        atTime: kCMTimeZero)
                } catch _ {
                }
            }
            
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
            let savePath = (documentDirectory as NSString).stringByAppendingPathComponent("mergeVideo-conmplete.mp4")
            unlink(savePath)
            let url = NSURL(fileURLWithPath: savePath)
            
            let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
            exporter!.timeRange = CMTimeRangeMake(kCMTimeZero, firstAsset.duration)
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
    }
    
    func exportDidFinish(session: AVAssetExportSession) {
        if session.status == AVAssetExportSessionStatus.Completed {
            let outputURL = session.outputURL
            startFilter(outputURL)
//            let library = ALAssetsLibrary()
//            if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL) {
//                library.writeVideoAtPathToSavedPhotosAlbum(outputURL,
//                    completionBlock: { (assetURL:NSURL!, error:NSError!) -> Void in
//                })
//            }
        }
        
        firstAsset = nil
        audioAsset = nil
    }
    
    func savePhotoAlbum(filePath:String!){
        UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, Selector("filePath:didFinishSavingWithError:contextInfo:"), nil)
    }
    
    //==フィルター関連
    func startFilter(url: NSURL?) {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0]
        let mediaURL : NSURL = url!
        
        //保存用パス
        newFilePath = "\(documentsDirectory)/newTemp.mp4"
        
        //一時保存先を空にしておく
        unlink(newFilePath)
        let movieURL = NSURL(fileURLWithPath: newFilePath!)
        self.movieWriter = GPUImageMovieWriter(movieURL: movieURL, size: CGSize(width: 480, height: 480))
        //"Couldn't write a frame" エラーが出ないための一行
        //self.movieWriter.assetWriter.movieFragmentInterval = kCMTimeInvalid
        self.movieWriter.shouldPassthroughAudio = true
        movieWriter.encodingLiveVideo = true
        
        
        movieFile = GPUImageMovie(URL: mediaURL)
        movieFile.playAtActualSpeed = false
        movieFile.audioEncodingTarget = movieWriter!
        
        let filter = filters[filterNum]
        filter.addTarget(movieWriter)
        movieFile.addTarget(filter)
        fileView.frame = CGRectMake(0, self.view.frame.width / 4, self.view.frame.width, self.view.frame.width)
        filter.addTarget(fileView)
        self.view.addSubview(fileView)
        
        myProgressView.transform = CGAffineTransformMakeScale(1.0, 4.0)
        myProgressView.layer.cornerRadius = 10
        myProgressView.progressTintColor = UIColor.whiteColor()
        myProgressView.trackTintColor = UIColor.blackColor()
        myProgressView.progress = 0.0
        self.view.addSubview(myProgressView)
        
        movieFile.startProcessing()
        movieWriter.startRecording()
        print("started")
        _ = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("printProgress"), userInfo: nil, repeats: false)
    }
    
    func printProgress(){
        //規定のレンダリング時間に達するまでは0.5秒に一度進捗を監視する
        //        barView.p= CGFloat(movieFile.progress*100)
        print(movieFile.progress)
        myProgressView.progress = movieFile.progress
        if(movieFile.progress >= 1){
            stopFilter()
        }else{
            _ = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: Selector("printProgress"), userInfo: nil, repeats: false)
        }
    }
    
    func stopFilter() {
        movieWriter!.finishRecording()
        savePhotoAlbum(newFilePath)
        print("completed")
        let controller = PostVideoViewController()
        controller.filePath = newFilePath
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
    func filePath(filePath: String!, didFinishSavingWithError: NSError, contextInfo:UnsafePointer<Void>)       {
        
        if (didFinishSavingWithError as NSError? != nil) {
            print("error")
        } else {
            unlink(newFilePath)
            print("success!")
        }
    }
    
    
}
