extends SceneTree

func _initialize() -> void:
	var recipes := RecipeDef.load_all()
	print(JSON.stringify({"knife_plus_poison": RecipeDef.find(recipes, &"knife", &"poison_vial") != null,
		"knife_brute_plus_poison": RecipeDef.find(recipes, &"knife_brute", &"poison_vial") != null,
		"knife_brute_plus_poison_adjacent": RecipeDef.find(recipes, &"knife_brute", &"poison_vial", true) != null}))
	quit()
