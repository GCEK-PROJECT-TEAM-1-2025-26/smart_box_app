# Smart Box Database Collections - Firebase Setup Guide

## 🔥 **Firebase Console Setup Instructions**

### Step 1: Access Firebase Console

1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Select your Smart Box project
3. Click "Firestore Database" in the left sidebar
4. Click "Create collection" for each collection below

---

## 📋 **Collections to Create**

## 1. **boxes** Collection

**Collection ID:** `boxes`

### Document Structure (Document ID: `box_001`):

```javascript
{
  "boxId": "box_001",                // String
  "location": "Smart Box Location",   // String
  "isLocked": true,                  // Boolean - ESP32 updates this based on physical sensor
  "rfidDetected": true,              // Boolean - ESP32 updates this based on RFID sensor
  "devices": {                       // Map
    "evCharger": {                   // Map
      "isOn": false,                 // Boolean - ESP32 updates after relay control
      "voltage": 230.0,              // Number - ESP32 sends real readings
      "current": 16.0,               // Number - ESP32 sends real readings
      "power": 3680.0                // Number - ESP32 sends real readings
    },
    "threePinSocket": {              // Map
      "isOn": false,                 // Boolean - ESP32 updates after relay control
      "voltage": 230.0,              // Number - ESP32 sends real readings
      "current": 5.0,                // Number - ESP32 sends real readings
      "power": 1150.0                // Number - ESP32 sends real readings
    }
  },
  "status": "available",             // String: "available" | "in_use" | "unlocked"
  "lastUpdated": "2024-03-15T10:30:00Z"  // Timestamp
}
```

**Firebase Console Steps:**

1. Collection ID: `boxes`
2. Document ID: `box_001`
3. Add fields as per the structure above
4. Set Field Types: String, Boolean, Number, Map, Timestamp as specified

---

## 2. **commands** Collection (ESP32 Reads This)

**Collection ID:** `commands`

### Document Structure (Auto-generated Document ID):

```javascript
{
  "boxId": "box_001",               // String
  "commandType": "unlock",          // String: "unlock" | "device_control"
  "payload": {                      // Map
    "action": "unlock",             // String
    "device": "evCharger",          // String (for device_control commands)
    "timestamp": 1709116800000      // Number
  },
  "status": "pending",              // String: "pending" | "completed" | "failed"
  "createdAt": "2024-03-15T10:30:00Z",    // Timestamp
  "executedAt": null,               // Timestamp (nullable)
  "errorMessage": null,             // String (nullable)
  "userId": "user_abc123"           // String
}
```

**Firebase Console Steps:**

1. Collection ID: `commands`
2. Let Document ID auto-generate
3. Add fields as per structure above

## 1. **boxes** Collection

```javascript
{
  "box_001": {
    "boxId": "box_001",
    "location": "Smart Box Location",
    "isLocked": true,           // ← ESP32 updates this based on physical sensor
    "rfidDetected": true,       // ← ESP32 updates this based on RFID sensor
    "devices": {
      "evCharger": {
        "isOn": false,          // ← ESP32 updates after relay control
        "voltage": 230.0,       // ← ESP32 sends real readings
        "current": 16.0,        // ← ESP32 sends real readings
        "power": 3680.0         // ← ESP32 sends real readings
      },
      "threePinSocket": {
        "isOn": false,          // ← ESP32 updates after relay control
        "voltage": 230.0,       // ← ESP32 sends real readings
        "current": 5.0,         // ← ESP32 sends real readings
        "power": 1150.0         // ← ESP32 sends real readings
      }
    },
    "status": "available",      // available | in_use | unlocked
    "lastUpdated": "timestamp"
  }
}
```

## 2. **commands** Collection (ESP32 Reads This)

```javascript
{
  "command_xyz": {
    "boxId": "box_001",
    "commandType": "unlock",    // unlock | device_control
    "payload": {
      "action": "unlock",
      "timestamp": 1709116800000
    },
    "status": "pending",        // pending → completed/failed
    "createdAt": "timestamp",
    "executedAt": null,
    "errorMessage": null,
    "userId": "user_abc"
  }
}
```

---

## 3. **sessions** Collection

**Collection ID:** `sessions`

### Document Structure (Auto-generated Document ID):

```javascript
{
  "userId": "user_abc123",          // String
  "boxId": "box_001",               // String
  "startTime": "2024-03-15T10:30:00Z",    // Timestamp
  "endTime": null,                  // Timestamp (nullable)
  "isActive": true,                 // Boolean
  "devices": {                      // Map
    "evCharger": {                  // Map
      "totalUsage": 0.0,            // Number (kWh - App calculates from ESP32 readings)
      "totalCost": 0.0              // Number (₹ - App calculates usage × rate)
    },
    "threePinSocket": {             // Map
      "totalUsage": 0.0,            // Number
      "totalCost": 0.0              // Number
    }
  },
  "totalCost": 0.0,                 // Number
  "status": "active"                // String: "active" | "completed" | "cancelled"
}
```

**Firebase Console Steps:**

1. Collection ID: `sessions`
2. Let Document ID auto-generate
3. Add fields as per structure above

---

## 4. **sessions/{sessionId}/readings** Subcollection

**Collection ID:** `readings` (inside each session document)

### Document Structure (Auto-generated Document ID):

```javascript
{
  "timestamp": "2024-03-15T10:30:00Z",   // Timestamp
  "evCharger": {                         // Map
    "voltage": 230.0,                    // Number - From ESP32 sensors
    "current": 16.0,                     // Number - From ESP32 sensors
    "power": 3680.0                      // Number - From ESP32 sensors
  },
  "threePinSocket": {                    // Map
    "voltage": 230.0,                    // Number - From ESP32 sensors
    "current": 5.0,                      // Number - From ESP32 sensors
    "power": 1150.0                      // Number - From ESP32 sensors
  }
}
```

**Firebase Console Steps:**

1. Go to any session document
2. Click "Start collection"
3. Collection ID: `readings`
4. Let Document ID auto-generate
5. Add fields as per structure above

---

## 5. **users** Collection (Created automatically by app)

**Collection ID:** `users`

### Document Structure (Document ID: `user_uid`):

```javascript
{
  "uid": "user_abc123",             // String
  "email": "user@example.com",      // String
  "displayName": "John Doe",        // String
  "phone": "+1234567890",           // String (nullable)
  "profilePicture": null,           // String URL (nullable)
  "emailVerified": true,            // Boolean
  "createdAt": "2024-03-15T10:30:00Z",   // Timestamp
  "lastLoginAt": "2024-03-15T10:30:00Z", // Timestamp
  "preferences": {                  // Map
    "notifications": true,          // Boolean
    "theme": "dark",               // String
    "language": "en"               // String
  },
  "walletBalance": 250.75,          // Number (₹)
  "totalSessions": 0,               // Number
  "totalSpent": 0.0                 // Number (₹)
}
```

---

## 🔧 **Firebase Console Creation Steps**

### For Main Collections:

1. **Go to Firestore Database**

   - Open Firebase Console
   - Select your project
   - Click "Firestore Database" → "Data" tab

2. **Create Collections:**

   ```
   ✅ Create collection: "boxes"
   ✅ Create collection: "commands"
   ✅ Create collection: "sessions"
   ✅ Create collection: "users" (optional - auto-created by app)
   ```

3. **Field Types Reference:**
   ```
   String     → Text values
   Number     → Numeric values (integer/decimal)
   Boolean    → true/false
   Timestamp  → Date and time
   Map        → Nested object
   Array      → List of values
   null       → Empty/nullable field
   ```

### Sample Document Creation:

**For `boxes/box_001`:**

1. Collection ID: `boxes`
2. Document ID: `box_001`
3. Add fields:
   - boxId: `box_001` (String)
   - location: `Smart Box Location` (String)
   - isLocked: `true` (Boolean)
   - rfidDetected: `true` (Boolean)
   - devices: (Map) → Click "Add field" for nested structure
   - status: `available` (String)
   - lastUpdated: (Timestamp) → Use current timestamp

---

## 🔍 **How to Verify Setup**

### Test Data Flow:

1. **App creates command** → Check `commands` collection
2. **ESP32 reads command** → Command status changes to "completed"
3. **ESP32 updates status** → Check `boxes` collection updates
4. **User starts session** → Check `sessions` collection
5. **Session readings** → Check `sessions/{sessionId}/readings` subcollection

### Firebase Rules (Security):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Sessions - users can only access their own sessions
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null &&
        resource.data.userId == request.auth.uid;

      // Session readings
      match /readings/{readingId} {
        allow read, write: if request.auth != null;
      }
    }

    // Boxes - read-only for authenticated users
    match /boxes/{boxId} {
      allow read: if request.auth != null;
      allow write: if false; // Only ESP32 should update (via service account)
    }

    // Commands - users can create, but not read others' commands
    match /commands/{commandId} {
      allow create: if request.auth != null &&
        request.resource.data.userId == request.auth.uid;
      allow read, update: if request.auth != null &&
        resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 🚀 **ESP32 Integration Points**

### ESP32 Should Monitor:

1. **commands** collection where `status = "pending"`
2. Update **boxes** collection with real sensor readings
3. Update command **status** to "completed" or "failed"

### ESP32 Firebase Functions:

```cpp
// Read pending commands
void checkPendingCommands()

// Execute unlock command
void unlockBox()

// Control device relays
void controlDevice(String device, bool turnOn)

// Update box status with sensor readings
void updateBoxStatus()

// Update command completion status
void updateCommandStatus(String commandId, String status)
```

### Real-time Updates Required:

- **Every 5 seconds**: Update device readings in `boxes` collection
- **On command**: Update command status in `commands` collection
- **On hardware change**: Update lock/RFID status in `boxes` collection

---

## 📱 **App Integration Confirmed**

✅ **Dashboard** - Shows real-time session data  
✅ **Commands** - Sends unlock/device control commands  
✅ **Sessions** - Tracks usage and costs in real-time  
✅ **Authentication** - Email verification required  
✅ **Profile** - User management and preferences

**Your Firebase database structure is now ready for production! 🎉**
