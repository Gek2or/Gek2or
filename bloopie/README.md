# Bloopie — your cozy AI friend

Мобильная игра-компаньон на Godot 4.3 (портрет 9:16, 1080×1920, рендер Mobile).

## Запуск

1. Открой папку `bloopie/` в Godot 4.3+ (`project.godot`).
2. Нажми F5 — стартует `scenes/MainRoom.tscn`.

Бэкенд не обязателен: если `POST {backend_url}/v1/interact` недоступен, `AIClient`
отвечает встроенными репликами. Адрес бэкенда — в Project Settings → `bloopie/backend_url`.

## Структура

| Путь | Что внутри |
| --- | --- |
| `scripts/autoload/` | `GameState`, `TimeWeatherSystem`, `AIClient`, `MemoryManager` |
| `scripts/bloopie/` | актёр, лицо, процедурный рендер (`BloopieArt`), синтезатор голоса и звуков |
| `scripts/environment/` | контроллер комнаты, интерьеры трёх архетипов, гирлянда |
| `scripts/ui/` | панель заботы, вокальная мини-игра, альбом, онбординг, стили |
| `shaders/rain_window.gdshader` | небо, дождь по стеклу, боке огней, звёзды |
| `art/icons/` | SVG-иконки интерфейса |

## Замена плейсхолдеров на арт

Все слои Блупи (`BodyBase`, `TopCurl`, `EyesSprite`, `MouthTeeth`, …) — узлы `Sprite2D` /
`AnimatedSprite2D` со скриптом `BloopiePart.gd`. Пока у узла нет текстуры или кадров, слой
рисуется процедурно; как только назначить `texture` / `sprite_frames`, процедурный рендер
этого слоя отключается сам.

Канон зубок закреплён в `BloopieArt.draw_teeth()`: один скруглённый снизу блок 30×19.5 px
(−25% от пары 40×26) с единственной вертикальной линией по центру.

## Контракт `/v1/interact`

Запрос с заголовком `Authorization: Bearer <bloopie/api_token>`: `message`, `player_name`, `archetype`, `stats`, `recent_memories` (не больше 7), `context`
(время суток, погода), `event` (например, результат вокальной игры).

Ответ (`BloopieAIResponse`): `reply_text`, `emotion_animation` (одна из 12 эмоций),
`stat_deltas { mood_delta, energy_delta, affection_delta }`, `save_to_memory`.

## Сборка APK

Пресет `Android` лежит в `export_presets.cfg` (пакет `com.cozyai.bloopie`, arm64-v8a,
разрешения INTERNET и VIBRATE). Нужны шаблоны экспорта Godot 4.3 и пути к
Android SDK / JDK / debug-keystore в Editor Settings → Export → Android.

```
godot --headless --path bloopie --export-debug "Android" build/bloopie-debug.apk
```

Шрифт интерфейса — Nunito (SIL OFL, `art/fonts/OFL.txt`).
