import '../models/encryption.dart';
import '../models/obfuscation.dart';

class InputHandler{

}

class Qrypt{
  String text="";
  late final EncryptionMethod encryption;
  late final ObfuscationMethod obfuscation;
  bool useTag=false;
  String? tag;
  Qrypt.withTag({required this.text,required this.encryption,required this.obfuscation,this.tag}){
    useTag=true;
  }
  Qrypt({required this.text,required this.encryption,required this.obfuscation});
}
// class DeQrypt{
//   String text="";
//   late final EncryptionMethod encryption;
//   late final ObfuscationMethod obfuscation;
//   bool useTag=false;
//   String? tag;
//   DeQrypt.withTag({required this.text,required this.encryption,required this.obfuscation,this.tag}){
//     useTag=true;
//   }
//   DeQrypt({required this.text,required this.encryption,required this.obfuscation});
// }