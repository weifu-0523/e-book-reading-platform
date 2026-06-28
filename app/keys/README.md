# Android Release Signing

本目录被 `.gitignore` 保护。本地构建 release APK 前，需要先生成 keystore：

## 1. 生成 keystore

```bash
keytool -genkey -v \
  -keystore app/keys/zhiyue-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias zhiyue
```

按提示输入 keystore 密码、姓名/组织等（个人项目可填任意）。

## 2. 创建 keystore.properties

新建 `app/keys/keystore.properties`（不要提交）：

```properties
storePassword=<你刚才输入的 keystore 密码>
keyPassword=<你刚才输入的 key 密码（通常与 storePassword 相同）>
keyAlias=zhiyue
storeFile=app/keys/zhiyue-release.jks
```

## 3. 验证

```bash
cd app && flutter build apk --release
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

应输出 `Verified using v1 scheme` / `Verified using v2 scheme`。
