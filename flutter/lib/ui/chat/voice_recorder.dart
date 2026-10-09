import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Voice input records an audio file (AAC/m4a) for Hermes to transcribe
/// server-side — there is no on-device transcription.
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentPath;

  /// Returns the file the recording is being written to, or null when the
  /// recorder could not start (permission denied, device error…).
  Future<String?> start() async {
    try {
      if (!await _recorder.hasPermission()) return null;
      final dir = await getTemporaryDirectory();
      final path = p.join(
          dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );
      _currentPath = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Finishes the recording and returns the file (null when nothing was
  /// captured).
  Future<File?> stop() async {
    try {
      final path = await _recorder.stop();
      _currentPath = null;
      if (path == null) return null;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) return null;
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Discard an in-progress recording (user left the screen).
  Future<void> abort() async {
    try {
      await _recorder.stop();
    } catch (_) {}
    final path = _currentPath;
    _currentPath = null;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }
}
