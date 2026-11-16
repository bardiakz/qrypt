# Privacy Policy & Disclaimer for Qrypt

## 1. Overview & Core Philosophy

Qrypt is an open-source, client-side cryptography and text obfuscation utility designed with strict zero-knowledge principles. The application operates **100% offline** on your device. Qrypt has no backend servers, performs no network requests, and integrates zero tracking, analytics, or third-party telemetry frameworks.

---

## 2. Information Collection and Telemetry

Qrypt does not collect, harvest, monitor, or transmit any user information or telemetry. Specifically, the application does not request or require access to:

- Personal identity or contact information
- Device identifiers, IMEI, or advertising IDs
- Geolocation data
- Cameras, microphones, or photo libraries
- Contacts, calendars, or system logs
- Network or internet connectivity

All cryptographic computations (encryption, decryption, signing, verification, compression, and obfuscation) execute exclusively in local memory on your device.

---

## 3. Local Data Storage & Key Security

Certain user-created data is stored locally on your device to enable core functionality across sessions:

- **Cryptographic Keys**: User-generated or imported symmetric keys (AES-GCM, AES-CBC, AES-CTR) and asymmetric key pairs (RSA, ML-KEM-768, ML-DSA-65).
- **Custom Obfuscation Profiles**: User-defined character/word replacement maps.
- **Application Preferences**: Selected default encryption algorithms, compression methods, obfuscation profiles, signature modes, and theme settings.

### How Data Is Secured
Locally persisted keys and preferences are stored exclusively in platform-native secure storage mechanisms provided by your operating system via `FlutterSecureStorage`:
- **Android**: Android Keystore with encrypted SharedPreferences (AES-256 GCM).
- **iOS / macOS**: Apple Keychain Services with hardware-backed Secure Enclave where supported.
- **Linux**: Linux Secret Service API (via `libsecret` / GNOME Keyring / KWallet).
- **Windows**: Windows Data Protection API (DPAPI).

None of this information is ever synchronized, transmitted, or accessible to the developers or any third party.

---

## 4. User Control & Data Deletion

You have absolute sovereignty over your data:
- **In-App Data Wipe**: You can permanently and irreversibly erase all stored keys, custom maps, and settings at any time by selecting **Settings > Clear All Saved Data**.
- **Uninstallation**: Uninstalling Qrypt automatically removes all locally stored data on standard operating systems.

---

## 5. Third-Party Services & Dependencies

Qrypt does not incorporate any advertising networks, third-party analytics SDKs (e.g., Firebase, Google Analytics, Sentry), or external cloud services.

---

## 6. Disclaimers, Limitation of Liability & Backward Compatibility

### "AS IS" Warranty Disclaimer
THE APPLICATION IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT. ALL RISKS ARISING OUT OF THE USE OR PERFORMANCE OF THE SOFTWARE REMAIN WITH THE USER.

### Limitation of Liability
IN NO EVENT SHALL THE AUTHORS, MAINTAINERS, CONTRIBUTORS, OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, LOSS OF DATA, CORRUPTION OF DATA, INTERCEPTED COMMUNICATIONS, LOST CRYPTOGRAPHIC KEYS, BUSINESS INTERRUPTION, OR ANY OTHER DIRECT, INDIRECT, INCIDENTAL, SPECIAL, OR CONSEQUENTIAL DAMAGES ARISING FROM THE USE OF OR INABILITY TO USE THIS APPLICATION.

### No Guaranteed Backward Compatibility
While maintainers strive to preserve backward compatibility across updates where feasible, **backward compatibility across versions is NOT guaranteed**. Cryptographic algorithms, tag formats, serialization protocols, and underlying libraries evolve over time. Older ciphertexts, tags, or keys may become deprecated or unreadable in future releases. **The developers accept no responsibility or liability if older encrypted data or tags cannot be decrypted by future versions or vice versa.** Users are strongly advised to keep permanent, unencrypted backups of critical information and maintain key backups independently.

### User Responsibility for Cryptographic Keys
All encryption operations are irreversible without the corresponding key or passphrase. The developers have no access to your device or data and **cannot recover, reset, or bypass** lost keys or passwords. Safeguarding keys and passphrases is the sole responsibility of the user.

### Legal Compliance
Users are solely responsible for verifying that their use of cryptography and obfuscation complies with all laws, export controls, and regulations in their respective jurisdiction.

---

## 7. Open Source Verification

Qrypt is open-source software under the MIT License. The complete source code is publicly accessible and auditable at:
[https://github.com/bardiakz/qrypt](https://github.com/bardiakz/qrypt)

---

## 8. Changes to This Policy

If changes are made to how the application handles data in future versions, this document and the in-app notice will be updated accordingly.

---

*Last updated: November 2026*
