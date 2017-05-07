//
//  ScrollingBars.swift
//
//  Created by Taisuke Hori on 2014/12/28.
//  Copyright (c) 2015年 Hori Taisuke. All rights reserved.
//

import Foundation
import UIKit

public protocol ScrollingBarsDelegate {
    var topBarPosition: CGFloat { get set }
    var topBarHeight: CGFloat { get }
    var topBarMinHeight: CGFloat { get }
    var bottomBarPosition: CGFloat { get set }
    var bottomBarHeight: CGFloat { get }
    var bottomBarMinHeight: CGFloat { get }
}

public class ScrollingBars: NSObject, UIScrollViewDelegate {
    
    var scrollView: UIScrollView!
    var delegate: ScrollingBarsDelegate!
    var proxyDelegate: UIScrollViewDelegate?
    
    var isScrollViewDragging: Bool = false
    var scrollBeginOffset: CGPoint = CGPoint()
    var scrollPrevPoint: CGPoint = CGPoint()
    var scrollDirection: Int = 0
    var isScrollFromBottomLine: Bool = false
    var isUpdateingInset: Bool = false
    
    // MARK: public
    
    public func follow(scrollView : UIScrollView, delegate: ScrollingBarsDelegate) {
        self.scrollView = scrollView
        self.delegate = delegate
        self.updateContentInset()
    }
    
    public func showBars(_ animate: Bool) {
        let changeFunc: () -> Void = {
            self.delegate.topBarPosition = 0
            self.delegate.bottomBarPosition = 0
            self.updateContentInset()
        }
        if (animate) {
            // workaround for smooth animation
            DispatchQueue.main.async() {
                UIView.animate(withDuration: self.animationDuration, animations: changeFunc, completion: nil)
            }
        } else {
            changeFunc()
        }
    }
    
    public func hideBars(_ animate: Bool) {
        let changeFunc: () -> Void = {
            self.delegate.topBarPosition = self.topBarMaxPosition()
            self.delegate.bottomBarPosition = self.bottomBarMaxPosition()
            self.updateContentInset()
        }
        if (animate) {
            // workaround for smooth animation
            DispatchQueue.main.async() {
                UIView.animate(withDuration: self.animationDuration, animations: changeFunc, completion:nil)
            }
        } else {
            changeFunc()
        }
    }
    
    public func refresh(_ animated: Bool) {
        if self.delegate == nil {
            return
        }
        
        if self.isTopBarHidden() || self.isBottomBarHidden() {
            self.hideBars(animated)
        } else {
            self.showBars(animated)
        }
    }
    
    // MARK: - ScrollView Delegate
    
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.scrollBeginOffset = self.scrollView.contentOffset
        self.scrollPrevPoint = scrollView.panGestureRecognizer.location(in: scrollView.superview)
        self.isScrollViewDragging = true
        self.isScrollFromBottomLine = scrollView.contentSize.height - scrollView.frame.size.height <= self.scrollBeginOffset.y + CGFloat(Float.ulpOfOne) && (self.isBottomBarHidden() || self.bottomBarMaxPosition() == 0)
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        self.isScrollViewDragging = false
        
        if !decelerate {
            if self.isTopBarHalfWay() || self.isBottomBarHalfWay() {
                let isUnderTopBar = scrollView.contentOffset.y < -self.delegate.topBarMinHeight
                let appearRatio = self.delegate.bottomBarPosition / self.bottomBarMaxPosition()
                if isUnderTopBar || appearRatio <=  self.barAppearThreshold {
                    self.showBars(true)
                } else {
                    self.hideBars(true)
                }
            }
        }
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if !self.isScrollViewDragging {
            return
        }
        if self.isUpdateingInset {
            return
        }
        
        
        let currentPoint = scrollView.panGestureRecognizer.location(in: scrollView.superview)
        
        if currentPoint.y == self.scrollPrevPoint.y {
            self.scrollDirection = 0
        } else if currentPoint.y < self.scrollPrevPoint.y {
            self.scrollDirection = 1
        } else {
            self.scrollDirection = -1
        }
        
        let scrollDistanceFromPrev = -(currentPoint.y - self.scrollPrevPoint.y)
        self.scrollPrevPoint = currentPoint
        
        let isSmallContentSize = scrollView.contentSize.height <= scrollView.frame.size.height - self.delegate.topBarHeight + CGFloat(Float.ulpOfOne)
        let isScrollOverBottom = scrollView.contentOffset.y + scrollView.frame.size.height > scrollView.contentSize.height - CGFloat(Float.ulpOfOne)
        
        if isSmallContentSize {
            // do nothing
        } else if isScrollOverBottom {
            if self.isBottomBarHidden() && self.isScrollFromBottomLine {
                self.showBars(true)
            }
        } else {
            let isUnderTopBar = scrollView.contentOffset.y < -self.delegate.topBarMinHeight && scrollView.contentOffset.y >= -self.delegate.topBarHeight
            let isOverUnderTopBar = scrollView.contentOffset.y < -self.delegate.topBarHeight
            if (!self.isTopBarHidden() || isUnderTopBar) && !isOverUnderTopBar {
                self.delegate.topBarPosition = min(self.topBarMaxPosition(), max(0, scrollDistanceFromPrev + self.delegate.topBarPosition))
            }
            if (!self.isBottomBarHidden() || isUnderTopBar) && !isOverUnderTopBar {
                self.delegate.bottomBarPosition = min(self.bottomBarMaxPosition(), max(0, scrollDistanceFromPrev + self.delegate.bottomBarPosition))
                //                let prevTop = self.scrollView.contentInset.top
                self.updateContentInset()
            }
        }
    }
    
    public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        if self.scrollDirection < 0 {
            if !self.isTopBarFullAppear() || !self.isBottomBarFullAppear() {
                self.showBars(true)
            }
        } else if self.scrollDirection > 0 {
            let isScrollOverBottom = scrollView.contentOffset.y + scrollView.frame.size.height > scrollView.contentSize.height - CGFloat(Float.ulpOfOne)
            if !(self.isTopBarHidden() && self.isBottomBarHidden()) && !(self.isBottomBarFullAppear() && (isScrollOverBottom || scrollView.contentOffset.y < 0)) {
                self.hideBars(true)
            }
        }
    }
    
    public func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if !self.isTopBarFullAppear() {
            self.showBars(true)
            return false
        }
        return true
    }
    
    // MARK: - Internal Func
    
    func updateContentInset() {
        self.isUpdateingInset = true
        self.scrollView.contentInset = UIEdgeInsetsMake(
            self.delegate.topBarHeight - self.delegate.topBarPosition,
            self.scrollView.contentInset.left,
            self.delegate.bottomBarHeight - self.delegate.bottomBarPosition,
            self.scrollView.contentInset.right)
        self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
        self.isUpdateingInset = false
    }
    
    // MARK: - Constants
    
    var animationDuration: TimeInterval {
        return 0.2
    }
    
    var barAppearThreshold: CGFloat {
        return 1 / 4
    }
    
    // MARK: - Bar State
    
    func topBarMaxPosition() -> CGFloat {
        return self.delegate.topBarHeight - self.delegate.topBarMinHeight
    }
    
    func isTopBarHidden() -> Bool {
        return self.delegate.topBarPosition >= self.topBarMaxPosition()
    }
    
    func isTopBarFullAppear() -> Bool {
        return self.delegate.topBarPosition == 0
    }
    
    func isTopBarHalfWay() -> Bool {
        return !isTopBarHidden() && !isTopBarFullAppear()
    }
    
    func bottomBarMaxPosition() -> CGFloat {
        return self.delegate.bottomBarHeight - self.delegate.bottomBarMinHeight
    }
    
    func isBottomBarHidden() -> Bool {
        return self.delegate.bottomBarPosition >= self.bottomBarMaxPosition()
    }
    
    func isBottomBarFullAppear() -> Bool {
        return self.delegate.bottomBarPosition == 0
    }
    
    func isBottomBarHalfWay() -> Bool {
        return !isBottomBarHidden() && !isBottomBarFullAppear()
    }
}
