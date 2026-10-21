extends Node2D


var junction_id: String = ""

var radius: float = 6.0


func _ready() -> void:

    queue_redraw()


func _draw() -> void:

    draw_circle(
        Vector2.ZERO,
        radius,
        Color(0.9, 0.95, 1.0)
    )
