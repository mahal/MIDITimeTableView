//
//  Conductor.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 24.04.18.
//  Copyright © 2018 Raskin Software LLC. All rights reserved.
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
            sequencer.loadMIDIFile(midiFileName)
        }
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

