extends Node2D


var geometry = null

var minimum_area_m2: float = 0.0

var valid_size: bool = false


func setup(
    cell_geometry,
    minimum_area: float
) -> void:

    geometry = cell_geometry

    minimum_area_m2 = minimum_area

    valid_size = geometry.is_large_enough(
        minimum_area_m2
    )

    z_index = -5

    queue_redraw()


func _draw() -> void:

    if geometry == null:
        return

    if geometry.outline.size() < 3:
        return

    var fill_color := Color(
        0.15,
        0.55,
        0.45,
        0.18
    )

    var outline_color := Color(
        0.3,
        0.8,
        0.65,
        0.45
    )

    if not valid_size:

        fill_color = Color(
            0.75,
            0.15,
            0.15,
            0.20
        )

        outline_color = Color(
            0.95,
            0.25,
            0.25,
            0.55
        )

    draw_colored_polygon(
        geometry.outline,
        fill_color
    )

    var closed_outline := PackedVector2Array(
        geometry.outline
    )

    closed_outline.append(
        geometry.outline[0]
    )

    draw_polyline(
        closed_outline,
        outline_color,
        2.0,
        true
    )
