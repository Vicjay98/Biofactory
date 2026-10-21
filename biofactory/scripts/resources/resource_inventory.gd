class_name ResourceInventory
extends RefCounted


signal changed


var amounts: Dictionary[String, float] = {}


func get_amount(resource_id: String) -> float:

    return amounts.get(resource_id, 0.0)


func has_amount(
    resource_id: String,
    amount: float
) -> bool:

    return get_amount(resource_id) >= amount


func set_amount(
    resource_id: String,
    amount: float
) -> void:

    if not ResourceDatabase.has_resource(resource_id):
        push_warning(
            "Impossible de définir une ressource inconnue : " + resource_id
        )
        return

    var new_amount: float = max(amount, 0.0)

    if get_amount(resource_id) == new_amount:
        return

    amounts[resource_id] = new_amount

    changed.emit()


func add_resource(
    resource_id: String,
    amount: float
) -> bool:

    if not ResourceDatabase.has_resource(resource_id):
        push_warning(
            "Impossible d'ajouter une ressource inconnue : " + resource_id
        )
        return false

    if amount < 0.0:
        push_warning(
			"Impossible d'ajouter une quantité négative."
        )
        return false

    if not amounts.has(resource_id):
        amounts[resource_id] = 0.0

    amounts[resource_id] += amount

    changed.emit()

    return true


func remove_resource(
    resource_id: String,
    amount: float
) -> bool:

    if amount < 0.0:
        return false

    if not has_amount(resource_id, amount):
        return false

    if amount == 0.0:
        return true

    amounts[resource_id] -= amount

    changed.emit()

    return true
