import 'encryption.dart';
import 'obfuscation.dart';

class Qrypt{
  String text="";
  late final EncryptionMethod encryption;
  late final ObfuscationMethod obfuscation;
  bool useTag=false;
  String? tag;
  Qrypt.withTag({required this.text,required this.encryption,required this.obfuscation,required this.useTag});
  Qrypt({required this.text,required this.encryption,required this.obfuscation});
}