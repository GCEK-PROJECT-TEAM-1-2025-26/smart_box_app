# Smart Box App 🔐

A Flutter mobile app for controlling smart boxes with QR code scanning, energy monitoring, and digital wallet payments.

## ✨ Features

- **QR Code Scanning** - Scan box QR codes or enter Box ID manually
- **Multi-Box Support** - Access different smart boxes
- **Remote Control** - Lock/unlock boxes, control devices (EV charger, 3-pin socket)
- **Real-time Monitoring** - Energy usage tracking with cost calculation
- **Digital Wallet** - Prepaid balance system
- **Live Updates** - Firestore integration for real-time data
- **User Authentication** - Firebase Auth with email verification

## 🚀 Quick Start

```bash
cd m:\smart_box_app
flutter pub get
flutter run
```

## 📱 How It Works

1. **Login** - Enter email/password
2. **Verify Email** - Click verification link
3. **Select Box** - Scan QR code or enter box ID (e.g., `box_001`)
4. **Control** - Unlock, start session, toggle devices
5. **Monitor** - View real-time energy usage and costs

## 📁 Project Structure

```
lib/
├── main.dart                          # Entry point & auth wrapper
├── screens/
│   ├── login_screen.dart
│   ├── email_verification_screen.dart
│   ├── box_selection_screen.dart     # ⭐ NEW: QR scanner & manual entry
│   ├── dashboard_screen.dart          # Main control dashboard
│   └── profile_screen.dart
├── services/
│   ├── auth_service.dart
│   ├── box_service.dart               # ⭐ Updated with validateBoxId()
│   ├── command_service.dart
│   ├── session_service.dart
│   └── user_service.dart
├── models/
├── widgets/
└── theme/
    └── app_theme.dart                # Dark theme
```

## 🗄️ Firestore Collections

- **boxes/** - Smart box configurations and status
- **commands/** - Relay control commands (unlock, device control)
- **sessions/** - Usage tracking and billing
- **users/** - User wallet balances and preferences

## 📦 Dependencies

```yaml
firebase_core: ^3.8.0
firebase_auth: ^5.3.3
cloud_firestore: ^5.4.4
qr_code_scanner: ^1.0.1 # ⭐ NEW
permission_handler: ^12.0.2 # ⭐ NEW
google_sign_in: ^6.2.1
```

## ✅ Testing Checklist

- [ ] Login → Email verification → Box Selection
- [ ] Manual entry: Type `box_001` → Dashboard
- [ ] QR scan: Scan code → Dashboard
- [ ] Invalid box: See error
- [ ] Lock/Unlock works
- [ ] Device control works
- [ ] Session tracking works
- [ ] Back button returns to Box Selection
- [ ] Multiple boxes work
- [ ] Logout works

## 🔧 Setup Needed

**Android**: Camera permission already in `AndroidManifest.xml`  
**iOS**: Camera permission already in `Info.plist`

## 🆘 Troubleshooting

| Issue                  | Solution                              |
| ---------------------- | ------------------------------------- |
| Camera not working     | Grant camera permission in Settings   |
| "Box not found"        | Verify box exists in Firestore        |
| QR code not scanning   | Ensure good lighting, clear code      |
| Commands not executing | Check ESP32 backend & Firestore rules |

## 📊 Recent Changes

- ✅ Added QR code scanner screen
- ✅ Added manual box ID entry
- ✅ Multi-box support with dynamic box ID
- ✅ Camera permission handling
- ✅ Box validation in Firestore

---

**Status**: ✅ Production Ready | **Version**: 1.0.0 | **Updated**: May 30, 2026
