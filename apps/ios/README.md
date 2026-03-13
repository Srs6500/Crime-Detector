# Krogan iOS

Native Swift/SwiftUI app for Krogan. iOS 18+, USA-focused. One app for both user and guardian; guardian linking via invite.

## Requirements

- Xcode 16+
- iOS 18.0 deployment target
- Swift 6

## Open the project

The Xcode project is checked in (XcodeGen was hanging, so the project was created by hand). Open it directly:

```bash
cd apps/ios
open Krogan.xcodeproj
```

Or in Xcode: **File → Open** and choose `apps/ios/Krogan.xcodeproj`.

## Structure

- `Krogan/App/` — App entry, ContentView
- `Krogan/Features/` — Auth, Home, Session, Guardian, Settings
- `Krogan/Core/` — Network, auth client, shared utilities

## Auth (first release)

- Sign in with Apple
- Phone number (OTP via backend/Twilio)

Backend base URL and API are configured in Core when we add the client.
