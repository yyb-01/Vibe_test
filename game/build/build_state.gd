class_name BuildState
extends RefCounted

var grid
var build_sites: Dictionary = {}
var structures: Dictionary = {}
var dirty_cells: Array = []
var revision: int = 0
