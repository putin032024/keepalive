# KeepAlive trên Dopamine2-RootHide

## Vì sao cài xong “chả thấy đâu”

1. **Không có app Settings “KeepAlive”** — bản CI **không** có PreferenceBundle.  
2. Menu **chỉ** hiện khi **hold icon app** (Zalo…) — không phải trong Cài đặt.  
3. Deb GitHub build là **rootless** (`/var/jb`). RootHide **không** đọc path đó trực tiếp → **bắt buộc** RootHide Patcher (hoặc build `roothide`).  
4. Patcher xong mà **chưa respring** / dylib **không vào SpringBoard** → hold icon **không** có dòng KeepAlive.

## Cài đúng (Dopamine2-roothide)

1. Jailbreak bằng **Dopamine2-roothide**, mở **RootHide Manager**, bootstrap ổn.  
2. Cài **ElleKit** / injection (thường bootstrap có).  
3. Tải deb rootless:  
   `com.local.keepalive_*_iphoneos-arm64.deb`  
4. Mở **RootHide Patcher** → chọn deb → **Convert** → **Share / Open in Sileo** → cài.  
5. **Respring** (Sileo / `sbreload` / RootHide).  
6. **Gỡ Immortalizer** nếu còn.  
7. Hold icon **Zalo** (giữ lâu) → nhìn list action:  
   **Bật KeepAlive (giữ nền + popup)**  
   (nằm cùng chỗ Share / Remove App, **không** phải Edit Home Screen).

## Kiểm tra dylib đã vào máy chưa (Filza / SSH)

RootHide path **random** (jbroot). Trong Filza bật RootHide / jb:

Tìm:
```
.../Library/MobileSubstrate/DynamicLibraries/KeepAlive.dylib
.../Library/MobileSubstrate/DynamicLibraries/KeepAlive.plist
```

Hoặc SSH sau jb:
```bash
# nếu có lệnh jbroot
find $(jbroot)/Library/MobileSubstrate/DynamicLibraries -name 'KeepAlive*' 2>/dev/null
# hoặc
find /var/containers -name 'KeepAlive.dylib' 2>/dev/null | head
```

**Không thấy file** → cài fail / patcher fail / cài nhầm deb chưa convert.  
**Có file** nhưng hold không thấy menu → dylib **chưa load SpringBoard** → respring lại, check ElleKit.

## Package đã cài?

```bash
dpkg -l | grep -i keepalive
```

## Immortalizer

Đang dùng Immortalizer + KeepAlive → gỡ Immortalizer, chỉ giữ KeepAlive, respring.

## Patcher “hit or miss”

RootHide doc: Patcher **không** 100%. Nếu convert xong vẫn không load:

- Cài lại bootstrap / ElleKit  
- Thử deb convert lại  
- Hoặc build native `THEOS_PACKAGE_SCHEME=roothide` (cần roothide/theos)

## Tóm tắt 1 dòng

**Patcher → Sileo cài → respring → hold icon app → Bật KeepAlive.**  
Không có icon app KeepAlive trên home.
