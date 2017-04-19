//
//  SideMenuManager.swift
//
//  Created by Jon Kent on 12/6/15.
//  Copyright © 2015 Jon Kent. All rights reserved.
//

/* Example usage:
     // Define the menus
     sideMenuManager.menuLeftNavigationController = storyboard!.instantiateViewController(withIdentifier: "LeftMenuNavigationController") as? UISideMenuNavigationController
     sideMenuManager.menuRightNavigationController = storyboard!.instantiateViewController(withIdentifier: "RightMenuNavigationController") as? UISideMenuNavigationController
     
     // Enable gestures. The left and/or right menus must be set up above for these to work.
     // Note that these continue to work on the Navigation Controller independent of the View Controller it displays!
     sideMenuManager.menuAddPanGestureToPresent(toView: self.navigationController!.navigationBar)
     sideMenuManager.menuAddScreenEdgePanGesturesToPresent(toView: self.navigationController!.view)
*/

open class SideMenuManager: NSObject {

    internal let sideMenuTransition: SideMenuTransition

    fileprivate static var appWindowRect: CGRect {
        return UIApplication.shared.keyWindow?.bounds ?? UIWindow().bounds
    }

    public override init() {
        sideMenuTransition = SideMenuTransition()
        let appWindowRect = type(of: self).appWindowRect
        menuWidth = max(round(min((appWindowRect.width), (appWindowRect.height)) * 0.75), 240)
        super.init()
        sideMenuTransition.sideMenuManager = self
    }

    @objc public enum MenuPresentMode: Int {
        case menuSlideIn
        case viewSlideOut
        case viewSlideInOut
        case menuDissolveIn
    }

    // Bounds which has been allocated for the app on the whole device screen
    internal var appScreenRect: CGRect {
        return type(of: self).appWindowRect
    }

    /**
     The presentation mode of the menu.
     
     There are four modes in MenuPresentMode:
     - menuSlideIn: Menu slides in over of the existing view.
     - viewSlideOut: The existing view slides out to reveal the menu.
     - viewSlideInOut: The existing view slides out while the menu slides in.
     - menuDissolveIn: The menu dissolves in over the existing view controller.
     */
    open var menuPresentMode: MenuPresentMode = .viewSlideOut

    /// Prevents the same view controller (or a view controller of the same class) from being pushed more than once. Defaults to true.
    open var menuAllowPushOfSameClassTwice = true

    /// Pops to any view controller already in the navigation stack instead of the view controller being pushed if they share the same class. Defaults to false.
    open var menuAllowPopIfPossible = false

    /// Width of the menu when presented on screen, showing the existing view controller in the remaining space. Default is 75% of the screen width.
    open var menuWidth: CGFloat

    /// Duration of the animation when the menu is presented without gestures. Default is 0.35 seconds.
    open var menuAnimationPresentDuration = 0.35

    /// Duration of the animation when the menu is dismissed without gestures. Default is 0.35 seconds.
    open var menuAnimationDismissDuration = 0.35

    /// Amount to fade the existing view controller when the menu is presented. Default is 0 for no fade. Set to 1 to fade completely.
    open var menuAnimationFadeStrength: CGFloat = 0

    /// The amount to scale the existing view controller or the menu view controller depending on the `menuPresentMode`. Default is 1 for no scaling. Less than 1 will shrink, greater than 1 will grow.
    open var menuAnimationTransformScaleFactor: CGFloat = 1

    /// The background color behind menu animations. Depending on the animation settings this may not be visible. If `menuFadeStatusBar` is true, this color is used to fade it. Default is black.
    open var menuAnimationBackgroundColor: UIColor?

    /// The shadow opacity around the menu view controller or existing view controller depending on the `menuPresentMode`. Default is 0.5 for 50% opacity.
    open var menuShadowOpacity: Float = 0.5

    /// The shadow color around the menu view controller or existing view controller depending on the `menuPresentMode`. Default is black.
    open var menuShadowColor = UIColor.black

    /// The radius of the shadow around the menu view controller or existing view controller depending on the `menuPresentMode`. Default is 5.
    open var menuShadowRadius: CGFloat = 5

    /// The left menu swipe to dismiss gesture.
    open weak var menuLeftSwipeToDismissGesture: UIPanGestureRecognizer?

    /// The right menu swipe to dismiss gesture.
    open weak var menuRightSwipeToDismissGesture: UIPanGestureRecognizer?

    /// Enable or disable interaction with the presenting view controller while the menu is displayed. Enabling may make it difficult to dismiss the menu or cause exceptions if the user tries to present and already presented menu. Default is false.
    open var menuPresentingViewControllerUserInteractionEnabled: Bool = false

    /// The strength of the parallax effect on the existing view controller. Does not apply to `menuPresentMode` when set to `ViewSlideOut`. Default is 0.
    open var menuParallaxStrength: Int = 0

    /// Draws the `menuAnimationBackgroundColor` behind the status bar. Default is true.
    open var menuFadeStatusBar = true

    /// When true, pushViewController called within the menu it will push the new view controller inside of the menu. Otherwise, it is pushed on the menu's presentingViewController. Default is false.
    open var menuAllowSubmenus: Bool = false

    /// When true, pushViewController will replace the last view controller in the navigation controller's viewController stack instead of appending to it. This makes menus similar to tab bar controller behavior.
    open var menuReplaceOnPush: Bool = false

    /// -Warning: Deprecated. Use `menuAnimationTransformScaleFactor` instead.
    @available(*, deprecated, renamed: "menuAnimationTransformScaleFactor")
    open var menuAnimationShrinkStrength: CGFloat {
        get {
            return menuAnimationTransformScaleFactor
        }
        set {
            menuAnimationTransformScaleFactor = newValue
        }
    }

    /**
     The blur effect style of the menu if the menu's root view controller is a UITableViewController or UICollectionViewController.
     
     - Note: If you want cells in a UITableViewController menu to show vibrancy, make them a subclass of UITableViewVibrantCell and set the cell's sideMenuManager property.
     */
    open var menuBlurEffectStyle: UIBlurEffectStyle? {
        didSet {
            if oldValue != menuBlurEffectStyle {
                updateMenuBlurIfNecessary()
            }
        }
    }

    /// The left menu.
    open var menuLeftNavigationController: UISideMenuNavigationController? {
        willSet {
            if menuLeftNavigationController?.presentingViewController == nil {
                removeMenuBlurForMenu(menuLeftNavigationController)
            }
        }
        didSet {
            guard oldValue?.presentingViewController == nil else {
                print("SideMenu Warning: menuLeftNavigationController cannot be modified while it's presented.")
                menuLeftNavigationController = oldValue
                return
            }
            setupNavigationController(menuLeftNavigationController, leftSide: true)
        }
    }

    /// The right menu.
    open var menuRightNavigationController: UISideMenuNavigationController? {
        willSet {
            if menuRightNavigationController?.presentingViewController == nil {
                removeMenuBlurForMenu(menuRightNavigationController)
            }
        }
        didSet {
            guard oldValue?.presentingViewController == nil else {
                print("SideMenu Warning: menuRightNavigationController cannot be modified while it's presented.")
                menuRightNavigationController = oldValue
                return
            }
            setupNavigationController(menuRightNavigationController, leftSide: false)
        }
    }

    fileprivate func setupNavigationController(_ forMenu: UISideMenuNavigationController?, leftSide: Bool) {
        guard let forMenu = forMenu else {
            return
        }

        if menuEnableSwipeGestures {
            let exitPanGesture = UIPanGestureRecognizer()
            exitPanGesture.addTarget(sideMenuTransition, action:#selector(SideMenuTransition.handleHideMenuPan(_:)))
            forMenu.view.addGestureRecognizer(exitPanGesture)
            if leftSide {
                menuLeftSwipeToDismissGesture = exitPanGesture
            } else {
                menuRightSwipeToDismissGesture = exitPanGesture
            }
        }
        forMenu.transitioningDelegate = sideMenuTransition
        forMenu.modalPresentationStyle = .overFullScreen
        forMenu.leftSide = leftSide
        updateMenuBlurIfNecessary()
    }

    /// Enable or disable gestures that would swipe to present or dismiss the menu. Default is true.
    open var menuEnableSwipeGestures: Bool = true {
        didSet {
            menuLeftSwipeToDismissGesture?.view?.removeGestureRecognizer(menuLeftSwipeToDismissGesture!)
            menuRightSwipeToDismissGesture?.view?.removeGestureRecognizer(menuRightSwipeToDismissGesture!)
            setupNavigationController(menuLeftNavigationController, leftSide: true)
            setupNavigationController(menuRightNavigationController, leftSide: false)
        }
    }

    fileprivate func updateMenuBlurIfNecessary() {
        let menuBlurBlock = { (forMenu: UISideMenuNavigationController?) in
            if let forMenu = forMenu {
                self.setupMenuBlurForMenu(forMenu)
            }
        }

        menuBlurBlock(menuLeftNavigationController)
        menuBlurBlock(menuRightNavigationController)
    }

    fileprivate func setupMenuBlurForMenu(_ forMenu: UISideMenuNavigationController?) {
        removeMenuBlurForMenu(forMenu)

        guard let forMenu = forMenu,
            let menuBlurEffectStyle = menuBlurEffectStyle,
            let view = forMenu.visibleViewController?.view, !UIAccessibilityIsReduceTransparencyEnabled() else {
                return
        }

        if forMenu.originalMenuBackgroundColor == nil {
            forMenu.originalMenuBackgroundColor = view.backgroundColor
        }

        let blurEffect = UIBlurEffect(style: menuBlurEffectStyle)
        let blurView = UIVisualEffectView(effect: blurEffect)
        view.backgroundColor = UIColor.clear
        if let tableViewController = forMenu.visibleViewController as? UITableViewController {
            tableViewController.tableView.backgroundView = blurView
            tableViewController.tableView.separatorEffect = UIVibrancyEffect(blurEffect: blurEffect)
            tableViewController.tableView.reloadData()
        } else {
            blurView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
            blurView.frame = view.bounds
            view.insertSubview(blurView, at: 0)
        }
    }

    fileprivate func removeMenuBlurForMenu(_ forMenu: UISideMenuNavigationController?) {
        guard let forMenu = forMenu,
            let originalMenuBackgroundColor = forMenu.originalMenuBackgroundColor,
            let view = forMenu.visibleViewController?.view else {
                return
        }

        view.backgroundColor = originalMenuBackgroundColor
        forMenu.originalMenuBackgroundColor = nil

        if let tableViewController = forMenu.visibleViewController as? UITableViewController {
            tableViewController.tableView.backgroundView = nil
            tableViewController.tableView.separatorEffect = nil
            tableViewController.tableView.reloadData()
        } else if let blurView = view.subviews[0] as? UIVisualEffectView {
            blurView.removeFromSuperview()
        }
    }

    /// This dismisses the currently presented view controller and hide the sideMenu.
    public func hideMenu() {
        if let menuViewController: UINavigationController = sideMenuTransition.presentDirection == .left ? menuLeftNavigationController : menuRightNavigationController,
            menuViewController.presentedViewController == nil {
            sideMenuTransition.hideMenuStart()
            sideMenuTransition.hideMenuComplete()
            menuViewController.dismiss(animated: false, completion: nil)
        }
    }

    /**
     Adds screen edge gestures to a view to present a menu.
     
     - Parameter toView: The view to add gestures to.
     - Parameter forMenu: The menu (left or right) you want to add a gesture for. If unspecified, gestures will be added for both sides.
 
     - Returns: The array of screen edge gestures added to `toView`.
     */
    @discardableResult open func menuAddScreenEdgePanGesturesToPresent(toView: UIView, forMenu: UIRectEdge? = nil) -> [UIScreenEdgePanGestureRecognizer] {
        var array = [UIScreenEdgePanGestureRecognizer]()

        if forMenu != .right {
            let leftScreenEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer()
            leftScreenEdgeGestureRecognizer.addTarget(self.sideMenuTransition, action:#selector(SideMenuTransition.handlePresentMenuLeftScreenEdge(_:)))
            leftScreenEdgeGestureRecognizer.edges = .left
            leftScreenEdgeGestureRecognizer.cancelsTouchesInView = true
            toView.addGestureRecognizer(leftScreenEdgeGestureRecognizer)
            array.append(leftScreenEdgeGestureRecognizer)
        }

        if forMenu != .left {
            let rightScreenEdgeGestureRecognizer = UIScreenEdgePanGestureRecognizer()
            rightScreenEdgeGestureRecognizer.addTarget(self.sideMenuTransition, action:#selector(SideMenuTransition.handlePresentMenuRightScreenEdge(_:)))
            rightScreenEdgeGestureRecognizer.edges = .right
            rightScreenEdgeGestureRecognizer.cancelsTouchesInView = true
            toView.addGestureRecognizer(rightScreenEdgeGestureRecognizer)
            array.append(rightScreenEdgeGestureRecognizer)
        }

        return array
    }

    /**
     Adds a pan edge gesture to a view to present menus.
     
     - Parameter toView: The view to add a pan gesture to.
     
     - Returns: The pan gesture added to `toView`.
     */
    @discardableResult open func menuAddPanGestureToPresent(toView: UIView) -> UIPanGestureRecognizer {
        let panGestureRecognizer = UIPanGestureRecognizer()
        panGestureRecognizer.addTarget(self.sideMenuTransition, action:#selector(SideMenuTransition.handlePresentMenuPan(_:)))
        toView.addGestureRecognizer(panGestureRecognizer)

        return panGestureRecognizer
    }
}
