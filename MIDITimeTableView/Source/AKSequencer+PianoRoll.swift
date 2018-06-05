//
//  AKSequencer+PianoRoll.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 02.05.18.
//  Copyright © 2018 Raskin Software LLC. All rights reserved.
//

import AudioKit

extension AKSequencer {
    
    // gets alls notes from all tracks and returns an array suitable for MIDITimeTablePianoRollView
    // could probably done more efficiently with some nice swift mutating collection stuff that I'm not familiar with
    // might be slow so please cache the result in your conductor/viewcontroller
    open func midiTimeTableRowData() -> [MIDITimeTableRowData] {
        var outArray : [MIDITimeTableRowData] = []
        var lookupArray = Conductor.shared().sequencer.midiNoteDataByNote
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
        outArray = Array(outArray[0 ..< (lastInRange - firstInRange) + 1]).reversed()        
        return outArray
    }
    
    // could probably done more efficiently with some nice swift mutating collection stuff that I'm not familiar with 
    func convertMIDINotesToRow(notes: [AKMIDINoteData]) -> MIDITimeTableRowData {
        var cells : [MIDITimeTableCellData] = []
        for note in notes {
            let cellData = MIDITimeTableCellData.init(data: "\(note.velocity)", position: note.position.beats, duration: note.duration.beats)
            cells.append(cellData)
        }
        let headerCell = HeaderCellView2.init(title:"")
        return MIDITimeTableRowData.init(cells: cells, headerCellView: headerCell, cellView: { _ in return CellView2.init(frame: .zero) } )
    }

    
    // this might be slow.
    var midiNoteData : [AKMIDINoteData] {
        var outArray : [AKMIDINoteData] = []
        for track in self.tracks {
            outArray += track.getMIDINoteData()
        } 
        return outArray
    }
    
    // this might be slow.
    var midiNoteDataByNote : [[AKMIDINoteData]] {
        // create array. it's not emtpy! it contains 1 element
        var outArray : [[AKMIDINoteData]] = [[]]
        let flatNoteData = midiNoteData
        for midiNoteNumber in 0...127 {
            let noteNumber60 = flatNoteData.filter { $0.noteNumber == midiNoteNumber }
            outArray.append(noteNumber60)
        }
        // strangely the array was created not empty but with 1 element at the beginning
        outArray.removeFirst(1)
        return outArray
    }
}

