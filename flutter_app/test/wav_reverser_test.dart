import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zadom_napered/wav_reverser.dart';

/// Собирает минимальный канонический PCM16 mono WAV из списка сэмплов.
Uint8List buildWav(List<int> samples, {int sampleRate = 8000}) {
  const numChannels = 1;
  const bitsPerSample = 16;
  final dataBytes = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    dataBytes.setInt16(i * 2, samples[i], Endian.little);
  }
  final data = dataBytes.buffer.asUint8List();

  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final header = ByteData(44);
  void ascii(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + data.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little); // PCM
  header.setUint16(22, numChannels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, numChannels * bitsPerSample ~/ 8, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  header.setUint32(40, data.length, Endian.little);

  return Uint8List.fromList([...header.buffer.asUint8List(), ...data]);
}

List<int> readSamples(Uint8List wav) {
  final bd = ByteData.sublistView(wav);
  final count = (wav.length - 44) ~/ 2;
  return List<int>.generate(count, (i) => bd.getInt16(44 + i * 2, Endian.little));
}

void main() {
  test('переворачивает сэмплы задом наперёд', () {
    final wav = buildWav([1, 2, 3, 4, 5]);
    final reversed = WavReverser.reverse(wav);
    expect(readSamples(reversed), [5, 4, 3, 2, 1]);
  });

  test('заголовок остаётся прежним', () {
    final wav = buildWav([10, 20, 30]);
    final reversed = WavReverser.reverse(wav);
    expect(reversed.sublist(0, 44), wav.sublist(0, 44));
    expect(reversed.length, wav.length);
  });

  test('двойной переворот возвращает оригинал', () {
    final wav = buildWav([7, -3, 100, -50, 0, 9]);
    final twice = WavReverser.reverse(WavReverser.reverse(wav));
    expect(readSamples(twice), readSamples(wav));
  });

  test('бросает исключение на не-WAV', () {
    expect(
      () => WavReverser.reverse(Uint8List.fromList([0, 1, 2, 3])),
      throwsA(isA<FormatException>()),
    );
  });
}
