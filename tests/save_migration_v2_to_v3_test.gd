extends SceneTree

# res://tests/save_migration_v2_to_v3_test.gd
# Conformance test for Save Schema v2 -> v3 migration, SHA-256 integrity verification, and atomic disk writes.

const SaveEnvelopeV3Class = preload("res://scripts/infrastructure/persistence/save_envelope_v3.gd")
const SaveMigrationServiceClass = preload("res://scripts/infrastructure/persistence/save_migration_service.gd")
const LocalSaveStoreClass = preload("res://scripts/infrastructure/persistence/local_save_store.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("========================================")
	print(" RUNNING SAVE MIGRATION V2 -> V3 TEST SUITE")
	print("========================================")

	test_schema_v2_to_v3_migration()
	test_sha256_integrity_verification()
	test_local_store_atomic_save_and_load()

	print("========================================")
	print(" TEST RESULTS: %d Passed, %d Failed (Total: %d)" % [passed_tests, failed_tests, total_tests])
	print("========================================")

	quit(1 if failed_tests > 0 else 0)

func assert_true(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func assert_equal(actual, expected, test_name: String) -> void:
	total_tests += 1
	if actual == expected:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s: expected %s, got %s" % [test_name, str(expected), str(actual)])

func test_schema_v2_to_v3_migration() -> void:
	print("\n--- Test: Schema v2 Dictionary to SaveEnvelopeV3 Migration ---")
	var v2_data: Dictionary = {
		"version": 2,
		"day": 4,
		"state": "HUB",
		"meta": {
			"legacy_scrap": 35,
			"survivor_xp": 120,
			"survivor_level": 2,
			"unlocked_blueprints": ["barricade_wood", "barricade_metal"]
		},
		"storage": {
			"wood": 60,
			"scrap_metal": 18
		},
		"structures": [
			{
				"id": "barricade_wood",
				"cell": [1, 2],
				"rot": 0,
				"hp": 90.0
			}
		],
		"day_start_snapshot": {
			"day": 4,
			"legacy_scrap": 35
		}
	}

	var env: SaveEnvelopeV3Class = SaveMigrationServiceClass.migrate_to_v3(v2_data)
	assert_true(env != null, "Migration produces a non-null SaveEnvelopeV3")
	assert_equal(env.to_dict().get("schema_version", 0), 3, "Migrated envelope schema version is 3")

	var session = env.payload.get("session", {})
	assert_equal(int(session.get("day", 0)), 4, "Migrated day matches v2 day")
	assert_equal(str(session.get("phase", "")), "HUB", "Migrated phase matches v2 state")

	var storage = env.payload.get("shared_storage", {})
	assert_equal(int(storage.get("wood", 0)), 60, "Migrated storage matches v2 storage")

	var meta = env.payload.get("meta_progress", {})
	assert_equal(int(meta.get("legacy_scrap", 0)), 35, "Migrated legacy scrap matches v2 meta")
	assert_true(env.verify_integrity(), "Generated envelope passes SHA-256 integrity verification")

func test_sha256_integrity_verification() -> void:
	print("\n--- Test: SHA-256 Checksum Calculation & Tamper Detection ---")
	var env := SaveEnvelopeV3Class.new()
	env.payload = {"test_key": "valid_value", "number": 123}
	env.integrity["digest"] = env.compute_sha256()

	assert_true(env.verify_integrity(), "Untampered envelope passes verification")

	# Tamper with payload
	env.payload["test_key"] = "tampered_value"
	assert_true(not env.verify_integrity(), "Tampered envelope fails verification")

func test_local_store_atomic_save_and_load() -> void:
	print("\n--- Test: Local Save Store Atomic Write and Read-Back ---")
	var store := LocalSaveStoreClass.new()
	store.delete_all_saves()

	var env := SaveEnvelopeV3Class.new()
	env.payload = {
		"session": {"day": 2, "phase": "HUB"},
		"shared_storage": {"wood": 80}
	}

	var written := store.write_save(env)
	assert_true(written, "Save file written to disk")
	assert_true(store.has_save(), "Store reports save exists")

	var loaded: SaveEnvelopeV3Class = store.read_save()
	assert_true(loaded != null, "Save file successfully loaded from disk")
	assert_true(loaded.verify_integrity(), "Loaded save passes integrity verification")
	var loaded_storage = loaded.payload.get("shared_storage", {})
	assert_equal(int(loaded_storage.get("wood", 0)), 80, "Loaded storage content matches")

	store.delete_all_saves()
