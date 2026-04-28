# QRSCAN 电脑端备份接收工具（第一版）

用途：
- 在电脑上接收手机 `发送` 出来的数据库快照（无云场景）。

## 环境

- Python 3.9+
- 依赖：`requests`

安装依赖：

```bash
pip install requests
```

## 使用

1. 手机打开 `数据备份` -> `发送`，生成二维码与连接码。  
2. 在电脑运行：

```bash
python receive_from_phone.py --code "<连接码字符串>" --output "C:/backups/qrscan"
```

说明：
- `--code` 是二维码里完整连接码内容（可在手机点“复制二维码内容”后粘贴）
- `--output` 是电脑保存目录（默认当前目录）

## 输出

- 成功后会保存：
  - `jiemei-backup-YYYYMMDD-HHMMSS.sqlite`
  - `jiemei-backup-YYYYMMDD-HHMMSS.backup_info.json`

## 注意

- 手机和电脑必须在同一局域网。
- 这是第一版 CLI 工具，后续可升级为桌面 GUI（扫码/配对码输入）。
