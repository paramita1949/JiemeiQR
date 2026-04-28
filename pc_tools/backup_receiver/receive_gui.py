#!/usr/bin/env python3
from __future__ import annotations

import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox

from client import receive_backup


class ReceiverGui:
    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("QRSCAN 电脑接收")
        self.root.geometry("620x320")
        self.root.resizable(False, False)

        self.code_var = tk.StringVar()
        self.output_var = tk.StringVar(value=str(Path.cwd()))
        self.status_var = tk.StringVar(value="等待输入连接码")
        self.receiving = False

        self._build()

    def _build(self) -> None:
        pad = {"padx": 14, "pady": 8}

        tk.Label(
            self.root,
            text="连接码（手机“复制二维码内容”后粘贴）",
            anchor="w",
            font=("Microsoft YaHei", 11, "bold"),
        ).pack(fill="x", **pad)

        self.code_entry = tk.Entry(self.root, textvariable=self.code_var, font=("Consolas", 10))
        self.code_entry.pack(fill="x", padx=14)

        tk.Label(
            self.root,
            text="保存目录",
            anchor="w",
            font=("Microsoft YaHei", 11, "bold"),
        ).pack(fill="x", **pad)

        output_row = tk.Frame(self.root)
        output_row.pack(fill="x", padx=14)
        tk.Entry(output_row, textvariable=self.output_var).pack(side="left", fill="x", expand=True)
        tk.Button(output_row, text="选择", width=8, command=self._pick_output).pack(side="left", padx=8)

        button_row = tk.Frame(self.root)
        button_row.pack(fill="x", padx=14, pady=20)
        self.receive_button = tk.Button(
            button_row,
            text="开始接收",
            width=14,
            command=self._start_receive,
            bg="#1f6bff",
            fg="white",
        )
        self.receive_button.pack(side="left")
        tk.Button(
            button_row,
            text="退出",
            width=10,
            command=self.root.destroy,
        ).pack(side="left", padx=8)

        tk.Label(
            self.root,
            textvariable=self.status_var,
            anchor="w",
            fg="#1f6bff",
            font=("Microsoft YaHei", 10),
        ).pack(fill="x", padx=14)

    def _pick_output(self) -> None:
        directory = filedialog.askdirectory(initialdir=self.output_var.get())
        if directory:
            self.output_var.set(directory)

    def _start_receive(self) -> None:
        if self.receiving:
            return
        code = self.code_var.get().strip()
        if not code:
            messagebox.showwarning("提示", "请先粘贴连接码")
            return
        self.receiving = True
        self.receive_button.config(state="disabled")
        self.status_var.set("正在连接手机并下载备份...")
        thread = threading.Thread(target=self._receive_worker, daemon=True)
        thread.start()

    def _receive_worker(self) -> None:
        code = self.code_var.get().strip()
        output_dir = Path(self.output_var.get()).resolve()
        try:
            result = receive_backup(code, output_dir)
            self.root.after(0, lambda: self._on_success(result))
        except Exception as exc:  # noqa: BLE001
            self.root.after(0, lambda: self._on_error(str(exc)))

    def _on_success(self, output: Path) -> None:
        self.receiving = False
        self.receive_button.config(state="normal")
        self.status_var.set(f"接收完成：{output}")
        messagebox.showinfo("完成", f"备份已保存到：\n{output}")

    def _on_error(self, message: str) -> None:
        self.receiving = False
        self.receive_button.config(state="normal")
        self.status_var.set("接收失败")
        messagebox.showerror("失败", message)


def main() -> None:
    root = tk.Tk()
    ReceiverGui(root)
    root.mainloop()


if __name__ == "__main__":
    main()
