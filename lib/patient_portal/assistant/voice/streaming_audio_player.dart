import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

class StreamingAudioPlayer {
  StreamingAudioPlayer({SoLoud? engine}) : _engine = engine ?? SoLoud.instance;

  final SoLoud _engine;
  AudioSource? _source;
  SoundHandle? _handle;
  final List<Uint8List> _pendingChunks = <Uint8List>[];

  bool get isPlaying => _handle != null;

  Future<void> initialize() async {
    if (_engine.isInitialized) return;
    await _engine.init(
      sampleRate: 24000,
      bufferSize: 1024,
      channels: Channels.mono,
    );
  }

  Future<void> start() async {
    await initialize();
    await stop();
    _source = _engine.setBufferStream(
      bufferingType: BufferingType.released,
      bufferingTimeNeeds: 0.12,
      maxBufferSizeDuration: const Duration(seconds: 20),
      sampleRate: 24000,
      channels: Channels.mono,
      format: BufferType.s16le,
    );
    _handle = await _engine.play(_source!);
    final source = _source!;
    for (final chunk in _pendingChunks) {
      _engine.addAudioDataStream(source, chunk);
    }
    _pendingChunks.clear();
  }

  void add(Uint8List pcm16) {
    if (pcm16.isEmpty) return;
    final source = _source;
    if (source == null) {
      _pendingChunks.add(pcm16);
      return;
    }
    _engine.addAudioDataStream(source, pcm16);
  }

  Future<void> finish() async {
    final source = _source;
    if (source == null) return;
    _engine.setDataIsEnded(source);
  }

  Future<void> stop() async {
    final handle = _handle;
    if (handle != null) {
      _engine.stop(handle);
    }
    final source = _source;
    if (source != null) {
      _engine.disposeSource(source);
    }
    _handle = null;
    _source = null;
    _pendingChunks.clear();
  }

  Future<void> dispose() async {
    stop();
    if (_engine.isInitialized) {
      _engine.deinit();
    }
  }
}
