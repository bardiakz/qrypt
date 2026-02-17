import 'dart:convert';
import 'package:obfuscate/obfuscate.dart' as obfs;
import 'package:flutter/cupertino.dart';
import 'package:qrypt/models/obfuscation_method.dart';
import 'package:qrypt/resources/obfuscation/built_in_obfuscation_maps.dart';
import 'package:qrypt/services/obfuscation/obfuscation_map_repository.dart';

Map<String, String> obfuscationFA2Map = Map<String, String>.from(builtInFa2Map);
Map<String, String> obfuscationFA1Map = Map<String, String>.from(builtInFa1Map);
Map<String, String> obfuscationEN2Map = Map<String, String>.from(builtInEn2Map);
Map<String, String> obfuscationEN1Map = Map<String, String>.from(builtInEn1Map);

class Obfuscate {
  static final ObfuscationMapRepository _repository =
      ObfuscationMapRepository.instance;

  static void _setObfuscationFA2Map() {
    obfuscationFA2Map = _repository.getMap(ObfuscationMethod.fa2);
    if (obfuscationFA2Map.isEmpty) {
      debugPrint('Warning: FA2 map is empty; obfuscation will be no-op.');
    }
  }

  static void _setObfuscationFA1Map() {
    obfuscationFA1Map = _repository.getMap(ObfuscationMethod.fa1);
    if (obfuscationFA1Map.isEmpty) {
      debugPrint('Warning: FA1 map is empty; obfuscation will be no-op.');
    }
  }

  static void _setObfuscationEN2Map() {
    obfuscationEN2Map = _repository.getMap(ObfuscationMethod.en2);
    if (obfuscationEN2Map.isEmpty) {
      debugPrint('Warning: EN2 map is empty; obfuscation will be no-op.');
    }
  }

  static void _setObfuscationEN1Map() {
    obfuscationEN1Map = _repository.getMap(ObfuscationMethod.en1);
    if (obfuscationEN1Map.isEmpty) {
      debugPrint('Warning: EN1 map is empty; obfuscation will be no-op.');
    }
  }

  static Future<void> setAllMaps() async {
    await _repository.initialize();
    _setObfuscationFA1Map();
    _setObfuscationFA2Map();
    _setObfuscationEN1Map();
    _setObfuscationEN2Map();
  }

  static Future<void> setCustomMap(
    ObfuscationMethod method,
    Map<String, String> map,
  ) async {
    await _repository.setCustomMap(method, map);
    await setAllMaps();
  }

  static Future<void> clearCustomMap(ObfuscationMethod method) async {
    await _repository.clearCustomMap(method);
    await setAllMaps();
  }

  static Map<String, String> getMapForMethod(ObfuscationMethod method) {
    return _repository.getMap(method);
  }

  static String obfuscateText(
    String text,
    Map<String, String> obfuscationMap, {
    bool preserveUnmapped = false,
    bool preserveCase = false,
  }) {
    return obfs.Obfuscate.obfuscateWithMap(text, obfuscationMap);
  }

  static String deobfuscateText(
    String text,
    Map<String, String> obfuscationMap,
  ) {
    return obfs.Obfuscate.deobfuscateWithMap(text, obfuscationMap);
  }

  // Base64 obfuscation
  static String obfuscateBase64(String text) {
    final bytes = utf8.encode(text);
    return base64.encode(bytes);
  }

  static String deobfuscateBase64(String encodedText) {
    try {
      final bytes = base64.decode(encodedText);
      return utf8.decode(bytes);
    } catch (e) {
      return encodedText; // Return original if decoding fails
    }
  }

  // ROT13 obfuscation
  static String obfuscateROT13(String text) {
    return obfs.Obfuscate.obfuscateROT13(text);
  }

  static String deobfuscateROT13(String text) {
    return obfuscateROT13(text);
  }

  //XOR obfuscation with key
  static String obfuscateXOR(String text, int key) {
    return obfs.Obfuscate.obfuscateXOR(text, key);
  }

  static String deobfuscateXOR(String text, int key) {
    return obfuscateXOR(text, key);
  }

  // Reverse string obfuscation
  static String obfuscateReverse(String text) {
    return obfs.Obfuscate.obfuscateReverse(text);
  }

  static String deobfuscateReverse(String text) {
    return obfuscateReverse(text);
  }
}
