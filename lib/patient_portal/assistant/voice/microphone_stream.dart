import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

class MicrophoneStream {
  MicrophoneStream({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  Stream<Uint8List>? get audioStream => _audioStream;
  Stream<Amplitude> get amplitudeStream =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 90));

  Stream<Uint8List>? _audioStream;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Stream<Uint8List>> start() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        streamBufferSize: 3200,
      ),
    );
    _audioStream = stream;
    return stream;
  }

  Future<void> stop() async {
    _audioStream = null;
    await _recorder.stop();
  }

  Future<void> cancel() async {
    _audioStream = null;
    await _recorder.cancel();
  }

  Future<void> dispose() => _recorder.dispose();
}
