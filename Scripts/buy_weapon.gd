extends Button

func buy(): get_tree().get_first_node_in_group("Player").buy_weapon(name)
