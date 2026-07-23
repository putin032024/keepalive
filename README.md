# KeepAlive (AlwaysAlive)

Jailbreak tweak: **giữ app sống** (Immortalizer-style) + **ép notification banner/popup**.

Repo: https://github.com/putin032024/keepalive

## Cài nhanh (sau khi Actions build xong)

1. GitHub → tab **Actions** → workflow **Build KeepAlive** → artifact  
   - `keepalive-rootless` → Dopamine / rootless  
   - `keepalive-rootful` → rootful  
2. Tải `.deb` → Filza / Sileo cài → respring  
3. **Tắt Immortalizer** (tránh conflict)  
4. Hold icon app → **Bật AlwaysAlive**  
5. Settings → AlwaysAlive → bật **Ép hiện popup/banner**

## Build local (Mac + Theos)

```bash
export THEOS=~/theos
# Dopamine
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
# Rootful
make package FINALPACKAGE=1 SCHEME=rootful
```

## Source map

| File | Việc |
|------|------|
| `TweakScene.x` | Giữ process / chặn deactivate |
| `TweakNotifications.x` | Ép banner (server + app) |
| `TweakIcons.x` | Menu hold icon, chống kill |
| `AAConfig.*` | Prefs / list immortal |
| `prefs/` | Settings UI |
| `.github/workflows/build.yml` | CI build deb |

## GitHub Actions

- Push `main` / PR / **Run workflow** → build  
- Artifacts: `.deb` rootless + rootful  
- GitHub **Release** → tự attach `.deb`
