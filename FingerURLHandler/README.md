# Finger for iOS

A tiny native iOS Finger client and `finger://` URL handler.

## Features

- Registers the `finger` URL scheme with iOS.
- Handles the IANA provisional syntax `finger://host[:port][/<request>]`.
- Also accepts `finger://user@host` as a convenience.
- Direct TCP Finger queries using Apple's `Network.framework`.
- TCP port 79 by default; custom ports supported.
- `/W` verbose queries.
- Manual host/request UI, response viewer, copy URL, copy response.
- 10-second timeout and 1 MiB response cap.
- Rejects CR/LF in requests so an incoming URL cannot inject extra Finger query lines.
- Includes `NSLocalNetworkUsageDescription` so local-LAN Finger servers can be accessed after user approval.

## Build

1. Open `Finger.xcodeproj` in Xcode.
2. Select the **Finger** target.
3. Under **Signing & Capabilities**, select your Development Team.
4. If Xcode says the bundle identifier is unavailable, change `works.endoftime.Finger` to any identifier you control.
5. Run on an iPhone or iPad.

No third-party packages are used.

## URL examples

```text
finger://example.com/
finger://example.com/alice
finger://example.com:7979/alice
finger://alice@example.com
```

Verbose `/W` requests are encoded into the request path, for example:

```text
finger://example.com/%2FW%20alice
```

The app also accepts this convenience form:

```text
finger://example.com/alice?verbose=1
```

## Test the URL handler

Once the app is installed, tap a `finger://...` link from another app, or invoke one with a Shortcut. iOS launches the app and SwiftUI's `onOpenURL` handler immediately runs the query.

## Protocol/security note

Finger (RFC 1288) is plaintext and unauthenticated. Do not treat returned text as trusted, and do not use Finger where confidentiality or authentication is required.
