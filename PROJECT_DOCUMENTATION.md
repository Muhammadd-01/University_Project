# ChildGuard - Architecture & Documentation

Welcome to the ChildGuard technical documentation! This guide is designed for developers, students, and educators who want to understand the inner workings of the ChildGuard mobile application.

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Data Flow & Database Schema](#data-flow--database-schema)
3. [Emergency System (Panic Mode)](#emergency-system-panic-mode)
4. [Background Services & Native Integrations](#background-services--native-integrations)
5. [Code Structure & Roman Urdu Guide](#code-structure--roman-urdu-guide)

---

## System Architecture

ChildGuard uses a robust, real-time architecture built upon Flutter (Dart) for the front end and Firebase for the back end. 

### Roles
The system divides users into two primary roles:
- **Parent**: Monitors locations, sets safe boundaries, and manages emergency contacts. A parent can also connect to a "Co-Parent" to mirror all data and alerts.
- **Child**: The monitored device that continuously sends location updates and can trigger panic alerts.

### Tech Stack
- **Frontend**: Flutter (Cross-platform UI)
- **Backend**: Firebase Authentication & Cloud Firestore (Real-time NoSQL Database)
- **Native Android**: 
  - `MethodChannel`: For sending silent SMS using native Android APIs.
  - `EventChannel`: For listening to hardware button clicks (Power/Volume buttons) even when the app is in the background.
- **Background Tasks**: `Workmanager` handles background location checks and geofence evaluation without draining the battery.

---

## Data Flow & Database Schema

The database uses Cloud Firestore collections to manage state and synchronize devices instantly.

### Collections:
1. `users` (Contains both Parent and Child profiles)
2. `locations` (Live GPS coordinates of children)
3. `alerts` (Emergency notifications, e.g., panic or boundary breaches)

### Example User Document (Parent):
```json
{
  "email": "parent@example.com",
  "name": "Ali (Dad)",
  "role": "parent",
  "connectionCode": "123456",
  "children": ["child_uid_1", "child_uid_2"],
  "coParent": "mom_uid_1",
  "safeZones": [
    { "name": "School", "lat": 31.5204, "lng": 74.3587, "radius": 500 }
  ],
  "emergencyContacts": [
    { "name": "Uncle", "phone": "03001234567", "countryCode": "+92" }
  ]
}
```

---

## Emergency System (Panic Mode)

The Panic Mode is the core safety feature of ChildGuard. It is designed to be accessible and highly reliable.

### How it triggers:
1. **Manual**: The child opens the app and taps the big red "Emergency" button on the `PanicScreen`.
2. **Hardware**: The child presses the physical Power Button 3 times or holds the Volume Buttons. This is captured by native Android code via an `EventChannel`.

### The Action Flow:
1. **Firestore Alert**: An alert document is instantly written to the `alerts` collection.
2. **Parent Reaction**: The parent's device is actively listening to the `alerts` stream. When an alert arrives, the parent's app immediately triggers a full-screen `DangerScreen`, vibrating aggressively and playing an alarm.
3. **Silent SMS**: Simultaneously, the child's device fetches the emergency contacts set by the parent. Using native Android permissions, the app silently sends an SMS containing the child's Google Maps location to all contacts.

---

## Background Services & Native Integrations

To ensure safety, ChildGuard must operate even when the app is closed.

### 1. Workmanager (Geofencing)
The `main.dart` file registers a headless task using `Workmanager`. This task wakes up periodically (every ~15 mins), fetches the child's GPS location, and checks if they are inside the parent's defined `safeZones`. If the child is outside the zone, it writes a `boundary` alert to Firestore.

### 2. Method Channels & Android Manifest
The app requires deep integration with Android to function fully:
- `SEND_SMS`: Required to auto-send texts during emergencies.
- `SYSTEM_ALERT_WINDOW`: Required to pop up the `DangerScreen` on the parent's phone even if they are using another app.
- `VIBRATE` & `WAKE_LOCK`: To alert the parent effectively.

---

## Code Structure & Roman Urdu Guide

For educational purposes, the core business logic files have been documented using **Roman Urdu**. This allows beginner programmers and local students to grasp complex concepts like Streams, Async/Await, and State Management more easily.

### Key Files to Study:
- `lib/services/firestore_service.dart`: Seekhye ke data database me kaisay jata hai aur nikalta hai. (Database operations)
- `lib/screens/panic_screen.dart`: Seekhye ke hardware buttons aur silent SMS kaisay kaam karte hain. (Emergency response)
- `lib/screens/connect_screen.dart`: Seekhye ke Parent aur Child ki app aapas me kaisay link hoti hai. (User linking)
- `lib/screens/home_screen.dart`: Seekhye ke app real-time mein dosre phone ki updates kaisay dekhti hai. (StreamBuilders and UI state)

---

*Thank you for exploring the ChildGuard Codebase!*
