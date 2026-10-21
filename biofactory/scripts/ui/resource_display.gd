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
    for resource_id in ["atp", "oxygen", "nutrient"]:
        labels_by_resource_id[resource_id] = _add_label("")
    objective_label = _add_label("")
    _add_label("Survolez la cellule, l'usine ou la membrane.\nClic droit sur la membrane : actions O₂.\nClic droit dans la cellule : construction.")
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
        state_label.text = "CELLULE · " + physiology.get_state_name().to_upper()
        var colors: Array[Color] = [Color(0.4, 0.95, 0.7), Color(1.0, 0.8, 0.4), Color(1.0, 0.45, 0.35), Color(0.8, 0.65, 0.95)]
        state_label.add_theme_color_override("font_color", colors[physiology.state])
        if physiology.stabilized:
            objective_label.text = "✓ Première stabilisation réussie !"
        else:
            objective_label.text = "Objectif : rester stable %.0f s\nStabilité : %.1f / %.0f s" % [physiology.profile.stabilization_seconds, physiology.stable_seconds, physiology.profile.stabilization_seconds]
