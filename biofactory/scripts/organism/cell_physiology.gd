extends RefCounted

signal state_changed

enum State { STABLE, WEAK, CRITICAL, DORMANT }

var cell: Node2D
var profile: CellPhysiologyProfile
var state: State = State.WEAK
var oxygen_intake_per_second: float = 0.0
var nutrient_intake_per_second: float = 0.0
var atp_demand_per_second: float = 0.0
var atp_production_per_second: float = 0.0
var metabolism: float = 1.0
var manual_cooldown_remaining: float = 0.0
var nutrient_cooldown_remaining: float = 0.0
var stable_seconds: float = 0.0
var stabilized: bool = false
var autonomous_seconds: float = 0.0
var autonomous: bool = false
var _production: float = 0.0
var _measurement_seconds: float = 0.0


func configure(owner_cell: Node2D, settings: CellPhysiologyProfile) -> void:
    cell = owner_cell
    profile = settings
    _update_demand()
    refresh_state()


func _update_demand() -> void:
    atp_demand_per_second = (
        cell.get_area_m2() * profile.basal_atp_per_m2_per_second
        + cell.membrane_maintenance_atp_per_second
    )


func get_oxygen_capacity() -> float:
    return maxf(cell.get_area_m2() * profile.oxygen_capacity_per_m2, 0.01)


func get_nutrient_capacity() -> float:
    return maxf(cell.get_area_m2() * profile.nutrient_capacity_per_m2, 0.01)


func get_oxygen_ratio() -> float:
    return cell.inventory.get_amount("oxygen") / get_oxygen_capacity()


func get_nutrient_ratio() -> float:
    return cell.inventory.get_amount("nutrient") / get_nutrient_capacity()


func get_state_name() -> String:
    return ["Stable", "Affaiblie", "Critique", "Dormance"][state]


func has_low_nutrients() -> bool:
    return cell.inventory.get_amount("nutrient") < profile.low_nutrient


func get_status_name() -> String:
    # ATP/O2 stability unlocks feeding, but must not hide a nutrient shortage.
    if state == State.STABLE and has_low_nutrients():
        return "Nutriments faibles"
    return get_state_name()


func refresh_state() -> void:
    var previous: State = state
    var atp: float = cell.inventory.get_amount("atp")
    var oxygen_ratio: float = get_oxygen_ratio()
    var lacks_fuel: bool = (
        cell.inventory.get_amount("oxygen") < 1.0
        or cell.inventory.get_amount("nutrient") < 2.0
    )
    if atp <= profile.critical_atp and lacks_fuel:
        state = State.DORMANT
    elif atp <= profile.critical_atp or oxygen_ratio <= profile.critical_oxygen_ratio:
        state = State.CRITICAL
    elif atp < profile.low_atp or oxygen_ratio < profile.low_oxygen_ratio:
        state = State.WEAK
    else:
        state = State.STABLE
    metabolism = 1.0 if state == State.STABLE else profile.stressed_metabolism
    if state != previous:
        state_changed.emit()


func _passive_intake(resource_id: String, conductance: float, capacity: float, ambient: float, delta: float) -> float:
    var stored: float = cell.inventory.get_amount(resource_id)
    var gradient: float = maxf(ambient - stored / capacity, 0.0)
    var amount: float = minf(conductance * gradient * delta, maxf(capacity * ambient - stored, 0.0))
    if amount > 0.0:
        cell.inventory.add_resource(resource_id, amount)
    return amount / delta


func advance(delta: float) -> void:
    if delta <= 0.0:
        return
    manual_cooldown_remaining = maxf(manual_cooldown_remaining - delta, 0.0)
    nutrient_cooldown_remaining = maxf(nutrient_cooldown_remaining - delta, 0.0)
    # Uniform external reservoirs for this prototype. Only exterior physical
    # membrane fragments contribute to the conductances cached by BioCell.
    oxygen_intake_per_second = _passive_intake(
        "oxygen", cell.oxygen_conductance, get_oxygen_capacity(), profile.ambient_oxygen, delta
    )
    nutrient_intake_per_second = _passive_intake(
        "nutrient", cell.nutrient_conductance, get_nutrient_capacity(), profile.ambient_nutrient, delta
    )
    refresh_state()
    for building in cell.buildings.duplicate():
        if is_instance_valid(building):
            _production += building.simulate(delta * metabolism)
    _update_demand()
    var payment: float = minf(
        cell.inventory.get_amount("atp"), atp_demand_per_second * delta
    )
    cell.inventory.remove_resource("atp", payment)
    _measurement_seconds += delta
    if _measurement_seconds >= 2.0:
        atp_production_per_second = _production / _measurement_seconds
        _production = 0.0
        _measurement_seconds = 0.0
    refresh_state()
    if state == State.STABLE:
        stable_seconds += delta
        if stable_seconds >= profile.stabilization_seconds:
            stabilized = true
    else:
        stable_seconds = 0.0
    # The first milestone teaches ATP/O2 recovery. Nutrition must not lock
    # its own unlock behind that later requirement (e.g. with two factories).
    if get_autonomy_wait_reason().is_empty():
        autonomous_seconds += delta
        if autonomous_seconds >= profile.autonomy_seconds:
            autonomous = true
    else:
        autonomous_seconds = 0.0


func _absorb_manually(section, resource_id: String, capacity: float, ambient: float, requested: float) -> float:
    if section == null or not section.is_external:
        return 0.0
    if not cell.boundary.membrane_sections.has(section):
        return 0.0
    var room: float = maxf(capacity * ambient - cell.inventory.get_amount(resource_id), 0.0)
    var amount: float = minf(room, requested)
    if amount > 0.0:
        cell.inventory.add_resource(resource_id, amount)
        autonomous_seconds = 0.0
        refresh_state()
    return amount


func absorb_oxygen(section) -> float:
    if manual_cooldown_remaining > 0.0:
        return 0.0
    var amount: float = _absorb_manually(
        section, "oxygen", get_oxygen_capacity(), profile.ambient_oxygen, profile.manual_oxygen_amount
    )
    if amount > 0.0:
        manual_cooldown_remaining = profile.manual_oxygen_cooldown
    return amount


func absorb_nutrients(section) -> float:
    if nutrient_cooldown_remaining > 0.0:
        return 0.0
    var amount: float = _absorb_manually(
        section, "nutrient", get_nutrient_capacity(), profile.ambient_nutrient, profile.manual_nutrient_amount
    )
    if amount > 0.0:
        nutrient_cooldown_remaining = profile.manual_nutrient_cooldown
    return amount


## Evaluate supply at healthy reserve thresholds, not at the current stock:
## a high initial stock may settle toward a viable equilibrium without growing.
func get_autonomy_blockers() -> PackedStringArray:
    _update_demand()
    var blockers := PackedStringArray()
    if not stabilized:
        blockers.append("Stabilisez d'abord la cellule.")
        return blockers
    var demand: Dictionary[String, float] = {}
    var atp_output: float = 0.0
    for building in cell.buildings:
        if not is_instance_valid(building) or building.data == null or building.data.supported_recipes.is_empty():
            continue
        if building.recipe_processor != null and not building.recipe_processor.enabled:
            continue
        var recipe = RecipeDatabase.get_recipe(building.data.supported_recipes[0])
        if recipe == null or recipe.duration <= 0.0:
            continue
        for resource_id in recipe.inputs:
            demand[resource_id] = demand.get(resource_id, 0.0) + recipe.inputs[resource_id] / recipe.duration
        atp_output += recipe.outputs.get("atp", 0.0) / recipe.duration
    var oxygen_supply: float = cell.oxygen_conductance * maxf(profile.ambient_oxygen - profile.low_oxygen_ratio, 0.0)
    var nutrient_supply: float = cell.nutrient_conductance * maxf(profile.ambient_nutrient - profile.low_nutrient / get_nutrient_capacity(), 0.0)
    if oxygen_supply < demand.get("oxygen", 0.0):
        blockers.append("Échanges O₂ trop faibles pour alimenter toutes les usines.")
    if nutrient_supply < demand.get("nutrient", 0.0):
        blockers.append("Collecte de nutriments insuffisante : une membrane d'alimentation est disponible.")
    if atp_output <= atp_demand_per_second + demand.get("atp", 0.0):
        blockers.append("La production ATP ne couvre pas l'entretien de la cellule.")
    for resource_id in demand:
        if resource_id not in ["oxygen", "nutrient", "atp"] and demand[resource_id] > 0.0:
            blockers.append("Approvisionnement non automatisé : " + ResourceDatabase.get_resource(resource_id).display_name)
    return blockers


func get_stability_wait_reason() -> String:
    if state == State.STABLE:
        return ""
    var atp: float = cell.inventory.get_amount("atp")
    if atp < profile.low_atp:
        return "Réserve ATP : %.1f / %.1f." % [atp, profile.low_atp]
    if get_oxygen_ratio() < profile.low_oxygen_ratio:
        return "Réserve O₂ : %.1f / %.1f." % [cell.inventory.get_amount("oxygen"), get_oxygen_capacity() * profile.low_oxygen_ratio]
    return "État de la cellule : " + get_state_name() + "."


## Shared by the timer and the HUD so a stopped counter always has a reason.
func get_autonomy_wait_reason() -> String:
    if not stabilized:
        return "Stabilisez d'abord l'ATP et l'O₂ de la cellule."
    var stability_reason: String = get_stability_wait_reason()
    if not stability_reason.is_empty():
        return stability_reason
    var blockers: PackedStringArray = get_autonomy_blockers()
    if not blockers.is_empty():
        return blockers[0]
    if has_low_nutrients():
        return "Reconstitution automatique des nutriments : %.1f / %.1f." % [cell.inventory.get_amount("nutrient"), profile.low_nutrient]
    return ""


func get_alerts() -> PackedStringArray:
    var alerts := PackedStringArray()
    var autonomy_blockers: PackedStringArray = get_autonomy_blockers() if stabilized else PackedStringArray()
    if has_low_nutrients():
        if stabilized and autonomy_blockers.is_empty():
            alerts.append("Nutriments en reconstitution automatique : %.1f / %.1f. Le chrono attend une réserve suffisante." % [cell.inventory.get_amount("nutrient"), profile.low_nutrient])
        else:
            alerts.append("Nutriments faibles : améliorez la collecte ou utilisez une absorption de secours.")
    if get_oxygen_ratio() < profile.low_oxygen_ratio:
        alerts.append("O₂ faible : le métabolisme ralentit. Améliorez les échanges membranaires.")
    if cell.inventory.get_amount("atp") < profile.low_atp:
        alerts.append("Réserve ATP faible : la cellule fonctionne au ralenti, mais reste récupérable.")
    if cell.get_buildings_by_id("atp_factory").is_empty():
        alerts.append("Aucune usine ATP : la cellule ne produit pas d'énergie.")
    if stabilized:
        alerts.append_array(autonomy_blockers)
    if alerts.is_empty():
        alerts.append(
            "Les échanges peuvent soutenir la production sans secours manuel."
            if stabilized else "Réserves saines : maintenez cet état pour stabiliser la cellule."
        )
    return alerts
