extends Node2D


var start_junction = null
var end_junction = null


var membrane_type_id: String = "basic_membrane"

var adjacent_cell_a = null
var adjacent_cell_b = null


var membrane_width: float = 5.0

# Courbure relative à la longueur de la section.
# 0.0 = ligne droite.
# 0.12 = légère courbure organique.
var curve_offset_ratio: float = 0.12

var curve_side: float = 1.0


func setup(
    start_point,
    end_point
) -> void:

    start_junction = start_point
    end_junction = end_point

    queue_redraw()


func _draw() -> void:

    var points: PackedVector2Array = get_sampled_points()

    if points.size() < 2:
        return

    draw_polyline(
        points,
        Color(0.45, 0.85, 0.95),
        membrane_width,
        true
    )


func get_control_point() -> Vector2:

    if start_junction == null:
        return Vector2.ZERO

    if end_junction == null:
        return Vector2.ZERO

    var start_position: Vector2 = start_junction.position
    var end_position: Vector2 = end_junction.position

    var difference: Vector2 = (
        end_position - start_position
    )

    var length: float = difference.length()

    if length <= 0.001:
        return start_position

    var direction: Vector2 = (
        difference / length
    )

    var perpendicular := Vector2(
        -direction.y,
        direction.x
    )

    var midpoint: Vector2 = (
        start_position + end_position
    ) * 0.5

    var offset: float = (
        length
        * curve_offset_ratio
        * curve_side
    )

    return (
        midpoint
        + perpendicular * offset
    )


func get_sampled_points() -> PackedVector2Array:

    var points := PackedVector2Array()

    if start_junction == null:
        return points

    if end_junction == null:
        return points

    var start_position: Vector2 = start_junction.position
    var end_position: Vector2 = end_junction.position

    var control_position: Vector2 = get_control_point()

    var chord_length: float = (
        start_position.distance_to(
            end_position
        )
    )

    var sample_count: int = max(
        8,
        int(ceil(chord_length / 12.0))
    )

    for index in range(sample_count + 1):

        var t: float = (
            float(index)
            / float(sample_count)
        )

        var inverse_t: float = 1.0 - t

        var point: Vector2 = (
            inverse_t * inverse_t * start_position
            + 2.0 * inverse_t * t * control_position
            + t * t * end_position
        )

        points.append(point)

    return points


func get_length() -> float:

    var points: PackedVector2Array = (
        get_sampled_points()
    )

    if points.size() < 2:
        return 0.0

    var total_length: float = 0.0

    for index in range(
        points.size() - 1
    ):

        total_length += points[index].distance_to(
            points[index + 1]
        )

    return total_length


func set_curve_offset_ratio(
    new_ratio: float
) -> void:

    curve_offset_ratio = new_ratio

    queue_redraw()
