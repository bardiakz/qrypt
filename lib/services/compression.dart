export 'compression_io.dart'
    if (dart.library.html) 'compression_web.dart'
    if (dart.library.js_interop) 'compression_web.dart';
