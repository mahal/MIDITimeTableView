//
//  Conductor.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 24.04.18.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import Foundation
import AudioKit

class Conductor {
    private static var sharedConductor: Conductor = {
        let singletonConductor = Conductor.init()
        
        // Configuration
        // ...
        
        return singletonConductor
    }()
    
    // MARK: -
    var midiFileName = "Morley-Now_is_the_month_of_maying" {
        didSet {
            _midiNoteData = nil
            _midiNoteDataByNote = nil
            sequencer.loadMIDIFile(midiFileName)
        }
    }
    var _midiNoteData : [AKMIDINoteData]? 
    var midiNoteData : [AKMIDINoteData] {
        if (_midiNoteData == nil) {
            var outArray : [AKMIDINoteData] = []
            for track in sequencer.tracks {
                outArray += track.getMIDINoteData()
            } 
            _midiNoteData = outArray
        }
        return _midiNoteData!
    }
    
    var _midiNoteDataByNote : [[AKMIDINoteData]]?
    var midiNoteDataByNote : [[AKMIDINoteData]] {
        if (_midiNoteDataByNote == nil) {
            var outArray : [[AKMIDINoteData]] = [[]]
            let flatNoteData = midiNoteData
            for midiNoteNumber in 0...127 {
                let noteNumber60 = flatNoteData.filter { $0.noteNumber == midiNoteNumber }
                outArray.append(noteNumber60)
            }
            _midiNoteDataByNote = outArray
        }
        return _midiNoteDataByNote!
    }
    
    // MARK: - internals to make sound
    var sequencer = AKSequencer()
    private var instrument = AKMIDISampler()

    
    // Initialization
    
    private init() {
        AKAudioFile.cleanTempDirectory()
        AKSettings.bufferLength = .medium
        AKSettings.enableLogging = true
        
        // Allow audio to play while the iOS device is muted.
        AKSettings.playbackWhileMuted = true
        
        do {
            try AKSettings.setSession(category: .playAndRecord, with: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            
            // Set Output & Start AudioKit
            AudioKit.output = instrument
            try instrument.loadWav("FM Piano")
            try AudioKit.start()
        } catch {
            AKLog("Could not set session category or start AudioKit")
        }
    }
    
    // MARK: - Accessors
    
    class func shared() -> Conductor {
        return sharedConductor
    }

    func loadMelody() {
        // add a return on following line to debug when no sequencer needed
        // otherwise it will crashes as sequencer and debugger don't work together
        // return;
        // reloading a midi-file into an existing AKSequencer does not work
        // keep playRate tempo as it might be set before or after setting the midi chord
        //TODO: if the rate is 0 and a new midi is loaded: strum first note
        //TODO: or make it really good with pause and strum and so
        sequencer = AKSequencer()
        sequencer.loadMIDIFile(midiFileName)
        sequencer.setGlobalMIDIOutput(instrument.midiIn)
    }

}

