class_name ContentManifest
extends Resource

@export var definitions: Array = []

func all_definitions() -> Array:
	return definitions if definitions != null else []
