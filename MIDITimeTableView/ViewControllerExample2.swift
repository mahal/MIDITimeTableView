//
//  ViewControllerExample2.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 24.04.18.
//  Copyright © 2018 Raskin Software LLC. All rights reserved.
//

import UIKit
import AudioKit

// class that displays the note-name (like C6)
class HeaderCellView2: MIDITimeTableHeaderCellView {
    var titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    convenience init(title: String) {
        self.init(frame: .zero)
        commonInit()
        titleLabel.text = title
    }
    
    func commonInit() {
        addSubview(titleLabel)
        backgroundColor = UIColor(red: 36.0/255.0, green: 40.0/255.0, blue: 41.0/255.0, alpha: 1)
        titleLabel.textColor = UIColor(red: 216.0/255.0, green: 214.0/255.0, blue: 217.0/255.0, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 5)
        titleLabel.lineBreakMode = .byWordWrapping
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = CGRect(origin: .zero, size: frame.size)
    }
}

// class that displays single notes
class CellView2: MIDITimeTableCellView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        backgroundColor = UIColor.orange
        layer.masksToBounds = true
        layer.cornerRadius = 3.5/2
    }
    
    override func didLongPress(longPress: UILongPressGestureRecognizer) {
        // nop. overwrite as we don't need it
    }
    
    override func didTap(tap: UITapGestureRecognizer) {
        // nop. overwrite as we don't need it
    }
    
    override func didMove(pan: UIPanGestureRecognizer) {
        // nop. overwrite as we don't need it
    }
    
    override func didResize(pan: UIPanGestureRecognizer) {
        // nop. overwrite as we don't need it
    }
    
}


// view controller for the second example with a piano roll
class ViewControllerExample2: UIViewController, MIDITimeTableViewDataSource, MIDITimeTableViewDelegate, UIScrollViewDelegate {
    
    @IBOutlet weak var pianoRollView: MIDITimeTablePianoRollView?
    private var pianoPlayScrollAnimator : UIViewPropertyAnimator?
    private var updateIntervalTimer : Timer?
    private var isDragInProgress = false
    private var lastSequencerUpdatedWhileDragTimestamp = Date.init()
    private var lastRelativeDragPosition = 0.0
    private var isPlaying = false
    lazy var midiNoteData : [MIDITimeTableRowData] = {
        Conductor.shared().sequencer.midiTimeTableRowData();
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        Conductor.shared().midiFileName = "chromatik"
        Conductor.shared().loadMelody()
        setupPianoRollView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        Conductor.shared().sequencer.stop()
    }
    
    func setupPianoRollView() {
        pianoRollView?.delegate = self
        pianoRollView?.dataSource = self
        pianoRollView?.timeTableDelegate = self
        pianoRollView?.gridLayer.showsSubbeatLines = false
        pianoRollView?.showsGrid = false
        pianoRollView?.showsRangeHead = false
        pianoRollView?.measureWidth = 100.0
        pianoRollView?.maxMeasureWidth = 200.0
        pianoRollView?.minMeasureWidth = 10.0
        pianoRollView?.reloadData()
    }
    
    @objc func updatePlayheadPosition() {
        
      
    }
    
    @IBAction func play(_ sender: Any) {
        let sequencer = Conductor.shared().sequencer
        sequencer.play()
        //let durationInSec = (sequencer.tempo / 60) * sequencer.length().beats
        var durationInSec = sequencer.seconds(duration:sequencer.length)
        durationInSec = durationInSec / sequencer.rate
        isPlaying = true
        
        pianoPlayScrollAnimator = UIViewPropertyAnimator(duration: durationInSec, curve: UIViewAnimationCurve.linear, animations: {
            self.pianoRollView?.contentOffset.x = (self.pianoRollView?.contentSize.width)!
        })
        
        pianoPlayScrollAnimator?.startAnimation()
        
        
        /*DispatchQueue.main.async() {
            UIView.animate(withDuration: durationInSec, delay: 0, options: UIViewAnimationOptions.curveLinear, animations: {
                self.pianoRollView?.contentOffset.x = (self.pianoRollView?.contentSize.width)!
            }, completion: nil)
        }*/
    }
    
    @IBAction func stop(_ sender: Any) {
        isPlaying = false
        pianoPlayScrollAnimator?.stopAnimation(true)
        stopUpdatePlaheadTimer()
        Conductor.shared().sequencer.stop()
        Conductor.shared().sequencer.rewind()
    }
    
    @IBAction func tempoChanged(_ sender: UISlider) {
        let newValue: Float = sender.value
        let sequencer = Conductor.shared().sequencer 
        sequencer.setRate(Double(newValue))
        if (pianoPlayScrollAnimator != nil && (pianoPlayScrollAnimator?.isRunning)!) {
            pianoPlayScrollAnimator?.pauseAnimation()
            let relativePosition = sequencer.currentRelativePosition
            // var durationFactor = durationInSec / ( ( durationInSec / newValue ) -  (durationInSec / newValue) * relativePosition  )
            let durationFactor = newValue / ( -relativePosition + 1)
            pianoPlayScrollAnimator?.continueAnimation(withTimingParameters: UICubicTimingParameters.init(animationCurve: UIViewAnimationCurve.linear), durationFactor: CGFloat(1/durationFactor))
        }
    }
    
  func startUpdatePlayheadTimer() {
    updateIntervalTimer = Timer.scheduledTimer(
      timeInterval: 0.1,
      target: self,
      selector: #selector(updatePlayheadPosition),
      userInfo: nil,
      repeats: true)
  }
  
  func stopUpdatePlaheadTimer() {
    updateIntervalTimer?.invalidate()

  }
  
    // MARK: MIDITimeTableViewDataSource
    
    func numberOfRows(in midiTimeTableView: MIDITimeTableViewBase) -> Int {
        return midiNoteData.count
    }
    
    func timeSignature(of midiTimeTableView: MIDITimeTableViewBase) -> MIDITimeTableTimeSignature {
        // TODO: if there are several signatures: just show beats and no bars
        let akTimeSig = Conductor.shared().sequencer.getTimeSignature(at:0)
        var bottomValue = MIDITimeTableNoteValue.quarter
        switch akTimeSig.bottomValue {
        case .two:
            bottomValue = .half
        case .four:
            bottomValue = .quarter
        case .eight:
            bottomValue = .eighth
        case .sixteen:
            bottomValue = .sixteenth
        }
        return MIDITimeTableTimeSignature(beats: Int(akTimeSig.topValue), noteValue: bottomValue)
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, rowAt index: Int) -> MIDITimeTableRowData {
        let row = midiNoteData[index]
        return row
    }
    
    // MARK: MIDITimeTableViewDelegate
    
    func midiTimeTableViewHeightForRows(_ midiTimeTableView: MIDITimeTableViewBase) -> CGFloat {
        return 3.5
    }
    
    func midiTimeTableViewHeightForMeasureView(_ midiTimeTableView: MIDITimeTableViewBase) -> CGFloat {
        return 10
    }
    
    func midiTimeTableViewWidthForRowHeaderCells(_ midiTimeTableView: MIDITimeTableViewBase) -> CGFloat {
        return 20
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, didUpdatePlayhead position: Double) {
        return
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, didUpdateRangeHead position: Double) {
        return
    }
    

  // MARK: UIScrollViewDelegate
  public func scrollViewDidScroll(_ scrollView: UIScrollView) {
    // this event comes when we manipulate the contentOffset by our own and when user drags the view.
    // update the sequencer when in manual drag
    if isDragInProgress {
      // calc delta time since last event, scrollduration
      let deltaTimeInterval = -1 * lastSequencerUpdatedWhileDragTimestamp.timeIntervalSinceNow
      // calc how much midi-time is in between the current position of sequencer and the newly set position by scroll
      let sequencer = Conductor.shared().sequencer
      // duration didn't work with seconds. need to use beats and convert them as AKDuration can't convert directly.
      let oldMusicTimeBeats = sequencer.currentPosition
      let oldMusicTime = sequencer.seconds(duration: oldMusicTimeBeats)
      let newRelativePosition = Double( (self.pianoRollView?.contentOffset.x)! / (self.pianoRollView?.contentSize.width)! )
      let sequencerLenghtSeconds = sequencer.seconds(duration:sequencer.length)
      let newMusicTime = sequencerLenghtSeconds * Double(newRelativePosition)

      AKLog("delta musictime: \(newMusicTime - oldMusicTime) ")
      //AKLog("delta the user scrolled: ")
        //delta usertime \( sequencerLenghtSeconds * (lastRelativeDragPosition - newRelativePosition) )")

      /*if oldMusicTime < newMusicTime {
        // user scrolled forward in time: set the tempo to catch up
        let tempo = (newMusicTime - oldMusicTime ) / deltaTimeInterval
        AKLog("tempo \(tempo)")
        if isPlaying && deltaTimeInterval > 0.3{
          sequencer.setRate(abs(tempo))
        }
        // delta timeinterval is how long passed since last event, and not how much time the user scrolled since last scroll-evnt
      }*/
      lastRelativeDragPosition = newRelativePosition
      lastSequencerUpdatedWhileDragTimestamp = Date.init()

      //let tempo = (newMusicTime - oldMusicTime ) / deltaTimeInterval
      //sequencer.setRate(abs(tempo))
      //AKLog("tempo \(tempo)")
      //AKLog("old: \(oldMusicTime)  newMusicTime \(newMusicTime)")
      // AKLog("old: \(oldMusicTime)  newMusicTime \(newMusicTime)")
      

      if lastSequencerUpdatedWhileDragTimestamp.timeIntervalSinceNow < TimeInterval(-0.3) {
        lastSequencerUpdatedWhileDragTimestamp = Date.init()
        let relativePosition = (self.pianoRollView?.contentOffset.x)! / (self.pianoRollView?.contentSize.width)!
        DispatchQueue.global(qos: .userInitiated).async {
          let sequencer = Conductor.shared().sequencer
          //NSLog("relative position \(relativePosition)")
          let newTimestamp = sequencer.length.musicTimeStamp * Double(relativePosition)
          sequencer.setTime(newTimestamp)
        }
      }
      
    }
  }
  
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    isDragInProgress = true
    lastSequencerUpdatedWhileDragTimestamp = Date.init()
    //Conductor.shared().sequencer.setRate(0.00001)
    lastRelativeDragPosition = Double( (self.pianoRollView?.contentOffset.x)! / (self.pianoRollView?.contentSize.width)! )
    // without live scrubbing: stop timer and sequencer
    //stop(self)
    
    // with live scrubbing: only stop timer.
    // doens't really work as well as in Logic. Maybe need to iterate the sequence and play notes at the current scroll position.
     updateIntervalTimer?.invalidate()

  }
  
  public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    if !decelerate {
      dragEnded()
    }
  }

  
  // the decelerating can take quite a long time 
  public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    dragEnded()
  }
  
  func dragEnded() {
    if isDragInProgress {
      isDragInProgress = false
      if isPlaying {
        startUpdatePlayheadTimer()
      } else {
        updatePlayheadPosition()
      }
    }
  }

}

