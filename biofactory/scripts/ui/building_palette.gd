extends Control


@export var construction_controller: Node
@export var building_catalog: Resource

@onready var factory_button: Button = $Panel/VBox/FactoryButton
@onready var storage_button: Button = $Panel/VBox/StorageButton
@onready var pipe_button: Button = $Panel/VBox/PipeButton
var owning_cell: Node2D


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    factory_button.pressed.connect(select_factory)
    # These prototypes do not yet implement storage or transport.
    storage_button.disabled = true
    storage_button.tooltip_text = "Stockage : disponible dans une prochaine étape."
    pipe_button.disabled = true
    pipe_button.tooltip_text = "Transport : disponible dans une prochaine étape."
    hide()


func open_for_cell(cell: Node2D) -> void:
    owning_cell = cell
    construction_controller = cell.get_node("OrganicConstructionController")
    show()
    _update_affordability()
    # Position in screen coordinates, just beyond the cell's current bounds.
    var bounds := Rect2()
    var transform: Transform2D = cell.boundary.get_global_transform_with_canvas()
    var first: bool = true
    for point in cell.boundary.outline:
        var screen_point: Vector2 = transform * point
        if first:
            bounds = Rect2(screen_point, Vector2.ZERO)
            first = false
        else:
            bounds = bounds.expand(screen_point)
    var panel_size: Vector2 = $Panel.get_combined_minimum_size()
    var viewport_size: Vector2 = get_viewport_rect().size
    var desired := Vector2(bounds.end.x + 20.0, bounds.position.y)
    if desired.x + panel_size.x > viewport_size.x:
        desired.x = bounds.position.x - panel_size.x - 20.0
    position = desired.clamp(Vector2(8, 8), (viewport_size - panel_size - Vector2(8, 8)).max(Vector2(8, 8)))


func _process(_delta: float) -> void:
    if visible and is_instance_valid(owning_cell):
        _update_affordability()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        hide()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
        hide()


func _update_affordability() -> void:
    var data = building_catalog.buildings[0]
    var affordable: bool = true
    var lines := PackedStringArray([data.description, "Coût dans cette cellule :"])
    for resource_id in data.build_cost:
        var amount: float = data.build_cost[resource_id]
        lines.append("%.0f %s" % [amount, ResourceDatabase.get_resource(resource_id).display_name])
        if not owning_cell.inventory.has_amount(resource_id, amount):
            affordable = false
    factory_button.disabled = not affordable
    factory_button.tooltip_text = "\n".join(lines)


func select_factory() -> void:
    if not is_instance_valid(owning_cell):
        return
    _update_affordability()
    if factory_button.disabled:
        return
    construction_controller.building_data = building_catalog.buildings[0]
    construction_controller.construction_active = true
    hide()
