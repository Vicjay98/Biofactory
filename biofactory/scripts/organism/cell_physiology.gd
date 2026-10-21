extends RefCounted

signal state_changed

enum State { STABLE, WEAK, CRITICAL, DORMANT }

var cell: Node2D
var profile: CellPhysiologyProfile
var state: State = State.WEAK
var oxygen_intake_per_second: float = 0.0
var atp_demand_per_second: float = 0.0
var atp_production_per_second: float = 0.0
var metabolism: float = 1.0
var manual_cooldown_remaining: float = 0.0
var stable_seconds: float = 0.0
var stabilized: bool = false
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


func get_oxygen_ratio() -> float:
    return cell.inventory.get_amount("oxygen") / get_oxygen_capacity()


func get_state_name() -> String:
    return ["Stable", "Affaiblie", "Critique", "Dormance"][state]


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


func advance(delta: float) -> void:
    if delta <= 0.0:
        return
    manual_cooldown_remaining = maxf(manual_cooldown_remaining - delta, 0.0)
    # The prototype has a uniform reservoir of dissolved O2 outside the cell.
    # Shared sections never absorb from this reservoir.
    var oxygen: float = cell.inventory.get_amount("oxygen")
    var capacity: float = get_oxygen_capacity()
    var gradient: float = maxf(profile.ambient_oxygen - oxygen / capacity, 0.0)
    var intake: float = minf(
        cell.oxygen_conductance * gradient * delta,
        maxf(capacity * profile.ambient_oxygen - oxygen, 0.0)
    )
    cell.inventory.add_resource("oxygen", intake)
    oxygen_intake_per_second = intake / delta
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


func absorb_oxygen(section) -> float:
    if section == null or not section.is_external or manual_cooldown_remaining > 0.0:
        return 0.0
    if not cell.boundary.membrane_sections.has(section):
        return 0.0
    var room: float = maxf(
        get_oxygen_capacity() * profile.ambient_oxygen
        - cell.inventory.get_amount("oxygen"), 0.0
    )
    var amount: float = minf(room, profile.manual_oxygen_amount)
    if amount > 0.0:
        cell.inventory.add_resource("oxygen", amount)
        manual_cooldown_remaining = profile.manual_oxygen_cooldown
        refresh_state()
    return amount


func get_alerts() -> PackedStringArray:
    var alerts := PackedStringArray()
    if cell.inventory.get_amount("nutrient") < 2.0:
        alerts.append("Nutriments insuffisants : la production d'ATP attend du combustible.")
    if get_oxygen_ratio() < profile.low_oxygen_ratio:
        alerts.append("O₂ faible : le métabolisme ralentit. Améliorez les échanges membranaires.")
    if cell.inventory.get_amount("atp") < profile.low_atp:
        alerts.append("Réserve ATP faible : la cellule fonctionne au ralenti, mais reste récupérable.")
    if cell.get_buildings_by_id("atp_factory").is_empty():
        alerts.append("Aucune usine ATP : la cellule ne produit pas d'énergie.")
    if alerts.is_empty():
        alerts.append("Les réserves permettent un fonctionnement normal.")
    return alerts
