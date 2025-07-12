import 'package:qrypt/models/encryption.dart';

import '../models/Qrypt.dart';
import '../models/encryption.dart';
import 'aes_encryption.dart';

class InputHandler{
  Qrypt handleEncrypt(Qrypt qrypt){
    String? encryptedText='';
    switch(qrypt.getEncryptionMethod()){
      case EncryptionMethod.aes:
        encryptedText = Aes.encryptMessage(qrypt.text)['ciphertext'];
        qrypt.text = encryptedText!;
        return qrypt;
      case EncryptionMethod.none:
        return qrypt;
      }
  }
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