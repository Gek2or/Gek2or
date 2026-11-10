# Bloopie — контекст для продолжения работы

Этот файл самодостаточен: его можно отдать новому ассистенту вместе с архивом
`bloopie-project.zip` или репозиторием `gek2or/gek2or` (ветка `ccr-4de81cc6-9tmkl3`).

## 1. Где что лежит

| Что | Где |
| --- | --- |
| Рабочая версия игры (запускается, проверена) | коммит `37ae052`; в архиве — папка `bloopie/` |
| Тестовый APK этой версии | `bloopie-debug.apk` в архиве (в git его нет) |
| Незаконченный переход на спецификацию v02 | коммит `e97b5a5` (голова ветки); в архиве — `WIP_spec_v02.patch` |

**Голова ветки сейчас не запускается.** Чтобы получить рабочую игру, берите `37ae052`.
Чтобы продолжать переход на v02 — работайте от `e97b5a5`.

## 2. Проект

- Godot 4.3, GDScript. Портрет 1080×1920. Главная сцена `scenes/MainRoom.tscn`.
- Вся графика процедурная (`_draw()`), звук синтезируется в коде, внешних ассетов нет,
  кроме SVG-иконок (`art/icons/`) и шрифта Nunito (`art/fonts/`, лицензия OFL).
- Бэкенда нет. `AIClient` шлёт `POST {bloopie/backend_url}/v1/interact`, при ошибке
  отвечает встроенными репликами по архетипу.

```
bloopie/
  project.godot, export_presets.cfg
  scenes/MainRoom.tscn
  scripts/autoload/   GameState, TimeWeatherSystem, AIClient, MemoryManager
  scripts/bloopie/    BloopieActor, BloopieArt, BloopiePart, FaceController,
                      BloopieVoiceSynth, ProcAudio
  scripts/environment/ EnvironmentController, RoomArt, FairyLightsDrawer
  scripts/ui/         UIStyle, CareDrawer, VocalMinigame, MemoryAlbum, Onboarding
  scripts/MainRoom.gd
  shaders/            rain_window.gdshader, palette_swap.gdshader (только в WIP)
```

### Как устроен рендер Блупи

- `BloopieActor` держит общий словарь `state` (палитра, эмоция, моргание, взгляд, рот,
  стадия роста, шапочка, время).
- Каждый слой под `VisualRoot` — узел со скриптом `BloopiePart.gd` и полем `part`.
  Он вызывает соответствующую функцию `BloopieArt.draw_*`.
- Если узлу-слою назначить `texture` / `sprite_frames`, процедурная отрисовка этого
  слоя отключается — так вставляется готовый арт.
- Канон зубок — `BloopieArt.draw_teeth()`: один блок 30×19.5 px со скруглённым низом
  и единственной вертикальной линией. Вызывается из `draw_mouth()` для всех эмоций.

### Проверка без редактора

```
godot --headless --path bloopie --import          # импорт ассетов
godot --headless --path bloopie --quit-after 120  # дымовой запуск, ошибок быть не должно
xvfb-run -a godot --path bloopie --rendering-driver opengl3 -s <скрипт.gd>   # скриншоты
```

Скрипт для скриншотов наследует `SceneTree`, загружает `MainRoom.tscn`, вызывает методы
сцены и сохраняет `root.get_texture().get_image()`. События касания подаются через
`Input.parse_input_event()`; координаты нужно умножать на `root.get_final_transform()`.

### Сборка APK

Нужны шаблоны экспорта Godot 4.3 (`android_debug.apk`), JDK, `apksigner` и debug-keystore;
пути задаются в Editor Settings → Export → Android.

```
godot --headless --path bloopie --export-debug "Android" build/bloopie-debug.apk
```

## 3. Канон персонажа (не нарушать)

- Круглое плюшевое тело `#8AC7F7`, пропорция 1.08 : 1.0, контур `#232946` (чёрный запрещён),
  контровой свет `#FFD175`.
- Спиральный завиток 1.5 оборота, хохолки по бокам из 2–3 долей, две овальные лапки снизу.
- Глаза: большие вертикальные овалы `#1E2542 → #8AC7F7`, реснички, блики, 4-конечные звёздочки.
- Румянец `#FF8FA3` с тремя штрихами `#E05772`.
- **Зубки:** ровно два верхних, на 25% меньше обычных, слиты в один белый блок `#FFFDF9`
  с одной тонкой вертикальной линией. Без щели, клыков и языка. Широко открытый рот
  допустим только на высокой ноте в вокальной игре.
- Подушка крупной вязки `#E6B39A`.

## 4. Спецификация v02: что уже сделано (коммит `e97b5a5`)

| Файл | Состояние |
| --- | --- |
| `autoload/GameState.gd` | Готов. Сохранение в `user://bloopie_save_v02.json`. Новые поля и API — см. таблицу ниже. |
| `autoload/TimeWeatherSystem.gd` | Готов. `current_time_of_day` (evening/sunset/night), `current_weather` (rain/stars), сигнал `environment_updated(time_of_day, weather)`. |
| `autoload/AIClient.gd` | Готов. Заголовок `Authorization: Bearer <bloopie/api_token>`, в запросе `player_name`, `hunger`, `hygiene`, `pet_level`. |
| `autoload/MemoryManager.gd` | Готов. `register_camera(hud, flash)` и `take_polaroid(caption, focus, side)`; карточки пишутся в `GameState.album_cards`. |
| `shaders/palette_swap.gdshader` | Готов, к сцене не подключён. |
| `bloopie/BloopieArt.gd` | Готов. Толстый завиток-улитка, пышные хохолки, крупные лапки, ручки убраны. Плюшевые слои читают `state.draw_palette`. |
| `bloopie/BloopieActor.gd` | Готов. Ждёт материал `palette_swap` на `VisualRoot/BodyBase`; кросс-фейд темы, хвостик пузыря, постоянный пузырь стазиса, `start_singing(freq, pitch)`. |

### Переименования, которые ломают остальные скрипты

| Было | Стало |
| --- | --- |
| `GameState.get_level()` | `GameState.pet_level` |
| `GameState.theme_id` / `hat_id` | `GameState.current_theme` / `current_hat` |
| `GameState.has_cozy_pass`, `grant_cozy_pass()` | `has_active_subscription`, `activate_subscription()` |
| `GameState.cycle_hat()`, `next_locked_hat()` | `next_hat()`, `is_hat_unlocked()`, `is_hat_owned()`, `buy_hat()` |
| `GameState.hatch(archetype)` | `hatch(archetype, player_name)` |
| `TimeWeatherSystem.atmosphere_changed` | `environment_updated(time_of_day, weather)` |
| `TimeWeatherSystem.get_window_mode()`, `time_of_day` | `current_time_of_day`; для приветствий — `get_day_part()` |
| `MemoryManager.entries`, `capture()` | `GameState.album_cards`, `take_polaroid()` |
| поля карточки `file`, `unix` | `image_path`, `timestamp`, `date_string` |
| `BloopieActor.start_singing(freq)` | `start_singing(freq, pitch)` — сигнал мини-игры должен отдавать и высоту 0..1 |

Новое в `GameState`: `hunger`, `hygiene` (медленно снижаются, но не ниже 35 — без наказаний),
`coins` (старт 120, ежедневный подарок 20, +25 за уровень), `feed()`, `wash()`,
`spend_coins()`, `get_happiness()`, `claim_daily_gift()`, `owned_hats`.
Цены шапочек: cosy 50, cat 120, frog 200, wizard 350 (плюс пороги уровня 1 / 5 / 10 / 20).

## 5. Что осталось сделать

1. **Скрипты на старом API:** `MainRoom.gd`, `ui/CareDrawer.gd`, `ui/MemoryAlbum.gd`,
   `ui/Onboarding.gd`, `environment/EnvironmentController.gd` — перевести на таблицу выше.
   В `EnvironmentController` звёзды и дождь брать из `get_star_amount()` / `get_rain_intensity()`.
2. **`MainRoom.tscn`:**
   - общий `ShaderMaterial` с `palette_swap.gdshader` на `BodyBase`, `BackTufts`, `TopCurl`, `FrontPaws`;
   - `BloopieActor.scale = (1.5, 1.5)` — Блупи должен занимать около 58% ширины, как на макетах;
   - `Camera2D` в `(540, 960)`, zoom 1; в чате 1.18;
   - `TopBar`: `LevelPill`, `CoinsPill`, `MoodBar`, `AlbumButton`;
   - `PaywallModal → WakeUpButton` «Разбудить Блупи (Cozy Pass)», виден всё время стазиса.
3. **`RoomArt.gd`:** подоконник ниже (`SILL_TOP ≈ 1330`, `SILL_FRONT ≈ 1600`), подушка
   `#E6B39A` с центром около `(540, 1420)` и полуосями `500 × 150`, задняя подушка слева,
   кот / книги с кружкой / утка / кристаллы — перед подушкой. Гирлянду поднять к `y ≈ 250`.
4. **HUD по макетам:** кремовые плашки и док на полупрозрачной белой рамке; шкала
   «Счастье N%» в панели заботы; какао 5 монет, тарт 10; альбом 2×2 с пагинацией «1 / 3»
   и кнопкой «Назад»; в вокальной игре — бирюзовая неоновая волна с цветными нотными
   кольцами в верхней трети экрана, плашки «Вокал Lv.N» и «Точность N%».
5. **Онбординг:** поле имени игрока.
6. **`project.godot` / `export_presets.cfg`:** aspect `expand`, окно 540×960,
   renderer `mobile`, `bloopie/api_token`, пакет `com.cozyai.bloopie`, только `arm64-v8a`.
7. **Бэкенд FastAPI + Gemini 2.5 Flash** — не начат. Контракт ответа: `reply_text`,
   `emotion_animation` (одна из 12 эмоций), `stat_deltas {mood_delta, energy_delta, affection_delta}`,
   `save_to_memory`.

## 6. Решения и ограничения

- Интерфейс на русском; на макетах подписи английские. Локализации нет.
- Эмодзи заменены SVG-иконками: во встроенном шрифте Godot их нет.
- Погода симулируется от даты и часа, без геолокации.
- Покупка не подключена: в debug-сборке кнопка выдаёт подписку сразу, в release сообщает,
  что покупка недоступна.
- Renderer `mobile` требует Vulkan. В рабочей версии стоит `gl_compatibility`; при переходе
  на `mobile` проверить запуск на реальном телефоне.
- APK ни разу не запускался на устройстве: проверены только подпись и состав пакета.
- Контроллы с нулевым размером отсекаются при зуме камеры — у `WindowFrameProps` задан
  размер 1080×1920 именно поэтому.
- Сообщение со спецификацией v02 оборвалось на дереве сцены; раздел про бэкенд до меня не дошёл.
