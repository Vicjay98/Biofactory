class_name CellGeometry
extends RefCounted


var outline: PackedVector2Array = PackedVector2Array()

var pixels_per_meter: float = 32.0


func configure(
    points: PackedVector2Array,
    world_pixels_per_meter: float
) -> void:

    outline = points.duplicate()

    pixels_per_meter = max(
        world_pixels_per_meter,
        0.001
    )


func get_area_pixels_squared() -> float:

    if outline.size() < 3:
        return 0.0

    var area: float = 0.0

    for index in range(outline.size()):

        var current_point: Vector2 = outline[index]

        var next_index: int = (
            (index + 1) % outline.size()
        )

        var next_point: Vector2 = outline[next_index]

        area += (
            current_point.x
            * next_point.y
        )

        area -= (
            next_point.x
            * current_point.y
        )

    return abs(area * 0.5)


func get_area_m2() -> float:

    var area_pixels: float = (
        get_area_pixels_squared()
    )

    return area_pixels / (
        pixels_per_meter * pixels_per_meter
    )


func get_perimeter_pixels() -> float:

    if outline.size() < 2:
        return 0.0

    var perimeter: float = 0.0

    for index in range(outline.size()):

        var current_point: Vector2 = outline[index]

        var next_index: int = (
            (index + 1) % outline.size()
        )

        var next_point: Vector2 = outline[next_index]

        perimeter += current_point.distance_to(
            next_point
        )

    return perimeter


func get_perimeter_m() -> float:

    return (
        get_perimeter_pixels()
        / pixels_per_meter
    )


func contains_point(
    local_point: Vector2
) -> bool:

    if outline.size() < 3:
        return false

    return Geometry2D.is_point_in_polygon(
        local_point,
        outline
    )


func is_large_enough(
    minimum_area_m2: float
) -> bool:

    return (
        get_area_m2()
        >= minimum_area_m2
    )


func get_centroid() -> Vector2:

    if outline.size() < 3:
        return Vector2.ZERO

    var signed_area: float = 0.0

    var centroid_x: float = 0.0
    var centroid_y: float = 0.0

    for index in range(outline.size()):

        var current_point: Vector2 = outline[index]

        var next_index: int = (
            (index + 1) % outline.size()
        )

        var next_point: Vector2 = outline[next_index]

        var cross: float = (
            current_point.x * next_point.y
            - next_point.x * current_point.y
        )

        signed_area += cross

        centroid_x += (
            current_point.x
            + next_point.x
        ) * cross

        centroid_y += (
            current_point.y
            + next_point.y
        ) * cross

    signed_area *= 0.5

    if abs(signed_area) <= 0.001:

        var average := Vector2.ZERO

        for point in outline:
            average += point

        return average / float(outline.size())

    centroid_x /= (
        6.0 * signed_area
    )

    centroid_y /= (
        6.0 * signed_area
    )

    return Vector2(
        centroid_x,
        centroid_y
    )
