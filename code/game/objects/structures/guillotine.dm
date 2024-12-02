#define GUILLOTINE_BLADE_MAX_SHARP  10 // This is maxiumum sharpness and will decapitate without failure
#define GUILLOTINE_DECAP_MIN_SHARP  7  // Minimum amount of sharpness for decapitation. Any less and it will just do severe brute damage
#define GUILLOTINE_ANIMATION_LENGTH 9 // How many deciseconds the animation is
#define GUILLOTINE_BLADE_RAISED     1
#define GUILLOTINE_BLADE_MOVING     2
#define GUILLOTINE_BLADE_DROPPED    3
#define GUILLOTINE_BLADE_SHARPENING 4
#define GUILLOTINE_HEAD_OFFSET      16 // How much we need to move the player to center their head
#define GUILLOTINE_LAYER_DIFF       1.2 // How much to increase/decrease a head when it's buckled/unbuckled
#define GUILLOTINE_ACTIVATE_DELAY   30 // Delay for executing someone
#define GUILLOTINE_WRENCH_DELAY     10
#define GUILLOTINE_ACTION_INUSE      5
#define GUILLOTINE_ACTION_WRENCH     6

/obj/structure/guillotine
	name = "guillotine"
	desc = "A large structure used to remove the heads of traitors and treasonists."
	icon = 'icons/obj/guillotine.dmi'
	icon_state = "guillotine_raised"
	can_buckle = TRUE
	anchored = TRUE
	density = TRUE
	max_buckled_mobs = 1
	buckle_lying = 0
	buckle_prevents_pull = TRUE
	layer = ABOVE_MOB_LAYER
	var/blade_status = GUILLOTINE_BLADE_RAISED
	var/blade_sharpness = GUILLOTINE_BLADE_MAX_SHARP // How sharp the blade is
	var/kill_count = 0
	var/current_action = 0 // What's currently happening to the guillotine

/obj/structure/guillotine/Initialize()
	LAZYINITLIST(buckled_mobs)
	. = ..()

/obj/structure/guillotine/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/stack/sheet/plasteel))
		to_chat(user, "<span class='notice'>You start repairing the guillotine with the plasteel...</span>")
		if(blade_sharpness<10)
			if(do_after(user,100,target=user))
				blade_sharpness = min(10,blade_sharpness+3)
				I.use(1)
				to_chat(user, "<span class='notice'>You repair the guillotine with the plasteel.</span>")
			else
				to_chat(user, "<span class='notice'>You stop repairing the guillotine with the plasteel.</span>")
		else
			to_chat(user, "<span class='warning'>The guillotine is already fully repaired!</span>")

/obj/structure/guillotine/examine(mob/user)
	. = ..()

	var/msg = "It is [anchored ? "wrenched to the floor." : "unsecured. A wrench should fix that."]<br/>"

	if (blade_status == GUILLOTINE_BLADE_RAISED)
		msg += "The blade is raised, ready to fall, and"

		if (blade_sharpness >= GUILLOTINE_DECAP_MIN_SHARP)
			msg += " looks sharp enough to decapitate without any resistance."
		else
			msg += " doesn't look particularly sharp. Perhaps a whetstone can be used to sharpen it."
	else
		msg += "The blade is hidden inside the stocks."

	. += msg

	if (LAZYLEN(buckled_mobs))
		. += "Someone appears to be strapped in. You can help them out, or you can harm them by activating the guillotine."

/obj/structure/guillotine/attack_hand(mob/user)
	add_fingerprint(user)

	// Currently being used by something
	if (current_action)
		return

	switch (blade_status)
		if (GUILLOTINE_BLADE_MOVING)
			return
		if (GUILLOTINE_BLADE_DROPPED)
			blade_status = GUILLOTINE_BLADE_MOVING
			icon_state = "guillotine_raise"
			addtimer(CALLBACK(src, PROC_REF(raise_blade)), GUILLOTINE_ANIMATION_LENGTH)
			return
		if (GUILLOTINE_BLADE_RAISED)
			if (LAZYLEN(buckled_mobs))
				if (user.a_intent == INTENT_HARM)
					user.visible_message("<span class='warning'>[user] begins to pull the lever!</span>",
						                 "<span class='warning'>You begin to the pull the lever.</span>")
					current_action = GUILLOTINE_ACTION_INUSE

					if (do_after(user, GUILLOTINE_ACTIVATE_DELAY, target = src) && blade_status == GUILLOTINE_BLADE_RAISED)
						current_action = 0
						blade_status = GUILLOTINE_BLADE_MOVING
						icon_state = "guillotine_drop"
						addtimer(CALLBACK(src, PROC_REF(drop_blade), user), GUILLOTINE_ANIMATION_LENGTH - 2) // Minus two so we play the sound and decap faster
					else
						current_action = 0
				else
					var/mob/living/carbon/human/H = buckled_mobs[1]

					if (H)
						H.regenerate_icons()

					unbuckle_all_mobs()
			else
				blade_status = GUILLOTINE_BLADE_MOVING
				icon_state = "guillotine_drop"
				addtimer(CALLBACK(src, PROC_REF(drop_blade)), GUILLOTINE_ANIMATION_LENGTH)

/obj/structure/guillotine/proc/raise_blade()
	blade_status = GUILLOTINE_BLADE_RAISED
	icon_state = "guillotine_raised"

/obj/structure/guillotine/proc/drop_blade(mob/user)
	if (has_buckled_mobs() && blade_sharpness)
		var/mob/living/carbon/human/H = buckled_mobs[1]

		if (!H)
			return

		var/obj/item/bodypart/head/head = H.get_bodypart("head")

		if (QDELETED(head))
			return

		playsound(src, 'sound/weapons/guillotine.ogg', 100, TRUE)
		if (blade_sharpness >= GUILLOTINE_DECAP_MIN_SHARP || head.brute_dam >= 100)
			for(var/mob/living/carbon/human/M in viewers(src, 7))
				if(M.stat == CONSCIOUS)
					var/loved = TRUE
					var/datum/preferences/P1 = GLOB.preferences_datums[ckey(M.key)]
					if(H in GLOB.masquerade_breakers_list)
						if(M.vampire_faction == "Sabbat")
							to_chat(M, "<span class='userdanger'><b>You feel your interests being ignored</b></span>")
							loved = FALSE
						else
							to_chat(M, "<span class='userhelp'><b>Violator was punished</b></span>")
							if(P1)
								P1.add_experience(1)
					if(H.diablerist)
						if(M.vampire_faction == "Camarilla")
							to_chat(M, "<span class='userhelp'><b>Diablerist was punished</b></span>")
							if(P1)
								P1.add_experience(1)
						else if(M.vampire_faction)
							loved = FALSE
							to_chat(M, "<span class='userdanger'><b>You feel your interests being ignored</b></span>")
					if(H.bloodhunted)
						if(M.vampire_faction == "Camarilla")
							to_chat(M, "<span class='userhelp'><b>Blood Hunt after [H] is over</b></span>")
							if(P1)
								P1.add_experience(1)
						else if(M.vampire_faction)
							loved = FALSE
							to_chat(M, "<span class='userdanger'><b>You feel your interests being ignored</b></span>")
					if("[H.mind.assigned_role]" == "Prince" || "[H.mind.assigned_role]" == "Sheriff" || "[H.mind.assigned_role]" == "Seneschal" || "[H.mind.assigned_role]" == "Chantry Regent" || "[H.mind.assigned_role]" == "Baron" || "[H.mind.assigned_role]" == "Dealer")
						if(M.vampire_faction == "Sabbat")
							to_chat(M, "<span class='userhelp'><b>Authority increased</b></span>")
							loved = TRUE
							if(P1)
								P1.add_experience(1)
					if(loved)
						M.emote("clap")
			var/datum/preferences/P = GLOB.preferences_datums[ckey(H.key)]
			head.dismember()
			log_combat(user, H, "beheaded", src)
			H.regenerate_icons()
			unbuckle_all_mobs()
			kill_count += 1
			var/blood_overlay = "bloody"
			if(P)
				P.reason_of_death = "Executed to sustain the Traditions ([time2text(world.timeofday, "YYYY-MM-DD hh:mm:ss")])."
			if (kill_count == 2)
				blood_overlay = "bloodier"
			else if (kill_count > 2)
				blood_overlay = "bloodiest"

			blood_overlay = "guillotine_" + blood_overlay + "_overlay"
			cut_overlays()
			add_overlay(mutable_appearance(icon, blood_overlay))

			SSbloodhunt.hunted -= H
			H.bloodhunted = FALSE
			SSbloodhunt.update_shit()
		else
			H.apply_damage(15 * blade_sharpness, BRUTE, head)
			log_combat(user, H, "dropped the blade on", src, " non-fatally")
			H.emote("scream")

	blade_status = GUILLOTINE_BLADE_DROPPED
	icon_state = "guillotine"

/obj/structure/guillotine/attackby(obj/item/W, mob/user, params)
	if (istype(W, /obj/item/sharpener))
		add_fingerprint(user)
		if (blade_status == GUILLOTINE_BLADE_SHARPENING)
			return

		if (blade_status == GUILLOTINE_BLADE_RAISED)
			if (blade_sharpness < GUILLOTINE_BLADE_MAX_SHARP)
				blade_status = GUILLOTINE_BLADE_SHARPENING
				if(do_after(user, 7, target = src))
					blade_status = GUILLOTINE_BLADE_RAISED
					user.visible_message("<span class='notice'>[user] sharpens the large blade of the guillotine.</span>",
						                 "<span class='notice'>You sharpen the large blade of the guillotine.</span>")
					blade_sharpness += 1
					playsound(src, 'sound/items/unsheath.ogg', 100, TRUE)
					return
				else
					blade_status = GUILLOTINE_BLADE_RAISED
					return
			else
				to_chat(user, "<span class='warning'>The blade is sharp enough!</span>")
				return
		else
			to_chat(user, "<span class='warning'>You need to raise the blade in order to sharpen it!</span>")
			return
	else
		return ..()

/obj/structure/guillotine/user_buckle_mob(mob/living/M, mob/user, check_loc = TRUE)
	if (!anchored)
		to_chat(usr, "<span class='warning'>[src] needs to be wrenched to the floor!</span>")
		return FALSE

	if (!istype(M, /mob/living/carbon/human))
		to_chat(usr, "<span class='warning'>It doesn't look like [M.p_they()] can fit into this properly!</span>")
		return FALSE // Can't decapitate non-humans

	if (blade_status != GUILLOTINE_BLADE_RAISED)
		to_chat(usr, "<span class='warning'>You need to raise the blade before buckling someone in!</span>")
		return FALSE

	return ..(M, user, check_loc = FALSE) //check_loc = FALSE to allow moving people in from adjacent turfs

/obj/structure/guillotine/post_buckle_mob(mob/living/M)
	if (!istype(M, /mob/living/carbon/human))
		return

	SEND_SIGNAL(M, COMSIG_ADD_MOOD_EVENT, "dying", /datum/mood_event/deaths_door)
	var/mob/living/carbon/human/H = M

	if (H.dna)
		if (H.dna.species)
			var/datum/species/S = H.dna.species

			if (istype(S))
				H.cut_overlays()
				H.update_body_parts_head_only()
				H.pixel_y += -GUILLOTINE_HEAD_OFFSET // Offset their body so it looks like they're in the guillotine
				H.layer += GUILLOTINE_LAYER_DIFF
			else
				unbuckle_all_mobs()
		else
			unbuckle_all_mobs()
	else
		unbuckle_all_mobs()

	..()

/obj/structure/guillotine/post_unbuckle_mob(mob/living/M)
	M.regenerate_icons()
	M.pixel_y -= -GUILLOTINE_HEAD_OFFSET // Move their body back
	M.layer -= GUILLOTINE_LAYER_DIFF
	SEND_SIGNAL(M, COMSIG_CLEAR_MOOD_EVENT, "dying")
	..()

/obj/structure/guillotine/can_be_unfasten_wrench(mob/user, silent)
	if (LAZYLEN(buckled_mobs))
		if (!silent)
			to_chat(user, "<span class='warning'>Can't unfasten, someone's strapped in!</span>")
		return FAILED_UNFASTEN

	if (current_action)
		return FAILED_UNFASTEN

	return ..()

/obj/structure/guillotine/wrench_act(mob/living/user, obj/item/I)
	. = ..()
	if (current_action)
		return

	current_action = GUILLOTINE_ACTION_WRENCH

	if (do_after(user, GUILLOTINE_WRENCH_DELAY, target = src))
		current_action = 0
		default_unfasten_wrench(user, I, 0)
		setDir(SOUTH)
		return TRUE
	else
		current_action = 0

#undef GUILLOTINE_BLADE_MAX_SHARP
#undef GUILLOTINE_DECAP_MIN_SHARP
#undef GUILLOTINE_ANIMATION_LENGTH
#undef GUILLOTINE_BLADE_RAISED
#undef GUILLOTINE_BLADE_MOVING
#undef GUILLOTINE_BLADE_DROPPED
#undef GUILLOTINE_BLADE_SHARPENING
#undef GUILLOTINE_HEAD_OFFSET
#undef GUILLOTINE_LAYER_DIFF
#undef GUILLOTINE_ACTIVATE_DELAY
#undef GUILLOTINE_WRENCH_DELAY
#undef GUILLOTINE_ACTION_INUSE
#undef GUILLOTINE_ACTION_WRENCH
