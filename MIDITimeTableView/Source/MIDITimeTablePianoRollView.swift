//
//  MIDITimeTablePianoRollView.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 02.05.18.
//  Copyright © 2018 Raskin Software LLC. All rights reserved.
//

import UIKit

open class MIDITimeTablePianoRollView: MIDITimeTableViewBase {

  public override init(frame: CGRect) {
    super.init(frame: frame)
    commonInit()
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    commonInit()
  }
  
  private func commonInit() {
    canCancelContentTouches = true
    delaysContentTouches = false
  }
  
  override open func touchesShouldCancel(in view: UIView) -> Bool {    
    if (view.isKind(of:MIDITimeTableCellView.self)) {
      return true
    }
    return super.touchesShouldCancel(in: view)
  }    
  
  override open func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
    // this is intermediate right. It may change when we do zooming. 
    return false
    
    let touch = touches.first
    if (touch?.phase == UITouchPhase.moved) {
      if (view.isKind(of:MIDITimeTableCellView.self)) {
        return false
      }
    } 
  
    return super.touchesShouldBegin(touches, with: event, in: view)
  }

}
