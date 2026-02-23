# Google Sign-In Configuration Steps

## Current SHA-1 Fingerprint

Debug SHA-1: 92:25:18:69:04:09:5C:91:E2:9B:E0:D2:95:BF:44:33:E3:94:75:5F

## Steps to Fix Google Sign-In:

1. **Go to Firebase Console** (https://console.firebase.google.com)
2. **Select your project**: smart-box-app-6c55c
3. **Go to Project Settings** (gear icon)
4. **Select "Your Apps" tab**
5. **Click on your Android app** (com.example.smart_box_app)
6. **Add the SHA-1 fingerprint**:

   - Scroll down to "SHA certificate fingerprints"
   - Click "Add fingerprint"
   - Add: `92:25:18:69:04:09:5C:91:E2:9B:E0:D2:95:BF:44:33:E3:94:75:5F`
   - Click "Save"

7. **Download the updated google-services.json**:

   - After adding the SHA-1, download the new google-services.json
   - Replace the existing file in android/app/google-services.json

8. **Enable Google Sign-In**:
   - Go to "Authentication" > "Sign-in method"
   - Enable "Google" as a sign-in provider
   - The Android client should now be automatically configured

## Alternative: Get OAuth Client ID

If you see a web client ID in the Google Services JSON, you can also manually configure:

- Go to Google Cloud Console
- Navigate to "APIs & Services" > "Credentials"
- Find your OAuth 2.0 client ID for Android
- Make sure the package name matches: com.example.smart_box_app
- Make sure the SHA-1 fingerprint is added

After completing these steps, Google Sign-In should work properly.
