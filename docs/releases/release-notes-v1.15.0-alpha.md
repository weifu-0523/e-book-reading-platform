# v1.15.0-alpha

**发布日期**：2026-07-21
**类型**：feature（POC,可选引擎)
**上一版本**：v1.14.2-alpha

## 摘要

引入 [Sherpa-ONNX](https://github.com/k2-fsa/sherpa-onnx) 离线神经 TTS 引擎作为系统 TTS 的可选替代，首批嵌入 [MeloTTS-zh_en](https://github.com/myshell-ai/MeloTTS) 模型。用户长期反馈"目前 tts 等基础能力有了，但效果确实一般，而且存在不同手机效果差异明显的情况"，POC 目标是验证离线神经 TTS 能否在中文质量与跨设备一致性上超越系统 TTS。

## 新增功能

### 1. SherpaOnnx MeloTTS 引擎（实验）

- **完全离线**：163MB ONNX 模型 + 6.5MB 词典打包进 APK / 安装包,首次启动拷贝到 `applicationSupportDirectory`(Android) 或 exe 同目录(Windows),之后无网络需求。
- **跨设备一致**:不同 Android 手机(ROM 自带 TTS 引擎各异,华为/小米/OPPO/vivo/Samsung 各家质量参差)使用同一 MeloTTS-zh_en 权重,音质、节奏、发音完全一致。
- **女声标准普通话**:MyShell MIT 许可,22050 Hz 采样率(高于系统 TTS 通常的 16000 Hz),高频细节更丰富。
- **无缝切换**:设置 → 朗读 → TTS 引擎(实验)下拉选「SherpaOnnx MeloTTS」,下一句朗读即生效。切回「系统(默认)」也立即生效。

### 2. TTS Benchmark 工具

- `SherpaOnnxBenchmark.testSentences`:4 句标准测试集(短/中/长/中英混排)。
- `service.benchmark(text)`:`@visibleForTesting` 入口,直接调底层 `generate()` 测 RTF(实时因子) + synth/audio 时长 + 内存峰值 + 模型加载耗时。
- 输出 markdown 表格行供 T9 POC report 使用。

### 3. POC Report 框架

- `docs/research/2026-07-21-sherpa-onnx-tts-poc-report.md`:执行摘要 + benchmark/盲听 placeholder + APK 体积影响 + 架构 + 已知问题 + Phase 2 风险表。

## 重要限制(必读)

### 1. APK / 安装包体积显著增加

| 配置 | 大小 | 增量 |
|---|---|---|
| v1.14.2-alpha Android release | 135 MB | - |
| v1.15.0-alpha Android release(预测) | **~325 MB** | **+190 MB** |
| v1.14.2-alpha Windows installer | ~85 MB | - |
| v1.15.0-alpha Windows installer(预测) | **~255 MB** | **+170 MB** |

主要来自 MeloTTS-zh_en 的 163MB ONNX 模型权重(几乎不可压缩)。Phase 2 W1 计划改为首次启动按需下载(hf-mirror.com 镜像 + 坚果云 WebDAV fallback),APK 回到 ~155MB。

### 2. Windows 桌面 SherpaOnnx 运行时不可用

`sherpa_onnx_windows 1.13.4` 自带的 `onnxruntime.dll` 是 v1.17.1(ORT API v27),sherpa-onnx C API 期望 API v17,加载 `OfflineTts` 时会抛 `OrtApiGetApi` 错误。

- Windows 安装包仍嵌入 sherpa-onnx native DLL + MeloTTS asset(等上游修复后可直接用)
- Windows 用户切换 dropdown 到 SherpaOnnx 朗读会失败,自动 fallback 到系统 TTS(SAPI5)
- Android 端正常工作,是 POC 的主要目标平台

### 3. 首次切换引擎朗读有 1-3 秒延迟

170MB asset 拷贝(写到 applicationSupportDirectory)+ ONNX 权重加载到 native heap。后续启动有 filesystem cache 加速。

### 4. 盲听评估未完成

T9 POC report 留 placeholder 表等待真机 benchmark + 中文母语盲听 A/B 数据填回。Go/No-Go Phase 2 决策依赖这些数据。

## 测试步骤(用户)

### 测试 1:Android 端 SherpaOnnx 朗读(核心)

1. **重要**:卸载旧版本,装 v1.15.0-alpha APK(直接覆盖也行,drift schema v15 不变)
2. 打开任意中文 EPUB
3. 用系统 TTS 朗读一段(基线对比)
4. 设置 → 朗读 → 「TTS 引擎(实验)」下拉 → 选「SherpaOnnx MeloTTS(163MB)」
5. 出现 SnackBar「引擎已切换,重启朗读生效」
6. 重新触发朗读(点「朗读本章」或选段朗读)
7. **首次启动会有 1-3 秒延迟**(屏幕无变化,实际在拷贝模型 + 加载权重)
8. 朗读开始后,**对比音质与系统 TTS 的差异**

### 测试 2:Android 端切回系统 TTS

1. 测试 1 完成后,设置 → 朗读 → 「TTS 引擎(实验)」→ 选「系统(默认)」
2. 触发朗读,应回到原系统 TTS 声音

### 测试 3:Android 端速率/音量(可用,音调不可用)

1. 切到 SherpaOnnx 引擎
2. 设置 → 朗读 → 语速 / 音量滑块 → 调整
3. 触发朗读,**应反映调整**(语速 1.0 = 默认,0.5 = 半速,2.0 = 双倍速)
4. 音调滑块对 SherpaOnnx **无效**(MeloTTS 不支持运行时调音调,接口保留但不生效)

### 测试 4:Windows 端 SherpaOnnx(应 fallback)

1. 装 v1.15.0-alpha Windows installer
2. 打开任意书
3. 设置 → 朗读 → 切到 SherpaOnnx
4. 触发朗读
5. **应仍能听到朗读**(自动 fallback 到系统 SAPI5 TTS),但控制台 / 调试日志会有 sherpa-onnx init 失败警告

### 测试 5:选段朗读(章节级起点)

1. 打开 EPUB
2. 长按选中一段文字
3. 点选区弹片的「朗读」按钮
4. **应从选中文字开始朗读**(不是从章节头)

## 升级路径

直接装 v1.15.0-alpha 覆盖 v1.14.2-alpha 或更早版本。

- drift schema v15 不变(无 DB 迁移)
- versionCode 2012 > v1.14.2 的 2011
- 默认 TTS 引擎仍是「系统(默认)」,需手动切到 SherpaOnnx 才会启用新引擎

## Breaking Change

无。新增 SherpaOnnx 引擎是 opt-in(默认仍 system),不影响现有用户。

## 决策依赖(用户填回 POC report)

完成真机测试后,请把以下数据填回 `docs/research/2026-07-21-sherpa-onnx-tts-poc-report.md` 的 §2 / §3 表格,然后决策 Go/No-Go Phase 2:

1. **Benchmark 数据**(§2):在中端 Android 设备(骁龙 778G / 天玑 8100 以上)跑 `SherpaOnnxBenchmark.run()`,记录每句的 synth/audio/RTF/内存。
   - 门槛:RTF < 0.5 = 移动端可用
2. **盲听评分**(§3):至少 3 位中文母语用户对 4 句做 A/B 盲听(系统 TTS vs SherpaOnnx,顺序随机)。
   - 门槛:综合 ≥ 4.0/5 且与系统 TTS 差距 ≤ 0.3 分

数据满足 → Go Phase 2(模型按需下载 + 多 voice + 正式 settings panel + CosyVoice 桌面)。
不满足 → No-Go,保留 system TTS,评估 edge-tts / 阿里云 CosyVoice API。
