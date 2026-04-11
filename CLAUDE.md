# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Rmos Sayım** — A Flutter mobile/desktop app for inventory management, goods receiving (mal kabul), and barcode-based stock counting, targeting Turkish logistics/hospitality environments. Primary deployment target is Windows (Oracle Micros POS tablet), with Android/iOS also supported.

## Build & Development Commands

```bash
# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run on Windows desktop
flutter run -d windows

# Build for Android
flutter build apk

# Build for Windows
flutter build windows

# Run tests
flutter test

# Analyze code
flutter analyze
```

## Architecture

### State Management
Uses the **Provider** package. Two global providers initialized in `main.dart`:
- `ThemeProvider` — dark/light theme toggle
- `SelectedDatabaseProvider` — tracks which database/branch the user is working against

### Services (`lib/services/`)
- **`ApiService`** — All HTTP calls. Uses three base URLs (`baseUrl`, `backApiBaseUrl`, `efaturaApiBaseUrl`). Bearer token auth after login.
- **`StorageService`** — SharedPreferences wrapper for local persistence (auth token, selected port, etc.)
- **`SerialBarcodeService`** — Windows-only singleton. Manages COM port lifecycle for a physical barcode scanner. Injects scanned barcodes as Win32 keyboard events (`SendInput`) into the active window. Port preference persisted via `StorageService` under key `barcode_port`.

### Screens (`lib/screens/`)
Navigation flow: `LoginScreen` → `DatabaseSelectionScreen` → `MainMenuScreen` → functional screens (`BarcodeInventoryScreen`, `MalKabulScreen`, `AmberRequestScreen`, etc.)

### Data Models (`lib/models/`)
29 model classes covering API responses and domain entities (inventory, orders, products, branches).

## Serial Barcode Scanner (Windows-specific)

The `SerialBarcodeService` is a singleton initialized in `main()` but port-opened deferred to `LoginScreen.initState()`. Key rules:
- **Do not call `dispose()` in `LoginScreen.dispose()`** — only cancel the stream subscription. The singleton owns the port for the full app lifetime.
- Serial config: 9600 baud, 8N1
- Uses `calloc` from `package:ffi` for Win32 SendInput memory; always free in a `finally` block
- Buffer flushes on CR (13) or LF (10); handles `\r\n` pairs
- Requires `flutter_libserialport` and `win32` packages; Windows build bundles `libserialport-0.dll`

## Key Dependencies

| Package | Purpose |
|---|---|
| `provider` | State management |
| `http` | REST API calls |
| `qr_code_scanner_plus` | Camera-based QR/barcode scanning |
| `shared_preferences` | Local persistence |
| `flutter_libserialport` | Windows COM port access |
| `win32` | Win32 API (SendInput for keyboard injection) |
| `intl` | Turkish locale formatting |

## Windows Build Notları

### `atlbase.h` Hatası
`flutter build windows --release` sırasında şu hata alınırsa:
```
error C1083: 'atlbase.h': No such file or directory
```
**Çözüm:** Visual Studio Installer → Modify → Individual components → şunu yükle:
> **Son v143 derleme araçları için C++ ATL (x86 ve x64)**

Sebep: `alice` paketi → `flutter_local_notifications_windows` bağımlılığı ATL header gerektirir. Sadece build makinesinde gerekli, dağıtım PC'lerinde değil.

### Dağıtım
Build tamamlandıktan sonra `build/windows/x64/runner/Release/` klasörünün **tamamı** hedef PC'ye taşınmalı (sadece .exe değil). Hedef PC'lerde ek kurulum gerekmez.

## Turkish Locale

The app is Turkish-language. UI strings are in Turkish. The app initializes with `tr_TR` locale. Model field names often use Turkish (e.g., `Sube` = branch, `Sayim` = inventory count, `MalKabul` = goods receiving).
