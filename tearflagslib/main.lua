TearFlagsLib = TearFlagsLib or RegisterMod("Tear Flags Library", 1)
local build = 101
local version = "1.1.1"
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
TearFlagsLib.Release = build
TearFlagsLib.Source = "tearflagslib"									-- !!!!!!!! If you embed this into your own mod, remember to set this variable
TearFlagsLib.DataKey = localHolder.key or {}
TearFlagsLib.BitSetZero = BitSet128(0, 0)
TearFlagsLib.BitSetOne = BitSet128(-1, -1)
TearFlagsLib.GuarenteedFlagTracker = bitSet128FromIndex(TearFlags.TEAR_EFFECT_COUNT + 1)

TearFlagsLib.AntiRecursion = false
TearFlagsLib.IsPollingForTearFlags = false

TearFlagsLib.Flag = localHolder.flags or {}
TearFlagsLib.IndexedFlags = localHolder.flagsN or 0
TearFlagsLib.playerMimickingFamiliarMap = localHolder.mimics
TearFlagsLib.playerMimickingEffectMap = localHolder.mimics2
TearFlagsLib.UpdateLists = {}
TearFlagsLib.RecursionBlockers = {Count = 0, NextIndex = 0}

include(TearFlagsLib.Source .. ".bitset_infinity")
if TearFlagsLib.Updated then
	TearFlagsLib.UpdateBitSetInfinity(TearFlagsLib.Flag)
	TearFlagsLib.UpdateBitSetInfinity(localHolder.weapons)
end

TearFlagsLib.Callback = {
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
	TearFlagsLib.Callback.POLL_TEARFLAGS,
	TearFlagsLib.Callback.POLL_CHANCELESS_TEARFLAGS,

	TearFlagsLib.Callback.PRE_ADD_TEARFLAG,
	TearFlagsLib.Callback.POST_ADD_TEARFLAG,
	TearFlagsLib.Callback.POST_COPY_TEARFLAGS,
	TearFlagsLib.Callback.PRE_REMOVE_TEARFLAG,
	TearFlagsLib.Callback.POST_REMOVE_TEARFLAG,

	TearFlagsLib.Callback.PRE_POLL_TEARFLAGS,
	TearFlagsLib.Callback.POST_POLL_TEARFLAGS,
}) do
	setmetatable(Isaac.GetCallbacks(callback, true), {
		__matchParams = paramsTestFlagMatch
	})
end

-- Any pre-existing callbacks should maintain their old callback address when a newer version is loaded
-- This makes sure mods that regsiter callbacks on these old addresses still get their code run
if localHolder.callback then
	for key, callbackAddress in pairs(localHolder.callback) do
		TearFlagsLib.Callback[key] = callbackAddress
	end
end

TearFlagsLib.WeaponFlag = localHolder.weapons or {
	NUM_FLAGS = 0
}

TearFlagsLib.WeaponIdentityFunctions = localHolder.weaponIdentity or {}

-- Provides a more efficient, cached wrapper for GetData.
include(TearFlagsLib.Source .. ".getdatacache")

function TearFlagsLib.GetSafeData(entity)
	local data = GetDataCache.GetEntityData(entity)
	data[TearFlagsLib.DataKey] = data[TearFlagsLib.DataKey] or {
		checkedFlags = false,
		tearFlags = TearFlagsLib.BitSetInfinity.Zero,
		vanillaFlags = TearFlagsLib.BitSetZero,
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

	return data[TearFlagsLib.DataKey]
end

function TearFlagsLib.SetAntiRecursion()
	local key = "RECURSOR" .. TearFlagsLib.RecursionBlockers.NextIndex
	TearFlagsLib.RecursionBlockers[key] = true
	TearFlagsLib.RecursionBlockers.Count = TearFlagsLib.RecursionBlockers.Count + 1
	TearFlagsLib.RecursionBlockers.NextIndex = TearFlagsLib.RecursionBlockers.NextIndex + 1
	TearFlagsLib.AntiRecursion = true
	return key
end

function TearFlagsLib.ClearAntiRecursion(key)
	if not TearFlagsLib.RecursionBlockers[key] then return false end
	TearFlagsLib.RecursionBlockers[key] = nil
	TearFlagsLib.RecursionBlockers.Count = math.max(0, TearFlagsLib.RecursionBlockers.Count)
	TearFlagsLib.AntiRecursion = TearFlagsLib.RecursionBlockers.Count == 0
end

local function getValidatedCustomParams(data, key)
	data.customParams[key] = data.customParams[key] or {}
	return data.customParams[key]
end

function TearFlagsLib.RegisterTearFlag(flagKey) -- Called either as RegisterTearFlag("NAME") or RegisterTearFlag({"NAME1", "NAME2", "NAME3"})
	if type(flagKey) == "table" then
		local indexes = {}
		for _, flag in pairs(flagKey) do
			table.insert(indexes, TearFlagsLib.RegisterTearFlag(flag))
		end

		return table.unpack(indexes)
	elseif type(flagKey) == "string" then
		if TearFlagsLib.Flag[flagKey] then return TearFlagsLib.Flag[flagKey] end

		TearFlagsLib.Flag[flagKey] = TearFlagsLib.BitSetInfinity.FromIndex(TearFlagsLib.IndexedFlags)
		TearFlagsLib.IndexedFlags = TearFlagsLib.IndexedFlags + 1

		return TearFlagsLib.Flag[flagKey]
	end
end

function TearFlagsLib.RegisterWeapon(weaponKey) -- Called either as RegisterWeapon("NAME") or RegisterWeapon({"NAME1", "NAME2", "NAME3"})
	if type(weaponKey) == "table" then
		local indexes = {}
		for _, flag in pairs(weaponKey) do
			table.insert(indexes, TearFlagsLib.RegisterWeapon(flag))
		end

		return table.unpack(indexes)
	elseif type(weaponKey) == "string" then
		if TearFlagsLib.WeaponFlag[weaponKey] then return TearFlagsLib.WeaponFlag[weaponKey] end
		
		TearFlagsLib.WeaponFlag[weaponKey] = TearFlagsLib.BitSetInfinity.FromIndex(TearFlagsLib.WeaponFlag.NUM_FLAGS)
		TearFlagsLib.WeaponFlag.NUM_FLAGS = TearFlagsLib.WeaponFlag.NUM_FLAGS + 1


		return TearFlagsLib.WeaponFlag[weaponKey]
	end	
end

TearFlagsLib.RegisterWeapon({"TEAR", "LASER", "KNIFE", "CLUB", "AQUARIUS", "DARK_ARTS", "DR_FETUS", "EPIC_FETUS", "LOCUST", "UMBILICAL_WHIP", "BRIMSTONE_BALL", "ANTI_GRAV_LASER", "SWORD", "OCULAR_RIFT", "HEMOPTYSIS", "CLUB_EPIC_FETUS"})
TearFlagsLib.RegisterWeapon({"LUDOVICO_TEAR", "BOBS_ROTTEN_HEAD", "SHARP_KEY"}) -- Tear Semi-Weapons. These WeaponTypes are only used in *some* callbacks, where they may be expected to behave differently than their "true" WeaponType
TearFlagsLib.TEAR_VARIANT_WEAPON_FLAGS = TearFlagsLib.WeaponFlag.TEAR | TearFlagsLib.WeaponFlag.LUDOVICO_TEAR | TearFlagsLib.WeaponFlag.BOBS_ROTTEN_HEAD | TearFlagsLib.WeaponFlag.SHARP_KEY
TearFlagsLib.LASER_VARIANT_WEAPON_FLAGS = TearFlagsLib.WeaponFlag.LASER | TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER | TearFlagsLib.WeaponFlag.BRIMSTONE_BALL
TearFlagsLib.EPIC_FETUS_VARIANT_WEAPON_FLAGS = TearFlagsLib.WeaponFlag.EPIC_FETUS | TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS
TearFlagsLib.NO_SPLITSHOT_WEAPON_FLAGS = TearFlagsLib.WeaponFlag.AQUARIUS | TearFlagsLib.WeaponFlag.DARK_ARTS | TearFlagsLib.WeaponFlag.EPIC_FETUS | TearFlagsLib.WeaponFlag.UMBILICAL_WHIP | TearFlagsLib.WeaponFlag.BRIMSTONE_BALL | TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER | TearFlagsLib.WeaponFlag.SWORD | TearFlagsLib.WeaponFlag.OCULAR_RIFT | TearFlagsLib.WeaponFlag.HEMOPTYSIS | TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS
TearFlagsLib.NO_COLOR_WEAPON_FLAGS = TearFlagsLib.WeaponFlag.LASER | TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER | TearFlagsLib.WeaponFlag.KNIFE | TearFlagsLib.WeaponFlag.DARK_ARTS | TearFlagsLib.WeaponFlag.LOCUST | TearFlagsLib.WeaponFlag.UMBILICAL_WHIP | TearFlagsLib.WeaponFlag.BRIMSTONE_BALL | TearFlagsLib.WeaponFlag.BOBS_ROTTEN_HEAD | TearFlagsLib.WeaponFlag.SHARP_KEY | TearFlagsLib.WeaponFlag.OCULAR_RIFT | TearFlagsLib.WeaponFlag.HEMOPTYSIS | TearFlagsLib.WeaponFlag.AQUARIUS | TearFlagsLib.WeaponFlag.EPIC_FETUS | TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS
TearFlagsLib.VANILLA_WEAPON_FLAGS = TearFlagsLib.WeaponFlag.TEAR | TearFlagsLib.WeaponFlag.LASER | TearFlagsLib.WeaponFlag.KNIFE | TearFlagsLib.WeaponFlag.CLUB | TearFlagsLib.WeaponFlag.AQUARIUS | TearFlagsLib.WeaponFlag.DARK_ARTS | TearFlagsLib.WeaponFlag.DR_FETUS | TearFlagsLib.WeaponFlag.EPIC_FETUS | TearFlagsLib.WeaponFlag.LOCUST | TearFlagsLib.WeaponFlag.UMBILICAL_WHIP | TearFlagsLib.WeaponFlag.BRIMSTONE_BALL | TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER | TearFlagsLib.WeaponFlag.SWORD | TearFlagsLib.WeaponFlag.OCULAR_RIFT | TearFlagsLib.WeaponFlag.HEMOPTYSIS | TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS | TearFlagsLib.WeaponFlag.SHARP_KEY | TearFlagsLib.WeaponFlag.BOBS_ROTTEN_HEAD

if localHolder.tearWeapons then TearFlagsLib.TEAR_VARIANT_WEAPON_FLAGS = TearFlagsLib.TEAR_VARIANT_WEAPON_FLAGS | localHolder.tearWeapons end
if localHolder.laserWeapons then TearFlagsLib.LASER_VARIANT_WEAPON_FLAGS = TearFlagsLib.LASER_VARIANT_WEAPON_FLAGS | localHolder.laserWeapons end
if localHolder.epicFetusWeapons then TearFlagsLib.EPIC_FETUS_VARIANT_WEAPON_FLAGS = TearFlagsLib.EPIC_FETUS_VARIANT_WEAPON_FLAGS | localHolder.epicFetusWeapons end
if localHolder.noColorWeapons then TearFlagsLib.NO_COLOR_WEAPON_FLAGS = TearFlagsLib.NO_COLOR_WEAPON_FLAGS | localHolder.noColorWeapons end
if localHolder.noSplitshotsWeapons then TearFlagsLib.NO_SPLITSHOT_WEAPON_FLAGS = TearFlagsLib.NO_SPLITSHOT_WEAPON_FLAGS | localHolder.noSplitshotsWeapons end

function TearFlagsLib.IsWeaponTearVariant(flag)
	return TearFlagsLib.TEAR_VARIANT_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.IsWeaponLaserVariant(flag)
	return TearFlagsLib.LASER_VARIANT_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.IsWeaponEpicFetusVariant(flag)
	return TearFlagsLib.EPIC_FETUS_VARIANT_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.DoesWeaponBlockSplitshots(flag) -- Don't treat this as gospel, there is a line somewhere between an effect that spawns tears, and a true split-shot. Idk where that line is though. That's your choice.
	return TearFlagsLib.NO_SPLITSHOT_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.ShouldWeaponGainEntityColor(flag) -- By default this returns false for everything except TEAR, LUDOVICO_TEAR, CLUB, and DR_FETUS
	return not TearFlagsLib.NO_COLOR_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.IsVanillaWeapon(flag)
	return TearFlagsLib.VANILLA_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.IsModdedWeapon(flag)
	return not TearFlagsLib.VANILLA_WEAPON_FLAGS:HasFlags(flag)
end

function TearFlagsLib.IsTearSplitTear(entity)
	return TearFlagsLib.GetSafeData(entity).isSplitTear
end

function TearFlagsLib.RegisterWeaponIdentityFunction(weaponFlag, func)
	TearFlagsLib.WeaponIdentityFunctions[weaponFlag] = func
end

function TearFlagsLib.RegisterPlayerMimicFamiliar(familiarVariant)
	if type(familiarVariant) == "table" then
		for _, variant in pairs(familiarVariant) do
			TearFlagsLib.playerMimickingFamiliarMap[variant] = true
		end
	elseif type(familiarVariant) == "number" then
		TearFlagsLib.playerMimickingFamiliarMap[familiarVariant] = true 
	end
end

function TearFlagsLib.RegisterPlayerMimicEffect(effectVariant)
	if type(effectVariant) == "table" then
		for _, variant in pairs(effectVariant) do
			TearFlagsLib.playerMimickingEffectMap[variant] = true
		end
	elseif type(effectVariant) == "number" then
		TearFlagsLib.playerMimickingEffectMap[effectVariant] = true 
	end
end

function TearFlagsLib.AddTearFlags(entity, flags, force)
	local data = TearFlagsLib.GetSafeData(entity)
	local player = TearFlagsLib.GetTearPlayer(entity)

	flags:ForEach(function(flag)
		local skipAdd = false

		if not force then
			for _, callbackData in pairs(Isaac.GetCallbacks(TearFlagsLib.Callback.PRE_ADD_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					if callbackData.Function(callbackData.Mod, entity, player, not not TearFlagsLib.IsPollingForTearFlags, TearFlagsLib.IsPollingForTearFlags, flag) then 
						skipAdd = true 
						break
					end
				end
			end
		end

		if not skipAdd then
			flag:EqualiseLength(data.tearFlags)
			data.tearFlags = data.tearFlags | flag
			
			for _, callbackData in pairs(Isaac.GetCallbacks(TearFlagsLib.Callback.POST_ADD_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					callbackData.Function(callbackData.Mod, entity, player, not not TearFlagsLib.IsPollingForTearFlags, TearFlagsLib.IsPollingForTearFlags, flag)
				end
			end
		end
	end)
end

function TearFlagsLib.GetTearFlags(entity)
	return TearFlagsLib.GetSafeData(entity).tearFlags:Clone()
end

function TearFlagsLib.HasTearFlags(entity, flags)
	local data = TearFlagsLib.GetSafeData(entity)
	return data.tearFlags & flags == flags
end

function TearFlagsLib.HasAnyTearFlags(entity)
	local data = TearFlagsLib.GetSafeData(entity)
	return data.tearFlags ~= TearFlagsLib.BitSetInfinity.Zero
end

function TearFlagsLib.ClearTearFlags(entity, flags, force)
	local data = TearFlagsLib.GetSafeData(entity)
	flags = flags & data.tearFlags -- Data validation for the callback
	
	flags:ForEach(function(flag)
		local player = TearFlagsLib.GetTearPlayer(entity)
		local canRemove = true

		if not force then
			for _, callbackData in pairs(Isaac.GetCallbacks(TearFlagsLib.Callback.PRE_REMOVE_TEARFLAG)) do
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

			local params = TearFlagsLib.GetTearFlagParams(entity, flag)
			if not params.KeepParamsOnFlagRemove then
				TearFlagsLib.ClearTearFlagParams(entity, flag)
			end

			for _, callbackData in pairs(Isaac.GetCallbacks(TearFlagsLib.Callback.POST_REMOVE_TEARFLAG)) do
				if not callbackData.Param or callbackData.Param & flag == flag then
					callbackData.Function(callbackData.Mod, entity, player, flag)
				end
			end
		end
	end)
end

function TearFlagsLib.WipeTearFlags(entity, force)
	TearFlagsLib.ClearTearFlags(entity, TearFlagsLib.GetTearFlags(entity), force)
end

function TearFlagsLib.SetTearFlagParams(entity, flag, newParams, override)
	if flag then
		local params = getValidatedCustomParams(TearFlagsLib.GetSafeData(entity), tostring(flag:GetFirstIndex()))
		if override then
			params = newParams
		else
			TearFlagsLib.FuzzyReplaceTable(params, newParams)
		end
	else
		if override then
			TearFlagsLib.GetSafeData(entity).customParams = newParams
		else
			TearFlagsLib.FuzzyReplaceTable(TearFlagsLib.GetSafeData(entity).customParams, newParams)
		end
	end
end

function TearFlagsLib.GetTearFlagParams(entity, flag)
	if flag then
		return TearFlagsLib.CopyTable(getValidatedCustomParams(TearFlagsLib.GetSafeData(entity), tostring(flag:GetFirstIndex())))
	else
		return TearFlagsLib.CopyTable(TearFlagsLib.GetSafeData(entity).customParams)
	end
end

function TearFlagsLib.ClearTearFlagParams(entity, flag)
	TearFlagsLib.GetSafeData(entity).customParams[tostring(flag:GetFirstIndex())] = {}
end

function TearFlagsLib.AddCustomVanillaTearFlags(entity, flags)
	local data = TearFlagsLib.GetSafeData(entity)
	data.vanillaFlags = data.vanillaFlags | flags
end

function TearFlagsLib.GetCustomVanillaTearFlags(entity)
	return TearFlagsLib.GetSafeData(entity).vanillaFlags
end

function TearFlagsLib.HasCustomVanillaTearFlags(entity, flags)
	local data = TearFlagsLib.GetSafeData(entity)
	return data.vanillaFlags & flags == flags
end

function TearFlagsLib.HasAnyCustomVanillaTearFlags(entity)
	local data = TearFlagsLib.GetSafeData(entity)
	return data.vanillaFlags ~= TearFlagsLib.BitSetZero
end

function TearFlagsLib.ClearCustomVanillaTearFlags(entity, flags)
	local data = TearFlagsLib.GetSafeData(entity)
	data.vanillaFlags = data.vanillaFlags &~ flags
end

function TearFlagsLib.WipeCustomVanillaTearFlags(entity)
	TearFlagsLib.GetSafeData(entity).vanillaFlags = TearFlagsLib.BitSetZero
end

function TearFlagsLib.SetCustomVanillaTearFlagParams(entity, newParams, override)
	if override then
		TearFlagsLib.GetSafeData(entity).vanillaParams = newParams
	else
		TearFlagsLib.FuzzyReplaceTable(TearFlagsLib.GetSafeData(entity).vanillaParams, newParams)
	end
end

function TearFlagsLib.GetCustomVanillaTearFlagParams(entity)
	return TearFlagsLib.CopyTable(TearFlagsLib.GetSafeData(entity).vanillaParams)
end

function TearFlagsLib.FuzzyGetVanillaTearFlags(entity)
	return (TearFlagsLib.Cast(entity).TearFlags or TearFlags.TEAR_NORMAL) | TearFlagsLib.GetCustomVanillaTearFlags(entity)
end

function TearFlagsLib.CopyTearFlags(recipient, donor, weaponFlag, params) -- weaponFlag is technically optional, but you should always provide one if you can (the weaponFlag of the recipient)
	params = params or {}

	if params.wipe then
		TearFlagsLib.WipeTearFlags(recipient)
		TearFlagsLib.WipeCustomVanillaTearFlags(recipient)
	end

	TearFlagsLib.AddTearFlags(recipient, TearFlagsLib.GetTearFlags(donor))
	TearFlagsLib.SetTearFlagParams(recipient, nil, TearFlagsLib.GetTearFlagParams(donor), true)
	TearFlagsLib.TryCopyBlacklist(recipient, donor)

	if not params.skipVanilla then
		TearFlagsLib.AddCustomVanillaTearFlags(recipient, TearFlagsLib.FuzzyGetVanillaTearFlags(donor))
		TearFlagsLib.SetCustomVanillaTearFlagParams(recipient, TearFlagsLib.GetCustomVanillaTearFlagParams(donor), true)
	end

	for _, callbackData in pairs(Isaac.GetCallbacks(TearFlagsLib.Callback.POST_COPY_TEARFLAGS)) do
		if not callbackData.Param or TearFlagsLib.HasTearFlags(recipient, callbackData.Param) then
			callbackData.Function(callbackData.Mod, recipient, donor, weaponFlag)
		end
	end
end

function TearFlagsLib.TryCopyBlacklist(recipient, donor)
	local donorData = TearFlagsLib.GetSafeData(donor)
	local data = TearFlagsLib.GetSafeData(recipient)

	TearFlagsLib.GetTearFlags(recipient):ForEach(function(flag)
		local id = tostring(flag:GetFirstIndex())
		if donorData.copyBlacklist[id] then
			data.entityBlacklist[id] = TearFlagsLib.CopyTable(donorData.entityBlacklist[id])
			data.copyBlacklist[id] = TearFlagsLib.CopyTable(donorData.copyBlacklist[id])
		end
	end)

	if donorData.copyBlacklist.General then
		data.entityBlacklist.General = TearFlagsLib.CopyTable(donorData.entityBlacklist.General)
		data.copyBlacklist.General = TearFlagsLib.CopyTable(donorData.copyBlacklist.General)
	end
end

-- Literally just a wrapper for EntityPlayer.GetTearHitParams to grab the only 2 things you probably care about
function TearFlagsLib.PollVanillaTearFlags(player, weaponEntity, weaponTypeOverride, damageScaleOverride, tearDisplacementOverride)
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
function TearFlagsLib.ApplyVanillaTearFlagEffectsToEntity(entity, flags, player, flagsSource, params)
	flags = flags or BitSet128(0, 0)
	player = player or Isaac.GetPlayer()
	params = params or {}

	local position = params.PositionOverride or (flagsSource and flagsSource.Position) or (entity.Position + (player.Position - entity.Position):Resized(entity.Size + 7))
	local velocity = params.VelocityOverride or (flagsSource and flagsSource.Velocity) or (entity.Position - player.Position)
	if params.RemoveStickyTears then flags = flags &~ TearFlagsLib.STICKY_TEAR_FLAGS end

	local recursionKey = TearFlagsLib.SetAntiRecursion()
	TearFlagsLib.CancelDamage = true
	local tear = Isaac.Spawn(2, 0, 0, position, velocity, player):ToTear()
	tear.CollisionDamage = params.DamageOverride or player.Damage
	tear.Scale = params.ScaleOverride or tear.Scale
	tear.Color = params.ColorOverride or tear.Color
	tear:AddTearFlags(flags &~ (TearFlagsLib.SPLITSHOT_TEAR_FLAGS | TearFlagsLib.PIERCING_TEARFLAGS))
	tear:AddEntityFlags(EntityFlag.FLAG_NO_QUERY)
	tear:ForceCollide(entity, true)
	TearFlagsLib.CancelDamage = false
	TearFlagsLib.ClearAntiRecursion(recursionKey)

	if flags & TearFlagsLib.STICKY_TEAR_FLAGS ~= TearFlags.TEAR_NORMAL then -- Has Sinus/Explosivo/Mucormycosis
		TearFlagsLib.CostumeStickyTear(tear)
		tear.StickDiff = tear.StickDiff:Resized(entity.Size + tear.Size)
		return
	end

	if flags & TearFlagsLib.NO_REMOVE_TEAR_FLAGS ~= TearFlags.TEAR_NORMAL then -- Has Ipecac/Mysterious Liquid
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
function TearFlagsLib.ApplyCustomTearFlagEffectsToEntity(entity, flags, player, flagsSource, weaponFlag)
	for _, callbackData in pairs(Isaac.GetCallbacks(TearFlagsLib.Callback.APPLY_TEARFLAG_EFFECT)) do
		if flags & callbackData.Param ~= TearFlagsLib.BitSetInfinity.Zero then
			callbackData.Function(callbackData.Mod, entity, player, flagsSource, weaponFlag)
		end
	end
end

function TearFlagsLib.BlacklistEntity(entity, source, flag) -- Blacklists Entity from recieving the effects of a given Flag from Source. Source should be your WeaponEntity.
	local blacklist = TearFlagsLib.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = blacklist[node] or {}
	blacklist[node][tostring(entity.InitSeed)] = true
end

function TearFlagsLib.TemporarilyBlacklistEntity(entity, source, flag, duration) -- This is its own function primarily just to reduce confusion.
	local blacklist = TearFlagsLib.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = blacklist[node] or {}
	blacklist[node][tostring(entity.InitSeed)] = Game():GetFrameCount() + duration
end

function TearFlagsLib.WhitelistEntity(entity, source, flag)
	local blacklist = TearFlagsLib.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = blacklist[node] or {}
	blacklist[node][tostring(entity.InitSeed)] = false
end

function TearFlagsLib.ClearBlacklist(source, flag)
	local blacklist = TearFlagsLib.GetSafeData(source).entityBlacklist
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	blacklist[node] = {}
end

function TearFlagsLib.WipeBlacklists(source)
	TearFlagsLib.GetSafeData(source).entityBlacklist = {General = {}}
end

function TearFlagsLib.IsEntityBlacklisted(entity, source, flag)
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	local blacklisted = (TearFlagsLib.GetSafeData(source).entityBlacklist[node] or {})[tostring(entity.InitSeed)]
	
	if type(blacklisted) == "number" then
		if blacklisted < Game():GetFrameCount() then
			TearFlagsLib.WhitelistEntity(entity, source, flag)
			return false
		else
			return true
		end
	else
		return blacklisted
	end
end

function TearFlagsLib.SetCopyBlacklist(source, bool, flag) -- Tells the passed Source whether its blacklist should be passed onto any entity that copies its TearFlags
	local node = flag and tostring(flag:GetFirstIndex()) or "General"
	TearFlagsLib.GetSafeData().copyBlacklist[node] = bool
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
function TearFlagsLib.FireSplitTear(spawner, velocity, player, params)
	spawner = TearFlagsLib.Cast(spawner)
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
		TearFlagsLib.SetTearScale(tear, params.ScaleOverride)
	elseif spawner.Scale then
		TearFlagsLib.SetTearScale(tear, spawner.Scale * (params.ScaleMult or 0.5))
	else
		TearFlagsLib.SetTearScale(tear, tear.Scale * (params.ScaleMult or 0.5))
	end

	tear.Color = params.ColorOverride or spawner.Color
	tear.CollisionDamage = params.DamageOverride or ((spawner.CollisionDamage or player.Damage) * (params.DamageMult or 0.5))
	tear.CanTriggerStreakEnd = params.CanTriggerStreakEnd or false
	Isaac.RunCallbackWithParam(ModCallbacks.MC_POST_FIRE_SPLIT_TEAR, params.SplitTearType or "TearFlagsLibGeneric", tear, spawner, params.SplitTearType or "TearFlagsLibGeneric")

	tear.TearFlags = tear.TearFlags | TearFlagsLib.GetCustomVanillaTearFlags(tear)

	if not params.SkipRemoveOnSplitFlags then
		tear.TearFlags = tear.TearFlags &~ TearFlagsLib.REMOVE_ON_SPLITSHOT_FLAGS
	end

	TearFlagsLib.WipeCustomVanillaTearFlags(tear)

	if params.RemoveFlags then
		tear.TearFlags = tear.TearFlags &~ params.RemoveFlags
	end

	if params.RemoveCustomFlags then
		TearFlagsLib.ClearTearFlags(tear, params.RemoveCustomFlags)
	end

	return tear
end

-- Params is an optional table that can contain every TearFlagsLib.FireSplitTear param, as well as:
	-- number:		NumTears		(Defaults to 14)
	-- boolean:		NoBurstSfx		(Defaults to false)
	-- boolean:		IgnoreShotSpeed (Defaults to false)
function TearFlagsLib.FireSplitTearMonstroBurst(spawner, velocity, player, rng, params)
    local tears = {}
    params = params or {}
    rng = rng or player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)

    for _, tearInfo in ipairs(TearFlagsLib.GetPlayerMonstroBurstInfo(player, params.PositionOverride or spawner.Position, velocity, params.NumTears, rng, params.IgnoreShotSpeed)) do
        local tear = TearFlagsLib.FireSplitTear(spawner, tearInfo.Vel, player, TearFlagsLib.FuzzyReplaceTable(params, {
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
function TearFlagsLib.FireSplitBomb(spawner, velocity, player, params)
	spawner = TearFlagsLib.Cast(spawner)
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
	
	TearFlagsLib.CopyTearFlags(bomb, spawner, TearFlagsLib.WeaponFlag.DR_FETUS, {wipe = true})
	bomb:AddTearFlags(TearFlagsLib.GetCustomVanillaTearFlags(bomb))


	if not params.SkipRemoveOnSplitFlags then
		bomb:ClearTearFlags(TearFlagsLib.REMOVE_ON_SPLITSHOT_FLAGS)
	end

	TearFlagsLib.WipeCustomVanillaTearFlags(bomb)

	if params.RemoveFlags then
		bomb:ClearTearFlags(params.RemoveFlags)
	end

	if params.RemoveCustomFlags then
		TearFlagsLib.ClearTearFlags(bomb, params.RemoveCustomFlags)
	end

	bomb:SetLoadCostumes(true)
	return bomb
end

-- Params is an optional table that can contain every TearFlagsLib.FireSplitBomb param, as well as:
	-- number: NumBombs	(Defaults to 5)
function TearFlagsLib.FireSplitBombMonstroBurst(spawner, velocity, player, rng, params)
	local bombs = {}
	params = params or {}
	rng = rng or player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)

    for _, bombInfo in ipairs(TearFlagsLib.GetMonstroBombBurstInfo(params.PositionOverride or spawner.Position, velocity, params.NumBombs, rng)) do
        local bomb = TearFlagsLib.FireSplitBomb(spawner, bombInfo.Vel, player, TearFlagsLib.FuzzyReplaceTable(params, {
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
function TearFlagsLib.FireSplitLaser(spawner, direction, player, params)
	spawner = TearFlagsLib.Cast(spawner)
	params = params or {}

	TearFlagsLib.FiringSplitLaser = {
		Spawner = spawner,
		Player = player,
		Params = params,
	}

	local variant = params.LaserVariant or (spawner.Type == EntityType.ENTITY_LASER and spawner.Variant) or LaserVariant.THIN_RED
	if TearFlagsLib.IsLaserVariantBrimstone(variant) then
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
function TearFlagsLib.FireSplitLaserMonstroBurst(spawner, direction, player, rng, params)
	local playBurstSfx = params.PlayMonstroBurstSfx
    posOffset = posOffset or Vector(0, -20)

    local lasers = {}

    for _, laserInfo in ipairs(TearFlagsLib.GetMonstroLaserBurstInfo(params.PositionOverride or spawner.Position, direction, params.NumLasers)) do
        local laser = TearFlagsLib.FireSplitLaser(spawner, laserInfo.Dir, player, TearFlagsLib.FuzzyReplaceTable(params, {
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
function TearFlagsLib.EstimateWeaponFlagFromEntity(entity)
	local data = TearFlagsLib.GetSafeData(entity)

	for weapon, func in pairs(TearFlagsLib.WeaponIdentityFunctions) do
		if func(entity) then return weapon end
	end 

	if entity.Type == 2 then
		if data.isBobsHead then
			return TearFlagsLib.WeaponFlag.BOBS_ROTTEN_HEAD
		elseif data.isSharpKey then
			return TearFlagsLib.WeaponFlag.SHARP_KEY
		else
			return TearFlagsLib.WeaponFlag.TEAR
		end
	elseif entity.Type == 3 then
		if entity.Variant == FamiliarVariant.ABYSS_LOCUST then
			return TearFlagsLib.WeaponFlag.LOCUST
		elseif entity.Variant == FamiliarVariant.UMBILICAL_BABY then
			return TearFlagsLib.WeaponFlag.UMBILICAL_WHIP
		end
	elseif entity.Type == 4 then
		return TearFlagsLib.WeaponFlag.DR_FETUS
	elseif entity.Type == 7 then
		return TearFlagsLib.WeaponFlag.LASER
	elseif entity.Type == 8 then
		if TearFlagsLib.IsKnifeVariantTrueKnife(entity.Variant) then
			return TearFlagsLib.WeaponFlag.KNIFE
		elseif TearFlagsLib.IsKnifeVariantClub(entity.Variant) then
			return TearFlagsLib.WeaponFlag.CLUB
		elseif TearFlagsLib.IsKnifeVariantSword(entity.Variant) then
			return TearFlagsLib.WeaponFlag.SWORD
		end
	elseif entity.Type == 1000 then
		if entity.Variant == EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL then
			return TearFlagsLib.WeaponFlag.AQUARIUS
		elseif entity.Variant == EffectVariant.ROCKET then
			return TearFlagsLib.WeaponFlag.EPIC_FETUS
		elseif entity.Variant == EffectVariant.SMALL_ROCKET then
			return TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS
		elseif entity.Variant == EffectVariant.BRIMSTONE_SWIRL or entity.Variant == EffectVariant.TECH_DOT then
			return TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER
		elseif entity.Variant == EffectVariant.BRIMSTONE_BALL then
			return TearFlagsLib.WeaponFlag.BRIMSTONE_BALL
		elseif entity.Variant == EffectVariant.DARK_SNARE then
			return TearFlagsLib.WeaponFlag.DARK_ARTS
		elseif entity.Variant == EffectVariant.RIFT then
			return TearFlagsLib.WeaponFlag.OCULAR_RIFT
		elseif data.dummyWeaponIdentity == TearFlagsLib.WeaponFlag.HEMOPTYSIS then
			return TearFlagsLib.WeaponFlag.HEMOPTYSIS
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
function TearFlagsLib.DamageEntity(entity, amount, damageFlags, weaponEntity, params)
	local damageMult = 1
	local damageAdd = 0
	local damageFlat = 0
	params = params or {}

	TearFlagsLib.GetTearFlags(weaponEntity):ForEach(function(flag)
		local flagParams = TearFlagsLib.GetTearFlagParams(weaponEntity, flag)
		if flagParams.DamageParams then
			damageFlags = damageFlags | (flagParams.DamageParams.DamageFlags or 0)
			damageMult = damageMult * (flagParams.DamageParams.DamageMult or 1)
			damageAdd = damageAdd + (flagParams.DamageParams.ExtraDamage or 0)
			damageFlat = damageFlat + (flagParams.DamageParams.ExtraDamageFlat or 0)
		end
	end)

	if not params.IgnoreVanillaDamageFlags then damageFlags = damageFlags | TearFlagsLib.GetVanillaTearFlagDamageFlags(weaponEntity) end
	amount = (amount + damageAdd) * damageMult + damageFlat
	entity:TakeDamage(amount, damageFlags, EntityRef(params.DamageSource or weaponEntity), params.DamageCooldown or 0)
end

function TearFlagsLib.AddEntityToUpdateList(entity, listKey)
	TearFlagsLib.UpdateLists[listKey] = TearFlagsLib.UpdateLists[listKey] or {}
	table.insert(TearFlagsLib.UpdateLists[listKey], entity)
end

function TearFlagsLib.RemoveEntityFromUpdateList(entity, listKey)
	TearFlagsLib.RemoveUserDataValueFromTable(entity, TearFlagsLib.EntityLists[listKey] or {})
end

function TearFlagsLib.SetTearCanHitMultipleTimes(tear, canHit, frequency) -- Ludovico Technique tears are allowed to damage the same entity multiple times. This allows you to set a frequency by which any tear can do the same, managed by TearFlagsLib
	if not tear:ToTear() then return end -- This one really DOES have to be a tear
	if canHit == nil then canHit = true end

	TearFlagsLib.GetSafeData(tear).pseudoLudo = {
		canReset = canHit,
		frequency = frequency, -- Frequency defaults to player fire rate if not set
	}
end

-- Only Isaac gets the benefits of Teardrop Charm. Familiars like Incubus and Twisted Pair do not
-- The entity which is polling for TearFlags therefore must be passed in order to determine when not to include this bonus
function TearFlagsLib.GetRealLuck(player, testEntity)
	TearFlagsLib.LuckCache = 0
	player:AddCacheFlags(CacheFlag.CACHE_LUCK)
	player:EvaluateItems()

	if testEntity and TearFlagsLib.WasEntityFiredByPlayerMimic(testEntity, true) then
		return TearFlagsLib.LuckCache -- This is a familiar attack, do not apply Teardrop Charm bonuses
	end

	if player:HasTrinket(TrinketType.TRINKET_TEARDROP_CHARM) then
		TearFlagsLib.LuckCache = TearFlagsLib.LuckCache + 2
		TearFlagsLib.LuckCache = TearFlagsLib.LuckCache + 2 * player:GetTrinketMultiplier(TrinketType.TRINKET_TEARDROP_CHARM)
	end

	return TearFlagsLib.LuckCache
end

-- Linearly scales chance from baseChance -> maxChance as rawLuck scales from 0 -> luckRequirement
function TearFlagsLib.GetChance(rawLuck, baseChance, maxChance, luckRequirement, itemScalerN)
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

function TearFlagsLib.DumpFlags()
	for key, flag in pairs(TearFlagsLib.Flag) do
		print(key, flag)
	end
end

include(TearFlagsLib.Source .. ".library")
include(TearFlagsLib.Source .. ".callbacks")

TearFlagsLib.RegisterCallbacks()

print("Loaded TearFlagsLib Version:", version)