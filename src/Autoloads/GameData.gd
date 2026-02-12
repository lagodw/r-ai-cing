class_name Data
extends Node

# Storage
var karts: Dictionary[String, KartDef] = {}   # { id: KartDef }
var powers: Dictionary[String, PowerDef] = {}  # { id: PowerDef }
var tracks: Dictionary[String, TrackDef] = {}  # { id: TrackDef }
var current_track: TrackDef = null

var selected_kart_id: String = ""
var selected_powers: Array[PowerDef] = []

func _ready():
	load_all_data()

func load_all_data():
	karts.clear()
	powers.clear()
	tracks.clear()
	
	# Scan folders for BOTH .json and .tres files
	_scan_folder("res://data/karts/", karts, _parse_kart_json)
	_scan_folder("res://data/powers/", powers, _parse_power_json)
	_scan_folder("res://data/tracks/", tracks, _parse_track_json)
	
	print("Loaded: %d Karts, %d Powers, %d Tracks" % [karts.size(), powers.size(), tracks.size()])
	
	# Set a default track (e.g. the first one found)
	if not tracks.is_empty():
		current_track = tracks.values()[0]

# --- Core Scanner Logic ---
func _scan_folder(path: String, target_dict: Dictionary, json_parser_func: Callable):
	var dir = DirAccess.open(path)
	if not dir:
		print("Warning: Folder not found ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# If it is a directory, skip it immediately
		if dir.current_is_dir():
			file_name = dir.get_next()
			continue
		
		# In exports, resources are often renamed to .remap. 
		# We strip this so we can check the original extension and load it correctly.
		var check_name = file_name
		if check_name.ends_with(".remap"):
			check_name = check_name.trim_suffix(".remap")
			
		# Ignore hidden files (now checking the stripped name)
		if not check_name.begins_with("."):
			var full_path = path.path_join(check_name)
			
			# OPTION A: Handle JSON Files
			if check_name.ends_with(".json"):
				var data = _load_json_file(full_path)
				if data:
					if data is Array:
						for entry in data:
							var res = json_parser_func.call(entry)
							if res and "id" in res: target_dict[res.id] = res
					elif data is Dictionary:
						var res = json_parser_func.call(data)
						if res and "id" in res: target_dict[res.id] = res
			
			# OPTION B: Handle Godot Resources (.tres, .res)
			elif check_name.ends_with(".tres") or check_name.ends_with(".res"):
				# Godot's load() expects the original path (e.g. .tres), 
				# even if the actual file on disk is .remap
				var res = load(full_path)
				if res and "id" in res:
					target_dict[res.id] = res
					
		file_name = dir.get_next()

# --- JSON Parsers (Factories) ---
# These convert raw Dictionaries into Resource Objects

func _parse_kart_json(data: Dictionary) -> KartDef:
	var def = KartDef.new()
	def.id = data.get("id", "unknown_kart")
	def.name = data.get("name", "Unnamed")
	def.max_health = data.get("max_health", 100)
	def.max_speed = data.get("max_speed", 500)
	def.acceleration = data.get("acceleration", 800)
	def.turn_speed = data.get("turn_speed", 3.5)
	
	# Sprite path inference
	var sprite_name = data.get("sprite_file", def.id + ".png")
	def.sprite_path = "res://assets/sprites/" + sprite_name
	
	return def

func _parse_power_json(data: Dictionary) -> PowerDef:
	var def = PowerDef.new()
	def.id = data.get("id", "unknown_power")
	def.type = data.get("type", "projectile")
	def.cooldown = data.get("cooldown", 1.0)
	def.damage = data.get("damage", 0)
	def.speed = data.get("speed", 0.0)
	def.projectile_behavior = data.get("projectile_behavior", "Forward")
	def.turn_speed = data.get("turn_speed", 4.0)
	def.detection_radius = data.get("detection_radius", 400.0)
	def.stat_target = data.get("stat_target", "")
	def.amount = data.get("amount", 0.0)
	def.duration = data.get("duration", 0.0)
	
	var sprite_name = data.get("sprite_file", "power_default.png")
	def.sprite_path = "res://assets/sprites/" + sprite_name
	
	return def

func _parse_track_json(data: Dictionary) -> TrackDef:
	var def = TrackDef.new()
	def.id = data.get("id", "track_01") # Add ID to track JSON
	def.background_path = "res://assets/backgrounds/" + data.get("background_image", "default.png")
	
	# Parse helpers
	var vec = func(d): return Vector2(d.get("x",0), d.get("y",0))
	
	if data.has("start_position"):
		def.start_position = vec.call(data["start_position"])
	
	for p in data.get("waypoints", []):
		def.waypoints.append(vec.call(p))
		
	for wall_poly in data.get("collision_walls", []):
		var poly = PackedVector2Array()
		for point in wall_poly:
			poly.append(vec.call(point))
		def.walls.append(poly)
		
	return def

# --- Helper ---
func _load_json_file(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.data
	return null
