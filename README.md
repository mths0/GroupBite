# Yjeek - API Keys Setup


# !!!!!
# Security Note !
Do not commit real API keys to the repository.

If a key is accidentally pushed:
	1.	Revoke the key immediately
	2.	Generate a new key
	3.	Update your local configuration
# !!!!!!

Before running the project, each developer must add their own API keys locally.

For security reasons, the repository contains **placeholder values only**.

---

# 1. Google Maps API Key

### Android

Open the file:

android/app/src/main/AndroidManifest.xml

Find this section:

xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>

Replace YOUR_API_KEY with your Google Maps API key.

Example:

<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIza..." />

Create a key from:

Google Cloud Console → APIs & Services → Credentials

Make sure to restrict the key to the Android package name.

⸻

# 2. Firebase Configuration

Each developer must connect the project to their own Firebase configuration.

### Android

Replace the file:

android/app/google-services.json

Steps:
	1.	Open Firebase Console
	2.	Create or open a project
	3.	Add an Android App
	4.	Download google-services.json
	5.	Place it in:

android/app/

⸻

### iOS

Replace the file:

ios/Runner/GoogleService-Info.plist

Steps:
	1.	Add an iOS App in Firebase Console
	2.	Download GoogleService-Info.plist
	3.	Place it in:

ios/Runner/

⸻

# 3. Firebase Options (Flutter)

Open:

lib/firebase_options.dart

Replace the placeholders:

apiKey: 'YOUR_API_KEY_ANDROID'
apiKey: 'YOUR_API_KEY_IOS'

