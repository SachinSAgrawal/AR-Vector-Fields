# Vector Fields

## About
Simply enter a vector field to view it in Augmented Reality. I created this app for the final project of my Multivariable Calculus class since I had been working with AR for a project completely unrelated to school where some of the basic parts like the arrows themselves could be reused, and I figured something like this could be fun. 

## Acknowledgments
This is heavily based on this [cool Desmos 3D graph](https://www.desmos.com/3d/lwagvtqhn3) by Elliot Wymore that allows you input each component of a vector field and see it graphed. That was largely my reference for this project.

## Usage
When the app is launched, there will be a popup asking you to input a vector field. Enter one in the text box in the top center of the app. As long as it is valid, it will be graphed. You should receive a warning popup if that is not the case. Please enter the vector field as one string, with each of the three components separated by commas, and no parentheses. Each component can be a function of `x`, `y`, `z`, or even constant. You can input almost anything, including square roots, absolute values, powers, and logarithms, but you might need to type them in as pseudo-Swift so it can be parsed properly.

## Challenges
* Orienting the vector correctly: solved using the `look(at:up:localFront:)`, where `up` and `localFront` are both the **j** vector, instead of using the `atan2` function, which was my inital method.
* Passing in custom values to the vector field: solved using `NSExpression` to evaluate each component, where the variables are replaced with their actual values using `replacingOccurrences(of:with:)`.

## Installation
1. Clone this repository or download it as a zip folder and uncompress it.
2. Open up the `.xcodeproj` file, which should automatically launch Xcode.
3. You might need to change the signing of the app from the current one.
4. Click the `Run` button near the top left of Xcode to build and install.

#### Prerequisites
Hopefully this goes without saying, but you need Xcode, which is only available on Macs.

#### Notes
You can run this app on the Xcode simulator or connect a physical device. <br>
The device must be either an iPhone or iPad running iOS 17.0 or newer. <br>
If using a simulator, you can only view the vector field along the `x`-axis.

## SDKs
* [ARKit](https://developer.apple.com/documentation/arkit/) - Integrate hardware sensing features to produce augmented reality apps and games.
* [SceneKit](https://developer.apple.com/documentation/scenekit/) - Create 3D games and add 3D content to apps using high-level scene descriptions.
* [UIKit](https://developer.apple.com/documentation/uikit/) - Construct and manage a graphical, event-driven user interface for your iOS, iPadOS, or tvOS app.
* [Swift](https://developer.apple.com/swift/) - A powerful and intuitive programming language for all Apple platforms.

## Bugs
I have not tested this app super rigorously, so I would not be surpised if there were more than the known ones. If you find any, feel free to open up a new issue or even better, create a pull request fixing it.

#### Known
- [ ] Trigonometric functions are not supported becuase they are forbidden from `NSExpression`

## Author
I'm a self-taught programmer who knows many languages and I'm into app, game, and web development. If you would like to contact me, my email is [github@sachin.email](mailto:github@sachin.email).

## License
This package is licensed under the [MIT License](LICENSE.txt).
