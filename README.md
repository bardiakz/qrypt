# Qrypt 🔐

**⚠️ Disclaimer**: This tool is for educational and legitimate use cases only. Users are responsible
for compliance with local laws and regulations regarding encryption and data protection.

A comprehensive Flutter application for text encryption, compression, and obfuscation with support
for multiple algorithms and customizable processing pipelines, including quantum-safe encryption.

## Features ✨

### 🔒 Encryption Methods

- **AES-CBC**: Advanced Encryption Standard with Cipher Block Chaining
- **AES-CTR**: AES with Counter mode for streaming encryption
- **AES-GCM**: AES with Galois/Counter Mode for authenticated encryption
- **RSA**: RSA encryption with public-key cryptography and built-in key-pair generation
- **ML-KEM (Kyber)**: Post-quantum key encapsulation mechanism for quantum-safe key exchange
- **None**: Base64 encoding without encryption

### 🛡️ Quantum-Safe Cryptography

- **ML-KEM-768**: NIST-standardized Module-Lattice-Based Key Encapsulation Mechanism
- Key exchange resistant to quantum computer attacks
- Built-in key pair generation and management
- Ciphertext encapsulation and shared secret extraction
- Based on liboqs (Open Quantum Safe) library

### 🗜️ Compression Algorithms

- **GZip**: Industry-standard compression
- **LZ4**: High-speed compression/decompression
- **Brotli**: Modern compression with excellent ratios
- **Zstd**: Facebook's high-performance compression

### 🎭 Obfuscation Techniques

- **Character Mapping**: Custom language-specific character substitution
    - English variants (EN1, EN2)
    - Persian/Farsi variants (FA1, FA2)
- **Base64**: Simple encoding obfuscation
- **ROT13**: Classical letter substitution cipher
- **XOR**: Bitwise XOR with configurable key
- **Reverse**: String reversal obfuscation

### 🏷️ Smart Tagging System

- Automatic method detection from embedded tags
- Seamless encoding/decoding without manual configuration
- Compact tag format for efficient storage

## Architecture 🏗️

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Input Text    │ -> │  Compression    │ -> │   Encryption    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
┌─────────────────┐    ┌─────────────────┐              │
│  Final Output   │ <- │  Obfuscation    │ <-           │
└─────────────────┘    └─────────────────┘              │
                              ^                         │
                              └─── Tag Addition ←───────┘

                    ┌─────────────────────────────┐
                    │    Quantum-Safe Layer       │
                    │                             │
                    │  ML-KEM Key Exchange        │
                    │  ┌─────────┐  ┌─────────┐  │
                    │  │ Public  │  │ Secret  │  │
                    │  │   Key   │  │   Key   │  │
                    │  └─────────┘  └─────────┘  │
                    │       │           │        │
                    │       ▼           ▼        │
                    │  ┌─────────────────────┐   │
                    │  │   Shared Secret     │   │
                    │  └─────────────────────┘   │
                    └─────────────────────────────┘
```

## Key Management 🔑

### RSA Key Pairs

- Generate new RSA key pairs (2048-bit)
- Import existing public/private key pairs
- Key validation and secure storage
- Export capabilities for sharing public keys

### ML-KEM (Quantum-Safe) Key Pairs

- Generate ML-KEM-768 key pairs for post-quantum security
- Key encapsulation mechanism for secure key exchange
- Ciphertext generation and shared secret extraction
- Future-proof against quantum computing threats

## Configuration 🔧

### Environment Variables

The application uses environment variables for obfuscation mappings:

```env
# Format: OBF_{LANGUAGE}_{VERSION}_{CHARACTER}=replacement
OBF_EN1_A=word_for_a
OBF_EN1_B=word_for_b
OBF_FA1_ا=persian_word
```

### Supported Languages

- **EN1/EN2**: English character mappings
- **FA1/FA2**: Persian/Farsi character mappings

## Security Considerations 🛡️

1. **Key Management**: Ensure encryption keys are securely stored
2. **Quantum Resistance**: Use ML-KEM for future-proof security against quantum attacks
3. **Environment Variables**: Keep `.env` file secure and never commit to version control
4. **Obfuscation Limits**: Character mapping provides obfuscation, not cryptographic security
5. **Tag Exposure**: Tags may reveal processing methods used
6. **Key Exchange**: ML-KEM provides forward secrecy through ephemeral key exchanges

## Performance 📊

### Compression Algorithms

| Algorithm | Compression Ratio | Speed  | Memory Usage |
|-----------|-------------------|--------|--------------|
| GZip      | High              | Medium | Medium       |
| LZ4       | Medium            | Fast   | Low          |
| Brotli    | Very High         | Slow   | High         |
| Zstd      | High              | Fast   | Medium       |

### Encryption Performance

| Algorithm  | Key Size | Speed  | Quantum Safe | Use Case                  |
|------------|----------|--------|--------------|---------------------------|
| AES-256    | 256-bit  | Fast   | No           | Symmetric encryption      |
| RSA-2048   | 2048-bit | Medium | No           | Asymmetric encryption     |
| ML-KEM-768 | 1184-bit | Fast   | Yes          | Post-quantum key exchange |
