//
//  PlaneNode.swift
//  Paper Toss AR
//
//  Created by Lasse Hammer Priebe on 20/09/2017.
//  Copyright © 2017 Hundredeni. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

class PlaneNode: SCNNode {
    
    var anchor: ARPlaneAnchor
    
    // MARK: - Init
    
    init(anchor: ARPlaneAnchor) {
        self.anchor = anchor
        super.init()
        setupPlaneGeometry()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Update
    
    func update(anchor: ARPlaneAnchor) {
        
        // Update the plane geometry and node position.
        if let geometry = planeGeometry {
            geometry.width = CGFloat(anchor.extent.x)
            geometry.height = CGFloat(anchor.extent.z)
            let physicsShape = SCNPhysicsShape(geometry: geometry, options: nil)
            let physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
            physicsBody.categoryBitMask = CategoryBitMask.floor
            planeNode?.physicsBody = physicsBody
        }
        planeNode?.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
    }
    
    // MARK: - Private
    
    private var planeNode: SCNNode?
    
    private var planeGeometry: SCNPlane? {
        return planeNode?.geometry as? SCNPlane
    }
    
    private func setupPlaneGeometry() {
        
        // Create a grid texture for the plane.
        let planeMaterial = SCNMaterial()
        let planeColor = #colorLiteral(red: 1, green: 0.7738900781, blue: 0.1969780922, alpha: 1)
        planeMaterial.diffuse.contents = planeColor.withAlphaComponent(0.5)
        
        // Create the geometry based on the extent of the anchor.
        let planeWidth = CGFloat(anchor.extent.x)
        let planeHeight = CGFloat(anchor.extent.z)
        let planeGeometry = SCNPlane(width: planeWidth, height: planeHeight)
        planeGeometry.materials = [planeMaterial]
        
        // Create a child node for the plane.
        let planeNode = SCNNode(geometry: planeGeometry)
        planeNode.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z)
        let physicsShape = SCNPhysicsShape(geometry: planeGeometry, options: nil)
        let physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        physicsBody.categoryBitMask = CategoryBitMask.floor
        planeNode.physicsBody = physicsBody
        
        // Rotate the plane from vertical to horizontal.
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
        
        // Add the plane node as a child.
        self.planeNode = planeNode
        addChildNode(planeNode)
    }
}
