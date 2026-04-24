extends RefCounted
class_name Special

const MOVES := [
	{
		"name": "SPEED SHOT",
		"color": Color("#ff3030"),
		"arc_speed": 16.8,
		"speed_multiplier": 1.26,
		"vertical_multiplier": 1.0,
		"curve": 0.0,
	},
	{
		"name": "WOBBLE SHOT",
		"color": Color("#00ff4c"),
		"arc_speed": 15.2,
		"speed_multiplier": 1.08,
		"vertical_multiplier": 1.05,
		"curve": 4.4,
	},
	{
		"name": "PAUSE SPIKE",
		"color": Color("#fcb503"),
		"arc_speed": 18.4,
		"speed_multiplier": 1.22,
		"vertical_multiplier": -0.72,
		"curve": 0.0,
	},
	{
		"name": "TRIPLE DECOY",
		"color": Color("#ff77d9"),
		"arc_speed": 15.8,
		"speed_multiplier": 1.16,
		"vertical_multiplier": 1.12,
		"curve": -3.8,
	},
	{
		"name": "BLOCK SHIELD",
		"color": Color("#8f949c"),
		"arc_speed": 14.7,
		"speed_multiplier": 1.04,
		"vertical_multiplier": 1.48,
		"curve": 0.0,
	},
	{
		"name": "CURVE BLAST",
		"color": Color("#0040ff"),
		"arc_speed": 16.2,
		"speed_multiplier": 1.14,
		"vertical_multiplier": 1.0,
		"curve": 6.2,
	},
	{
		"name": "SPIRAL COASTER",
		"color": Color("#00a693"),
		"arc_speed": 15.4,
		"speed_multiplier": 1.2,
		"vertical_multiplier": 1.34,
		"curve": 2.8,
	},
	{
		"name": "SQUARE BURST",
		"color": Color("#ff00a2"),
		"arc_speed": 17.4,
		"speed_multiplier": 1.32,
		"vertical_multiplier": 0.86,
		"curve": -2.4,
	},
]


static func move(char_id: int) -> Dictionary:
	return MOVES[wrapi(char_id, 0, MOVES.size())]


static func move_name(char_id: int) -> String:
	return str(move(char_id)["name"])


static func ball_color(char_id: int) -> Color:
	return move(char_id)["color"]


static func arc_speed(char_id: int) -> float:
	return float(move(char_id)["arc_speed"])


static func apply_velocity(char_id: int, velocity: Vector3, side_dir: float) -> Vector3:
	var data := move(char_id)
	var result := velocity * float(data["speed_multiplier"])
	result.y *= float(data["vertical_multiplier"])
	result.x += float(data["curve"]) * side_dir
	return result
