extends Node


signal resources_changed


var main_inventory = null


func bind_main_inventory(inventory) -> void:

    if main_inventory != null:

        if main_inventory.changed.is_connected(
            _on_inventory_changed
        ):
            main_inventory.changed.disconnect(
                _on_inventory_changed
            )

    main_inventory = inventory

    if main_inventory != null:

        main_inventory.changed.connect(
            _on_inventory_changed
        )

    resources_changed.emit()


func _on_inventory_changed() -> void:

    resources_changed.emit()


func get_amount(resource_id: String) -> float:

    if main_inventory == null:
        return 0.0

    return main_inventory.get_amount(resource_id)


func has_amount(
    resource_id: String,
    amount: float
) -> bool:

    if main_inventory == null:
        return false

    return main_inventory.has_amount(
        resource_id,
        amount
    )


func add_resource(
    resource_id: String,
    amount: float
) -> bool:

    if main_inventory == null:
        return false

    return main_inventory.add_resource(
        resource_id,
        amount
    )


func remove_resource(
    resource_id: String,
    amount: float
) -> bool:

    if main_inventory == null:
        return false

    return main_inventory.remove_resource(
        resource_id,
        amount
    )
