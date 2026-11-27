extends SceneTree
func _init() -> void:
	var db := ItemDatabase.new(); db.load_dir()
	var re := RegEx.create_from_string("\\[[^\\]]*\\]")
	for id in [&"knife", &"steel_greatsword", &"salve", &"herb_pouch"]:
		for lang in ["zh", "en"]:
			UiText.lang = lang
			var full := ItemTooltip.describe_full(ItemInstance.create(db.get_def(id)))
			print("WT %s %s：%s" % [id, lang, re.sub(str(full.get("text", full)), "", true).replace("\n", " / ").left(300)])
	quit(0)
