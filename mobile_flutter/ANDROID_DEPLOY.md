# Flutter Android 部署教程

本文档记录本项目 `mobile_flutter` 的 Android 真机部署流程，基于当前仓库的实际环境整理，可用于课程演示和组内交接。

## 1. 当前部署方案

本项目采用：

- `Flutter` 作为移动端前端
- `Docker Compose` 启动后端服务
- Android 真机通过 `adb reverse` 访问本机 Docker 中的后端

也就是说：

- 手机端运行的是独立的 Flutter App
- 但演示时仍然依赖本机后端服务
- 不需要单独部署云服务器

## 2. 前置条件

需要提前准备：

- 已安装 `Flutter`
- 已安装 `Android SDK`
- 已连接 Android 真机
- 真机已开启：
  - 开发者模式
  - USB 调试
- 本机已安装并启动 `Docker Desktop`

## 3. 启动后端

在项目根目录运行：

```powershell
docker compose up -d db redis backend
```

确认容器状态：

```powershell
docker compose ps
```

正常情况下应至少看到：

- `interview-db`
- `interview-redis`
- `interview-backend`

检查后端健康状态：

```powershell
curl.exe -s http://localhost:8000/health
```

如果启动成功，通常会返回类似：

```json
{"status":"ok","version":"1.0.0","environment":"development","llm_model":"deepseek-v4-pro"}
```

## 4. 连接 Android 设备

先查看 Flutter 是否识别到手机：

```powershell
flutter devices
```

如果识别成功，会看到类似：

```text
Mi 10 (mobile) • 43020770 • android-arm64 • Android 12
```

其中 `43020770` 是设备 ID，不同电脑/设备可能不同。

## 5. 让手机访问本机后端

由于后端跑在本机 Docker 中，手机不能直接访问 Windows 的 `localhost`，因此要使用 `adb reverse`：

```powershell
adb -s <设备ID> reverse tcp:8000 tcp:8000
```

例如：

```powershell
adb -s 43020770 reverse tcp:8000 tcp:8000
```

如果本机 `adb` 不在 PATH，可以直接使用完整路径，例如：

```powershell
C:\Users\Clumsy\AppData\Local\Android\Sdk\platform-tools\adb.exe -s 43020770 reverse tcp:8000 tcp:8000
```

这样手机中的 `http://127.0.0.1:8000` 就会映射到电脑上的后端服务。

## 6. 运行 Flutter Android 端

进入 Flutter 项目目录：

```powershell
cd mobile_flutter
```

使用以下命令运行到真机：

```powershell
flutter run -d <设备ID> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

例如：

```powershell
flutter run -d 43020770 --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

说明：

- `API_BASE_URL` 必须传入 `http://127.0.0.1:8000`
- 这里的 `127.0.0.1` 指的是手机通过 `adb reverse` 映射后的本地端口

## 7. Android 端已做的适配

当前 Flutter Android 端已经补充：

- 网络权限 `INTERNET`
- 麦克风权限 `RECORD_AUDIO`
- 允许明文 HTTP：`usesCleartextTraffic="true"`

相关文件：

- [AndroidManifest.xml](D:/2026Spring/Innovative%20Experiment/Exp5/innovation-GroupFinalProject-team8/mobile_flutter/android/app/src/main/AndroidManifest.xml)

## 8. 如果构建卡在 Kotlin/Gradle 缓存

本项目在真机部署时遇到过 Kotlin 增量编译缓存问题。当前已经在：

- [gradle.properties](D:/2026Spring/Innovative%20Experiment/Exp5/innovation-GroupFinalProject-team8/mobile_flutter/android/gradle.properties)

中加入：

```properties
kotlin.incremental=false
kotlin.compiler.execution.strategy=in-process
```

如果仍然失败，可以按下面顺序清理：

```powershell
flutter clean
```

```powershell
cd android
.\gradlew.bat --stop
cd ..
```

然后删除缓存目录：

```powershell
Remove-Item build -Recurse -Force
Remove-Item android\.gradle -Recurse -Force
```

再重新执行：

```powershell
flutter run -d <设备ID> --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## 9. 常见问题

### 9.1 `flutter devices` 看不到手机

检查：

- 手机是否打开 USB 调试
- 数据线是否支持数据传输
- 是否已在手机上确认 USB 调试授权
- Android 驱动是否正常

### 9.2 手机打开 App 后无法请求后端

检查：

- `docker compose ps` 中 `backend` 是否为 `Up`
- `curl.exe -s http://localhost:8000/health` 是否有返回
- 是否执行了 `adb reverse tcp:8000 tcp:8000`
- `flutter run` 是否带了：

```powershell
--dart-define=API_BASE_URL=http://127.0.0.1:8000
```

### 9.3 录音功能不可用

检查：

- 首次启动时是否允许麦克风权限
- AndroidManifest 是否包含 `RECORD_AUDIO`

## 10. 演示建议

课程演示时建议按下面顺序执行：

1. 在项目根目录启动后端容器
2. 检查 `/health`
3. 连接手机并执行 `adb reverse`
4. 进入 `mobile_flutter` 运行 `flutter run`
5. 在手机上完成登录、面试、报告查看流程

## 11. 备注

当前 `mobile_flutter` 已移除不需要的平台目录，仅保留 Android 方向开发所需内容。

如果后续要改成真正脱离电脑的方案，则需要把后端部署到公网或局域网可访问服务，而不是继续依赖 `adb reverse`。
