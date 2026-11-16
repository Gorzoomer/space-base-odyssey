--!strict
-- Space Base Odyssey - every sound in the game (Stage 11: sound and music): name -> Roblox audio asset.
-- SI disclosure: generated with AI assistance (Claude, Anthropic) and reviewed by the team.
-- Pure data (no Roblox APIs), so it also loads in Lune. src/client/Audio.luau plays these.
-- All 50 assets were uploaded by the team (creator user 4714729983) from promo/audio/manifest.json.
-- Licences: the music and most effects are original audio synthesized in code by the team. Five
-- effects mix in edited CC0 1.0 (public domain) recordings from Freesound, found through Openverse;
-- they need no credit, but THIRD_PARTY_NOTICES.md lists them and the Credits screen mentions them.
-- No sound is CC BY, so no attribution is required.
-- Fields:
--   group   "Music" (SoundService.SBO_Music, the Music slider) or "Effects" (SoundService.SBO_SFX,
--           the Effects slider). Both groups are created by Settings.luau; Audio.luau reuses them.
--   loop    the file loops seamlessly.
--   volume  default Sound.Volume (the sliders scale the whole group on top of this).
--   seconds length of the file (stings duck the music this long).
--   world   a sound from the world outside the helmet. Science: there is no sound in the vacuum of
--           space, so outside these are heard only as vibration through the suit and boots: Audio.luau
--           plays them through a muffled sub-group while the player is outside (SBO_Inside false).
--           Sounds without `world` come from the helmet radio, the tablet or C.A.R.L. (always clear).
--   jitter  random pitch change (+-) for sounds that repeat, so they do not sound robotic.
--   cooldown seconds before the same one-shot may play again.
-- Asset pet_happy (135675575026545) was still in Roblox moderation ("Reviewing") on 16 Nov 2026; it
-- stays silent until Roblox approves it.

export type Group = "Music" | "Effects"
export type Entry = {
	id: string,
	group: Group,
	loop: boolean,
	volume: number,
	seconds: number,
	world: boolean,
	jitter: number,
	cooldown: number,
}

type Options = {
	loop: boolean,
	volume: number,
	seconds: number,
	world: boolean?,
	jitter: number?,
	cooldown: number?,
}

local function sound(id: string, group: Group, options: Options): Entry
	return table.freeze({
		id = id,
		group = group,
		loop = options.loop,
		volume = options.volume,
		seconds = options.seconds,
		world = options.world == true,
		jitter = options.jitter or 0,
		cooldown = options.cooldown or 0,
	})
end

local AudioIds: { [string]: Entry } = {
	music_menu = sound("rbxassetid://80610181106342", "Music", { loop = true, volume = 0.45, seconds = 106.67 }),
	music_base_day = sound("rbxassetid://72851766202728", "Music", { loop = true, volume = 0.4, seconds = 85.33 }),
	music_base_build = sound("rbxassetid://91085655712630", "Music", { loop = true, volume = 0.42, seconds = 85.71 }),
	music_storm = sound("rbxassetid://91896079085887", "Music", { loop = true, volume = 0.42, seconds = 73.85 }),
	music_mission = sound("rbxassetid://134707162251835", "Music", { loop = true, volume = 0.42, seconds = 80.0 }),
	music_night_eclipse = sound("rbxassetid://81054933823491", "Music", { loop = true, volume = 0.4, seconds = 87.27 }),
	sting_victory = sound("rbxassetid://73868438488889", "Music", { loop = false, volume = 0.6, seconds = 3.8 }),
	sting_level_up = sound("rbxassetid://102058390697794", "Music", { loop = false, volume = 0.55, seconds = 2.0 }),
	sting_mission_fail = sound("rbxassetid://86491719263461", "Music", { loop = false, volume = 0.5, seconds = 2.9 }),
	ui_click = sound("rbxassetid://94502078824273", "Effects", { loop = false, volume = 0.35, seconds = 0.09, jitter = 0.04, cooldown = 0.05 }),
	ui_open = sound("rbxassetid://92951506398476", "Effects", { loop = false, volume = 0.4, seconds = 0.32, jitter = 0.02, cooldown = 0.1 }),
	ui_close = sound("rbxassetid://99037348265611", "Effects", { loop = false, volume = 0.38, seconds = 0.3, jitter = 0.02, cooldown = 0.1 }),
	ui_error = sound("rbxassetid://73300231826444", "Effects", { loop = false, volume = 0.45, seconds = 0.42, cooldown = 0.3 }),
	toast_pop = sound("rbxassetid://118715452235115", "Effects", { loop = false, volume = 0.45, seconds = 0.45, jitter = 0.03, cooldown = 0.2 }),
	coin_single = sound("rbxassetid://118711466950140", "Effects", { loop = false, volume = 0.45, seconds = 0.45, jitter = 0.06, cooldown = 0.08 }),
	coin_burst = sound("rbxassetid://78527452195373", "Effects", { loop = false, volume = 0.5, seconds = 1.1, jitter = 0.03, cooldown = 0.3 }),
	xp_gain = sound("rbxassetid://96019982246237", "Effects", { loop = false, volume = 0.4, seconds = 0.8, jitter = 0.04, cooldown = 0.25 }),
	level_up = sound("rbxassetid://105836658771230", "Effects", { loop = false, volume = 0.55, seconds = 1.4, cooldown = 0.5 }),
	achievement_unlock = sound("rbxassetid://103416388488229", "Effects", { loop = false, volume = 0.55, seconds = 1.8, cooldown = 0.5 }),
	quest_complete = sound("rbxassetid://84495928895991", "Effects", { loop = false, volume = 0.55, seconds = 1.3, cooldown = 0.5 }),
	quest_new = sound("rbxassetid://135797306718982", "Effects", { loop = false, volume = 0.45, seconds = 0.9, cooldown = 0.4 }),
	build_step = sound("rbxassetid://121420837876984", "Effects", { loop = false, volume = 0.55, seconds = 0.55, world = true, jitter = 0.06, cooldown = 0.2 }), -- mixes CC0 1.0 clips: "Ratchet Wrench Fast Multiple" by Rudmer_Rotteveel, "Wrench Clanking" by magnuswaker
	build_complete = sound("rbxassetid://86193833531970", "Effects", { loop = false, volume = 0.6, seconds = 1.6, world = true, cooldown = 0.5 }),
	crate_pickup = sound("rbxassetid://87972721666198", "Effects", { loop = false, volume = 0.5, seconds = 0.45, world = true, jitter = 0.05, cooldown = 0.2 }),
	crate_drop = sound("rbxassetid://83479705088087", "Effects", { loop = false, volume = 0.55, seconds = 0.6, world = true, jitter = 0.05, cooldown = 0.2 }), -- mixes a CC0 1.0 clip: "Heavy Metal Thud on Ground" by 7of9Designs
	ice_pickup = sound("rbxassetid://107371873892390", "Effects", { loop = false, volume = 0.5, seconds = 0.6, world = true, jitter = 0.06, cooldown = 0.2 }),
	ice_deliver = sound("rbxassetid://121898755095486", "Effects", { loop = false, volume = 0.5, seconds = 0.95, world = true, jitter = 0.04, cooldown = 0.2 }),
	silo_claim = sound("rbxassetid://136983010974080", "Effects", { loop = false, volume = 0.55, seconds = 1.0, world = true, cooldown = 0.5 }),
	drill_loop = sound("rbxassetid://77042837887174", "Effects", { loop = true, volume = 0.6, seconds = 4.0, world = true }),
	conveyor_loop = sound("rbxassetid://95400085985309", "Effects", { loop = true, volume = 0.5, seconds = 2.0, world = true }),
	cargo_robot_beep = sound("rbxassetid://89649811705251", "Effects", { loop = false, volume = 0.55, seconds = 0.55, world = true, jitter = 0.05, cooldown = 1.0 }),
	storm_alarm = sound("rbxassetid://105794532784346", "Effects", { loop = false, volume = 0.5, seconds = 2.0, cooldown = 1.0 }),
	storm_particles_loop = sound("rbxassetid://81363926020164", "Effects", { loop = true, volume = 0.3, seconds = 6.0 }),
	shelter_enter = sound("rbxassetid://135309787543335", "Effects", { loop = false, volume = 0.55, seconds = 2.0, cooldown = 2.0 }), -- mixes a CC0 1.0 clip: "Heavy Metal Thud on Ground" by 7of9Designs
	suit_low_air = sound("rbxassetid://111919893513122", "Effects", { loop = false, volume = 0.5, seconds = 1.3, cooldown = 3.0 }),
	suit_refill = sound("rbxassetid://84926421258294", "Effects", { loop = false, volume = 0.5, seconds = 1.6, cooldown = 2.0 }),
	jetpack_loop = sound("rbxassetid://80324989896569", "Effects", { loop = true, volume = 0.45, seconds = 3.0, world = true }),
	boots_puff = sound("rbxassetid://73465562494750", "Effects", { loop = false, volume = 0.5, seconds = 0.3, world = true, jitter = 0.08, cooldown = 0.1 }),
	buggy_engine_loop = sound("rbxassetid://95487515643013", "Effects", { loop = true, volume = 0.45, seconds = 2.0, world = true }),
	buggy_horn = sound("rbxassetid://116132555765233", "Effects", { loop = false, volume = 0.5, seconds = 0.65, world = true, cooldown = 1.0 }),
	carl_beep = sound("rbxassetid://130616067125768", "Effects", { loop = false, volume = 0.35, seconds = 0.55, jitter = 0.06, cooldown = 1.5 }),
	carl_hop = sound("rbxassetid://105392385737683", "Effects", { loop = false, volume = 0.35, seconds = 0.45, world = true, jitter = 0.08, cooldown = 0.5 }),
	meteor_whoosh = sound("rbxassetid://105554710043546", "Effects", { loop = false, volume = 0.45, seconds = 1.4, cooldown = 1.0 }),
	meteor_impact = sound("rbxassetid://103953916577920", "Effects", { loop = false, volume = 0.7, seconds = 1.8, world = true, jitter = 0.05, cooldown = 1.0 }), -- mixes a CC0 1.0 clip: "Heavy Metal Thud on Ground" by 7of9Designs
	scan_tablet = sound("rbxassetid://92773878825038", "Effects", { loop = false, volume = 0.5, seconds = 1.1, cooldown = 0.5 }),
	eclipse_swell = sound("rbxassetid://94609548992352", "Effects", { loop = false, volume = 0.5, seconds = 3.6, cooldown = 10.0 }),
	footstep_inside = sound("rbxassetid://124874584439978", "Effects", { loop = false, volume = 0.3, seconds = 0.33, jitter = 0.1, cooldown = 0.15 }), -- mixes a CC0 1.0 clip: "Footsteps Metallic Muffled.wav" by RutgerMuller
	panel_clean = sound("rbxassetid://109457445676949", "Effects", { loop = false, volume = 0.5, seconds = 0.5, world = true, jitter = 0.05, cooldown = 0.3 }),
	antenna_lock = sound("rbxassetid://84499625228416", "Effects", { loop = false, volume = 0.5, seconds = 1.0, cooldown = 0.5 }),
	pet_happy = sound("rbxassetid://135675575026545", "Effects", { loop = false, volume = 0.45, seconds = 0.7, world = true, jitter = 0.05, cooldown = 1.0 }),
}

return table.freeze(AudioIds)
