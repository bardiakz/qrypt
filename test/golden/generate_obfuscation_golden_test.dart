// RUN THIS ON THE CURRENT (OLD obfuscate package) BRANCH, BEFORE UPGRADING:
//
//   GENERATE_GOLDEN=1 flutter test test/golden/generate_obfuscation_golden_test.dart
//   (PowerShell: $env:GENERATE_GOLDEN=1; flutter test ...)
//
// It records what today's app produces and commit the resulting
// test/fixtures/obfuscation_golden.json. The compatibility test then proves
// the migrated code reproduces it byte for byte. Do not regenerate after the
// upgrade: that would make the test compare the new code with itself.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrypt/services/obfuscate.dart';
import 'package:qrypt/services/tag_manager.dart';

import 'golden_inputs.dart';

void main() {
  // Opt-in on purpose: re-running this after the upgrade would overwrite the
  // fixture with the NEW code's output and make the compatibility test
  // compare the new code with itself.
  final enabled = Platform.environment['GENERATE_GOLDEN'] == '1';
  test('generate golden fixture from the OLD implementation',
      skip: enabled ? false : 'set GENERATE_GOLDEN=1 (OLD package only)', () {
    final inputs = goldenInputs();

    // name -> (encode, decode). Global maps default to the built-in maps.
    final methods = <String, (String Function(String), String Function(String))>{
      'en1': (
        (s) => Obfuscate.obfuscateText(s, obfuscationEN1Map),
        (s) => Obfuscate.deobfuscateText(s, obfuscationEN1Map),
      ),
      'en2': (
        (s) => Obfuscate.obfuscateText(s, obfuscationEN2Map),
        (s) => Obfuscate.deobfuscateText(s, obfuscationEN2Map),
      ),
      'fa1': (
        (s) => Obfuscate.obfuscateText(s, obfuscationFA1Map),
        (s) => Obfuscate.deobfuscateText(s, obfuscationFA1Map),
      ),
      'fa2': (
        (s) => Obfuscate.obfuscateText(s, obfuscationFA2Map),
        (s) => Obfuscate.deobfuscateText(s, obfuscationFA2Map),
      ),
      'b64': (Obfuscate.obfuscateBase64, Obfuscate.deobfuscateBase64),
      'rot13': (Obfuscate.obfuscateROT13, Obfuscate.deobfuscateROT13),
    };

    final outputs = <String, Map<String, List<String>>>{};
    methods.forEach((name, fns) {
      final encoded = [for (final s in inputs) fns.$1(s)];
      outputs[name] = {
        'encoded': encoded,
        'roundTrip': [for (final e in encoded) fns.$2(e)],
      };
    });

    TagManager.initializeTags();
    final tags = <String, Map<String, String>>{};
    for (final tag in TagManager.knownTags) {
      final m = TagManager.getMethodsFromTag(tag)!;
      tags[tag] = {
        'compression': m.compression.name,
        'encryption': m.encryption.name,
        'sign': m.sign.name,
        'obfuscation': m.obfuscation.name,
      };
    }

    final file = File('test/fixtures/obfuscation_golden.json')
      ..createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        'inputs': inputs,
        'outputs': outputs,
        'tags': tags,
      }),
    );
    // ignore: avoid_print
    print('Wrote ${tags.length} tags and ${methods.length} methods.');
  });
}
