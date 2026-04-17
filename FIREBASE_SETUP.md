# 🔥 Firebase Setup Guide — ChildGuard App

Yeh guide step-by-step batayegi ke Firebase ko kaise setup karna hai ChildGuard app ke liye.

---

## Step 1: Firebase Console pe Project Banao

1. Browser mein jao: https://console.firebase.google.com
2. **"Add Project"** ya **"Create a project"** pe click karo
3. Project name likho: `ChildGuard`
4. Google Analytics disable kardo (university project hai, zaroorat nahi)
5. **"Create Project"** pe click karo
6. Jab project ban jaye, **"Continue"** pe click karo

---

## Step 2: Android App Register Karo

1. Firebase Console mein apne project pe jao
2. **"Add app"** button pe click karo (ya Android icon ☐)
3. Android package name likho: `com.childguard.childguard`
   - Yeh SAME hona chahiye jo `android/app/build.gradle.kts` mein hai
4. App nickname likho: `ChildGuard`
5. SHA-1 key abhi skip kardo (optional hai)
6. **"Register app"** pe click karo

---

## Step 3: google-services.json Download Karo

1. Firebase Console **"Download google-services.json"** button dikhayega
2. Is file ko download karo
3. Downloaded file ko COPY karo aur yahan PASTE karo:
   ```
   android/app/google-services.json
   ```
4. **IMPORTANT:** Yeh file `android/app/` folder ke andar honi chahiye, `android/` mein nahi!

Folder structure aisi hogi:
```
android/
├── app/
│   ├── google-services.json    ← YAHAN PASTE KARO
│   ├── build.gradle.kts
│   └── src/
│       └── main/
│           └── ...
```

---

## Step 4: Firebase Authentication Enable Karo

1. Firebase Console mein left side mein **"Build"** → **"Authentication"** pe click karo
2. **"Get Started"** pe click karo
3. **"Email/Password"** provider pe click karo
4. **"Enable"** toggle ON karo
5. **"Save"** pe click karo

---

## Step 5: Cloud Firestore Database Banao

1. Firebase Console mein **"Build"** → **"Firestore Database"** pe click karo
2. **"Create Database"** pe click karo
3. Location choose karo (koi bhi select karo, suggestion: `asia-south1` for Pakistan)
4. **"Start in TEST MODE"** select karo (30 din ke liye open access)
5. **"Create"** pe click karo

### Firestore Rules (Test Mode):
Test mode mein yeh rules automatically set ho jayenge:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

> ⚠️ **NOTE:** Test mode sirf 30 din tak kaam karega. University demo ke liye kaafi hai.

---

## Step 6: Flutter Project Mein Packages Install Karo

Terminal mein project folder kholo aur yeh command run karo:

```bash
flutter pub get
```

Yeh sab packages download kar lega (firebase_core, firebase_auth, cloud_firestore, etc.)

---

## Step 7: App Run Karo

```bash
flutter run
```

Agar sab sahi hai toh app start ho jayegi bina kisi error ke!

---

## Troubleshooting (Maslay aur Unka Hal)

### Error: "google-services.json not found"
- Check karo ke file `android/app/` folder mein hai
- File ka naam exactly `google-services.json` hona chahiye

### Error: "No Firebase App"
- Check karo ke `main.dart` mein `Firebase.initializeApp()` call ho rahi hai
- Check karo ke `await` lagaya hai

### Error: "minSdkVersion" issue
- `android/app/build.gradle.kts` mein `minSdk` ko `21` ya `23` set karo:
  ```kotlin
  minSdk = 23
  ```

### Error: "Multidex" issue
- `android/app/build.gradle.kts` mein defaultConfig mein add karo:
  ```kotlin
  multiDexEnabled = true
  ```

---

## Quick Checklist ✅

- [ ] Firebase Console pe project banaya
- [ ] Android app register kiya (package: com.childguard.childguard)
- [ ] google-services.json download karke android/app/ mein dala
- [ ] Authentication mein Email/Password enable kiya
- [ ] Firestore Database banaya (test mode)
- [ ] `flutter pub get` run kiya
- [ ] `flutter run` se app chal gayi

---

## Firebase ka Kaam Ho Gaya! 🎉

Ab app properly Firebase se connect ho jayegi. Login, Register, Location tracking,
Alerts — sab kuch Firebase ke through kaam karega.
