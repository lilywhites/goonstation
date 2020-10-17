/datum/game_mode/pod_war
	name = "pod war"

	votable = 1
	probability = 0 // Overridden by the server config. If you don't have access to that repo, keep it 0.
	crew_shortage_enabled = 1

	shuttle_available = 0 // 0: Won't dock. | 1: Normal. | 2: Won't dock if called too early.
	list/latejoin_antag_roles = list() // Unrecognized roles default to traitor in mob/new_player/proc/makebad().
	do_antag_random_spawns = 0

	var/list/commanders = list()

	var/datum/pod_war_team/team1
	var/datum/pod_war_team/team2



/datum/game_mode/pod_war/announce()
	boutput(world, "<B>The current game mode is - Pod War!</B>")
	boutput(world, "<B>Two starships of similar technology and crew compliment warped into the same asteroid field!</B>")
	boutput(world, "<B>Mine materials, build pods, kill enemies, destroy the enemy mothership!</B>")

//setup teams and commanders
/datum/game_mode/pod_war/pre_setup()
	if (!select_commanders())
		return 0
	if (!setup_teams())
		return 0


	return 1



/datum/game_mode/pod_war/proc/setup_teams()
	if (!islist(commanders) || commanders.len != 2)
		return 0
	team1 = new/datum/pod_war_team(mode = src, team = 1, commander = commanders[1])
	team2 = new/datum/pod_war_team(mode = src, team = 2, commander = commanders[2])

	//get all ready players and split em into two equal teams, 
	var/list/readied_minds = list()
	for(var/client/C)
		var/mob/new_player/player = C.mob
		if (!istype(player)) continue
		if (player.ready && player.mind)
			readied_minds += player.mind

	if (islist(readied_minds))
		var/length = length(readied_minds)
		shuffle_list(readied_minds)
		if (length < 2)
			if (prob(50))
				team1.accept_players(readied_minds)
			else
				team2.accept_players(readied_minds)

		else
			var/half = round(length/2)
			team1.accept_players(readied_minds.Copy(1, half))
			team2.accept_players(readied_minds.Copy(half+1, length))

		


/datum/game_mode/pod_war/proc/select_commanders()
	var/list/possible_commanders = get_possible_commanders()
	if (isnull(possible_commanders) || !possible_commanders.len)
		return 0

	//randomly pick 2 commanders from the list. make em a commander if they aren't in the list. 
	var/count = possible_commanders.len
	var/datum/mind/commander = null
	while (count > 0)
		commander = pick(possible_commanders)
		if (istype(commander) && !(commander in commanders))
			commander.special_role = "commander"
			possible_commanders.Remove(commander)
			commanders += commander

		if (length(commanders) >= 2)
			break
		count --

//Really stolen from gang, But this basically just picks everyone who is ready and not hellbanned or jobbanned from Command or Captain
/datum/game_mode/pod_war/proc/get_possible_commanders()
	var/list/candidates = list()
	for(var/client/C)
		var/mob/new_player/M = C.mob
		if (!istype(M)) continue
		if (ishellbanned(M)) continue
		if(jobban_isbanned(M, "Captain")) continue //If you can't captain a Space Station, you probably can't command a starship either...
		if ((M.ready) && !(M.mind in commanders) && !candidates.Find(M.mind))
			candidates += M.mind

	if(candidates.len < 1)
		return null
	else
		return candidates


/datum/game_mode/pod_war/post_setup()
	for (var/datum/mind/leaderMind in commanders)
		if (!leaderMind.current)
			continue

		create_team(leaderMind)
		bestow_objective(leaderMind,/datum/objective/specialist/pod_war)
		boutput(leaderMind.current, "<h1><font color=red>You are the Commander of your starship! Organize your crew fight for survival!</font></h1>")
		equip_commander(leaderMind.current)

	//Create teams
	//Setup critical systems for each starship.

	return 1

//Give em their special jacket. and their visible hud icon
/datum/game_mode/gang/proc/equip_commander(mob/living/carbon/human/leader)
	if(leader.ears != null && istype(leader.ears,/obj/item/device/radio/headset))
		var/obj/item/device/radio/headset/H = leader.ears
		// H.set_secure_frequency("g",leader.mind.gang.comms_frequency)
		// H.secure_classes["g"] = RADIOCL_SYNDICATE
		boutput(leader, "Your headset has been tuned to your crew's frequency. Prefix a message with :g to communicate on this channel.")

	return

/datum/game_mode/pod_war/check_finished()
	if(emergency_shuttle.location == SHUTTLE_LOC_RETURNED)
		return 1

	var/leadercount = 0
	for (var/datum/mind/L in ticker.mode:commanders)
		leadercount++

	if(leadercount <= 1 && ticker.round_elapsed_ticks > 12000 && !emergency_shuttle.online)
		force_shuttle()

	else return 0

/datum/game_mode/pod_war/process()
	..()

/datum/game_mode/pod_war/declare_completion()

	var/text = ""

	boutput(world, "<FONT size = 2><B>The ship commanders were: </B></FONT><br>")
	// for(var/datum/mind/leader_mind in commanders)

	..() // Admin-assigned antagonists or whatever.



/datum/pod_war_team
	var/name = "North Crew"
	var/comms_frequency = 0
	var/area/base = null		//base ship area
	var/datum/mind/commander = null
	var/list/members = list()
	var/team_num = 0

	New(var/datum/game_mode/pod_war/mode, team, var/datum/mind/commander)
		src.team_num = team
		src.commander = commander

		if (team_num == 2)
			name = "South Crew"

		set_comms(mode)

		set_members(mode)




		//stolen from gang, works well enough, I don't care to make better. - kyle
	proc/set_comms(var/datum/game_mode/pod_war/mode)
		comms_frequency = rand(1360,1420)

		while(comms_frequency in mode.frequencies_used)
			comms_frequency = rand(1360,1420)

		mode.frequencies_used += comms_frequency


	proc/accept_players(var/list/players)
		members = players
		for (var/datum/mind/M in players)
			equip_player(M)

	proc/equip_player(var/datum/mind/mind)
			