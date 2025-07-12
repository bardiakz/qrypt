import 'package:qrypt/models/encryption.dart';

import '../models/Qrypt.dart';
import '../models/encryption.dart';
import '../models/obfuscation.dart';
import 'aes_encryption.dart';
import 'obfuscate.dart';

class InputHandler{
  Qrypt handleEncrypt(Qrypt qrypt){
    String? encryptedText=qrypt.text;
    switch(qrypt.getEncryptionMethod()){
      case EncryptionMethod.aes:
        encryptedText = '${Aes.encryptMessage(qrypt.text)['ciphertext']}:${Aes.encryptMessage(qrypt.text)['iv']!}';
        qrypt.text = encryptedText;
        return qrypt;
      case EncryptionMethod.none:
        return qrypt;
    }
  }
  Qrypt handleObfs(Qrypt qrypt){
    String? obfsText=qrypt.text;
    switch(qrypt.getObfuscationMethod()){
      case ObfuscationMethod.fa1:

        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationFA1Map);
        // print('crypt txt is:${obfsText}');
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.fa2:
        obfsText = Obfuscate.obfuscateText(qrypt.text, obfuscationFA2Map);
        qrypt.text = obfsText;
        return qrypt;
      case ObfuscationMethod.none:
        return qrypt;

    }
  }
  Qrypt handleProcess(Qrypt qrypt){
    qrypt = handleEncrypt(qrypt);
    qrypt = handleObfs(qrypt);
    return qrypt;
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