extends RefCounted


func calculate_cost(
    boundary,
    old_outline: PackedVector2Array,
    new_outline: PackedVector2Array
) -> Dictionary[String, float]:

    var total_cost: Dictionary[String, float] = {}

    if boundary == null:
        return total_cost

    for section in boundary.membrane_sections:

        var old_length: float = (
            boundary.get_section_length_m_for_outline(
                section,
                old_outline
            )
        )

        var new_length: float = (
            boundary.get_section_length_m_for_outline(
                section,
                new_outline
            )
        )

        var added_length: float = max(
            new_length - old_length,
            0.0
        )

        if added_length <= 0.0001:
            continue

        var membrane_data = (
            MembraneTypeDatabase.get_membrane_type(
                section.membrane_type_id
            )
        )

        if membrane_data == null:
            continue

        for resource_id in (
            membrane_data.build_cost_per_meter
        ):

            var cost_per_meter: float = (
                membrane_data
                .build_cost_per_meter[
                    resource_id
                ]
            )

            var section_cost: float = (
                cost_per_meter
                * added_length
            )

            if not total_cost.has(
                resource_id
            ):

                total_cost[
                    resource_id
                ] = 0.0

            total_cost[
                resource_id
            ] += section_cost

    return total_cost


func can_afford(
    inventory,
    cost: Dictionary[String, float]
) -> bool:

    if inventory == null:
        return false

    for resource_id in cost:

        var amount: float = cost[
            resource_id
        ]

        if not inventory.has_amount(
            resource_id,
            amount
        ):

            return false

    return true


func pay_cost(
    inventory,
    cost: Dictionary[String, float]
) -> bool:

    if not can_afford(
        inventory,
        cost
    ):
        return false

    for resource_id in cost:

        var amount: float = cost[
            resource_id
        ]

        inventory.remove_resource(
            resource_id,
            amount
        )

    return true
