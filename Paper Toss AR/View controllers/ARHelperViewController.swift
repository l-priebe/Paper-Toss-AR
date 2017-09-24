//
//  ARHelperViewController.swift
//  Paper Toss AR
//
//  Created by Lasse Hammer Priebe on 20/09/2017.
//  Copyright © 2017 Hundredeni. All rights reserved.
//

import UIKit

class ARHelperViewController: UIViewController {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var helperImageView: UIImageView!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    private var _continueButtonTitle: String?
    
    var blocking: Bool = false {
        didSet {
            continueButton.isEnabled = !blocking
            if blocking {
                activityIndicator.startAnimating()
                continueButton.setTitle(nil, for: .normal)
                
            } else {
                activityIndicator.stopAnimating()
                continueButton.setTitle(_continueButtonTitle, for: .normal)
            }
        }
    }
    
    var configurationBlock: ((_ controller: ARHelperViewController) -> Void)?
    var actionBlock: ((_ controller: ARHelperViewController, _ sender: Any) -> Void)?
    var completionBlock: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the subviews.
        let cornerRadius: CGFloat = 8
        containerView.layer.cornerRadius = cornerRadius
        continueButton.layer.cornerRadius = cornerRadius
        
        // Run configuration block.
        configurationBlock?(self)
    }
    
    @IBAction func continueButtonTouchUpInside(_ sender: Any) {
        dismiss(animated: true) {
            self.completionBlock?()
        }
    }
    
    @IBAction func actionButtonTouchUpInside(_ sender: Any) {
        actionBlock?(self, sender)
    }
}

// MARK: - Scene selection

extension ARHelperViewController {
    
    func configureForSceneSelection() {
        titleLabel.text = "Prepare for augmented reality"
        descriptionLabel.text = "Move to an open space and point the camera at the desired scene"
        helperImageView.image = #imageLiteral(resourceName: "config_scene_selection")
        _continueButtonTitle = "I'm ready"
        continueButton.setTitle(_continueButtonTitle, for: .normal)
        blocking = false
    }
}

// MARK - Plane detection

extension ARHelperViewController {
    
    func configureForPlaneDetection() {
        titleLabel.text = "Detecting ground plane"
        descriptionLabel.text = "Move the camera slowly around the scene to aid the process"
        helperImageView.image = #imageLiteral(resourceName: "config_plane_detection")
        _continueButtonTitle = "Continue"
        continueButton.setTitle(_continueButtonTitle, for: .normal)
        blocking = true
    }
}
