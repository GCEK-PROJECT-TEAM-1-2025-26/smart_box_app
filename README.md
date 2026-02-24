# Smart Box App

A Flutter application for managing smart electrical boxes with usage tracking and payment functionality.

## Features

- **User Authentication**

  - Email/Password sign-in and sign-up
  - Google Sign-In integration
  - Secure Firebase Authentication

- **Dashboard**

  - Real-time usage tracking for 3-pin plugs and EV chargers
  - Total amount calculation
  - Professional dark theme UI

- **Smart Box Controls**
  - Remote unlock functionality
  - Payment processing
  - Usage monitoring

## Screenshots


## Technologies Used

- **Flutter** - Cross-platform mobile development
- **Firebase Authentication** - User management
- **Cloud Firestore** - Database (ready for future features)
- **Google Sign-In** - OAuth authentication
- **Material Design 3** - Modern UI components

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code
- Firebase project set up

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/smart-box-app.git
   cd smart-box-app
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**

   - Follow the instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
   - Add `google-services.json` to `android/app/`
   - Generate `firebase_options.dart` using `flutterfire configure`

4. **Run the app**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point with authentication wrapper
├── firebase_options.dart     # Firebase configuration (not in repo)
├── screens/
│   ├── login_screen.dart     # Login with email/password and Google
│   ├── signup_screen.dart    # User registration
│   └── dashboard_screen.dart # Main app dashboard
├── services/
│   └── auth_service.dart     # Authentication service
├── theme/
│   └── app_theme.dart        # App-wide theme configuration
└── widgets/
    └── meter_card.dart       # Reusable meter display widget
```

## Configuration

### Firebase

- Authentication enabled for Email/Password and Google Sign-In
- SHA-1 fingerprint configured for Google Sign-In
- Package name: `com.example.smart_box_app`

### Theme

- Professional dark theme with blue accents
- Consistent Material Design 3 components
- Responsive design for various screen sizes

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support or questions, please open an issue in this repository.
