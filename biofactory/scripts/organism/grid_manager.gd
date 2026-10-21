extends Node2D


@export var cell_size: int = 32
@export var grid_width: int = 50
@export var grid_height: int = 30


var occupied_cells: Dictionary = {}


func _ready() -> void:
    queue_redraw()


func _draw() -> void:

    var offset := get_grid_offset()

    for x in range(grid_width):
        for y in range(grid_height):

            var cell_position := offset + Vector2(
                x * cell_size,
                y * cell_size
            )

            draw_rect(
                Rect2(
                    cell_position,
                    Vector2(cell_size, cell_size)
                ),
                Color(0.15, 0.15, 0.15),
                false,
                1.0
            )


func get_grid_offset() -> Vector2:

    return Vector2(
        -grid_width * cell_size / 2.0,
        -grid_height * cell_size / 2.0
    )


func grid_to_world(cell: Vector2i) -> Vector2:

    var offset := get_grid_offset()

    return offset + Vector2(
        cell.x * cell_size + cell_size / 2.0,
        cell.y * cell_size + cell_size / 2.0
    )


func world_to_grid(world_position: Vector2) -> Vector2i:

    var offset := get_grid_offset()

    var local_position := world_position - offset

    return Vector2i(
        floor(local_position.x / cell_size),
        floor(local_position.y / cell_size)
    )


func is_inside_grid(cell: Vector2i) -> bool:

    return (
        cell.x >= 0
        and cell.x < grid_width
        and cell.y >= 0
        and cell.y < grid_height
    )


func is_cell_free(cell: Vector2i) -> bool:

    return not occupied_cells.has(cell)


func occupy_cell(cell: Vector2i, building: Building) -> void:

    occupied_cells[cell] = building


func free_cell(cell: Vector2i) -> void:

    occupied_cells.erase(cell)
