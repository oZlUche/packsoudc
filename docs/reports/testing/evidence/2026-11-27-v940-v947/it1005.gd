extends SceneTree
## 测试 v9.45（PR #1005）无头：食材悬浮窗正文（野葱 / 自然赐福野葱 / 狼心 / 熊肝 / 兽腿），下锅表数、售价


func _init() -> void:
	var db := ItemDatabase.new(); db.load_dir()


	for id in [&"wild_scallion", &"wolf_heart", &"bear_liver", &"beast_haunch", &"long_scallion"]:
		var base := db.get_def(id)
		var blessed := db.get_def(Blessings.variant_id(id, &"nature"))
		for d in [base, blessed]:
			if d == null: continue
			var e := Canteen.entry_of(d)
			var line := "IT1005 %s（%s）：下锅 %s；售价 %d；器官特性 %s" % [Names.of(d), String(d.id), str(e), ItemValue.of(d), str(d.eat_trait)]
			print(line)
			for lang in ["zh", "en"]:
				UiText.lang = lang
				var full := ItemTooltip.describe_full(ItemInstance.create(d))
				print("IT1005 　　%s：%s" % [lang, RegEx.create_from_string("\\[[^\\]]*\\]").sub(str(full.get("text", full)), "", true).replace("\n", " / ").left(500)])
			UiText.lang = "zh"
	print("IT1005 完")
	quit(0)
