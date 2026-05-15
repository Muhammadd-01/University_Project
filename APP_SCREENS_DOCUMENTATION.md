# ChildGuard - Full App Screen Documentation

This document provides a comprehensive breakdown of every screen in the ChildGuard application, including its purpose, user interface (UI) components, and core functionality.

---

## 1. Splash Screen (`splash_screen.dart`)
**Purpose:** Initial loading screen to verify authentication state and provide a branded entry.
- **UI Elements:**
    - Animated ChildGuard Logo.
    - App Name in bold typography.
    - Subtle loading indicator.
- **Functionality:**
    - Checks `SharedPreferences` and `FirebaseAuth` for an existing session.
    - Redirects to **Onboarding** (first time), **Home** (logged in), or **Login** (not logged in).

## 2. Onboarding Screen (`onboarding_screen.dart`)
**Purpose:** Educates new users about the app's key safety features.
- **UI Elements:**
    - Three-page carousel with modern illustrations.
    - "Get Started" button.
- **Functionality:**
    - Slide 1: Focus on **Live Tracking**.
    - Slide 2: Focus on **Safe Zones (Geofencing)**.
    - Slide 3: Focus on **Hardware Panic Triggers**.

## 3. Login Screen (`login_screen.dart`)
**Purpose:** Secure access for existing users.
- **UI Elements:**
    - Email and Password fields.
    - "Forgot Password" link.
    - "Register Now" navigation.
- **Functionality:**
    - Integrates with **Firebase Authentication**.
    - Persistent login using local storage.

## 4. Register Screen (`register_screen.dart`)
**Purpose:** New user creation and role assignment.
- **UI Elements:**
    - Full Name, Email, Password fields.
    - **Role Selector:** Toggle between "Parent" and "Child".
- **Functionality:**
    - Creates a user document in Firestore.
    - Sets initial permissions based on the selected role.

## 5. Home Screen / Dashboard (`home_screen.dart`)
**Purpose:** Central hub for all app features.
- **UI Elements:**
    - **Profile Card:** Displays name, role, and current GPS status.
    - **Family Status:** Shows if a Co-Parent (Mom/Dad) is linked.
    - **Menu Grid:** Cards for Connect, Live Map, Safe Zone, Activity, and SOS List.
    - **Panic Button (Child Only):** A glowing, animated button for instant emergencies.
- **Functionality:**
    - Starts the background location tracking service.
    - Initializes the **Alert Listener** (for parents) to catch incoming emergencies.
    - Manages Logout and Co-Parent linking.

## 6. Connect Screen (`connect_screen.dart`)
**Purpose:** Pairs the child's device with the parent's account.
- **UI Elements:**
    - **Parent View:** Displays a unique 6-digit connection code.
    - **Child View:** Input field to enter the parent's code.
- **Functionality:**
    - Updates the Firestore `connectedTo` field to link devices.
    - Prevents tracking until a secure connection is established.

## 7. Live Map Screen (`map_screen.dart`)
**Purpose:** Visual real-time tracking of the child.
- **UI Elements:**
    - Interactive map (Flutter Map/Google Maps).
    - Child's custom avatar marker.
    - "Last Updated" timestamp.
    - **Navigation Button:** Opens Google Maps for turn-by-turn directions to the child.
- **Functionality:**
    - Listens to a Firestore **Stream** of the child's coordinates.
    - Auto-centers on the child's movement.

## 8. Safe Zone Screen (`safe_zone_screen.dart`)
**Purpose:** Geofencing management (Parent only).
- **UI Elements:**
    - List of saved zones (Home, School, etc.).
    - Map interface to pick a location.
    - **Radius Slider:** Set boundary from 100m to 2000m.
- **Functionality:**
    - Saves zones to the parent's Firestore profile.
    - Used by the background worker to trigger "Boundary Breach" alerts.

## 10. Contacts Screen (`contacts_screen.dart`)
**Purpose:** Management of emergency SMS recipients.
- **UI Elements:**
    - List of SOS contacts (Name & Phone Number).
    - "Add Contact" button (integrates with phone's contact picker).
- **Functionality:**
    - Syncs contacts to Firestore.
    - These numbers receive the **Silent SMS** during a Panic trigger.

## 11. Panic Screen (`panic_screen.dart`)
**Purpose:** Dedicated emergency interface for the child.
- **UI Elements:**
    - Massive Red "SOS" button.
    - Real-time status log (e.g., "Sending SMS 1/3...").
- **Functionality:**
    - **Manual Trigger:** Tapping the button.
    - **Hardware Trigger:** Intercepts Volume/Power button presses via Native Android Channels.
    - **Silent SMS:** Sends automated texts to the SOS list without user intervention.

## 12. Danger Screen (`danger_screen.dart`)
**Purpose:** High-priority alarm interface for the parent.
- **UI Elements:**
    - Full-screen flashing red background.
    - "STOP ALARM" button.
    - Large text showing the alert type and message.
- **Functionality:**
    - Bypasses "Silent Mode" to play a loud alarm sound.
    - Vibrates the device aggressively.
    - Pops up over other apps using Android `System Alert Window`.
