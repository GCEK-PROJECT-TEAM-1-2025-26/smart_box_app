# Firebase Configuration Setup

⚠️ **IMPORTANT**: The Firebase configuration files are not included in this repository for security reasons.

## Required Files to Add After Cloning

### 1. Android Configuration

- Create `android/app/google-services.json`
- Get this file from your Firebase Console:
  1. Go to [Firebase Console](https://console.firebase.google.com)
  2. Select your project: `smart-box-app-6c55c`
  3. Go to Project Settings → Your Apps
  4. Download `google-services.json` for Android
  5. Place it in `android/app/`

### 2. Firebase Options (Dart)

- Create `lib/firebase_options.dart`
- Run this command in your project root:
  ```bash
  flutterfire configure
  ```
- This will generate the `firebase_options.dart` file automatically

### 3. Required Firebase Services

Make sure these services are enabled in your Firebase Console:

- **Authentication** (Email/Password and Google Sign-In)
- **Firestore Database**

### 4. Google Sign-In Configuration

- Add your app's SHA-1 fingerprint to Firebase Console
- Get SHA-1 fingerprint by running:
  ```bash
  cd android
  ./gradlew signingReport
  ```
- Copy the SHA1 fingerprint and add it to Firebase Console → Project Settings → Your Apps → Add Fingerprint

### 5. Environment Variables (Optional)

If you're using environment variables, create a `.env` file in the root directory:

```
FIREBASE_PROJECT_ID=smart-box-app-6c55c
FIREBASE_APP_ID=your_app_id
# Add any other environment variables you need
```

## Installation Steps After Cloning

1. Clone this repository
2. Run `flutter pub get`
3. Follow the Firebase configuration steps above
4. Run `flutter run` to start the app

## Package Name

The app uses package name: `com.example.smart_box_app`
Make sure this matches in your Firebase configuration.
