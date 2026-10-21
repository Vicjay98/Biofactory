extends Control


@onready var resource_list: VBoxContainer = $Panel/VBox
var objective_label: Label
var _elapsed: float = 0.0


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    $Panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    resource_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
    for child in resource_list.get_children():
        child.queue_free()
    var title := _add_label("MISSIONS")
    title.add_theme_font_size_override("font_size", 21)
    title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.42))
    objective_label = _add_label("")
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.custom_minimum_size.x = 350.0
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
    for cell in get_tree().get_nodes_in_group("bio_cell"):
        if cell.inventory != inventory or cell.physiology == null:
            continue
        var physiology = cell.physiology
        var first_status: String = "✓ Terminée" if physiology.stabilized else "%.1f / %.0f s" % [physiology.stable_seconds, physiology.profile.stabilization_seconds]
        var first_reason: String = physiology.get_stability_wait_reason()
        objective_label.text = "1. Stabiliser l'ATP et l'O₂\n   " + first_status
        if not physiology.stabilized and not first_reason.is_empty():
            objective_label.text += "\n   En attente : " + first_reason
        var second_status: String = "✓ Terminée" if physiology.autonomous else ("%.1f / %.0f s" % [physiology.autonomous_seconds, physiology.profile.autonomy_seconds] if physiology.stabilized else "Verrouillée")
        objective_label.text += "\n\n2. Atteindre l'autonomie sans secours\n   " + second_status
        var second_reason: String = physiology.get_autonomy_wait_reason()
        if physiology.stabilized and not physiology.autonomous and not second_reason.is_empty():
            objective_label.text += "\n   En attente : " + second_reason
