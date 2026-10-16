import 'dart:typed_data';

import 'excel_download_helper_stub.dart'
    if (dart.library.html) 'excel_download_helper_web.dart' as platform;

/// Downloads an in-memory Excel byte stream to the client device.
/// Seamlessly uses HTML Anchor/Blob download on Web without compile issues.
Future<void> saveAndLaunchExcel(Uint8List bytes, String fileName) async {
  await platform.saveAndLaunchExcelFile(bytes, fileName);
}
