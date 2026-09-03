extends Node

var checked := 0
var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Starting full resource verification...")
	_scan_directory("res://")
	if failures.is_empty():
		print("Resource verification passed: %d files loaded." % checked)
		get_tree().quit(0)
		return
	for failure in failures:
		push_error(failure)
	push_error("Resource verification failed: %d of %d files." % [failures.size(), checked])
	get_tree().quit(1)

func _scan_directory(directory: String) -> void:
	for file_name in DirAccess.get_files_at(directory):
		var path := directory.path_join(file_name)
		if ResourceLoader.exists(path):
			_verify_resource(path)
	for child_name in DirAccess.get_directories_at(directory):
		if not child_name.begins_with(".") and child_name != "build" and not child_name.ends_with(".exe"):
			_scan_directory(directory.path_join(child_name))

func _verify_resource(path: String) -> void:
	checked += 1
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		failures.append("Could not load: " + path)
		return
	if resource is Script:
		var script := resource as Script
		if not script.can_instantiate():
			failures.append("Script cannot instantiate (parse/compile error): " + path)
	elif resource is PackedScene:
		var scene := resource as PackedScene
		var instance: Node = scene.instantiate()
		if instance == null:
			failures.append("Scene cannot instantiate: " + path)
		else:
			instance.free()
