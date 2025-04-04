/mob/living/silicon/ai/proc/InvalidTurf(turf/T as turf)
	if(!T)
		return 1
	if(!is_level_reachable(T.z))
		return 1
	return 0

/mob/living/silicon/ai/proc/get_camera_list()

	track.cameras.Cut()

	if(stat == DEAD)
		return

	var/list/L = list()
	for(var/obj/machinery/camera/C in GLOB.cameranet.cameras)
		L.Add(C)

	camera_sort(L)

	var/list/T = list()

	for(var/obj/machinery/camera/C in L)
		var/list/tempnetwork = C.network & src.network
		if(length(tempnetwork))
			T[text("[][]", C.c_tag, (C.can_use() ? null : " (Deactivated)"))] = C

	track.cameras = T
	return T


/mob/living/silicon/ai/proc/ai_camera_list(camera in get_camera_list())
	set category = "AI Commands"
	set name = "Show Camera List"

	if(stat == DEAD)
		to_chat(src, "You can't list the cameras because you are dead!")
		return

	if(!camera || camera == "Cancel")
		return 0

	var/obj/machinery/camera/C = track.cameras[camera]
	src.eyeobj.set_loc(C)

	return

// Used to allow the AI is write in mob names/camera name from the CMD line.
/datum/trackable
	var/list/names = list()
	var/list/namecounts = list()
	var/list/humans = list()
	var/list/others = list()
	var/list/cameras = list()

/mob/living/silicon/ai/proc/trackable_mobs()

	track.names.Cut()
	track.namecounts.Cut()
	track.humans.Cut()
	track.others.Cut()

	if(usr.stat == DEAD)
		return list()

	for(var/mob/living/M in GLOB.mob_list)
		if(!M.can_track(usr))
			continue

		// Human check
		var/human = 0
		if(ishuman(M))
			human = 1

		var/name = M.name
		if(name in track.names)
			track.namecounts[name]++
			name = "[name] ([track.namecounts[name]])"
		else
			track.names.Add(name)
			track.namecounts[name] = 1
		if(human)
			track.humans[name] = M
		else
			track.others[name] = M

	var/list/targets = sortList(track.humans) + sortList(track.others)

	return targets

/mob/living/silicon/ai/proc/ai_camera_track(target_name in trackable_mobs())
	set category = "AI Commands"
	set name = "Track With Camera"
	set desc = "Select who you would like to track."

	if(src.stat == DEAD)
		to_chat(src, "You can't track with camera because you are dead!")
		return
	if(!target_name)
		return

	var/mob/target = (isnull(track.humans[target_name]) ? track.others[target_name] : track.humans[target_name])

	ai_actual_track(target)

/mob/living/silicon/ai/proc/ai_cancel_tracking(forced = 0)
	if(!camera_follow)
		return

	to_chat(src, "Follow camera mode [forced ? "terminated" : "ended"].")
	camera_follow = null

/mob/living/silicon/ai/proc/ai_actual_track(mob/living/target, doubleclick = FALSE)
	if(!istype(target))
		return
	var/mob/living/silicon/ai/U = usr

	U.camera_follow = target
	U.tracking = TRUE

	to_chat(U, "<span class='notice'>Attempting to track [target.get_visible_name()]...</span>")
	if(!doubleclick)
		sleep(1.5 SECONDS) // Gives antags a brief window to get out of dodge before the eye of sauron decends upon them when someone yells ;HALP
	spawn(15) //give the AI a grace period to stop moving.
		U.tracking = FALSE

	if(target.is_jammed())
		to_chat(U, "<span class='warning'>Unable to track [target.get_visible_name()]...</span>")
		U.camera_follow = null
		return

	if(!target || !target.can_track(usr))
		to_chat(U, "<span class='warning'>Target is not near any active cameras.</span>")
		U.camera_follow = null
		return

	to_chat(U, "<span class='notice'>Now tracking [target.get_visible_name()] on camera.</span>")

	var/cameraticks = 0
	spawn(0)
		while(U.camera_follow == target)
			if(U.camera_follow == null)
				return

			if(!target.can_track(usr))
				U.tracking = TRUE
				if(!cameraticks)
					to_chat(U, "<span class='warning'>Target is not near any active cameras. Attempting to reacquire...</span>")
				cameraticks++
				if(cameraticks > 9)
					U.camera_follow = null
					to_chat(U, "<span class='warning'>Unable to reacquire, cancelling track...</span>")
					U.tracking = FALSE
					return
				else
					sleep(10)
					continue

			else
				cameraticks = 0
				U.tracking = FALSE

			if(U.eyeobj)
				U.eyeobj.set_loc(get_turf(target))

			else
				view_core()
				U.camera_follow = null
				return

			sleep(10)

/proc/near_camera(mob/living/M)
	if(!isturf(M.loc))
		return 0
	if(isrobot(M))
		var/mob/living/silicon/robot/R = M
		if(!(R.camera && R.camera.can_use()) && !GLOB.cameranet.check_camera_vis(M))
			return 0
	else if(!GLOB.cameranet.check_camera_vis(M))
		return 0
	return 1

/obj/machinery/camera/attack_ai(mob/living/silicon/ai/user)
	if(!istype(user))
		return
	if(!src.can_use())
		return
	user.eyeobj.set_loc(get_turf(src))


/mob/living/silicon/ai/attack_ai(mob/user)
	ai_camera_list()

/proc/camera_sort(list/L)
	var/obj/machinery/camera/a
	var/obj/machinery/camera/b

	for(var/i = length(L), i > 0, i--)
		for(var/j = 1 to i - 1)
			a = L[j]
			b = L[j + 1]
			if(a.c_tag_order != b.c_tag_order)
				if(a.c_tag_order > b.c_tag_order)
					L.Swap(j, j + 1)
			else
				if(sorttext(a.c_tag, b.c_tag) < 0)
					L.Swap(j, j + 1)
	return L
