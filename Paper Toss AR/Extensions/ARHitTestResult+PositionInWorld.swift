//
//  ARHitTestResult+PositionInWorld.swift
//  Paper Toss AR
//
//  Created by Lasse Hammer Priebe on 21/09/2017.
//  Copyright © 2017 Hundredeni. All rights reserved.
//

import Foundation
import ARKit

extension ARHitTestResult {
    
    var positionInWorld: SCNVector3 {
        
        // Calculate the position of the tap in 3D space.
        let x = worldTransform.columns.3.x
        let y = worldTransform.columns.3.y
        let z = worldTransform.columns.3.z
        
        return SCNVector3Make(x, y, z)
    }
}
