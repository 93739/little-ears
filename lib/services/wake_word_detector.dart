import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

abstract interface class WakeWordDetector {
  Future<void> start({
    required void Function() onWake,
    required void Function(String) onError,
  });
  Future<void> stop();
  Future<void> dispose();
}

class WakeWordException implements Exception {
  const WakeWordException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Records PCM only while explicitly enabled. Samples stay in memory and are
/// decoded locally in an isolate; no microphone audio is saved or uploaded.
class DeviceWakeWordDetector implements WakeWordDetector {
  static const _sampleRate = 16000;
  AudioRecorder? _recorder;
  Isolate? _worker;
  ReceivePort? _events;
  SendPort? _input;
  Completer<SendPort?>? _ready;
  StreamSubscription<Uint8List>? _audio;
  Future<void> _pending = Future<void>.value();
  void Function()? _onWake;
  void Function(String)? _onError;
  int _generation = 0;
  int _queuedFrames = 0;
  bool _droppedAudio = false;
  int? _leftoverByte;
  bool _listening = false;
  bool _recording = false;
  bool _workerFailed = false;
  bool _disposed = false;

  Future<void> _serialize(Future<void> Function() action) {
    final next = _pending.catchError((Object _) {}).then((_) => action());
    _pending = next;
    return next;
  }

  @override
  Future<void> start({
    required void Function() onWake,
    required void Function(String) onError,
  }) {
    final generation = ++_generation;
    return _serialize(() async {
      if (_disposed || generation != _generation) return;
      if (!Platform.isAndroid) {
        throw const WakeWordException('当前版本的喊名字唤醒仅支持安卓。');
      }
      await _stopRecording();
      final recorder = _recorder ??= AudioRecorder();
      if (!await recorder.hasPermission()) {
        throw const WakeWordException('请允许麦克风权限，才能开启喊名字唤醒。');
      }
      if (_disposed || generation != _generation) return;
      await _ensureWorker();
      if (_disposed || generation != _generation) return;
      _onWake = onWake;
      _onError = onError;
      _queuedFrames = 0;
      _droppedAudio = false;
      _leftoverByte = null;
      _input!.send({'type': 'reset', 'generation': generation});
      _recording = true;
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          streamBufferSize: 3200,
          // Keep detecting the wake word while this app's music is playing.
          audioInterruption: AudioInterruptionMode.none,
          androidConfig: AndroidRecordConfig(
            manageBluetooth: false,
            audioSource: AndroidAudioSource.voiceRecognition,
          ),
        ),
      );
      if (_disposed || generation != _generation) {
        await _stopRecording();
        return;
      }
      if (_input == null) {
        await _stopRecording();
        throw const WakeWordException('本地唤醒已停止，请重新开启语音助手。');
      }
      _listening = true;
      _audio = stream.listen(
        (bytes) => _acceptAudio(bytes, generation),
        onError: (Object _) => _captureFailed(generation),
        onDone: () => _captureFailed(generation),
      );
    });
  }

  void _captureFailed(int generation) {
    if (_disposed || !_listening || generation != _generation) return;
    _listening = false;
    _onError?.call('麦克风监听已中断，请重新开启语音助手。');
  }

  void _acceptAudio(Uint8List incoming, int generation) {
    if (!_listening || generation != _generation || incoming.isEmpty) return;
    // Do not accumulate an unbounded inference queue on slow devices.
    if (_queuedFrames >= 4) {
      _leftoverByte = null;
      _droppedAudio = true;
      return;
    }
    if (_droppedAudio) {
      _input?.send({'type': 'reset', 'generation': generation});
      _droppedAudio = false;
    }
    var bytes = incoming;
    if (_leftoverByte != null) {
      bytes = Uint8List(incoming.length + 1)
        ..[0] = _leftoverByte!
        ..setRange(1, incoming.length + 1, incoming);
      _leftoverByte = null;
    }
    if (bytes.length.isOdd) _leftoverByte = bytes.last;
    final count = bytes.length ~/ 2;
    if (count == 0) return;
    final view = ByteData.sublistView(bytes);
    final samples = Float32List(count);
    for (var i = 0; i < count; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    _queuedFrames++;
    _input!.send({
      'type': 'audio',
      'generation': generation,
      'samples': TransferableTypedData.fromList([samples.buffer.asUint8List()]),
    });
  }

  Future<void> _ensureWorker() async {
    if (_input != null) return;
    final support = await getApplicationSupportDirectory();
    final folder = Directory('${support.path}/kws-wenetspeech-20240101-v1');
    await folder.create(recursive: true);
    for (final name in [
      'encoder.int8.onnx',
      'decoder.int8.onnx',
      'joiner.int8.onnx',
      'tokens.txt',
      'keywords.txt',
    ]) {
      final data = await rootBundle.load('assets/models/kws/$name');
      final file = File('${folder.path}/$name');
      if (name == 'keywords.txt' ||
          !await file.exists() ||
          await file.length() != data.lengthInBytes) {
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          flush: true,
        );
      }
    }
    _ready = Completer<SendPort?>();
    _workerFailed = false;
    final events = _events = ReceivePort();
    events.listen((event) {
      if (_events == events) _handleWorkerEvent(event);
    });
    try {
      _worker = await Isolate.spawn(
        _keywordWorker,
        {'events': _events!.sendPort, 'directory': folder.path},
        onError: _events!.sendPort,
        onExit: _events!.sendPort,
      );
      _input = await _ready!.future.timeout(const Duration(seconds: 25));
      if (_input == null || _workerFailed) {
        throw StateError('Wake-word worker did not initialize');
      }
    } catch (_) {
      _worker?.kill(priority: Isolate.immediate);
      _worker = null;
      _events?.close();
      _events = null;
      _input = null;
      throw const WakeWordException('本地唤醒模型未能启动，请关闭语音助手后重试。');
    } finally {
      _ready = null;
    }
  }

  void _handleWorkerEvent(dynamic event) {
    if (event is List && event.isNotEmpty && event.first == 'ready') {
      if (_ready != null && !_ready!.isCompleted) {
        _ready!.complete(event[1] as SendPort);
      }
      return;
    }
    if (event is List && event.isNotEmpty && event.first == 'ack') {
      if (event[1] == _generation && _queuedFrames > 0) _queuedFrames--;
      return;
    }
    if (event is List && event.isNotEmpty && event.first == 'wake') {
      if (event[1] == _generation && _listening) {
        _listening = false;
        _onWake?.call();
      }
      return;
    }
    // Includes isolate errors and unexpected exits. A failed worker must never
    // leave the UI saying that the microphone is still waiting for a wake word.
    final wasListening = _listening;
    _workerFailed = true;
    _listening = false;
    _input = null;
    _worker = null;
    _events?.close();
    _events = null;
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.complete(null);
    } else if (wasListening && !_disposed) {
      _onError?.call('本地唤醒已停止，请重新开启语音助手。');
    }
  }

  Future<void> _stopRecording() async {
    _listening = false;
    final audio = _audio;
    _audio = null;
    try {
      await audio?.cancel();
    } finally {
      try {
        if (_recording) await _recorder?.stop();
      } finally {
        _recording = false;
        _queuedFrames = 0;
        _droppedAudio = false;
        _leftoverByte = null;
      }
    }
  }

  @override
  Future<void> stop() {
    _generation++;
    return _serialize(_stopRecording);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    try {
      await stop();
    } finally {
      // The worker frees its native objects and exits on this message.
      _input?.send({'type': 'dispose'});
      _events?.close();
      _events = null;
      _input = null;
      _worker = null;
      await _recorder?.dispose();
      _recorder = null;
    }
  }
}

void _keywordWorker(Map<String, Object> configuration) {
  final events = configuration['events']! as SendPort;
  final folder = configuration['directory']! as String;
  final commands = ReceivePort();
  sherpa.KeywordSpotter? spotter;
  sherpa.OnlineStream? stream;
  late final sherpa.KeywordSpotter decoder;
  late sherpa.OnlineStream input;
  try {
    sherpa.initBindings();
    spotter = sherpa.KeywordSpotter(
      sherpa.KeywordSpotterConfig(
        feat: const sherpa.FeatureConfig(sampleRate: 16000, featureDim: 80),
        model: sherpa.OnlineModelConfig(
          transducer: sherpa.OnlineTransducerModelConfig(
            encoder: '$folder/encoder.int8.onnx',
            decoder: '$folder/decoder.int8.onnx',
            joiner: '$folder/joiner.int8.onnx',
          ),
          tokens: '$folder/tokens.txt',
          numThreads: 1,
          provider: 'cpu',
        ),
        keywordsFile: '$folder/keywords.txt',
        keywordsThreshold: 0.35,
      ),
    );
    stream = spotter.createStream();
    decoder = spotter;
    input = stream;
    events.send(['ready', commands.sendPort]);
  } catch (error) {
    stream?.free();
    spotter?.free();
    commands.close();
    events.send(['error', error.toString()]);
    return;
  }
  commands.listen((dynamic message) {
    if (message is! Map) return;
    try {
      switch (message['type']) {
        case 'reset':
          input.free();
          input = decoder.createStream();
          break;
        case 'audio':
          final transfer = message['samples'] as TransferableTypedData;
          final samples = transfer.materialize().asFloat32List();
          input.acceptWaveform(samples: samples, sampleRate: 16000);
          while (decoder.isReady(input)) {
            decoder.decode(input);
            final result = decoder.getResult(input);
            if (result.keyword.isNotEmpty) {
              decoder.reset(input);
              events.send(['wake', message['generation']]);
              break;
            }
          }
          events.send(['ack', message['generation']]);
          break;
        case 'dispose':
          input.free();
          decoder.free();
          commands.close();
          break;
      }
    } catch (error) {
      input.free();
      decoder.free();
      commands.close();
      events.send(['error', error.toString()]);
    }
  });
}
