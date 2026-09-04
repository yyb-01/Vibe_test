class_name MainMenu
extends Control

signal campaign_requested

func _ready() -> void:
	$StartOperation.pressed.connect(_on_start_operation_pressed)

func configure(catalog: ContentCatalog) -> void:
	$Status.text = "Content ready · %d definitions · catalog %s" % [catalog.definition_count(), catalog.catalog_hash]

func _on_start_operation_pressed() -> void:
	campaign_requested.emit()
