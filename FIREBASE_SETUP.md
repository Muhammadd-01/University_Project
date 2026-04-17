# ChildGuard - Firebase Setup Guide (Roman Urdu)

App ko Firebase se connect karne ke liye ye steps follow karein:

## 1. Firebase Project Banayein
- [Firebase Console](https://console.firebase.google.com/) pe jayein.
- **Add Project** pe click karein aur naam "ChildGuard" rakhein.

## 2. Android App Register Karein
- Project Dashboard mein **Android icon** pe click karein.
- **Package Name** "com.childguard.childguard" dalein.
- `google-services.json` file download karein aur ise `android/app/` folder mein paste karein.

## 3. Firestore Database Setup
- **Build > Firestore Database** mein jayein.
- **Create Database** pe click karein.
- **Rules** tab mein jayein aur `FIRESTORE_RULES.txt` waale rules paste karke **Publish** karein.

## 4. Firestore Composite Indexes (IMPORTANT! 🚨)
Alerts system ko sahi se chalane ke liye aapko **Composite Index** banana padega. Iske bagair Alerts screen pe data nahi dikhega.

### Index Kyun Chahiye? (Deep Explanation)
Firestore mein jab hum kisi data ko filter karte hain (jaise: `where('parentId', isEqualTo: '...')`) aur saath hi kisi doosre field pe sort karte hain (jaise: `orderBy('timestamp', descending: true)`), toh Firestore ko **pehle se pata hona chahiye** ke ye data kis order mein save hai.

**Roman Urdu Explanation:**
1. **Single Index:** Firestore default mein har field ka alag index banata hai. Lekin jab hum 2 different fields (parentId aur timestamp) ko ek saath use karte hain, toh Firestore confuse ho jata hai ke pehle filter kare ya pehle sort kare.
2. **Composite Index:** Ye index do ya do se zyada fields ko milakar ek special "map" banata hai. Isse Firestore ko pata chal jata hai ke specific Parent ke alerts kahan hain aur wo time ke hisab se kaise lage hue hain. Isse query bohot fast ho jati hai.

### Index Kaise Banayein?
1. App mein **Alerts** screen pe jayein.
2. Apne computer ke **Debug Console** (VS Code ya Android Studio) mein dekhein.
3. Wahan ek Error message dikhega jisme ek **URL/Link** hoga.
4. Us link pe click karein. Ye aapko direct Firebase Console ke Index page pe le jayega.
5. Sirf **Create Index** button pe click kar dein. 5-10 minutes mein alerts chalne lagenge!

---

## 5. Firebase Auth Enable Karein
- **Build > Authentication** mein jayein.
- **Get Started** pe click karein.
- **Sign-in method** mein **Email/Password** ko enable karein.
