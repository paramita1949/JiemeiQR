# Android Release Signing

## Why This Exists

Android only allows an APK to overwrite an installed app when both APKs use the same `applicationId` and the same signing certificate.

The app package is:

```text
com.jiemei.hualushui
```

If a previous APK was signed with a different key, Android/vivo will show an error similar to:

```text
软件包与现有软件包存在冲突
安装包的开发者签名有异常
```

That is expected Android behavior. It cannot be fixed by increasing the version number.

## One-Time User Action

If the installed app was signed by an older debug or unknown key:

1. Export or migrate app data first if needed.
2. Uninstall the old app from the phone.
3. Install the first APK signed with the stable release key.

After that, future APKs signed by the same release key can be installed as normal upgrades.

## Local Release Signing File

Create this file locally:

```text
flutter_app/android/key.properties
```

Do not commit this file. It is ignored by git.

Example:

```properties
storeFile=jiemei-release.jks
storePassword=your-store-password
keyAlias=jiemei
keyPassword=your-key-password
```

The keystore file should be placed at:

```text
flutter_app/android/jiemei-release.jks
```

## Generate A Keystore

Run from the repository root:

```powershell
keytool -genkeypair `
  -v `
  -keystore flutter_app/android/jiemei-release.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias jiemei
```

Back up this keystore and its passwords. Losing it means future APKs cannot upgrade the installed app.

## GitHub Actions Secrets

GitHub Actions requires these repository secrets:

```text
RELEASE_KEYSTORE_BASE64
RELEASE_KEYSTORE_PASSWORD
RELEASE_KEY_ALIAS
RELEASE_KEY_PASSWORD
```

Create `RELEASE_KEYSTORE_BASE64` from PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("flutter_app/android/jiemei-release.jks"))
```

Then store the printed value in the GitHub repository secret.

The workflow writes `flutter_app/android/key.properties` during CI and signs the release APK with the stable release key.
