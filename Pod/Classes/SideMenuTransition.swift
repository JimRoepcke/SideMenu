//
//  SideMenuTransition.swift
//  Pods
//
//  Created by Jon Kent on 1/14/16.
//
//

import UIKit

open class SideMenuTransition: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate {

    fileprivate var presenting = false
    fileprivate var interactive = false
    fileprivate weak var originalSuperview: UIView?
    fileprivate var switchMenus = false

    internal var presentDirection: UIRectEdge = .left
    internal weak var tapView: UIView?
    internal weak var statusBarView: UIView?

    internal weak var sideMenuManager: SideMenuManager?

    fileprivate var viewControllerForPresentedMenu: UIViewController? {
        get {
            guard let sideMenuManager = sideMenuManager else {
                return nil
            }
            return sideMenuManager.menuLeftNavigationController?.presentingViewController != nil ? sideMenuManager.menuLeftNavigationController?.presentingViewController : sideMenuManager.menuRightNavigationController?.presentingViewController
        }
    }

    fileprivate var visibleViewController: UIViewController? {
        get {
            return getVisibleViewControllerFromViewController(UIApplication.shared.keyWindow?.rootViewController)
        }
    }

    fileprivate func getVisibleViewControllerFromViewController(_ viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return getVisibleViewControllerFromViewController(navigationController.visibleViewController)
        } else if let tabBarController = viewController as? UITabBarController {
            return getVisibleViewControllerFromViewController(tabBarController.selectedViewController)
        } else if let presentedViewController = viewController?.presentedViewController {
            return getVisibleViewControllerFromViewController(presentedViewController)
        }

        return viewController
    }

    @objc
    internal func handlePresentMenuLeftScreenEdge(_ edge: UIScreenEdgePanGestureRecognizer) {
        presentDirection = .left
        handlePresentMenuPan(edge)
    }

    @objc
    internal func handlePresentMenuRightScreenEdge(_ edge: UIScreenEdgePanGestureRecognizer) {
        presentDirection = .right
        handlePresentMenuPan(edge)
    }

    @objc
    internal func handlePresentMenuPan(_ pan: UIPanGestureRecognizer) {
        guard let sideMenuManager = sideMenuManager else {
            return
        }
        // how much distance have we panned in reference to the parent view?
        guard let view = viewControllerForPresentedMenu != nil ? viewControllerForPresentedMenu?.view : pan.view else {
            return
        }

        let transform = view.transform
        view.transform = CGAffineTransform.identity
        let translation = pan.translation(in: pan.view!)
        view.transform = transform

        // do some math to translate this to a percentage based value
        if !interactive {
            if translation.x == 0 {
                return // not sure which way the user is swiping yet, so do nothing
            }

            if !(pan is UIScreenEdgePanGestureRecognizer) {
                presentDirection = translation.x > 0 ? .left : .right
            }

            if let menuViewController = presentDirection == .left ? sideMenuManager.menuLeftNavigationController : sideMenuManager.menuRightNavigationController,
                let visibleViewController = visibleViewController {
                interactive = true
                visibleViewController.present(menuViewController, animated: true, completion: nil)
            }
        }

        let direction: CGFloat = presentDirection == .left ? 1 : -1
        let distance = translation.x / sideMenuManager.menuWidth
        // now lets deal with different states that the gesture recognizer sends
        switch (pan.state) {
        case .began, .changed:
            if pan is UIScreenEdgePanGestureRecognizer {
                update(min(distance * direction, 1))
            } else if distance > 0 && presentDirection == .right && sideMenuManager.menuLeftNavigationController != nil {
                presentDirection = .left
                switchMenus = true
                cancel()
            } else if distance < 0 && presentDirection == .left && sideMenuManager.menuRightNavigationController != nil {
                presentDirection = .right
                switchMenus = true
                cancel()
            } else {
                update(min(distance * direction, 1))
            }
        default:
            interactive = false
            view.transform = CGAffineTransform.identity
            let velocity = pan.velocity(in: pan.view!).x * direction
            view.transform = transform
            if velocity >= 100 || velocity >= -50 && abs(distance) >= 0.5 {
                // bug workaround: animation briefly resets after call to finishInteractiveTransition() but before animateTransition completion is called.
                if ProcessInfo().operatingSystemVersion.majorVersion == 8 && percentComplete > 1 - CGFloat.ulpOfOne {
                    update(0.9999)
                }
                finish()
            } else {
                cancel()
            }
        }
    }

    @objc
    internal func handleHideMenuPan(_ pan: UIPanGestureRecognizer) {
        guard let sideMenuManager = sideMenuManager else {
            return
        }
        let translation = pan.translation(in: pan.view!)
        let direction: CGFloat = presentDirection == .left ? -1 : 1
        let distance = translation.x / sideMenuManager.menuWidth * direction

        switch (pan.state) {

        case .began:
            interactive = true
            viewControllerForPresentedMenu?.dismiss(animated: true, completion: nil)
        case .changed:
            update(max(min(distance, 1), 0))
        default:
            interactive = false
            let velocity = pan.velocity(in: pan.view!).x * direction
            if velocity >= 100 || velocity >= -50 && distance >= 0.5 {
                // bug workaround: animation briefly resets after call to finishInteractiveTransition() but before animateTransition completion is called.
                if ProcessInfo().operatingSystemVersion.majorVersion == 8 && percentComplete > 1 - CGFloat.ulpOfOne {
                    update(0.9999)
                }
                finish()
            } else {
                cancel()
            }
        }
    }

    @objc
    internal func handleHideMenuTap(_ tap: UITapGestureRecognizer) {
        viewControllerForPresentedMenu?.dismiss(animated: true, completion: nil)
    }

    internal func hideMenuStart() {
        if observeAppEnterBackground {
            NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        }
        guard let sideMenuManager = sideMenuManager,
            let mainViewController = viewControllerForPresentedMenu,
            let menuView = presentDirection == .left ? sideMenuManager.menuLeftNavigationController?.view : sideMenuManager.menuRightNavigationController?.view else {return}

        menuView.transform = CGAffineTransform.identity
        mainViewController.view.transform = CGAffineTransform.identity
        mainViewController.view.alpha = 1
        tapView?.frame = CGRect(x: 0, y: 0, width: mainViewController.view.frame.width, height: mainViewController.view.frame.height)
        menuView.frame.origin.y = 0
        menuView.frame.size.width = sideMenuManager.menuWidth
        menuView.frame.size.height = mainViewController.view.frame.height
        statusBarView?.frame = UIApplication.shared.statusBarFrame
        statusBarView?.alpha = 0

        switch sideMenuManager.menuPresentMode {

        case .viewSlideOut:
            menuView.alpha = 1 - sideMenuManager.menuAnimationFadeStrength
            menuView.frame.origin.x = presentDirection == .left ? 0 : mainViewController.view.frame.width - sideMenuManager.menuWidth
            mainViewController.view.frame.origin.x = 0
            menuView.transform = CGAffineTransform(scaleX: sideMenuManager.menuAnimationTransformScaleFactor, y: sideMenuManager.menuAnimationTransformScaleFactor)

        case .viewSlideInOut:
            menuView.alpha = 1
            menuView.frame.origin.x = presentDirection == .left ? -menuView.frame.width : mainViewController.view.frame.width
            mainViewController.view.frame.origin.x = 0

        case .menuSlideIn:
            menuView.alpha = 1
            menuView.frame.origin.x = presentDirection == .left ? -menuView.frame.width : mainViewController.view.frame.width

        case .menuDissolveIn:
            menuView.alpha = 0
            menuView.frame.origin.x = presentDirection == .left ? 0 : mainViewController.view.frame.width - sideMenuManager.menuWidth
            mainViewController.view.frame.origin.x = 0
        }
    }

    internal func hideMenuComplete() {
        guard let sideMenuManager = sideMenuManager,
            let mainViewController = viewControllerForPresentedMenu,
            let menuView = presentDirection == .left ? sideMenuManager.menuLeftNavigationController?.view : sideMenuManager.menuRightNavigationController?.view else {
                return
        }

        tapView?.removeFromSuperview()
        statusBarView?.removeFromSuperview()
        mainViewController.view.motionEffects.removeAll()
        mainViewController.view.layer.shadowOpacity = 0
        menuView.layer.shadowOpacity = 0
        if let topNavigationController = mainViewController as? UINavigationController {
            topNavigationController.interactivePopGestureRecognizer!.isEnabled = true
        }
        originalSuperview?.addSubview(mainViewController.view)
    }

    internal func presentMenuStart(forSize size: CGSize) {
        guard let sideMenuManager = sideMenuManager else {
            return
        }
        guard let menuView = presentDirection == .left ? sideMenuManager.menuLeftNavigationController?.view : sideMenuManager.menuRightNavigationController?.view,
            let mainViewController = viewControllerForPresentedMenu else {
                return
        }

        menuView.transform = CGAffineTransform.identity
        mainViewController.view.transform = CGAffineTransform.identity
        menuView.frame.size.width = sideMenuManager.menuWidth
        menuView.frame.size.height = size.height
        menuView.frame.origin.x = presentDirection == .left ? 0 : size.width - sideMenuManager.menuWidth
        statusBarView?.frame = UIApplication.shared.statusBarFrame
        statusBarView?.alpha = 1

        switch sideMenuManager.menuPresentMode {

        case .viewSlideOut:
            menuView.alpha = 1
            let direction: CGFloat = presentDirection == .left ? 1 : -1
            mainViewController.view.frame.origin.x = direction * (menuView.frame.width)
            mainViewController.view.layer.shadowColor = sideMenuManager.menuShadowColor.cgColor
            mainViewController.view.layer.shadowRadius = sideMenuManager.menuShadowRadius
            mainViewController.view.layer.shadowOpacity = sideMenuManager.menuShadowOpacity
            mainViewController.view.layer.shadowOffset = CGSize(width: 0, height: 0)

        case .viewSlideInOut:
            menuView.alpha = 1
            mainViewController.view.layer.shadowColor = sideMenuManager.menuShadowColor.cgColor
            mainViewController.view.layer.shadowRadius = sideMenuManager.menuShadowRadius
            mainViewController.view.layer.shadowOpacity = sideMenuManager.menuShadowOpacity
            mainViewController.view.layer.shadowOffset = CGSize(width: 0, height: 0)
            let direction: CGFloat = presentDirection == .left ? 1 : -1
            mainViewController.view.frame = CGRect(x: direction * (menuView.frame.width), y: 0, width: size.width, height: size.height)
            mainViewController.view.transform = CGAffineTransform(scaleX: sideMenuManager.menuAnimationTransformScaleFactor, y: sideMenuManager.menuAnimationTransformScaleFactor)
            mainViewController.view.alpha = 1 - sideMenuManager.menuAnimationFadeStrength

        case .menuSlideIn, .menuDissolveIn:
            menuView.alpha = 1
            if sideMenuManager.menuBlurEffectStyle == nil {
                menuView.layer.shadowColor = sideMenuManager.menuShadowColor.cgColor
                menuView.layer.shadowRadius = sideMenuManager.menuShadowRadius
                menuView.layer.shadowOpacity = sideMenuManager.menuShadowOpacity
                menuView.layer.shadowOffset = CGSize(width: 0, height: 0)
            }
            mainViewController.view.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            mainViewController.view.transform = CGAffineTransform(scaleX: sideMenuManager.menuAnimationTransformScaleFactor, y: sideMenuManager.menuAnimationTransformScaleFactor)
            mainViewController.view.alpha = 1 - sideMenuManager.menuAnimationFadeStrength
        }
    }

    internal var observeAppEnterBackground: Bool {
        return false
    }

    internal func presentMenuComplete() {
        if observeAppEnterBackground {
            NotificationCenter.default.addObserver(self, selector:#selector(SideMenuTransition.applicationDidEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        }

        guard let sideMenuManager = sideMenuManager,
            let mainViewController = viewControllerForPresentedMenu else {
            return
        }

        switch sideMenuManager.menuPresentMode {
        case .menuSlideIn, .menuDissolveIn, .viewSlideInOut:
            if sideMenuManager.menuParallaxStrength != 0 {
                let horizontal = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
                horizontal.minimumRelativeValue = -sideMenuManager.menuParallaxStrength
                horizontal.maximumRelativeValue = sideMenuManager.menuParallaxStrength

                let vertical = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongVerticalAxis)
                vertical.minimumRelativeValue = -sideMenuManager.menuParallaxStrength
                vertical.maximumRelativeValue = sideMenuManager.menuParallaxStrength

                let group = UIMotionEffectGroup()
                group.motionEffects = [horizontal, vertical]
                mainViewController.view.addMotionEffect(group)
            }
        case .viewSlideOut: break
        }
        if let topNavigationController = mainViewController as? UINavigationController {
            topNavigationController.interactivePopGestureRecognizer!.isEnabled = false
        }
    }

    // MARK: UIViewControllerAnimatedTransitioning protocol methods

    // animate a change from one viewcontroller to another
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let sideMenuManager = sideMenuManager else {
            return
        }

        // get reference to our fromView, toView and the container view that we should perform the transition in
        let container = transitionContext.containerView
        if let menuBackgroundColor = sideMenuManager.menuAnimationBackgroundColor {
            container.backgroundColor = menuBackgroundColor
        }

        // create a tuple of our screens
        let screens : (from: UIViewController, to: UIViewController) = (transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!, transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!)

        // assign references to our menu view controller and the 'bottom' view controller from the tuple
        // remember that our menuViewController will alternate between the from and to view controller depending if we're presenting or dismissing
        let menuViewController = (!presenting ? screens.from : screens.to)
        let topViewController = !presenting ? screens.to : screens.from

        let menuView = menuViewController.view
        let topView = topViewController.view

        // prepare menu items to slide in
        if presenting {
            var tapView: UIView?
            if !sideMenuManager.menuPresentingViewControllerUserInteractionEnabled {
                tapView = UIView()
                tapView!.autoresizingMask = [.flexibleHeight, .flexibleWidth]
                let exitPanGesture = UIPanGestureRecognizer()
                exitPanGesture.addTarget(self, action:#selector(SideMenuTransition.handleHideMenuPan(_:)))
                let exitTapGesture = UITapGestureRecognizer()
                exitTapGesture.addTarget(self, action: #selector(SideMenuTransition.handleHideMenuTap(_:)))
                tapView!.addGestureRecognizer(exitPanGesture)
                tapView!.addGestureRecognizer(exitTapGesture)
                self.tapView = tapView
            }

            originalSuperview = topView?.superview

            // add the both views to our view controller
            switch sideMenuManager.menuPresentMode {
            case .viewSlideOut, .viewSlideInOut:
                container.addSubview(menuView!)
                container.addSubview(topView!)
                if let tapView = tapView {
                    topView?.addSubview(tapView)
                }
            case .menuSlideIn, .menuDissolveIn:
                container.addSubview(topView!)
                if let tapView = tapView {
                    container.addSubview(tapView)
                }
                container.addSubview(menuView!)
            }

            if sideMenuManager.menuFadeStatusBar {
                let blackBar = UIView()
                if let menuShrinkBackgroundColor = sideMenuManager.menuAnimationBackgroundColor {
                    blackBar.backgroundColor = menuShrinkBackgroundColor
                } else {
                    blackBar.backgroundColor = UIColor.black
                }
                blackBar.isUserInteractionEnabled = false
                container.addSubview(blackBar)
                statusBarView = blackBar
            }

            hideMenuStart() // offstage for interactive
        }

        // perform the animation!
        let duration = transitionDuration(using: transitionContext)
        let options: UIView.AnimationOptions = interactive ? .curveLinear : []
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: { () -> Void in
            if self.presenting {
                self.presentMenuStart(forSize: sideMenuManager.appScreenRect.size) // onstage items: slide in
            } else {
                self.hideMenuStart()
            }
            menuView?.isUserInteractionEnabled = false
        }) { (_) -> Void in
            // tell our transitionContext object that we've finished animating
            if transitionContext.transitionWasCancelled {

                if self.presenting {
                    self.hideMenuComplete()
                } else {
                    self.presentMenuComplete()
                }
                menuView?.isUserInteractionEnabled = true

                transitionContext.completeTransition(false)

                if self.switchMenus {
                    self.switchMenus = false
                    self.viewControllerForPresentedMenu?.present(self.presentDirection == .left ? sideMenuManager.menuLeftNavigationController! : sideMenuManager.menuRightNavigationController!, animated: true, completion: nil)
                }

                return
            }

            if self.presenting {
                self.presentMenuComplete()
                menuView?.isUserInteractionEnabled = true
                transitionContext.completeTransition(true)
                switch sideMenuManager.menuPresentMode {
                case .viewSlideOut, .viewSlideInOut:
                    container.addSubview(topView!)
                case .menuSlideIn, .menuDissolveIn:
                    container.insertSubview(topView!, at: 0)
                }
                if let statusBarView = self.statusBarView {
                    container.bringSubviewToFront(statusBarView)
                }

                return
            }

            self.hideMenuComplete()
            transitionContext.completeTransition(true)
            menuView?.removeFromSuperview()
        }
    }

    // return how many seconds the transiton animation will take
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        guard let sideMenuManager = sideMenuManager else {
            return 0.0
        }
        return presenting ? sideMenuManager.menuAnimationPresentDuration : sideMenuManager.menuAnimationDismissDuration
    }

    // MARK: UIViewControllerTransitioningDelegate protocol methods

    // return the animator when presenting a viewcontroller
    // rememeber that an animator (or animation controller) is any object that aheres to the UIViewControllerAnimatedTransitioning protocol
    open func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.presenting = true
        guard let sideMenuManager = sideMenuManager else {
            return self
        }
        presentDirection = presented == sideMenuManager.menuLeftNavigationController ? .left : .right
        return self
    }

    // return the animator used when dismissing from a viewcontroller
    open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presenting = false
        return self
    }

    open func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        // if our interactive flag is true, return the transition manager object
        // otherwise return nil
        return interactive ? self : nil
    }

    open func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactive ? self: nil
    }

    @objc
    internal func applicationDidEnterBackgroundNotification() {
        hideMenu()
    }

    internal func hideMenu() {
        guard let sideMenuManager = sideMenuManager else {
            return
        }
        if let menuViewController: UINavigationController = presentDirection == .left ? sideMenuManager.menuLeftNavigationController : sideMenuManager.menuRightNavigationController,
            menuViewController.presentedViewController == nil {
            hideMenuStart()
            hideMenuComplete()
            menuViewController.dismiss(animated: false, completion: nil)
        }
    }

}

#if swift(>=3.1)

#else
fileprivate extension CGFloat {
    static var ulpOfOne: CGFloat {
        return CGFloat(FLT_EPSILON)
    }
}
#endif
