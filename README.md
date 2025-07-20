# Qrypt 🔐

**⚠️ Disclaimer**: This tool is for educational and legitimate use cases only. Users are responsible
for compliance with local laws and regulations regarding encryption and data protection.

A comprehensive Flutter application for text encryption, compression, and obfuscation with support
for multiple algorithms and customizable processing pipelines.

## Features ✨

### 🔒 Encryption Methods

- **AES-CBC**: Advanced Encryption Standard with Cipher Block Chaining
- **AES-CTR**: AES with Counter mode for streaming encryption
- **AES-GCM**: AES with Galois/Counter Mode for authenticated encryption
- **RSA**: RSA encryption with public-key with built in key-pair generation
- **None**: Base64 encoding without encryption
- Planned support for PQC algorithms using liboqs for quantum-safe encryption

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
```

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
2. **Environment Variables**: Keep `.env` file secure and never commit to version control
3. **Obfuscation Limits**: Character mapping provides obfuscation, not cryptographic security
4. **Tag Exposure**: Tags may reveal processing methods used

## Performance 📊

| Algorithm | Compression Ratio | Speed  | Memory Usage |
|-----------|-------------------|--------|--------------|
| GZip      | High              | Medium | Medium       |
| LZ4       | Medium            | Fast   | Low          |
| Brotli    | Very High         | Slow   | High         |
| Zstd      | High              | Fast   | Medium       |

---

