class_name SaveService
extends RefCounted

const CampaignSaveClass = preload("res://game/save/campaign_save.gd")
const OperationSnapshotClass = preload("res://game/save/operation_snapshot.gd")
const SaveStoreClass = preload("res://game/save/save_store.gd")

var store
var content_hash: String = ""

func setup(next_directory: String, next_content_hash: String) -> bool:
	store = SaveStoreClass.new()
	content_hash = next_content_hash
	return not String(content_hash).is_empty() and store.configure(next_directory)

func configure_directory(next_directory: String) -> bool:
	return store != null and store.configure(next_directory)

func save_campaign(campaign_state) -> Dictionary:
	if campaign_state == null or store == null:
		return {"accepted": false, "reason": &"SAVE_NOT_READY"}
	return store.write("campaign.save", "CAMPAIGN", CampaignSaveClass.capture(campaign_state), content_hash, "campaign_%d" % campaign_state.revision)

func load_campaign(campaign_state) -> Dictionary:
	if campaign_state == null or store == null:
		return {"accepted": false, "reason": &"SAVE_NOT_READY"}
	var result: Dictionary = store.read("campaign.save", "CAMPAIGN", content_hash)
	if result.get("accepted", false) and not CampaignSaveClass.restore(campaign_state, result.payload):
		return {"accepted": false, "reason": &"CAMPAIGN_RESTORE_FAILED"}
	return result

func save_operation(controller) -> Dictionary:
	if controller == null or controller.state == null or store == null:
		return {"accepted": false, "reason": &"SAVE_NOT_READY"}
	var payload := OperationSnapshotClass.capture(controller)
	return store.write("operation.save", "OPERATION", payload, content_hash, "operation_%s_%d" % [String(controller.state.operation_id), controller.state.logical_tick])

func load_operation(controller) -> Dictionary:
	if controller == null or store == null:
		return {"accepted": false, "reason": &"SAVE_NOT_READY"}
	var result: Dictionary = store.read("operation.save", "OPERATION", content_hash)
	if result.get("accepted", false) and not OperationSnapshotClass.restore(controller, result.payload):
		return {"accepted": false, "reason": &"OPERATION_RESTORE_FAILED"}
	return result
