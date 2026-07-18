import 'dart:typed_data';

/// Разворачивает PCM WAV-файл задом наперёд.
///
/// Работает с любым каноническим WAV (RIFF/WAVE) с целочисленным PCM:
/// парсит чанки, находит `fmt ` (число каналов и бит на сэмпл) и `data`,
/// затем меняет порядок кадров (frame = numChannels * bytesPerSample),
/// не трогая байты внутри кадра — так сэмплы и каналы остаются валидными.
///
/// Заголовок и любые данные до/после чанка `data` сохраняются как есть,
/// поэтому результат — корректный воспроизводимый WAV той же длительности.
class WavReverser {
  static Uint8List reverse(Uint8List bytes) {
    if (bytes.length < 12 ||
        _ascii(bytes, 0, 4) != 'RIFF' ||
        _ascii(bytes, 8, 4) != 'WAVE') {
      throw const FormatException('Это не WAV-файл (нет RIFF/WAVE).');
    }

    final data = ByteData.sublistView(bytes);

    int numChannels = 1;
    int bitsPerSample = 16;
    int dataStart = -1;
    int dataLen = 0;

    // Обходим чанки, начиная сразу после "WAVE" (позиция 12).
    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, pos, 4);
      final chunkSize = data.getUint32(pos + 4, Endian.little);
      final body = pos + 8;

      if (chunkId == 'fmt ' && body + 16 <= bytes.length) {
        numChannels = data.getUint16(body + 2, Endian.little);
        bitsPerSample = data.getUint16(body + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataStart = body;
        // Защита от «битой» длины в заголовке.
        dataLen = chunkSize;
        if (dataStart + dataLen > bytes.length) {
          dataLen = bytes.length - dataStart;
        }
        break;
      }

      // Чанки выравниваются по чётной границе.
      pos = body + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (dataStart < 0 || dataLen <= 0) {
      throw const FormatException('В WAV не найден чанк data.');
    }

    final bytesPerSample = (bitsPerSample / 8).ceil();
    final frameSize = (numChannels * bytesPerSample).clamp(1, 1 << 20);
    final frameCount = dataLen ~/ frameSize;

    final out = Uint8List.fromList(bytes); // копия: заголовок остаётся прежним
    for (int i = 0; i < frameCount; i++) {
      final srcOffset = dataStart + i * frameSize;
      final dstOffset = dataStart + (frameCount - 1 - i) * frameSize;
      for (int b = 0; b < frameSize; b++) {
        out[dstOffset + b] = bytes[srcOffset + b];
      }
    }
    return out;
  }

  static String _ascii(Uint8List b, int start, int len) {
    return String.fromCharCodes(b.sublist(start, start + len));
  }
}
