//
//  MIDITimeTableViewBase.swift
//  MIDITimeTableView
//
//  Created by Martin Halter on 02.05.18.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import UIKit

/// Populates the `MIDITimeTableView` with the datas of rows and cells.
public protocol MIDITimeTableViewDataSource: class {
    /// Number of rows in the time table.
    ///
    /// - Parameter midiTimeTableView: Time table to populate rows.
    /// - Returns: Number of rows populate.
    func numberOfRows(in midiTimeTableView: MIDITimeTableViewBase) -> Int
    
    /// Time signature of the time table.
    ///
    /// - Parameter midiTimeTableView: Time table to set time signature.
    /// - Returns: Time signature of the time table.
    func timeSignature(of midiTimeTableView: MIDITimeTableViewBase) -> MIDITimeTableTimeSignature
    
    /// Row data for each row in the time table.
    ///
    /// - Parameters:
    ///   - midiTimeTableView: Time table that populates row data.
    ///   - index: Index of row to populate data.
    /// - Returns: Row data of time table for an index.
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, rowAt index: Int) -> MIDITimeTableRowData
}

/// Delegate functions to inform about sizing of the time table.
public protocol MIDITimeTableViewDelegate: class {
    /// Measure view height in the time table.
    ///
    /// - Parameter midiTimeTableView: Time table to set its measure view's height.
    /// - Returns: Height of measure view.
    func midiTimeTableViewHeightForMeasureView(_ midiTimeTableView: MIDITimeTableViewBase) -> CGFloat
    
    /// Height of each row in the time table.
    ///
    /// - Parameter midiTimeTableView: Time table to set its rows height.
    /// - Returns: Height of each row.
    func midiTimeTableViewHeightForRows(_ midiTimeTableView: MIDITimeTableViewBase) -> CGFloat
    
    /// Width of header cells in each row.
    ///
    /// - Parameter midiTimeTableView: Time table to set its header cells widths in each row.
    /// - Returns: Width of header cell in each row.
    func midiTimeTableViewWidthForRowHeaderCells(_ midiTimeTableView: MIDITimeTableViewBase) -> CGFloat
    
    /// Informs about user updated playhead position.
    ///
    /// - Parameter midiTimeTableView: Time table that updated.
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, didUpdatePlayhead position: Double)
    
    /// Informs about user updated range head position.
    ///
    /// - Parameter midiTimeTableView: Time table that updated.
    func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, didUpdateRangeHead position: Double)
    }

/// Draws time table with multiple rows and editable cells. Heavily customisable.
open class MIDITimeTableViewBase: UIScrollView {
    /// Property to show measure bar. Defaults true.
    public var showsMeasure: Bool = true
    /// Property to show header cells in each row. Defaults true.
    public var showsHeaders: Bool = true
    /// Property to show grid. Defaults true.
    public var showsGrid: Bool = true
    /// Property to show range head that sets the playable are on the timetable. Defaults true.
    public var showsRangeHead: Bool = true
    /// Speed of zooming by pinch gesture.
    public var zoomSpeed: CGFloat = 0.4
    /// Maximum width of a measure bar after zooming in. Defaults 500.
    public var maxMeasureWidth: CGFloat = 500
    /// Minimum width of a measure bar after zooming out. Defaults 100.
    public var minMeasureWidth: CGFloat = 100
    /// Initial width of a measure bar. Defaults 200.
    public var measureWidth: CGFloat = 200 {
        didSet {
            if measureWidth >= maxMeasureWidth {
                measureWidth = maxMeasureWidth
            } else if measureWidth <= minMeasureWidth {
                measureWidth = minMeasureWidth
            }
        }
    }
    
    /// Grid layer to set its customisable properties like drawing rules, colors or line widths.
    public private(set) var gridLayer = MIDITimeTableGridLayer()
    /// Measure view that draws measure bars on it. You can customise its style.
    public private(set) var measureView = MIDITimeTableMeasureView()
    /// Rangehead view that shows or adjusts the playable area on the timetable.
    public private(set) var rangeheadView = MIDITimeTablePlayheadView()
    // Delegate and data source references
    /// Current data to display of the time table.
    internal var rowData = [MIDITimeTableRowData]()
    /// All row header cell views currently displaying.
    public internal(set) var rowHeaderCellViews = [MIDITimeTableHeaderCellView]()
    /// All data cell views currently displaying.
    public internal(set) var cellViews = [[MIDITimeTableCellView]]()

    /// Data source object of the time table to populate its data.
    public weak var dataSource: MIDITimeTableViewDataSource?
    /// Delegate object of the time table to inform about changes and customise sizing.
    public weak var timeTableDelegate: MIDITimeTableViewDelegate?

    internal var rowHeight: CGFloat = 60
    internal var measureHeight: CGFloat = 30
    internal var headerCellWidth: CGFloat = 120

    internal var beatWidth: CGFloat {
        return measureWidth / CGFloat(measureView.beatCount)
    }
    
    internal var subbeatWidth: CGFloat {
        return beatWidth / 4
    }
    
    // MARK: Init
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        // Measure
        measureView.layer.borderWidth = 0.5
        measureView.layer.borderColor = UIColor.cyan.cgColor
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.green.cgColor

        addSubview(measureView)
        // Grid
        layer.insertSublayer(gridLayer, at: 0)
        // Zoom gesture
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(didPinch(pinch:)))
        addGestureRecognizer(pinch)
    }

// MARK: Lifecycle

    open override func layoutSubviews() {
        super.layoutSubviews()
        
        if isDragging || isDecelerating {
            return
        }
        
        for (index, row) in rowHeaderCellViews.enumerated() {
            row.frame = CGRect(
                x: 0,
                y: measureHeight + (CGFloat(index) * rowHeight),
                width: headerCellWidth,
                height: rowHeight)
        }
        
        var duration = 0.0
        for i in 0..<rowData.count {
            let row = rowData[i]
            duration = row.duration > duration ? row.duration : duration
            for (index, cell) in row.cells.enumerated() {
                let cellView = cellViews[i][index]
                let startX = beatWidth * CGFloat(cell.position)
                let width = beatWidth * CGFloat(cell.duration)
                cellView.frame = CGRect(
                    x: headerCellWidth + startX,
                    y: measureHeight + (CGFloat(i) * rowHeight),
                    width: width,
                    height: rowHeight)
            }
        }
        
        // Calculate optimum bar count for measureView.
        // Fit measure view in time table frame even if not enough data to show in time table.
        let minBarCount = Int(ceil(frame.size.width / measureWidth))
        var barCount = Int(ceil(duration / Double(measureView.beatCount)))
        barCount = max(barCount, minBarCount)
        // Check if range is set.
        if showsRangeHead {
            let rangePosition = rangeheadView.position
            let rangedBarCount = Int(ceil(rangePosition / Double(measureView.beatCount))) + 1
            barCount = max(barCount, rangedBarCount)
        }
        measureView.barCount = barCount
        
        measureView.frame = CGRect(
            x: headerCellWidth,
            y: 0,
            width: CGFloat(measureView.barCount) * measureWidth,
            height: measureHeight)
        
        contentSize = CGSize(
            width: headerCellWidth + measureView.frame.width,
            height: measureView.frame.height + (rowHeight * CGFloat(rowHeaderCellViews.count)))
        
        
        // Rangehead
        rangeheadView.rowHeaderWidth = headerCellWidth
        rangeheadView.measureHeight = measureHeight
        rangeheadView.lineHeight = contentSize.height - measureHeight
        rangeheadView.measureBeatWidth = measureWidth / CGFloat(measureView.beatCount)
        rangeheadView.isHidden = !showsRangeHead
        bringSubview(toFront: rangeheadView)
        
        // Grid layer
        gridLayer.rowCount = rowHeaderCellViews.count
        gridLayer.barCount = measureView.barCount
        gridLayer.rowHeight = rowHeight
        gridLayer.rowHeaderWidth = headerCellWidth
        gridLayer.measureWidth = measureWidth
        gridLayer.measureHeight = measureHeight
        gridLayer.beatCount = measureView.beatCount
        gridLayer.isHidden = !showsGrid
        gridLayer.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
    }

    /// Populates row and cell datas from its data source and redraws time table. Could be invoked with an history item.
    ///
    /// - Parameter keepHistory: If you specify the history writing even if it is enabled, you can control it from here either.
    /// - Parameter historyItem: Optional history item. Defaults nil.
    public func reloadData(keepHistory: Bool = true, historyItem: MIDITimeTableHistoryItem? = nil) {
        // called on and implemented by subclass
    }
    
    /// Gets the row and column index of the cell view in the data source.
    ///
    /// - Parameter cell: The cell you want to get row and column info.
    /// - Returns: Returns a row and column index Int pair in a tuple.
    public func cellIndex(of cell: MIDITimeTableCellView) -> MIDITimeTableCellIndex? {
        let row = Int((cell.frame.minY - measureHeight) / rowHeight)
        guard let index = cellViews[row].index(of: cell), row < cellViews.count else { return nil }
        return MIDITimeTableCellIndex(row: row, index: index)
    }

    // MARK: Zooming
    
    @objc func didPinch(pinch: UIPinchGestureRecognizer) {
        switch pinch.state {
        case .began, .changed:
            var deltaScale = pinch.scale
            deltaScale = ((deltaScale - 1) * zoomSpeed) + 1
            deltaScale = min(deltaScale, maxMeasureWidth/measureWidth)
            deltaScale = max(deltaScale, minMeasureWidth/measureWidth)
            measureWidth *= deltaScale
            setNeedsLayout()
            pinch.scale = 1
        default:
            return
        }
    }

    
}

