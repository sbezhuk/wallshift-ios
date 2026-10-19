//
//  GameViewController.swift
//  wallshift
//
//  Created by Stepan Bezhuk on 19.10.2026.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func loadView() {
        let skView = SKView()
        skView.backgroundColor = .black
        self.view = skView
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let skView = self.view as? SKView, skView.scene == nil, skView.bounds.size.width > 0 {
            let scene = GameScene(size: skView.bounds.size)
            scene.scaleMode = .resizeFill
            
            skView.presentScene(scene)
            skView.ignoresSiblingOrder = true
            skView.showsFPS = true
            skView.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
