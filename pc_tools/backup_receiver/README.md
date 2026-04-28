# QRSCAN 电脑端备份接收工具

用途：
- 在电脑上接收手机 `发送` 出来的数据库快照（无云场景）。
- 支持 `命令行` 与 `GUI` 两种模式。

## 环境

- Python 3.9+
- 依赖：`requests`

安装依赖：

```bash
pip install requests
```

## 使用

1. 手机打开 `数据备份` -> `发送`，生成二维码与连接码。  
2. 命令行模式（CLI）：

```bash
python receive_from_phone.py --code "<连接码字符串>" --output "C:/backups/qrscan"
```

3. 图形界面模式（GUI）：

```bash
python receive_gui.py
```

在 GUI 内粘贴连接码并选择目录后，点击 `开始接收`。

参数说明（CLI）：
- `--code`：二维码里完整连接码内容（可在手机点“复制二维码内容”后粘贴）
- `--output`：电脑保存目录（默认当前目录）

## 输出

- 成功后会保存：
  - `jiemei-backup-YYYYMMDD-HHMMSS.sqlite`
  - `jiemei-backup-YYYYMMDD-HHMMSS.backup_info.json`

## 注意

- 手机和电脑必须在同一局域网。
- 建议先用 CLI 验证链路，再用 GUI 给一线人员使用。
