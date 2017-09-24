//
//  ViewController.swift
//  Paper Toss AR
//
//  Created by Lasse Hammer Priebe on 20/09/2017.
//  Copyright © 2017 Hundredeni. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ARViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var helperViewController: ARHelperViewController? {
        let _controller = storyboard?.instantiateViewController(withIdentifier: "helperViewController") as? ARHelperViewController
        _controller?.modalPresentationStyle = .overFullScreen
        _controller?.modalTransitionStyle = .crossDissolve
        _controller?.actionBlock = { (controller, sender) in
            self.presentActions(in: controller, sender: sender)
        }
        return _controller
    }
    var activeHelperViewController: ARHelperViewController?
    
    var configurationProgress: ARConfigurationProgress?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupGestureRecognizers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        enterPreparationPhase()
        
        // Disallow sleeping while in ar
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        // Allow the device to sleep again
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - SceneKit Nodes
    
    private var paperNode: SCNNode?
    private var panSurfaceNode: SCNNode?
    private var planeNodes = [ARPlaneAnchor: PlaneNode]()
    private var trashcanNode: SCNNode?
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        // Check if the anchor represents a plane
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        // Create a plane node for the anchor
        let plane = PlaneNode(anchor: planeAnchor)
        planeNodes[planeAnchor] = plane
        node.addChildNode(plane)

        // Update the configuration progress if detecting planes.
        if configurationProgress == .detectingPlanes {
            
            DispatchQueue.main.async {
                self.activeHelperViewController?.blocking = false
                
                // Vibrate to let the user know plane detection is done.
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                
                self.enterObjectPlacementPhase()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        // Check if the anchor represents a plane
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        // Update the plane node with the anchor
        if let plane = planeNodes[planeAnchor] {
            plane.update(anchor: planeAnchor)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    // MARK: - SCNPhysicsContactDelegate
    
    private var score = 0
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

        guard let aBody = contact.nodeA.physicsBody, let bBody = contact.nodeB.physicsBody else {
            return
        }
        
        let contactMask = aBody.categoryBitMask | bBody.categoryBitMask
        let goalMask = CategoryBitMask.paper | CategoryBitMask.target
        
        if contactMask == goalMask {
            let nodes = [contact.nodeA, contact.nodeB]
            if let paper = (nodes.filter { $0.name != "target" }).first {
                
                // Disable further interaction and remove
                paper.physicsBody = nil
                paper.removeFromParentNode()
                paperNode = nil
                
                // Show score overlay
                score += 1
                updateScoreNode(score: score)
            }
        }
    }
    
    private var scoreNode: SCNNode?
    
    func updateScoreNode(score: Int) {
        
        let textMaterial = SCNMaterial()
        textMaterial.diffuse.contents = #colorLiteral(red: 1, green: 0.7738900781, blue: 0.1969780922, alpha: 1)
        
        // Create text geometry
        let text = SCNText(string: "Score: \(score)", extrusionDepth: 0.01)
        text.materials = [textMaterial]
        text.font = UIFont.systemFont(ofSize: 0.1)
        text.alignmentMode = kCAAlignmentCenter
        
        // Create and center text node
        let textNode = SCNNode(geometry: text)
        centerPivot(for: textNode)
        textNode.position.y = 0.5
        
        // Constrain to always look at camera
        let lookAtCameraConstraint = SCNBillboardConstraint()
        lookAtCameraConstraint.freeAxes = [.Y, .X]
        textNode.constraints = [lookAtCameraConstraint]
        
        // Add to scene by replacing old node
        scoreNode?.removeAllActions()
        scoreNode?.removeFromParentNode()
        scoreNode = textNode
        trashcanNode?.addChildNode(textNode)
        textNode.runAction(SCNAction.fadeOut(duration: 2))
    }
    
    func centerPivot(for node: SCNNode) {
        let (min, max) = node.boundingBox
        node.pivot = SCNMatrix4MakeTranslation(
            min.x + (max.x - min.x)/2,
            min.y + (max.y - min.y)/2,
            min.z + (max.z - min.z)/2
        )
    }
    
    // MARK: - Configuration progress
    
    private func enterPreparationPhase() {
        
        configurationProgress = .preparing
        
        // Start orientation tracking
        runOrientationTrackingConfiguration()
        
        // Present helper view controller
        guard let helperViewController = helperViewController else {
            return
        }
        helperViewController.configurationBlock = { controller in
            controller.configureForSceneSelection()
        }
        helperViewController.completionBlock = {
            self.enterPlaneDetectionPhase()
            self.activeHelperViewController = nil
        }
        present(helperViewController, animated: true) {
            self.activeHelperViewController = helperViewController
        }
    }

    private func enterPlaneDetectionPhase() {
        
        configurationProgress = .detectingPlanes
        
        // Present helper view controller
        guard let helperViewController = helperViewController else {
            return
        }
        helperViewController.configurationBlock = { controller in
            controller.configureForPlaneDetection()
        }
        helperViewController.completionBlock = {
            self.activeHelperViewController = nil
        }
        present(helperViewController, animated: true) {
            self.activeHelperViewController = helperViewController
        }
        
        // Start detecting planes
        runPlaneDetectionConfiguration()
    }
    
    private func enterObjectPlacementPhase() {
        
        configurationProgress = .placingObjects
        
        // Continue plane detection
        runPlaneDetectionConfiguration()
        
        // Show detected planes
        showPlaneNodes()
    }
    
    private func enterCompletedPhase() {
        
        configurationProgress = .completed
        
        // Start world tracking
        runWorldTrackingConfiguration()
        
        // Hide detected planes
        hidePlaneNodes()
    }
    
    private func runOrientationTrackingConfiguration() {
        
        // Don't show feature points
        sceneView.debugOptions = []
        
        // Create a world tracking session configuration
        let configuration = AROrientationTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    private func runWorldTrackingConfiguration() {
        
        // Don't show feature points
        sceneView.debugOptions = []
        
        // Create a world tracking session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    private func runPlaneDetectionConfiguration() {
        
        // Show feature points
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        // Create a plane detecting session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    private func hidePlaneNodes() {
        SCNTransaction.animationDuration = 1
        for (_, node) in planeNodes {
            node.opacity = 0
        }
    }
    
    private func showPlaneNodes() {
        SCNTransaction.animationDuration = 1
        for (_, node) in planeNodes {
            node.opacity = 1
        }
    }
    
    // MARK: - Actions
    
    @IBAction func actionButtonTouchUpInside(_ sender: Any) {
        presentActions(in: self, sender: sender)
    }
    
    private func presentActions(in controller: UIViewController, sender: Any) {
        
        // Create action sheet
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheetController.view.tintColor = .black
        
        // Add action to reset the ar configuration
        let reconfigureAction = UIAlertAction(title: "Reset Session", style: .default) { _ in
            if let helperViewController = self.activeHelperViewController {
                helperViewController.dismiss(animated: true) {
                    self.enterPreparationPhase()
                }
            } else {
                self.enterPreparationPhase()
            }
        }
        actionSheetController.addAction(reconfigureAction)
        
        // Add action to reposition the virtual objects
        if configurationProgress == .completed {
            let repositionAction = UIAlertAction(title: "Reposition Trashcan", style: .default) { _ in
                if let helperViewController = self.activeHelperViewController {
                    helperViewController.dismiss(animated: true) {
                        self.enterObjectPlacementPhase()
                    }
                } else {
                    self.enterObjectPlacementPhase()
                }
            }
            actionSheetController.addAction(repositionAction)
        }
        
        // Add action to leave the ar viewer
        let leaveAction = UIAlertAction(title: "Leave", style: .destructive) { _ in
            if let helperViewController = self.activeHelperViewController {
                helperViewController.dismiss(animated: true) {
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }
        actionSheetController.addAction(leaveAction)
        
        // Add default action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        actionSheetController.addAction(cancelAction)
        
        // Configure popover controller for iPad
        if let popoverController = actionSheetController.popoverPresentationController {
            if let rect = (sender as? UIView)?.frame {
                popoverController.sourceView = self.view
                popoverController.sourceRect = rect
            }
        }
        
        controller.present(actionSheetController, animated: true, completion: nil)
    }
    
    // MARK: - Private
    
    private func setupSceneView() {
        
        // Set the view's delegate
        sceneView.delegate = self

        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/world.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Become the contact delegate of the scene
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    private func setupGestureRecognizers() {
        
        // Add tap gesture recognizer
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didReceiveTapGesture))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
        
        // Add pan gesture recognizer
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didReceivePanGesture))
        sceneView.addGestureRecognizer(panGestureRecognizer)
        
        // Add pan surface
        let panSurfaceNode = createPanSurfaceNode()
        panSurfaceNode.isHidden = true
        panSurfaceNode.position = SCNVector3(0, 0, -0.2)
        if let pointOfView = sceneView.pointOfView {
            pointOfView.addChildNode(panSurfaceNode)
            self.panSurfaceNode = panSurfaceNode
        }
    }
    
    @objc func didReceivePanGesture(_ sender: UIPanGestureRecognizer) {
        
        guard configurationProgress == .completed else { return }
        
        // Handle .ended
        guard sender.state != .ended else {
            
            paperNode?.physicsBody?.isAffectedByGravity = true
            
            // Apply outward force to the paper ball
            let (userDirection, _) = getUserVectors()
            let velocity = sender.velocity(in: sceneView)
            let norm = Float(sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))) / 1000
            let outwardForce = SCNVector3(userDirection.x * norm, userDirection.y * norm, userDirection.z * norm)
            paperNode?.physicsBody?.applyForce(outwardForce, asImpulse: true)
            
            // Apply upward force to the paper ball
            let upwardForce = SCNVector3(0, norm, 0)
            paperNode?.physicsBody?.applyForce(upwardForce, asImpulse: true)
            return
        }
        
        // Handle .failed, .cancelled
        let allowedStates: [UIGestureRecognizerState] = [.began, .changed]
        guard allowedStates.contains(sender.state) else {
            paperNode?.removeFromParentNode()
            paperNode = nil
            return
        }
        
        // Handle .began
        if sender.state == .began {
            
            // Reset score if last ball didn't hit
            if let previousNode = self.paperNode {
                score = 0
                let fadeOutAction = SCNAction.fadeOut(duration: 1)
                previousNode.runAction(fadeOutAction, completionHandler: {
                    previousNode.removeFromParentNode()
                })
            }
            
            
            // Create new paper node
            let paperNode = createPaperNode()
            sceneView.scene.rootNode.addChildNode(paperNode)
            self.paperNode = paperNode
        }
        
        // Update paper node position
        let touchLocation = sender.location(in: sceneView)
        let hitTestResult = sceneView.hitTest(touchLocation, options: [.ignoreHiddenNodes: false, .searchMode: SCNHitTestSearchMode.all.rawValue])
        for result in hitTestResult {
            if result.node === panSurfaceNode {
                paperNode?.position = result.worldCoordinates
            }
        }
    }
    
    @objc func didReceiveTapGesture(_ sender: UITapGestureRecognizer) {
        
        guard configurationProgress == .placingObjects else { return }
        
        // Get the world position of the recognizer
        guard let position = getPositionInWorld(from: sender) else {
            return
        }
        
        // Add trashcan node to the selected position.
        trashcanNode?.removeFromParentNode()
        guard let trashcanNode = SCNScene(named: "art.scnassets/trashcan.scn")?.rootNode else {
            return
        }
        trashcanNode.position = position
        sceneView.scene.rootNode.addChildNode(trashcanNode)
        self.trashcanNode = trashcanNode
        
        // Go to completed phase.
        enterCompletedPhase()
    }
    
    private func getPositionInWorld(from recognizer: UIGestureRecognizer) -> SCNVector3? {
        
        // Hit test the tap gesture location in the scene view.
        guard let sceneView = recognizer.view as? ARSCNView else {
            return nil
        }
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlane)
        
        // Check if the hit test resulted in at least one hit.
        guard let firstResult = hitTestResults.first else {
            return nil
        }
        
        return firstResult.positionInWorld
    }
    
    private func createPaperNode() -> SCNNode {
        
        // Create paper material
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.lightingModel = .physicallyBased
        
        // Create paper geometry
        let geometry = SCNSphere(radius: 0.05)
        geometry.isGeodesic = true
        geometry.segmentCount = 5
        geometry.materials = [material]
        
        // Create physics body
        let physicsShape = SCNPhysicsShape(geometry: geometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: physicsShape)
        physicsBody.isAffectedByGravity = false
        physicsBody.categoryBitMask = CategoryBitMask.paper
        physicsBody.collisionBitMask = CategoryBitMask.all
        physicsBody.contactTestBitMask = CategoryBitMask.target
        
        // Create and return the node
        let node = SCNNode(geometry: geometry)
        node.physicsBody = physicsBody
        return node
    }
    
    private func createPanSurfaceNode() -> SCNNode {
        
        // Create plane geometry
        let geometry = SCNPlane()
        
        // Create and return the node
        let node = SCNNode(geometry: geometry)
        return node
    }
    
    private func getUserVectors() -> (direction: SCNVector3, position: SCNVector3) {
        
        if let frame = self.sceneView.session.currentFrame {
            
            let mat = SCNMatrix4(frame.camera.transform)                    // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)  // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43)                 // location of camera in world space
            
            return (dir, pos)
        }
        
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }
}
