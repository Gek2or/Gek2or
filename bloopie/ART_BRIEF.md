# ТЗ на рендеры для Bloopie

Игра собрана из арта, вырезанного из прототипов. Ниже — кадры, которых не хватает, чтобы
убрать последнюю нарисованную кодом графику. Каждый кадр встраивается одной командой и
сразу заменяет свой кусок; присылать можно по одному.

## Общие правила

1. **Исходный файл генератора (PNG)**, не скриншот галереи. Без интерфейса, без подписей,
   без плашки «Gemini has detected this screenshot».
2. **К каждому запросу прикладывайте референс** `art/painted/bloopie_body.png` — это тот
   Блупи, который сейчас в игре. Просите сохранить его в точности.
3. **Персонаж — на ровном пурпурном фоне `#FF00FF`.** Блупи голубой, поэтому зелёный и
   синий фон не годятся. Без тени на фоне, без градиента, без предметов.
4. Тот же ракурс три четверти, Блупи **целиком в кадре** с запасом по краям, один на кадре.
5. **Комнаты — без Блупи и без интерфейса**, вертикаль 9:20 (например 1080×2400), подушка
   пустая и по центру нижней трети — туда сядет Блупи.
6. Канон зубок повторяется в каждом промпте: ровно два, слитые в один блок, одна линия.

Общая вставка для всех кадров с персонажем (дальше — `[CHARACTER]`):

> Use the attached image as the exact character reference: Bloopie, a round soft
> plush-textured sky-blue creature, three-quarter view, signature spiral curl on top of the
> head, fluffy 3-tuft cheek fur on both sides, two small oval feet, huge dark-blue eyes with
> long eyelashes and starry highlights, coral blush with three tiny hash marks, deep indigo
> ink lineart, cozy 2D hand-painted lo-fi illustration style. Keep the same proportions,
> colours, line weight and shading as the reference. CRITICAL: exactly two tiny upper front
> teeth fused into a single rounded white block with one thin dark vertical line in the
> middle; no gap, no fangs, no tongue. Full body in frame with margin, centred, on a
> perfectly flat solid magenta background #FF00FF, no shadow on the background, no props,
> no text, no UI.

## Кадры по приоритету

### 1. Шапочки — 3 кадра

Сейчас капюшоны рисует код, и они сильнее всего выбиваются из стиля.

| Файл | Промпт |
| --- | --- |
| `hat_cosy.png` | `[CHARACTER]` Bloopie wears a chunky beige knitted hood that frames the face like a cozy scarf-hood; the spiral curl pokes out on top. Same happy smile as the reference. |
| `hat_cat.png` | `[CHARACTER]` Bloopie wears a ginger cat hood with two pointed ears with pink inner ear; the spiral curl pokes out between the ears. Same happy smile as the reference. |
| `hat_frog.png` | `[CHARACTER]` Bloopie wears a green frog hat with two round frog eyes on top; the spiral curl pokes out between them. Same happy smile as the reference. |

```
python3 tools/art/import_render.py body cosy art_src/renders/hat_cosy.png
python3 tools/art/import_render.py body cat  art_src/renders/hat_cat.png
python3 tools/art/import_render.py body frog art_src/renders/hat_frog.png
```

### 2. Эмоции — 9 кадров

Сейчас закрытые веки, брови и рот дорисованы тушью поверх закрашенного лица. Из рендера
берётся только зона лица, поэтому эмоция подойдёт к любой шапочке.

| Имя | Что на лице |
| --- | --- |
| `sleepy` | eyes gently closed as soft downward arcs with eyelashes, calm small smile with the two-tooth block (also used for blinking and stasis) |
| `sad` | eyebrows raised at the inner ends, glossy teary eyes, small downturned mouth with the two-tooth block, one tear on the cheek |
| `angry` | cute frown, eyebrows lowered at the inner ends, puffed cheeks, flat mouth with the two-tooth block |
| `surprised` | perfectly round wide eyes, raised eyebrows, small round open mouth with the two-tooth block at the top |
| `confused` | one eyebrow raised, the other lowered, small sideways mouth with the two-tooth block |
| `shy` | eyes looking down and to the side, stronger blush, small smile with the two-tooth block |
| `proud` | half-closed confident eyes, satisfied smile with the two-tooth block |
| `curious` | wide attentive eyes looking slightly up, one eyebrow raised, small smile with the two-tooth block |
| `love` | heart-shaped highlights in the eyes, big blissful smile with the two-tooth block |

Промпт: `[CHARACTER] Same pose and body as the reference; change only the face: <строка из таблицы>.`

```
python3 tools/art/import_render.py expression sleepy art_src/renders/face_sleepy.png
```

Допустимые имена: `happy excited sleepy sad curious love angry surprised confused shy laugh proud`.

### 3. Комната у окна — 3 кадра

Сейчас закат и ночь — цветокоррекция одной картины, а место за пузырём речи достроено
приблизительно.

> Cozy 2D hand-painted lo-fi illustration, vertical 9:20. A wooden windowsill nook with a
> big window, warm fairy lights hanging across the window, leafy plant on the left, a large
> chunky peach knitted cushion in the centre of the lower third (empty, nobody sits on it),
> a second knitted pillow leaning behind it on the left, a table lamp on the right, a mug of
> cocoa on a stack of books at the bottom right, wooden floor with tiny warm light dots.
> No characters, no text, no UI. `<время суток>`

| Имя | `<время суток>` |
| --- | --- |
| `supporter:evening` | Rainy purple twilight outside, raindrops on the glass, blurry town lights. |
| `supporter:sunset` | Golden-pink sunset sky outside, no rain, warm light on the cushion. |
| `supporter:night` | Deep blue starry night outside, the room lit only by the lamp and fairy lights. |

Лучше всего генерировать закат и ночь **как правку вечернего кадра** («same room, change
only the sky and lighting»), чтобы мебель не съезжала при смене времени суток.

```
python3 tools/art/import_render.py room supporter:sunset art_src/renders/room_supporter_sunset.png
```

### 4. Комната шутника — 1 кадр

Сейчас шутник живёт в комнате у окна.

> Cozy 2D hand-painted lo-fi illustration, vertical 9:20. A playful creative corner by a
> window: a vinyl record player on the left, polaroid photos clipped to a string across the
> window frame, a wind-up toy duck and a pink ball on the right, warm fairy lights, a large
> chunky peach knitted cushion in the centre of the lower third (empty). Rainy purple
> twilight outside. No characters, no text, no UI.

```
python3 tools/art/import_render.py room joker:evening art_src/renders/room_joker.png
```

### 5. Мансарда исследователя — 1 кадр

Сейчас в картине мансарды место под Блупи и шляпой восстановлено размытием.

> Cozy 2D hand-painted lo-fi illustration, vertical 9:20. A wooden attic with a slanted
> skylight window showing a starry night sky, a brass telescope on a tripod and a globe on
> the left, bookshelves and a hanging plant on the right, a warm lantern, fairy lights along
> the beams, a large chunky peach knitted cushion in the centre of the lower third (empty).
> No characters, no text, no UI.

```
python3 tools/art/import_render.py room explorer:night art_src/renders/room_explorer.png
```

### 6. Купол стазиса — 1 кадр

> A glowing turquoise glass dome (cloche) with a frosted rim at the base, icy sparkles and
> soft highlights on the glass, empty inside, cozy 2D hand-painted illustration, centred,
> on a perfectly flat solid black background, no text.

Фон здесь **чёрный**, а не пурпурный: яркость становится прозрачностью, и стекло остаётся
стеклом.

```
python3 tools/art/import_render.py capsule dome art_src/renders/dome.png
```

### 7. Позы — 6 кадров

Сейчас при ходьбе, прыжке и игре двигается и сплющивается один спрайт.

| Имя | Промпт (после `[CHARACTER]`) |
| --- | --- |
| `walk_a` | mid-waddle, left foot stepping forward, body tilted slightly left, happy smile |
| `walk_b` | mid-waddle, right foot stepping forward, body tilted slightly right, happy smile |
| `crouch` | squashed low and wide, getting ready to jump, excited smile |
| `air` | stretched tall in mid-jump, feet off the ground, excited open smile |
| `curl` | lying down asleep, body flattened, eyes closed, calm smile with the two-tooth block |
| `reach` | leaning forward with both feet out, playfully reaching for something, excited smile |

Позы рисуются без шапочки; пока на Блупи шапочка, остаётся текущая анимация.

```
python3 tools/art/import_render.py pose walk_a art_src/renders/walk_a.png
```

### 8. Взросление — 2 кадра

Сейчас на Lv.10 и Lv.20 тот же Блупи, только крупнее.

| Имя | Промпт (после `[CHARACTER]`) |
| --- | --- |
| `teen` | a slightly older Bloopie: fuller 3-tuft cheek fur, a bigger curl, a confident sitting pose |
| `adult` | a grown-up Bloopie: thick voluminous curl, the fluffiest cheek fur, calm warm smile |

```
python3 tools/art/import_render.py stage teen art_src/renders/teen.png
```

## Как проверить кадр

После каждой команды в `tools/art/_preview/` появляется лист «было / стало» на фоне
комнаты. Если новый Блупи стоит не там или другого размера — значит, генератор изменил
пропорции тела; такой кадр лучше перегенерировать, чем править руками.

Что импортёр делает сам: убирает фон, подгоняет масштаб и положение по ширине тела и
точке под лапками, записывает кадр в `art/painted/painted.json`. Что он не исправит:
другую форму тела, другой ракурс, неровный фон.

Нужны только `numpy` и `Pillow`.
