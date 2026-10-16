# 小耳朵英语 · Little Ears

独立 Flutter 项目，首发目标为 Android。面向低龄家庭、以儿歌和故事为主的英语听播应用。

## 已实现

- 12 段内置英语音频：4 段原创童谣朗读、4 段生活短句、4 段短故事。
- 儿歌 / 故事双入口与封面内容库；生活英语作为次级分类。
- 播放页支持返回按钮和下滑关闭（跟手拖动、短拖动回弹），关闭页面后继续播放；固定操作区提供中英逐句字幕、松手后跳转进度、上/下一首、睡前定时和播放列表。
- 底部「首页 / 收藏 / 设置」页面切换，各页保留浏览位置；迷你播放器固定在 Tab 上方。
- 顺序播放、列表循环、单曲循环。
- 本地收藏、最近播放曲目记忆。
- 5/10/15/30/60 分钟定时停止，语音可设置 1–120 分钟。
- Android 后台音频、通知栏及系统媒体控制。
- App 前台的“小耳朵”本地唤醒、中文语音回应，以及播放、音量、定时控制；保留点麦克风说指令的入口。

## 运行

需要 Flutter 3.41 / Dart 3.11 或兼容版本、Android SDK 和 JDK 17。

```sh
flutter pub get
flutter run -d <Android设备ID>
```

```sh
flutter analyze
flutter test
flutter build apk --debug
```

安卓 ARM64 体验包：

```sh
flutter build apk --release --target-platform android-arm64
```

输出：`build/app/outputs/flutter-apk/app-release.apk`。

真机播放与界面验证：

```sh
flutter test integration_test/android_smoke_test.dart -d <Android设备ID>
```

此前的点按语音版本通过过 18 项单元/界面检查及 Android 12 真机播放检查。后续语音唤醒及新版界面改造按使用者要求没有打包、运行测试或安装到设备，唤醒效果、录音与播放的兼容性仍待真机确认。

首版历史截图：[首页](docs/screenshots/home.png)、[播放页](docs/screenshots/player.png)。新版页面结构和视觉规范见 [设计说明](docs/design.md)，尚未生成新的运行截图。

APK：`build/app/outputs/flutter-apk/app-debug.apk`。
当前 release 配置仍使用脚手架的调试签名；商店发布需配置自己的应用 ID、正式签名及发布材料。

## 语音控制

1. 点击首页或播放页的「小耳朵语音助手」，开启「喊名字唤醒」，首次使用允许麦克风权限。
2. 在 App 前台喊 **“小耳朵”**。
3. 音频暂停，听到 **“我在，请说”** 后再说一句指令。
4. 执行完后自动回到等待唤醒，也可以随时关闭开关。

关闭语音面板会保留等待唤醒；正在识别的本次指令会取消。也可以不开启唤醒，直接点击面板麦克风说一次指令。

- 播放儿歌 / 播放生活英语 / 播放故事
- 播放「早安，好心情」等曲目中文名称
- 暂停 / 继续播放 / 上一首 / 下一首
- 收藏这首 / 单曲循环 / 列表循环
- 声音大一点 / 声音小一点（调整应用播放音量）
- 定时十分钟 / 十五分钟后停止 / 取消定时

当前仅支持 **Android App 前台唤醒**。切到桌面、锁屏或切换到其他 App 后停止监听，返回 App 后继续；重启应用默认关闭。后台音频播放仍由原有媒体服务负责。

唤醒词使用 `record` 采集 PCM，通过 `sherpa_onnx` 在独立 isolate 中本地识别，不上传或保存唤醒录音。已内置约 5 MB 的中文量化模型及“小耳朵”词表，授权和来源见 [模型说明](assets/models/kws/NOTICE.md)。模型阈值为初始配置，尚未经目标设备和儿童发音验证。

指令使用 `speech_to_text` 调用设备语音识别服务。是否支持中文、能否离线、是否需要联网由设备及其识别服务决定，系统识别服务可能处理或上传指令音频。部分安卓系统没有可用的识别服务，此时提供提示并关闭唤醒开关，普通播放仍可使用。本项目不配置语音服务器，也不保存指令录音。

语音回应使用 `flutter_tts` 和系统中文语音引擎；中文引擎不可用时改用提示音和界面文字。

识别期间暂停播放；取消、超时或调整定时等指令后，按之前的播放状态恢复。暂停指令会保持暂停。

## 内容与音频

`assets/catalog.json` 是音频目录和字幕时间点，`assets/audio/` 中的 m4a 随包离线可用。

**当前为合成朗读试听素材，童谣并非真人演唱。** 文本和提示音为项目原创。商业发布前应使用具有分发授权的正式音频，并核实所用声音的许可。

在 macOS 上可重新生成试听内容：

```sh
python3 scripts/generate_audio.py
```

该脚本使用系统 `say` 的 Samantha 英语声音和 `afconvert`，不需要 API key。生成器包含全部原创文本，并由实际音频长度计算字幕时间点。

## 结构

- `lib/controllers/`：播放、收藏、定时、语音会话。
- `lib/services/`：音频引擎接口、just_audio 实现、语音命令解析。
- `lib/services/wake_word_detector.dart`：本地唤醒模型、PCM 采集、独立推理线程及麦克风释放。
- `lib/services/assistant_speech.dart`：中文语音回应及无可用引擎时的提示音。
- `lib/ui/`：首页、播放页、语音/定时面板、原创矢量插画。
- `test/`：命令解析、播放队列、定时、收藏、界面测试。

使用的主要库：
[just_audio](https://pub.dev/packages/just_audio)、
[just_audio_background](https://pub.dev/packages/just_audio_background)、
[speech_to_text](https://pub.dev/packages/speech_to_text)、
[sherpa_onnx](https://pub.dev/packages/sherpa_onnx)、
[record](https://pub.dev/packages/record)、
[flutter_tts](https://pub.dev/packages/flutter_tts)、
[shared_preferences](https://pub.dev/packages/shared_preferences)。

已有的建管平台项目未作修改。这个目录可单独使用 Git、构建和发布。
