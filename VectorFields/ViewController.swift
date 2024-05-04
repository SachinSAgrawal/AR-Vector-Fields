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
        
        // Show initial popup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.viewLoadedInitialPopup()
        }
    }
    
    // MARK: Popups
    
    // Function to display the initial popup when the view loads
    func viewLoadedInitialPopup() {
        let alertController = UIAlertController(title: "Welcome", message: "Please enter a vector field into the text box to get started.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // Function to display an invalid vector field popup
    func invalidVectorFieldPopup() {
        let alertController = UIAlertController(title: "Invalid", message: "The vector field must have 3 components separated by commas.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // Function to display popup if vector field has trigonometric functions
    func vectorFieldWithTrigPopup() {
        let alertController = UIAlertController(title: "Invalid", message: "Trigonometric functions besides sin and cos are not allowed.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // Function to display popup if vector field has parentheses surrounding it
    func vectorFieldWithParenPopup() {
        let alertController = UIAlertController(title: "Invalid", message: "Please do not put parentheses surrounding the vector field.", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    // Action method triggered when the text field's content changes
    @IBAction func textFieldChanged(_ sender: Any) {
        // Remove existing arrows
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
        
        // Render the grid and add it to the scene
        let gridNode = renderGrid()
        sceneView.scene.rootNode.addChildNode(gridNode)
        
        // Create arrows based on the new vector field function
        createVectorField()
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
            vectorFieldWithTrigPopup()
            return
        }
        
        // Split the vector field input into its components
        let components = vectorField.split(separator: ",")
        
        // Check if there are exactly 3 components
        guard components.count == 3 else {
            // Display an invalid vector field popup if the number of components is not 3
            invalidVectorFieldPopup()
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
            vectorFieldWithParenPopup()
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
            return "\(argString) - (\(argString)^3 / 3) + (\(argString)^5 / 5) - (\(argString)^7 / 7) + (\(argString)^9 / 9) - (\(argString)^11 / 11) + (\(argString)^13 / 13) - (\(argString)^15 / 15) + (\(argString)^17 / 17) - (\(argString)^19 / 19)"
        }

        // Define a function to compute the Taylor series expansion of cos(x) up to ten terms
        func taylorSeriesCos(_ argString: String) -> String {
            return "1 - (\(argString)^2 / 2) + (\(argString)^4 / 24) - (\(argString)^6 / 720) + (\(argString)^8 / 40320) - (\(argString)^10 / 362880) + (\(argString)^12 / 47900160) - (\(argString)^14 / 87178291200) + (\(argString)^16 / 20922789888000) - (\(argString)^18 / 6402373705728000) + (\(argString)^20 / 2432902008176640000)"
        }

        // Function to evaluate a component expression at a given point
        func evaluateComponent(_ expression: String, x: Float, y: Float, z: Float) -> Float {
            // Define regular expression patterns to match sin and cos function calls
            let sinPattern = "(?<!co)(?i)sin(?:e)?\\(([\\w\\d.+-]*)\\)"
            let cosPattern = "(?i)cos(?:ine)?\\(([\\w\\d.+-]*)\\)"
            
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
                    let cylinderLength = 0.1 * CGFloat(magnitude)
                    
                    // Create a cylinder representing the shaft of the arrow
                    let cylinder = SCNCylinder(radius: 0.01, height: cylinderLength)
                    let cylinderNode = SCNNode(geometry: cylinder)
                    
                    // Create a cone representing the head of the arrow
                    let cone = SCNCone(topRadius: 0, bottomRadius: 0.025, height: 0.05)
                    let coneNode = SCNNode(geometry: cone)
                    coneNode.position = SCNVector3(0, cylinderLength / 2, 0)
                    
                    // Group the cylinder and cone to form the arrow
                    let arrowNode = SCNNode()
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

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: View Delegate
    
    /*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
    */
    
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
        textField.resignFirstResponder()

        // Print the text content of the text field
        if let text = textField.text {
            print("\(text)")
        }
        
        return true
    }
}
