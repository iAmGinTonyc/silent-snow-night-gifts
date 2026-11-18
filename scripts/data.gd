extends RefCounted
## Game data: materials, items, shop, nights and customers. No logic here.
## Colors are stored as "#rrggbb" strings and turned into Color with Color.html().
## The game is in English. Customers come from all over the world because the shop travels.

const START_MONEY := 20

## cpp: coins per 100 px of paper pulled from the roll. price: shop price (0 = owned from the start).
## bonus: extra rating for a premium material.
const PAPERS := [
	{"id": "kraft", "name": "Kraft", "tag": "kraft", "base": "#b58a5a", "accent": "#8f6a40", "pattern": "plain", "cpp": 0.6, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "red_plain", "name": "Red", "tag": "red", "base": "#b94a3e", "accent": "#e08a7e", "pattern": "plain", "cpp": 0.8, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "green_plain", "name": "Green", "tag": "green", "base": "#5f9a57", "accent": "#95c78a", "pattern": "plain", "cpp": 0.8, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "blue_plain", "name": "Blue", "tag": "blue", "base": "#5a86b8", "accent": "#93b6de", "pattern": "plain", "cpp": 0.8, "price": 0, "premium": false, "bonus": 0.0},
	{"id": "red_stars", "name": "Red with stars", "tag": "red", "base": "#c23b3b", "accent": "#f6e7c8", "pattern": "stars", "cpp": 1.0, "price": 20, "premium": false, "bonus": 0.0},
	{"id": "blue_stripes", "name": "Blue stripes", "tag": "blue", "base": "#2a4a8a", "accent": "#a9c4f0", "pattern": "stripes", "cpp": 1.0, "price": 25, "premium": false, "bonus": 0.0},
	{"id": "gold", "name": "Gold", "tag": "gold", "base": "#d6a93f", "accent": "#fff1b8", "pattern": "lines", "cpp": 1.0, "price": 30, "premium": false, "bonus": 0.0},
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
	"ball": {"name": "Football", "kind": "ball", "w": 150, "h": 150, "price": 14, "color": "#f4f1ea", "tail": [75, 0, 1, 0, 40], "sell": 24, "stock": 10, "tier": "cheap"},
	"bear": {"name": "Teddy bear", "kind": "bear", "w": 150, "h": 180, "price": 18, "color": "#a9703f", "tail": [0, -88, 0, -1, 44], "sell": 30, "stock": 12, "tier": "cheap"},
	"ornament": {"name": "Christmas ornament", "kind": "ornament", "w": 110, "h": 124, "price": 10, "color": "#c93a4a", "tail": [0, -62, 0, -1, 34], "sell": 18, "stock": 6, "tier": "cheap"},
	"train": {"name": "Toy train", "kind": "train", "w": 232, "h": 66, "price": 16, "color": "#c93a4a", "tail": [118, 0, 1, 0, 40], "sell": 34, "stock": 14, "tier": "cheap"},
	"ball_mid": {"name": "Leather ball", "kind": "ball", "w": 150, "h": 150, "price": 14, "color": "#8a4a2c", "tail": [75, 0, 1, 0, 40], "sell": 52, "stock": 22, "tier": "mid"},
	"bear_mid": {"name": "Plush bear with scarf", "kind": "bear", "w": 150, "h": 180, "price": 18, "color": "#c9955a", "tail": [0, -88, 0, -1, 44], "sell": 64, "stock": 26, "tier": "mid"},
	"ornament_mid": {"name": "Painted ornament", "kind": "ornament", "w": 110, "h": 124, "price": 10, "color": "#bfb3a4", "tail": [0, -62, 0, -1, 34], "sell": 40, "stock": 14, "tier": "mid"},
	"train_mid": {"name": "Wooden train set", "kind": "train", "w": 232, "h": 66, "price": 16, "color": "#4a8a4a", "tail": [118, 0, 1, 0, 40], "sell": 72, "stock": 30, "tier": "mid"},
}

## The minimal set of gifts we keep in stock.
const STOCK := ["bear", "ornament", "ball", "train"]
## Mid-price versions of the same toys; they appear in the supplier catalog after the first order.
const STOCK_MID := ["bear_mid", "ornament_mid", "ball_mid", "train_mid"]

## On the first night the plaque shows how many days are left until New Year (the demo is the first three of 12 nights).
const DAYS_TO_NEW_YEAR := 12

## What a customer says when we offer a gift. Everyone comes empty-handed: we read their mind
## and offer one gift from the shelf. A miss means the customer chooses for themselves.
const BUYER_LINES := {
	"perfect": "You read my mind! This is exactly it.",
	"miss": "Hmm, not quite what I pictured. Let me choose myself.",
	"choose": "This one, please.",
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
		"date": "20 December",
		"sky": "#1b2347",
		"clock": [1290, 1500],
		"place": "Kyoto, a night platform by a closed ticket office",
		"patience": 170.0,
		"customers": [
			{
				"name": "Mrs. Tanaka", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "ornament",
				"coat": "#7a4b6e", "skin": "#e8c8a4", "hair": "#d8d8de", "hat": "bun", "hatc": "#e8d9a8",
				"thought": "My granddaughter is five and adores anything golden. She can stare at the lights on a tree for an hour. I want to give her something that shines.",
				"pack": "Something festive, please. She adores anything shiny.",
				"good": "How beautiful! Thank you so much.",
				"ok": "Lovely. She will be happy.",
				"meh": "Well... it is the thought that counts.",
			},
			{
				"name": "Mateo", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "train",
				"coat": "#2f6f8f", "skin": "#d3a07a", "hair": "#2a1d16", "hat": "cap", "hatc": "#e0a030",
				"thought": "My little nephew waves at every train that passes his window. I am running for the night train myself, and I want to bring him something on rails.",
				"pack": "Something simple, just make it pretty. The night train is leaving!",
				"good": "Wow, fast and pretty! Gracias!",
				"ok": "Good enough, gracias! I am late!",
				"meh": "Fine, no time to complain.",
			},
			{
				"name": "Ingrid", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "ornament",
				"coat": "#5a6f8f", "skin": "#f3dccb", "hair": "#d8b46a", "hat": "beanie", "hatc": "#c0504d",
				"thought": "My friend just moved into an empty apartment. It is cold and smells of paint. I want it to feel cozy and festive, even with one shiny little thing.",
				"pack": "",
				"good": "Thank you! This is what the place was missing.",
				"ok": "Nice. Thank you.",
				"meh": "Well... all right. Thanks.",
			},
			{
				"name": "Leo", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "free",
				"ask_free": "I counted my coins three times... it is not enough. Could you give it to me for free? It is for my mom.",
				"ideal": "ball",
				"coat": "#c94f4f", "skin": "#c68b62", "hair": "#2a1d16", "hat": "beanie", "hatc": "#3a7bd5",
				"thought": "It is for my mom. She says she was the best goalkeeper on our street when she was young. I have only a few coins, but I want her to feel it again.",
				"pack": "The prettiest wrap you have! And a big bow!",
				"good": "Mom will love it! Thank you so much!",
				"ok": "Pretty. Thanks!",
				"meh": "The bow could have been bigger... but thanks.",
			},
			{
				"name": "Pavel", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "bear",
				"coat": "#2f6f8f", "skin": "#ecd0b0", "hair": "#6a4a2a", "hat": "cap", "hatc": "#e0a030",
				"thought": "My daughter is three and sleeps badly. She hugs anything soft and warm. I am late and it is urgent!",
				"pack": "",
				"good": "She will be thrilled! Thank you!",
				"ok": "Great, thanks!",
				"meh": "Fine, no time to argue.",
			},
			{
				"name": "Mr. Okafor", "paper": "blue", "ribbon": "none", "bow": "any", "wrap": "free",
				"ideal": "train",
				"coat": "#33384a", "skin": "#7a4f35", "hair": "#16110e", "hat": "none", "hatc": "#8a8fa0",
				"thought": "My nephew is a serious boy. Every weekend he builds tracks across the living room and nobody may step on them.",
				"pack": "Blue paper, and no ribbons. He cannot stand them.",
				"good": "Flawless. Thank you.",
				"ok": "Acceptable. Thank you.",
				"meh": "Hm. Not quite right, but thank you.",
			},
		],
	},
	{
		"date": "21 December",
		"sky": "#141a3c",
		"clock": [1290, 1500],
		"place": "a lonely gas station on a Patagonian highway",
		"patience": 150.0,
		"customers": [
			{
				"name": "Auntie Meena", "paper": "red", "ribbon": "green", "bow": "any", "wrap": "free",
				"ideal": "bear",
				"coat": "#2f7a5a", "skin": "#a8754f", "hair": "#1c1410", "hat": "beanie", "hatc": "#f2c14e",
				"thought": "My nephew and I shared one worn-out teddy bear when we were kids. He still talks about it. I want him to hold something like that again.",
				"pack": "Red paper and a green ribbon, like when we were kids.",
				"good": "Exactly like back then! Thank you!",
				"ok": "Sweet. Thank you.",
				"meh": "Oh... well, he will understand.",
			},
			{
				"name": "Dmitri", "paper": "any", "ribbon": "none", "bow": "any", "wrap": "shape",
				"ideal": "ornament",
				"coat": "#4a4f5e", "skin": "#e7c9aa", "hair": "#3a2a20", "hat": "ushanka", "hatc": "#6b5a4a",
				"thought": "A colleague of mine pretends he hates the holidays and has never decorated his flat. I want his lonely little tree to finally sparkle.",
				"pack": "No ribbons, please, and no box. I want it to look like what it is.",
				"good": "Exactly right. My colleague will appreciate it.",
				"ok": "Fine, thanks.",
				"meh": "The box or the bow is too much, but all right.",
			},
			{
				"name": "Kwame", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "ball",
				"coat": "#4a4f5e", "skin": "#6e4630", "hair": "#14100e", "hat": "cap", "hatc": "#2e2e2e",
				"thought": "My son came home covered in mud again. He plays until dark and shouts Goal! I want him to have something to kick.",
				"pack": "",
				"good": "That is a great kick! Thank you.",
				"ok": "It will do, thanks.",
				"meh": "Not quite what I imagined, but thanks.",
			},
			{
				"name": "Anh", "paper": "kraft", "ribbon": "any", "bow": "small", "wrap": "box",
				"ideal": "train",
				"coat": "#9a5fb0", "skin": "#e2bf98", "hair": "#14100e", "hat": "beanie", "hatc": "#e86a8a",
				"thought": "My friend likes simple things and collects tiny miniatures from every trip. Her desk is tidy and she loves little machines.",
				"pack": "Kraft paper, she likes simple things, and in a box please. Only a tiny bow.",
				"good": "Perfect! She will love it.",
				"ok": "Sweet gift, thanks!",
				"meh": "I pictured it differently. But thanks!",
			},
			{
				"name": "Father Christmas (sort of)", "paper": "red", "ribbon": "red", "bow": "big", "wrap": "shape",
				"ideal": "bear",
				"coat": "#c52b2b", "skin": "#e8c4a0", "hair": "#f4f4f4", "hat": "santa", "hatc": "#c52b2b",
				"thought": "Ho ho ho... every year my grandchildren expect something soft and huggable from me. I must not disappoint them.",
				"pack": "All red, no box, and a big bow so they can see it from afar!",
				"good": "Ho ho! Pure magic!",
				"ok": "Ho ho, not bad!",
				"meh": "Oh ho ho... well, the kids will forgive.",
			},
			{
				"name": "Granny Zeynep", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ask_free": "Oh dear, my pension is late this month. Could you let me have it for free, for little Timur?",
				"ideal": "train",
				"coat": "#7a4b6e", "skin": "#d7b08a", "hair": "#cfcfd8", "hat": "hijab", "hatc": "#4a7f8a",
				"thought": "My grandson Timur is five. Anything that hums and runs on rails is a miracle to him. He stands at the window for hours waiting for the train.",
				"pack": "",
				"good": "Choo choo! He will be so happy, thank you.",
				"ok": "Good, thank you.",
				"meh": "Well... it is the attention that matters.",
			},
			{
				"name": "Aaliyah", "paper": "blue", "ribbon": "gold", "bow": "any", "wrap": "box",
				"ideal": "ball",
				"coat": "#3a8fa8", "skin": "#c9a07a", "hair": "#101010", "hat": "hijab", "hatc": "#d9c36a",
				"thought": "My father still talks about a football match he watched in 1998. He likes the classics and a good old story.",
				"pack": "In a box, blue paper and a gold ribbon, please.",
				"good": "He will be delighted! Thank you!",
				"ok": "Nice. Thank you!",
				"meh": "Well... he is easy to please.",
			},
		],
	},
	{
		"date": "22 December",
		"sky": "#0c1030",
		"clock": [1260, 1439],
		"place": "a stairwell in a Lisbon apartment block",
		"patience": 130.0,
		"customers": [
			{
				"name": "The Murphy family", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "box",
				"ideal": "ball",
				"coat": "#d28a2f", "skin": "#f1d5c0", "hair": "#b8532a", "hat": "cap", "hatc": "#1f6f5a",
				"thought": "Our son talks about nothing but football. He kicks everything in the house, including the cat. We want to surprise him.",
				"pack": "Do not let him guess what is inside, so a box please! And a big bow.",
				"good": "He will never guess! Thank you!",
				"ok": "Good, thanks!",
				"meh": "He will probably guess. But thanks.",
			},
			{
				"name": "Jin", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ask_free": "Sorry... I spent everything on the ticket home. Could I have it for free? I will pay you back someday.",
				"ideal": "ornament",
				"coat": "#37a37a", "skin": "#ecd0b0", "hair": "#14100e", "hat": "beanie", "hatc": "#f2f2f2",
				"thought": "My dorm room is gray and bare. I bought a tiny tree but it has nothing to hang on it. Anything beautiful will do.",
				"pack": "",
				"good": "Just right. The dorm will come alive!",
				"ok": "Nice, thank you.",
				"meh": "Fine, that will do.",
			},
			{
				"name": "Mrs. Fernandez", "paper": "gold", "ribbon": "red", "bow": "any", "wrap": "free",
				"ideal": "ornament",
				"coat": "#6a3f5a", "skin": "#d9a679", "hair": "#2a1d16", "hat": "beret", "hatc": "#8a2a3a",
				"thought": "My class teacher has decorated the school tree for thirty years and nobody ever gave her anything for it. I want it to be special.",
				"pack": "Gold paper and a red ribbon, please.",
				"good": "A party in a box. Thank you!",
				"ok": "Good. Thank you.",
				"meh": "Well... it is the thought that counts.",
			},
			{
				"name": "Sasha", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "ball",
				"coat": "#37a37a", "skin": "#ecd0b0", "hair": "#c9a24a", "hat": "beanie", "hatc": "#f2f2f2",
				"thought": "My friend can never sit still. Come New Year he will want to run outside and play in the snow, even in the cold.",
				"pack": "Wrap it however you like.",
				"good": "That is the spirit! Thank you!",
				"ok": "Not bad, thanks!",
				"meh": "Okay, my friend will appreciate the effort.",
			},
			{
				"name": "Mr. Al-Rashid", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "bear",
				"coat": "#33384a", "skin": "#c9a07a", "hair": "#1a1410", "hat": "none", "hatc": "#8a8fa0",
				"thought": "My colleague pretends he dislikes the holidays. But once he cried over a greeting card. Something warm that he can hug, I think.",
				"pack": "",
				"good": "He will pretend not to be moved. He will be moved. Thank you.",
				"ok": "Well, not bad. Thank you.",
				"meh": "Hm. Not quite right, but thank you.",
			},
			{
				"name": "Lucia", "paper": "any", "ribbon": "any", "bow": "big", "wrap": "free",
				"ideal": "train",
				"coat": "#2c3e66", "skin": "#e0b894", "hair": "#2a1d16", "hat": "beret", "hatc": "#e24b4b",
				"thought": "My little brother will wait up for midnight to open his gift. He is crazy about trains. I must make it home before midnight!",
				"pack": "I need the prettiest wrap you can manage, and a big bow!",
				"good": "Right on time! Thank you so much!",
				"ok": "Made it. Thank you!",
				"meh": "Fine, the main thing is that I made it. Thanks.",
			},
			{
				"name": "Dona Rosa from upstairs", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free", "free": true,
				"ideal": "bear",
				"coat": "#a85a6a", "skin": "#d9ab86", "hair": "#8a8a96", "hat": "none", "hatc": "#f2c14e",
				"thought": "That little shop wrapped gifts for everyone tonight, but nobody gave a gift to the one who wrapped them. I want to.",
				"pack": "This one is for you, wrap it any way you like.",
				"good": "Happy holidays, dear!",
				"ok": "Happy holidays, dear!",
				"meh": "Happy holidays, dear!",
			},
			{
				"name": "Santa", "scene": "santa", "paper": "any", "ribbon": "any", "bow": "any", "wrap": "free",
				"ideal": "box_small",
				"coat": "#c93a3a", "skin": "#f0d0b0", "hair": "#f4f4f4", "hat": "none", "hatc": "#c93a3a",
				"thought": "", "pack": "Wrap me one gift before I go. Empty. I do not know yet what goes inside.",
				"good": "Neat. Very neat.", "ok": "Neat enough.", "meh": "Hm. We will practice.",
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
