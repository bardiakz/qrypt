# Qrypt 🔐

**⚠️ Disclaimer**: This tool is for educational and legitimate use cases only. Users are responsible for compliance with local laws and regulations regarding encryption and data protection.

A comprehensive Flutter application for text encryption, compression, obfuscation, and digital signing with support for multiple algorithms, customizable processing pipelines, and quantum-safe cryptography.

## Features ✨

### 🔒 Encryption Methods

- **AES-CBC**: Advanced Encryption Standard with Cipher Block Chaining
- **AES-CTR**: AES with Counter mode for streaming encryption
- **AES-GCM**: AES with Galois/Counter Mode for authenticated encryption
- **RSA**: RSA encryption with public-key cryptography and built-in key pair generation
- **RSA+Sign**: RSA encryption combined with RSA digital signatures for authenticated encryption
- **ML-KEM (Kyber)**: Post-quantum key encapsulation mechanism for quantum-safe key exchange
- **None**: Base64 encoding without encryption

### 🛡️ Quantum-Safe Cryptography

#### ML-KEM (Key Encapsulation Mechanism)
- **ML-KEM-768**: NIST-standardized Module-Lattice-Based Key Encapsulation Mechanism
- Key exchange resistant to quantum computer attacks
- Built-in key pair generation and management
- Ciphertext encapsulation and shared secret extraction

#### ML-DSA (Digital Signature Algorithm)
- **ML-DSA**: Post-quantum digital signature algorithm based on lattice cryptography
- Quantum-resistant message signing and verification
- Integrated key pair management with secure key storage
- Compatible with all encryption methods for authenticated encryption

### 🗜️ Compression Algorithms

- **GZip**: Industry-standard compression with good balance of size and speed
- **LZ4**: High-speed compression/decompression for performance-critical applications
- **Brotli**: Modern compression with excellent ratios for web applications
- **Zstd**: Facebook's high-performance compression with tunable compression levels

### 🎭 Obfuscation Techniques

- **Character Mapping**: Custom language-specific character substitution
  - English variants (EN1, EN2)
  - Persian/Farsi variants (FA1, FA2)
- **Base64**: Simple encoding obfuscation
- **ROT13**: Classical letter substitution cipher
- **XOR**: Bitwise XOR with configurable key
- **None**: No obfuscation applied

### 🏷️ Smart Tagging System

- Automatic method detection from embedded tags
- Seamless encoding/decoding without manual configuration
- Compact tag format for efficient storage and transmission
- Version-aware tag parsing for backward compatibility

## Architecture 🏗️

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Input Text    │ -> │  Compression    │ -> │   Encryption    │ <-- Optional: ML-KEM shared secret 
└─────────────────┘    └─────────────────┘    └─────────────────┘               as encryption key
                                                        │
┌─────────────────┐    ┌─────────────────┐              │
│  Final Output   │ <- │  Obfuscation    │ <-           │
└─────────────────┘    └─────────────────┘              │
                              ^                         │
                              └─── Tag Addition ←───────┘


    ┌─────────────────────────────────────────────────────┐
    │                Quantum-Safe Layer                   │
    │                                                     │
    │  ML-KEM Key Exchange        ML-DSA Digital Signing  │
    │  ┌─────────┐  ┌─────────┐   ┌─────────┐  ┌────────┐ │
    │  │ Public  │  │ Secret  │   │ Private │  │ Public │ │
    │  │   Key   │  │   Key   │   │   Key   │  │   Key  │ │
    │  └─────────┘  └─────────┘   └─────────┘  └────────┘ │
    │       │           │              │           │      │
    │       ▼           ▼              ▼           ▼      │
    │  ┌─────────────────────┐   ┌─────────────────────┐  │ 
    │  │   Shared Secret     │   │   Digital Signature │  │
    │  └─────────────────────┘   └─────────────────────┘  │
    └─────────────────────────────────────────────────────┘
```

## Key Management 🔑

### RSA Key Pairs
- Generate new RSA key pairs (2048-bit) with secure random number generation
- Import existing PEM-formatted public/private key pairs
- Key validation with format verification and cryptographic checks
- Export capabilities for sharing public keys securely
- Support for both encryption/decryption and signing/verification operations

### ML-KEM (Quantum-Safe Key Exchange)
- Generate ML-KEM-768 key pairs for post-quantum security
- Key encapsulation mechanism for secure key exchange
- Ciphertext generation and shared secret extraction
- Future-proof against quantum computing threats
- Compatible with classical encryption for hybrid security

### ML-DSA (Quantum-Safe Digital Signatures)
- Generate ML-DSA key pairs for post-quantum digital signatures
- Message signing with private keys
- Signature verification with public keys
- Integrated with all encryption methods for authenticated communication
- Tamper-evident messaging with cryptographic proof of authenticity

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

### Encryption Security
1. **Key Management**: All encryption keys are securely stored using platform-specific secure storage
2. **Quantum Resistance**: Use ML-KEM and ML-DSA for future-proof security against quantum attacks
3. **Hybrid Security**: Combine classical and post-quantum algorithms for maximum security
4. **Key Rotation**: Regularly generate new key pairs for forward secrecy

### Authentication & Integrity
1. **Digital Signatures**: ML-DSA provides quantum-resistant authentication
2. **Message Integrity**: Cryptographic signatures detect tampering
3. **Key Verification**: Public key fingerprints ensure key authenticity
4. **Signature Verification**: Automatic verification with clear success/failure indicators

### Implementation Security
1. **Environment Variables**: Keep `.env` file secure and never commit to version control
2. **Obfuscation Limits**: Character mapping provides obfuscation, not cryptographic security
3. **Tag Security**: Tags may reveal processing methods but not keys or content
4. **Memory Security**: Sensitive data cleared from memory after use

## Usage Examples 📝

### Basic Encryption
1. Enter your text in the input field
2. Select compression method (optional)
3. Choose encryption method (AES recommended for symmetric, RSA for asymmetric)
4. Select obfuscation method if needed
5. Process and copy the encrypted output

### Quantum-Safe Communication (advanced)
1. Generate ML-KEM key pairs for both parties
2. Use ML-KEM for creating shared secret
3. Sign KEM ciphertext with ML-DSA key
4. Share the secret with the receiver
5. Combine shared secret with classical encryption for hybrid security

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
