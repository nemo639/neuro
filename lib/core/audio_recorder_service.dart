import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Shared audio recording service for all speech tests.
/// Records WAV files to temporary storage for upload to backend.
class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentFilePath;
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get currentFilePath => _currentFilePath;

  /// Request microphone permission. Returns true if granted.
  static Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;

    // On some devices, check if already granted
    if (await Permission.microphone.isGranted) return true;

    debugPrint('Microphone permission denied: $status');
    return false;
  }

  /// Check if microphone permission is granted.
  static Future<bool> hasPermission() async {
    return await Permission.microphone.isGranted;
  }

  /// Start recording audio to a WAV file.
  /// [fileName] is the base name without extension (e.g., 'story_recall_1234').
  Future<bool> startRecording(String fileName) async {
    try {
      final hasPerms = await requestPermission();
      if (!hasPerms) {
        debugPrint('Cannot record: microphone permission not granted');
        return false;
      }

      final dir = await getTemporaryDirectory();
      _currentFilePath = '${dir.path}/$fileName.wav';

      // Configure for WAV format at 16kHz mono (optimal for speech analysis)
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      );

      await _recorder.start(config, path: _currentFilePath!);
      _isRecording = true;
      debugPrint('Recording started: $_currentFilePath');
      return true;
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the file path of the recorded audio.
  /// Returns null if recording failed or was not started.
  Future<String?> stopRecording() async {
    if (!_isRecording) return _currentFilePath;

    try {
      final path = await _recorder.stop();
      _isRecording = false;
      debugPrint('Recording stopped: $path');

      // Verify file exists and has content
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint('Recorded file size: $size bytes');
          if (size > 0) {
            _currentFilePath = path;
            return path;
          }
        }
      }

      debugPrint('Recording file invalid or empty');
      return null;
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Cancel and discard the current recording.
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }

    // Delete the file if it exists
    if (_currentFilePath != null) {
      final file = File(_currentFilePath!);
      if (await file.exists()) {
        await file.delete();
      }
      _currentFilePath = null;
    }
  }

  /// Clean up resources.
  void dispose() {
    _recorder.dispose();
  }
}
