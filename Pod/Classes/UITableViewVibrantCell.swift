//
//  UITableViewVibrantCell.swift
//  Pods
//
//  Created by Jon Kent on 1/14/16.
//
//

import UIKit

open class UITableViewVibrantCell: UITableViewCell {

    fileprivate var vibrancyView: UIVisualEffectView = UIVisualEffectView()
    fileprivate var vibrancySelectedBackgroundView: UIVisualEffectView = UIVisualEffectView()
    fileprivate var defaultSelectedBackgroundView: UIView?

    public weak var sideMenuManager: SideMenuManager?

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        vibrancyView.frame = bounds
        vibrancyView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        for view in subviews {
            vibrancyView.contentView.addSubview(view)
        }
        addSubview(vibrancyView)

        let blurSelectionEffect = UIBlurEffect(style: .light)
        vibrancySelectedBackgroundView.effect = blurSelectionEffect
        defaultSelectedBackgroundView = selectedBackgroundView
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        // shouldn't be needed but backgroundColor is set to white on iPad:
        backgroundColor = UIColor.clear

        guard let sideMenuManager = sideMenuManager else {
            return
        }
        if !UIAccessibilityIsReduceTransparencyEnabled() && sideMenuManager.menuBlurEffectStyle != nil {
            let blurEffect = UIBlurEffect(style: sideMenuManager.menuBlurEffectStyle!)
            vibrancyView.effect = UIVibrancyEffect(blurEffect: blurEffect)

            if selectedBackgroundView != nil && selectedBackgroundView != vibrancySelectedBackgroundView {
                vibrancySelectedBackgroundView.contentView.addSubview(selectedBackgroundView!)
                selectedBackgroundView = vibrancySelectedBackgroundView
            }
        } else {
            vibrancyView.effect = nil
            selectedBackgroundView = defaultSelectedBackgroundView
        }
    }
}
