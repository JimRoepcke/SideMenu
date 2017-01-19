//
//  UISideMenuNavigationController.swift
//
//  Created by Jon Kent on 1/14/16.
//  Copyright © 2016 Jon Kent. All rights reserved.
//

import UIKit

open class UISideMenuNavigationController: UINavigationController {

    internal var originalMenuBackgroundColor: UIColor?

    public weak var sideMenuManager: SideMenuManager?

    open override func awakeFromNib() {
        super.awakeFromNib()

        // if this isn't set here, segues cause viewWillAppear and viewDidAppear to be called twice
        // likely because the transition completes and the presentingViewController is added back
        // into view for the default transition style.
        modalPresentationStyle = .overFullScreen
    }

    /// Whether the menu appears on the right or left side of the screen. Right is the default.
    @IBInspectable open var leftSide: Bool = false

    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let sideMenuManager = sideMenuManager else {
            return
        }

        // we had presented a view before, so lets dismiss ourselves as already acted upon
        if view.isHidden {
            sideMenuManager.sideMenuTransition.hideMenuComplete()
            dismiss(animated: false, completion: { () -> Void in
                self.view.isHidden = false
            })
        }
    }

    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let sideMenuManager = sideMenuManager else {
            return
        }

        // when presenting a view controller from the menu, the menu view gets moved into another transition view above our transition container
        // which can break the visual layout we had before. So, we move the menu view back to its original transition view to preserve it.
        if !isBeingDismissed {
            if let mainView = presentingViewController?.view {
                switch sideMenuManager.menuPresentMode {
                case .viewSlideOut, .viewSlideInOut:
                    mainView.superview?.insertSubview(view, belowSubview: mainView)
                case .menuSlideIn, .menuDissolveIn:
                    if let tapView = sideMenuManager.sideMenuTransition.tapView {
                        mainView.superview?.insertSubview(view, aboveSubview: tapView)
                    } else {
                        mainView.superview?.insertSubview(view, aboveSubview: mainView)
                    }
                }
            }
        }
    }

    override open func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // we're presenting a view controller from the menu, so we need to hide the menu so it isn't  g when the presented view is dismissed.
        if !isBeingDismissed {
            view.isHidden = true
            sideMenuManager?.sideMenuTransition.hideMenuStart()
        }
    }

    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let sideMenuManager = sideMenuManager else {
            return
        }

        // don't bother resizing if the view isn't visible
        if view.isHidden {
            return
        }

        sideMenuManager.sideMenuTransition.statusBarView?.isHidden = true
        coordinator.animate(alongsideTransition: { (context) -> Void in
            sideMenuManager.sideMenuTransition.presentMenuStart(forSize: size)
            }) { (context) -> Void in
                sideMenuManager.sideMenuTransition.statusBarView?.isHidden = false
        }
    }

    override open func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let sideMenuManager = sideMenuManager else {
            return
        }
        if let menuViewController: UINavigationController = sideMenuManager.sideMenuTransition.presentDirection == .left ? sideMenuManager.menuLeftNavigationController : sideMenuManager.menuRightNavigationController,
            let presentingViewController = menuViewController.presentingViewController as? UINavigationController {
                presentingViewController.prepare(for: segue, sender: sender)
        }
    }

    override open func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        guard let sideMenuManager = sideMenuManager else {
            return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        }
        if let menuViewController: UINavigationController = sideMenuManager.sideMenuTransition.presentDirection == .left ? sideMenuManager.menuLeftNavigationController : sideMenuManager.menuRightNavigationController,
            let presentingViewController = menuViewController.presentingViewController as? UINavigationController {
                return presentingViewController.shouldPerformSegue(withIdentifier: identifier, sender: sender)
        }

        return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
    }

    override open func pushViewController(_ viewController: UIViewController, animated: Bool) {
        guard let sideMenuManager = sideMenuManager else {
            return super.pushViewController(viewController, animated: animated)
        }
        guard !viewControllers.isEmpty && !(sideMenuManager.menuAllowSubmenus ?? true) else {
            // NOTE: pushViewController is called by init(rootViewController: UIViewController)
            // so we must perform the normal super method in this case.
            super.pushViewController(viewController, animated: animated)
            return
        }

        guard let presentingViewController = presentingViewController as? UINavigationController else {
            print("SideMenu Warning: attempt to push a View Controller from \(self.presentingViewController.self) where its navigationController == nil. It must be embedded in a Navigation Controller for this to work.")
            return
        }

        // to avoid overlapping dismiss & pop/push calls, create a transaction block where the menu
        // is dismissed after showing the appropriate screen
        CATransaction.begin()
        CATransaction.setCompletionBlock({ () -> Void in
            self.dismiss(animated: true, completion: nil)
            self.visibleViewController?.viewWillAppear(false) // Hack: force selection to get cleared on UITableViewControllers when reappearing using custom transitions
        })

        UIView.animate(withDuration: sideMenuManager.menuAnimationDismissDuration, animations: { () -> Void in
            sideMenuManager.sideMenuTransition.hideMenuStart()
        })

        if sideMenuManager.menuAllowPopIfPossible {
            for subViewController in presentingViewController.viewControllers {
                if type(of: subViewController) == type(of: viewController) {
                    presentingViewController.popToViewController(subViewController, animated: animated)
                    CATransaction.commit()
                    return
                }
            }
        }

        if sideMenuManager.menuReplaceOnPush {
            var viewControllers = presentingViewController.viewControllers
            viewControllers.removeLast()
            viewControllers.append(viewController)
            presentingViewController.setViewControllers(viewControllers, animated: animated)
            CATransaction.commit()
            return
        }

        if let lastViewController = presentingViewController.viewControllers.last, !sideMenuManager.menuAllowPushOfSameClassTwice && type(of: lastViewController) == type(of: viewController) {
            CATransaction.commit()
            return
        }

        presentingViewController.pushViewController(viewController, animated: animated)
        CATransaction.commit()
    }
}
