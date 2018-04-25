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


class ViewControllerExample2: UIViewController, MIDITimeTableViewDataSource, MIDITimeTableViewDelegate {
    
    @IBOutlet weak var pianoRollView: MIDITimeTableView?
    private var updateIntervalTimer : Timer?
    
    lazy var midiNoteData : [MIDITimeTableRowData] = {
        var outArray : [MIDITimeTableRowData] = []
        var lookupArray = Conductor.shared().midiNoteDataByNote
        var rangeStarted = false
        var firstInRange = 0
        var lastInRange = 0
        for notesOfSameToneIndex in 0...lookupArray.count - 1 {
            let notes = lookupArray[notesOfSameToneIndex]
            if notes.count > 0 {
                if !rangeStarted { 
                    rangeStarted = true
                    firstInRange = notesOfSameToneIndex
                } else {
                    lastInRange = notesOfSameToneIndex
                }
            }
            // add even when no notes in this row (as we'll show emtpy rows inbetween)
            if rangeStarted {
                outArray.append(convertMIDINotesToRow(notes: notes))
                if (notesOfSameToneIndex % 12 == 0) {
                    (outArray.last?.headerCellView as! HeaderCellView2).titleLabel.text = "C\(Int(notesOfSameToneIndex / 12))"
                }
            }
        }
        outArray = Array(outArray[0..<lastInRange - firstInRange]).reversed()        
        return outArray
    }()
    
    func convertMIDINotesToRow(notes: [AKMIDINoteData]) -> MIDITimeTableRowData {
        var cells : [MIDITimeTableCellData] = []
        for note in notes {
            let cellData = MIDITimeTableCellData.init(data: "\(note.velocity)", position: note.position.beats, duration: note.duration.beats)
            cells.append(cellData)
        }
        let headerCell = HeaderCellView2.init(title:"")
        return MIDITimeTableRowData.init(cells: cells, headerCellView: headerCell, cellView: { _ in return CellView2.init(frame: .zero) } )
    }

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
        pianoRollView?.dataSource = self
        pianoRollView?.timeTableDelegate = self
        pianoRollView?.gridLayer.showsSubbeatLines = false
        pianoRollView?.showsGrid = false
        pianoRollView?.showsRangeHead = false
        pianoRollView?.holdsHistory = false
        pianoRollView?.cellsSelectable = false
        pianoRollView?.measureWidth = 100.0
        pianoRollView?.maxMeasureWidth = 200.0
        pianoRollView?.minMeasureWidth = 50.0
        pianoRollView?.reloadData()
    }
    
    @objc func updatePlayhead() {
        let sequencerPosition = Conductor.shared().sequencer.currentPosition
        pianoRollView?.playheadView.position = sequencerPosition.beats
    }
    
    @IBAction func play(_ sender: Any) {
        Conductor.shared().sequencer.play()
        updateIntervalTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(updatePlayhead),
            userInfo: nil,
            repeats: true)
    }
    
    @IBAction func stop(_ sender: Any) {
        updateIntervalTimer?.invalidate()
        updateIntervalTimer = nil
        Conductor.shared().sequencer.stop()
    }
    
    // MARK: MIDITimeTableViewDataSource
    
    func numberOfRows(in midiTimeTableView: MIDITimeTableView) -> Int {
        return midiNoteData.count
    }
    
    func timeSignature(of midiTimeTableView: MIDITimeTableView) -> MIDITimeTableTimeSignature {
        // TODO: how to represent it? can it be read from the midi-file?
        return MIDITimeTableTimeSignature(beats: 4, noteValue: .quarter)
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, rowAt index: Int) -> MIDITimeTableRowData {
        let row = midiNoteData[index]
        return row
    }
    
    // MARK: MIDITimeTableViewDelegate
    
    func midiTimeTableViewHeightForRows(_ midiTimeTableView: MIDITimeTableView) -> CGFloat {
        return 3.5
    }
    
    func midiTimeTableViewHeightForMeasureView(_ midiTimeTableView: MIDITimeTableView) -> CGFloat {
        return 10
    }
    
    func midiTimeTableViewWidthForRowHeaderCells(_ midiTimeTableView: MIDITimeTableView) -> CGFloat {
        return 20
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, didDelete cells: [MIDITimeTableCellIndex]) {
        // nop
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, didEdit cells: [MIDITimeTableViewEditedCellData]) {
        // nop
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, didUpdatePlayhead position: Double) {
        return
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, didUpdateRangeHead position: Double) {
        return
    }
    
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, historyDidChange history: MIDITimeTableHistory) {
        // nop
    }
}

