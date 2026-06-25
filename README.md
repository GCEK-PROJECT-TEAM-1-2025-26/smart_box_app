# Smart Box App 🔐

A comprehensive Flutter mobile application for controlling smart energy boxes. Features QR code scanning, energy monitoring, digital wallet payments, Google Maps navigation, and ESP32 hardware integration.

## ✨ Features

- **QR Code Scanning** - Scan box QR codes or enter Box ID manually (`mobile_scanner`).
- **Google Maps Integration** - Locate nearby boxes on a map and navigate directly to them (`google_maps_flutter`).
- **Remote Control** - Lock/unlock boxes and toggle power to EV Chargers and 3-Pin Sockets.
- **Real-time Monitoring** - Track live energy usage (Voltage, Current, Power) and cost calculations.
- **Digital Wallet & Payments** - Recharge digital wallet using Razorpay integration.
- **Live Updates** - Real-time synchronization using Firebase Firestore Streams.
- **User Authentication** - Secure login via Firebase Auth with email verification.

## 🚀 Quick Start

1. **Clone & Install**
   ```bash
   cd m:\smart_box_app
   flutter pub get
   ```

2. **Environment Setup**
   Create a `.env` file in the root directory and add your Razorpay API Key:
   ```env
   RAZORPAY_API_KEY=rzp_test_YOUR_API_KEY_HERE
   ```

3. **Run App**
   ```bash
   flutter run
   ```

## 📱 How It Works

1. **Authentication**: Register, verify email, and log in.
2. **Find a Box**: Use the Map screen to locate nearby boxes. Tap "Navigate" to get directions via external Maps.
3. **Connect**: Scan the QR code on the physical box or enter the ID (e.g., `box_001`).
4. **Control**: Start a session, unlock the physical lid, and turn on the EV/Socket relays.
5. **Monitor & Pay**: View real-time energy flow. When the session ends, the cost is automatically deducted from your Wallet Balance. Recharge the wallet using the Razorpay gateway if funds run low.

## 🗄️ Firebase Structure

### Firestore Collections
- **`boxes/`**: Contains box configuration, coordinates (`latitude`, `longitude`), and rates (`tariff.evRate`, `tariff.socketRate`).
- **`commands/`**: Relay commands sent from the app to the ESP32 (e.g., `{"command": "unlock"}`).
- **`sessions/`**: Usage tracking logs (kWh consumed, session duration, cost).
- **`users/`**: Stores user profiles, preferences, and real-time `walletBalance`.

### Security Note
For production, ensure Firestore Rules restrict users from manually modifying their own `walletBalance`. Balance updates should be handled securely by Firebase Cloud Functions via Razorpay webhooks.

## 🔧 Google Maps Setup
The app uses the Google Maps SDK. Ensure you have restricted your API key in the Google Cloud Console to this app's package name (`com.example.smart_box_app`) and your debug/release SHA-1 fingerprint.

## 📦 Core Dependencies
- `firebase_core`, `firebase_auth`, `cloud_firestore`
- `razorpay_flutter` (Wallet Recharge)
- `google_maps_flutter`, `geolocator`, `url_launcher` (Maps & Navigation)
- `mobile_scanner` (QR Code)
- `flutter_dotenv` (Environment Variables)

---

**Status**: ✅ Production Ready | **Version**: 1.1.0
