class_name RecipeProcessor
extends RefCounted


signal cycle_started
signal cycle_completed


var recipe: RecipeData

var input_inventory
var output_inventory

var cycle_progress: float = 0.0
var cycle_running: bool = false

var enabled: bool = true


func configure(
    recipe_data: RecipeData,
    input_inventory_data,
    output_inventory_data = null
) -> void:

    recipe = recipe_data

    input_inventory = input_inventory_data

    if output_inventory_data == null:
        output_inventory = input_inventory_data
    else:
        output_inventory = output_inventory_data

    cycle_progress = 0.0
    cycle_running = false


func process(delta: float) -> void:
    if not enabled or recipe == null or delta <= 0.0:
        return
    if input_inventory == null or output_inventory == null or recipe.duration <= 0.0:
        return
    # Preserve elapsed time when a frame completes several cycles.
    var remaining: float = delta
    while remaining > 0.000001:
        if not cycle_running:
            if not can_start_cycle():
                return
            consume_inputs()
            cycle_running = true
            cycle_progress = 0.0
            cycle_started.emit()
        var elapsed: float = minf(remaining, recipe.duration - cycle_progress)
        cycle_progress += elapsed
        remaining -= elapsed
        if cycle_progress + 0.000001 >= recipe.duration:
            produce_outputs()
            cycle_progress = 0.0
            cycle_running = false
            cycle_completed.emit()


func can_start_cycle() -> bool:

    for resource_id in recipe.inputs:

        var required_amount: float = recipe.inputs[
            resource_id
        ]

        if not input_inventory.has_amount(
            resource_id,
            required_amount
        ):
            return false

    return true


func consume_inputs() -> void:

    for resource_id in recipe.inputs:

        var amount: float = recipe.inputs[
            resource_id
        ]

        input_inventory.remove_resource(
            resource_id,
            amount
        )


func produce_outputs() -> void:

    for resource_id in recipe.outputs:

        var amount: float = recipe.outputs[
            resource_id
        ]

        output_inventory.add_resource(
            resource_id,
            amount
        )


func get_progress_ratio() -> float:

    if recipe == null:
        return 0.0

    if recipe.duration <= 0.0:
        return 0.0

    return cycle_progress / recipe.duration
