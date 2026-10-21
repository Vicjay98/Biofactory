extends Node2D


@export var grid: Node2D
@export var construction_manager: ConstructionManager

var membrane_data: BuildingData = preload(
	"res://data/buildings/membrane.tres"
)

var atp_factory_data: BuildingData = preload(
	"res://data/buildings/atp_factory.tres"
)

var building_data: BuildingData

var current_cell: Vector2i = Vector2i.ZERO


func _ready() -> void:
    building_data = atp_factory_data


func _process(_delta: float) -> void:

    var mouse_position := get_global_mouse_position()

    current_cell = grid.world_to_grid(mouse_position)

    queue_redraw()


func _draw() -> void:

    if not grid.is_inside_grid(current_cell):
        return

    var can_build: bool = construction_manager.can_build(
        building_data,
        current_cell
    )

    var building_size: Vector2i = building_data.size

    var cell_size: int = grid.cell_size

    var top_left: Vector2 = grid.grid_to_world(current_cell)

    var preview_size := Vector2(
        building_size.x * cell_size,
        building_size.y * cell_size
    )

    var preview_position := top_left - Vector2(
        cell_size / 2.0,
        cell_size / 2.0
    )

    var preview_color := Color(
        0.2,
        0.8,
        0.2,
        0.35
    )

    if not can_build:
        preview_color = Color(
            0.9,
            0.2,
            0.2,
            0.35
        )

    draw_rect(
        Rect2(
            preview_position,
            preview_size
        ),
        preview_color,
        true
    )

    draw_rect(
        Rect2(
            preview_position,
            preview_size
        ),
        preview_color,
        false,
        2.0
    )


func _unhandled_input(event: InputEvent) -> void:

    if event is InputEventMouseButton:

        if event.button_index == MOUSE_BUTTON_LEFT:
            
            if event.pressed:

                var building := construction_manager.build(
                    building_data,
                    current_cell
                )

                if building != null:
                    print("Bâtiment construit.")
                else:
                    print("Construction impossible.")


func select_building(new_building_data: BuildingData) -> void:

    building_data = new_building_data

    print("Bâtiment sélectionné : ", building_data.display_name)

    queue_redraw()
