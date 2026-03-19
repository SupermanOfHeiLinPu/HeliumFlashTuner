# HeliumFlash Tuner

**HeliumFlash Tuner** 是一款基于 **Flutter 3.41.5** 和 **JUCE 8.0.12** 构建的跨平台专业级调音器，支持 Android、macOS 和 Ubuntu（Linux）。

---

## 功能特性

- **全音域覆盖**：支持钢琴 88 键完整音域（A0 = 27.5 Hz ~ C8 ≈ 4186 Hz）。
- **环境噪音过滤**：内置噪音门（Noise Gate），自动过滤低于阈值的环境杂音。
- **实时示波器**：
  - 居中显示当前声音的实时波形。
  - 中心线表示当前声音最近的音高（参考频率）。
  - 中心线附近有 **±5 cents** 绿色区域。
  - 声音频率超出 ±5 cents 时，波形到绿色区域之间填充**红色**。
- **顶部信息栏**：
  - 左侧显示当前频率（Hz）。
  - 中央显示音名（大字体）。
  - 右侧显示 ±cents 偏差值。
- **设置菜单**（右上角）：
  - A4 标准音频率（默认 440 Hz，可调范围 420–460 Hz）。
  - 音名记号法：**科学音高记号法**（C4, A4 …）或 **亥姆霍兹音高记号法**（c', a' …）。
- **深色主题**：整体配色方案为深色 GitHub 风格。

---

## 项目结构

```
HeliumFlashTuner/
├── flutter_app/          # Flutter 用户界面（Dart）
│   ├── lib/
│   │   ├── main.dart                      # 应用入口
│   │   ├── models/tuner_model.dart        # 状态管理（ChangeNotifier）
│   │   ├── screens/tuner_screen.dart      # 主界面 + 设置对话框
│   │   ├── services/
│   │   │   ├── audio_bridge.dart          # dart:ffi 桥接原生库
│   │   │   └── note_utils.dart            # 音名 / 频率 / cents 工具
│   │   └── widgets/oscilloscope_painter.dart  # 示波器 CustomPainter
│   ├── android/                           # Android 平台文件
│   ├── macos/                             # macOS 平台文件（含麦克风权限）
│   ├── linux/                             # Linux 平台文件
│   └── test/                             # 单元测试
│       └── note_utils_test.dart
│
├── native/               # JUCE 原生音频库（C++17）
│   ├── CMakeLists.txt                     # CMake 构建配置
│   ├── Source/
│   │   ├── PitchDetector.h/.cpp           # YIN 基频检测算法
│   │   ├── TunerProcessor.h/.cpp          # JUCE 音频设备管理 + 噪音门
│   │   └── TunerBridge.h/.cpp             # C API（供 Flutter FFI 调用）
│   └── scripts/
│       ├── build_android.sh               # Android 交叉编译脚本
│       ├── build_macos.sh                 # macOS Universal 编译脚本
│       └── build_linux.sh                 # Linux x86_64 编译脚本
│
└── README.md
```

---

## 环境要求

| 工具 | 版本 |
|------|------|
| Flutter | 3.41.5 |
| Dart | ≥ 3.0.0 |
| JUCE | 8.0.12 |
| CMake | ≥ 3.22 |
| C++ 编译器 | 支持 C++17（GCC 11+ / Clang 14+ / MSVC 2022+） |
| Android NDK | r25 或更高（仅构建 Android 版本时需要） |
| Xcode | 14+ （仅构建 macOS 版本时需要） |

---

## 构建步骤

### 第一步：克隆仓库并获取 JUCE

```bash
git clone https://github.com/SupermanOfHeiLinPu/HeliumFlashTuner.git
cd HeliumFlashTuner

# 将 JUCE 8.0.12 克隆到 native/JUCE 目录
git clone --depth 1 --branch 8.0.12 https://github.com/juce-framework/JUCE.git native/JUCE
```

> **提示**：也可以将 JUCE 放在其他路径，在 CMake 命令中传入 `-DJUCE_PATH=/your/path/to/JUCE`。

---

### 第二步：编译 JUCE 原生库

根据目标平台，选择以下其中一种方式：

#### Linux (Ubuntu)

```bash
# 安装依赖
sudo apt-get install -y \
    build-essential cmake \
    libasound2-dev libx11-dev libxext-dev libxinerama-dev \
    libxrandr-dev libxcursor-dev libfreetype6-dev \
    libgl1-mesa-dev

# 编译
bash native/scripts/build_linux.sh

# 将编译好的 .so 文件复制到 Flutter Linux bundle
cp native/build/linux/libhelium_flash_tuner.so \
   flutter_app/linux/bundle/lib/
```

#### macOS

```bash
# 编译 arm64 + x86_64 通用二进制
bash native/scripts/build_macos.sh

# 将编译好的 .dylib 文件复制到 Flutter macOS bundle
cp native/build/macos_universal/libhelium_flash_tuner.dylib \
   flutter_app/macos/Runner/
```

#### Android

```bash
# 设置 NDK 路径（示例）
export ANDROID_NDK_ROOT=/path/to/ndk/25.x.xxxxx

# 编译（arm64-v8a、armeabi-v7a、x86_64 三个 ABI）
bash native/scripts/build_android.sh

# 将编译好的 .so 文件复制到 Flutter Android 项目
for abi in arm64-v8a armeabi-v7a x86_64; do
    cp native/build/android/$abi/libhelium_flash_tuner.so \
       flutter_app/android/app/src/main/jniLibs/$abi/
done
```

---

### 第三步：安装 Flutter 依赖

```bash
cd flutter_app
flutter pub get
```

---

### 第四步：运行 / 打包

#### 在 Ubuntu 上运行

```bash
cd flutter_app
flutter run -d linux
```

#### 在 macOS 上运行

```bash
cd flutter_app
flutter run -d macos
```

#### 在 Android 上运行

```bash
cd flutter_app
flutter run -d android
```

#### 打包发布版本

```bash
# Android APK
flutter build apk --release

# Android AAB（发布到 Google Play）
flutter build appbundle --release

# macOS .app
flutter build macos --release

# Linux bundle
flutter build linux --release
```

---

## 运行单元测试

```bash
cd flutter_app
flutter test
```

测试文件位于 `flutter_app/test/note_utils_test.dart`，覆盖了 `NoteUtils` 工具类（频率 ↔ MIDI、cents 计算、科学音高记号法、亥姆霍兹音高记号法）。

---

## 技术实现说明

### 音高检测（YIN 算法）

原生库使用 **YIN 算法**（de Cheveigné & Kawahara, 2002）进行基频估计：

1. **差异函数**（Difference Function）：计算信号的自相关差异。
2. **累积均值归一化**（Cumulative Mean Normalisation）：降低低 tau 的偏差。
3. **绝对阈值检测**（Absolute Threshold）：以 0.15 为阈值查找候选周期。
4. **抛物线插值**（Parabolic Interpolation）：提高频率估计的亚样本精度。

检测范围：**27.5 Hz（A0）～ 4200 Hz（C8 以上）**，覆盖钢琴完整 88 键。

### 噪音过滤

对每个音频块计算 RMS（均方根）能量，若低于配置的噪音门阈值（dBFS），则忽略该块并清空检测结果，有效过滤环境背景噪音。

### FFI 通信

Flutter 通过 **dart:ffi** 直接调用 JUCE 编译的共享库（`.so` / `.dylib`），以轮询方式（约 60 fps）获取最新的频率、cents、MIDI 音符号和波形数据，无 JNI 或 Platform Channel 开销。

### 示波器渲染

示波器使用 Flutter `CustomPainter` 实现：
- **实时波形**：从原生库获取最新 1024 个采样点。
- **绿色区域**：以显示高度的 ±7% 作为 ±5 cents 的视觉范围。
- **颜色逻辑**：
  - 频率偏差 ≤ ±5 cents → 波形填充**绿色**。
  - 频率偏差 > ±5 cents → 超出绿色区域的部分填充**红色**，区域内仍为绿色。

---

## 许可证

本项目基于 [LICENSE](LICENSE) 文件中的许可证授权。

JUCE 遵循其自身许可条款，请参阅 [JUCE License](https://juce.com/juce-8-licence/)。

---

## 贡献

欢迎提交 Issue 和 Pull Request！
