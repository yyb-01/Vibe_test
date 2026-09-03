extends SceneTree

# res://tools/asset_pipeline/validate_assets.gd
# Asset validation tool per Section G.2, G.5 and H.4 of game_system_architecture.md.
# Uses only Godot's built-in Image loader.

var total_assets: int = 0
var passed_assets: int = 0
var failed_assets: int = 0

func _init() -> void:
	print("========================================")
	print(" RUNNING ASSET VALIDATION PIPELINE")
	print("========================================")
	
	var scan_dirs: Array[String] = [
		"res://assets/art/placeholders",
		"res://assets/art/tiles",
		"res://assets/art/characters",
		"res://assets/art/structures",
		"res://assets/art/props",
		"res://assets/art/items"
	]
	
	for dir_path in scan_dirs:
		_scan_directory(dir_path)
		
	print("========================================")
	print(" ASSET VALIDATION SUMMARY: %d Passed, %d Failed (Total: %d)" % [passed_assets, failed_assets, total_assets])
	print("========================================")
	
	if failed_assets > 0:
		print("VALIDATION FAILED: Issues found in one or more assets.")
		quit(1)
	else:
		print("VALIDATION SUCCESS: All assets adhere to technical specification.")
		quit(0)

func _scan_directory(dir_path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(dir_path)
	if not DirAccess.dir_exists_absolute(global_path):
		return
		
	var dir := DirAccess.open(global_path)
	if dir == null:
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory(dir_path + "/" + file_name)
		elif file_name.ends_with(".png"):
			_validate_asset(dir_path + "/" + file_name, file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

func _validate_asset(res_path: String, file_name: String) -> void:
	total_assets += 1
	var global_path: String = ProjectSettings.globalize_path(res_path)
	var image := Image.load_from_file(global_path)
	
	if image == null:
		_record_fail(res_path, "Could not load image file via Image.load_from_file")
		return
		
	var w: int = image.get_width()
	var h: int = image.get_height()
	
	# Rule 1: Real RGBA Alpha channel check
	var has_alpha: bool = false
	var has_transparent_pixels: bool = false
	var has_opaque_pixels: bool = false
	
	for y in range(0, h, maxi(1, h / 16)):
		for x in range(0, w, maxi(1, w / 16)):
			var a: float = image.get_pixel(x, y).a
			if a < 0.99:
				has_transparent_pixels = true
			if a > 0.01:
				has_opaque_pixels = true
				
	if not has_transparent_pixels:
		_record_fail(res_path, "Image appears completely opaque (no transparent background/real alpha)")
		return
		
	# Rule 2: Dimension & Pivot validation per Category
	if "ground" in file_name or "tile" in res_path:
		# Ground tiles: exactly 128x64
		if w != 128 or h != 64:
			_record_fail(res_path, "Ground tile dimensions must be exactly 128x64 (got %dx%d)" % [w, h])
			return
		# Check outer corners are transparent
		if image.get_pixel(0, 0).a > 0.05 or image.get_pixel(127, 0).a > 0.05 or \
		   image.get_pixel(0, 63).a > 0.05 or image.get_pixel(127, 63).a > 0.05:
			_record_fail(res_path, "Isometric tile corners must be transparent outside diamond boundary")
			return
			
	elif "player" in file_name or "character" in res_path or "zombie" in file_name:
		# Character sprites: 128x128 (standard) or 192x192 (brute)
		if not ((w == 128 and h == 128) or (w == 192 and h == 192)):
			_record_fail(res_path, "Character sprite dimensions must be 128x128 or 192x192 (got %dx%d)" % [w, h])
			return
		# Check bottom-center foot contact area has non-zero presence
		var contact_x: int = w / 2
		var tolerance: int = 16 if w <= 128 else 72
		var found_contact: bool = false
		for y in range(h - 12, h):
			for dx in range(-tolerance, tolerance + 1):
				var px: int = clampi(contact_x + dx, 0, w - 1)
				if image.get_pixel(px, y).a > 0.1:
					found_contact = true
					break
			if found_contact:
				break
		if not found_contact:
			_record_fail(res_path, "Character foot contact point missing near bottom-center (%d, %d)" % [contact_x, h])
			return
			
	elif "icon" in file_name or "items" in res_path:
		if w != 64 or h != 64:
			_record_fail(res_path, "UI icon dimensions must be exactly 64x64 (got %dx%d)" % [w, h])
			return
			
	elif "structure" in res_path or "structure" in file_name or "barricade" in file_name or "turret" in file_name or "core" in file_name:
		if "core" in file_name:
			if w != 256 or h != 320:
				_record_fail(res_path, "Base core dimensions must be exactly 256x320 (got %dx%d)" % [w, h])
				return
		else:
			if w != 128 or h != 192:
				_record_fail(res_path, "1x1 structure dimensions must be exactly 128x192 (got %dx%d)" % [w, h])
				return

	elif "prop" in res_path or "props" in res_path or "resource_node" in file_name:
		if "car" in file_name:
			if w != 256 or h != 192:
				_record_fail(res_path, "Car prop dimensions must be 256x192 (got %dx%d)" % [w, h])
				return
		else:
			if w != 128 or h != 192:
				_record_fail(res_path, "Standard prop dimensions must be 128x192 (got %dx%d)" % [w, h])
				return

	_record_pass(res_path, "%dx%d, RGBA OK" % [w, h])

func _record_pass(path: String, detail: String) -> void:
	passed_assets += 1
	print("  [PASS] %s (%s)" % [path, detail])

func _record_fail(path: String, reason: String) -> void:
	failed_assets += 1
	printerr("  [FAIL] %s: %s" % [path, reason])
