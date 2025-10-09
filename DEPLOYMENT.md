# QR Code Redirect Deployment Guide

## Overview
The `web/download.html` file needs to be deployed to handle QR code redirects when users scan venue QR codes without the Flock app installed.

## Deployment Options

### Option 1: GitHub Pages (Recommended for testing)
1. Create a new GitHub repository
2. Upload the `web/download.html` file to the repository
3. Go to Settings > Pages
4. Select "Deploy from a branch" and choose `main` branch
5. Your URL will be: `https://yourusername.github.io/repositoryname/download.html`

### Option 2: Netlify (Recommended for production)
1. Go to [netlify.com](https://netlify.com)
2. Drag and drop the `web/download.html` file
3. Your URL will be: `https://random-name.netlify.app/download.html`
4. You can set up a custom domain later

### Option 3: Vercel
1. Go to [vercel.com](https://vercel.com)
2. Create a new project
3. Upload the `web/download.html` file
4. Deploy

### Option 4: Firebase Hosting
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Run `firebase init hosting`
3. Upload the `web/download.html` file
4. Run `firebase deploy`

## Update App Configuration

After deploying, update the fallback URLs in your Flutter app:

### In `lib/HomeScreen.dart` and `lib/venue.dart`:
```dart
'fallbackUrl': 'https://your-deployed-url.com/download.html?venue=$venueId'
```

## Deep Link Configuration

For the deep links to work, you need to configure your Flock app to handle these URLs:

### iOS (Info.plist):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.flock.customer</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>flock</string>
        </array>
    </dict>
</array>
```

### Android (AndroidManifest.xml):
```xml
<activity>
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="flock" />
    </intent-filter>
</activity>
```

## Testing

1. Deploy the HTML file
2. Update the fallback URLs in your Flutter app
3. Generate a QR code
4. Test scanning with:
   - Flock app installed
   - Flock app not installed
   - Different device scanners

## Current Configuration

The HTML file is configured to:
- Try to open the Flock app using deep links
- If app is not installed, redirect to app store
- Support both iOS and Android
- Handle venue IDs from QR codes 