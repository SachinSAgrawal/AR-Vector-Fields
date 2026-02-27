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

    // Helper to refresh only the vector arrows
    func refreshVectorField() {
        textFieldChanged(self)
    }
    
    // MARK: Popups
    
    // Single function to show a popup with a custom message
    func showPopup(_ message: String, title: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
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

        // Remove existing arrows only and preserve grid
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "arrow" {
                node.removeFromParentNode()
            }
        }
        
        // Create arrows based on the new vector field function
        createVectorField()
    }
    
    // MARK: Slider Actions
    
    // Update the label in real time as the thickness slider changes
    @IBAction func thicknessSliderChanged(_ sender: UISlider) {
        arrowThickness = CGFloat(sender.value)
        thicknessLabel?.text = String(format: "Thickness: %.3f", sender.value)
    }

    // Update the label in real time as the length slider changes
    @IBAction func lengthSliderChanged(_ sender: UISlider) {
        arrowLengthScale = CGFloat(sender.value)
        lengthLabel?.text = String(format: "Length: %.3f", sender.value)
    }

    // Programmatic handler regardless of IB wiring
    @objc func sliderValueChanged(_ sender: UISlider) {
        if sender === thicknessSlider {
            arrowThickness = CGFloat(sender.value)
            thicknessLabel?.text = String(format: "Thickness: %.3f", sender.value)
        } else if sender === lengthSlider {
            arrowLengthScale = CGFloat(sender.value)
            lengthLabel?.text = String(format: "Length: %.3f", sender.value)
        }
    }

    // Apply the final value and refresh when user has finished interacting with slider
    @objc func sliderTouchEnded(_ sender: UISlider) {
        if sender === thicknessSlider {
            arrowThickness = CGFloat(sender.value)
            thicknessLabel?.text = String(format: "Thickness: %.3f", sender.value)
        } else if sender === lengthSlider {
            arrowLengthScale = CGFloat(sender.value)
            lengthLabel?.text = String(format: "Length: %.3f", sender.value)
        }

        refreshVectorField()
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
        guard let vectorField = textField.text else {
            return
        }
        
        let trigFunctions = ["tan", "csc", "sec", "cot", "tangent", "cosecant", "secant", "cotangent"]

        // Check if any trigFunctions exist in the vectorField string
        let hasKeyword = trigFunctions.contains {
            keyword in vectorField.contains(keyword)
        }
        
        // If so then do not continue and show a popup warning
        guard !hasKeyword else {
            showPopup("Trigonometric functions besides sin and cos are not allowed.", title: "Invalid")
            return
        }
        
        // Split the vector field input into its components
        let components = vectorField.split(separator: ",")
        
        // Check if there are exactly 3 components
        guard components.count == 3 else {
            // Display an invalid vector field popup if the number of components is not 3
            showPopup("The vector field must have 3 components separated by commas.", title: "Invalid")
            return
        }
        
        // Check if the number of open parentheses matches the number of closed ones in the first and third components
        let firstComponent = components[0]
        let thirdComponent = components[2]

        let firstOpenParenthesesCount = firstComponent.filter { $0 == "(" }.count
        let firstClosedParenthesesCount = firstComponent.filter { $0 == ")" }.count

        let thirdOpenParenthesesCount = thirdComponent.filter { $0 == "(" }.count
        let thirdClosedParenthesesCount = thirdComponent.filter { $0 == ")" }.count

        guard firstOpenParenthesesCount == firstClosedParenthesesCount,
              thirdOpenParenthesesCount == thirdClosedParenthesesCount else {
            // Display an invalid vector field popup if the parentheses are not properly placed
            showPopup("Please do not put parentheses surrounding the vector field.", title: "Invalid")
            return
        }
        
        // Function representing the vector field
        func vectorFieldFunction(x: Float, y: Float, z: Float) -> SCNVector3 {
            // Evaluate each component of the vector field at a given point (x, y, z)
            let component1 = evaluateComponent(String(components[0]), x: x, y: y, z: z)
            let component2 = evaluateComponent(String(components[1]), x: x, y: y, z: z)
            let component3 = evaluateComponent(String(components[2]), x: x, y: y, z: z)
            
            // Create a SCNVector3 representing the components of the vector field at the given point
            let vectorComps = SCNVector3(component1, component2, component3)
            return vectorComps
        }
        
        // Define a function to compute the Taylor series expansion of sin(x) up to ten terms
        func taylorSeriesSin(_ argString: String) -> String {
            return "\(argString) - (\(argString)^3 / 6) + (\(argString)^5 / 120) - (\(argString)^7 / 5040) + (\(argString)^9 / 362880) - (\(argString)^11 / 39916800) + (\(argString)^13 / 6227020800) - (\(argString)^15 / 1307674368000) + (\(argString)^17 / 17) - (\(argString)^19 / 121645100408832000)"
        }

        // Define a function to compute the Taylor series expansion of cos(x) up to ten terms
        func taylorSeriesCos(_ argString: String) -> String {
            return "1 - (\(argString)^2 / 2) + (\(argString)^4 / 24) - (\(argString)^6 / 720) + (\(argString)^8 / 40320) - (\(argString)^10 / 362880) + (\(argString)^12 / 47900160) - (\(argString)^14 / 87178291200) + (\(argString)^16 / 20922789888000) - (\(argString)^18 / 6402373705728000) + (\(argString)^20 / 2432902008176640000)"
        }

        // Function to evaluate a component expression at a given point
        func evaluateComponent(_ expression: String, x: Float, y: Float, z: Float) -> Float {
            // Define regular expression patterns to match sin and cos function calls
            let sinPattern = "(?<!co)(?i)sin(?:e)?\\(((?:[\\w\\d.+-]*[*/^])*[\\w\\d.+-]*)\\)"
            let cosPattern = "(?i)cos(?:ine)?\\(((?:[\\w\\d.+-]*[*/^])*[\\w\\d.+-]*)\\)"
            
            // Create regular expressions using the patterns
            let sinRegex = try! NSRegularExpression(pattern: sinPattern, options: [])
            let cosRegex = try! NSRegularExpression(pattern: cosPattern, options: [])
            
            // Replace occurrences of sin function calls with their Taylor series expansions
            var replacedExpression = expression
            let sinMatches = sinRegex.matches(in: expression, options: [], range: NSRange(location: 0, length: expression.utf16.count))
            for match in sinMatches.reversed() {
                let argumentRange = Range(match.range(at: 1), in: expression)!
                let argument = String(expression[argumentRange])
                let taylorValue = taylorSeriesSin(argument)
                replacedExpression = replacedExpression.replacingCharacters(in: Range(match.range, in: expression)!, with: "\(taylorValue)")
            }
            
            // Replace occurrences of cos function calls with their Taylor series expansions
            let cosMatches = cosRegex.matches(in: expression, options: [], range: NSRange(location: 0, length: expression.utf16.count))
            for match in cosMatches.reversed() {
                let argumentRange = Range(match.range(at: 1), in: expression)!
                let argument = String(expression[argumentRange])
                let taylorValue = taylorSeriesCos(argument)
                replacedExpression = replacedExpression.replacingCharacters(in: Range(match.range, in: expression)!, with: "\(taylorValue)")
            }
            
            // Replace 'x', 'y', and 'z' placeholders with their corresponding values in the expression
            replacedExpression = replacedExpression
                .replacingOccurrences(of: "x", with: "\(x)", options: .caseInsensitive)
                .replacingOccurrences(of: "y", with: "\(y)", options: .caseInsensitive)
                .replacingOccurrences(of: "z", with: "\(z)", options: .caseInsensitive)
            
            // Evaluate the modified expression and retrieve the numeric value
            if let value = NSExpression(format: replacedExpression).expressionValue(with: nil, context: nil) as? NSNumber {
                return value.floatValue
            }
            
            // Return 0 if evaluation fails
            return 0.0
        }
        
        // Define the parameters of the vector field
        let gridSize = 4
        
        // MARK: Iterations
        
        // Create arrows for each point in the vector field
        for x in -gridSize...gridSize {
            for y in -gridSize...gridSize {
                for z in -gridSize...gridSize {
                    // Define the position vector at the current point in the vector field grid
                    let position = SCNVector3(Float(x), Float(y), Float(z))
                    
                    // Calculate the vector at the current point in the vector field grid
                    let vectorAtPoint = vectorFieldFunction(x: Float(x), y: Float(y), z: Float(z))
                    
                    // Calculate the resultant vector by adding the position vector to the vector at the current point
                    let resultantVector = SCNVector3(position.x + vectorAtPoint.x, position.y + vectorAtPoint.y, position.z + vectorAtPoint.z)

                    // Calculate the magnitude of the vector at the current point
                    let magnitude = sqrt(pow(vectorAtPoint.x, 2) + pow(vectorAtPoint.y, 2) + pow(vectorAtPoint.z, 2))
                    
                    // Calculate the length of the cylinder representing the arrow proportional to the magnitude
                    let cylinderLength = arrowLengthScale * CGFloat(magnitude)
                    
                    // Create a cylinder representing the shaft of the arrow
                    let cylinder = SCNCylinder(radius: arrowThickness, height: cylinderLength)
                    let cylinderNode = SCNNode(geometry: cylinder)
                    
                    // Create a cone representing the head of the arrow scaled relative to thickness/length
                    let coneHeight = max(0.02, cylinderLength * 0.5)
                    let coneBottomRadius = max(arrowThickness * 1.5, arrowThickness * 2.5)
                    let cone = SCNCone(topRadius: 0, bottomRadius: coneBottomRadius, height: coneHeight)
                    let coneNode = SCNNode(geometry: cone)
                    coneNode.position = SCNVector3(0, Float(cylinderLength / 2.0) + Float(coneHeight / 2.0), 0)
                    
                    // Group the cylinder and cone to form the arrow
                    let arrowNode = SCNNode()
                    arrowNode.name = "arrow"
                    arrowNode.addChildNode(cylinderNode)
                    arrowNode.addChildNode(coneNode)
                    
                    // Set the position of the arrow node to the current point in the vector field grid
                    arrowNode.position = SCNVector3(Float(x) / 2, Float(y) / 2, Float(z) / 2)
                    
                    // Orient the arrow node to look towards the direction of the resultant vector
                    arrowNode.look(at: resultantVector, up: SCNVector3(0,1,0), localFront: SCNVector3(0,1,0))
                    
                    // Add the arrow to the scene if its magnitude is not zero
                    if magnitude != 0 {
                        sceneView.scene.rootNode.addChildNode(arrowNode)
                    }
                }
            }
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
