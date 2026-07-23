# KeepAlive

**Một tweak duy nhất** (thay Immortalizer):

1. **Giữ app sống** — hold icon → Bật KeepAlive → **để bật** (đừng tắt, tránh mất notif sau ~30p)  
2. **Popup bắt buộc** — khi app immortal, **luôn** ép banner/popup (core feature, không có nút tắt, không cần tweak phụ)

## Cài

1. **Gỡ Immortalizer** (tránh conflict — `Conflicts` trong control)  
2. Cài KeepAlive `.deb` → respring  
3. Hold Zalo / Messenger… → **Bật KeepAlive**  
4. Test: nhắn tới = **popup + tiếng**, app vẫn sống nền  

## Build

Chỉ **1 bản rootless** (Dopamine / RootHide đều cài được):

```bash
make package FINALPACKAGE=1
```

GitHub Actions → artifact **`KeepAlive-rootless`** → tải file `.deb`.

## Source

| File | Việc |
|------|------|
| `Tweak.x` | Immortal + ép popup (cùng file) |
| `KAConfig.*` | List app immortal |
| `prefs/` | Bật/tắt tweak |
