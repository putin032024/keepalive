# ForceBanner (+ Immortalizer)

**Không tắt Immortalizer.**

| Tweak | Việc |
|--------|------|
| **Immortalizer** (giữ nguyên, luôn bật) | Giữ app sống → không miss tin sau 30p |
| **ForceBanner** (tweak này) | Ép **popup/banner** khi Immortalizer đang immortal (hết chỉ-có-tiếng) |

## Cài

1. Immortalizer **vẫn bật**, Zalo vẫn immortal như đang dùng  
2. Cài `ForceBanner` `.deb` (rootless / rootful / roothide)  
3. Respring  
4. **Cài đặt → ForceBanner → Bật**  
5. (Mặc định) **Chỉ app Immortalizer đang bật**  
6. Test nhắn: **popup + tiếng**

## Build

```bash
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless   # Dopamine
make package FINALPACKAGE=1 SCHEME=roothide                 # RootHide
```

GitHub Actions: artifact `forcebanner-rootless` / `rootful` / `roothide`.

## Source

- `Tweak.x` — toàn bộ logic ép banner (SpringBoard + in-app)
- Đọc list Immortalizer: `ImmortalForegroundBundleIDs`
