# Qrypt 🔐

A comprehensive Flutter application for text encryption, compression, and obfuscation with support for multiple algorithms and customizable processing pipelines.

## Features ✨

### 🔒 Encryption Methods
- **AES-CBC**: Advanced Encryption Standard with Cipher Block Chaining
- **AES-CTR**: AES with Counter mode for streaming encryption
- **AES-GCM**: AES with Galois/Counter Mode for authenticated encryption
- **None**: Base64 encoding without encryption

### 🗜️ Compression Algorithms
- **GZip**: Industry-standard compression
- **LZ4**: High-speed compression/decompression
- **Brotli**: Modern compression with excellent ratios
- **Zstd**: Facebook's high-performance compression
- **None**: No compression applied

### 🎭 Obfuscation Techniques
- **Character Mapping**: Custom language-specific character substitution
  - English variants (EN1, EN2)
  - Persian/Farsi variants (FA1, FA2)
- **Base64**: Simple encoding obfuscation
- **ROT13**: Classical letter substitution cipher
- **XOR**: Bitwise XOR with configurable key
- **Reverse**: String reversal obfuscation
- **None**: No obfuscation applied

### 🏷️ Smart Tagging System
- Automatic method detection from embedded tags
- Seamless encoding/decoding without manual configuration
- Compact tag format for efficient storage

## Installation 🚀

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Setup
1. Clone the repository:
```bash
git clone https://github.com/yourusername/qrypt.git
cd qrypt
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure environment variables:
Create a `.env` file in the root directory with your obfuscation mappings:
```env
# English obfuscation mappings
OBF_EN1_A=alpha
OBF_EN1_B=beta
OBF_EN1_C=gamma
# ... add more mappings

# Persian obfuscation mappings
OBF_FA1_ا=alef
OBF_FA1_ب=beh
# ... add more mappings
```

4. Run the application:
```bash
flutter run
```

## Usage 📱

### Basic Text Processing

```dart
import 'package:qrypt/services/input_handler.dart';
import 'package:qrypt/models/Qrypt.dart';

// Create a Qrypt instance
Qrypt qrypt = Qrypt(
  text: "Hello, World!",
  encryption: EncryptionMethod.aesGcm,
  compression: CompressionMethod.gZip,
  obfuscation: ObfuscationMethod.en1,
);

// Process the text
InputHandler handler = InputHandler();
Qrypt processed = handler.handleProcess(qrypt);
print("Processed: ${processed.text}");

// Reverse the process
Qrypt restored = handler.handleDeProcess(processed, true);
print("Restored: ${restored.text}");
```

### Advanced Configuration

```dart
// Custom processing pipeline
Qrypt qrypt = Qrypt(text: "Sensitive data");

// Apply compression first
qrypt.compression = CompressionMethod.zstd;
qrypt = handler.handleCompression(qrypt);

// Then encryption
qrypt.encryption = EncryptionMethod.aesCbc;
qrypt = handler.handleEncrypt(qrypt);

// Finally obfuscation
qrypt.obfuscation = ObfuscationMethod.xor;
qrypt = handler.handleObfs(qrypt);
```

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

### Core Components

- **InputHandler**: Main orchestrator for all processing operations
- **Qrypt Model**: Data structure holding text and method configurations
- **Compression Service**: Handles all compression algorithms
- **AES Encryption**: Implements various AES encryption modes
- **Obfuscation Service**: Manages character mapping and other obfuscation techniques
- **Tag Manager**: Handles automatic method detection and tag generation

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

## Contributing 🤝

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines
- Follow Dart coding conventions
- Add tests for new features
- Update documentation for API changes
- Ensure backward compatibility

## Testing 🧪

Run the test suite:
```bash
flutter test
```

Run with coverage:
```bash
flutter test --coverage
```

## Performance 📊

| Algorithm | Compression Ratio | Speed | Memory Usage |
|-----------|-------------------|-------|--------------|
| GZip      | High              | Medium| Medium       |
| LZ4       | Medium            | Fast  | Low          |
| Brotli    | Very High         | Slow  | High         |
| Zstd      | High              | Fast  | Medium       |

## License 📄

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support 💬

- 📧 Email: support@qrypt.dev
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/qrypt/issues)
- 📖 Documentation: [Wiki](https://github.com/yourusername/qrypt/wiki)

## Acknowledgments 🙏

- Flutter team for the excellent framework
- Dart ecosystem contributors
- Cryptography and compression algorithm researchers
- Open source community

---

**⚠️ Disclaimer**: This tool is for educational and legitimate use cases only. Users are responsible for compliance with local laws and regulations regarding encryption and data protection.
