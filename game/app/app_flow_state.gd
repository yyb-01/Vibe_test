class_name AppFlowState
extends RefCounted

enum Screen { BOOT, MAIN_MENU, CAMPAIGN, BRIEFING, OPERATION, SETTLEMENT }

var current_screen: Screen = Screen.BOOT

func transition_to(next_screen: Screen) -> bool:
	if current_screen == next_screen:
		return false
	var valid_transition := current_screen == Screen.BOOT and next_screen == Screen.MAIN_MENU
	valid_transition = valid_transition or current_screen == Screen.MAIN_MENU and next_screen == Screen.CAMPAIGN
	valid_transition = valid_transition or current_screen == Screen.CAMPAIGN and next_screen == Screen.BRIEFING
	valid_transition = valid_transition or current_screen == Screen.CAMPAIGN and next_screen == Screen.MAIN_MENU
	valid_transition = valid_transition or current_screen == Screen.BRIEFING and next_screen == Screen.OPERATION
	valid_transition = valid_transition or current_screen == Screen.BRIEFING and next_screen == Screen.CAMPAIGN
	valid_transition = valid_transition or current_screen == Screen.OPERATION and next_screen == Screen.SETTLEMENT
	valid_transition = valid_transition or current_screen == Screen.OPERATION and next_screen == Screen.MAIN_MENU
	valid_transition = valid_transition or current_screen == Screen.SETTLEMENT and next_screen == Screen.CAMPAIGN
	valid_transition = valid_transition or current_screen == Screen.SETTLEMENT and next_screen == Screen.MAIN_MENU
	if not valid_transition:
		return false
	current_screen = next_screen
	return true
