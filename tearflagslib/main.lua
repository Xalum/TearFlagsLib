TearFlagsLib = TearFlagsLib or RegisterMod("Tear Flags Library", 1)
local build = 100
local version = "1.1"
local localHolder = {}

if TearFlagsLib.Release then
	if TearFlagsLib.Release < build then
		localHolder.flags = TearFlagsLib.Flag			-- Remember registered flags
		localHolder.flagsN = TearFlagsLib.IndexedFlags	-- Remember how many flags there are
		localHolder.callback = TearFlagsLib.Callback	-- Remember old callback ids
		localHolder.weapons = TearFlagsLib.WeaponFlag 	-- Remember old weapon ids
		localHolder.key = TearFlagsLib.DataKey			-- Keep consistent just in case

		localHolder.mimics = TearFlagsLib.playerMimickingFamiliarMap
		localHolder.mimics2 = TearFlagsLib.playerMimickingEffectMap
		localHolder.weaponIdentity = TearFlagsLib.WeaponIdentityFunctions

		-- I wouldn't expect to really need to do this if it weren't for the fact that people will probably put their weapons in these, let their mod get outdated, and then complain that their weapon is applying splitshots
		localHolder.tearWeapons = TearFlagsLib.TEAR_VARIANT_WEAPON_FLAGS
		localHolder.laserWeapons = TearFlagsLib.LASER_VARIANT_WEAPON_FLAGS
		localHolder.epicFetusWeapons = TearFlagsLib.EPIC_FETUS_VARIANT_WEAPON_FLAGS
		localHolder.noColorWeapons = TearFlagsLib.NO_COLOR_WEAPON_FLAGS
		localHolder.noSplitshotsWeapons = TearFlagsLib.NO_SPLITSHOT_WEAPON_FLAGS

		TearFlagsLib.UnregisterCallbacks()
		TearFlagsLib.Updated = true
	else
		if #Isaac.GetCallbacks(TearFlagsLib.Callback.__META_RELOADDETECTOR) == 0 then
			TearFlagsLib.UnregisterCallbacks() -- Just in case
			TearFlagsLib.RegisterCallbacks()
		end

		return
	end
end

local function bitSet128FromIndex(x)
	return x >= 64 and BitSet128(0,1<<(x-64)) or BitSet128(1<<x,0)
end

local sfx = SFXManager()
local mod = TearFlagsLib
mod.Release = build
mod.Source = "tearflagslib"									-- !!!!!!!! If you embed this into your own mod, remember to set this variable
mod.DataKey = localHolder.key or {}
mod.BitSetZero = BitSet128(0, 0)
mod.BitSetOne = BitSet128(-1, -1)
mod.GuarenteedFlagTracker = bitSet128FromIndex(TearFlags.TEAR_EFFECT_COUNT + 1)

mod.AntiRecursion = false
mod.IsPollingForTearFlags = false

mod.Flag = localHolder.flags or {}
mod.IndexedFlags = localHolder.flagsN or 0
mod.playerMimickingFamiliarMap = localHolder.mimics
mod.playerMimickingEffectMap = localHolder.mimics2
mod.UpdateLists = {}
mod.RecursionBlockers = {Count = 0, NextIndex = 0}

include(mod.Source .. ".bitset_infinity")
if mod.Updated then
	mod.UpdateBitSetInfinity(mod.Flag)
	mod.UpdateBitSetInfinity(localHolder.weapons)
end

mod.Callback = {
	-- Best-practice callbacks, these are the intended way to apply and respond to TearFlags
	POLL_TEARFLAGS = {},					-- {entity, player, weaponFlag} -- Takes an optional WeaponFlag argument
	POLL_CHANCELESS_TEARFLAGS = {},			-- Called by certain Lasers which do not roll for random-chance effects like Common Cold, but gain guarenteed effects like Scorpio {entity, player, weaponFlag}
	POLL_LOCUST_TEARFLAGS = {},				-- Takes an optional CollectibleType argument. Locusts should only recieve TearFlags applied by the item sacrificed to make them. {entity, player}
	APPLY_TEARFLAG_EFFECT = {},				-- Called for each enemy hit by something that applies a given TearFlag	{entity, player, source, weaponFlag, flagParams} -- Takes a recommended TearFlag argument
	APPLY_EXPLOSION_TEARFLAG_EFFECT = {},	-- Called for each explosion summoned by a weapon with a given TearFlag	{explosion, player, explosionSource, weaponFlag, flagParams} -- Takes a recommended TearFlag argument
	POST_FIRE_VASCULITIS_TEAR = {},			-- Called for each Vasculitis tear. When an enemy with a Status Effect dies, Vasculitis tears gain the TearFlag that applies it. Do not use for general TearFlag application {tear, enemy}

	-- Flag management callbacks, these should be used to ensure the presence and integrity of data related to TearFlags stored on an entity
	PRE_ADD_TEARFLAG = {},					-- Called before a TearFlag is applied to an entity {entity, player, fromPolling, weaponFlag, tearFlag} Takes an optional TearFlag argument
	POST_ADD_TEARFLAG = {},					-- Called after a TearFlag is added to an entity {entity, player, fromPolling, weaponFlag, tearFlag} Takes an optional TearFlag argument
	POST_COPY_TEARFLAGS = {},				-- Called when custom TearFlags are copied. (e.g. Club Swings passing flags to Thrown Clubs, or Splitshot tears from (e.g.) Parasite) {recipient, donor, recipientWeaponFlag}
	PRE_REMOVE_TEARFLAG = {},				-- Called before custom TearFlags are removed, return true to prevent. {entity, player, tearFlag} Takes an optional TearFlag argument
	POST_REMOVE_TEARFLAG = {},				-- Called when custom TearFlags are removed. {entity, player, tearFlag} Takes an optional TearFlag argument
	POST_CLEAR_LUDOVICO_FLAGS = {},			-- Called specifically when TearFlags are periodically removed by Ludovico Tears and Knives to reroll their TearFlags, this is called alongside PRE/POST_REMOVE_TEARFLAG. {entity, player, weaponFlag, oldTearFlags}

	PRE_POLL_TEARFLAGS = {},				-- Called prior to tearflags being polled, return true to prevent flags from being polled {entity, player, weaponFlag} -- Takes an optional WeaponFlag argument
	POST_POLL_TEARFLAGS = {},				-- Called after tearflags have been polled, allowing you to respond to any and all changes {entity, player, weaponFlag} -- Takes an optional WeaponFlag argument			
	PRE_APPLY_TEARFLAG_EFFECTS = {},		-- Called before any tearflag effects get applied to an entity. Return `true` to prevent all tear flag effects from being applied {entity, player, source, weaponFlag, bonusArg} -- Takes an optional EntityType argument
	POST_APPLY_TEARFLAG_EFFECTS = {},		-- Called after every tearflag effect has been resolved on an entity {entity, player, source, weaponFlag, bonusArg} -- Takes an optional EntityType argument

	-- More specific callbacks for handling more complicated effects, these callbacks generally shouldn't be used to add TearFlags
	POST_REAL_FIRE_TEAR = {},
	POST_THROW_KNIFE = {},
	POST_CATCH_KNIFE = {},
	PRE_SWING_CLUB = {},
	POST_THROW_CLUB = {}, -- Never apply TearFlags using this callback, thrown clubs maintain their flags from their previous swing
	POST_CATCH_CLUB = {},
	UPDATE_ENTITY_LIST = {},				-- Called once per update for each entity in an UpdateList {entity, listKey}. Takes an optional listKey argument

	-- This callback should NEVER be registered by other mods, it is exclusively for maintaining TearFlagsLib's functionality over luamod-ing
	__META_RELOADDETECTOR = {},
}

-- b contains the flag a or either a/b is nil
local function paramsTestFlagMatch(a, b)
	return not a or not b or b & a == a
end

-- Callbacks that take BitSetInfinity values as optional arguments
for _, callback in pairs({
	mod.Callback.POLL_TEARFLAGS,
	mod.Callback.POLL_CHANCELESS_TEARFLAGS,

	mod.Callback.PRE_ADD_TEARFLAG,
	mod.Callback.POST_ADD_TEARFLAG,
	mod.Callback.POST_COPY_TEARFLAGS,
	mod.Callback.PRE_REMOVE_TEARFLAG,
	mod.Callback.POST_REMOVE_TEARFLAG,

	mod.Callback.PRE_POLL_TEARFLAGS,
	mod.Callback.POST_POLL_TEARFLAGS,
}) do
	setmetatable(Isaac.GetCallbacks(callback, true), {
		__matchParams = paramsTestFlagMatch
	})
end

-- Any pre-existing callbacks should maintain their old callback address when a newer version is loaded
-- This makes sure mods that regsiter callbacks on these old addresses still get their code run
if localHolder.callback then
	for key, callbackAddress in pairs(localHolder.callback) do
		mod.Callback[key] = callbackAddress
	end
end

mod.WeaponFlag = localHolder.weapons or {
	NUM_FLAGS = 0
}

mod.WeaponIdentityFunctions = localHolder.weaponIdentity or {}

-- Provides a more efficient, cached wrapper for GetData.
include(mod.Source .. ".getdatacache")

function mod.GetSafeData(entity)
	local data = GetDataCache.GetEntityData(entity)
	data[mod.DataKey] = data[mod.DataKey] or {
		checkedFlags = false,
		tearFlags = mod.BitSetInfinity.Zero,
		vanillaFlags = mod.BitSetZero,
		entityBlacklist = {General = {}},
		copyBlacklist = {},
		customParams = {},
		vanillaParams = {
			auto = false,
			homingStrength = 1,
		},
		pseudoLudo = {
			canReset = false,
			frequency = nil,
		},
	}

	return data[mod.DataKey]
end

function mod.SetAntiRecursion()
	local key = "RECURSOR" .. mod.RecursionBlockers.NextIndex
	mod.RecursionBlockers[key] = true
	mod.RecursionBlockers.Count = mod.RecursionBlockers.Count + 1
	mod.RecursionBlockers.NextIndex = mod.RecursionBlockers.NextIndex + 1
	mod.AntiRecursion = true
	return key
end

function mod.ClearAntiRecursion(key)
	if not mod.RecursionBlockers[key] then return false end
	mod.RecursionBlockers[key] = nil
	mod.RecursionBlockers.Count = math.max(0, mod.RecursionBlockers.Count)
	mod.AntiRecursion = mod.RecursionBlockers.Count == 0
end

local function getValidatedCustomParams(data, key)
	data.customParams[key] = data.customParams[key] or {}
	return data.customParams[key]
end

function mod.RegisterTearFlag(flagKey) -- Called either as RegisterTearFlag("NAME") or RegisterTearFlag({"NAME1", "NAME2", "NAME3"})
	if type(flagKey) == "table" then
		local indexes = {}
		for _, flag in pairs(flagKey) do
			table.insert(indexes, mod.RegisterTearFlag(flag))
		end

		return table.unpack(indexes)
	elseif type(flagKey) == "string" then
		if mod.Flag[flagKey] then return mod.Flag[flagKey] end

		mod.Flag[flagKey] = mod.BitSetInfinity.FromIndex(mod.IndexedFlags)
		mod.IndexedFlags = mod.IndexedFlags + 1

		return mod.Flag[flagKey]
	end
end

function mod.RegisterWeapon(weaponKey) -- Called either as RegisterWeapon("NAME") or RegisterWeapon({"NAME1", "NAME2", "NAME3"})
	if type(weaponKey) == "table" then
		local indexes = {}
		for _, flag in pairs(weaponKey) do
			table.insert(indexes, mod.RegisterWeapon(flag))
		end

		return table.unpack(indexes)
	elseif type(weaponKey) == "string" then
		if mod.WeaponFlag[weaponKey] then return mod.WeaponFlag[weaponKey] end
		
		mod.WeaponFlag[weaponKey] = mod.BitSetInfinity.FromIndex(mod.WeaponFlag.NUM_FLAGS)
		mod.WeaponFlag.NUM_FLAGS = mod.WeaponFlag.NUM_FLAGS + 1


		return mod.WeaponFlag[weaponKey]
	end	
end

mod.RegisterWeapon({"TEAR", "LASER", "KNIFE", "CLUB", "AQUARIUS", "DARK_ARTS", "DR_FETUS", "EPIC_FETUS", "LOCUST", "UMBILICAL_WHIP", "BRIMSTONE_BALL", "ANTI_GRAV_LASER", "SWORD", "OCULAR_RIFT", "HEMOPTYSIS", "CLUB_EPIC_FETUS"})
mod.RegisterWeapon({"LUDOVICO_TEAR", "BOBS_ROTTEN_HEAD", "SHARP_KEY"}) -- Tear Semi-Weapons. These WeaponTypes are only used in *some* callbacks, where they may be expected to behave differently than their "true" WeaponType
mod.TEAR_VARIANT_WEAPON_FLAGS = mod.WeaponFlag.TEAR | mod.WeaponFlag.LUDOVICO_TEAR | mod.WeaponFlag.BOBS_ROTTEN_HEAD | mod.WeaponFlag.SHARP_KEY
mod.LASER_VARIANT_WEAPON_FLAGS = mod.WeaponFlag.LASER | mod.WeaponFlag.ANTI_GRAV_LASER | mod.WeaponFlag.BRIMSTONE_BALL
mod.EPIC_FETUS_VARIANT_WEAPON_FLAGS = mod.WeaponFlag.EPIC_FETUS | mod.WeaponFlag.CLUB_EPIC_FETUS
mod.NO_SPLITSHOT_WEAPON_FLAGS = mod.WeaponFlag.AQUARIUS | mod.WeaponFlag.DARK_ARTS | mod.WeaponFlag.EPIC_FETUS | mod.WeaponFlag.UMBILICAL_WHIP | mod.WeaponFlag.BRIMSTONE_BALL | mod.WeaponFlag.ANTI_GRAV_LASER | mod.WeaponFlag.SWORD | mod.WeaponFlag.OCULAR_RIFT | mod.WeaponFlag.HEMOPTYSIS | mod.WeaponFlag.CLUB_EPIC_FETUS
mod.NO_COLOR_WEAPON_FLAGS = mod.WeaponFlag.LASER | mod.WeaponFlag.ANTI_GRAV_LASER | mod.WeaponFlag.KNIFE | mod.WeaponFlag.DARK_ARTS | mod.WeaponFlag.LOCUST | mod.WeaponFlag.UMBILICAL_WHIP | mod.WeaponFlag.BRIMSTONE_BALL | mod.WeaponFlag.BOBS_ROTTEN_HEAD | mod.WeaponFlag.SHARP_KEY | mod.WeaponFlag.OCULAR_RIFT | mod.WeaponFlag.HEMOPTYSIS | mod.WeaponFlag.AQUARIUS | mod.WeaponFlag.EPIC_FETUS | mod.WeaponFlag.CLUB_EPIC_FETUS
mod.VANILLA_WEAPON_FLAGS = mod.WeaponFlag.TEAR | mod.WeaponFlag.LASER | mod.WeaponFlag.KNIFE | mod.WeaponFlag.CLUB | mod.WeaponFlag.AQUARIUS | mod.WeaponFlag.DARK_ARTS | mod.WeaponFlag.DR_FETUS | mod.WeaponFlag.EPIC_FETUS | mod.WeaponFlag.LOCUST | mod.WeaponFlag.UMBILICAL_WHIP | mod.WeaponFlag.BRIMSTONE_BALL | mod.WeaponFlag.ANTI_GRAV_LASER | mod.WeaponFlag.SWORD | mod.WeaponFlag.OCULAR_RIFT | mod.WeaponFlag.HEMOPTYSIS | mod.WeaponFlag.CLUB_EPIC_FETUS | mod.WeaponFlag.SHARP_KEY | mod.WeaponFlag.BOBS_ROTTEN_HEAD

if localHolder.tearWeapons then mod.TEAR_VARIANT_WEAPON_FLAGS = mod.TEAR_VARIANT_WEAPON_FLAGS | localHolder.tearWeapons end
if localHolder.laserWeapons then mod.LASER_VARIANT_WEAPON_FLAGS = mod.LASER_VARIANT_WEAPON_FLAGS | localHolder.laserWeapons end
if localHolder.epicFetusWeapons then mod.EPIC_FETUS_VARIANT_WEAPON_FLAGS = mod.EPIC_FETUS_VARIANT_WEAPON_FLAGS | localHolder.epicFetusWeapons end
if localHolder.noColorWeapons then mod.NO_COLOR_WEAPON_FLAGS = mod.NO_COLOR_WEAPON_FLAGS | localHolder.noColorWeapons end
if localHolder.noSplitshotsWeapons then mod.NO_SPLITSHOT_WEAPON_FLAGS = mod.NO_SPLITSHOT_WEAPON_FLAGS | localHolder.noSplitshotsWeapons end

function mod.IsWeaponTearVariant(flag)
	return mod.TEAR_VARIANT_WEAPON_FLAGS:HasFlags(flag)
end

function mod.IsWeaponLaserVariant(flag)
	return mod.LASER_VARIANT_WEAPON_FLAGS:HasFlags(flag)
end

function mod.IsWeaponEpicFetusVariant(flag)
	return mod.EPIC_FETUS_VARIANT_WEAPON_FLAGS:HasFlags(flag)
end

function mod.DoesWeaponBlockSplitshots(flag) -- Don't treat this as gospel, there is a line somewhere between an effect that spawns tears, and a true split-shot. Idk where that line is though. That's your choice.
	return mod.NO_SPLITSHOT_WEAPON_FLAGS:HasFlags(flag)
end

function mod.ShouldWeaponGainEntityColor(flag) -- By default this returns false for everything except TEAR, LUDOVICO_TEAR, CLUB, and DR_FETUS
	return not mod.NO_COLOR_WEAPON_FLAGS:HasFlags(flag)
end

function mod.IsVanillaWeapon(flag)
	return mod.VANILLA_WEAPON_FLAGS:HasFlags(flag)
end

function mod.IsModdedWeapon(flag)
	return not mod.VANILLA_WEAPON_FLAGS:HasFlags(flag)
end

function mod.IsTearSplitTear(entity)
	return mod.GetSafeData(entity).isSplitTear
end

function mod.RegisterWeaponIdentityFunction(weaponFlag, func)
	mod.WeaponIdentityFunctions[weaponFlag] = func
end

function mod.RegisterPlayerMimicFamiliar(familiarVariant)
	if type(familiarVariant) == "table" then
		for _, variant in pairs(familiarVariant) do
			mod.playerMimickingFamiliarMap[variant] = true
		end
	elseif type(familiarVariant) == "number" then
		mod.playerMimickingFamiliarMap[familiarVariant] = true 
	end
end

function mod.RegisterPlayerMimicEffect(effectVariant)
	if type(effectVariant) == "table" then
		for _, variant in pairs(effectVariant) do
			mod.playerMimickingEffectMap[variant] = true
		end
	elseif type(effectVariant) == "number" then
		mod.playerMimickingEffectMap[effectVariant] = true 
	end
end

function mod.AddTearFlags(entity, flags, force)
	local data = mod.GetSafeData(entity)
	local player = mod.GetTearPlayer(entity)

	flags:ForEach(function(flag)
		local skipAdd = false

		if not force then
			for _, callbackData in pairs(Isaac.GetCallbacks(mod.Callback.PRE_ADD_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					if callbackData.Function(callbackData.Mod, entity, player, not not mod.IsPollingForTearFlags, mod.IsPollingForTearFlags, flag) then 
						skipAdd = true 
						break
					end
				end
			end
		end

		if not skipAdd then
			flag:EqualiseLength(data.tearFlags)
			data.tearFlags = data.tearFlags | flag
			
			for _, callbackData in pairs(Isaac.GetCallbacks(mod.Callback.POST_ADD_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					callbackData.Function(callbackData.Mod, entity, player, not not mod.IsPollingForTearFlags, mod.IsPollingForTearFlags, flag)
				end
			end
		end
	end)
end

function mod.GetTearFlags(entity)
	return mod.GetSafeData(entity).tearFlags:Clone()
end

function mod.HasTearFlags(entity, flags)
	local data = mod.GetSafeData(entity)
	return data.tearFlags & flags == flags
end

function mod.HasAnyTearFlags(entity)
	local data = mod.GetSafeData(entity)
	return data.tearFlags ~= mod.BitSetInfinity.Zero
end

function mod.ClearTearFlags(entity, flags, force)
	local data = mod.GetSafeData(entity)
	flags = flags & data.tearFlags -- Data validation for the callback
	
	flags:ForEach(function(flag)
		local player = mod.GetTearPlayer(entity)
		local canRemove = true

		if not force then
			for _, callbackData in pairs(Isaac.GetCallbacks(mod.Callback.PRE_REMOVE_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					if callbackData.Function(callbackData.Mod, entity, player, flag) then 
						canRemove = false 
						break
					end
				end
			end
		end
		
		if canRemove then
			flag:EqualiseLength(data.tearFlags)
			data.tearFlags = data.tearFlags &~ flag

			local params = mod.GetTearFlagParams(entity, flag)
			if not params.KeepParamsOnFlagRemove then
				mod.ClearTearFlagParams(entity, flag)
			end

			for _, callbackData in pairs(Isaac.GetCallbacks(mod.Callback.POST_REMOVE_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					callbackData.Function(callbackData.Mod, entity, player, flag)
				end
			end
		end
	end)
end

function mod.WipeTearFlags(entity, force)
	mod.ClearTearFlags(entity, mod.GetTearFlags(entity), force)
end

function mod.SetTearFlagParams(entity, flag, newParams, override)
	if flag then
		local params = getValidatedCustomParams(mod.GetSafeData(entity), tostring(flag:GetFirstIndex()))
		if override then
			params = newParams
		else
			mod.FuzzyReplaceTable(params, newParams)
		end
	else
		if override then
			mod.GetSafeData(entity).customParams = newParams
		else
			mod.FuzzyReplaceTable(mod.GetSafeData(entity).customParams, newParams)
		end
	end
end

function mod.GetTearFlagParams(entity, flag)
	if flag then
		return mod.CopyTable(getValidatedCustomParams(mod.GetSafeData(entity), tostring(flag:GetFirstIndex())))
	else
		return mod.CopyTable(mod.GetSafeData(entity).customParams)
	end
end

function mod.ClearTearFlagParams(entity, flag)
	mod.GetSafeData(entity).customParams[tostring(flag:GetFirstIndex())] = {}
end

function mod.AddCustomVanillaTearFlags(entity, flags)
	local data = mod.GetSafeData(entity)
	data.vanillaFlags = data.vanillaFlags | flags
end

function mod.GetCustomVanillaTearFlags(entity)
	return mod.GetSafeData(entity).vanillaFlags
end

function mod.HasCustomVanillaTearFlags(entity, flags)
	local data = mod.GetSafeData(entity)
	return data.vanillaFlags & flags == flags
end

function mod.HasAnyCustomVanillaTearFlags(entity)
	local data = mod.GetSafeData(entity)
	return data.vanillaFlags ~= mod.BitSetZero
end

function mod.ClearCustomVanillaTearFlags(entity, flags)
	local data = mod.GetSafeData(entity)
	data.vanillaFlags = data.vanillaFlags &~ flags
end

function mod.WipeCustomVanillaTearFlags(entity)
	mod.GetSafeData(entity).vanillaFlags = mod.BitSetZero
end

function mod.SetCustomVanillaTearFlagParams(entity, newParams, override)
	if override then
		mod.GetSafeData(entity).vanillaParams = newParams
	else
		mod.FuzzyReplaceTable(mod.GetSafeData(entity).vanillaParams, newParams)
	end
end

function mod.GetCustomVanillaTearFlagParams(entity)
	return mod.CopyTable(mod.GetSafeData(entity).vanillaParams)
end

function mod.FuzzyGetVanillaTearFlags(entity)
	return (mod.Cast(entity).TearFlags or TearFlags.TEAR_NORMAL) | mod.GetCustomVanillaTearFlags(entity)
end

function mod.CopyTearFlags(recipient, donor, weaponFlag, params) -- weaponFlag is technically optional, but you should always provide one if you can (the weaponFlag of the recipient)
	params = params or {}

	if params.wipe then
		mod.WipeTearFlags(recipient)
		mod.WipeCustomVanillaTearFlags(recipient)
	end

	mod.AddTearFlags(recipient, mod.GetTearFlags(donor))
	mod.SetTearFlagParams(recipient, nil, mod.GetTearFlagParams(donor), true)
	mod.TryCopyBlacklist(recipient, donor)

	if not params.skipVanilla then
		mod.AddCustomVanillaTearFlags(recipient, mod.FuzzyGetVanillaTearFlags(donor))
		mod.SetCustomVanillaTearFlagParams(recipient, mod.GetCustomVanillaTearFlagParams(donor), true)
	end

	for _, callbackData in pairs(Isaac.GetCallbacks(mod.Callback.POST_COPY_TEARFLAGS)) do
		if not callbackData.Param or mod.HasTearFlags(recipient, callbackData.Param) then
			callbackData.Function(callbackData.Mod, recipient, donor, weaponFlag)
		end
	end
end

function mod.TryCopyBlacklist(recipient, donor)
	local donorData = mod.GetSafeData(donor)
	local data = mod.GetSafeData(recipient)

	mod.GetTearFlags(recipient):ForEach(function(flag)
		local id = tostring(flag:GetFirstIndex())
		if donorData.copyBlacklist[id] then
			data.entityBlacklist[id] = mod.CopyTable(donorData.entityBlacklist[id])
			data.copyBlacklist[id] = mod.CopyTable(donorData.copyBlacklist[id])
		end
	end)

	if donorData.copyBlacklist.General then
		data.entityBlacklist.General = mod.CopyTable(donorData.entityBlacklist.General)
		data.copyBlacklist.General = mod.CopyTable(donorData.copyBlacklist.General)
	end
end

-- Literally just a wrapper for EntityPlayer.GetTearHitParams to grab the only 2 things you probably care about
function mod.PollVanillaTearFlags(player, weaponEntity, weaponTypeOverride, damageScaleOverride, tearDisplacementOverride)
	local params = player:GetTearHitParams(weaponTypeOverride or WeaponType.WEAPON_TEARS, damageScaleOverride, tearDisplacementOverride, weaponEntity or player)
	return params.TearFlags, params.TearDamage
end

-- Because of how :ForceCollide works, ApplyVanillaTearFlagEffectsToEntity will trigger an instance of damage against the entity receiving the flags
-- This damage is cancelled early, but the callback will still fire so be aware

-- Params is an optional table that can contain the following information:
	-- vector:	PositionOverride	(For determining where tear-spawns appear like Parasitoid creep)
	-- vector:	VelocityOverride	(For determining which direction Knockout Drops launches the entity)
	-- integer:	DamageOverride 		(For modifying the damage of tear-spawns like Holy Light and Explosions)
	-- integer:	ScaleOverride 		(For modifying the size of sticky-type tears and some tear-spawns like Explosions)
	-- Color:	ColorOverride		(For modifying the colour of tear-spawns like Explosions)
	-- boolean:	RemoveStickyTears	(For automatically removing all sticky-type tears if your Weapon has custom behaviour)
	-- boolean: RemoveSplashDamage  (For automatically removing )
function mod.ApplyVanillaTearFlagEffectsToEntity(entity, flags, player, flagsSource, params)
	flags = flags or BitSet128(0, 0)
	player = player or Isaac.GetPlayer()
	params = params or {}

	local position = params.PositionOverride or (flagsSource and flagsSource.Position) or (entity.Position + (player.Position - entity.Position):Resized(entity.Size + 7))
	local velocity = params.VelocityOverride or (flagsSource and flagsSource.Velocity) or (entity.Position - player.Position)
	if params.RemoveStickyTears then flags = flags &~ mod.STICKY_TEAR_FLAGS end

	local recursionKey = mod.SetAntiRecursion()
	mod.CancelDamage = true
	local tear = Isaac.Spawn(2, 0, 0, position, velocity, player):ToTear()
	tear.CollisionDamage = params.DamageOverride or player.Damage
	tear.Scale = params.ScaleOverride or tear.Scale
	tear.Color = params.ColorOverride or tear.Color
	tear:AddTearFlags(flags &~ (mod.SPLITSHOT_TEAR_FLAGS | mod.PIERCING_TEARFLAGS))
	tear:AddEntityFlags(EntityFlag.FLAG_NO_QUERY)
	tear:ForceCollide(entity, true)
	mod.CancelDamage = false
	mod.ClearAntiRecursion(recursionKey)

	if flags & mod.STICKY_TEAR_FLAGS ~= TearFlags.TEAR_NORMAL then -- Has Sinus/Explosivo/Mucormycosis
		mod.CostumeStickyTear(tear)
		tear.StickDiff = tear.StickDiff:Resized(entity.Size + tear.Size)
		return
	end

	if flags & mod.NO_REMOVE_TEAR_FLAGS ~= TearFlags.TEAR_NORMAL then -- Has Ipecac/Mysterious Liquid
		tear.Visible = false
		if flags & TearFlags.TEAR_EXPLOSIVE == TearFlags.TEAR_EXPLOSIVE then
			if flags & TearFlags.TEAR_BURN then
				tear.Color = params.ColorOverride or Color.LaserFireMind
			else
				tear.Color = params.ColorOverride or Color.TearIpecac
			end
		else
			tear.Color = Color(1,1,1,0,0,0,0)
		end
		tear:Update()
	else
		tear.Position = Vector(9e9, 9e9)
	end

	tear:Remove()
end

-- Generally this shouldn't be used for custom weapons, this is for arbitrarily applying the effects of flags
-- See the beginning of the callbacks.lua for how to properly interact with our custom flags
function mod.ApplyCustomTearFlagEffectsToEntity(entity, flags, player, flagsSource, weaponFlag)
	for _, callbackData in pairs(Isaac.GetCallbacks(mod.Callback.APPLY_TEARFLAG_EFFECT)) do
		if flags & callbackData.Param ~= mod.BitSetInfinity.Zero then
			callbackData.Function(callbackData.Mod, entity, player, flagsSource, weaponFlag)
		end
	end
end

function mod.BlacklistEntity(entity, source, flag) -- Blacklists Entity from recieving the effects of a given Flag from Source. Source should be your WeaponEntity.
	local blacklist = mod.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = blacklist[node] or {}
	blacklist[node][tostring(entity.InitSeed)] = true
end

function mod.TemporarilyBlacklistEntity(entity, source, flag, duration) -- This is its own function primarily just to reduce confusion.
	local blacklist = mod.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = blacklist[node] or {}
	blacklist[node][tostring(entity.InitSeed)] = Game():GetFrameCount() + duration
end

function mod.WhitelistEntity(entity, source, flag)
	local blacklist = mod.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = blacklist[node] or {}
	blacklist[node][tostring(entity.InitSeed)] = false
end

function mod.ClearBlacklist(source, flag)
	local blacklist = mod.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = {}
end

function mod.WipeBlacklists(source)
	mod.GetSafeData(source).entityBlacklist = {General = {}}
end

function mod.IsEntityBlacklisted(entity, source, flag)
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	local blacklisted = (mod.GetSafeData(source).entityBlacklist[node] or {})[tostring(entity.InitSeed)]
	
	if type(blacklisted) == "number" then
		if blacklisted < Game():GetFrameCount() then
			mod.WhitelistEntity(entity, source, flag)
			return false
		else
			return true
		end
	else
		return blacklisted
	end
end

function mod.SetCopyBlacklist(source, bool, flag) -- Tells the passed Source whether its blacklist should be passed onto any entity that copies its TearFlags
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	mod.GetSafeData().copyBlacklist[node] = bool
end

-- Params is an optional table that can contain the following information:
	-- BitSet128:		RemoveFlags 		(Removes any defined Vanilla TearFlags)
	-- BitSetInfinity:	RemoveCustomFlags	(Removes any defined Custom TearFlags)

	-- vector:	PositionOverride		(Position defaults to spawner.Position, this takes priority)
	-- Color:	ColorOverride			(Color defaults to spawner.Color, this takes priority)
	-- number:	DamageMult 				(Defaults to 0.5)
	-- number:	DamageOverride 			(Damage is hard set to this value if provided, ignoring DamageMult)
	-- number:	ScaleMult 				(Defaults to 0.5)
	-- number:	ScaleOverride 			(Scale is hard set to this value if provided, ignoring ScaleMult)
	-- number:	TearVariant 			(If spawner is an EntityTear, defaults to spawner.Variant, otherwise defaults to player:GetTearHitParams(...).TearVariant)
	-- boolean: SkipRemoveOnSplitFlags	(Some TearFlags are removed automatically (Tractor Beam), pass as `true` to allow these flags to stay)
	-- boolean: CanTriggerStreakEnd		(For Dead Eye, defaults to false)
	-- string:	SplitTearType 			(Passed through to MC_POST_FIRE_SPLIT_TEAR in the SplitTearType argument)
function mod.FireSplitTear(spawner, velocity, player, params)
	spawner = mod.Cast(spawner)
	params = params or {}

	local variant = 0

	if params.TearVariant then
		variant = params.TearVariant
	elseif spawner.Type == 2 then
		variant = spawner.Variant
	else
		variant = player:GetTearHitParams(WeaponType.WEAPON_TEARS).TearVariant
	end

	local tear = Isaac.Spawn(2, variant, 0, params.PositionOverride or spawner.Position, velocity, player):ToTear()
	if spawner.TearFlags or spawner.Flags then tear.TearFlags = (spawner.TearFlags or spawner.Flags) end

	if params.ScaleOverride then
		mod.SetTearScale(tear, params.ScaleOverride)
	elseif spawner.Scale then
		mod.SetTearScale(tear, spawner.Scale * (params.ScaleMult or 0.5))
	else
		mod.SetTearScale(tear, tear.Scale * (params.ScaleMult or 0.5))
	end

	tear.Color = params.ColorOverride or spawner.Color
	tear.CollisionDamage = params.DamageOverride or ((spawner.CollisionDamage or player.Damage) * (params.DamageMult or 0.5))
	tear.CanTriggerStreakEnd = params.CanTriggerStreakEnd or false
	Isaac.RunCallbackWithParam(ModCallbacks.MC_POST_FIRE_SPLIT_TEAR, params.SplitTearType or "TearFlagsLibGeneric", tear, spawner, params.SplitTearType or "TearFlagsLibGeneric")

	tear.TearFlags = tear.TearFlags | mod.GetCustomVanillaTearFlags(tear)

	if not params.SkipRemoveOnSplitFlags then
		tear.TearFlags = tear.TearFlags &~ mod.REMOVE_ON_SPLITSHOT_FLAGS
	end

	mod.WipeCustomVanillaTearFlags(tear)

	if params.RemoveFlags then
		tear.TearFlags = tear.TearFlags &~ params.RemoveFlags
	end

	if params.RemoveCustomFlags then
		mod.ClearTearFlags(tear, params.RemoveCustomFlags)
	end

	return tear
end

-- Params is an optional table that can contain every TearFlagsLib.FireSplitTear param, as well as:
	-- number:		NumTears		(Defaults to 14)
	-- boolean:		NoBurstSfx		(Defaults to false)
	-- boolean:		IgnoreShotSpeed (Defaults to false)
function mod.FireSplitTearMonstroBurst(spawner, velocity, player, rng, params)
    local tears = {}
    params = params or {}
    rng = rng or player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)

    for _, tearInfo in ipairs(mod.GetPlayerMonstroBurstInfo(player, params.PositionOverride or spawner.Position, velocity, params.NumTears, rng, params.IgnoreShotSpeed)) do
        local tear = mod.FireSplitTear(spawner, tearInfo.Vel, player, mod.FuzzyReplaceTable(params, {
        	PositionOverride = tearInfo.Pos,
        	ScaleMult = tearInfo.ScaleMult,
        }))
        
        tear.CanTriggerStreakEnd = false
        tear.FallingAcceleration = tearInfo.FallingAcceleration
        tear.FallingSpeed = tear.FallingSpeed + tearInfo.FallingSpeed
        tear:ResetSpriteScale()
        table.insert(tears, tear)
    end

    if playBurstSound ~= false then
        sfx:Play(891, 0.8, 0, false, rng:RandomFloat(1.3, 1.5))
    end

    return tears
end

-- Params is an option table that can contain the following information:
	-- BitSet128:		RemoveFlags 		(Removes any defined Vanilla TearFlags)
	-- BitSetInfinity:	RemoveCustomFlags	(Removes any defined Custom TearFlags)

	-- vector:	PositionOverride		(Position defaults to spawner.Position, this takes priority)
	-- Color:	ColorOverride			(Color defaults to spawner.Color, this takes priority)
	-- number:	DamageMult 				(Defaults to 0.5)
	-- number:	DamageOverride 			(Damage is hard set to this value if provided, ignoring DamageMult)
	-- number:	ScaleOverride 			(Scale is hard set to this value if provided, ignoring ScaleMult)
	-- number:	BombVariant 			(If spawner is an EntityBomb, defaults to spawner.Variant, otherwise defaults to player:GetTearHitParams(...).BombVariant)
	-- boolean: SkipRemoveOnSplitFlags	(Some TearFlags are removed automatically (Tractor Beam), pass as `true` to allow these flags to stay)
function mod.FireSplitBomb(spawner, velocity, player, params)
	spawner = mod.Cast(spawner)
	params = params or {}

	local variant = 0

	if params.BombVariant then
		variant = params.BombVariant
	elseif spawner.Type == 4 then
		variant = spawner.Variant
	else
		variant = player:GetTearHitParams(WeaponType.WEAPON_BOMBS).BombVariant
	end

	local bomb = Isaac.Spawn(4, variant, 0, params.PositionOverride or spawner.Position, velocity, player):ToBomb()
	bomb:SetScale(params.ScaleOverride or 0.5)
	bomb.RadiusMultiplier = 0.6
	bomb.IsFetus = true
	bomb.Color = params.ColorOverride or spawner.Color
	bomb.ExplosionDamage = params.DamageOverride or ((spawner.ExplosionDamage or 100) * (params.DamageMult or 0.5))
	bomb.Flags = spawner.Flags or spawner.TearFlags or bomb.Flags
	-- This is where I would call MC_POST_FIRE_SPLIT_BOMB if it existed
	
	mod.CopyTearFlags(bomb, spawner, mod.WeaponFlag.DR_FETUS, {wipe = true})
	bomb:AddTearFlags(mod.GetCustomVanillaTearFlags(bomb))


	if not params.SkipRemoveOnSplitFlags then
		bomb:ClearTearFlags(mod.REMOVE_ON_SPLITSHOT_FLAGS)
	end

	mod.WipeCustomVanillaTearFlags(bomb)

	if params.RemoveFlags then
		bomb:ClearTearFlags(params.RemoveFlags)
	end

	if params.RemoveCustomFlags then
		mod.ClearTearFlags(bomb, params.RemoveCustomFlags)
	end

	bomb:SetLoadCostumes(true)
	return bomb
end

-- Params is an optional table that can contain every TearFlagsLib.FireSplitBomb param, as well as:
	-- number: NumBombs	(Defaults to 5)
function mod.FireSplitBombMonstroBurst(spawner, velocity, player, rng, params)
	local bombs = {}
	params = params or {}
	rng = rng or player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)

    for _, bombInfo in ipairs(mod.GetMonstroBombBurstInfo(params.PositionOverride or spawner.Position, velocity, params.NumBombs, rng)) do
        local bomb = mod.FireSplitBomb(spawner, bombInfo.Vel, player, mod.FuzzyReplaceTable(params, {
        	PositionOverride = bombInfo.Pos,
        }))
        bomb:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK)
        bomb.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ENEMIES
        bomb.PositionOffset.Y = bombInfo.Height
        bomb:SetFallSpeed(bombInfo.FallSpeed)
        bomb:SetFallAcceleration(bombInfo.FallAcceleration)
        bomb:SetExplosionCountdown(bombInfo.ExplosionCountdown)
        bomb:SetScale(bomb:GetScale() * bombInfo.ScaleMult)
        bomb:SetLoadCostumes(true)
        table.insert(bombs, bomb)
    end

    return bombs
end

-- Params is an optional table that can contain the following information:
	-- BitSet128:		RemoveFlags 		(Removes any defined Vanilla TearFlags)
	-- BitSetInfinity:	RemoveCustomFlags	(Removes any defined Custom TearFlags)

	-- vector:	PositionOverride		(Position defaults to spawner.Position, this takes priority)
	-- Color:	ColorOverride			(Color defaults to spawner.Color, this takes priority)
	-- number:	DamageMult 				(Defaults to 0.5)
	-- number:	ScaleMult 				(Defaults to 0.5)
	-- number:	LaserVariant 			(If spawner is an EntityLaser, defaults to spawner.Variant. If said variant corresponds to a Brimstone-style laser, or spawner is not a Laser, defaults to LaserVariant.THIN_RED)
	-- enum:	LaserOffset 			(Defaults to LaserOffset.LASER_TRACTOR_BEAM_OFFSET)
	-- vector:	PositionOffset			(Defaults to Vector(0, -20))
	-- number:	MaxDistance
	-- number:	NumChainedLasers
	-- number:	InitSound 				(Overrides the default laser init sound)
function mod.FireSplitLaser(spawner, direction, player, params)
	spawner = mod.Cast(spawner)
	params = params or {}

	TearFlagsLib.FiringSplitLaser = {
		Spawner = spawner,
		Player = player,
		Params = params,
	}

	local variant = params.LaserVariant or (spawner.Type == EntityType.ENTITY_LASER and spawner.Variant) or LaserVariant.THIN_RED
	if mod.IsLaserVariantBrimstone(variant) then
		variant = LaserVariant.THIN_RED
	end

	-- TearFlags stuff is done in a POST_FIRE_TECH_LASER callback for laser reasons
	local laser = player:FireTechLaser(params.PositionOverride or spawner.Position, LaserOffset.LASER_TRACTOR_BEAM_OFFSET, direction, false, true, player, params.DamageMult or 0.5)
	TearFlagsLib.FiringSplitLaser = nil

	laser.DisableFollowParent = true
	laser.ParentOffset = Vector.Zero
	laser.PositionOffset = params.PositionOffset or Vector(0, -20)
	laser:SetScale(laser:GetScale() * params.ScaleMult)
    laser:ResetSpriteScale()
	laser.MaxDistance = params.MaxDistance or laser.MaxDistance

	if params.ColorOverride then -- Not automatically setting to spawner.Color no matter what because normal tints looks insanely ugly on lasers
		laser.Color = params.ColorOverride
	elseif spawner.Type == EntityType.ENTITY_LASER then
		laser.Color = spawner.Color
	end

	if params.NumChainedLasers then
		laser:SetNumChainedLasers(params.NumChainedLasers)
	end

	if params.InitSound then
		laser:SetInitSound(params.InitSound)
	end

	return laser
end

-- Params is an optional table that can contain every TearFlagsLib.FireSplitLaser param, as well as:
	-- number:	NumLasers 	(Defaults to 6)
	-- boolean:	NoBurstSfx 	(Defaults to false)
function mod.FireSplitLaserMonstroBurst(spawner, direction, player, rng, params)
	local playBurstSfx = params.PlayMonstroBurstSfx
    posOffset = posOffset or Vector(0, -20)

    local lasers = {}

    for _, laserInfo in ipairs(mod.GetMonstroLaserBurstInfo(params.PositionOverride or spawner.Position, direction, params.NumLasers)) do
        local laser = mod.FireSplitLaser(spawner, laserInfo.Dir, player, mod.FuzzyReplaceTable(params, {
        	PositionOverride = laserInfo.Pos,
        	ScaleMult = laserInfo.ScaleMult,
        	MaxDistance = laserInfo.ChainSegmentDistance,
        	NumChainedLasers = laserInfo.NumChainedLasers,
        	InitSound = (not params.NoBurstSfx) and SoundEffect.SOUND_NULL,
        }))

        laser.Position = laserInfo.Pos
        table.insert(lasers, laser)
    end

    if not params.NoBurstSfx then
        sfx:Play(SoundEffect.SOUND_REDLIGHTNING_ZAP_BURST)
    end

    return lasers
end

-- :(
function mod.EstimateWeaponFlagFromEntity(entity)
	local data = mod.GetSafeData(entity)

	for weapon, func in pairs(mod.WeaponIdentityFunctions) do
		if func(entity) then return weapon end
	end 

	if entity.Type == 2 then
		if data.isBobsHead then
			return mod.WeaponFlag.BOBS_ROTTEN_HEAD
		elseif data.isSharpKey then
			return mod.WeaponFlag.SHARP_KEY
		else
			return mod.WeaponFlag.TEAR
		end
	elseif entity.Type == 3 then
		if entity.Variant == FamiliarVariant.ABYSS_LOCUST then
			return mod.WeaponFlag.LOCUST
		elseif entity.Variant == FamiliarVariant.UMBILICAL_BABY then
			return mod.WeaponFlag.UMBILICAL_WHIP
		end
	elseif entity.Type == 4 then
		return mod.WeaponFlag.DR_FETUS
	elseif entity.Type == 7 then
		return mod.WeaponFlag.LASER
	elseif entity.Type == 8 then
		if mod.IsKnifeVariantTrueKnife(entity.Variant) then
			return mod.WeaponFlag.KNIFE
		elseif mod.IsKnifeVariantClub(entity.Variant) then
			return mod.WeaponFlag.CLUB
		elseif mod.IsKnifeVariantSword(entity.Variant) then
			return mod.WeaponFlag.SWORD
		end
	elseif entity.Type == 1000 then
		if entity.Variant == EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL then
			return mod.WeaponFlag.AQUARIUS
		elseif entity.Variant == EffectVariant.ROCKET then
			return mod.WeaponFlag.EPIC_FETUS
		elseif entity.Variant == EffectVariant.SMALL_ROCKET then
			return mod.WeaponFlag.CLUB_EPIC_FETUS
		elseif entity.Variant == EffectVariant.BRIMSTONE_SWIRL or entity.Variant == EffectVariant.TECH_DOT then
			return mod.WeaponFlag.ANTI_GRAV_LASER
		elseif entity.Variant == EffectVariant.BRIMSTONE_BALL then
			return mod.WeaponFlag.BRIMSTONE_BALL
		elseif entity.Variant == EffectVariant.DARK_SNARE then
			return mod.WeaponFlag.DARK_ARTS
		elseif entity.Variant == EffectVariant.RIFT then
			return mod.WeaponFlag.OCULAR_RIFT
		elseif data.dummyWeaponIdentity == mod.WeaponFlag.HEMOPTYSIS then
			return mod.WeaponFlag.HEMOPTYSIS
		end
	end

	return nil
end

-- Sort of like entity:TakeDamage, only specifically geared to make custom Weapons easier
-- Automatically modifies the amount of damage dealt based on a specific TearFlagParams table
-- Automatically deals damage with the correct DamageFlags for items like Terra

-- Params is an optional table that can contain the following information:
	-- Entity:		DamageSource				(Overrides the entity passed through Entity:TakeDamage as the Source)
	-- Number:		DamageCooldown				(Passed to the DamageCooldown argument of Entity:TakeDamage, defaults to 0)
	-- boolean:		IgnoreVanillaDamageFlags 	(Skips adding the extra damage flags from vanilla)
function mod.DamageEntity(entity, amount, damageFlags, weaponEntity, params)
	local damageMult = 1
	local damageAdd = 0
	local damageFlat = 0
	params = params or {}

	mod.GetTearFlags(weaponEntity):ForEach(function(flag)
		local flagParams = mod.GetTearFlagParams(weaponEntity, flag)
		if flagParams.DamageParams then
			damageFlags = damageFlags | (flagParams.DamageParams.DamageFlags or 0)
			damageMult = damageMult * (flagParams.DamageParams.DamageMult or 1)
			damageAdd = damageAdd + (flagParams.DamageParams.ExtraDamage or 0)
			damageFlat = damageFlat + (flagParams.DamageParams.ExtraDamageFlat or 0)
		end
	end)

	if not params.IgnoreVanillaDamageFlags then damageFlags = damageFlags | mod.GetVanillaTearFlagDamageFlags(weaponEntity) end
	amount = (amount + damageAdd) * damageMult + damageFlat
	entity:TakeDamage(amount, damageFlags, EntityRef(params.DamageSource or weaponEntity), params.DamageCooldown or 0)
end

function mod.AddEntityToUpdateList(entity, listKey)
	mod.UpdateLists[listKey] = mod.UpdateLists[listKey] or {}
	table.insert(mod.UpdateLists[listKey], entity)
end

function mod.RemoveEntityFromUpdateList(entity, listKey)
	mod.RemoveUserDataValueFromTable(entity, mod.EntityLists[listKey] or {})
end

function mod.SetTearCanHitMultipleTimes(tear, canHit, frequency) -- Ludovico Technique tears are allowed to damage the same entity multiple times. This allows you to set a frequency by which any tear can do the same, managed by TearFlagsLib
	if not tear:ToTear() then return end -- This one really DOES have to be a tear
	if canHit == nil then canHit = true end

	mod.GetSafeData(tear).pseudoLudo = {
		canReset = canHit,
		frequency = frequency, -- Frequency defaults to player fire rate if not set
	}
end

-- Only Isaac gets the benefits of Teardrop Charm. Familiars like Incubus and Twisted Pair do not
-- The entity which is polling for TearFlags therefore must be passed in order to determine when not to include this bonus
function mod.GetRealLuck(player, testEntity)
	mod.LuckCache = 0
	player:AddCacheFlags(CacheFlag.CACHE_LUCK)
	player:EvaluateItems()

	if testEntity and mod.WasEntityFiredByPlayerMimic(testEntity, true) then
		return mod.LuckCache -- This is a familiar attack, do not apply Teardrop Charm bonuses
	end

	if player:HasTrinket(TrinketType.TRINKET_TEARDROP_CHARM) then
		mod.LuckCache = mod.LuckCache + 2
		mod.LuckCache = mod.LuckCache + 2 * player:GetTrinketMultiplier(TrinketType.TRINKET_TEARDROP_CHARM)
	end

	return mod.LuckCache
end

-- Linearly scales chance from baseChance -> maxChance as rawLuck scales from 0 -> luckRequirement
function mod.GetChance(rawLuck, baseChance, maxChance, luckRequirement, itemScalerN)
	local range = maxChance - baseChance
	local luck = math.max(math.min(rawLuck, luckRequirement), 0)
	local chance = baseChance + range * (luck / luckRequirement)

	if itemScalerN then -- Optionally stacks the chance based on a passed scaler, usually GetCollectibleNum
		chance = 1 - (1 - chance) ^ itemScalerN -- If itemScalerN is 0, the returned chance is 0%, which means that you don't *technically* have to check for item ownership if you pass a sensible itemScalerN
	end

	return chance
end

-- Example:

-- Scales effect chance from 5% to 25% as "player" approaches 27 Luck. Respects the effect of Teardrop Charm. Chance is stacked multiplicatively based on how many of the item they have
--[[
	local rng = player:GetCollectibleRNG(myFunnyItem)
	local chance = TearFlagsLib.GetChance(TearFlagsLib.GetRealLuck(player, tear), 0.05, 0.25, 27, player:GetCollectibleNum(myFunnyItem))
	if rng:RandomFloat() < chance then
		TearFlagsLib.AddTearFlags(tear, TearFlagsLib.Flag.MY_FUNNY_TEARFLAG)
	end
]]

function mod.DumpFlags()
	for key, flag in pairs(mod.Flag) do
		print(key, flag)
	end
end

include(mod.Source .. ".library")
include(mod.Source .. ".callbacks")

TearFlagsLib.RegisterCallbacks()

print("Loaded TearFlagsLib Version:", version)