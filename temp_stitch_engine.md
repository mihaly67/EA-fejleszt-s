# StitchEngine

This is open source code for Stitch's graph calculation logic. Here you will find code for handling the topological order of node calculation, including cycle detection, performance optimizations, and invocations of node evaluation.

## How to Update Binary Target

> **Make sure you follow the pre-reqs below!**

1. To create the binary, first access the root directory of this repo and call:
    ```sh
    ./build.sh
    ```
2. Drag the newly created `StitchEngine.xcframework` file into Stitch -> Project Workspace Settings -> Stitch Target -> "Frameworks, Libraries, and Embedded Content".


## Prerequisites

1. Install `swift-create-xcframework`, a package which abstracts away a complicated set of callers used to create the closed-source binary:
```sh
brew install segment-integrations/formulae/swift-create-xcframework
```
2. Enable permissions to run the build script:
```sh
chmod +x build.sh
```
