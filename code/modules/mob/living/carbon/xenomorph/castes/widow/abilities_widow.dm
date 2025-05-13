// ***************************************
// *********** Resin building
// ***************************************
/datum/action/ability/activable/xeno/secrete_resin/widow
	ability_cost = 100
	buildable_structures = list(
		/turf/closed/wall/resin/regenerating/thick,
		/obj/alien/resin/sticky,
		/obj/structure/mineral_door/resin/thick,
	)

// ***************************************
// *********** Web Spit
// ***************************************

/datum/action/ability/activable/xeno/web_spit
	name = "Web Spit"
	desc = "Spit a web to your target, this causes different effects depending on where you hit. Spitting the head causes the target to be temporarily blind, body and arms will cause the target to be weakened, and legs will snare the target for a brief while."
	action_icon_state = "web_spit"
	action_icon = 'icons/Xeno/actions/widow.dmi'
	ability_cost = 125
	cooldown_duration = 10 SECONDS
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_WEB_SPIT,
	)

/datum/action/ability/activable/xeno/web_spit/use_ability(atom/target)
	var/datum/ammo/xeno/web/web_spit = GLOB.ammo_list[/datum/ammo/xeno/web]
	var/obj/projectile/newspit = new /obj/projectile(get_turf(xeno_owner))

	newspit.generate_bullet(web_spit, web_spit.damage * SPIT_UPGRADE_BONUS(xeno_owner))
	newspit.def_zone = xeno_owner.get_limbzone_target()

	newspit.fire_at(target, xeno_owner, xeno_owner, newspit.ammo.max_range)
	succeed_activate()
	add_cooldown()

// ***************************************
// *********** Leash Ball
// ***************************************

/datum/action/ability/activable/xeno/leash_ball
	name = "Leash Ball"
	desc = "Spit a huge web ball that snares groups of targets for a brief while."
	action_icon_state = "leash_ball"
	action_icon = 'icons/Xeno/actions/widow.dmi'
	ability_cost = 250
	cooldown_duration = 20 SECONDS
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_LEASH_BALL,
	)

/datum/action/ability/activable/xeno/leash_ball/use_ability(atom/A)
	var/turf/target = get_turf(A)
	xeno_owner.face_atom(target)
	if(!do_after(xeno_owner, 1 SECONDS, NONE, xeno_owner, BUSY_ICON_DANGER))
		return fail_activate()
	var/datum/ammo/xeno/leash_ball/leash_ball = GLOB.ammo_list[/datum/ammo/xeno/leash_ball]
	leash_ball.hivenumber = xeno_owner.hivenumber
	leash_ball.creator = xeno_owner
	var/obj/projectile/newspit = new (get_turf(xeno_owner))

	newspit.generate_bullet(leash_ball)
	newspit.fire_at(target, xeno_owner, xeno_owner, newspit.ammo.max_range)
	succeed_activate()
	add_cooldown()

/obj/structure/xeno/aoe_leash
	name = "Snaring Web"
	icon = 'icons/Xeno/Effects.dmi'
	icon_state = "aoe_leash"
	desc = "Sticky and icky. Destroy it when you are stuck!"
	destroy_sound = SFX_ALIEN_RESIN_BREAK
	max_integrity = 75
	layer = ABOVE_ALL_MOB_LAYER
	anchored = TRUE
	allow_pass_flags = NONE
	density = FALSE
	obj_flags = CAN_BE_HIT | PROJ_IGNORE_DENSITY
	/// How long the leash ball lasts untill it dies
	var/leash_life = 10 SECONDS
	/// Radius for how far the leash should affect humans and how far away they may walk
	var/leash_radius = 5
	/// List of beams to be removed on obj_destruction
	var/list/obj/effect/ebeam/beams = list()
	/// List of victims to unregister aoe_leash is destroyed
	var/list/mob/living/carbon/human/leash_victims = list()
	/// Xeno that created the web ball
	var/mob/living/carbon/xenomorph/creator = null

/// Humans caught get beamed and registered for proc/check_dist, aoe_leash also gains increased integrity for each caught human
/obj/structure/xeno/aoe_leash/Initialize(mapload, _hivenumber, _creator)
	. = ..()
	for(var/mob/living/carbon/human/victim in GLOB.humans_by_zlevel["[z]"])
		if(get_dist(src, victim) > leash_radius)
			continue
		if(victim.stat == DEAD) /// Add || CONSCIOUS after testing
			continue
		if(HAS_TRAIT(victim, TRAIT_LEASHED))
			continue
		if(check_path(src, victim, pass_flags_checked = PASS_PROJECTILE) != get_turf(victim))
			continue
		leash_victims += victim
	for(var/mob/living/carbon/human/snared_victim AS in leash_victims)
		ADD_TRAIT(snared_victim, TRAIT_LEASHED, src)
		beams += beam(snared_victim, "beam_web", 'icons/effects/beam.dmi', INFINITY, INFINITY)
		RegisterSignal(snared_victim, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_dist))
	if(!length(beams))
		return INITIALIZE_HINT_QDEL
	creator = _creator
	RegisterSignal(creator, COMSIG_QDELETING, PROC_REF(clear_creator))
	var/datum/action/ability/xeno_action/create_spiderling/create_spiderling_action = creator.actions_by_path[/datum/action/ability/xeno_action/create_spiderling]
	if(create_spiderling_action)
		create_spiderling_action.add_spiderling()
	QDEL_IN(src, leash_life)

/// To remove beams after the leash_ball is destroyed and also unregister all victims
/obj/structure/xeno/aoe_leash/Destroy()
	for(var/mob/living/carbon/human/victim AS in leash_victims)
		UnregisterSignal(victim, COMSIG_MOVABLE_PRE_MOVE)
		REMOVE_TRAIT(victim, TRAIT_LEASHED, src)
	leash_victims = null
	creator = null
	QDEL_LIST(beams)
	return ..()

///Signal handler for creator destruction to clear reference
/obj/structure/xeno/aoe_leash/proc/clear_creator()
	SIGNAL_HANDLER
	creator = null

/// Humans caught in the aoe_leash will be pulled back if they leave it's radius
/obj/structure/xeno/aoe_leash/proc/check_dist(datum/leash_victim, atom/newloc)
	SIGNAL_HANDLER
	if(get_dist(newloc, src) >= leash_radius)
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/// This is so that xenos can remove leash balls
/obj/structure/xeno/aoe_leash/attack_alien(mob/living/carbon/xenomorph/xeno_attacker, damage_amount = xeno_attacker.xeno_caste.melee_damage, damage_type = BRUTE, armor_type = MELEE, effects = TRUE, armor_penetration = xeno_attacker.xeno_caste.melee_ap, isrightclick = FALSE)
	if(xeno_attacker.status_flags & INCORPOREAL)
		return
	xeno_attacker.visible_message(span_xenonotice("\The [xeno_attacker] starts tearing down \the [src]!"), \
	span_xenonotice("We start to tear down \the [src]."))
	if(!do_after(xeno_attacker, 1 SECONDS, NONE, xeno_attacker, BUSY_ICON_GENERIC) || QDELETED(src))
		return
	xeno_attacker.do_attack_animation(src, ATTACK_EFFECT_CLAW)
	xeno_attacker.visible_message(span_xenonotice("\The [xeno_attacker] tears down \the [src]!"), \
	span_xenonotice("We tear down \the [src]."))
	playsound(src, SFX_ALIEN_RESIN_BREAK, 25)
	take_damage(max_integrity)

// ***************************************
// *********** Spiderling Section
// ***************************************

/datum/action/ability/xeno_action/create_spiderling
	name = "Birth Spiderlings"
	desc = "Give birth to three spiderling after a short charge-up. The spiderlings will attack the nearest enemy, or the one that is marked. Spiderlings will perish after 15 seconds."
	action_icon_state = "spawn_spiderling"
	action_icon = 'icons/Xeno/actions/widow.dmi'
	ability_cost = 100
	cooldown_duration = 5 SECONDS
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_CREATE_SPIDERLING,
	)
	use_state_flags = ABILITY_USE_LYING

	/// List of all our spiderlings
	var/list/mob/living/carbon/xenomorph/spiderling/spiderlings = list()

/datum/action/ability/xeno_action/create_spiderling/give_action(mob/living/L)
	. = ..()
	var/max_spiderlings = xeno_owner?.xeno_caste.max_spiderlings ? xeno_owner.xeno_caste.max_spiderlings : 5
	desc = "Give birth to a spiderling after a short charge-up. The spiderlings will follow you until death. You can only deploy [max_spiderlings] spiderlings at one time. On alt-use, if any charges of Cannibalise are stored, create a spiderling at no plasma cost or cooldown."

/datum/action/ability/xeno_action/create_spiderling/can_use_action(silent = FALSE, override_flags)
	. = ..()
	if(!.)
		return FALSE
	if(length(spiderlings) >= xeno_owner.xeno_caste.max_spiderlings)
		if(!silent)
			xeno_owner.balloon_alert(xeno_owner, "Max Spiderlings")
		return FALSE

/// The action to create spiderlings
/datum/action/ability/xeno_action/create_spiderling/action_activate()
	. = ..()
	if(!do_after(owner, 0.5 SECONDS, NONE, owner, BUSY_ICON_DANGER))
		return fail_activate()
	release_spiderlings()
	succeed_activate()
	add_cooldown()

/datum/action/ability/xeno_action/create_spiderling/proc/release_spiderlings(time_left = 3)
	if(time_left <= 0)
		return
	if(xeno_owner.IsStaggered()) //If we got staggered, return
		to_chat(xeno_owner, span_xenowarning("We try to release spiderlings but are staggered!"))
		return
	if(xeno_owner.IsStun() || xeno_owner.IsParalyzed())
		to_chat(xeno_owner, span_xenowarning("We try to release spiderlings but are disabled!"))
		return
	add_spiderling()
	addtimer(CALLBACK(src, PROC_REF(release_spiderlings), time_left - 1), WIDOW_RELEASE_SPIDERLINGS_DELAY)

/// Adds spiderlings to spiderling list and registers them for death so we can remove them later
/datum/action/ability/xeno_action/create_spiderling/proc/add_spiderling()
	SIGNAL_HANDLER
	/// This creates and stores the spiderling so we can reassign the owner for spider swarm and cap how many spiderlings you can have at once
	var/mob/living/carbon/xenomorph/spiderling/new_spiderling = new(owner.loc, owner, owner)
	RegisterSignals(new_spiderling, list(COMSIG_MOB_DEATH, COMSIG_QDELETING), PROC_REF(remove_spiderling))
	spiderlings += new_spiderling
	new_spiderling.pixel_x = rand(-8, 8)
	new_spiderling.pixel_y = rand(-8, 8)
	return TRUE

/// Removes spiderling from spiderling list and unregisters death signal
/datum/action/ability/xeno_action/create_spiderling/proc/remove_spiderling(datum/source)
	SIGNAL_HANDLER
	spiderlings -= source
	UnregisterSignal(source, list(COMSIG_MOB_DEATH, COMSIG_QDELETING))

// ***************************************
// *********** Spiderling mark
// ***************************************

/datum/action/ability/activable/xeno/spiderling_mark
	name = "Spiderling Mark"
	desc = "Send your spawn on a valid target."
	action_icon_state = "spiderling_mark"
	action_icon = 'icons/Xeno/actions/widow.dmi'
	ability_cost = 0
	cooldown_duration = 0.5 SECONDS
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_SPIDERLING_MARK,
	)
	use_state_flags = ABILITY_USE_INCAP|ABILITY_USE_LYING|ABILITY_USE_STAGGERED|ABILITY_USE_BUSY

/datum/action/ability/activable/xeno/spiderling_mark/use_ability(atom/A)
	. = ..()
	var/datum/action/ability/xeno_action/create_spiderling/create_spiderling_action = owner.actions_by_path[/datum/action/ability/xeno_action/create_spiderling]
	if(length(create_spiderling_action.spiderlings) <= 0)
		owner.balloon_alert(owner, "No spiderlings")
		return fail_activate()
	if(!isturf(A) && !istype(A, /obj/alien/weeds))
		owner.balloon_alert(owner, "Spiderlings attacking " + A.name)
	else
		for(var/item in A) //Autoaim at humans if weeds or turfs are clicked
			if(!ishuman(item))
				continue
			A = item
			owner.balloon_alert(owner, "Spiderlings attacking " + A.name)
			break
		if(!ishuman(A)) //If no human found, cancel ability
			owner.balloon_alert(owner, "Nothing to attack, cancelled")
			return fail_activate()

	succeed_activate()
	SEND_SIGNAL(owner, COMSIG_SPIDERLING_MARK, A)
	add_cooldown()

// ***************************************
// *********** Web Hook
// ***************************************
/datum/action/ability/activable/xeno/web_hook
	name = "Web Hook"
	desc = "Shoot out a web and pull it to traverse forward"
	action_icon_state = "web_hook"
	action_icon = 'icons/Xeno/actions/widow.dmi'
	ability_cost = 200
	cooldown_duration = 10 SECONDS
	keybinding_signals = list(
		KEYBINDING_NORMAL = COMSIG_XENOABILITY_WEB_HOOK,
	)
	//ref to beam for web hook
	var/datum/beam/web_beam

/datum/action/ability/activable/xeno/web_hook/can_use_ability(atom/A)
	. = ..()
	if(!.)
		return
	if(isliving(A))
		owner.balloon_alert(owner, "We can't attach to that")
		return FALSE
	if(!isturf(A))
		return FALSE
	if(get_dist(owner, A) <= WIDOW_WEB_HOOK_MIN_RANGE)
		owner.balloon_alert(owner, "Too close")
		return FALSE
	var/turf/current = get_turf(owner)
	var/turf/target_turf = get_turf(A)
	if(get_dist(current, target_turf) > WIDOW_WEB_HOOK_RANGE)
		owner.balloon_alert(owner, "Too far")
		return FALSE
	current = get_step_towards(current, target_turf)

/datum/action/ability/activable/xeno/web_hook/use_ability(atom/A)
	var/atom/movable/web_hook/web_hook = new (get_turf(owner))
	web_beam = owner.beam(web_hook,"beam_web",'icons/effects/beam.dmi')
	RegisterSignals(web_hook, list(COMSIG_MOVABLE_POST_THROW, COMSIG_MOVABLE_IMPACT), PROC_REF(drag_widow), TRUE)
	web_hook.throw_at(A, WIDOW_WEB_HOOK_RANGE, 3, owner, FALSE)
	succeed_activate()
	add_cooldown()

/// This throws widow wherever the web_hook landed, distance is dependant on if the web_hook hit a wall or just ground
/datum/action/ability/activable/xeno/web_hook/proc/drag_widow(datum/source, turf/target_turf)
	SIGNAL_HANDLER
	QDEL_NULL(web_beam)
	if(target_turf)
		owner.throw_at(target_turf, WIDOW_WEB_HOOK_RANGE, WIDOW_WEB_HOOK_SPEED, owner, FALSE)
	else
		// we throw widow half the distance if she hits the floor
		owner.throw_at(get_turf(source), WIDOW_WEB_HOOK_RANGE / 2, WIDOW_WEB_HOOK_SPEED, owner, FALSE)
	qdel(source)
	RegisterSignal(owner, COMSIG_MOVABLE_POST_THROW, PROC_REF(delete_beam))

///signal handler to delete the web_hook after we are done draggging owner along
/datum/action/ability/activable/xeno/web_hook/proc/delete_beam(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOVABLE_POST_THROW)
	QDEL_NULL(web_beam)

/// Our web hook that we throw
/atom/movable/web_hook
	name = "You can't see this"
	invisibility = INVISIBILITY_ABSTRACT
