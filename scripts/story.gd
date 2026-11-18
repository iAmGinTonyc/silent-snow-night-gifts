extends RefCounted
## Реплики демки: внутренний голос героя в первую ночь, приветствия клиентов (лор по ходу диалогов)
## и сцена с Сантой. Тексты английские, как и вся игра; пояснения к сюжету в STORY.md.

## Первое появление героя за прилавком: мы эльфы-ИП и впервые ведём дело сами.
const INTRO := [
	{"who": "", "text": "Night one. First time running the shop all by myself."},
	{"who": "", "text": "No boss, no schedule, nobody to check the list. Just me, the cat and a very large pile of paper."},
	{"who": "", "text": "Self-employed elf. Sounds grand. Let's see what I have learned."},
]

## Приветствия до мысли клиента (поле hello): первый гость объясняет, что лавка появилась из ниоткуда,
## дальше на это ссылаются другие. Показываются в облачке, по строке за раз.
const HELLO := {
	"Mrs. Tanaka": [
		"Oh! Good evening. Forgive me, but there was only a wall here when I came to the platform.",
		"And now a little shop with snow on its roof! My grandmother used to say that on winter nights a shop appears wherever someone needs a gift in a hurry.",
		"I always thought it was only a story. How lovely to be wrong.",
	],
	"Mateo": ["Is this shop new? I take this platform every day and I have never seen it. No time to wonder, my night train leaves soon!"],
	"Ingrid": ["A shop that was not here this morning? Strange. But the lights are so warm that I do not mind."],
	"Pavel": ["They say the shop shows up when someone is truly out of options. I qualify. Please, quickly."],
	"Mr. Okafor": ["So it is true. A shop that opens only at night, and the wall does not even remember it."],
	"Auntie Meena": ["Beta, an hour ago this gas station sold only gasoline. Now there are lights and a cat? I will ask no questions."],
	"Kwame": ["A shop out here on the empty highway! Do you move from place to place?"],
	"Father Christmas (sort of)": ["Ho ho... ahem. A fine little shop. Very... tidy. I am just looking around. For a friend. Who cares about small shops."],
	"Granny Zeynep": ["I felt a warm light from far away, like in the old stories. And here it is."],
	"The Murphy family": ["The mailboxes were here, the wall was here, and now a shop between them! Kids, do not touch the sign."],
	"Mrs. Fernandez": ["I have lived in this building for thirty years and never seen a shop in the entrance. I like it more than the mailboxes."],
	"Mr. Al-Rashid": ["Interesting. A shop that comes to the customer. Excellent business model."],
	"Dona Rosa from upstairs": ["Good evening, dear. I live upstairs and saw a glow in the entrance. Imagine, a whole shop in our building!"],
}

## Сцена в конце ночи 3: приходит Санта. Поле face: какой кадр лица показать (0 вздох, 1 думает,
## 2 привет, 3 мечтает, 4 показывает, 6 смех).
const SANTA := [
	{"who": "Santa", "face": 2, "text": "Well, well. The smallest shop in the world, in the middle of nowhere. I'd know that cat anywhere."},
	{"who": "Elf", "face": 2, "text": "Boss?! What brings you here?"},
	{"who": "Santa", "face": 2, "text": "Checking on my best employee. How is life as your own boss?",
		"choices": ["Busy. Good busy.", "The paper tears, the cat naps. I love it."]},
	{"who": "Santa", "face": 6, "text": "Good. That's good. I never got to be my own boss, you know. Eleven hundred years behind a desk."},
	{"who": "Santa", "face": 0, "text": "My back hurts, my knees creak, and the reindeer snore in meetings. I want to retire. Sit on a beach. A snowy beach, but a beach."},
	{"who": "Elf", "face": 0, "text": "So retire!"},
	{"who": "Santa", "face": 1, "text": "To whom do I leave it? Every elf I ask wants a raise or the sleigh. One counted every gift twice. He is still counting."},
	{"who": "Santa", "face": 3, "text": "Hm. Wrap me one gift before I go. Empty. I don't know yet what goes inside."},
]

## Прощание после упаковки пустой коробки.
const SANTA_BYE := [
	{"who": "Santa", "face": 4, "text": "Neat. Very neat. Hm."},
	{"who": "Santa", "face": 2, "text": "I'll be back before New Year. Keep the cat warm!"},
]

## Конец демки.
const DEMO_END_TITLE := "To be continued..."
const DEMO_END_TEXT := "The rest of the story is still being wrapped."
