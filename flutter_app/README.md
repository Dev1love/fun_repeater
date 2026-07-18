# 🔊 Задом наперёд — Flutter (мобильная версия)

Нативная мобильная версия игры «Задом наперёд» на Flutter (Android + iOS).
Логика та же, что и в веб-версии из `main`/ветки с `index.html`:

1. **🎙️ Записать слово** — Игрок 1 говорит слово (нажать → говоришь → нажать ещё раз, чтобы остановить).
2. **⏪ Слушать задом наперёд** — Игрок 2 слушает перевёрнутую запись сколько угодно раз.
3. **🎤 Записать повтор** — Игрок 2 пытается повторить услышанные (перевёрнутые) звуки.
4. **🎯 Проверить слово** — повтор Игрока 2 проигрывается задом наперёд. Должно получиться исходное слово.

## Как устроен переворот звука

В отличие от веба (там был Web Audio API), на телефоне запись идёт в **WAV (PCM16)**
через пакет [`record`](https://pub.dev/packages/record). Затем `lib/wav_reverser.dart`
разбирает WAV, меняет порядок звуковых кадров (не трогая байты внутри кадра) и пишет
новый корректный WAV, который проигрывается через [`audioplayers`](https://pub.dev/packages/audioplayers).

## Структура

```
flutter_app/
├── pubspec.yaml
├── analysis_options.yaml
├── lib/
│   ├── main.dart          # UI и игровая логика (4 кнопки)
│   └── wav_reverser.dart  # переворот PCM WAV
└── test/
    └── wav_reverser_test.dart
```

Платформенные папки (`android/`, `ios/`, …) в репозиторий не закоммичены —
их генерирует Flutter одной командой (см. ниже).

## Запуск на машине с установленным Flutter

> В окружении, где собиралась ветка, Flutter SDK не было, поэтому проект собран
> как исходники. На своей машине с [Flutter](https://docs.flutter.dev/get-started/install):

```bash
cd flutter_app

# 1. Сгенерировать платформенные папки вокруг существующих lib/ и pubspec.yaml.
#    Существующие файлы не перезаписываются.
flutter create .

# 2. Установить зависимости.
flutter pub get

# 3. Запустить на подключённом телефоне или эмуляторе.
flutter run
```

Прогнать логику переворота (без устройства):

```bash
flutter test
```

## ⚠️ Разрешения на микрофон (обязательный шаг после `flutter create .`)

`flutter create .` создаёт манифесты со стандартными правами, **без** микрофона.
Добавь доступ вручную:

**Android** — `android/app/src/main/AndroidManifest.xml`, внутри `<manifest>` (над `<application>`):

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

**iOS** — `ios/Runner/Info.plist`, внутри `<dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Приложению нужен микрофон, чтобы записывать слова для игры.</string>
```

Минимальные версии платформ, которые ожидают `record`/`audioplayers`:
Android `minSdkVersion 23` (`android/app/build.gradle`) и iOS 12+.

После этого `flutter run` — и можно играть.

## Сборка релизных пакетов (когда решишь публиковать)

```bash
flutter build apk        # Android APK
flutter build appbundle  # Android App Bundle для Google Play
flutter build ios        # iOS (нужен Xcode/macOS)
```
