extends Node
## Talks to the FastAPI backend (POST /v1/interact with a Bearer token, Gemini
## Flash structured output).
## If the backend is unreachable or answers with garbage, an on-device fallback
## reply is produced so the game stays fully playable offline.

signal request_started
signal reply_received(response: Dictionary)

const ENDPOINT := "/v1/interact"
const TIMEOUT_SECONDS := 8.0
const MAX_MESSAGE_LENGTH := 400
const MAX_REPLY_LENGTH := 320

const FALLBACK_REPLIES := {
	"supporter": {
		"greeting": ["Привет! Я так рад, что ты заглянул. Садись рядом, тут тепло.", "Привет-привет. Я как раз грел для тебя место на подушке."],
		"tired": ["Ты сегодня много сделал. Давай просто посидим и послушаем дождь.", "Устать — это нормально. Я рядом, никуда не тороплю."],
		"sad": ["Мне жаль, что так вышло. Хочешь, расскажи, а я тихонько послушаю.", "Я с тобой. Плохие дни тоже заканчиваются, а я останусь."],
		"happy": ["Как здорово! От твоей радости мне самому теплее.", "Ура! Запомню этот момент, он хороший."],
		"joke": ["Почему подушка никогда не спорит? Она за мягкие решения.", "Какао сказало молоку: без тебя я просто горький порошок."],
		"thanks": ["И тебе спасибо, что ты есть.", "Мне приятно. Обнимаю тебя лапками."],
		"love": ["И я тебя очень люблю. Прямо до кончика завитка.", "Ты мой самый тёплый человек."],
		"question": ["Хороший вопрос. Давай подумаем вместе, не спеша.", "Я не всё знаю, но мне интересно разобраться вместе с тобой."],
		"default": ["Я тебя слушаю. Рассказывай, мне правда интересно.", "Понимаю. Спасибо, что делишься со мной.", "Мне нравится сидеть с тобой и болтать под дождь."],
	},
	"explorer": {
		"greeting": ["Привет! Я только что считал звёзды и сбился на тебе.", "О, ты пришёл! Смотри, какое сегодня небо."],
		"tired": ["Даже кометы отдыхают между витками. Отдохни, я посторожу небо.", "Давай ляжем и будем просто смотреть вверх."],
		"sad": ["Знаешь, после самой тёмной ночи звёзды видно лучше всего. Я рядом.", "Грусть — как облако: закрывает небо, но не навсегда."],
		"happy": ["Вот это открытие дня! Записываю в бортовой журнал.", "Сияешь ярче Сириуса!"],
		"joke": ["Почему Луна не ходит в школу? У неё и так все фазы пройдены.", "Что сказал телескоп звезде? Я на тебя глаз положил."],
		"thanks": ["Всегда пожалуйста, мой напарник по экспедициям.", "Это взаимно, как гравитация."],
		"love": ["Ты моя любимая точка на карте созвездий.", "Я бы назвал в твою честь звезду."],
		"question": ["Ух, люблю вопросы! Давай исследуем это вместе.", "Интересно! А как думаешь ты сам?"],
		"default": ["Расскажи ещё, мне любопытно.", "Хм, это стоит исследовать!", "Я записал это в журнал наблюдений."],
	},
	"joker": {
		"greeting": ["Привет! Я тут подушку грел. Она сказала, что я тёплый тип.", "Приветики! День сразу стал на одного человека лучше."],
		"tired": ["Устал? Ложись. Я официально разрешаю ничего не делать.", "Отдых — это тоже дело. Причём самое уютное."],
		"sad": ["Иди сюда. Шутки подождут, сначала обнимашки.", "Я рядом. А когда захочешь улыбнуться, у меня припасён каламбур."],
		"happy": ["Вот это настроение! Включаю праздничный винил.", "Ура-ура! Танцую лапками."],
		"joke": ["Почему какао не опаздывает? Оно всегда приходит в кружке друзей.", "Что делает дождь в выходной? Капает на мозги тучам.", "Зачем утке завод? Чтобы день был заводной."],
		"thanks": ["Обращайся! Я работаю за обнимашки.", "Пожалуйста! С тебя улыбка."],
		"love": ["Я тебя тоже! Аж завиток закрутился.", "Ой, всё. Я растаял, как зефирка в какао."],
		"question": ["Вопрос на миллион! Жаль, у меня только мячик.", "Давай подумаем. Я, чур, думаю вслух."],
		"default": ["Ха, неплохо! Рассказывай дальше.", "Записал в блокнот смешных мыслей.", "С тобой не соскучишься!"],
	},
}

const KEYWORDS := {
	"greeting": ["привет", "здравств", "хай", "добрый", "доброе", "hello", "hi "],
	"tired": ["устал", "устала", "вымотал", "сил нет", "tired", "спать хочу"],
	"sad": ["груст", "плохо", "тяжело", "тревож", "одинок", "плач", "sad", "трудн"],
	"happy": ["рад", "счастлив", "ура", "класс", "отлично", "получилось", "happy", "хорошо"],
	"joke": ["шутк", "пошути", "анекдот", "рассмеши", "joke", "смешн"],
	"thanks": ["спасибо", "благодар", "thank"],
	"love": ["люблю", "обнима", "love", "скучал"],
}
const TOPIC_EMOTIONS := {
	"greeting": "happy", "tired": "sleepy", "sad": "sad", "happy": "excited",
	"joke": "laugh", "thanks": "shy", "love": "love", "question": "curious",
	"default": "happy",
}

var is_busy := false

var _http: HTTPRequest
var _pending_message := ""
var _pending_event := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)


## Sends a chat message. `event` carries gameplay results, e.g.
## {"type": "vocal_result", "accuracy_percent": 87}.
func send_message(message: String, event: Dictionary = {}) -> void:
	if is_busy:
		return
	is_busy = true
	_pending_message = message.strip_edges().left(MAX_MESSAGE_LENGTH)
	_pending_event = event
	request_started.emit()
	var payload := {
		"message": _pending_message,
		"player_name": GameState.player_name,
		"archetype": GameState.archetype,
		"stats": {
			"hunger": GameState.hunger,
			"hygiene": GameState.hygiene,
			"energy": GameState.energy,
			"mood": GameState.mood,
			"pet_level": GameState.pet_level,
			"vocal_level": GameState.vocal_level,
		},
		"recent_memories": GameState.recent_memories,
		"context": TimeWeatherSystem.get_context(),
		"event": event,
	}
	var base_url := str(ProjectSettings.get_setting("bloopie/backend_url", "")).strip_edges()
	if base_url.is_empty():
		_emit_offline_fallback.call_deferred()
		return
	var error := _http.request(
		base_url.trim_suffix("/") + ENDPOINT,
		PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer %s" % str(ProjectSettings.get_setting("bloopie/api_token", "")),
		]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload))
	if error != OK:
		_emit_offline_fallback.call_deferred()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_emit_offline_fallback()
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		_emit_offline_fallback()
		return
	var response := _sanitize(parsed)
	if response.is_empty():
		_emit_offline_fallback()
		return
	_finish(response)


## Validates the BloopieAIResponse contract; returns {} when it is unusable.
func _sanitize(raw: Dictionary) -> Dictionary:
	var text := str(raw.get("reply_text", "")).strip_edges()
	if text.is_empty():
		return {}
	var emotion := str(raw.get("emotion_animation", "happy"))
	if not GameState.EMOTIONS.has(emotion):
		emotion = "happy"
	var deltas: Variant = raw.get("stat_deltas", {})
	if typeof(deltas) != TYPE_DICTIONARY:
		deltas = {}
	var memory: Variant = raw.get("save_to_memory", null)
	return {
		"reply_text": text.left(MAX_REPLY_LENGTH),
		"emotion_animation": emotion,
		"stat_deltas": {
			"mood_delta": clampi(int(deltas.get("mood_delta", 0)), -10, 10),
			"energy_delta": clampi(int(deltas.get("energy_delta", 0)), -10, 10),
			"affection_delta": clampi(int(deltas.get("affection_delta", 0)), 0, 15),
		},
		"save_to_memory": "" if memory == null else str(memory).strip_edges().left(120),
		"offline": false,
	}


func _emit_offline_fallback() -> void:
	var response: Dictionary
	if _pending_event.get("type", "") == "vocal_result":
		response = _vocal_fallback(int(_pending_event.get("accuracy_percent", 50)))
	else:
		response = _chat_fallback(_pending_message)
	response["offline"] = true
	_finish(response)


func _chat_fallback(message: String) -> Dictionary:
	var topic := _detect_topic(message)
	var lines: Array = FALLBACK_REPLIES[GameState.archetype][topic]
	var memory := ""
	if topic in ["sad", "happy", "love"] and message.length() >= 12:
		memory = "Ты поделился: «%s»" % message.left(70)
	return {
		"reply_text": lines[_rng.randi() % lines.size()],
		"emotion_animation": TOPIC_EMOTIONS[topic],
		"stat_deltas": {
			"mood_delta": 4 if topic != "sad" else 1,
			"energy_delta": -1,
			"affection_delta": 6 if not memory.is_empty() else 3,
		},
		"save_to_memory": memory,
	}


func _vocal_fallback(accuracy: int) -> Dictionary:
	var text: String
	var emotion: String
	var memory := ""
	if accuracy >= 90:
		text = "Ого, %d%%! Мы спели почти идеально. Я горжусь нашим дуэтом!" % accuracy
		emotion = "proud"
		memory = "Мы спели дуэтом на %d%%" % accuracy
	elif accuracy >= 60:
		text = "%d%% — это было красиво! Мне нравится петь с тобой." % accuracy
		emotion = "excited"
	else:
		text = "Мы немного разошлись с мелодией, зато как душевно! Споём ещё?"
		emotion = "laugh"
	return {
		"reply_text": text,
		"emotion_animation": emotion,
		"stat_deltas": {"mood_delta": 5, "energy_delta": -4, "affection_delta": 4 + accuracy / 20},
		"save_to_memory": memory,
	}


func _detect_topic(message: String) -> String:
	var lowered := " " + message.to_lower() + " "
	for topic: String in KEYWORDS:
		for keyword: String in KEYWORDS[topic]:
			if lowered.contains(keyword):
				return topic
	return "question" if lowered.contains("?") else "default"


func _finish(response: Dictionary) -> void:
	is_busy = false
	_pending_event = {}
	reply_received.emit(response)
