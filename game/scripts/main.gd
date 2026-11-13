extends Node
func _ready() -> void:
	Mats.init_base()
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("view"):
		await Mats.build_decals(self)
		var v = load("res://scripts/devview.gd").new(); add_child(v); v.setup(args)
		return
	get_tree().quit()
