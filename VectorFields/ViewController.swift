//
//  ViewController.swift
//  VectorFields
//
//  Created by Sachin Agrawal on 5/1/24.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var textField: UITextField!
    @IBOutlet weak var thicknessSlider: UISlider!
    @IBOutlet weak var lengthSlider: UISlider!
    @IBOutlet weak var thicknessLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!

    var arrowThickness: CGFloat = 0.01
    var arrowLengthScale: CGFloat = 0.1

    private var textFieldBackgroundView: UIVisualEffectView?
    private var suppressTextFieldChangeHandling: Bool = false

    // Share one unit sized geometry between every arrow and scale each node to size
    private let arrowShaftGeometry = SCNCylinder(radius: 1, height: 1)
    private let arrowHeadGeometry = SCNCone(topRadius: 0, bottomRadius: 1, height: 1)

    // Hold the parts of an arrow the sliders resize so dragging never rebuilds the scene
    private struct Arrow {
        let shaftNode: SCNNode
        let headNode: SCNNode
        let magnitude: Float
    }

    private var arrows: [Arrow] = []
    private var appliedThickness: CGFloat = -1
    private var appliedLengthScale: CGFloat = -1

    // MARK: View Loaded
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Show world origin for debugging
//        sceneView.debugOptions = [.showWorldOrigin]
        
        // Enable default lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Setup the text field
        textField.becomeFirstResponder()
        textField.delegate = self
        textField.layer.cornerRadius = 8.0
        textField.layer.masksToBounds = true
        textField.textColor = .white
        textField.tintColor = .white
        
        // Ensure the Done key is always enabled
        textField.returnKeyType = .done
        textField.enablesReturnKeyAutomatically = false
        
        // Set placeholder color to be visible on the glass
        if let placeholder = textField.placeholder, !placeholder.isEmpty {
            textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(white: 1.0, alpha: 0.7)])
        }

        // Initialize sliders and set to fire continuously
        thicknessSlider?.minimumValue = 0.001
        thicknessSlider?.maximumValue = 0.05
        thicknessSlider?.value = Float(arrowThickness)
        thicknessSlider?.isContinuous = true

        lengthSlider?.minimumValue = 0.02
        lengthSlider?.maximumValue = 0.5
        lengthSlider?.value = Float(arrowLengthScale)
        lengthSlider?.isContinuous = true

        // Configure all labels to avoid truncation
        let allLabels: [UILabel?] = [thicknessLabel, lengthLabel]
        for lbl in allLabels {
            lbl?.adjustsFontForContentSizeCategory = true
            lbl?.adjustsFontSizeToFitWidth = true
            lbl?.minimumScaleFactor = 0.6
            lbl?.numberOfLines = 0
            lbl?.lineBreakMode = .byWordWrapping

            // Ensure label text is white with a dark shadow
            lbl?.textColor = .white
            lbl?.layer.shadowColor = UIColor.black.cgColor
            lbl?.layer.shadowOpacity = 1.0
            lbl?.layer.shadowOffset = CGSize(width: 1, height: 1)
            lbl?.layer.shadowRadius = 1.0
            lbl?.layer.masksToBounds = false
        }

        // Initialize label text with keys and numbers
        thicknessLabel?.text = String(format: "Thickness: %.3f", arrowThickness)
        lengthLabel?.text = String(format: "Length: %.3f", arrowLengthScale)

        // Wire up programmatic targets so behavior doesn't strictly depend on storyboard connections
        thicknessSlider?.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        thicknessSlider?.addTarget(self, action: #selector(sliderTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        lengthSlider?.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        lengthSlider?.addTarget(self, action: #selector(sliderTouchEnded(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        // Show initial popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.viewLoadedInitialPopup()
        }
        
        // Render the grid and add it to the scene
        let gridNode = renderGrid()
        sceneView.scene.rootNode.addChildNode(gridNode)
    }
    
    override func viewDidLayoutSubviews() {
         super.viewDidLayoutSubviews()
         configureTextFieldBackgroundIfNeeded()
     }
 
    // Have text field adopt Liquid Glass
    private func configureTextFieldBackgroundIfNeeded() {
        guard textFieldBackgroundView == nil, let parent = textField.superview else { return }

        let glass = UIGlassEffect(style: .regular)
        glass.tintColor = UIColor(white: 1.0, alpha: 0.04)
        glass.isInteractive = false

        let glassView = UIVisualEffectView(effect: glass)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        parent.insertSubview(glassView, belowSubview: textField)

        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: textField.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: textField.bottomAnchor)
        ])

        // Round the corners of the text field
        glassView.layer.cornerRadius = textField.layer.cornerRadius
        glassView.layer.masksToBounds = true

        textField.backgroundColor = .clear
        textFieldBackgroundView = glassView
    }

    // Resize every arrow in place using its scale transform
    private func applyArrowDimensions(force: Bool = false) {
        // Ignore the duplicate event that arrives from wiring each slider up twice
        guard force || arrowThickness != appliedThickness || arrowLengthScale != appliedLengthScale else { return }

        appliedThickness = arrowThickness
        appliedLengthScale = arrowLengthScale

        // Size the head from the thickness alone so it does not grow with the shaft
        let headHeight = arrowThickness * 5.0
        let headRadius = arrowThickness * 2.5

        for arrow in arrows {
            // Only the shaft is proportional to the magnitude of the vector
            let shaftLength = arrowLengthScale * CGFloat(arrow.magnitude)

            arrow.shaftNode.scale = SCNVector3(Float(arrowThickness), Float(shaftLength), Float(arrowThickness))
            arrow.headNode.scale = SCNVector3(Float(headRadius), Float(headHeight), Float(headRadius))
            arrow.headNode.position = SCNVector3(0, Float(shaftLength / 2.0) + Float(headHeight / 2.0), 0)
        }
    }
    
    // MARK: Popups
    
    // Single function to show a popup with a custom message
    func showPopup(_ message: String, title: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        // Replace an alert that is already up since presenting on top of one does nothing
        if let existing = presentedViewController {
            existing.dismiss(animated: false) { [weak self] in
                self?.present(alertController, animated: true, completion: nil)
            }
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    // Function to display the initial popup when the view loads
    func viewLoadedInitialPopup() {
        showPopup("Please enter a vector field into the text box to get started.", title: "Welcome")
    }
    
    // Action method triggered when the text field's content changes
    @IBAction func textFieldChanged(_ sender: Any) {
        // If suppression flag is set, clear it and ignore this change
        if suppressTextFieldChangeHandling {
            suppressTextFieldChangeHandling = false
            return
        }

        rebuildVectorField()
    }

    // Clear the existing arrows and graph whatever the text field currently holds
    private func rebuildVectorField() {
        // Remove existing arrows only and preserve grid
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "arrow" {
                node.removeFromParentNode()
            }
        }

        arrows.removeAll()

        // Create arrows based on the new vector field function
        createVectorField()
    }
    
    // MARK: Slider Actions
    
    // Update the label in real time as the thickness slider changes
    @IBAction func thicknessSliderChanged(_ sender: UISlider) {
        arrowThickness = CGFloat(sender.value)
        thicknessLabel?.text = String(format: "Thickness: %.3f", sender.value)
        applyArrowDimensions()
    }

    // Update the label in real time as the length slider changes
    @IBAction func lengthSliderChanged(_ sender: UISlider) {
        arrowLengthScale = CGFloat(sender.value)
        lengthLabel?.text = String(format: "Length: %.3f", sender.value)
        applyArrowDimensions()
    }

    // Resize the arrows as the value moves regardless of the storyboard wiring
    @objc func sliderValueChanged(_ sender: UISlider) {
        if sender === thicknessSlider {
            arrowThickness = CGFloat(sender.value)
            thicknessLabel?.text = String(format: "Thickness: %.3f", sender.value)
        } else if sender === lengthSlider {
            arrowLengthScale = CGFloat(sender.value)
            lengthLabel?.text = String(format: "Length: %.3f", sender.value)
        }

        applyArrowDimensions()
    }

    // Apply the final value once the user lifts off in case the last event was missed
    @objc func sliderTouchEnded(_ sender: UISlider) {
        if sender === thicknessSlider {
            arrowThickness = CGFloat(sender.value)
            thicknessLabel?.text = String(format: "Thickness: %.3f", sender.value)
        } else if sender === lengthSlider {
            arrowLengthScale = CGFloat(sender.value)
            lengthLabel?.text = String(format: "Length: %.3f", sender.value)
        }

        applyArrowDimensions()
    }
    
    // MARK: Render Grid
    
    // Function that renders a grid with defined axes
    func renderGrid() -> SCNNode {
        // Constants to define the grid
        let gridSpacing: CGFloat = 0.5

        let width = CGFloat(4)
        let height = CGFloat(4)
        
        // Initiate the grid node
        let gridNode = SCNNode()
        gridNode.position = SCNVector3(-width/2, 0, -height/2)
        gridNode.name = "grid"

        // Calculate the number of lines required
        let linesX = Int(width / gridSpacing)
        let linesZ = Int(height / gridSpacing)

        // Create lines in X direction
        for i in 0...linesX {
            let lineNode = createLineNode(length: height, thickness: 0.003, color: UIColor.gray)
            // Round positionX to the nearest meter
            let positionX = round(gridSpacing * CGFloat(i) / gridSpacing) * gridSpacing
            lineNode.position = SCNVector3(positionX, 0, height / 2)
            gridNode.addChildNode(lineNode)
        }

        // Create lines in Z direction
        for j in 0...linesZ {
            let lineNode = createLineNode(length: width, thickness: 0.003, color: UIColor.gray)
            // Round positionZ to the nearest meter
            let positionZ = round(gridSpacing * CGFloat(j) / gridSpacing) * gridSpacing
            lineNode.position = SCNVector3(width / 2, 0, positionZ)
            lineNode.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
            gridNode.addChildNode(lineNode)
        }
        
        // Create main x axis
        let xNode = createLineNode(length: width, thickness: 0.008, color: UIColor.red)
        xNode.position = SCNVector3(width/2, 0, height/2)
        gridNode.addChildNode(xNode)
        
        // Create main y axis
        let yNode = createLineNode(length: width, thickness: 0.008, color: UIColor.green)
        yNode.eulerAngles = SCNVector3(0, CGFloat.pi / 2, 0)
        yNode.position = SCNVector3(width/2, 0, height/2)
        gridNode.addChildNode(yNode)
        
        // Create main z axis
        let zNode = createLineNode(length: width, thickness: 0.008, color: UIColor.blue)
        zNode.eulerAngles = SCNVector3(0, 0, CGFloat.pi / 2)
        zNode.position = SCNVector3(width/2, 0, height/2)
        gridNode.addChildNode(zNode)
        
        return gridNode
    }
    
    // Create the line itself based on parameters passed in
    func createLineNode(length: CGFloat, thickness: CGFloat, color: UIColor) -> SCNNode {
        let line = SCNCylinder(radius: thickness, height: length)
        line.firstMaterial?.diffuse.contents = color

        let lineNode = SCNNode(geometry: line)
        lineNode.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)

        return lineNode
    }
    
    // MARK: Vector Field
    
    // Function to create the vector field based on the user input
    func createVectorField() {
        // Check if there is a valid vector field input
        guard let vectorField = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !vectorField.isEmpty else {
            return
        }

        // Split the input into its three components and repair what can be repaired
        let parsed: ExpressionSyntax.Components
        do {
            parsed = try ExpressionSyntax.components(of: vectorField)
        } catch {
            showPopup(error.localizedDescription, title: "Invalid")
            return
        }

        // Parse each component once up front instead of again at every grid point
        var compiled: [CompiledExpression] = []
        for (index, expression) in parsed.expressions.enumerated() {
            do {
                compiled.append(try ExpressionParser.compile(expression))
            } catch {
                let description = error.localizedDescription
                showPopup("Component \(index + 1), \"\(expression)\", could not be read. \(description)", title: "Invalid")
                return
            }
        }

        // Function representing the vector field or nil where the field is undefined
        func vectorFieldFunction(x: Float, y: Float, z: Float) -> SCNVector3? {
            // Evaluate each component of the vector field at the given point
            let values = compiled.compactMap { $0.value(x: Double(x), y: Double(y), z: Double(z)) }
            guard values.count == compiled.count else { return nil }

            // Narrowing to Float can overflow to infinity even when the Double was finite
            let components = values.map { Float($0) }
            guard components.allSatisfy({ $0.isFinite }) else { return nil }

            // Create a SCNVector3 representing the components of the vector field at the given point
            return SCNVector3(components[0], components[1], components[2])
        }

        // Define the parameters of the vector field
        let gridSize = 4

        // MARK: Iterations

        // Create arrows for each point in the vector field
        for x in -gridSize...gridSize {
            for y in -gridSize...gridSize {
                for z in -gridSize...gridSize {
                    // Calculate the vector at the current point in the vector field grid
                    guard let vectorAtPoint = vectorFieldFunction(x: Float(x), y: Float(y), z: Float(z)) else {
                        // Skip this point because the field is undefined here
                        continue
                    }

                    // Calculate the magnitude of the vector at the current point
                    let magnitude = sqrt(pow(vectorAtPoint.x, 2) + pow(vectorAtPoint.y, 2) + pow(vectorAtPoint.z, 2))

                    // Skip a zero vector since it has no direction to point in
                    guard magnitude > 0 else { continue }

                    // Define the position of the arrow in the scene
                    let position = SCNVector3(Float(x) / 2, Float(y) / 2, Float(z) / 2)

                    // Calculate the resultant vector by adding the position vector to the vector at the current point
                    let resultantVector = SCNVector3(position.x + vectorAtPoint.x, position.y + vectorAtPoint.y, position.z + vectorAtPoint.z)

                    // Create the shaft and the head from the shared unit geometry
                    let cylinderNode = SCNNode(geometry: arrowShaftGeometry)
                    let coneNode = SCNNode(geometry: arrowHeadGeometry)

                    // Group the cylinder and cone to form the arrow
                    let arrowNode = SCNNode()
                    arrowNode.name = "arrow"
                    arrowNode.addChildNode(cylinderNode)
                    arrowNode.addChildNode(coneNode)

                    // Set the position of the arrow node to the current point in the vector field grid
                    arrowNode.position = position

                    // Orient the arrow node to look towards the direction of the resultant vector
                    arrowNode.look(at: resultantVector, up: SCNVector3(0,1,0), localFront: SCNVector3(0,1,0))

                    // Add the arrow to the scene
                    sceneView.scene.rootNode.addChildNode(arrowNode)
                    arrows.append(Arrow(shaftNode: cylinderNode, headNode: coneNode, magnitude: magnitude))
                }
            }
        }

        // Give every arrow its size now that the whole field has been built
        applyArrowDimensions(force: true)

        // Let the user know if the field read fine but had nothing to show
        if arrows.isEmpty {
            showPopup("That field is zero or undefined at every point on the grid, so there is nothing to draw.", title: "Notice")
            return
        }

        // Otherwise mention anything that was quietly corrected in the input
        if !parsed.notes.isEmpty {
            showPopup(parsed.notes.joined(separator: " "), title: "Notice")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
                
        // Enable people occlusion in the AR configuration
        configuration.frameSemantics.insert(.personSegmentationWithDepth)
        
        // Allow for detection of a marker
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 1

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: View Delegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
    
        // Move the world origin to center of image
        DispatchQueue.main.async {
            self.sceneView.session.setWorldOrigin(relativeTransform: imageAnchor.transform)
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
}

// MARK: Extension

// Dismisses the keyboard when the return key is pressed
extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
         // Show a popup if the user hasn't inputted anything
         let trimmed = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
         if trimmed.isEmpty {
             // Remove any currently displayed vector arrows
             sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
                 if node.name == "arrow" {
                     node.removeFromParentNode()
                 }
             }
             
             // Dismiss keyboard so the popup doesn't leave it shown or cause it to reappear
             suppressTextFieldChangeHandling = true
             textField.resignFirstResponder()
             showPopup("No vector field has been inputted. Please try again.", title: "Notice")
             return true
         }

        // Otherwise dismiss the keyboard and proceed
        textField.resignFirstResponder()

        // Print the text content of the text field
        print("\(trimmed)")
        return true
    }
}
