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
  
    /// Populates row and cell datas from its data source and redraws time table. Could be invoked with an history item.
    ///
    /// - Parameter keepHistory: not implemented as pianoroll does not allow editing and undo
    /// - Parameter historyItem: Optional history item. Defaults nil.
    public override func reloadData(keepHistory: Bool = true, historyItem: MIDITimeTableHistoryItem? = nil) {
        reloadData()
    }
    
    /// Populates row and cell datas from its data source and redraws time table.
    private func reloadData() {
        // Reset data source
        rowHeaderCellViews.forEach({ $0.removeFromSuperview() })
        rowHeaderCellViews = []
        cellViews.flatMap({ $0 }).forEach({ $0.removeFromSuperview() })
        cellViews = []
        
        let numberOfRows = dataSource?.numberOfRows(in: self) ?? 0
        let timeSignature = dataSource?.timeSignature(of: self) ?? MIDITimeTableTimeSignature(beats: 4, noteValue: .quarter)
        measureView.beatCount = timeSignature.beats
        
        // Update rowData
        rowData.removeAll()
        for i in 0..<numberOfRows {
            guard let row = dataSource?.midiTimeTableView(self, rowAt: i) else { continue }
            rowData.insert(row, at: i)
            let rowHeaderCell = row.headerCellView
            rowHeaderCellViews.append(rowHeaderCell)
            addSubview(rowHeaderCell)
            
            var cells = [MIDITimeTableCellView]()
            for (index, cell) in row.cells.enumerated() {
                let cellView = row.cellView(cell)
                cellView.tag = index
                cells.append(cellView)
                addSubview(cellView)
            }
            cellViews.append(cells)
        }
        
        // Delegate
        rowHeight = timeTableDelegate?.midiTimeTableViewHeightForRows(self) ?? rowHeight
        measureHeight = showsMeasure ? (timeTableDelegate?.midiTimeTableViewHeightForMeasureView(self) ?? measureHeight) : 0
        headerCellWidth = showsHeaders ? timeTableDelegate?.midiTimeTableViewWidthForRowHeaderCells(self) ?? headerCellWidth : 0
        
        // Update grid
        gridLayer.setNeedsLayout()
        
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
