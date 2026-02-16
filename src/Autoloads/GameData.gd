class_name Data
extends Node

# Storage
var karts: Dictionary[String, KartDef] = {}   # { id: KartDef }
var powers: Dictionary[String, PowerDef] = {}  # { id: PowerDef }
var tracks: Dictionary[String, TrackDef] = {}  # { id: TrackDef }
var current_track: TrackDef = null
var num_bots: int = 3
var is_singleplayer: bool = true

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
	def.max_health = data.get("max_health", 100)
	def.max_speed = data.get("max_speed", 500.0)
	def.acceleration = data.get("acceleration", 500.0)
	def.traction = data.get("traction", 10.0)
	def.width_percent = data.get("width_percent", 0.2)
	
	return def

func _parse_power_json(data: Dictionary) -> PowerDef:
	var def = PowerDef.new()
	def.id = data.get("id", "unknown_power")
	def.type = data.get("type", "Projectile")
	def.description = data.get("description", "Description")
	def.cooldown = data.get("cooldown", 1.0)
	
	# Dimensions
	def.length = data.get("length", 20.0)
	def.width = data.get("width", 20.0)
	
	# Projectile Stats
	def.damage = data.get("damage", 0)
	def.speed = data.get("speed", 800.0)
	def.projectile_count = data.get("projectile_count", 1)
	def.can_bounce = data.get("can_bounce", false)
	def.projectile_behavior = data.get("projectile_behavior", "Forward")
	def.turn_speed = data.get("turn_speed", 4.0)
	def.detection_radius = data.get("detection_radius", 400.0)
	
	# "duration" is for Projectile Lifetime or Orbit Duration
	def.duration = data.get("duration", 0.0) 
	
	# Effect/Buff Stats
	def.stat_target = data.get("stat_target", "")
	def.amount = data.get("amount", 0.0)
	
	# "effect_duration" is for how long a Buff/Stat change lasts
	def.effect_duration = data.get("effect_duration", 0.0)
	
	return def

func _parse_track_json(data: Dictionary) -> TrackDef:
	var def = TrackDef.new()
	def.id = data.get("id", "track_01")
	return def

# --- Helper ---
func _load_json_file(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		return json.data
	return null
