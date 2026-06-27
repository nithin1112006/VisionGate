import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';

Future<void> saveFile(Uint8List bytes, String fileName) async {
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save template...',
      fileName: fileName,
      bytes: bytes,
    );
    if (path == null) {
      // User cancelled or platform returned null. Fallback to share sheet.
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  } catch (e) {
    // Fallback to share sheet on error/unimplemented platform features
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }
}
