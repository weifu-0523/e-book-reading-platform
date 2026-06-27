import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhiyue/features/notes/services/note_file_writer.dart';

/// Fake [FilePicker] that returns a pre-configured directory path (or null to
/// simulate user cancel). Set via [FilePicker.platform] in tests.
class _FakeFilePicker extends FilePicker {
  _FakeFilePicker(this._directoryPath);

  final String? _directoryPath;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async =>
      _directoryPath;

  // Unused in tests; provide no-op stubs.
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async =>
      null;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async =>
      null;

  @override
  Future<bool?> clearTemporaryFiles() async => false;
}

void main() {
  group('NoteFileWriter.sanitizeForFilename', () {
    test('replaces forbidden characters with underscore', () {
      expect(NoteFileWriter.sanitizeForFilename(r'a\b/c:d*e?f"g<h>i|j'),
          'a_b_c_d_e_f_g_h_i_j');
    });

    test('trims and collapses whitespace', () {
      expect(NoteFileWriter.sanitizeForFilename('  hello   world  '),
          'hello world');
    });

    test('truncates to 80 chars', () {
      final long = 'a' * 200;
      final result = NoteFileWriter.sanitizeForFilename(long);
      expect(result.length, 80);
    });
  });

  group('NoteFileWriter.saveMarkdownFile', () {
    late FilePicker _previousPlatform;
    late Directory tmpDir;

    setUp(() async {
      // file_picker's _instance is `late`; on first access it is whatever the
      // previous test (or framework) set. Capture it so we can restore.
      try {
        _previousPlatform = FilePicker.platform;
      } catch (_) {
        // _instance was never initialized in this isolate; we'll just leave
        // the fake installed. The `late` setter accepts any value.
        _previousPlatform = _FakeFilePicker(null);
      }
      tmpDir = await Directory.systemTemp.createTemp('m3.4_t5_test_');
    });

    tearDown(() async {
      FilePicker.platform = _previousPlatform;
      if (await tmpDir.exists()) {
        await tmpDir.delete(recursive: true);
      }
    });

    test('returns written path on success', () async {
      FilePicker.platform = _FakeFilePicker(tmpDir.path);
      final path = await NoteFileWriter.saveMarkdownFile(
        content: '# hi',
        suggestedName: 'test',
      );
      expect(path, isNotNull);
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), '# hi');
    });

    test('appends (1) suffix on collision', () async {
      FilePicker.platform = _FakeFilePicker(tmpDir.path);
      // Pre-create the base file to force collision.
      await File('${tmpDir.path}${Platform.pathSeparator}test.md')
          .writeAsString('existing');

      final path = await NoteFileWriter.saveMarkdownFile(
        content: '# new',
        suggestedName: 'test',
      );
      expect(path, isNotNull);
      expect(path, endsWith('test (1).md'));
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.readAsString(), '# new');
      // Original untouched.
      expect(
        await File('${tmpDir.path}${Platform.pathSeparator}test.md')
            .readAsString(),
        'existing',
      );
    });

    test('returns null when user cancels', () async {
      FilePicker.platform = _FakeFilePicker(null);
      final path = await NoteFileWriter.saveMarkdownFile(
        content: '# hi',
        suggestedName: 'test',
      );
      expect(path, isNull);
    });
  });
}
