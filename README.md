# Audio Client

Flutter application that streams microphone audio to the Windows server.

## Features

- Simple UI with a single button to enable/disable audio streaming
- Requests microphone permissions from the user
- Streams audio data to the server over TCP sockets
- Low latency audio transmission

## Getting Started

1. Make sure you have Flutter installed
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Connect a device or start an emulator
5. Run `flutter run` to start the app

## Server Connection

The app connects to the Windows server using TCP sockets. You'll need to configure the server IP address in the app settings.

## Implementation Notes

The app uses the following Flutter packages:
- `permission_handler`: For requesting microphone permissions
- `flutter_sound`: For capturing audio from the microphone
- `dart:io`: For TCP socket communication

## Audio Format

The app captures and sends audio in the following format:
- PCM audio
- 44.1 kHz sample rate
- 16-bit depth
- Mono channel

## Protocol

The app follows this protocol when communicating with the server:

1. **Connection**:
   - Connect to server TCP socket
   - Send device name: [2-byte length][UTF-8 string]
   - Receive acknowledgment: [2-byte length][UTF-8 "OK"]

2. **Audio Streaming**:
   - Send audio chunks: [4-byte length][audio data]
   - Each chunk is a complete audio frame