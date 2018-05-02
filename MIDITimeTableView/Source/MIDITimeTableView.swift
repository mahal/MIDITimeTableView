//
//  MIDITimeTableView.swift
//  MIDITimeTableView
//
//  Created by Cem Olcay on 14.10.2017.
//  Copyright © 2017 cemolcay. All rights reserved.
//

import UIKit

/// Auto scrolling direction type
public struct MIDITimeTableViewAutoScrollDirection: OptionSet {

  // MARK: Option Set

  public var rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  // MARK: Init

  /// Default initilization with one or more direction types.
  ///
  /// - Parameter type: Direction types.
  public init(type: [MIDITimeTableViewAutoScrollDirection]) {
    var direction = MIDITimeTableViewAutoScrollDirection()
    type.forEach({ direction.insert($0) })
    self = direction
  }

  /// Left direction
  public static let left = MIDITimeTableViewAutoScrollDirection(rawValue: 1 << 0)
  /// Right direction
  public static let right = MIDITimeTableViewAutoScrollDirection(rawValue: 1 << 1)
  /// Up direction
  public static let up = MIDITimeTableViewAutoScrollDirection(rawValue: 1 << 2)
  /// Down direction
  public static let down = MIDITimeTableViewAutoScrollDirection(rawValue: 1 << 3)
}


/// Edited cell data. Holds the edited cell's index before editing, and new row index, position and duration data after editing.
public typealias MIDITimeTableViewEditedCellData = (index: MIDITimeTableCellIndex, newRowIndex: Int, newPosition: Double, newDuration: Double)

/// Delegate functions to inform about editing cells
public protocol MIDITimeTableViewEditDelegate: MIDITimeTableViewDelegate {
  /// Informs about the cell is either moved to another position, changed duration or changed position in a current or a new row.
  ///
  /// - Parameters:
  ///   - midiTimeTableView: Time table that performed changes on.
  ///   - cells: Edited cells data with changes before and after.
  func midiTimeTableView(_ midiTimeTableView: MIDITimeTableViewBase, didEdit cells: [MIDITimeTableViewEditedCellData])

  /// Informs about the cell is being deleted.
  ///
  /// - Parameters:
  ///   - midiTimeTableView: Time table that performed changes on.
  ///   - cells: Row and column indices of the cells will be deleting.
  func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, didDelete cells: [MIDITimeTableCellIndex])

  /// Informs about history has been changed. You need to update your `rowData` with history's `currentItem`.
  ///
  /// - Parameters:
  ///   - midiTimeTableView: Time table taht updated.
  ///   - history: History object of the time table.
  func midiTimeTableView(_ midiTimeTableView: MIDITimeTableView, historyDidChange history: MIDITimeTableHistory)
}

/// Draws time table with multiple rows and editable cells. Heavily customisable.
open class MIDITimeTableView: MIDITimeTableViewBase, MIDITimeTableHistoryDelegate, MIDITimeTablePlayheadViewDelegate, MIDITimeTableCellViewDelegate {
  /// Property to show playhead. Defaults true.
  public var showsPlayhead: Bool = true
  /// Property to enable/disable history feature. Deafults true.
  public var holdsHistory: Bool = true
  /// Playhead view that shows the current position in timetable. You can set is hidden or movable status as well as its position.
  public private(set) var playheadView = MIDITimeTablePlayheadView()

  /// History data that holds each `rowData` on each `reloadData` cycle.
  public private(set) var history = MIDITimeTableHistory()
  private weak var timeTableEditDelegate: MIDITimeTableViewEditDelegate?
  override open var timeTableDelegate: MIDITimeTableViewDelegate? {
    get { return self.timeTableEditDelegate }
    set { self.timeTableEditDelegate = newValue as! MIDITimeTableViewEditDelegate? }
  }


  // if user is moving a cell
  private var isMoving = false
  private var isResizing = false
  private var editingCellIndices = [MIDITimeTableCellIndex]()

  private var dragTimer: Timer?
  private var dragTimerInterval: TimeInterval = 0.5
  private var dragStartPosition: CGPoint = .zero
  private var dragCurrentPosition: CGPoint?
  private var dragView: UIView?
  private var initialDragViewSize: CGFloat = 90
  private var dragViewAutoScrollingThreshold: CGFloat = 100
  private var autoScrollingTimer: Timer?
  private var autoScrollingTimerInterval: TimeInterval = 0.3

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
    // History
    history.delegate = self
    // Playhead
    addSubview(playheadView)
    playheadView.delegate = self
    playheadView.layer.zPosition = 10
    playheadView.shapeType = .playhead
    // Rangehead
    addSubview(rangeheadView)
    rangeheadView.delegate = self
    rangeheadView.layer.zPosition = 10
    rangeheadView.shapeType = .range
    // Tap gesture
    let tap = UITapGestureRecognizer(
      target: self,
      action: #selector(didTap(tap:)))
    addGestureRecognizer(tap)
  }

  // MARK: Lifecycle

  open override func layoutSubviews() {
    super.layoutSubviews()

    if isDragging || isDecelerating {
      return
    }
    if isResizing || isMoving {
      return
    }


    // Playhead
    playheadView.rowHeaderWidth = headerCellWidth
    playheadView.measureHeight = measureHeight
    playheadView.lineHeight = contentSize.height - measureHeight
    playheadView.measureBeatWidth = measureWidth / CGFloat(measureView.beatCount)
    playheadView.isHidden = !showsPlayhead

  }


  /// Populates row and cell datas from its data source and redraws time table. Could be invoked with an history item.
  ///
  /// - Parameter keepHistory: If you specify the history writing even if it is enabled, you can control it from here either.
  /// - Parameter historyItem: Optional history item. Defaults nil.
  public func reloadData(keepHistory: Bool = true, historyItem: MIDITimeTableHistoryItem? = nil) {
    //TODO: history things 
    //         let numberOfRows = historyItem?.count ?? dataSource?.numberOfRows(in: self) ?? 0
    //                      guard let row = historyItem?[i] ?? dataSource?.midiTimeTableView(self, rowAt: i) else { continue }
    
    // add self as delegate to each cellView
    //                 cellView.delegate = self


    super.reloadData()
    // Keep history
    /*if holdsHistory, keepHistory, historyItem == nil {
      history.append(item: rowData)
    }*/
  }


  /// Unselects all cells if tapped an empty area of the time table.
  @objc private func didTap(tap: UITapGestureRecognizer) {
    unselectAllCells()
    endDragging()
  }

  // MARK: Drag to select multiple cells

  open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)

    // Start drag timer.
    guard let touchLocation = touches.first?.location(in: self) else { return }
    dragStartPosition = touchLocation
    dragTimer = Timer.scheduledTimer(
      timeInterval: dragTimerInterval,
      target: self,
      selector: #selector(createDragView),
      userInfo: nil,
      repeats: false)
    
  }

  @objc private func createDragView() {
    isScrollEnabled = false

    // Drag start position.
    dragStartPosition.x -= initialDragViewSize/2
    dragStartPosition.y -= initialDragViewSize/2

    // Create drag view.
    dragView = UIView(frame: CGRect(origin: dragStartPosition, size: .zero))
    dragView?.layer.backgroundColor = UIColor.white.withAlphaComponent(0.3).cgColor
    dragView?.layer.borderColor = UIColor.white.cgColor
    dragView?.layer.borderWidth = 1
    addSubview(dragView!)
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      usingSpringWithDamping: 1,
      initialSpringVelocity: 1,
      options: [],
      animations: {
        self.dragView?.frame = CGRect(
          x: self.dragStartPosition.x,
          y: self.dragStartPosition.y,
          width: self.initialDragViewSize,
          height: self.initialDragViewSize)
      },
      completion: nil)

    // Reset drag timer.
    dragTimer?.invalidate()
    dragTimer = nil
  }

  open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    guard let touchLocation = touches.first?.location(in: self) else { return }
    updateDragView(touchLocation: touchLocation)
    endAutoScrolling()

    // Make scroll view scroll if drag view hits the limit
    var autoScrollDirection = MIDITimeTableViewAutoScrollDirection()
    var visibleRect = CGRect(origin: contentOffset, size: bounds.size)
    if touchLocation.y < visibleRect.minY + dragViewAutoScrollingThreshold, contentOffset.y > 0 { // move up
      visibleRect.origin.y -= dragViewAutoScrollingThreshold
      autoScrollDirection.insert(.up)
    } else if touchLocation.y > visibleRect.maxY - dragViewAutoScrollingThreshold, contentOffset.y + frame.size.height < contentSize.height { // move down
      autoScrollDirection.insert(.down)
    }
    if touchLocation.x < visibleRect.minX + dragViewAutoScrollingThreshold, contentOffset.x > 0 { // move left
      autoScrollDirection.insert(.left)
    } else if touchLocation.x > visibleRect.maxX - dragViewAutoScrollingThreshold, contentOffset.x + frame.size.width < contentSize.width { // move right
      autoScrollDirection.insert(.right)
    }

    if autoScrollDirection.isEmpty {
      endAutoScrolling()
    } else {
      dragCurrentPosition = touchLocation
      startAutoScrollTimer(with: autoScrollDirection)
    }
  }

  private func updateDragView(touchLocation: CGPoint) {
    guard let dragView = dragView else { return }

    // Set drag view frame
    let origin = dragStartPosition
    if touchLocation.y < origin.y && touchLocation.x < origin.x {
      dragView.frame = CGRect(
        x: touchLocation.x,
        y: touchLocation.y,
        width: origin.x - touchLocation.x,
        height: origin.y - touchLocation.y)
    } else if touchLocation.y < origin.y && touchLocation.x > origin.x {
      dragView.frame = CGRect(
        x: origin.x,
        y: touchLocation.y,
        width: touchLocation.x - origin.x,
        height: origin.y - touchLocation.y)
    } else if touchLocation.y > origin.y && touchLocation.x > origin.x {
      dragView.frame = CGRect(
        x: origin.x,
        y: origin.y,
        width: touchLocation.x - origin.x,
        height: touchLocation.y - origin.y)
    } else if touchLocation.y > origin.y && touchLocation.x < origin.x {
      dragView.frame = CGRect(
        x: touchLocation.x,
        y: origin.y,
        width: origin.x - touchLocation.x,
        height: touchLocation.y - origin.y)
    }

    // Make cells selected.
    cellViews
      .flatMap({ $0 })
      .forEach({ $0.isSelected = dragView.frame.intersects($0.frame) })
  }

  private func startAutoScrollTimer(with direction: MIDITimeTableViewAutoScrollDirection) {
    autoScrollingTimer = Timer.scheduledTimer(
      timeInterval: autoScrollingTimerInterval,
      target: self,
      selector: #selector(autoScrollTimerTick(timer:)),
      userInfo: ["direction": direction],
      repeats: true)
  }

  @objc private func autoScrollTimerTick(timer: Timer) {
    guard let userInfo = timer.userInfo as? [String: Any],
      let dragCurrentPosition = dragCurrentPosition,
      let direction = userInfo["direction"] as? MIDITimeTableViewAutoScrollDirection
      else { return }

    var scrollDirection = CGPoint.zero
    if direction.contains(.left) {
      scrollDirection.x -= 1
    }
    if direction.contains(.right) {
      scrollDirection.x += 1
    }
    if direction.contains(.up) {
      scrollDirection.y -= 1
    }
    if direction.contains(.down) {
      scrollDirection.y += 1
    }

    // Calculate and auto scroll

    let scrollAmount = CGSize(
      width: scrollDirection.x * dragViewAutoScrollingThreshold,
      height: scrollDirection.y * dragViewAutoScrollingThreshold)

    let visibleRect = CGRect(
      origin: CGPoint(
        x: contentOffset.x + scrollAmount.width,
        y: contentOffset.y + scrollAmount.height),
      size: bounds.size)

    let position = CGPoint(
      x: dragCurrentPosition.x + scrollAmount.width,
      y: dragCurrentPosition.y + scrollAmount.height)

    UIView.animate(
      withDuration: autoScrollingTimerInterval,
      animations: {
        self.scrollRectToVisible(visibleRect, animated: false)
        self.updateDragView(touchLocation: position)
      },
      completion: { _ in self.updateDragView(touchLocation: position)})
  }

  private func endAutoScrolling() {
    autoScrollingTimer?.invalidate()
    autoScrollingTimer = nil
    dragCurrentPosition = nil
  }

  open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    endDragging()
  }

  open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    endDragging()
  }

  private func endDragging() {
    // Disable auto scrolling
    endAutoScrolling()
    // Enable scrolling back
    isScrollEnabled = true
    // Reset timer
    dragTimer?.invalidate()
    dragTimer = nil
    // Remove drag view
    dragView?.removeFromSuperview()
    dragView = nil
  }

  /// Makes all cells unselected.
  public func unselectAllCells() {
    cellViews.flatMap({ $0 }).forEach({ $0.isSelected = false })
  }


  // MARK: MIDITimeTableCellViewDelegate

  public func midiTimeTableCellViewDidMove(_ midiTimeTableCellView: MIDITimeTableCellView, pan: UIPanGestureRecognizer) {
    let translation = pan.translation(in: self)
    bringSubview(toFront: midiTimeTableCellView)

    let selectedCells = cellViews.flatMap({ $0 }).filter({ $0.isSelected })

    if case .began = pan.state {
      midiTimeTableCellView.isSelected = true
      editingCellIndices = cellViews.flatMap({ $0 }).filter({ $0.isSelected }).flatMap({ cellIndex(of: $0) })
    }

    isMoving = true

    let selectedCellsPositionY = selectedCells.map({ $0.frame.origin.y }).sorted()
    let topMostSelectedCellRowY = selectedCellsPositionY.first ?? 0
    let bottomMostSelectedCellRowY = selectedCellsPositionY.last ?? 0

    for cell in selectedCells {
      // Horizontal move
      if translation.x > subbeatWidth, cell.frame.maxX < contentSize.width { // Right
        cell.frame.origin.x += subbeatWidth
        pan.setTranslation(CGPoint(x: 0, y: translation.y), in: self)
      } else if translation.x < -subbeatWidth, cell.frame.minX > headerCellWidth { // Left
        cell.frame.origin.x -= subbeatWidth
        pan.setTranslation(CGPoint(x: 0, y: translation.y), in: self)
      }

      // Vertical move
      if translation.y > rowHeight,
        cell.frame.maxY < measureHeight + (rowHeight * CGFloat(cellViews.count)),
        bottomMostSelectedCellRowY + rowHeight < measureHeight + (rowHeight * CGFloat(cellViews.count)) { // Down
        cell.frame.origin.y += rowHeight
        pan.setTranslation(CGPoint(x: translation.x, y: 0), in: self)
      } else if translation.y < -rowHeight,
          cell.frame.minY > measureHeight,
          topMostSelectedCellRowY > measureHeight { // Up
        cell.frame.origin.y -= rowHeight
        pan.setTranslation(CGPoint(x: translation.x, y: 0), in: self)
      }
    }

    if case .ended = pan.state {
      isMoving = false
      didEditCells(editingCellIndices)
    }
  }

  public func midiTimeTableCellViewDidResize(_ midiTimeTableCellView: MIDITimeTableCellView, pan: UIPanGestureRecognizer) {
    let translation = pan.translation(in: self)
    bringSubview(toFront: midiTimeTableCellView)

    let selectedCells = cellViews.flatMap({ $0 }).filter({ $0.isSelected })

    if case .began = pan.state {
      isResizing = true
      midiTimeTableCellView.isSelected = true
      editingCellIndices = cellViews.flatMap({ $0 }).filter({ $0.isSelected }).flatMap({ cellIndex(of: $0) })
    }

    for cell in selectedCells {
      if translation.x > subbeatWidth, cell.frame.maxX < contentSize.width - subbeatWidth { // Increase
        cell.frame.size.width += subbeatWidth
        pan.setTranslation(CGPoint(x: 0, y: translation.y), in: self)
      } else if translation.x < -subbeatWidth, cell.frame.width > subbeatWidth { // Decrease
        cell.frame.size.width -= subbeatWidth
        pan.setTranslation(CGPoint(x: 0, y: translation.y), in: self)
      }
    }

    if case .ended = pan.state {
      isResizing = false
      didEditCells(editingCellIndices)
    }
  }

  private func didEditCells(_ cells: [MIDITimeTableCellIndex]) {
    var editedCells = [MIDITimeTableViewEditedCellData]()

    for cell in cells {
      let cellView = cellViews[cell.row][cell.index]
      let newCellPosition = Double(cellView.frame.minX - headerCellWidth) / Double(beatWidth)
      let newCellDuration = Double(cellView.frame.size.width / beatWidth)
      let newCellRow = Int((cellView.frame.minY - measureHeight) / rowHeight)

      editedCells.append((
        cell,
        newCellRow,
        newCellPosition,
        newCellDuration))
    }

    editingCellIndices = []
    timeTableEditDelegate?.midiTimeTableView(self, didEdit: editedCells)
  }

  public func midiTimeTableCellViewDidTap(_ midiTimeTableCellView: MIDITimeTableCellView) {
    for cell in cellViews.flatMap({ $0 }) {
      cell.isSelected = cell == midiTimeTableCellView
    }
  }

  public func midiTimeTableCellViewDidDelete(_ midiTimeTableCellView: MIDITimeTableCellView) {
    let deletingCellIndices = cellViews
      .flatMap({ $0 })
      .filter({ $0.isSelected })
      .flatMap({ cellIndex(of: $0) })
    timeTableEditDelegate?.midiTimeTableView(self, didDelete: deletingCellIndices)
  }

  // MARK: MIDITimeTablePlayheadViewDelegate

  public func playheadView(_ playheadView: MIDITimeTablePlayheadView, didPan panGestureRecognizer: UIPanGestureRecognizer) {
    let translation = panGestureRecognizer.translation(in: self)

    // Horizontal move
    if translation.x > subbeatWidth, playheadView.frame.maxX < contentSize.width {
      playheadView.position += 0.25
      panGestureRecognizer.setTranslation(CGPoint(x: 0, y: translation.y), in: self)
    } else if translation.x < -subbeatWidth, playheadView.frame.minX > headerCellWidth {
      playheadView.position -= 0.25
      panGestureRecognizer.setTranslation(CGPoint(x: 0, y: translation.y), in: self)
    }

    // Fire delegate
    if panGestureRecognizer.state == .ended || panGestureRecognizer.state == .cancelled || panGestureRecognizer.state == .failed {
      if playheadView == self.playheadView {
        timeTableDelegate?.midiTimeTableView(self, didUpdatePlayhead: playheadView.position)
      } else if playheadView == rangeheadView {
        timeTableDelegate?.midiTimeTableView(self, didUpdateRangeHead: rangeheadView.position)
      }
    }
  }

    public func playheadViewDidUpdatePlayheadPosition(_ playheadView: MIDITimeTablePlayheadView) {
    }

  // MARK: MIDITimeTableHistoryDelegate

  public func midiTimeTableHistory(_ history: MIDITimeTableHistory, didHistoryChange item: MIDITimeTableHistoryItem) {
    if holdsHistory {
      reloadData(historyItem: item)
      timeTableEditDelegate?.midiTimeTableView(self, historyDidChange: history)
    }
  }
}
