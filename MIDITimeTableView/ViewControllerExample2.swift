//
//  ViewControllerExample2.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 24.04.18.
//  Copyright © 2018 Raskin Software LLC. All rights reserved.
//

import UIKit
import AudioKit

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
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        titleLabel.frame = CGRect(origin: .zero, size: frame.size)
    }
}

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


class ViewControllerExample2: UIViewController, MIDITimeTableViewDataSource, MIDITimeTableViewDelegate, UIScrollViewDelegate {
    
    @IBOutlet weak var pianoRollView: MIDITimeTablePianoRollView?
    private var updateIntervalTimer : Timer?
    private var isDragInProgress = false
    private var lastSequencerUpdatedWhileDragTimestamp = Date.init()
    private var isPlaying = false
    lazy var midiNoteData : [MIDITimeTableRowData] = {
        Conductor.shared().sequencer.midiTimeTableRowData();
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
      Conductor.shared().midiFileName = "Br-151"
        Conductor.shared().loadMelody()
        play(self)
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
        Conductor.shared().sequencer.play()
        isPlaying = true
        startUpdatePlayheadTimer()
    }
    
    @IBAction func stop(_ sender: Any) {
        isPlaying = false
        stopUpdatePlaheadTimer()
        Conductor.shared().sequencer.stop()
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
        // TODO: how to represent it? can it be read from the midi-file?
        return MIDITimeTableTimeSignature(beats: 4, noteValue: .quarter)
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
      if lastSequencerUpdatedWhileDragTimestamp.timeIntervalSinceNow < TimeInterval(-0.3) {
        lastSequencerUpdatedWhileDragTimestamp = Date.init()
        DispatchQueue.global(qos: .userInitiated).async {
          let sequencer = Conductor.shared().sequencer
          let relativePosition = (self.pianoRollView?.contentOffset.x)! / (self.pianoRollView?.contentSize.width)!
          //NSLog("relative position \(relativePosition)")
          let newTimestamp = sequencer.length.musicTimeStamp * Double(relativePosition)
          sequencer.setTime(newTimestamp)
        }
      }
    }
  }
  
  public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    isDragInProgress = true
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

