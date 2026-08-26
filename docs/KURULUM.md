# Puckyto — Kurulum ve Build Kılavuzu

Puckyto; çoklu terminal ve yapay zeka ajanı (Claude / ChatGPT / Gemini) yöneten bir macOS uygulamasıdır. Bu belge sıfırdan kurulumu, derlemeyi ve sorun gidermeyi anlatır.

*English version: [SETUP.md](SETUP.md)*

## 1. Gereksinimler

| Gereksinim | Sürüm | Not |
|---|---|---|
| macOS | 14.0+ (Sonoma ve üzeri) | Apple Silicon ve Intel desteklenir |
| Swift | 5.9+ | Xcode 15+ veya Command Line Tools ile gelir |
| Git | herhangi | SwiftTerm bağımlılığını indirmek için |
| İnternet | ilk derlemede | SPM, SwiftTerm paketini GitHub'dan çeker |

Swift'in kurulu olduğunu doğrula:

```bash
swift --version    # "Apple Swift version 5.9" veya üzeri görmelisin
```

Yoksa: `xcode-select --install` (Command Line Tools yeterlidir, tam Xcode şart değil).

### AI ajanları için CLI'ler (opsiyonel ama önerilir)

Uygulama terminal yöneticisi olarak CLI'siz de çalışır; ajan başlatmak için ilgili CLI kurulu olmalı:

```bash
# Claude Code (önerilen)
npm install -g @anthropic-ai/claude-code    # veya: brew install claude
claude --version

# OpenAI Codex CLI (ChatGPT ajanları için)
npm install -g @openai/codex

# Gemini CLI
npm install -g @google/gemini-cli
```

Kurulu olmayanlar uygulamada ⚠️ ile işaretlenir; sonradan kurup Agents panelinden "Yeniden Tara" diyebilirsin.

### Nerd Font (önerilir)

Prompt'unda powerlevel10k / starship ikonları varsa bir Nerd Font kurulu olmalı (uygulama otomatik algılar):

```bash
brew install --cask font-meslo-lg-nerd-font
```

## 2. Kaynağı Alma

```bash
git clone <repo-url> puckyto
cd puckyto
```

(Elinde zaten klasör varsa bu adımı atla.)

## 3. Derleme

### Yöntem A — Tek komut (önerilen): .app paketi

```bash
./scripts/build-app.sh
open "build/Puckyto.app"
```

Script sırasıyla: `swift build -c release` çalıştırır → çıktıyı `build/Puckyto.app` paketine sarar (Info.plist ile) → ad-hoc imzalar. **Bildirimlerin çalışması için uygulamayı bu .app paketi üzerinden açmalısın.**

Debug derlemesi istersen: `./scripts/build-app.sh debug`

### Yöntem B — Elle SPM

```bash
swift build -c release
.build/release/Puckyto        # doğrudan çalıştırma (bildirim izinleri kısıtlı olur)
```

### Kalıcı kullanım için Applications'a kopyalama

```bash
cp -R "build/Puckyto.app" /Applications/
```

## 4. İlk Açılış

1. Uygulama örnek bir workspace ve iki terminalle açılır.
2. macOS **bildirim izni** sorar — ajan bittiğinde/onay beklediğinde haber almak için izin ver.
3. Bir terminale tıkla, Agents panelinden ajanı yapılandır, 🧠 ile başlat.

## 5. Veri Konumları

| Ne | Nerede |
|---|---|
| Ayarlar, workspace'ler, ajanlar | `~/Library/Application Support/dev.puckyto.app/state.json` |
| Wiki notları | `.../dev.puckyto.app/wiki/<terminalID>/*.md` |
| Ajan hafızaları | `.../dev.puckyto.app/agents/<ajanID>/MEMORY.md` |
| Ortak panolar | `.../dev.puckyto.app/boards/<workspaceID>.md` |
| Özel temalar | `.../dev.puckyto.app/themes/*.json` |
| Koordinatör kuyruğu | `.../dev.puckyto.app/queue/<workspaceID>/` |

Yedeklemek için bu klasörü kopyalaman yeterli. Uygulamayı sıfırlamak için (terminaller kapalıyken) `state.json`'u sil.

## 6. Uygulama İkonu

İkon tek bir SVG olarak [`Resources/icon.svg`](../Resources/icon.svg) dosyasında duruyor — terminal
yeşili gözleri olan siyah bir kedi. Düzenledikten sonra paketlenen `.icns` dosyasını yeniden üret:

```bash
./scripts/make-icon.sh
./scripts/build-app.sh
```

Script SVG'yi render eder, gereken tüm boyutları üretir ve `Resources/AppIcon.icns` dosyasını yazar.

## 7. Güncelleme

```bash
git pull
./scripts/build-app.sh
```

Veriler `Application Support` altında olduğu için derleme/güncelleme verilere dokunmaz.

## 8. Sorun Giderme

**`swift package resolve` "cannot use bare repository" hatası**
Git ayarında `safe.bareRepository=explicit` varsa SPM takılır. `build-app.sh` bunu kendi içinde aşar; elle derliyorsan:

```bash
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all swift build -c release
```

**Ajan başlatınca "command not found: claude"**
CLI kurulu değil ya da PATH'te değil. Kur, sonra Agents panelinde "Yeniden Tara".

**Prompt'ta soru işareti kutuları (▯?)**
Nerd Font eksik. `brew install --cask font-meslo-lg-nerd-font` kur; uygulama otomatik algılar. Gerekirse Settings → Tema → Terminal Yazı Tipi'nden elle seç.

**Bildirim gelmiyor**
Uygulamayı `.app` paketinden açtığından emin ol; Sistem Ayarları → Bildirimler → Puckyto'dan izin ver. Ayrıca Settings panelindeki "Bildirimler" anahtarı açık olmalı.

**Token rozeti `≈` gösteriyor, gerçek sayıya geçmiyor**
Gerçek sayım yalnızca Claude ajanlarında çalışır ve `~/.claude/projects/` altındaki oturum dosyalarından okunur. Ajanı uygulama içinden (🧠) başlattığından emin ol; ilk mesajdan sonra `✓`'ya döner.
