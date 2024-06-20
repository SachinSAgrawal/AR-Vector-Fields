# Add Markers

## Instructions
1. Click on the `Assets` folder and then navigate to the `AR Resources` folder (under the app icon).
2. Drag and drop [ArUco markers](https://chev.me/arucogen/) (or really any other image) from Finder into the resource group.
3. For each image, use the attributes inspector located on the right of Xcode to describe the physical size of the image. 

## Note
According to Apple: 
> ARKit relies on this information (the physical size) to determine the distance of the image from the camera. Entering an incorrect physical size will result in an ARImageAnchor that’s the wrong distance from the camera.

## Warnings
Xcode may give warnings about any marker due to their nature, but detection still works fine in a well lit environment. <br>
The warnings may say the markers have narrow histograms, repetitive structures, or uniform contrast regions, but can be safely ignored. 
