# Qrypt 🔐

**⚠️ Disclaimer**: This tool is for educational and legitimate privacy use cases only. Users are responsible for compliance with local laws and regulations regarding encryption and data protection.

A flexible, privacy-first Flutter application for text compression, encryption, digital signing, and obfuscation. Designed for scenarios where end-to-end encryption is missing, restricted, or unavailable, Qrypt puts full control in the user's hands to securely exchange messages across any communication channel (e.g., SMS, chat, email, forums).

---

## Features ✨

### 🔒 Encryption Methods
- **AES-GCM**: Advanced Encryption Standard with Galois/Counter Mode (authenticated encryption, recommended default).
- **AES-CBC**: AES with Cipher Block Chaining and cryptographically secure random IVs.
- **AES-CTR**: AES in Counter mode for streaming encryption.
- **RSA-OAEP-256**: Asymmetric public-key encryption using PKCS#1 v2.1 OAEP padding with SHA-256 and configurable key sizes (2048, 3072, and 4096 bits). Includes payload size protection.
- **ML-KEM-768 (Kyber)**: NIST-standardized (FIPS 203) Module-Lattice-Based Key Encapsulation Mechanism for post-quantum key exchange.
- **None**: Pass plaintext directly to the signing/obfuscation stages.

### ✍️ Digital Signatures (Authentication & Integrity)
Signatures are orthogonal to encryption—they follow the standard **Encrypt-then-Sign (EtS)** pipeline and can be composed with any encryption method or used on standalone text:
- **ML-DSA (Dilithium)**: NIST-standardized (FIPS 204) lattice-based post-quantum digital signature algorithm.
- **RSA-PSS (SHA-256)**: Probabilistic Signature Scheme (PKCS#1 v2.1 / RFC 8017) with SHA-256 and fail-closed verification.
- **None**: Unsigned message transmission.

### 🗜️ Compression Algorithms
- **Zstandard (Zstd)**: High-performance compression algorithm with excellent compression ratios.
- **Brotli**: Modern Google compression format with high compression efficiency.
- **GZip**: Industry-standard compression offering a balanced size-to-speed profile.
- **LZ4**: Ultra-fast compression/decompression for latency-critical tasks.
- **None**: Uncompressed payload.

### 🎭 Obfuscation Techniques
- **Code-Defined Character Mapping**: Token-based natural language substitution:
  - English variants (**EN1**, **EN2**)
  - Persian/Farsi variants (**FA1**, **FA2**)
  - **Custom Profiles**: Create, import, export, and share custom obfuscation maps via QR code.
- **Base64**: Clean URL-safe ASCII encoding.
- **ROT13**: Classical Caesar cipher alphabet rotation.
- **XOR**: Bitwise byte manipulation.
- **None**: Output raw ciphertext without masking.

### 🏷️ Smart Tagging System
- **Deterministic Routing Tags**: 6-character HMAC routing tags identify exact pipeline configurations.
- **Single-Tap Auto-Decryption**: Automatically parses algorithm combinations, selects keys, validates signatures, and unwraps payloads.
- **Backward Compatibility**: Fully compatible with legacy combined `rsaSign` formats and older profile tags.

---

## Processing Pipeline 🏗️

Qrypt processes messages through a deterministic, layered pipeline:

```
┌──────────────┐     ┌─────────────┐     ┌────────────┐     ┌───────────────────┐     ┌─────────────┐     ┌──────────────┐
│  Input Text  │ ──> │ Compression │ ──> │ Encryption │ ──> │  Digital Signing  │ ──> │ Obfuscation │ ──> │ Final Output │
└──────────────┘     └─────────────┘     └────────────┘     └───────────────────┘     └─────────────┘     └──────────────┘
                        • None              • AES-GCM          • None                    • Custom Maps       (Prepended with
                        • Zstd              • AES-CBC          • RSA-PSS (SHA-256)       • EN1 / EN2         6-character tag)
                        • Brotli            • AES-CTR          • ML-DSA (Dilithium)      • FA1 / FA2
                        • GZip              • RSA-OAEP-256                               • Base64 / ROT13
                        • LZ4               • ML-KEM-768                                 • None
                                            • None
```

---

## Key Exchange Flow (ML-KEM-768) 🤝

Qrypt implements the NIST FIPS 203 post-quantum Key Encapsulation Mechanism (ML-KEM-768 / Kyber) to securely establish symmetric keys between parties without relying on classical Diffie-Hellman or RSA key exchange:

```
Alice (Sender)                                              Bob (Receiver)
──────────────                                              ──────────────
                                                   1. Generate ML-KEM-768 Key Pair
                                                      ┌───────────────────────────┐
                                                      │ Public Key  / Private Key │
                                                      └─────────────┬─────────────┘
                                                                    │
                                Bob's Public Key                    │
                       ◄────────────────────────────────────────────┘
2. Encapsulate Secret
   ┌──────────────────────────────────────────┐
   │ Encapsulate(Bob's Public Key)            │
   │   ├── Shared Secret  (32 bytes)          │
   │   └── KEM Ciphertext (1088 bytes)        │
   └────────────────────┬─────────────────────┘
                        │
                        │   KEM Ciphertext (Tagged / Signed)
                        └───────────────────────────────────────────►
                                                            3. Decapsulate Secret
                                                               ┌───────────────────────────┐
                                                               │ Decapsulate(Ciphertext,   │
                                                               │             Private Key)  │
                                                               │   └── Shared Secret       │
                                                               └─────────────┬─────────────┘
                                                                             │
                            Both Parties Now Share:                          ▼
                   ┌──────────────────────────────────────┐        ┌──────────────────┐
                   │    Shared Secret (32-byte AES Key)   │ <====> │  Shared Secret   │
                   └──────────────────────────────────────┘        └──────────────────┘
```

* **One-Tap AES Key Conversion**: Senders and receivers can immediately save the derived 32-byte shared secret as a persistent 256-bit AES key.
* **Hybrid Authenticated Exchange**: The KEM package can be digitally signed with **ML-DSA** or **RSA-PSS** to verify sender identity and eliminate man-in-the-middle risks.

---

## Key Management 🔑

All keys are managed strictly on-device using platform-native hardware keystores (`FlutterSecureStorage`):

* **AES Keys**: Generates, stores, and validates 128, 192, and 256-bit AES keys (supporting UTF-8 text, 44-character Base64, and 64-character Hex formats).
* **RSA Key Pairs**: Generates 2048, 3072, or 4096-bit RSA keys (defaulting to 3072-bit NIST standard). Supports PEM import/export and separate key pairs for encryption vs. digital signatures.
* **ML-KEM Keys**: Generates and encapsulates post-quantum ML-KEM-768 public/private keys with immediate conversion of derived shared secrets to saved AES keys.
* **ML-DSA Keys**: Generates and manages lattice-based post-quantum signature key pairs.
* **Custom Obfuscation Maps**: In-app management, validation, collision checks, and QR code sharing.

---

## Security & Implementation Details 🛡️

1. **Zero Secret Hardcoding**: No default encryption keys or `.env` files are bundled. All key material is generated or imported by the user.
2. **Fail-Closed Verification**: Digital signatures strictly fail closed—missing keys, corrupt signatures, or tampering immediately halts decompression and decryption.
3. **Payload Bounds Check**: RSA-OAEP enforces maximum plaintext limits before encryption, protecting against cipher buffer exceptions.
4. **Decompression Bomb Protection**: Input and ratio expansion guards prevent decompression bomb exploits across all compression codecs.

---

## Algorithms Summary 📊

### Ciphers
| Algorithm | Key Size / Spec | Type | Quantum-Resistant | Primary Use Case |
|---|---|---|:---:|---|
| **AES-GCM** | 128, 192, 256-bit | Symmetric | Yes* (256-bit) | Default bulk authenticated encryption |
| **AES-CBC** | 128, 192, 256-bit | Symmetric | Yes* (256-bit) | Standard block cipher |
| **AES-CTR** | 128, 192, 256-bit | Symmetric | Yes* (256-bit) | Stream cipher |
| **RSA-OAEP-256** | 2048, 3072, 4096-bit | Asymmetric | No | Asymmetric key transport / small payloads |
| **ML-KEM-768** | FIPS 203 (Kyber) | Asymmetric | Yes | Post-quantum key encapsulation |

*\*AES-256 is considered quantum-safe: while Grover's algorithm theoretically provides a quadratic speedup (reducing brute-force search complexity to ~2¹²⁸ quantum operations), executing 2¹²⁸ quantum operations remains computationally infeasible in practice due to physical limits on circuit depth and parallelization.*

### Signatures
| Algorithm | Key Size / Spec | Quantum-Resistant | Standard |
|---|---|:---:|---|
| **RSA-PSS** | 2048, 3072, 4096-bit (SHA-256) | No | PKCS#1 v2.1 / RFC 8017 |
| **ML-DSA** | FIPS 204 (Dilithium) | Yes | NIST Post-Quantum Standard |

---

## License & Contributing 📄

Contributions, bug reports, and pull requests are welcome! Please ensure code changes follow repository guidelines (`AGENTS.md`) and all tests pass with `flutter test`.
