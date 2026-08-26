<img src="docs/images/icon.png" width="104" align="right" alt="Puckyto">

# Puckyto

**AI kodlama ajanların için bir kontrol kulesi.**

Puckyto, birden fazla terminali yan yana çalıştıran ve her birinin içindeki AI ajanını
(Claude / ChatGPT / Gemini) birinci sınıf bir varlık olarak ele alan yerel bir macOS uygulaması:
ajanın adı, görevi, kural seti ve yeniden başlatmalara dayanan bir hafızası var. Etraflarında ise üç
ajan aynı anda çalışırken gerçekten ihtiyaç duyduğun şeyler duruyor — yazdıkları ortak pano, onları
besleyen görev kuyruğu, düzenlemelerini geri alınabilir kılan git checkpoint'leri, gerçek token
muhasebesi ve kimin ne yaptığını gösteren canlı harita.

Kullandığın ajan CLI'lerini sarmalamaz ya da değiştirmez. Terminallerinin sahibi olur, onlara bağlam
verir ve yoldan çekilir.

> **Oturumları ayakta tutmaktan çok, her ajana kimlik, bağlam ve ölçülebilir çıktı kazandırmaya odaklanır.**

*[English README](README.md)* · 📘 **[Kurulum](docs/KURULUM.md)** · 📗 **[Kullanım](docs/KULLANIM.md)**

![Terminal ızgarası](docs/images/01-terminals.png)

```bash
./scripts/build-app.sh && open "build/Puckyto.app"
```

Gereksinimler: macOS 14+, Swift 5.9+ ve çalıştırmak istediğin ajan CLI'si —
[Claude Code](https://claude.com/claude-code) (`claude`), OpenAI Codex (`codex`) ya da Gemini CLI (`gemini`).
Arayüz varsayılan olarak İngilizce; Türkçe bir tık uzakta.

---

## Neden var?

Tek ajan çalıştırmak kolay. Dört tanesini çalıştırmak başka bir iş: hangisinin takıldığını
kaçırıyorsun, aynı klasörde birbirlerinin üstüne yazıyorlar, aynı promptları tekrar tekrar yazıyorsun
ve günün maliyetini bilmiyorsun. Puckyto bu ikinci durum için yapıldı.

| Sorun | Puckyto'nun yaptığı |
|---|---|
| "Hangi ajan beni bekliyor?" | Durum rozetleri, menü çubuğu özeti ve tıklayınca o terminale götüren bildirimler |
| "Ne değiştirdiler?" | Ajan başına git checkpoint'i, canlı `Δ +a −b` rozeti, tek tıkla geri alma |
| "Sürekli çakışıyorlar" | Aynı klasör uyarısı ve tek tıkla `git worktree` izolasyonu |
| "Aynı promptları yazıp duruyorum" | Hızlı komutlar, broadcast ve ajan boşa düşünce ilerleyen görev kuyruğu |
| "Projeyi biliyorlar mı?" | Terminal başına wiki + ortak pano; ikisi de ajanın sistem promptuna bağlı |
| "Bu bana neye mal oluyor?" | Claude oturum dosyalarından okunan gerçek token kullanımı, workspace kırılımlı grafik |

---

## Kullanım

### 1. Terminaller ve ajanlar

Her terminal bir ajandır. Başlık, kimliğini ve canlı durumunu taşır: sağlayıcı etiketi, `Executing /
Idle`, zil çaldığında `🔔 onay bekliyor`, git değişiklikleri için `Δ +120 −34`, kuyruktaki işler için
`⏭ 3` ve token sayacı. `⌘T` yeni terminal ekler; workspace'e varsayılan klasör atanınca yeni
terminaller `cd` yazmadan doğrudan projende açılır.

![Terminal ızgarası](docs/images/01-terminals.png)

### 2. Ajana bir kimlik ver

Agents paneli, bir terminalin meslektaşa dönüştüğü yer: ad ve ikon, sağlayıcı, model ve effort, izin
modu (sor / plan / düzenlemeleri onayla / tam otonom), görev tanımı, her satırı bir kural olan kural
seti ve kalıcı `MEMORY.md`. Hafıza editörü dosya tabanlıdır: ajanın oraya yazdığı her şey saniyeler
içinde burada görünür ve yeniden başlatma onu asla ezmez.

![Agents paneli](docs/images/02-agents.png)

Şablonlar (Builder, Reviewer, Test Engineer, Documentarian) tüm bunları tek tıkla kurar; "Şablon
Kaydet" ise beğendiğin bir ajanı yeniden kullanılabilir hale getirir.

### 3. Koordine olmalarını sağla

Her workspace'in bir ortak panosu var. Başlarken her ajana tanıtılır; böylece ne yaptıklarını saniyeli
saat damgasıyla yazar, işe başlamadan önce birbirlerini okurlar. Koordinatör ajan bir adım öteye
gider ve dosya kuyruğu üzerinden diğerlerine iş atar; uygulama iletir ve panoya loglar. Logs bölümü bu
panonun tam genişlikte canlı okuyucusudur.

![Ortak pano](docs/images/03-board.png)

### 4. Projenin bilgisini yanlarında tut

Her terminalin kendi markdown wiki'si var. Ajanlar kendi wiki klasörünü bilir; mimari notları ve
kararları oraya yazarlar. Bir notu istediğin terminale sürükleyip devredebilirsin. Üstteki seçici, bir
ajanın notlarını okurken onları başka bir ajanın terminaline bırakmanı sağlar.

![Wiki](docs/images/05-wiki.png)

### 5. Filonun tamamını gör

Nöral harita workspace'leri ve ajanları bir ağ olarak çizer — düğümler aktiviteyle parlar,
bağlantılarda parçacıklar akar, durum noktası kimin çalıştığını ya da onay beklediğini gösterir.
Bir düğüme tıklayınca o terminale gidersin; düğümleri istediğin yerleşime sürükleyebilirsin.

![Nöral harita](docs/images/04-neural-map.png)

### 6. Ayarla, sonra faturayı izle

Settings'te dil anahtarı, beş gömülü tema (One Dark Pro, Dracula, GitHub Dark, Tokyo Night, Monokai
Pro) ve kendi JSON temaların, düzenlenebilir model kataloğu, ajan şablonları ve hızlı komutlar var.
Altında ise son yedi günün gerçek Claude token kullanımı, workspace kırılımıyla birlikte.

![Ayarlar](docs/images/06-settings.png)

> Ekran görüntüleri demo bir workspace ile alınmıştır; kişisel yol/isim içermez.

---

## Prompt mühendisliği araçları

Asıl iş prompt'ta olduğu için 🧪 menüsü ve terminalin sağ tık menüsü şunları sunar:

- **Sistem promptu önizleme** — ajana enjekte edilen metnin ve tam başlatma komutunun birebir hali, kopyalanabilir.
- **A/B koşusu** — tek görevi farklı yapılandırılmış 2-3 ajana gönder, yanıtları harcadıkları tokenlarla yan yana karşılaştır, 👍/👎 ver ve deney günlüğüne kaydet.
- **Gönderim geçmişi** — gönderdiğin her prompt, aranabilir, tekrar gönderilebilir.
- **Son yanıt** — kopyala, wiki'ye kaydet ya da başka bir ajana ileterek zincirle.
- **CLAUDE.md editörü** — proje talimatlarını uygulamadan çıkmadan düzenle.

Promptlarda `{{klasör}}`, `{{dal}}`, `{{terminal}}` ve `{{tarih}}` yer tutucuları kullanılabilir;
gönderim anında her terminal için doldurulur.

---

## Kısayollar

| Kısayol | İşlev |
|---|---|
| `⌘T` / `⇧⌘N` | Yeni terminal / yeni workspace |
| `⌘W` | Odaklı terminali, sonra uygulamayı kapat — her biri onaylı |
| `⌘\` | Yan paneli gizle/göster |
| `⌘F` | Odaklı terminalde ara |
| `⌘↑` / `⌘↓` / `⇧⌘↓` | Sayfa yukarı / aşağı / en alta in |

## Veri ve gizlilik

Her şey makinende, `~/Library/Application Support/dev.puckyto.app/` altında durur —
`state.json` (workspace'ler, ajanlar, ayarlar), `wiki/`, `agents/*/MEMORY.md`, `boards/`, `themes/`.
Yedeklemek için klasörü kopyala; sıfırlamak için `state.json`'u sil.

Puckyto kendi başına hiçbir ağ isteği yapmaz. Yalnızca başlattığın ajan CLI'leri, tıpkı herhangi bir
terminalde olduğu gibi kendi kimlik bilgilerinle kendi sağlayıcılarıyla konuşur.

## Lisans

MIT — [LICENSE](LICENSE) dosyasına bak.
