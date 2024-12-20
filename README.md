# Dicom2DTest
This is a simple example project for visionOS, aiming to explore the possibilities of displaying 2D image data from Dicom files using the Swift package [DcmSwift](https://github.com/LunarisTeam/DcmSwift)

> [!CAUTION]
> This project is not intended to be used in any medical production environment. It should be only used for R&D.

## Getting Started
### Requirements
- visionOS 2.0+
- Xcode 16+

### Getting Started
- Clone the repository using ```git clone https://github.com/LunarisTeam/Dicom2DTest```
- Create a directory named <strong>DataSet</strong> located at repository root and copy your Dicom dataset .dcm files inside of it
- Open Dicom2DTest.xcodeproj
- Manually add the DataSet folder to your build target

> [!IMPORTANT]
> Be sure to select the build target when adding files to the Xcode project, otherwise the app won't have the necessary resources inside its bundle

- Build the application
- Enjoy

## Contributors
- [Davide Castaldi](https://github.com/Dave-Ed-Cast): The whole project
- [Giuseppe Rocco](https://github.com/iOmega8561): Repository setup
