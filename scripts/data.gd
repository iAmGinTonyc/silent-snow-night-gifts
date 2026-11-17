extends RefCounted
## Game data: materials, items, shop, nights and customers. No logic here.
## Colors are stored as "#rrggbb" strings and turned into Color with Color.html().
## The game is in English. Customers come from all over the world because the shop travels.

const START_MONEY := 20

## cpp: coins per 100 px of paper pulled from the roll. price: shop price (0 = owned from the start).
## bonus: extra rating for a premium material.
const PAPERS := [
	{"id": "red_stars", "name": "Red with stars", "tag": "red", "base": "#c23b3b", "accent": "#f6e7c8", "pattern": "stars", "cpp": 1.0, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "gold", "name": "Gold", "tag": "gold", "base": "#d6a93f", "accent": "#fff1b8", "pattern": "lines", "cpp": 1.0, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "blue_stripes", "name": "Blue stripes", "tag": "blue", "base": "#2a4a8a", "accent": "#a9c4f0", "pattern": "stripes", "cpp": 1.0, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "kraft", "name": "Kraft", "tag": "kraft", "base": "#a97c50", "accent": "#5e4129", "pattern": "dots", "cpp": 0.6, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "green_polka", "name": "Green polka dots", "tag": "green", "base": "#2f7a52", "accent": "#f0e6c8", "pattern": "polka", "cpp": 1.2, "price": 30, "premium": false, "bonus": 0.0},
	{"id": "white_snow", "name": "White snowflakes", "tag": "white", "base": "#e9edf5", "accent": "#7fa6dc", "pattern": "snow", "cpp": 1.2, "price": 35, "premium": false, "bonus": 0.0},
	{"id": "pink_check", "name": "Pink check", "tag": "pink", "base": "#e58aa8", "accent": "#fbd9e4", "pattern": "check", "cpp": 1.3, "price": 40, "premium": false, "bonus": 0.0},
	{"id": "purple_stars", "name": "Purple stars", "tag": "purple", "base": "#5b3d8f", "accent": "#f2d98a", "pattern": "stars", "cpp": 1.5, "price": 45, "premium": false, "bonus": 0.0},
	{"id": "foil_silver", "name": "Silver foil", "tag": "silver", "base": "#b8c0cc", "accent": "#ffffff", "pattern": "lines", "cpp": 3.0, "price": 90, "premium": true, "bonus": 0.10},
	{"id": "velvet_wine", "name": "Velvet burgundy", "tag": "burgundy", "base": "#7d1f2e", "accent": "#e6b8a2", "pattern": "stars", "cpp": 3.5, "price": 110, "premium": true, "bonus": 0.12},
]

## cost: coins per 100 px of ribbon you draw.
const RIBBONS := [
	{"id": "red", "name": "Red ribbon", "color": "#d8343a", "cost": 1, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "green", "name": "Green ribbon", "color": "#2f9a62", "cost": 1, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "gold", "name": "Gold ribbon", "color": "#e3b84b", "cost": 1, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "blue", "name": "Blue ribbon", "color": "#3a6fd1", "cost": 1, "price": 25, "premium": false, "bonus": 0.0},
	{"id": "pink", "name": "Pink ribbon", "color": "#ee7fb0", "cost": 1, "price": 25, "premium": false, "bonus": 0.0},
	{"id": "silver", "name": "Silver ribbon", "color": "#c9d0dc", "cost": 3, "price": 60, "premium": true, "bonus": 0.05},
	{"id": "purple", "name": "Velvet ribbon", "color": "#7a3fb0", "cost": 4, "price": 80, "premium": true, "bonus": 0.06},
]

const BOXES := [
	{"id": "kraft", "name": "Kraft box", "color": "#b98a5e", "lid": "#a87c52", "cost": 3, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "white", "name": "White box", "color": "#f1ede4", "lid": "#ddd5c4", "cost": 6, "price": 50, "premium": true, "bonus": 0.06},
]

## kind: box (already a box), bottle, ball, bear, mug, ornament, train.
## tail: [x, y, dx, dy, length], the gathered end of the paper. sell/stock: price we charge and what it costs us.
const ITEMS := {
	"box_small": {"name": "Small box", "kind": "box", "w": 150, "h": 120, "price": 12, "color": "#b98a5e"},
	"box_big": {"name": "Large box", "kind": "box", "w": 210, "h": 140, "price": 16, "color": "#a87c52"},
	"bottle": {"name": "Bottle", "kind": "bottle", "w": 230, "h": 70, "price": 14, "color": "#1f5a3a", "tail": [115, 0, 1, 0, 48]},
	"mug": {"name": "Mug", "kind": "mug", "w": 140, "h": 110, "price": 13, "color": "#f0ece0", "tail": [74, 0, 1, 0, 40]},
	"ball": {"name": "Football", "kind": "ball", "w": 150, "h": 150, "price": 14, "color": "#f4f1ea", "tail": [75, 0, 1, 0, 40], "sell": 24, "stock": 10},
	"bear": {"name": "Teddy bear", "kind": "bear", "w": 150, "h": 180, "price": 18, "color": "#a9703f", "tail": [0, -88, 0, -1, 44], "sell": 30, "stock": 12},
	"ornament": {"name": "Christmas ornament", "kind": "ornament", "w": 110, "h": 124, "price": 10, "color": "#c93a4a", "tail": [0, -62, 0, -1, 34], "sell": 18, "stock": 6},
	"train": {"name": "Toy train", "kind": "train", "w": 232, "h": 66, "price": 16, "color": "#c93a4a", "tail": [118, 0, 1, 0, 40], "sell": 34, "stock": 14},
}

## The minimal set of gifts we keep in stock.
const STOCK := ["bear", "ornament", "ball", "train"]

## What a buyer says when we offer a gift.
const BUYER_LINES := {
	"perfect": "You read my mind! This is exactly it.",
	"ok": "Hmm, I suppose that will do.",
	"miss": "Well... all right, I will take it.",
}

const TAG_NAMES := {
	"red": "red", "gold": "gold", "blue": "blue", "kraft": "kraft", "green": "green",
	"white": "white", "pink": "pink", "purple": "purple", "silver": "silver", "burgundy": "burgundy",
}

const RIBBON_NAMES := {
	"red": "red", "green": "green", "gold": "gold", "blue": "blue",
	"pink": "pink", "silver": "silver", "purple": "velvet",
}

## patience: seconds a customer waits. clock: [start, end] in minutes since midnight, for the wall clock.
const EVENINGS := [
	{
		"date": "29 December",
		"sky": "#1b2347",
		"clock": [1290, 1500],
		"place": "Kyoto, a night platform by a closed ticket office",
		"patience": 170.0,
		"customers": [
			{
				"name": "Mrs. Tanaka", "item": "box_small", "paper": "gold", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#7a4b6e", "skin": "#e8c8a4", "hair": "#d8d8de", "hat": "bun", "hatc": "#e8d9a8",
				"request": "Good evening. A gift for my granddaughter. She adores anything golden.",
				"good": "How beautiful! Thank you so much.",
				"ok": "Lovely. She will be happy.",
				"meh": "Well... it is the thought that counts.",
			},
			{
				"name": "Mateo", "item": "box_small", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#2f6f8f", "skin": "#d3a07a", "hair": "#2a1d16", "hat": "cap", "hatc": "#e0a030",
				"request": "I am running for the night train! Something simple, just make it pretty.",
				"good": "Wow, fast and pretty! Gracias!",
				"ok": "Good enough, gracias! I am late!",
				"meh": "Fine, no time to complain.",
			},
			{
				"kind": "buyer", "mode": "mind", "ideal": "ornament", "okay": ["bear"],
				"name": "Ingrid", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#5a6f8f", "skin": "#f3dccb", "hair": "#d8b46a", "hat": "beanie", "hatc": "#c0504d",
				"thought": "My friend just moved into an empty apartment. It is cold and smells of paint. I want it to feel cozy and festive, even with one shiny little thing.",
				"request": "",
				"good": "Thank you! This is what the place was missing.",
				"ok": "Nice. Thank you.",
				"meh": "Well... all right. Thanks.",
			},
			{
				"name": "Leo", "item": "box_small", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "free",
				"coat": "#c94f4f", "skin": "#c68b62", "hair": "#2a1d16", "hat": "beanie", "hatc": "#3a7bd5",
				"request": "I have a few coins... this is for my mom. I want the prettiest one! And a big bow!",
				"good": "Mom will love it! Thank you so much!",
				"ok": "Pretty. Thanks!",
				"meh": "The bow could have been bigger... but thanks.",
			},
			{
				"kind": "buyer", "mode": "ask", "ideal": "bear", "okay": [],
				"name": "Pavel", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#2f6f8f", "skin": "#ecd0b0", "hair": "#6a4a2a", "hat": "cap", "hatc": "#e0a030",
				"request": "A teddy bear please. For my daughter, she is three. It is urgent!",
				"good": "She will be thrilled! Thank you!",
				"ok": "Great, thanks!",
				"meh": "Fine, no time to argue.",
			},
			{
				"name": "Mr. Okafor", "item": "box_big", "paper": "blue", "ribbon": "none", "bow": "any", "wrap": "free",
				"coat": "#33384a", "skin": "#7a4f35", "hair": "#16110e", "hat": "none", "hatc": "#8a8fa0",
				"request": "Good evening. Blue paper, and no ribbons. He cannot stand them.",
				"good": "Flawless. Thank you.",
				"ok": "Acceptable. Thank you.",
				"meh": "Hm. Not quite right, but thank you.",
			},
		],
	},
	{
		"date": "30 December",
		"sky": "#141a3c",
		"clock": [1290, 1500],
		"place": "a lonely gas station on a Patagonian highway",
		"patience": 150.0,
		"customers": [
			{
				"name": "Auntie Meena", "item": "box_big", "paper": "red", "ribbon": "green", "bow": "any", "wrap": "free",
				"coat": "#2f7a5a", "skin": "#a8754f", "hair": "#1c1410", "hat": "beanie", "hatc": "#f2c14e",
				"request": "For my nephew! Red paper and a green ribbon, like when we were kids.",
				"good": "Exactly like back then! Thank you!",
				"ok": "Sweet. Thank you.",
				"meh": "Oh... well, he will understand.",
			},
			{
				"name": "Dmitri", "item": "bottle", "paper": "any", "ribbon": "none", "bow": "any", "wrap": "shape",
				"coat": "#4a4f5e", "skin": "#e7c9aa", "hair": "#3a2a20", "hat": "ushanka", "hatc": "#6b5a4a",
				"request": "A bottle of champagne for a colleague. No box and no bows, I want it to look like a bottle.",
				"good": "Exactly right. My colleague will appreciate it.",
				"ok": "Fine, thanks.",
				"meh": "The box or the bow is too much, but all right.",
			},
			{
				"kind": "buyer", "mode": "mind", "ideal": "ball", "okay": [],
				"name": "Kwame", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#4a4f5e", "skin": "#6e4630", "hair": "#14100e", "hat": "cap", "hatc": "#2e2e2e",
				"thought": "My son came home covered in mud again. He plays until dark and shouts Goal! I want him to have something to kick.",
				"request": "",
				"good": "That is a great kick! Thank you.",
				"ok": "It will do, thanks.",
				"meh": "Not quite what I imagined, but thanks.",
			},
			{
				"name": "Anh", "item": "mug", "paper": "kraft", "ribbon": "any", "bow": "small", "wrap": "box",
				"coat": "#9a5fb0", "skin": "#e2bf98", "hair": "#14100e", "hat": "beanie", "hatc": "#e86a8a",
				"request": "A mug for my friend. Kraft paper, she likes simple things, and in a box please. Only a tiny bow.",
				"good": "Perfect! She will love it.",
				"ok": "Sweet gift, thanks!",
				"meh": "I pictured it differently. But thanks!",
			},
			{
				"name": "Father Christmas (sort of)", "item": "bear", "paper": "red", "ribbon": "red", "bow": "big", "wrap": "shape",
				"coat": "#c52b2b", "skin": "#e8c4a0", "hair": "#f4f4f4", "hat": "santa", "hatc": "#c52b2b",
				"request": "Ho ho ho! A teddy bear for the grandchildren. All red, no box, and a big bow so they can see it from afar!",
				"good": "Ho ho! Pure magic!",
				"ok": "Ho ho, not bad!",
				"meh": "Oh ho ho... well, the kids will forgive.",
			},
			{
				"kind": "buyer", "mode": "mind", "ideal": "train", "okay": [],
				"name": "Granny Zeynep", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#7a4b6e", "skin": "#d7b08a", "hair": "#cfcfd8", "hat": "hijab", "hatc": "#4a7f8a",
				"thought": "My grandson Timur is five. Anything that hums and runs on rails is a miracle to him. He stands at the window for hours waiting for the train.",
				"request": "",
				"good": "Choo choo! He will be so happy, thank you.",
				"ok": "Good, thank you.",
				"meh": "Well... it is the attention that matters.",
			},
			{
				"name": "Aaliyah", "item": "bottle", "paper": "blue", "ribbon": "gold", "bow": "any", "wrap": "box",
				"coat": "#3a8fa8", "skin": "#c9a07a", "hair": "#101010", "hat": "hijab", "hatc": "#d9c36a",
				"request": "For my father. He likes the classics: in a box, blue paper and a gold ribbon.",
				"good": "He will be delighted! Thank you!",
				"ok": "Nice. Thank you!",
				"meh": "Well... he is easy to please.",
			},
		],
	},
	{
		"date": "31 December",
		"sky": "#0c1030",
		"clock": [1260, 1439],
		"place": "a stairwell in a Lisbon apartment block",
		"patience": 130.0,
		"customers": [
			{
				"name": "The Murphy family", "item": "ball", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "box",
				"coat": "#d28a2f", "skin": "#f1d5c0", "hair": "#b8532a", "hat": "cap", "hatc": "#1f6f5a",
				"request": "A football for our son. Do not let him guess what is inside, so a box please! And a big bow.",
				"good": "He will never guess! Thank you!",
				"ok": "Good, thanks!",
				"meh": "He will probably guess. But thanks.",
			},
			{
				"kind": "buyer", "mode": "ask", "ideal": "ornament", "okay": [],
				"name": "Jin", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#37a37a", "skin": "#ecd0b0", "hair": "#14100e", "hat": "beanie", "hatc": "#f2f2f2",
				"request": "I would like a Christmas ornament. Any, but a beautiful one. For my dorm room.",
				"good": "Just right. The dorm will come alive!",
				"ok": "Nice, thank you.",
				"meh": "Fine, that will do.",
			},
			{
				"name": "Mrs. Fernandez", "item": "box_small", "paper": "gold", "ribbon": "red", "bow": "any", "wrap": "free",
				"coat": "#6a3f5a", "skin": "#d9a679", "hair": "#2a1d16", "hat": "beret", "hatc": "#8a2a3a",
				"request": "For my class teacher. Gold paper and a red ribbon, please.",
				"good": "A party in a box. Thank you!",
				"ok": "Good. Thank you.",
				"meh": "Well... it is the thought that counts.",
			},
			{
				"name": "Sasha", "item": "ball", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#37a37a", "skin": "#ecd0b0", "hair": "#c9a24a", "hat": "beanie", "hatc": "#f2f2f2",
				"request": "For a friend, for New Year. Something fun! Wrap it however you like.",
				"good": "That is the spirit! Thank you!",
				"ok": "Not bad, thanks!",
				"meh": "Okay, my friend will appreciate the effort.",
			},
			{
				"kind": "buyer", "mode": "mind", "ideal": "bear", "okay": ["ornament"],
				"name": "Mr. Al-Rashid", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"coat": "#33384a", "skin": "#c9a07a", "hair": "#1a1410", "hat": "none", "hatc": "#8a8fa0",
				"thought": "My colleague pretends he dislikes the holidays. But once he cried over a greeting card. Something warm that he can hug, I think.",
				"request": "",
				"good": "He will pretend not to be moved. He will be moved. Thank you.",
				"ok": "Well, not bad. Thank you.",
				"meh": "Hm. Not quite right, but thank you.",
			},
			{
				"name": "Lucia", "item": "bear", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "free",
				"coat": "#2c3e66", "skin": "#e0b894", "hair": "#2a1d16", "hat": "beret", "hatc": "#e24b4b",
				"request": "I must make it before midnight! I need the prettiest wrap you can manage.",
				"good": "Right on time! Thank you so much!",
				"ok": "Made it. Thank you!",
				"meh": "Fine, the main thing is that I made it. Thanks.",
			},
			{
				"name": "Dona Rosa from upstairs", "item": "box_big", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free", "free": true,
				"coat": "#a85a6a", "skin": "#d9ab86", "hair": "#8a8a96", "hat": "none", "hatc": "#f2c14e",
				"request": "You wrapped gifts for everyone tonight. This one is for you, wrap it any way you like.",
				"good": "Happy New Year!",
				"ok": "Happy New Year!",
				"meh": "Happy New Year!",
			},
		],
	},
]


## Lines for the order ticket on the wrapping table.
static func ticket_lines(c: Dictionary, item_id: String = "") -> Array:
	var lines: Array = []
	if c.get("free", false):
		lines.append("Do as you like")
		return lines
	var p: String = c["paper"]
	if p == "any":
		lines.append("Paper: any")
	else:
		lines.append("Paper: " + str(TAG_NAMES[p]))
	var r: String = c["ribbon"]
	if r == "none":
		lines.append("No ribbon")
	elif r == "any":
		lines.append("Ribbon: any")
	else:
		lines.append("Ribbon: " + str(RIBBON_NAMES[r]))
	var b: String = c["bow"]
	if b == "big":
		lines.append("Bow: big")
	elif b == "small":
		lines.append("Bow: small")
	var iid: String = item_id if item_id != "" else str(c.get("item", ""))
	var kind: String = ITEMS[iid]["kind"]
	var w: String = c["wrap"]
	if kind != "box":
		if w == "box":
			lines.append("In a box")
		elif w == "shape":
			lines.append("By shape, no box")
		else:
			lines.append("Box: your choice")
	return lines
