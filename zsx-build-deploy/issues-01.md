# APK Build Issues #01

> 构建日期: 2026-05-27
> 构建: frances-allen-v1.2.0-build22-20260527.apk
> 平台: WSL2 + Windows Flutter SDK (cmd.exe 构建)

---

## Issue 1: 字体文件找不到 — `fonts/` 目录遗漏

### 现象

```
Target aot_android_asset_bundle failed: PathNotFoundException:
Cannot copy file to '.../flutter_assets/fonts/inter/Inter-Bold.ttf',
path = 'C:\Users\codezsx\frances-allen\mobile\fonts\inter\Inter-Bold.ttf'
(OS Error: 系统找不到指定的文件)
```

### 原因

从 WSL 同步源码到 Windows 副本 (`C:\Users\codezsx\frances-allen\mobile\`) 时，只同步了 `lib/`、`assets/`、`android/`、`pubspec.yaml`，遗漏了项目根目录下的 `fonts/` 文件夹。

`pubspec.yaml` 中字体声明：

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: fonts/inter/Inter-Regular.ttf
        - asset: fonts/inter/Inter-Medium.ttf
        - asset: fonts/inter/Inter-SemiBold.ttf
        - asset: fonts/inter/Inter-Bold.ttf
```

Flutter 从**项目根目录**解析字体路径，不是从 `assets/` 下查找。`fonts/` 和 `assets/` 是项目根下平级的两个目录，都需要同步。

### 解决方案

补同步 `fonts/` 目录：

```bash
rm -rf /mnt/c/Users/codezsx/frances-allen/mobile/fonts
cp -r /home/codezsx/frances-allen/mobile/fonts /mnt/c/Users/codezsx/frances-allen/mobile/fonts
```

### 预防

WSL→Windows 同步清单应包含**所有项目根级源码目录**，不只是 `lib/` 和 `assets/`：

- `lib/`
- `assets/`
- `fonts/`（如存在）
- `android/`
- `pubspec.yaml`

---

## Issue 2: Kotlin 编译器无法 fork Java 进程 (CreateProcess error=1920)

### 现象

```
FAILURE: Build failed with an exception.

Execution failed for task ':shared_preferences_android:compileReleaseKotlin'.
> Cannot run program "C:\Program Files\Java\jdk-17\bin\java":
  CreateProcess error=1920, 系统无法访问此文件。
```

发生在 `flutter build apk --release` 和 `--debug` 两种模式下，`cmd.exe` 和 PowerShell 均复现。

### 原因

Gradle 的 Kotlin 编译器插件默认以**独立 daemon 进程**方式运行（`kotlin.compiler.execution.strategy=daemon`），即 Gradle 会尝试 `CreateProcess` 启动一个新的 `java.exe` 子进程来执行 Kotlin 编译。

Windows 安全机制（Windows Defender 实时保护 / Controlled Folder Access）拦截了 Gradle daemon 对 `C:\Program Files\Java\jdk-17\bin\java.exe` 的 `CreateProcess` 调用，返回系统错误码 1920。

注意：
- 直接在终端运行 `java -version` 正常，因为终端进程本身已经加载了 java
- Gradle 本身运行正常（JVM 已启动），问题仅在 Kotlin 编译器试图**另外 fork** 一个子 JVM 时触发

### 解决方案

在 `android/gradle.properties` 中将 Kotlin 编译器切换为**进程内模式**，避免 fork：

```properties
kotlin.compiler.execution.strategy=in-process
```

完整变更：

```diff
 org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G ...
+org.gradle.java.home=C\:\\Program Files\\Java\\jdk-17
+kotlin.compiler.execution.strategy=in-process
 android.useAndroidX=true
```

- `kotlin.compiler.execution.strategy=in-process` — Kotlin 编译器在 Gradle 的 JVM 内直接运行，不 fork 新进程
- `org.gradle.java.home` — 显式指定 JDK 路径，避免 Gradle 自动探测时落入不可访问的路径

### 替代方案（未采用）

- **无空格路径的 JDK**: `C:\Program Files\Java\jdk1.8.0_202` 路径不含空格，但 JDK 8 可能与新版 Gradle/Kotlin 不兼容
- **关闭 Windows Defender 实时保护**: 不安全，不推荐
- **以管理员运行**: 无效，这是 Defender 的文件访问控制，非 UAC 问题

### 预防

如果在其他机器上遇到同样的 `CreateProcess error=1920`，直接加 `kotlin.compiler.execution.strategy=in-process` 即可。此配置对构建产物无任何影响，仅改变编译器进程模型。

---

## 构建命令速查

```bash
# 1. 同步源码 (WSL → Windows)
rm -rf /mnt/c/Users/codezsx/<project>/mobile/{lib,assets,fonts,android}
cp -r /home/codezsx/<project>/mobile/{lib,assets,fonts,android} /mnt/c/Users/codezsx/<project>/mobile/
cp /home/codezsx/<project>/mobile/pubspec.yaml /mnt/c/Users/codezsx/<project>/mobile/

# 2. 生成自定义图标
cmd.exe /c "cd /d C:\Users\codezsx\<project>\mobile && flutter pub run flutter_launcher_icons"

# 3. 构建 APK
cmd.exe /c "cd /d C:\Users\codezsx\<project>\mobile && flutter build apk --release"

# 4. 拷贝产物并更新 build_number
APK_NAME="<project>-v<ver>-build<N>-<date>.apk"
cp /mnt/c/Users/codezsx/<project>/mobile/build/app/outputs/flutter-apk/app-release.apk \
   /home/codezsx/<project>/zsx-build-deploy/$APK_NAME
cp .../app-release.apk .../zsx-build-deploy/<project>-latest.apk
echo $((N+1)) > zsx-build-deploy/build_number
```
