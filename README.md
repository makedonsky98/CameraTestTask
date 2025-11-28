# Camera Test

![Version](https://img.shields.io/badge/version-1.0-blue.svg) ![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B.svg)

A robust Flutter camera application designed for testing photo and video capture capabilities, featuring image overlays, gallery management, and smooth animations.

## Features

### Permissions Management
* **Automatic Checks:** Checks and requests necessary permissions immediately upon app launch.
* **Denied State Handling:** If permissions are permanently denied, the app provides a direct link to the system settings.
* **Status Display:** displays a list of ungranted permissions for transparency.

### Camera Interface & Controls
* **Loading State:** Visual indication while the camera is initializing.
* **Bottom Control Panel:**
    * Shutter button for photos.
    * Camera toggle (Front/Back) with transition animations.
    * Video controls: Start, Stop, Pause, and Resume.
    * Video recording timer.
    * Thumbnail of the last captured media with a shortcut to the gallery.
* **Animations:**
    * Shutter animation when taking a photo.
    * Smooth transition animation when switching between cameras.

### Overlay System
* **Reference Image:** Ability to load and remove an overlay image on the camera view.
* **Interactive Controls:** The overlay image allows for scaling and dragging to help with composition or reference.

### Gallery & Media Management
* **Performance:** Global caching of media thumbnails for fast loading.
* **Media Details:** Displays detailed properties for every file:
    * Resolution
    * Format
    * File size
    * Date recorded
    * Disk path
* **Viewer Interaction:**
    * Zoom and pan images/video using gestures.
    * Navigate between files using swipe gestures.
* **Actions:**
    * **Share:** Share files instantly via the native system dialog.
    * **Delete:** Option to remove files directly from the app.

---

## Getting Started

To run this project locally:

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/makedonsky98/CameraTestTask.git
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

## 📱 Requirements
* Flutter SDK
* Android / iOS device

---

**Version 1.0**
