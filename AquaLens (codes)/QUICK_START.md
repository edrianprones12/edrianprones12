# AquaLens Quick Start Guide

## Prerequisites Checklist

- [ ] Flutter SDK installed (3.9.2+)
- [ ] Android Studio / Android SDK installed
- [ ] Android device or emulator ready
- [ ] Firebase account created
- [ ] TensorFlow Lite model file ready

## Quick Setup (5 Steps)

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Firebase Setup

1. Create Firebase project at https://console.firebase.google.com/
2. Add Android app with package: `com.example.boat_classifier`
3. Download `google-services.json` → place in `android/app/`
4. Enable **Authentication** (Anonymous)
5. Enable **Firestore Database** (Test mode)
6. Enable **Storage** (Test mode)

**Detailed instructions**: See `FIREBASE_SETUP.md`

### 3. Add TensorFlow Lite Model

1. Obtain or train a TensorFlow Lite model for 10 boat classes
2. Place `boat_model.tflite` in `assets/ml/` directory
3. Verify `labels.txt` matches your model's output classes

**Model instructions**: See `assets/ml/README_MODEL.md`

### 4. Build and Run

```bash
flutter clean
flutter pub get
flutter run
```

### 5. Test the App

- [ ] Camera opens and shows preview
- [ ] Can capture image
- [ ] Can select from gallery
- [ ] Classification works
- [ ] Results display correctly
- [ ] History saves to Firebase

## Common Issues

### "Model not found" error
→ Add `boat_model.tflite` to `assets/ml/`

### "Firebase not initialized" error
→ Add `google-services.json` to `android/app/`

### "Permission denied" error
→ Enable Anonymous authentication in Firebase Console

### Camera not working
→ Check AndroidManifest.xml has camera permissions

## Next Steps

- Train your own model with Teachable Machine
- Customize UI colors and branding
- Add more boat classes
- Implement real-time classification
- Deploy to Google Play Store

## Need Help?

- **Firebase Setup**: `FIREBASE_SETUP.md`
- **Model Training**: `assets/ml/README_MODEL.md`
- **Full Documentation**: `README.md`

