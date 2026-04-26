## 2026-04-26 - Pencil Node Lookup Mismatch

**Context:** While removing the standalone daily-orders draft, `batch_get` for old node ID `nRM2x` returned "No node with id 'nRM2x'". The old UI index still referenced that ID, but the current Pencil document no longer contained it.

**Impact:** No design loss. The active V3 daily-orders node `eZ2jR` was deleted, and a later name search for `每日订单` returned no nodes.

**Action:** Treat old exported UI index entries as stale unless confirmed in the active Pencil file.

## 2026-04-26 - Flutter Not On PATH

**Context:** Running `flutter test` from PowerShell failed with "The term 'flutter' is not recognized".

**Impact:** The Flutter SDK exists but is not on PATH for this shell.

**Action:** Use `C:\tools\flutter\bin\flutter.bat` and `C:\tools\flutter\bin\dart.bat` for local verification commands in this workspace.
