# ChildGuard 🛡️

**ChildGuard** is a Flutter-based mobile application designed to help parents keep their children safe in the real world. It features real-time GPS tracking, geofenced safe zones, and a highly reliable native emergency (SOS) system that works even when the phone is locked.

## 🌟 Key Features

1. **Real-time Tracking**: See exactly where your child is on a live map with visual markers and distance estimates.
2. **Safe Zones (Geofencing)**: Set up virtual boundaries around places like "Home" or "School". If the child leaves these areas, the parent is alerted immediately.
3. **Panic Mode / SOS**: 
   - **In-App Button**: A large red panic button for immediate alerts.
   - **Hardware Triggers**: The child can quickly press the **Power button 3 times** or use the **Volume buttons** to trigger an SOS silently, without even unlocking the phone.
4. **Intelligent Alerts**:
   - Sends silent SMS messages with live Google Maps links to pre-configured emergency contacts.
   - Bypasses battery optimization on the parent's phone to launch a Full-Screen intent (Danger Screen) with aggressive vibration.
5. **Co-Parenting**: Both parents can link their accounts to monitor the child simultaneously.
6. **Student Friendly Codebase**: Core logic files are heavily commented in Roman Urdu to help local students understand advanced Flutter concepts easily.

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: Firebase Authentication & Cloud Firestore
- **Mapping**: `flutter_map` with CartoDB Voyager tiles
- **Animations**: `flutter_animate` for a premium, dynamic UI experience
- **Native Android**: 
  - `MethodChannel` for direct access to Android's `SmsManager` (Silent SMS).
  - `EventChannel` for background hardware button listening.
- **Background Processes**: `Workmanager` for periodic geofence checking without draining battery life.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (Latest stable)
- Android Studio / VS Code
- A Firebase Project (with Auth and Firestore enabled)

### Installation
1. Clone the repository:
   ```bash
   git clone <repository-url>
   ```
2. Navigate to the project directory:
   ```bash
   cd University_Project
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. **Firebase Setup**:
   - Ensure your `google-services.json` (for Android) is placed in `android/app/`.
   - Ensure you have enabled Email/Password Authentication in your Firebase Console.
   - Set up Firestore Rules to allow read/write for authenticated users.
5. Run the app:
   ```bash
   flutter run
   ```

## 📖 Documentation
If you are a student or developer looking to understand *how* the app works, please read the [PROJECT_DOCUMENTATION.md](PROJECT_DOCUMENTATION.md) file included in this repository. 

It covers the database schema, background service logic, and the overall system architecture. We have also added extensive **Roman Urdu comments** directly in the Dart files to explain complex logic block by block!

## 📸 Screenshots
*(Add your app screenshots here)*

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the issues page.

---
*Stay Safe, Stay Connected.*
