import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/assistant_speech.dart';
import '../services/speech_input.dart';
import '../services/voice_commands.dart';
import '../services/wake_word_detector.dart';
import 'library_controller.dart';

enum VoicePhase {
  ready,
  preparing,
  speaking,
  listening,
  processing,
  finished,
  unavailable,
}

enum AssistantPhase { off, preparing, waiting, command, suspended, failed }

class VoiceController extends ChangeNotifier {
  VoiceController(
    this.library, {
    SpeechInput? input,
    WakeWordDetector? wakeWord,
    AssistantSpeech? speaker,
  }) : _speech = input ?? DeviceSpeechInput(),
       _wake = wakeWord,
       _speaker = speaker;

  static const wakeWord = '小耳朵';
  final LibraryController library;
  final SpeechInput _speech;
  WakeWordDetector? _wake;
  AssistantSpeech? _speaker;
  VoicePhase phase = VoicePhase.ready;
  AssistantPhase assistantPhase = AssistantPhase.off;
  String transcript = '';
  String feedback = '说出你想听的内容';
  bool _assistantEnabled = false;
  bool _foreground = true;
  bool _spokenSession = false;
  bool _wasPlaying = false;
  bool _finished = true;
  bool _disposed = false;
  int _generation = 0;
  int _assistantGeneration = 0;
  DateTime? _resumeDeadline;
  Timer? _timeout;
  Timer? _finishDelay;
  Timer? _wakeDelay;

  bool get assistantEnabled => _assistantEnabled;
  bool get waitingForWakeWord => assistantPhase == AssistantPhase.waiting;
  bool get active =>
      phase == VoicePhase.preparing ||
      phase == VoicePhase.speaking ||
      phase == VoicePhase.listening ||
      phase == VoicePhase.processing;
  bool get assistantPreparing => assistantPhase == AssistantPhase.preparing;
  String get assistantStatus {
    if (active) {
      return phase == VoicePhase.listening ? '我在听，请说播放指令' : feedback;
    }
    return switch (assistantPhase) {
      AssistantPhase.off => '开启后，喊“小耳朵”即可控制播放',
      AssistantPhase.preparing => '正在准备本地唤醒…',
      AssistantPhase.waiting => '正在等你喊“小耳朵”',
      AssistantPhase.command =>
        phase == VoicePhase.listening ? '我在听，请说播放指令' : feedback,
      AssistantPhase.suspended => '回到 App 后继续等待唤醒',
      AssistantPhase.failed => '语音助手暂不可用，点开查看',
    };
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int generation) => !_disposed && generation == _generation;

  Future<void> setAssistantEnabled(bool enabled) async {
    if (_disposed || enabled == _assistantEnabled) return;
    _assistantEnabled = enabled;
    _assistantGeneration++;
    _wakeDelay?.cancel();
    if (!enabled) {
      assistantPhase = AssistantPhase.off;
      _notify();
      await cancel();
    } else if (!_foreground) {
      assistantPhase = AssistantPhase.suspended;
      _notify();
    } else if (active) {
      // Let the existing manual command finish before taking the microphone.
      assistantPhase = AssistantPhase.command;
      _notify();
    } else {
      await _armWakeWord();
    }
  }

  Future<void> _armWakeWord() async {
    if (_disposed || !_assistantEnabled || !_foreground || active) return;
    _wakeDelay?.cancel();
    final generation = ++_assistantGeneration;
    assistantPhase = AssistantPhase.preparing;
    _notify();
    try {
      final detector = _wake ??= DeviceWakeWordDetector();
      await detector.start(
        onWake: () {
          if (_disposed ||
              !_assistantEnabled ||
              !_foreground ||
              active ||
              generation != _assistantGeneration) {
            return;
          }
          assistantPhase = AssistantPhase.command;
          _notify();
          unawaited(start(fromWakeWord: true));
        },
        onError: (reason) {
          if (_disposed || generation != _assistantGeneration) return;
          _assistantFailed(reason);
        },
      );
      if (_disposed ||
          generation != _assistantGeneration ||
          !_assistantEnabled ||
          !_foreground ||
          active) {
        return;
      }
      assistantPhase = AssistantPhase.waiting;
      _notify();
    } catch (error) {
      if (!_disposed && generation == _assistantGeneration) {
        _assistantFailed(
          error is WakeWordException ? error.message : '唤醒监听未能启动，请检查麦克风权限后重试。',
        );
      }
    }
  }

  void _assistantFailed(String reason) {
    _assistantEnabled = false;
    _assistantGeneration++;
    _wakeDelay?.cancel();
    assistantPhase = AssistantPhase.failed;
    phase = VoicePhase.unavailable;
    feedback = reason;
    unawaited(_wake?.stop().catchError((Object _) {}) ?? Future<void>.value());
    _notify();
  }

  void _scheduleWakeWord() {
    _wakeDelay?.cancel();
    if (_disposed || !_assistantEnabled || !_foreground || active) return;
    assistantPhase = AssistantPhase.preparing;
    // Let the spoken acknowledgement finish acoustically before recording again.
    _wakeDelay = Timer(
      const Duration(milliseconds: 450),
      () => unawaited(_armWakeWord()),
    );
    _notify();
  }

  /// Starts one command. Wake-word capture and recognition never share the mic.
  Future<void> start({bool fromWakeWord = false}) async {
    if (active || _disposed || !_foreground) return;
    _wakeDelay?.cancel();
    final generation = ++_generation;
    _finished = false;
    _spokenSession = fromWakeWord || _assistantEnabled;
    transcript = '';
    phase = VoicePhase.preparing;
    if (_assistantEnabled) assistantPhase = AssistantPhase.command;
    feedback = '正在准备麦克风…';
    _wasPlaying = library.playing;
    _resumeDeadline = library.sleepAt;
    _notify();
    try {
      await _wake?.stop();
      if (!_current(generation) || _finished) return;
      if (library.busy) {
        _finished = true;
        phase = VoicePhase.finished;
        feedback = '音频正在准备，稍等一下再说吧。';
        _scheduleWakeWord();
        _notify();
        return;
      }
      await library.pause();
      if (!_current(generation) || _finished) return;
      final available = await _speech.initialize(
        onStatus: (status) {
          if ((status == 'done' || status == 'notListening') &&
              !_finished &&
              phase == VoicePhase.listening) {
            _finishDelay?.cancel();
            _finishDelay = Timer(
              const Duration(milliseconds: 500),
              () => unawaited(_finish()),
            );
          }
        },
        onError: (error) {
          if (!_finished) {
            if (error.contains('no_match') ||
                error.contains('speech_timeout')) {
              // Silence is a normal end of a command, so keep wake mode on.
              unawaited(_finish());
              return;
            }
            unawaited(
              _fail(
                error.contains('permission')
                    ? '请在系统设置中允许麦克风和语音识别权限。'
                    : '这次没有识别成功，请检查网络和系统语音服务后重试。',
              ),
            );
          }
        },
      );
      if (!_current(generation) || _finished) return;
      if (!available) {
        await _fail('系统语音识别暂不可用。请检查麦克风权限及系统语音服务，也可以直接点按钮播放。');
        return;
      }
      final locales = await _speech.locales();
      if (!_current(generation) || _finished) return;
      final chinese = locales.where(
        (locale) =>
            locale.toLowerCase().replaceAll('-', '_').startsWith('zh_cn'),
      );
      final anyChinese = locales.where(
        (locale) => locale.toLowerCase().startsWith('zh'),
      );
      if (locales.isNotEmpty && chinese.isEmpty && anyChinese.isEmpty) {
        await _fail('系统尚未提供中文语音识别，请在系统语音设置中添加中文。');
        return;
      }
      // Some Android recognizers support Chinese but do not enumerate locales.
      final locale = chinese.isNotEmpty
          ? chinese.first
          : anyChinese.isNotEmpty
          ? anyChinese.first
          : 'zh_CN';
      if (_spokenSession) {
        await _say('我在，请说。');
        if (!_current(generation) || _finished) return;
      }
      phase = VoicePhase.listening;
      feedback = '正在听，请说一句指令…';
      _notify();
      _timeout = Timer(const Duration(seconds: 18), () => unawaited(_finish()));
      await _speech.listen(
        locale: locale,
        onResult: (words, finalResult) {
          if (_finished || !_current(generation)) return;
          transcript = words;
          _notify();
          if (finalResult) unawaited(_finish());
        },
      );
    } catch (_) {
      if (!_finished && _current(generation)) {
        await _fail('麦克风未能启动，请检查权限后再试一次。');
      }
    }
  }

  Future<void> _say(String text) async {
    phase = VoicePhase.speaking;
    feedback = text;
    _notify();
    try {
      await (_speaker ??= DeviceAssistantSpeech()).say(text);
    } catch (_) {
      /* Text feedback remains available. */
    }
  }

  Future<void> _restorePlayback() async {
    if (_wasPlaying &&
        !_disposed &&
        (_resumeDeadline == null ||
            DateTime.now().isBefore(_resumeDeadline!))) {
      await library.resume();
    }
  }

  Future<void> _finish() async {
    if (_finished || _disposed) return;
    final generation = _generation;
    _finished = true;
    _timeout?.cancel();
    _finishDelay?.cancel();
    phase = VoicePhase.processing;
    feedback = '好的，稍等一下…';
    _notify();
    try {
      await _speech.stop();
      if (!_current(generation)) return;
      final command = parseVoiceCommand(transcript, library.tracks);
      final noCommand =
          transcript.isEmpty || command.type == CommandType.unknown;
      if (_spokenSession) {
        await _say(noCommand ? '没有听懂。你可以喊小耳朵，再说播放儿歌。' : '好的。');
        if (!_current(generation)) return;
      }
      phase = VoicePhase.processing;
      feedback = transcript.isEmpty
          ? (_assistantEnabled ? '没有听清，喊“小耳朵”再试一次吧。' : '没有听清，点麦克风再试一次吧。')
          : await library.execute(command);
      const changesPlayback = {
        CommandType.play,
        CommandType.pause,
        CommandType.next,
        CommandType.previous,
        CommandType.category,
        CommandType.track,
      };
      if (!_current(generation)) return;
      if (!changesPlayback.contains(command.type)) await _restorePlayback();
      if (!_current(generation)) return;
      phase = VoicePhase.finished;
      _notify();
      _scheduleWakeWord();
    } catch (_) {
      if (_current(generation)) {
        await _completeFailure('这次指令未能执行，请再试一次。', generation);
      }
    }
  }

  Future<void> _fail(String reason) async {
    if (_finished || _disposed) return;
    _finished = true;
    await _completeFailure(reason, _generation);
  }

  Future<void> _completeFailure(String reason, int generation) async {
    _timeout?.cancel();
    _finishDelay?.cancel();
    try {
      await _speech.cancel();
    } catch (_) {
      /* Already stopped. */
    }
    if (!_current(generation)) return;
    if (_spokenSession) {
      await _say('语音识别暂时不可用，请使用播放按钮。');
      if (!_current(generation)) return;
    }
    try {
      await _restorePlayback();
    } catch (_) {
      /* Playback has its own controls. */
    }
    if (!_current(generation)) return;
    phase = VoicePhase.unavailable;
    feedback = reason;
    // An unavailable command recognizer needs user attention, rather than
    // repeatedly waking and failing with a live microphone.
    if (_assistantEnabled) {
      _assistantEnabled = false;
      _assistantGeneration++;
      assistantPhase = AssistantPhase.failed;
    }
    _notify();
  }

  Future<void> cancel() async {
    if (_disposed) return;
    final restore = !_finished || active;
    final generation = ++_generation;
    _finished = true;
    _timeout?.cancel();
    _finishDelay?.cancel();
    _wakeDelay?.cancel();
    // Attempt every stop even if one device service is no longer available.
    try {
      await _wake?.stop();
    } catch (_) {
      /* Stop the other services too. */
    }
    try {
      await _speaker?.stop();
    } catch (_) {
      /* Already stopped. */
    }
    try {
      await _speech.cancel();
    } catch (_) {
      /* Already stopped. */
    }
    if (!_current(generation)) return;
    if (restore) {
      try {
        await _restorePlayback();
      } catch (_) {
        /* Keep manual playback available. */
      }
    }
    if (!_current(generation)) return;
    phase = VoicePhase.ready;
    _notify();
    _scheduleWakeWord();
  }

  Future<void> dismissPanel() async {
    if (active) await cancel();
  }

  Future<void> setForeground(bool foreground) async {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    _assistantGeneration++;
    _wakeDelay?.cancel();
    if (!foreground) {
      assistantPhase = _assistantEnabled
          ? AssistantPhase.suspended
          : AssistantPhase.off;
      _notify();
      await cancel();
    } else if (_assistantEnabled) {
      if (active) await cancel();
      await _armWakeWord();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _finished = true;
    _assistantEnabled = false;
    _generation++;
    _assistantGeneration++;
    _timeout?.cancel();
    _finishDelay?.cancel();
    _wakeDelay?.cancel();
    unawaited(_speech.cancel().catchError((Object _) {}));
    unawaited(
      _wake?.dispose().catchError((Object _) {}) ?? Future<void>.value(),
    );
    unawaited(
      _speaker?.stop().catchError((Object _) {}) ?? Future<void>.value(),
    );
    super.dispose();
  }
}
