# Выпуск в App Store

Всё, что нужно, чтобы довести Sasha's Puzzles до магазина: чеклист, тексты
для App Store Connect, размеры скриншотов, локализация, замена картинок и
звуков, сбор ошибок.

## 1. Чеклист

**Аккаунт**
- [ ] Платное членство **Apple Developer Program** (99 $/год). Сертификата
      разработчика недостаточно — в App Store Connect пускают только с
      оплаченной программой. Проверить: <https://developer.apple.com/account>
      → Membership.
- [ ] Принять актуальные соглашения в App Store Connect → Agreements. Для
      бесплатного приложения достаточно Free Apps Agreement; для платного —
      Paid Apps плюс банковские и налоговые данные.

**Проект (уже сделано в репозитории)**
- [x] Bundle ID `com.kirillrychkov.SashasPazzle`, автоматическая подпись,
      команда `QU2NF6T447`.
- [x] Иконка 1024×1024 без прозрачности в `Assets.xcassets/AppIcon`.
- [x] `NSPhotoLibraryUsageDescription` (текст запроса к фото).
- [x] `ITSAppUsesNonExemptEncryption = NO` — вопрос про шифрование при
      каждой загрузке будет пропускаться.
- [x] `NSHumanReadableCopyright = © 2026 Kirill Rychkov`.
- [x] Launch screen генерируется (`UILaunchScreen_Generation`).
- [x] Sandbox + Hardened Runtime для Mac.
- [x] Версия `MARKETING_VERSION = 1.0`, сборка `CURRENT_PROJECT_VERSION = 1`.
      Каждая новая загрузка в App Store Connect — увеличить сборку (2, 3, …).

**App Store Connect → My Apps → «+»**
- [ ] Platforms: iOS (iPhone + iPad) и, если хотите, macOS — одна запись,
      universal purchase.
- [ ] Name: `Sasha's Puzzles` (проверят уникальность), Primary language:
      English (U.S.), SKU: `sashas-puzzles`, Bundle ID из списка.
- [ ] Category: Games → Puzzle; secondary: Games → Family.
- [ ] Age Rating — анкета, ответы «нет» везде → 4+.
- [ ] App Privacy → «Data Not Collected» (приложение ничего не собирает).
- [ ] Privacy Policy URL — обязательна для всех приложений:
      `https://github.com/5f59cbfv7m-maker/Sasha-s-Puzzles/blob/main/docs/privacy.md`
      (текст в `docs/privacy.md`; замените контактный e-mail, если хотите другой).
- [ ] Support URL: `https://github.com/5f59cbfv7m-maker/Sasha-s-Puzzles`.
- [ ] Pricing: Free (или цена) + страны.
- [ ] Тексты из раздела 2 — для English и Russian (остальные языки можно
      добавить позже, App Store Connect показывает английский как fallback).
- [ ] Скриншоты из раздела 3.
- [ ] App Review Information: контакт, заметки «Fully offline, no account.
      Tap any picture → Start puzzle.» Демо-логин не нужен.

**Сборка и загрузка**
- [ ] Xcode → Product → Archive (схема JigsawPuzzle, destination «Any iOS
      Device»). Затем Organizer → Distribute App → App Store Connect → Upload.
      dSYM загрузится автоматически — это нужно для расшифровки крашей.
- [ ] Для Mac: Archive с destination «Any Mac» и та же кнопка. Если Organizer
      пожалуется на подпись, уберите в Build Settings строку
      `CODE_SIGN_IDENTITY[sdk=macosx*] = "-"` (она нужна только для
      `Scripts/install-mac.sh` без сертификата).
- [ ] Обработка сборки занимает 10–30 минут, потом она появляется в
      TestFlight и в версии приложения.
- [ ] TestFlight: поставьте себе и Саше на реальные устройства и поиграйте
      день-два до отправки на ревью.
- [ ] Submit for Review. Первое ревью — обычно 1–3 дня.

**Перед отправкой прогнать**
```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle \
  -destination 'platform=macOS,arch=arm64' -configuration Debug test
```

## 2. Тексты для App Store Connect

Ограничения: название 30 символов, подзаголовок 30, промо-текст 170,
ключевые слова 100 (через запятую, без пробелов), описание 4000.

### English (U.S.)

**Name:** Sasha's Puzzles
**Subtitle:** Jigsaws from your own photos
**Promotional text:** A calm jigsaw table with a new puzzle every day. Turn any photo into a puzzle — 12 to 800 pieces, fully offline.
**Keywords:** `jigsaw,puzzle,puzzles,photo,relax,daily,offline,family,kids,pieces,calm,picture`
**Description:**

> Sasha's Puzzles is a jigsaw table that feels like the real thing — warm, quiet and yours.
>
> REAL PIECES
> Every cut exists once and is shared by its two neighbours, so pieces meet exactly: no gaps, no "close enough". Pieces click into place with a soft sound and a gentle haptic tap.
>
> YOUR PHOTOS ARE PUZZLES TOO
> Pick any photo from your library and choose 12 to 800 pieces. Frame it the way you like — nothing is ever stretched.
>
> A NEW PUZZLE EVERY DAY
> The daily puzzle keeps a streak going. Solve it seven days in a row and earn an achievement.
>
> JUST THE HELP YOU NEED
> Snap assist pulls a piece home when it is close. A hint highlights the next step. A faint guide of the picture can sit under the board — or not. Everything is a switch in Settings.
>
> BUILT FOR THE IPAD
> Drag pieces from the tray with your finger, pinch to zoom, scatter pieces across the whole table or keep them tidy. Works in portrait and landscape, light and dark.
>
> COMPLETELY OFFLINE
> No account, no ads, no tracking, nothing leaves your device. The table is saved automatically — come back whenever you like.
>
> Also on Mac with keyboard shortcuts, undo and redo.

**What's New (1.0):** First release.

### Russian

**Name:** Sasha's Puzzles
**Subtitle:** Пазлы из ваших фотографий
**Promotional text:** Спокойный стол для пазлов и новый пазл каждый день. Любое фото становится пазлом — от 12 до 800 деталей, полностью офлайн.
**Keywords:** `пазл,пазлы,головоломка,фото,картинки,релакс,офлайн,семья,дети,детали,спокойствие`
**Description:**

> Sasha's Puzzles — стол для пазлов, который ощущается как настоящий: тёплый, тихий и ваш.
>
> НАСТОЯЩИЕ ДЕТАЛИ
> Каждый разрез существует один раз и общий для двух соседей, поэтому детали сходятся точно — без зазоров и «примерно рядом». Деталь встаёт на место с мягким звуком и лёгким тактильным откликом.
>
> ВАШИ ФОТО — ТОЖЕ ПАЗЛЫ
> Выберите любое фото из галереи и число деталей от 12 до 800. Кадрируйте как нравится — растяжения не бывает никогда.
>
> НОВЫЙ ПАЗЛ КАЖДЫЙ ДЕНЬ
> Пазл дня поддерживает серию. Соберите его семь дней подряд — и получите достижение.
>
> ПОМОЩЬ РОВНО ТА, ЧТО НУЖНА
> Помощь при стыковке притягивает деталь, когда она рядом. Подсказка подсвечивает следующий шаг. Бледная картинка-подсказка может лежать под полем — или нет. Всё это переключатели в настройках.
>
> СДЕЛАНО ДЛЯ IPAD
> Перетаскивайте детали из лотка пальцем, масштабируйте щипком, рассыпайте детали по всему столу или держите их в порядке. Работает в портретной и альбомной ориентации, в светлой и тёмной теме.
>
> ПОЛНОСТЬЮ ОФЛАЙН
> Без аккаунта, рекламы и слежки — ничего не покидает устройство. Стол сохраняется сам, возвращайтесь когда удобно.
>
> Есть и на Mac — с клавиатурными сокращениями, отменой и повтором.

**What's New (1.0):** Первый выпуск.

## 3. Скриншоты

App Store Connect в 2026 году требует только два размера, остальные
масштабирует сам:

| Устройство | Пиксели | Симулятор |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 (портрет) | iPhone 17 Pro Max |
| iPad 13" | 2064 × 2752 (портрет) или 2752 × 2064 | iPad Pro 13-inch (M5) |
| Mac (если публикуете) | 2880 × 1800 или 2560 × 1600 | реальное окно |

До 10 штук на устройство, PNG или JPEG без прозрачности. Первые три видны
в поиске — ставьте самое сильное вперёд: собранный пазл, стол с деталями,
библиотека.

Готовый скрипт снимает все экраны нужного размера:

```bash
Scripts/store-screenshots.sh en
```

Результат — `docs/store/en/<устройство>/<экран>.png`. Второй аргумент —
язык (`ru`, `de`, …), App Store Connect принимает отдельные наборы для
каждого языка. Снимайте после замены картинок, а не до. Для Mac: запустите
приложение, `⌘⇧4`, пробел, клик по окну — получится PNG нужного размера на
Retina-дисплее.

Рамки устройств не нужны; если хочется подписи поверх, любой редактор
подойдёт, размер холста менять нельзя.

## 4. Языки интерфейса

В Xcode есть **String Catalog** — `Sources/Resources/Localizable.xcstrings`.
Он уже содержит все строки приложения на 10 языках: английский, русский,
немецкий, французский, испанский, итальянский, португальский (Бразилия),
японский, корейский, китайский (упрощённый). Автоматического перевода в
Xcode нет; переводы сделаны вручную.

- Посмотреть/поправить: откройте файл в Xcode — таблица «ключ → язык»,
  фильтр по языку, процент готовности справа.
- Добавить язык: Project → Info → Localizations → «+», затем в каталоге
  появится пустой столбец; строки без перевода показываются по-английски.
- Проверить, как выглядит: Scheme → Run → Options → App Language, или из
  терминала `-AppleLanguages "(ja)"` (см. `CLAUDE.md`).
- Тексты в App Store Connect переводятся отдельно, в веб-интерфейсе, для
  каждого языка магазина.

Названия встроенных картинок — тоже строки каталога, см. следующий раздел.

## 5. Замена картинок

Сейчас 24 картинки рисуются процедурно (`Sources/Art/`). Реальные
фотографии кладутся рядом, ничего в коде для этого менять не нужно:

1. Создайте папку `Sources/Resources/Pictures/` (Xcode подхватит её сам —
   папка `Sources` синхронизируется с диском).
2. Положите файлы с именем `<категория>_<Название>.jpg`, например
   `sea_Sunset Beach.jpg`, `animals_Red Panda.heic`. Категории: `space`,
   `nature`, `mountains`, `sea`, `city`, `animals`, `abstract`. Форматы:
   jpg, jpeg, png, heic. Файл с именем не по схеме молча пропускается.
3. Размер: длинная сторона 2400–3000 px, JPEG качество ~85 → 0.5–1 МБ на
   картинку. 800 деталей режутся из такого файла без потери резкости; больше
   — только раздувает приложение (приложение само не декодирует длинную
   сторону выше 2800 px). Пропорции — горизонтальные 3:2 или 4:3: так
   картинка целиком попадает в стандартные форматы пазла, а игрок всё равно
   может выбрать другое кадрирование. Цвет sRGB, без альфа-канала, поворот
   «запечён» в пиксели (не через EXIF-ориентацию), без встроенных превью.
   В Photoshop: «Экспортировать как…» → JPG, качество 85, «Преобразовать в
   sRGB», метаданные — «Нет».
4. Название после `_` — ключ в `Localizable.xcstrings`. Добавьте его туда
   (кнопка «+» в редакторе каталога) и переведите; без записи покажется
   как в имени файла.
5. Чтобы убрать процедурные картинки, удалите строки из
   `LibraryCatalog.selection` (`Sources/Library/LibraryCatalog.swift`).
   Пазл дня и достижения «все пазлы категории» пересчитаются сами.

Фотографии появляются в библиотеке первыми, в алфавитном порядке имени
файла. Права: только свои снимки или лицензия, разрешающая коммерческое
использование (Unsplash/Pexels подходят, стоковые «free for personal use» —
нет).

## 6. Звуки и фоновая музыка

Папка `Sources/Resources/Sounds/` (создайте, как и `Pictures`). Файл с
нужным именем заменяет встроенный синтезированный звук:

| Файл | Когда звучит |
|---|---|
| `snap.m4a` | деталь встала на место |
| `merge.m4a` | две группы соединились |
| `complete.m4a` | пазл собран |
| `music.m4a` | фоновая музыка, зациклена, пока открыт стол |

Форматы: m4a (AAC), wav, caf, mp3, aiff. Эффекты — короче секунды, музыка —
AAC 128–160 кбит/с, обрезанная так, чтобы шов цикла был незаметен (в
GarageBand/Logic: экспорт «без хвоста»). Тишина в начале файла = задержка
звука, обрежьте её.

Что уже сделано в коде (`Sources/Support/Feedback.swift`):
- музыка играет только на экране стола, ставится на паузу при сворачивании
  и возобновляется при возврате;
- громкость музыки относительно эффектов — `Feedback.musicVolume` (0.35);
- в настройках два переключателя: «Звуки» и «Фоновая музыка». Второй
  появляется только когда `music.*` есть в сборке;
- категория аудиосессии ambient: приложение не перебивает чужую музыку и
  уважает переключатель беззвучного режима.

Лицензия на музыку — то же, что и с картинками: нужна коммерческая.

## 7. Сбор ошибок

Вариант по умолчанию — **встроенный в Apple, бесплатный, без кода**:

- **Xcode → Window → Organizer → Crashes.** Краши от пользователей,
  которые разрешили делиться диагностикой (это большинство), приходят через
  1–2 дня, уже расшифрованные (dSYM загружается при Archive). Клик по
  крашу открывает строку кода.
- **TestFlight.** До релиза тестеры могут прямо из приложения прислать
  скриншот с описанием; краши из TestFlight приходят туда же, быстрее.
- **Organizer → Feedback / Hangs / Disk Writes** — то же самое для зависаний
  и производительности.

Чего этого не даёт: крашей от пользователей, отключивших диагностику;
отчётов в реальном времени; «хлебных крошек» — что делал пользователь
перед ошибкой. Если через месяц после релиза этого станет мало, следующая
ступень — **Sentry** или **Firebase Crashlytics** (оба бесплатны на этом
объёме): подключаются как Swift Package, дают все краши от всех
пользователей за минуты, с логами. Цена — в приложении появляется сетевой
SDK, ответ в App Privacy меняется на «Crash Data — collected, not linked»,
и политику конфиденциальности надо дополнить.

В самом приложении ошибки, которые можно предвидеть, уже перехвачены и
показываются по-человечески (нечитаемое фото, неподдерживаемый формат,
пропавшая картинка сохранённой игры); сохранения переживают краш, потому
что стол пишется на диск при каждом изменении.
