# AquaLens - Boat Image Classification App

AquaLens is an Android mobile application built with Flutter that classifies different types of watercraft using on-device TensorFlow Lite machine learning. The app features Firebase integration for authentication, storage, and history tracking.

## Features

- 📸 **Camera-Based Classification**: Capture images using the device camera
- 🖼️ **Gallery Image Classification**: Select and classify images from gallery
- 🤖 **On-Device ML**: Fast, private inference using TensorFlow Lite
- 🔥 **Firebase Integration**: 
  - Anonymous authentication
  - Cloud Storage for images
  - Firestore for classification history
- 📊 **Classification History**: View all past scans with details
- ℹ️ **Boat Information**: Learn about different boat types

## Supported Boat Classes

1. Bamboo Raft
2. Cargo Boat
3. Ferry Boat
4. Fishing Boat
5. Jet Ski
6. Kayak
7. Sail Boat
8. Speed Boat
9. Tourist Boat
10. Yacht

## Prerequisites

- Flutter SDK (3.9.2 or higher)
- Android Studio / Android SDK
- Firebase account
- TensorFlow Lite model file (see Model Setup below)

## Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd boat_classifier
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

#### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name (e.g., "AquaLens")
4. Follow the setup wizard

#### Step 2: Add Android App to Firebase

1. In Firebase Console, click "Add app" → Android
2. Register app with package name: `com.example.boat_classifier`
3. Download `google-services.json`
4. Place it in `android/app/` directory

#### Step 3: Enable Firebase Services

**Authentication:**
1. Go to Authentication → Sign-in method
2. Enable "Anonymous" sign-in provider

**Firestore Database:**
1. Go to Firestore Database
2. Click "Create database"
3. Start in "Test mode" (or configure security rules)
4. Choose a location

**Storage:**
1. Go to Storage
2. Click "Get started"
3. Start in "Test mode" (or configure security rules)
4. Choose a location

#### Step 4: Configure Android Build Files

The `google-services.json` file should already be referenced. Verify `android/build.gradle.kts` includes:

```kotlin
plugins {
    id("com.google.gms.google-services") version "4.4.0"
}
```

And `android/app/build.gradle.kts` should have:

```kotlin
plugins {
    id("com.google.gms.google-services")
}
```

### 4. TensorFlow Lite Model Setup

1. **Obtain or Train Model**: See `assets/ml/README_MODEL.md` for detailed instructions
2. **Place Model File**: Copy your `boat_model.tflite` to `assets/ml/boat_model.tflite`
3. **Verify Labels**: Ensure `assets/ml/labels.txt` matches your model's output classes

### 5. Android Permissions

Camera and storage permissions are already configured in `AndroidManifest.xml`. For Android 13+, runtime permissions are handled automatically by the camera and image_picker packages.

### 6. Build and Run

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── screens/
│   ├── home_screen.dart      # Main screen with bottom navigation
│   ├── camera_screen.dart    # Camera and gallery image selection
│   ├── result_screen.dart    # Classification results display
│   ├── history_screen.dart   # Scan history from Firestore
│   └── info_screen.dart      # Boat information and descriptions
├── services/
│   ├── firebase_service.dart # Firebase auth, storage, Firestore
│   └── classifier.dart      # TensorFlow Lite model inference
└── widgets/
    └── custom_button.dart    # Reusable button component

assets/
└── ml/
    ├── boat_model.tflite     # TensorFlow Lite model (you need to add this)
    └── labels.txt           # Model class labels
```

## Firestore Data Structure

### Collection: `classifications`

```json
{
  "userId": "string (anonymous user ID)",
  "boatType": "string (e.g., 'Yacht')",
  "confidence": "number (0-100)",
  "imageUrl": "string (Firebase Storage URL)",
  "timestamp": "timestamp (server timestamp)"
}
```

## Firebase Security Rules

### Firestore Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /classifications/{document} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /boat_images/{imageId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Model Training Guide

For detailed instructions on creating or obtaining the TensorFlow Lite model, see:
- `assets/ml/README_MODEL.md`

### Quick Start with Teachable Machine

1. Visit [Teachable Machine](https://teachablemachine.withgoogle.com/)
2. Create Image Project
3. Add 10 classes (one for each boat type)
4. Upload training images (500-1000 per class recommended)
5. Train model
6. Export as TensorFlow Lite
7. Rename to `boat_model.tflite` and place in `assets/ml/`

## Testing

### Unit Tests

```bash
flutter test
```

### Manual Testing Checklist

- [ ] Camera opens and displays preview
- [ ] Image capture works
- [ ] Gallery image selection works
- [ ] Classification returns results
- [ ] Results display correctly
- [ ] History saves to Firestore
- [ ] History displays correctly
- [ ] Images upload to Storage
- [ ] Anonymous authentication works

## Troubleshooting

### Model Not Loading

- Verify `boat_model.tflite` exists in `assets/ml/`
- Check `pubspec.yaml` includes the asset path
- Run `flutter clean` and `flutter pub get`
- Verify model input/output shapes match code expectations

### Firebase Errors

- Verify `google-services.json` is in `android/app/`
- Check Firebase services are enabled in console
- Verify security rules allow anonymous users
- Check internet connection

### Camera Issues

- Verify camera permissions in AndroidManifest.xml
- Check device has camera hardware
- Try restarting the app

## Dependencies

- `firebase_core`: Firebase initialization
- `firebase_auth`: Anonymous authentication
- `cloud_firestore`: Classification history
- `firebase_storage`: Image storage
- `tflite_flutter`: TensorFlow Lite inference
- `camera`: Camera functionality
- `image_picker`: Gallery image selection
- `image`: Image processing
- `intl`: Date formatting

## License

This project is created for educational purposes.

## Support

For issues or questions:
1. Check the troubleshooting section
2. Verify all setup steps are completed
3. Review Firebase console for errors
4. Check Flutter logs: `flutter logs`

## Future Enhancements

- Real-time classification (frame-by-frame)
- Offline mode improvements
- Model accuracy improvements
- Additional boat classes
- iOS support
- Export history feature
