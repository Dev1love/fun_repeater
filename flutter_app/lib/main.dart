import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'wav_reverser.dart';

void main() => runApp(const ZadomNaperedApp());

class ZadomNaperedApp extends StatelessWidget {
  const ZadomNaperedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C3AED),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Задом наперёд',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      home: const GameScreen(),
    );
  }
}

/// Какая запись сейчас пишется: слово игрока 1 или повтор игрока 2.
enum _Target { none, word, echo }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  _Target _recording = _Target.none;

  // Пути к перевёрнутым WAV: запись 1 (слово) и запись 2 (повтор).
  String? _reversedWordPath;
  String? _reversedEchoPath;

  // Какой файл сейчас играет (чтобы гасить нужную кнопку).
  _Target _playing = _Target.none;

  String _status = 'Готово к записи';
  String _hint = '';
  bool _busy = false; // блокировка на время обработки/переворота WAV

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = _Target.none;
        _status = 'Ещё раз? Жми ту же кнопку сколько угодно';
      });
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  bool get _isRecording => _recording != _Target.none;

  Future<String> _newFilePath(String tag) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return '${dir.path}/zn_${tag}_$stamp.wav';
  }

  Future<void> _startRecording(_Target target) async {
    if (_isRecording || _busy) return;

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      setState(() {
        _status = 'Нет доступа к микрофону 😔';
        _hint = 'Разреши доступ к микрофону в настройках телефона.';
      });
      return;
    }

    await _player.stop();
    final path = await _newFilePath(target == _Target.word ? 'word' : 'echo');
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() {
      _recording = target;
      _playing = _Target.none;
      _status = target == _Target.word
          ? 'Идёт запись… нажми ещё раз, чтобы остановить'
          : 'Идёт запись повтора… нажми ещё раз, чтобы остановить';
      _hint = '';
    });
  }

  Future<void> _stopRecording() async {
    final target = _recording;
    if (target == _Target.none) return;

    setState(() => _busy = true);
    final path = await _recorder.stop();
    setState(() => _recording = _Target.none);

    try {
      if (path == null) throw const FormatException('Пустая запись.');
      final file = File(path);
      final bytes = await file.readAsBytes();
      final reversed = WavReverser.reverse(bytes);

      final outPath =
          '${path.substring(0, path.length - 4)}_reversed.wav';
      await File(outPath).writeAsBytes(reversed, flush: true);

      setState(() {
        if (target == _Target.word) {
          _reversedWordPath = outPath;
          // Новое слово обнуляет прошлый повтор.
          _reversedEchoPath = null;
          _status = 'Слово записано! ⏪ Игрок 2 — слушай задом наперёд';
          _hint =
              'Нажимай «Слушать задом наперёд» столько раз, сколько нужно.';
        } else {
          _reversedEchoPath = outPath;
          _status = 'Повтор записан! 🎯 Нажми «Проверить слово»';
          _hint =
              '«Проверить слово» проиграет твой повтор задом наперёд — должно получиться исходное слово.';
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Не получилось обработать аудио 😔';
        _hint = 'Попробуй записать ещё раз.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleRecord(_Target target) async {
    if (_recording == target) {
      await _stopRecording();
    } else if (!_isRecording) {
      await _startRecording(target);
    }
  }

  Future<void> _play(_Target which, String? path) async {
    if (path == null || _isRecording || _busy) return;
    await _player.stop();
    setState(() {
      _playing = which;
      _status = which == _Target.word
          ? '▶️ Играет задом наперёд…'
          : '🎯 Играет твой повтор задом наперёд…';
    });
    await _player.play(DeviceFileSource(path));
  }

  @override
  Widget build(BuildContext context) {
    final canPlayWord = _reversedWordPath != null;
    final canRecordEcho = _reversedWordPath != null;
    final canReveal = _reversedEchoPath != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Column(
            children: [
              const SizedBox(height: 6),
              const Text(
                '🔊 Задом наперёд',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Игрок 1 записывает слово. Игрок 2 слушает его задом наперёд и пробует повторить!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GameButton(
                      icon: '🎙️',
                      color: const Color(0xFFDC2626),
                      title: _recording == _Target.word
                          ? 'Остановить запись'
                          : 'Записать слово',
                      subtitle: 'Игрок 1 · нажми для старта и стопа',
                      pulsing: _recording == _Target.word,
                      onTap: _busy ? null : () => _toggleRecord(_Target.word),
                    ),
                    const SizedBox(height: 14),
                    _GameButton(
                      icon: '⏪',
                      color: const Color(0xFF2563EB),
                      title: 'Слушать задом наперёд',
                      subtitle: 'Игрок 2 · сколько угодно раз',
                      pulsing: _playing == _Target.word,
                      onTap: (!canPlayWord || _isRecording || _busy)
                          ? null
                          : () => _play(_Target.word, _reversedWordPath),
                    ),
                    const SizedBox(height: 14),
                    _GameButton(
                      icon: '🎤',
                      color: const Color(0xFF7C3AED),
                      title: _recording == _Target.echo
                          ? 'Остановить запись'
                          : 'Записать повтор',
                      subtitle: 'Игрок 2 · повтори, что услышал',
                      pulsing: _recording == _Target.echo,
                      onTap: (!canRecordEcho || _busy)
                          ? null
                          : () => _toggleRecord(_Target.echo),
                    ),
                    const SizedBox(height: 14),
                    _GameButton(
                      icon: '🎯',
                      color: const Color(0xFF059669),
                      title: 'Проверить слово',
                      subtitle: 'Повтор задом наперёд — угадал?',
                      pulsing: _playing == _Target.echo,
                      onTap: (!canReveal || _isRecording || _busy)
                          ? null
                          : () => _play(_Target.echo, _reversedEchoPath),
                    ),
                  ],
                ),
              ),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFFCBD5E1)),
              ),
              if (_hint.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.pulsing = false,
  });

  final String icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool pulsing;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        elevation: enabled ? 6 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
            decoration: pulsing
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white70, width: 2),
                  )
                : null,
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text(icon,
                      style: const TextStyle(fontSize: 30),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
