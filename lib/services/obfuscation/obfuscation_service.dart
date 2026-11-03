import 'package:flutter/foundation.dart';
// The package's interface is also called ObfuscationMethod, so it MUST be
// imported with a prefix to avoid clashing with Qrypt's enum of that name.
import 'package:obfuscate/obfuscate.dart' as obfs;
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/resources/obfuscation/built_in_v2_maps.dart';
import 'package:qrypt/resources/obfuscation/v2_map_pools.dart';
import 'package:qrypt/services/obfuscation/obfuscation_map_repository.dart';

/// Helpers over Qrypt's [ObfuscationMethod] enum.
///
/// Requires four NEW enum values (see MIGRATION.md): en1v2, en2v2, fa1v2,
/// fa2v2. Never rename existing values: `.name` feeds the tag HMAC.
extension ObfuscationMethodX on ObfuscationMethod {
  /// Old per-character, space-delimited, case-insensitive map formats.
  /// Kept ONLY so old messages still decode.
  bool get isLegacyMapped => switch (this) {
    ObfuscationMethod.en1 ||
    ObfuscationMethod.en2 ||
    ObfuscationMethod.fa1 ||
    ObfuscationMethod.fa2 => true,
    _ => false,
  };

  /// New strict formats: the payload alphabet is the 16 hex digits plus the
  /// ':' separator (AES layout `ciphertext:iv` is unchanged), mapped through a
  /// validated 17-entry map. Anything else is rejected on decode.
  bool get isV2Mapped => switch (this) {
    ObfuscationMethod.en1v2 ||
    ObfuscationMethod.en2v2 ||
    ObfuscationMethod.fa1v2 ||
    ObfuscationMethod.fa2v2 => true,
    _ => false,
  };

  /// Replaces the four copy-pasted `usesMappedObfuscation` lists:
  /// the payload handed to obfuscation is hex (plus ':' for AES).
  bool get isHexMapped => isLegacyMapped || isV2Mapped;
}

typedef _Fn = String Function(String);
typedef _Codec = ({_Fn encode, _Fn decode});

/// Single entry point for every obfuscation operation in Qrypt.
///
/// Call [rebuild] (or [initialize]) after the map repository loads and after
/// any custom-map change, THEN `TagManager.initializeTags()`: tags are
/// themselves obfuscated, so they depend on the maps.
class ObfuscationService {
  ObfuscationService._();

  static final ObfuscationMapRepository _repo =
      ObfuscationMapRepository.instance;

  static final Map<ObfuscationMethod, _Codec> _codecs = {};
  static final Map<ObfuscationMethod, String> _unavailable = {};
  static bool _ready = false;

  /// Single-byte XOR key (unchanged from before).
  static const int xorKey = 42;

  static final RegExp _ws = RegExp(r'\s+');

  /// The separator character every v2 payload may contain (AES `ct:iv`).
  static const String separatorKey = ':';

  /// Default for the "Default Preset". Falls back to legacy EN2 if the v2 map
  /// is invalid, so the preset never becomes unusable.
  static ObfuscationMethod get defaultMethod =>
      isAvailable(ObfuscationMethod.en2v2)
      ? ObfuscationMethod.en2v2
      : ObfuscationMethod.en2;

  static Future<void> initialize() async {
    await _repo.initialize();
    rebuild();
  }

  static void rebuild() {
    rebuildWith({
      for (final m in ObfuscationMethod.values)
        if (m.isHexMapped) m: _mapFor(m),
    });
  }

  /// Repository first (so custom maps work), then the generated built-ins.
  static Map<String, String> _mapFor(ObfuscationMethod m) {
    final fromRepo = _repo.getMap(m);
    if (fromRepo.isNotEmpty || !m.isV2Mapped) return fromRepo;
    return builtInV2MapForMethod(m);
  }

  /// Test hook: build from explicit maps (legacy and v2), no repository.
  @visibleForTesting
  static void rebuildWith(Map<ObfuscationMethod, Map<String, String>> maps) {
    _codecs.clear();
    _unavailable.clear();

    _codecs[ObfuscationMethod.none] = (encode: (s) => s, decode: (s) => s);

    // Identical output to the old implementations on valid input.
    // Base64 now THROWS on invalid input instead of silently returning it.
    const rot13 = obfs.Rot13Codec();
    const b64 = obfs.Base64ObfuscationCodec();
    _codecs[ObfuscationMethod.rot13] = (
      encode: rot13.obfuscate,
      decode: rot13.deobfuscate,
    );
    _codecs[ObfuscationMethod.b64] = (
      encode: b64.obfuscate,
      decode: b64.deobfuscate,
    );

    // XOR: byte-safe base64 wire format. Messages made with the OLD raw
    // code-unit XOR are deliberately NOT supported: they still match their
    // tag but fail with DecodingException rather than decoding wrongly.
    final xor = obfs.XorCodec(xorKey);
    _codecs[ObfuscationMethod.xor] = (
      encode: xor.obfuscate,
      decode: xor.deobfuscate,
    );

    // Legacy maps: the frozen codec, so old messages decode byte-for-byte.
    for (final m in ObfuscationMethod.values.where((m) => m.isLegacyMapped)) {
      final map = Map<String, String>.unmodifiable(maps[m] ?? const {});
      _codecs[m] = (
        encode: (s) => obfs.LegacyMapCodec.obfuscate(s, map),
        decode: (s) => obfs.LegacyMapCodec.deobfuscate(s, map),
      );
    }

    // v2: strict, validated. A bad map disables that method (with a reason)
    // instead of crashing the app or producing undecodable messages.
    for (final m in ObfuscationMethod.values.where((m) => m.isV2Mapped)) {
      try {
        _codecs[m] = _buildV2(maps[m] ?? const {});
      } on obfs.ObfuscationException catch (e) {
        _unavailable[m] = e.message;
        debugPrint('Obfuscation method ${m.name} unavailable:\n${e.message}');
      }
    }
    _ready = true;
  }

  static const List<String> _v2Domain = [
    ...obfs.NibbleCodec.hexAlphabet,
    separatorKey,
  ];

  /// Runes of every vetted letter. Dart has no Unicode normalisation, so a v2
  /// map may only use characters the generator tool already proved safe.
  static final Set<int> _safeRunes = {
    for (final pool in kV2CharPools.values)
      for (final c in pool) c.runes.first,
  };

  static bool _isSingleChar(Map<String, String> map) {
    final hexValues = [
      for (final d in obfs.NibbleCodec.hexAlphabet)
        if (map[d] != null) map[d]!,
    ];
    return hexValues.isNotEmpty && hexValues.every((v) => v.runes.length == 1);
  }

  /// Every rule a v2 map must satisfy; empty list = valid. Used for built-in,
  /// custom and randomly generated maps alike (never save a map that fails).
  static List<String> validateV2Map(Map<String, String> map) {
    final singleChar = _isSingleChar(map);
    final result = obfs.validateMap(
      map,
      kind: singleChar ? obfs.MapKind.substitution : obfs.MapKind.token,
      requiredDomain: _v2Domain,
    );
    final problems = <String>[
      ...result.errors,
      // Combining/zero-width values can be silently reordered or dropped by
      // Unicode normalisation in clipboards and messengers => data
      // corruption with no exception. Fatal for v2, not a warning.
      ...result.warnings.map((w) => '(fatal for v2) $w'),
      // Exactly the 17 symbols: extra keys would let strict decoding accept
      // characters that are not valid hex/separator.
      for (final k in map.keys)
        if (!_v2Domain.contains(k))
          'Unexpected key "$k" (v2 maps have exactly the 16 hex digits and ":").',
    ];
    for (final e in map.entries) {
      final v = e.value;
      if (_ws.hasMatch(v)) {
        problems.add('Value for "${e.key}" contains whitespace.');
      }
      if (v != v.toLowerCase()) {
        problems.add('Value for "${e.key}" must already be lowercase.');
      }
      if (singleChar && v.runes.length != 1) {
        problems.add('Value for "${e.key}" must be a single character.');
      }
      for (final r in v.runes) {
        if (!_safeRunes.contains(r)) {
          problems.add(
            'Value for "${e.key}" contains U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}, '
            'which is not in the vetted letter pools (it could be altered by '
            'Unicode normalisation or app text handling).',
          );
        }
      }
    }
    if (!singleChar) {
      // If one word were a prefix of another, tag startsWith() matching and
      // partial pastes would be ambiguous.
      for (final a in map.entries) {
        for (final b in map.entries) {
          if (a.key != b.key && b.value.startsWith(a.value)) {
            problems.add(
              'Not prefix-free: "${a.value}" (${a.key}) is a prefix of '
              '"${b.value}" (${b.key}).',
            );
          }
        }
      }
    }
    return problems;
  }

  static _Codec _buildV2(Map<String, String> map) {
    final problems = validateV2Map(map);
    if (problems.isNotEmpty) {
      throw obfs.InvalidMapException(problems.join('\n'));
    }
    final singleChar = _isSingleChar(map);

    final obfs.ObfuscationMethod codec = singleChar
        ? obfs.SubstitutionCodec(map, strict: true)
        : obfs.TokenSubstitutionCodec(map);

    // Input hygiene before decoding. After the tag is stripped, token
    // output starts with a delimiter, hence trim().
    final _Fn prep = singleChar
        ? (s) => s.replaceAll(_ws, '').toLowerCase()
        : (s) => s.trim().replaceAll(_ws, ' ').toLowerCase();

    return (
      encode: codec.obfuscate,
      decode: (s) => codec.deobfuscate(prep(s)),
    );
  }

  // ---- public API ----

  static String obfuscate(ObfuscationMethod method, String text) =>
      _codec(method).encode(text);

  static String deobfuscate(ObfuscationMethod method, String text) =>
      _codec(method).decode(text);

  static bool isAvailable(ObfuscationMethod method) =>
      _codecs.containsKey(method);

  static String? unavailableReason(ObfuscationMethod method) =>
      _unavailable[method];

  /// For the ENCRYPT dropdown: never offer legacy formats for new messages.
  static List<ObfuscationMethod> get selectableForEncrypt => [
    for (final m in ObfuscationMethod.values)
      if (isAvailable(m) && !m.isLegacyMapped) m,
  ];

  /// For the DECRYPT dropdown (manual mode): everything that can decode.
  static List<ObfuscationMethod> get selectableForDecrypt => [
    for (final m in ObfuscationMethod.values)
      if (isAvailable(m)) m,
  ];

  static _Codec _codec(ObfuscationMethod method) {
    if (!_ready) {
      throw StateError(
        'ObfuscationService not initialised: call initialize()/rebuild() '
        'before obfuscating.',
      );
    }
    final c = _codecs[method];
    if (c == null) {
      throw obfs.InvalidMapException(
        'Obfuscation method "${method.name}" is unavailable: '
        '${_unavailable[method] ?? 'no codec registered'}',
      );
    }
    return c;
  }
}
