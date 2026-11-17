extends RefCounted
## Данные игры: материалы, предметы, магазин, вечера и клиенты. Логику сюда не класть.
## Цвета хранятся строками "#rrggbb" и превращаются в Color через Color.html().

const START_MONEY := 20

## cpp: расход денег на 100 пикселей отрезанной бумаги. price: цена в магазине (0 = есть с начала).
## bonus: прибавка к оценке подарка за дорогой материал.
const PAPERS := [
	{"id": "red_stars", "name": "Красная со звёздочками", "tag": "red", "base": "#c23b3b", "accent": "#f6e7c8", "pattern": "stars", "cpp": 1.0, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "gold", "name": "Золотая", "tag": "gold", "base": "#d6a93f", "accent": "#fff1b8", "pattern": "lines", "cpp": 1.0, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "blue_stripes", "name": "Синяя в полоску", "tag": "blue", "base": "#2a4a8a", "accent": "#a9c4f0", "pattern": "stripes", "cpp": 1.0, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "kraft", "name": "Крафт", "tag": "kraft", "base": "#a97c50", "accent": "#5e4129", "pattern": "dots", "cpp": 0.6, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "green_polka", "name": "Зелёная в горошек", "tag": "green", "base": "#2f7a52", "accent": "#f0e6c8", "pattern": "polka", "cpp": 1.2, "price": 30, "premium": false, "bonus": 0.0},
	{"id": "white_snow", "name": "Белая со снежинками", "tag": "white", "base": "#e9edf5", "accent": "#7fa6dc", "pattern": "snow", "cpp": 1.2, "price": 35, "premium": false, "bonus": 0.0},
	{"id": "pink_check", "name": "Розовая в клетку", "tag": "pink", "base": "#e58aa8", "accent": "#fbd9e4", "pattern": "check", "cpp": 1.3, "price": 40, "premium": false, "bonus": 0.0},
	{"id": "purple_stars", "name": "Фиолетовая со звёздами", "tag": "purple", "base": "#5b3d8f", "accent": "#f2d98a", "pattern": "stars", "cpp": 1.5, "price": 45, "premium": false, "bonus": 0.0},
	{"id": "foil_silver", "name": "Серебряная фольга", "tag": "silver", "base": "#b8c0cc", "accent": "#ffffff", "pattern": "lines", "cpp": 3.0, "price": 90, "premium": true, "bonus": 0.10},
	{"id": "velvet_wine", "name": "Бархатная бордовая", "tag": "burgundy", "base": "#7d1f2e", "accent": "#e6b8a2", "pattern": "stars", "cpp": 3.5, "price": 110, "premium": true, "bonus": 0.12},
]

const RIBBONS := [
	{"id": "red", "name": "Красная лента", "color": "#d8343a", "cost": 2, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "green", "name": "Зелёная лента", "color": "#2f9a62", "cost": 2, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "gold", "name": "Золотая лента", "color": "#e3b84b", "cost": 2, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "blue", "name": "Синяя лента", "color": "#3a6fd1", "cost": 2, "price": 25, "premium": false, "bonus": 0.0},
	{"id": "pink", "name": "Розовая лента", "color": "#ee7fb0", "cost": 2, "price": 25, "premium": false, "bonus": 0.0},
	{"id": "silver", "name": "Серебряная лента", "color": "#c9d0dc", "cost": 5, "price": 60, "premium": true, "bonus": 0.05},
	{"id": "purple", "name": "Бархатная лента", "color": "#7a3fb0", "cost": 6, "price": 80, "premium": true, "bonus": 0.06},
]

const BOXES := [
	{"id": "kraft", "name": "Крафт-коробка", "color": "#b98a5e", "lid": "#a87c52", "cost": 3, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "white", "name": "Белая коробка", "color": "#f1ede4", "lid": "#ddd5c4", "cost": 6, "price": 50, "premium": true, "bonus": 0.06},
]

## kind: box (уже коробка), bottle, ball, bear, mug. tail: [x, y, dx, dy, длина] — собранный «хвост» бумаги.
const ITEMS := {
	"box_small": {"name": "Маленькая коробка", "kind": "box", "w": 150, "h": 120, "price": 12, "color": "#b98a5e"},
	"box_big": {"name": "Большая коробка", "kind": "box", "w": 210, "h": 140, "price": 16, "color": "#a87c52"},
	"bottle": {"name": "Бутылка", "kind": "bottle", "w": 230, "h": 70, "price": 14, "color": "#1f5a3a", "tail": [115, 0, 1, 0, 48]},
	"ball": {"name": "Мяч", "kind": "ball", "w": 150, "h": 150, "price": 14, "color": "#d94a3d", "tail": [75, 0, 1, 0, 40]},
	"bear": {"name": "Мишка", "kind": "bear", "w": 150, "h": 180, "price": 18, "color": "#a9703f", "tail": [0, -88, 0, -1, 44]},
	"mug": {"name": "Кружка", "kind": "mug", "w": 140, "h": 110, "price": 13, "color": "#f0ece0", "tail": [74, 0, 1, 0, 40]},
}

const TAG_NAMES := {
	"red": "красная", "gold": "золотая", "blue": "синяя", "kraft": "крафт", "green": "зелёная",
	"white": "белая", "pink": "розовая", "purple": "фиолетовая", "silver": "серебряная", "burgundy": "бордовая",
}

const RIBBON_NAMES := {
	"red": "красная", "green": "зелёная", "gold": "золотая", "blue": "синяя",
	"pink": "розовая", "silver": "серебряная", "purple": "бархатная",
}

## patience: сколько секунд клиент ждёт. clock: [начало, конец] в минутах от полуночи.
const EVENINGS := [
	{
		"date": "29 декабря",
		"sky": "#1b2347",
		"clock": [1290, 1500],
		"place": "ночной вокзал, у закрытой кассы",
		"patience": 170.0,
		"customers": [
			{
				"name": "Бабушка Нина", "item": "box_small", "paper": "gold", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#7a4b6e", "skin": "#e8c4a0", "hair": "#d8d8de", "hat": "bun", "hatc": "#e8d9a8",
				"request": "Добрый вечер! Внучке подарок. Она у меня обожает всё золотое.",
				"good": "Какая красота! Спасибо вам.",
				"ok": "Хорошо, спасибо. Она будет рада.",
				"meh": "Ну… главное, что от души.",
			},
			{
				"name": "Курьер Гоша", "item": "box_small", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#2f6f8f", "skin": "#d9a679", "hair": "#3a2a20", "hat": "cap", "hatc": "#e0a030",
				"request": "Бегу на поезд! Что-нибудь простое, лишь бы красиво.",
				"good": "Ого, быстро и красиво! Побежал!",
				"ok": "Нормально, спасибо! Опаздываю!",
				"meh": "Ладно, некогда придираться.",
			},
			{
				"name": "Лёва", "item": "box_small", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "free",
				"coat": "#c94f4f", "skin": "#f0cfa8", "hair": "#6b4a2a", "hat": "beanie", "hatc": "#3a7bd5",
				"request": "У меня тут монетки… Это маме. Хочу самое красивое! И бант побольше!",
				"good": "Мама обрадуется! Спасибо огромное!",
				"ok": "Красиво. Спасибо!",
				"meh": "Бант мог бы быть и побольше… но спасибо.",
			},
			{
				"name": "Господин Ковалёв", "item": "box_big", "paper": "blue", "ribbon": "none", "bow": "any", "wrap": "free",
				"coat": "#33384a", "skin": "#e0b894", "hair": "#222222", "hat": "none", "hatc": "#8a8fa0",
				"request": "Добрый вечер. Синяя бумага, и без ленточек. Он их терпеть не может.",
				"good": "Безупречно. Благодарю.",
				"ok": "Сойдёт. Благодарю.",
				"meh": "Хм. Не совсем то, но благодарю.",
			},
		],
	},
	{
		"date": "30 декабря",
		"sky": "#141a3c",
		"clock": [1290, 1500],
		"place": "заправка на пустой трассе",
		"patience": 150.0,
		"customers": [
			{
				"name": "Тётя Вера", "item": "box_big", "paper": "red", "ribbon": "green", "bow": "any", "wrap": "free",
				"coat": "#2f7a5a", "skin": "#eac6a2", "hair": "#8a3b2a", "hat": "beanie", "hatc": "#f2c14e",
				"request": "Племяннику! Красная бумага и зелёная ленточка, как в детстве у нас было.",
				"good": "Точь-в-точь как в детстве! Спасибо!",
				"ok": "Мило. Спасибо.",
				"meh": "Ой… ну, он поймёт.",
			},
			{
				"name": "Дима", "item": "bottle", "paper": "any", "ribbon": "none", "bow": "any", "wrap": "shape",
				"coat": "#4a4f5e", "skin": "#d6a47c", "hair": "#1e1e1e", "hat": "cap", "hatc": "#2e2e2e",
				"request": "Бутылка шампанского коллеге. Без коробки и без бантов, пусть сразу видно, что это бутылка.",
				"good": "То что надо. Коллега оценит.",
				"ok": "Нормально, спасибо.",
				"meh": "Коробка или бантик лишние, но ладно.",
			},
			{
				"name": "Аня", "item": "mug", "paper": "kraft", "ribbon": "any", "bow": "small", "wrap": "box",
				"coat": "#9a5fb0", "skin": "#f1d2b6", "hair": "#2c1a14", "hat": "beanie", "hatc": "#e86a8a",
				"request": "Кружка для подруги. Крафт, она любит простое, и в коробку. Бантик только маленький.",
				"good": "Идеально! Она влюбится в это.",
				"ok": "Милый подарок, спасибо!",
				"meh": "Я представляла иначе. Но спасибо!",
			},
			{
				"name": "Дед Мороз (ну, почти)", "item": "bear", "paper": "red", "ribbon": "red", "bow": "big", "wrap": "shape",
				"coat": "#c52b2b", "skin": "#e8c4a0", "hair": "#f4f4f4", "hat": "santa", "hatc": "#c52b2b",
				"request": "Хо-хо-хо! Мишка внукам. Всё красное, без коробки, и бант побольше!",
				"good": "Хо-хо! Волшебство, не иначе!",
				"ok": "Хо-хо, неплохо!",
				"meh": "Ох-хо-хо… ну, дети простят.",
			},
			{
				"name": "Алина", "item": "bottle", "paper": "blue", "ribbon": "gold", "bow": "any", "wrap": "box",
				"coat": "#3a8fa8", "skin": "#c98f66", "hair": "#101010", "hat": "none", "hatc": "#f2c14e",
				"request": "Папе. Он любит классику: в коробку, синяя бумага и золотая лента.",
				"good": "Он будет в восторге! Спасибо!",
				"ok": "Красиво. Спасибо!",
				"meh": "Ну… он у меня неприхотливый.",
			},
		],
	},
	{
		"date": "31 декабря",
		"sky": "#0c1030",
		"clock": [1260, 1439],
		"place": "подъезд многоэтажки",
		"patience": 130.0,
		"customers": [
			{
				"name": "Семья Орловых", "item": "ball", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "box",
				"coat": "#d28a2f", "skin": "#e8c4a0", "hair": "#7a4a2a", "hat": "cap", "hatc": "#1f6f5a",
				"request": "Мяч сыну. Пусть не догадается, что внутри: только в коробку! И бант побольше.",
				"good": "Ни за что не догадается! Спасибо!",
				"ok": "Хорошо, спасибо!",
				"meh": "Он, пожалуй, догадается. Но спасибо.",
			},
			{
				"name": "Мария Ивановна", "item": "box_small", "paper": "gold", "ribbon": "red", "bow": "any", "wrap": "free",
				"coat": "#6a3f5a", "skin": "#ecd0b0", "hair": "#9a9aa6", "hat": "bun", "hatc": "#cfcfd8",
				"request": "Классной руководительнице. Золотая бумага и красная ленточка, пожалуйста.",
				"good": "Просто праздник в коробке. Спасибо!",
				"ok": "Хорошо. Спасибо.",
				"meh": "Ну… главное, внимание.",
			},
			{
				"name": "Саша", "item": "ball", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#37a37a", "skin": "#dfb48c", "hair": "#c24f2a", "hat": "beanie", "hatc": "#f2f2f2",
				"request": "Другу на Новый год. Что-нибудь весёлое! Как удобно, так и заворачивайте.",
				"good": "Вот это настроение! Спасибо!",
				"ok": "Неплохо, спасибо!",
				"meh": "Ладно, друг оценит старание.",
			},
			{
				"name": "Прохожий в шарфе", "item": "bear", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "free",
				"coat": "#2c3e66", "skin": "#e3bd98", "hair": "#3b2b20", "hat": "beanie", "hatc": "#e24b4b",
				"request": "Успеваю до полуночи! Мишка, самая красивая упаковка, какая получится.",
				"good": "Минута в минуту! Спасибо огромное!",
				"ok": "Успел. Спасибо!",
				"meh": "Ладно, главное, что успел. Спасибо.",
			},
			{
				"name": "Соседка со второго этажа", "item": "box_big", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free", "free": true,
				"coat": "#a85a6a", "skin": "#f0d0b0", "hair": "#5a3a2a", "hat": "none", "hatc": "#f2c14e",
				"request": "Вы весь вечер заворачивали подарки другим. Этот заверните для себя, как нравится.",
				"good": "С Новым годом!",
				"ok": "С Новым годом!",
				"meh": "С Новым годом!",
			},
		],
	},
]


## Строки для «талона заказа» на рабочем столе.
static func ticket_lines(c: Dictionary) -> Array:
	var lines: Array = []
	if c.get("free", false):
		lines.append("Как вам нравится")
		return lines
	var p: String = c["paper"]
	if p == "any":
		lines.append("Бумага: любая")
	else:
		lines.append("Бумага: " + str(TAG_NAMES[p]))
	var r: String = c["ribbon"]
	if r == "none":
		lines.append("Без ленты")
	elif r == "any":
		lines.append("Лента: любая")
	else:
		lines.append("Лента: " + str(RIBBON_NAMES[r]))
	var b: String = c["bow"]
	if b == "big":
		lines.append("Бант: большой")
	elif b == "small":
		lines.append("Бант: маленький")
	var kind: String = ITEMS[c["item"]]["kind"]
	var w: String = c["wrap"]
	if kind != "box":
		if w == "box":
			lines.append("В коробку")
		elif w == "shape":
			lines.append("По форме, без коробки")
		else:
			lines.append("Коробка: как удобно")
	return lines
