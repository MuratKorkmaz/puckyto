# Puckyto — Kullanım Kılavuzu

Puckyto, birden fazla terminalde koşan AI ajanlarını (Claude / ChatGPT / Gemini) tek ekrandan yönetmen için tasarlandı. Bu kılavuz tüm bölümleri ve akışları anlatır.

*English version: [USAGE.md](USAGE.md)*

## İçindekiler
1. [Arayüz Düzeni](#1-arayüz-düzeni)
2. [Workspace ve Terminaller](#2-workspace-ve-terminaller)
3. [AI Ajanları](#3-ai-ajanları)
4. [Görev Kuyruğu ve Hızlı Komutlar](#4-görev-kuyruğu-ve-hızlı-komutlar)
5. [Ajanlar Arası Koordinasyon](#5-ajanlar-arası-koordinasyon)
6. [Wiki ve Dosyalar](#6-wiki-ve-dosyalar)
7. [Git Güvenliği](#7-git-güvenliği)
8. [Nöral Harita](#8-nöral-harita)
9. [Bildirimler ve Menü Çubuğu](#9-bildirimler-ve-menü-çubuğu)
10. [Settings](#10-settings)
11. [Klavye Kısayolları](#11-klavye-kısayolları)

---

## 1. Arayüz Düzeni
![Terminal ızgarası](images/01-terminals.png)

- **Sol ray:** Bölüm ikonları — Workspaces, Sessions, Wiki, Files, Agents, Neural Map, Settings. Seçili bölümün ikonuna tekrar tıklamak yan paneli gizler/gösterir.
- **Yan panel:** Seçili bölümün içeriği. Kenarındaki tutamaçtan 220–520 px arası genişletilir; alt şeritten sağa/sola sabitlenir veya gizlenir (`⌘\`).
- **Üst bar:** Panel aç/kapa, workspace adı, "Görev Gönder" (broadcast) ve "+ Terminal". Boş alanına **çift tık** pencereyi büyütür.
- **Orta alan:** Terminal ızgarası (1→tek, 2–4→2 sütun, 5+→3 sütun) ya da Neural Map.

## 2. Workspace ve Terminaller

- **Workspace** = bir terminal grubu (ör. proje başına bir tane). `⇧⌘N` ile yeni workspace, `⌘T` ile seçili workspace'e yeni terminal.
- **Varsayılan klasör:** Workspaces listesinde sağ tık → "📁 Varsayılan Klasör Seç..." — o workspace'te açılan her yeni terminal otomatik bu klasörde başlar (`cd` derdi biter). Atanan yol satırın altında görünür; "Varsayılan Klasörü Kaldır" ev dizinine döndürür.
- **Yeniden adlandırma:** Terminal adına çift tık (panelde) ya da Sessions/Workspaces listesinde sağ tık → Yeniden Adlandır.
- **Terminal başlığındaki rozetler:**
  - `Executing / Idle` — son 2 sn'de çıktı aktı mı
  - `🤖 Ajan` + `CLAUDE/GPT/GEMINI` — atanmış ajan ve sağlayıcısı (marka renkli)
  - `🔔 onay bekliyor` — ajan zil çaldı, girdi bekliyor
  - `⚠️ aynı klasör` — başka bir ajan aynı dizinde çalışıyor (çakışma riski!)
  - `Δ +120 −34` — ajan başladığından beri git değişiklikleri
  - `⏭ 3` — görev kuyruğunda bekleyen iş
  - `✓ 12.3k tok` — gerçek Claude token kullanımı (`≈` ise PTY tahmini)
- **Başlık düğmeleri:** ⚡ hızlı komut menüsü · 🧠 ajanı başlat/yeniden başlat · ⤢ büyüt · ✕ kapat.
- **Sağ tık menüsü:** Görev Kuyruğu, Git Worktree Aç, Claude Oturum Geçmişi, Checkpoint'e Geri Dön.
- **Sürükle-bırak:** Files panelinden veya Finder'dan dosyayı terminale bırak → kabuk için kaçışlanmış yolu yapıştırılır. Wiki notları da bırakılabilir.

## 3. AI Ajanları
![Agents paneli](images/02-agents.png)

Her terminalin bir ajanı vardır. **Agents** panelinde (terminale tıklayıp odaklan) yapılandırılır:

- **Ad + ikon:** İkona tıklayınca emoji seçici açılır.
- **AI Sağlayıcı:** Claude / ChatGPT / Gemini. Kurulu olmayan CLI ⚠️ ile işaretlenir.
- **Model & Effort:** Sürümlü listeden seç (ör. Opus 4.8 + xhigh). Listeler Settings → AI Modelleri'nden düzenlenir — yeni model çıkınca oraya eklersin.
- **İzin Modu (Claude):**
  - *Sor* — her kritik eylemde onay ister (varsayılan)
  - *Plan* — önce plan sunar, onayınla uygular
  - *Düzenlemeleri otomatik onayla* — dosya düzenlemelerinde sormaz
  - *⚡ Tam otonom* — hiç sormaz (`--dangerously-skip-permissions`); yalnızca izole worktree'de öner
- **Görev Tanımı:** Ajanın ne yapacağı; sistem prompt'una eklenir.
- **Kurallar:** Her satır bir kural — kalıcı davranış sınırları ("main'e push etme", "testler geçmeden bitti deme").
- **Kalıcı Hafıza:** MEMORY.md içeriği; ajan başlarken okur, çalışırken günceller.
- **Otomatik başlat:** Terminal açılınca ajan kendiliğinden başlar.
- **🎯 Koordinatör:** Bkz. [Bölüm 5](#5-ajanlar-arası-koordinasyon).

**Başlatma:** "Ajanı Başlat" düğmesi (veya başlıktaki 🧠). Komut önizlemesi altta görünür. Ajan zaten açıksa düğme **"Yeniden Başlat"** olur: çift Ctrl+C ile kapatıp yeni ayarlarla açar — model/kural değişiklikleri ancak yeniden başlatınca etkinleşir.

**Şablonlar:** "Şablondan Uygula" menüsü hazır konfigürasyon basar (Kod Yazıcı, İnceleyici, Test Uzmanı, Dokümantasyoncu); "Şablon Kaydet" mevcut ajanı şablonlaştırır. Yönetim: Settings → Ajan Şablonları.

**Ajan ne bilir?** Başlatılırken sistem prompt'una şunlar işlenir: görev + kurallar, MEMORY.md yolu, terminalin **wiki klasörü** (okur ve yazar), workspace'in **ortak panosu**, koordinatörse görev kuyruğu.

**Oturum geçmişi:** Sağ tık → "Claude Oturum Geçmişi" — o klasörün geçmiş oturumları listelenir, "Devam Et" `claude --resume` ile kaldığın yerden açar.

## 4. Görev Kuyruğu ve Hızlı Komutlar

- **Görev kuyruğu** (sağ tık → Görev Kuyruğu): Ajan başına sıralı iş listesi. Ajan yanıtını bitirip boşa düştüğünde sıradaki görev **otomatik gönderilir** — gece 5 görev diz, sabah bitmiş bul. Ajan onay beklerken (🔔) kuyruk bekler. Görevler sürüklenerek sıralanır; "Şimdi Gönder" ile beklemeden yollarsın.
- **Hızlı komutlar** (başlıktaki ⚡): "Durum raporu", "Testleri koş & düzelt" gibi kayıtlı promptlar tek tıkla o ajana gider. Düzenleme: Settings → Hızlı Komutlar.
- **Görev Gönder / broadcast** (üst bar): Tek görevi yaz, hedef ajanları işaretle → hepsine aynı anda gönderilir ("hepiniz durum raporu verin").

## 5. Ajanlar Arası Koordinasyon
![Ortak pano](images/03-board.png)

- **Ortak Pano:** Workspace başına bir `BOARD.md`. Her ajan başlarken panoyu öğrenir: durumunu oraya yazar, diğerlerini oradan okur. Görüntüle: Workspaces listesinde sağ tık → "📋 Ortak Panoyu Göster".
- **Koordinatör ajan:** Agents panelinde 🎯 anahtarını aç ve ajanı başlat. Koordinatöre bir kuyruk klasörü öğretilir; oraya `{"target": "Terminal 2", "message": "..."}` biçiminde JSON bıraktığında uygulama birkaç saniye içinde mesajı hedef terminaldeki ajana iletir ve panoya loglar. Örnek kullanım: koordinatöre "projeyi modüllere böl, her modülü uygun ajana dağıt" dersin, gerisini o yürütür.

## 6. Wiki ve Dosyalar

- **Wiki:** Her terminalin kendi markdown not defteri. Üstteki iki seçici: *Workspace* (sağda hangi ızgara görünsün — sürükleme hedefi) ve *Wiki kaynağı* (hangi terminalin notları listelensin; tüm workspace'lerden seçilebilir). Başlık yaz → ⏎ → içerik editörü odaklanır; 👁 ile tam markdown önizleme (başlıklar, listeler, görev kutuları, kod blokları). Not satırını terminale sürükle → dosya yolu yapışır; sağ tık → "İçeriği Terminale Gönder" ham metni yollar. Ajanlar kendi wiki'lerini bilir — "wiki'ne mimari kararları not et" diyebilirsin.
- **Files:** Basit gezgin. Çift tık: klasöre gir / dosya yolunu odaklı terminale yapıştır. Sağ tık: yol yapıştır, `cd`, Finder'da göster. Terminal simgesi düğmesi seni odaklı terminalin klasörüne götürür.

## 7. Git Güvenliği

- **Checkpoint:** Ajan her başlatıldığında repo'nun anlık görüntüsü alınır (`git stash create` — çalışma ağacına dokunmaz, geçmişi kirletmez).
- **Değişiklik gözcüsü:** `Δ +a −r` rozeti 6 sn'de bir tazelenir; üzerine gelince değişen dosyalar (yeniler dahil) listelenir.
- **Geri dönüş:** Sağ tık → "⏪ Checkpoint'e Geri Dön" — `git restore --source=<sha> -- .` komutunu terminale yazar (izlenen dosyaları döndürür; ajanın oluşturduğu yeni dosyalar kalır, `git status` çıktısından ayıklarsın).
- **Çakışma önleme:** İki ajan aynı klasörde aktifse `⚠️ aynı klasör` rozeti yanar. Çözüm: sağ tık → "Git Worktree Aç" — yan klasörde yeni dal + izole kopya açılır ve terminal oraya `cd` yapar.

## 8. Nöral Harita
![Nöral harita](images/04-neural-map.png)

Sol raydan **Neural Map**: merkezde PUCKYTO çekirdeği → workspace düğümleri → ajan düğümleri (sağlayıcı renginde halka). Bağlantılardaki parçacıklar aktiviteyle hızlanır/parlar.

- **Tıkla:** workspace düğümü → o workspace'i seçer; ajan düğümü → terminaline odaklanır (kesikli halka = seçili).
- **Sürükle:** düğümleri istediğin yerleşime taşı ("Yerleşimi Sıfırla" ile geri al).
- Sağ sütunda ajan kartları: token, bellek, aktivite çubuğu, durum.

## 9. Bildirimler ve Menü Çubuğu

- **"✅ Ajan hazır"** — ajan yanıtını bitirip boşa düştüğünde. **"🔔 Onay bekliyor"** — ajan zil çaldığında (claude izin sorarken). Oturum başına hız sınırı var, yağmur olmaz.
- **Bildirime tıkla** → uygulama öne gelir, ilgili terminale odaklanır.
- **Menü çubuğu ikonu:** "🟢 2 ajan açık · 🔔 1 onay bekliyor" özeti + tüm terminaller (🟢 çalışıyor / 🟡 boşta / 🔔 onay); satıra tıkla → odaklan. Başka uygulamadayken kontrol kulen.
- Kapatmak için: Settings → Bildirimler anahtarı.

## 10. Settings
![Ayarlar](images/06-settings.png)

| Satır | Açılan pencere |
|---|---|
| **Tema** | Gömülü 4 tema + JSON özel temalar; kart önizlemeli. "Yeni Tema (JSON)" seçili temanın kopyasını `themes/` klasörüne yazar; dosyayı düzenle → "Yenile". Altta **Terminal Yazı Tipi**: genel font ailesi (Otomatik = Nerd Font algıla) + boyut; özel temaya "Bu Temaya Yaz" ile fonta tema bazında sabitlenir. JSON alanları: renkler (`RRGGBB` hex), `ansi` (16 renk), `fontFamily`, `fontSize`. |
| **AI Modelleri** | Sağlayıcı başına model listesi: Görünen Ad + CLI kimliği. Yeni model çıkınca satır ekle → Agents'taki menüye anında düşer. |
| **Ajan Şablonları** | Şablon ekle/sil/düzenle (ad, ikon, sağlayıcı, model, effort, görev, kurallar). |
| **Hızlı Komutlar** | ⚡ menüsündeki kayıtlı promptlar. |

Panelde ayrıca: **Bildirimler** anahtarı ve **Kullanım — Son 7 Gün** grafiği (gerçek Claude tokenları; "Tüm Workspace'ler" seçiliyken workspace kırılımı listelenir, satıra tıkla → tekil analiz).

Tüm ayar pencereleri taşınabilir, minimum boyutun üstünde serbestçe boyutlandırılabilir ve ana pencerenin üstünde kalır.

## 11. Klavye Kısayolları

| Kısayol | İşlev |
|---|---|
| `⌘T` | Yeni terminal |
| `⌘W` | Odaklı terminali kapat (onaylı); terminal kalmadıysa uygulamayı kapat (onaylı) |
| `⌘Q` | Uygulamadan çık — "emin misin?" onayıyla |
| `⇧⌘N` | Yeni workspace |
| `⌘\` | Yan paneli gizle/göster |
| `⌘F` | Odaklı terminalde ara (⏎ sonraki, ▲▼ ileri/geri, ✕ kapat) |
| Üst bara çift tık | Pencereyi büyüt/küçült |
| Terminal adına çift tık | Yeniden adlandır |

## İpucu: Tipik Çoklu Ajan Akışı

1. Projene bir workspace aç, 3 terminal ekle; her terminali sağ tık → **Git Worktree Aç** ile izole et.
2. Şablonlardan ata: Kod Yazıcı (acceptEdits), İnceleyici (plan modu), Test Uzmanı.
3. Kod Yazıcı'nın **görev kuyruğuna** işleri diz; İnceleyici'ye ⚡ "Değişiklikleri özetle" gönder.
4. Neural Map'i aç ya da menü çubuğundan izle; 🔔 bildirimi gelince tıkla, onayı ver.
5. Ortak panodan kimin ne yaptığını takip et; Settings → Kullanım'dan günün token maliyetine bak.
