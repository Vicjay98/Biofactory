extends Control


@onready var resource_list: VBoxContainer = $Panel/VBox
var labels_by_resource_id: Dictionary[String, Label] = {}
var state_label: Label
var objective_label: Label
var _elapsed: float = 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    $Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    resource_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in resource_list.get_children():
        child.queue_free()
    state_label = _add_label("CELLULE À STABILISER")
    state_label.add_theme_font_size_override("font_size", 21)
    state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    state_label.custom_minimum_size.x = 350.0
    for resource_id in ["atp", "oxygen", "nutrient"]:
        labels_by_resource_id[resource_id] = _add_label("")
    objective_label = _add_label("")
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.custom_minimum_size.x = 350.0
    _add_label("Survolez la cellule, l'usine ou la membrane.\nClic droit sur la membrane : collecte et échanges.\nClic droit dans la cellule : construction.")
    update_display()


func _add_label(text: String) -> Label:
    var label := Label.new()
    label.text = text
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    resource_list.add_child(label)
    return label


func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= 0.2:
        _elapsed = 0.0
        update_display()


func update_display() -> void:
    var inventory = ResourceManager.main_inventory
    if inventory == null:
        return
    for resource_id in labels_by_resource_id:
        var data = ResourceDatabase.get_resource(resource_id)
        labels_by_resource_id[resource_id].text = "%s : %.1f" % [data.display_name, inventory.get_amount(resource_id)]
    for cell in get_tree().get_nodes_in_group("bio_cell"):
        if cell.inventory != inventory or cell.physiology == null:
            continue
        var physiology = cell.physiology
        state_label.text = "CELLULE · " + physiology.get_status_name().to_upper()
        var colors: Array[Color] = [Color(0.4, 0.95, 0.7), Color(1.0, 0.8, 0.4), Color(1.0, 0.45, 0.35), Color(0.8, 0.65, 0.95)]
        var warning: bool = physiology.state == physiology.State.STABLE and physiology.has_low_nutrients()
        state_label.add_theme_color_override("font_color", colors[physiology.State.WEAK if warning else physiology.state])
        if physiology.autonomous:
            objective_label.text = "✓ Première autonomie réussie !"
        elif physiology.stabilized:
            objective_label.text = "✓ Stabilité ATP/O₂ réussie !\nObjectif 2 : autonomie sans secours\nAutonomie : %.1f / %.0f s" % [physiology.autonomous_seconds, physiology.profile.autonomy_seconds]
            var reason: String = physiology.get_autonomy_wait_reason()
            objective_label.text += "\nEn attente : " + reason if not reason.is_empty() else "\nEn cours · réserves et échanges suffisants."
        else:
            objective_label.text = "Objectif 1 : stabilité ATP/O₂\nStabilité : %.1f / %.0f s" % [physiology.stable_seconds, physiology.profile.stabilization_seconds]
            var reason: String = physiology.get_stability_wait_reason()
            objective_label.text += "\nEn attente : " + reason if not reason.is_empty() else "\nEn cours · maintenez les réserves ATP/O₂."
