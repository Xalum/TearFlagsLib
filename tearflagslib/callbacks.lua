TearFlagsLib.CallbackFuncs = {}

function TearFlagsLib.ApplyWeaponTearFlags(entity, player, source, weaponFlag, tryVanillaFlags, hitbox)
	-- Furniture is hard-blacklisted against receiving the effects of tearflags, you NEVER want to affect this stuff anyway so it's really stupid that it gets passed through the vanilla APPLY_TEARFLAG_EFFECTS callback
	if entity.Type == EntityType.ENTITY_GENERIC_PROP or TearFlagsLib.IsEntityBlacklisted(entity, source) or not entity:ToNPC() then return false end
	entity = entity:ToNPC()

	if Isaac.RunCallbackWithParam(TearFlagsLib.Callback.PRE_APPLY_TEARFLAG_EFFECTS, entity.Type, entity, player, source, weaponFlag, hitbox) then
		return false
	end

	local recursionKey = TearFlagsLib.SetAntiRecursion()
	for _, callbackData in ipairs(Isaac.GetCallbacks(TearFlagsLib.Callback.APPLY_TEARFLAG_EFFECT)) do
		if not callbackData.Param or (TearFlagsLib.HasTearFlags(source, callbackData.Param) and not TearFlagsLib.IsEntityBlacklisted(entity, source, callbackData.Param)) then
			callbackData.Function(callbackData.Mod, entity, player, source, weaponFlag, TearFlagsLib.GetTearFlagParams(source, callbackData.Param), hitbox)
		end
	end

	Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_APPLY_TEARFLAG_EFFECTS, entity.Type, entity, player, source)
	TearFlagsLib.ClearAntiRecursion(recursionKey)

	if not tryVanillaFlags then return true end
	local flags = TearFlagsLib.GetCustomVanillaTearFlags(source) &~ TearFlagsLib.AgnosticGetVanillaTearFlags(source, true)
	if flags == TearFlagsLib.BitSetZero then return true end

	local params = TearFlagsLib.GetCustomVanillaTearFlagParams(source)
	TearFlagsLib.ApplyVanillaTearFlagEffectsToEntity(entity, flags, player, source, TearFlagsLib.FuzzyReplaceTable({DamageOverride = source.CollisionDamage}, params))

	return true
end

function TearFlagsLib.ApplyWeaponExplosionTearFlags(explosion, player, sourceBomb, weaponFlag)
	local recursionKey = TearFlagsLib.SetAntiRecursion()
	for _, callbackData in ipairs(Isaac.GetCallbacks(TearFlagsLib.Callback.APPLY_EXPLOSION_TEARFLAG_EFFECT)) do
		if not callbackData.Param or TearFlagsLib.HasTearFlags(sourceBomb, callbackData.Param) then
			callbackData.Function(callbackData.Mod, explosion, player, sourceBomb, weaponFlag, TearFlagsLib.GetTearFlagParams(sourceBomb, callbackData.Param))
		end
	end
	TearFlagsLib.ClearAntiRecursion(recursionKey)
end

function TearFlagsLib.PollTearFlags(weaponEntity, player, weaponFlag)
	TearFlagsLib.IsPollingForTearFlags = weaponFlag

	local cancel = Isaac.RunCallbackWithParam(TearFlagsLib.Callback.PRE_POLL_TEARFLAGS, weaponFlag, TearFlagsLib.Cast(weaponEntity), player, weaponFlag)
	if cancel then
		TearFlagsLib.IsPollingForTearFlags = nil
		return false
	end

	Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POLL_TEARFLAGS, weaponFlag, TearFlagsLib.Cast(weaponEntity), player, weaponFlag)
	Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_POLL_TEARFLAGS, weaponFlag, TearFlagsLib.Cast(weaponEntity), player, weaponFlag)

	TearFlagsLib.IsPollingForTearFlags = nil
	TearFlagsLib.GetSafeData(weaponEntity).checkedFlags = true

	return true
end


function TearFlagsLib.PollLocustTearFlags(locust, player)
	TearFlagsLib.IsPollingForTearFlags = TearFlagsLib.WeaponFlag.LOCUST

	Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POLL_LOCUST_TEARFLAGS, locust.SubType, locust:ToFamiliar(), player)

	TearFlagsLib.IsPollingForTearFlags = nil
	TearFlagsLib.GetSafeData(locust).checkedFlags = true
end

function TearFlagsLib.PollChancelessTearFlags(weaponEntity, player, weaponFlag)
	TearFlagsLib.IsPollingForTearFlags = weaponFlag

	local oldColour = weaponEntity.Color

	if weaponEntity.TearFlags then
		weaponEntity.TearFlags = weaponEntity.TearFlags &~ TearFlagsLib.GuarenteedFlagTracker
	end

	Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POLL_CHANCELESS_TEARFLAGS, weaponFlag, TearFlagsLib.Cast(weaponEntity), player, weaponFlag)

	TearFlagsLib.IsPollingForTearFlags = nil
	TearFlagsLib.GetSafeData(weaponEntity).checkedFlags = true
	weaponEntity.Color = oldColour
end

-- Weapons spawned by C Section fetuses can and will attempt to deal damage before the fetus has even finished firing
-- These little SHITS will deal damage before the fetus even polls for its own tear flags
-- The ramifications of polling for tearflags this early scare me
-- (Also used for Trisagion)
function TearFlagsLib.EmergencyPollTearFlags(tear)
	if not TearFlagsLib.GetSafeData(tear).checkedForFlags and TearFlagsLib.WasEntityFiredByPlayerMimic(tear) then
		TearFlagsLib.PollTearFlags(tear:ToTear(), TearFlagsLib.GetTearPlayer(tear), TearFlagsLib.WeaponFlag.TEAR)
		Isaac.RunCallback(TearFlagsLib.Callback.POST_REAL_FIRE_TEAR, tear:ToTear(), TearFlagsLib.GetTearPlayer(tear))
		TearFlagsLib.GetSafeData(tear).checkedForFlags = true
	end
end


-- Below this point is the inner workings of the TearFlagsLib beast, venture at your own risk or stay in the comfort and safety above

-- POST_REAL_FIRE_TEAR
TearFlagsLib.CallbackFuncs.PostFireTear = function(_, tear)
	if TearFlagsLib.WasEntityFiredByPlayerMimic(tear) and not TearFlagsLib.GetSafeData(tear).checkedForFlags then
		TearFlagsLib.PollTearFlags(tear, TearFlagsLib.GetTearPlayer(tear), TearFlagsLib.WeaponFlag.TEAR)
		Isaac.RunCallback(TearFlagsLib.Callback.POST_REAL_FIRE_TEAR, tear, TearFlagsLib.GetTearPlayer(tear))
	end

	TearFlagsLib.GetSafeData(tear).checkedForFlags = true
end

local fatesRewardTears = {}
TearFlagsLib.CallbackFuncs.PostTearInit = function(_, tear) -- This is sketchy af ngl
	if not TearFlagsLib.WasEntityFiredByPlayerMimic(tear) then return end

	if tear.Variant == TearVariant.BOBS_HEAD and TearFlagsLib.PlayerHasItemEffect(TearFlagsLib.GetTearPlayer(tear), CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD) then
		TearFlagsLib.GetSafeData(tear).isBobsHead = true
		TearFlagsLib.PollTearFlags(tear, TearFlagsLib.GetTearPlayer(tear), TearFlagsLib.WeaponFlag.BOBS_ROTTEN_HEAD)
	elseif (tear.Variant == TearVariant.KEY or tear.Variant == TearVariant.KEY_BLOOD) and TearFlagsLib.PlayerHasItemEffect(TearFlagsLib.GetTearPlayer(tear), CollectibleType.COLLECTIBLE_SHARP_KEY) then
		TearFlagsLib.GetSafeData(tear).isSharpKey = true
		TearFlagsLib.PollTearFlags(tear, TearFlagsLib.GetTearPlayer(tear), TearFlagsLib.WeaponFlag.SHARP_KEY)
	elseif tear.SpawnerType == EntityType.ENTITY_FAMILIAR and tear.SpawnerVariant == FamiliarVariant.FATES_REWARD and TearFlagsLib.WasEntityFiredByPlayerMimic(tear, true) then
		TearFlagsLib.GetSafeData(tear).isFatesReward = true
		table.insert(fatesRewardTears, tear)
	end
end

TearFlagsLib.CallbackFuncs.PostFireFatesReward = function()
	-- Fate's Fucking Reward
	for _, tear in pairs(fatesRewardTears) do
		if tear:Exists() and tear.FrameCount == 0 and not TearFlagsLib.GetSafeData(tear).checkedForFlags then
			TearFlagsLib.PollTearFlags(tear, TearFlagsLib.GetTearPlayer(tear), TearFlagsLib.WeaponFlag.TEAR)
			Isaac.RunCallback(TearFlagsLib.Callback.POST_REAL_FIRE_TEAR, tear, TearFlagsLib.GetTearPlayer(tear))
		end
		TearFlagsLib.GetSafeData(tear).checkedForFlags = true
	end
	fatesRewardTears = {}
end

-- POST_THROW_KNIFE/POST_CATCH_KNIFE
TearFlagsLib.CallbackFuncs.PostThrowCatchKnife = function(_, knife)
	if TearFlagsLib.WasEntityFiredByPlayerMimic(knife) then
		local data = TearFlagsLib.GetSafeData(knife)
		local isFlying = knife:IsFlying()

		if isFlying then
			local isReturning = data.lastFrameDistance and data.lastFrameDistance > knife.Position:Distance(knife.SpawnerEntity.Position)
			
			if not data.lastFrameWasFlying then
				if TearFlagsLib.IsKnifeSwingableAndThrowable(knife) then
					Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_THROW_CLUB, knife.Variant, knife, TearFlagsLib.GetTearPlayer(knife))
					
					-- Only Clubs copy flags to Lasers spawned by their Technology synergy, Knives use "Chanceless Lasers"
					-- One shudders to think what the fuck they were thinking
					for _, laser in pairs(Isaac.FindByType(7)) do
						if laser.FrameCount == 0 and TearFlagsLib.IsLaserThrownClubTechnology(laser:ToLaser(), knife) then
							TearFlagsLib.GetSafeData(laser).checkedFlags = true
							TearFlagsLib.CopyTearFlags(laser, knife, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
						end
					end
				else
					Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_THROW_KNIFE, knife.Variant, knife, TearFlagsLib.GetTearPlayer(knife))
				end
			end

			if isReturning and not data.lastFrameWasReturning then
				data.lastFrameWasReturning = true
			end

			data.lastFrameWasReturning = isReturning
		elseif data.lastFrameWasFlying then
			if TearFlagsLib.IsKnifeSwingableAndThrowable(knife) then
				Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_CATCH_CLUB, knife.Variant, knife, TearFlagsLib.GetTearPlayer(knife))
			else
				Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_CATCH_KNIFE, knife.Variant, knife, TearFlagsLib.GetTearPlayer(knife))
			end

			TearFlagsLib.WipeTearFlags(knife, true)
			data.lastFrameWasReturning = false
		end

		data.lastFrameWasFlying = isFlying
		data.lastFrameDistance = knife.Position:Distance(knife.SpawnerEntity.Position)
	end
end

TearFlagsLib.CallbackFuncs.PostThrowCatchKnife2 = function(_, knife)
	if knife.FrameCount == 0 and TearFlagsLib.WasEntityFiredByPlayerMimic(knife) then
		Isaac.RunCallbackWithParam(TearFlagsLib.Callback.POST_THROW_KNIFE, knife.Variant, knife, TearFlagsLib.GetTearPlayer(knife))
	end
end

TearFlagsLib.CallbackFuncs.KnifeUpdate = function(_, knife)
	if TearFlagsLib.WasEntityFiredByPlayerMimic(knife) and TearFlagsLib.DoesKnifeVariantPollEveryFrame(knife.Variant) then
		TearFlagsLib.WipeTearFlags(knife)
		TearFlagsLib.PollTearFlags(knife, TearFlagsLib.GetTearPlayer(knife), TearFlagsLib.WeaponFlag.KNIFE)
	end
end

-- PRE_SWING_CLUB
TearFlagsLib.CallbackFuncs.ClubHitboxInit = function(_, knife)
	if knife.FrameCount > 0 then return end
	if not TearFlagsLib.WasEntityFiredByPlayerMimic(knife) or not TearFlagsLib.CanClubVariantHaveTearEffects(knife.Variant) then return end

	local parent = knife:GetHitboxParentKnife()

	if not parent then -- Evil Eye, Tainted Maggie
		TearFlagsLib.PollTearFlags(knife, TearFlagsLib.GetTearPlayer(knife), TearFlagsLib.WeaponFlag.CLUB)
	else
		if parent:GetSprite():GetFrame() > 0 then -- Cursed Eye
			knife.Color = parent.Color
			TearFlagsLib.CopyTearFlags(knife, parent, TearFlagsLib.WeaponFlag.CLUB, {wipe = true})
		elseif TearFlagsLib.IsClubCSectionClub(parent) then
			knife.Color = parent.Color
			TearFlagsLib.CopyTearFlags(knife, parent.Parent, TearFlagsLib.WeaponFlag.CLUB, {wipe = true})
		else -- Everything else
			TearFlagsLib.PollTearFlags(knife, TearFlagsLib.GetTearPlayer(knife), TearFlagsLib.WeaponFlag.CLUB)
			parent.Color = knife.Color
			TearFlagsLib.CopyTearFlags(parent, knife, TearFlagsLib.WeaponFlag.CLUB, {wipe = true})
		end
	end

	Isaac.RunCallback(TearFlagsLib.Callback.PRE_SWING_CLUB, knife, TearFlagsLib.GetTearPlayer(knife))
end

TearFlagsLib.CallbackFuncs.PostFireSword = function(_, sword)
	if TearFlagsLib.WasEntityFiredByPlayerMimic(sword) then
		TearFlagsLib.PollTearFlags(sword, TearFlagsLib.GetTearPlayer(sword), TearFlagsLib.WeaponFlag.SWORD)
	end
end

-- POST_SPAWN_AQUARIUS
TearFlagsLib.CallbackFuncs.PostSpawnAquarius = function(_, effect)
	if TearFlagsLib.WasEntityFiredByPlayerMimic(effect) then
		TearFlagsLib.PollTearFlags(effect, TearFlagsLib.GetTearPlayer(effect), TearFlagsLib.WeaponFlag.AQUARIUS)
	end
end

TearFlagsLib.CallbackFuncs.BrimstoneBallUpdate = function(_, effect)
	if TearFlagsLib.WasEntityFiredByPlayerMimic(effect) then
		TearFlagsLib.WipeTearFlags(effect)
		TearFlagsLib.PollTearFlags(effect, TearFlagsLib.GetTearPlayer(effect), TearFlagsLib.WeaponFlag.BRIMSTONE_BALL)
	end
end

-- POST_FIRE_LASER
function TearFlagsLib.EvaluateLaserTearFlags(laser)
	if TearFlagsLib.GetSafeData(laser).CanRollForFlags then
		TearFlagsLib.PollTearFlags(laser, TearFlagsLib.GetTearPlayer(laser), TearFlagsLib.WeaponFlag.LASER)
	end
end

TearFlagsLib.CallbackFuncs.PostFireLaser = function(_, laser)
	-- For some ungodly reason, Nicalis in their infinite wisdom decided to make it so that Lasers are capable of dealing damage BEFORE THEY FINISH INITIALISING
	-- This means that Lasers are capable of dealing damage before their usual TearFlag rolling
	-- As such, on top of rolling for flags every frame, lasers must also roll for flags when they're fired, which requires the use of THREE SEPARATE REPENTOGON CALLBACKS

	-- On the bright side, since REPENTOGON adds callbacks for Firing Lasers, I can also use this to tag which laser entities should recieve TearFlags
	-- For some goddamn reason, not every player-spawned laser gets random flags, can anyone on this Earth explain why? Probably not!

	-- On the not bright side, there are a couple of situations where I SHOULD be polling for flags but REPENTOGON doesn't give me easy access
	-- I will sort these out later (Later came and I kicked its ass!)

	if TearFlagsLib.FiringSplitLaser then
		TearFlagsLib.GetSafeData(laser).checkedFlags = true
		local source = TearFlagsLib.FiringSplitLaser.Spawner
		local params = TearFlagsLib.FiringSplitLaser.Params

		laser:ClearTearFlags(laser.TearFlags)
		TearFlagsLib.CopyTearFlags(laser, source, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
		laser:AddTearFlags((source.TearFlags or source.Flags or TearFlagsLib.BitSetZero))
		laser:AddTearFlags(TearFlagsLib.GetCustomVanillaTearFlags(source))
		laser:ClearTearFlags(params.RemoveFlags or TearFlagsLib.BitSetZero)
		TearFlagsLib.ClearTearFlags(laser, params.RemoveCustomFlags or TearFlagsLib.BitSetInfinity.Zero)
		TearFlagsLib.WipeCustomVanillaTearFlags(laser)
	elseif TearFlagsLib.WasEntityFiredByPlayerMimic(laser) and not TearFlagsLib.IsLaserFinger(laser) then
		TearFlagsLib.GetSafeData(laser).CanRollForFlags = true
		TearFlagsLib.EvaluateLaserTearFlags(laser)
	end
end

TearFlagsLib.CallbackFuncs.CatchMegaBlast = function(_, laser)
	if laser.Variant ~= LaserVariant.GIANT_RED and laser.Variant ~= LaserVariant.GIANT_BRIM_TECH then return end
	if not TearFlagsLib.WasEntityFiredByPlayerMimic(laser) then return end

	TearFlagsLib.GetSafeData(laser).CanRollForFlags = true
	TearFlagsLib.EvaluateLaserTearFlags(laser)
end

TearFlagsLib.CallbackFuncs.CatchChancelessLasersNoHit = function(_, laser)
	if not TearFlagsLib.GetSafeData(laser).checkedFlags and TearFlagsLib.DidLaserCopyPlayerFlags(laser) then
		TearFlagsLib.PollChancelessTearFlags(laser, TearFlagsLib.GetTearPlayer(laser), TearFlagsLib.WeaponFlag.LASER)
	end
end

TearFlagsLib.CallbackFuncs.UpdateLaser = function(_, laser)
	if not TearFlagsLib.GetSafeData(laser).CanRollForFlags then return end

	TearFlagsLib.WipeTearFlags(laser)
	TearFlagsLib.EvaluateLaserTearFlags(laser)
end

TearFlagsLib.CallbackFuncs.LaserSwirlUpdate = function(_, effect)
	local player = TearFlagsLib.GetTearPlayer(effect)

	if player then
		TearFlagsLib.WipeTearFlags(effect)
		TearFlagsLib.PollTearFlags(effect, player, TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER)
	end
end

-- Lasers fired by C Section fetuses (And Forgotten Swings x Technology)
TearFlagsLib.CallbackFuncs.CatchFetusLaserNoHit = function(_, laser)
	if TearFlagsLib.ShouldCopyLaserFlagsOnFirstUpdate(laser) then
		TearFlagsLib.GetSafeData(laser).checkedFlags = true
		TearFlagsLib.CopyTearFlags(laser, laser.Parent, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
	end
end

-- Spirit swords held by C Section fetuses
TearFlagsLib.CallbackFuncs.CatchFetusSpiritSword = function(_, sword)
	if sword.FrameCount > 0 or TearFlagsLib.GetSafeData(sword).checkedFlags then return end
	if TearFlagsLib.IsSwordCSectionSword(sword) then
		TearFlagsLib.EmergencyPollTearFlags(sword.Parent)
		TearFlagsLib.GetSafeData(sword).checkedFlags = true
		TearFlagsLib.CopyTearFlags(sword, sword.Parent, TearFlagsLib.WeaponFlag.SWORD, {wipe = true})
	end
end

-- EVALUATE_DARK_ARTS_FLAGS
TearFlagsLib.CallbackFuncs.EvaluateDarkArtsFlags = function(_, entity, amount, flags, source, cooldown)
	if TearFlagsLib.AntiRecursion then return end

	if source and source.Type == 1000 and source.Variant == EffectVariant.DARK_SNARE and source.Entity and source.Entity.SpawnerEntity and not TearFlagsLib.GetSafeData(source.Entity).evaluatedTearFlags then
		local snare = source.Entity
		local player = TearFlagsLib.GetTearPlayer(snare)
		TearFlagsLib.PollTearFlags(snare, player, TearFlagsLib.WeaponFlag.DARK_ARTS)

		TearFlagsLib.GetSafeData(snare).evaluatedTearFlags = true
		TearFlagsLib.ApplyWeaponTearFlags(entity, player, snare, TearFlagsLib.WeaponFlag.DARK_ARTS, true)
	end
end

-- Locusts
TearFlagsLib.CallbackFuncs.EvaluateLocust = function(_, entity, amount, flags, source, cooldown)
	if TearFlagsLib.AntiRecursion then return end

	if source.Type == EntityType.ENTITY_FAMILIAR and source.Variant == FamiliarVariant.ABYSS_LOCUST then
		local locust = source.Entity:ToFamiliar()
		TearFlagsLib.PollLocustTearFlags(locust, locust.Player)
		TearFlagsLib.ApplyWeaponTearFlags(entity, locust.Player, locust, TearFlagsLib.WeaponFlag.LOCUST, true)
		TearFlagsLib.WipeTearFlags(source.Entity)
	end
end

-- Umbilical Whip
TearFlagsLib.CallbackFuncs.UmbilicalWhipInit = function(_, familiar)
	TearFlagsLib.PollTearFlags(familiar, familiar.Player, TearFlagsLib.WeaponFlag.UMBILICAL_WHIP)
end

-- Dr. Fetus
TearFlagsLib.CallbackFuncs.PostFireBomb = function(_, bomb)
	TearFlagsLib.PollTearFlags(bomb, TearFlagsLib.GetTearPlayer(bomb), TearFlagsLib.WeaponFlag.DR_FETUS)
end

-- Epic Fetus
TearFlagsLib.CallbackFuncs.PostFireAirstrike = function(_, effect)
	TearFlagsLib.PollTearFlags(effect, TearFlagsLib.GetTearPlayer(effect), TearFlagsLib.WeaponFlag.EPIC_FETUS)
end

TearFlagsLib.CallbackFuncs.PostFireSmallAirstrike = function(_, effect)
	TearFlagsLib.PollTearFlags(effect, TearFlagsLib.GetTearPlayer(effect), TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS)
end

-- Hemoptysis
TearFlagsLib.CallbackFuncs.PreHemoptysis = function(_, source)
	local player = source:ToPlayer() or TearFlagsLib.GetTearPlayer(source)

	TearFlagsLib.hemoptysisCache = source
	TearFlagsLib.hemoptysisDummy = TearFlagsLib.SpawnDummyEntity(player, TearFlagsLib.WeaponFlag.HEMOPTYSIS)
	TearFlagsLib.PollTearFlags(TearFlagsLib.hemoptysisDummy, player, TearFlagsLib.WeaponFlag.HEMOPTYSIS)
end

TearFlagsLib.CallbackFuncs.PostHemoptysis = function()
	TearFlagsLib.hemoptysisCache = nil
	TearFlagsLib.hemoptysisDummy = nil
end

-- Monstro's Lung x Technology
TearFlagsLib.CallbackFuncs.PreMonstroLaser = function(_, laser)
	if TearFlagsLib.GetTearPlayer(laser):HasCollectible(CollectibleType.COLLECTIBLE_MONSTROS_LUNG) and (TearFlagsLib.HasAnyTearFlags(laser) or TearFlagsLib.HasAnyCustomVanillaTearFlags(laser)) then
		TearFlagsLib.monstroLaser = laser
	end
end

TearFlagsLib.CallbackFuncs.PostMonstroLaser = function()
	TearFlagsLib.monstroLaser = nil
end

TearFlagsLib.CallbackFuncs.CatchMonstroLaser = function(_, laser)
	if TearFlagsLib.monstroLaser and laser.Position:Distance(TearFlagsLib.monstroLaser.EndPoint) < 0.01 then -- Unfortunately this is kind of a risky assumption all in all but Isaac is held together with sticks and hope so w/e man
		TearFlagsLib.GetSafeData(laser).checkedFlags = true
		TearFlagsLib.CopyTearFlags(laser, TearFlagsLib.monstroLaser, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
	end
end

TearFlagsLib.CallbackFuncs.CatchTrisagionLaser = function(_, laser)
	if laser.FrameCount == 1 and TearFlagsLib.IsLaserTrisagion(laser) then
		if not TearFlagsLib.GetSafeData(laser).checkedFlags then
			TearFlagsLib.GetSafeData(laser).checkedFlags = true
			TearFlagsLib.CopyTearFlags(laser, laser.Parent, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
		end
	end
end

-- APPLY_TEARFLAG_EFFECT
-- Generic
TearFlagsLib.CallbackFuncs.GenericCatchApplyTearFlags = function(_, npc, position, flags, source, damage)

	-- What a mess
	if not npc or not source then return end
	local weapon = TearFlagsLib.Cast(source)
	if TearFlagsLib.IsEntity.Sword(weapon) and weapon.SubType == 4 then weapon = weapon:GetHitboxParentKnife() or weapon end
	if not (TearFlagsLib.HasAnyTearFlags(weapon) or TearFlagsLib.HasAnyCustomVanillaTearFlags(weapon)) or TearFlagsLib.IsEntityBlacklisted(npc, weapon) then return end
	local player = weapon.Player or TearFlagsLib.GetTearPlayer(weapon)

	-- The real shit
	local weaponFlag
	local bonusArg

	if TearFlagsLib.IsEntity.Tear(weapon) then -- The Daily Driver/Ludovico Technique/Flat Stone
		weaponFlag = TearFlagsLib.WeaponFlag.TEAR
	elseif TearFlagsLib.IsEntity.Gello(weapon) then -- Gello
		weaponFlag = TearFlagsLib.WeaponFlag.UMBILICAL_WHIP
	elseif TearFlagsLib.IsEntity.Knife(weapon) then -- Mom's Knife/Sumptorium/Thrown Clubs (Forgotten/Berserk)
		weaponFlag = TearFlagsLib.WeaponFlag.KNIFE
	elseif TearFlagsLib.IsEntity.Club(weapon) then -- Berserk/Notched Axe/Forgotten
		weaponFlag = TearFlagsLib.WeaponFlag.CLUB
	elseif TearFlagsLib.IsEntity.Sword(weapon) then -- Spirit Sword
		weaponFlag, bonusArg = TearFlagsLib.WeaponFlag.SWORD, weapon.SubType == 4 and source:ToKnife() or nil
	elseif TearFlagsLib.IsEntity.Aquarius(weapon) then -- Aquarius
		weaponFlag = TearFlagsLib.WeaponFlag.AQUARIUS
	elseif TearFlagsLib.IsEntity.LaserSwirl(weapon) then -- Anti-Gravity/Lasers
		weaponFlag = TearFlagsLib.WeaponFlag.ANTI_GRAV_LASER
	elseif TearFlagsLib.IsEntity.BrimstoneBall(weapon) then -- Forgotten x Brimstone
		weaponFlag = TearFlagsLib.WeaponFlag.BRIMSTONE_BALL
	end

	if weaponFlag then
		TearFlagsLib.ApplyWeaponTearFlags(npc, player, weapon, weaponFlag, true, bonusArg)
	end

	-- print(source.Type, source.Variant, source.SubType)
end

-- Lasers
TearFlagsLib.CallbackFuncs.PreLaserCollision = function(_, laser, collider)
	if TearFlagsLib.ShouldPollLaserFlagsOnApply(laser) then
		if TearFlagsLib.IsLaserTrisagion(laser) then
			TearFlagsLib.EmergencyPollTearFlags(laser.Parent)
			TearFlagsLib.GetSafeData(laser).checkedFlags = true
			TearFlagsLib.CopyTearFlags(laser, laser.Parent, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
		elseif TearFlagsLib.IsLaserCSectionTechnology(laser) then
			local fetus

			if laser.Parent.Type == 2 then
				fetus = laser.Parent
			end

			fetus = fetus or TearFlagsLib.EstimateCSectionParent(laser)
			if fetus then
				TearFlagsLib.EmergencyPollTearFlags(fetus)
				TearFlagsLib.GetSafeData(laser).checkedFlags = true
				TearFlagsLib.CopyTearFlags(laser, fetus, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
			end
		elseif TearFlagsLib.IsLaserClubTechnology(laser) then
			TearFlagsLib.GetSafeData(laser).checkedFlags = true
			TearFlagsLib.CopyTearFlags(laser:ToLaser(), laser.Parent, TearFlagsLib.WeaponFlag.LASER, {wipe = true})
		else
			TearFlagsLib.GetSafeData(laser).CanRollForFlags = true
			TearFlagsLib.EvaluateLaserTearFlags(laser:ToLaser())
		end
	end

	if TearFlagsLib.DidLaserCopyPlayerFlags(laser) and not TearFlagsLib.GetSafeData(laser).checkedFlags then
		TearFlagsLib.PollChancelessTearFlags(laser:ToLaser(), TearFlagsLib.GetTearPlayer(laser), TearFlagsLib.WeaponFlag.LASER)
	end
end

TearFlagsLib.CallbackFuncs.ApplyLaserFlags = function(_, npc, position, flags, source, damage)
	if TearFlagsLib.HasAnyTearFlags(source) or TearFlagsLib.HasAnyCustomVanillaTearFlags(source) then
		TearFlagsLib.ApplyWeaponTearFlags(npc, TearFlagsLib.GetTearPlayer(source), source, TearFlagsLib.WeaponFlag.LASER, true)
	end
end

-- Ocular Rift
TearFlagsLib.CallbackFuncs.ApplyOcularRiftFlags = function(_, npc, position, flags, source, damage)
	if TearFlagsLib.IsEntityOcularRift(source) then
		local player = TearFlagsLib.GetTearPlayer(source)
		local color = source.Color

		TearFlagsLib.WipeTearFlags(source)
		TearFlagsLib.PollTearFlags(source, player, TearFlagsLib.WeaponFlag.OCULAR_RIFT)
		TearFlagsLib.ApplyWeaponTearFlags(npc, player, source, TearFlagsLib.WeaponFlag.OCULAR_RIFT, true)

		source.Color = color
	end
end

-- Hemoptysis
TearFlagsLib.CallbackFuncs.ApplyHemoptysisFlags = function(_, npc, position, flags, source, damage)
	if TearFlagsLib.hemoptysisCache and GetPtrHash(source) == GetPtrHash(TearFlagsLib.hemoptysisCache) then
		local player = source:ToPlayer() or TearFlagsLib.GetTearPlayer(source)

		if not TearFlagsLib.hemoptysisDummy then
			TearFlagsLib.hemoptysisDummy = TearFlagsLib.SpawnDummyEntity(player, TearFlagsLib.WeaponFlag.HEMOPTYSIS)
			TearFlagsLib.PollTearFlags(TearFlagsLib.hemoptysisDummy, player, TearFlagsLib.WeaponFlag.HEMOPTYSIS)
		end

		TearFlagsLib.ApplyWeaponTearFlags(npc, player, TearFlagsLib.hemoptysisDummy, TearFlagsLib.WeaponFlag.HEMOPTYSIS, true)
	end
end

-- Dr. Fetus
TearFlagsLib.CallbackFuncs.DrFetusDamage = function(_, entity, amount, flags, source, cooldown)
	if TearFlagsLib.AntiRecursion then return end
	if source.Type ~= 4 or not source.Entity:ToBomb().IsFetus or not (TearFlagsLib.HasAnyTearFlags(source.Entity) or TearFlagsLib.HasAnyCustomVanillaTearFlags(source.Entity)) then return end

	if flags & DamageFlag.DAMAGE_EXPLOSION > 0 then
		TearFlagsLib.ApplyWeaponTearFlags(entity, TearFlagsLib.GetTearPlayer(source.Entity), source.Entity:ToBomb(), TearFlagsLib.WeaponFlag.DR_FETUS, true)
	end
end

-- Epic Fetus
TearFlagsLib.CallbackFuncs.EpicFetusDamage = function(_, entity, amount, flags, source, cooldown)
	if TearFlagsLib.AntiRecursion then return end
	if source.Type ~= 1000 or source.Variant ~= EffectVariant.ROCKET or not (TearFlagsLib.HasAnyTearFlags(source.Entity) or TearFlagsLib.HasAnyCustomVanillaTearFlags(source.Entity)) then return end

	if flags & DamageFlag.DAMAGE_EXPLOSION > 0 then
		TearFlagsLib.ApplyWeaponTearFlags(entity, TearFlagsLib.GetTearPlayer(source.Entity), source.Entity:ToEffect(), TearFlagsLib.WeaponFlag.EPIC_FETUS, true)
	end
end

TearFlagsLib.CallbackFuncs.ClubEpicFetusDamage = function(_, entity, amount, flags, source, cooldown)
	if TearFlagsLib.AntiRecursion then return end
	if source.Type ~= 1000 or source.Variant ~= EffectVariant.SMALL_ROCKET or not (TearFlagsLib.HasAnyTearFlags(source.Entity) or TearFlagsLib.HasAnyCustomVanillaTearFlags(source.Entity)) then return end

	if flags & DamageFlag.DAMAGE_EXPLOSION > 0 then
		TearFlagsLib.ApplyWeaponTearFlags(entity, TearFlagsLib.GetTearPlayer(source.Entity), source.Entity:ToEffect(), TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS, true)
	end
end

TearFlagsLib.CallbackFuncs.CatchIpecac = function(_, tear)
	if tear.TearFlags & TearFlagsLib.EXPLOSIVE_TEARFLAGS ~= TearFlags.TEAR_NORMAL then
		local weapon = TearFlagsLib.GetSafeData(tear).isBobsHead and TearFlagsLib.WeaponFlag.BOBS_ROTTEN_HEAD or TearFlagsLib.WeaponFlag.TEAR

		for _, explosion in pairs(Isaac.FindByType(1000, EffectVariant.BOMB_EXPLOSION)) do
			if explosion.FrameCount == 0 and explosion.Position:Distance(tear.Position) == 0 then
				TearFlagsLib.ApplyWeaponExplosionTearFlags(explosion:ToEffect(), TearFlagsLib.GetTearPlayer(tear), tear, weapon)
			end
		end
	end
end

TearFlagsLib.CallbackFuncs.ExplosionInit = function(_, explosion)
	if not explosion.SpawnerEntity or not (TearFlagsLib.HasAnyTearFlags(explosion.SpawnerEntity) or TearFlagsLib.HasAnyCustomVanillaTearFlags(explosion.SpawnerEntity)) then return end

	if explosion.SpawnerType == 4 then
		TearFlagsLib.ApplyWeaponExplosionTearFlags(explosion, TearFlagsLib.GetTearPlayer(explosion.SpawnerEntity), explosion.SpawnerEntity:ToBomb(), TearFlagsLib.WeaponFlag.DR_FETUS)
	elseif explosion.SpawnerType == 1000 and explosion.SpawnerVariant == EffectVariant.ROCKET then
		TearFlagsLib.ApplyWeaponExplosionTearFlags(explosion, TearFlagsLib.GetTearPlayer(explosion.SpawnerEntity), explosion.SpawnerEntity:ToEffect(), TearFlagsLib.WeaponFlag.EPIC_FETUS)
	elseif explosion.SpawnerType == 1000 and explosion.SpawnerVariant == EffectVariant.SMALL_ROCKET then
		TearFlagsLib.ApplyWeaponExplosionTearFlags(explosion, TearFlagsLib.GetTearPlayer(explosion.SpawnerEntity), explosion.SpawnerEntity:ToEffect(), TearFlagsLib.WeaponFlag.CLUB_EPIC_FETUS)
	end
end

-- POST_CLEAR_LUDOVICO_FLAGS
function TearFlagsLib.CheckLudovicoReset(entity, player, weaponFlag)
	if entity.FrameCount // player.MaxFireDelay ~= (entity.FrameCount - 1) // player.MaxFireDelay then
		local oldFlags = TearFlagsLib.GetTearFlags(entity):Clone()

		TearFlagsLib.WipeBlacklists(entity)
		TearFlagsLib.WipeTearFlags(entity)

		Isaac.RunCallback(TearFlagsLib.Callback.POST_CLEAR_LUDOVICO_FLAGS, entity, player, weaponFlag, oldFlags)

		if weaponFlag == TearFlagsLib.WeaponFlag.LASER then
			TearFlagsLib.PollChancelessTearFlags(entity, player, weaponFlag)
		else
			TearFlagsLib.PollTearFlags(entity, player, weaponFlag)
		end
	end
end

TearFlagsLib.CallbackFuncs.EvaluateTearHitParams = function(_, player, params, weapon, damageScale, tearDisplacement, source)
	params.TearFlags = params.TearFlags &~ TearFlagsLib.GuarenteedFlagTracker
end

TearFlagsLib.CallbackFuncs.ClearTearLudos = function(_, tear)
	if tear:HasTearFlags(TearFlags.TEAR_LUDOVICO) and TearFlagsLib.WasEntityFiredByPlayerMimic(tear) then
		TearFlagsLib.CheckLudovicoReset(tear, TearFlagsLib.GetTearPlayer(tear), TearFlagsLib.WeaponFlag.LUDOVICO_TEAR)
	end

	if TearFlagsLib.GetSafeData(tear).pseudoLudo.canReset then
		local frequency = TearFlagsLib.GetSafeData(tear).pseudoLudo.frequency or TearFlagsLib.GetTearPlayer(tear).MaxFireDelay
		if tear.FrameCount // frequency ~= (tear.FrameCount - 1) // frequency then
			tear:ClearHitList()
		end
	end
end

TearFlagsLib.CallbackFuncs.ClearLaserLudos = function(_, laser)
	if laser.SubType == LaserSubType.LASER_SUBTYPE_RING_LUDOVICO and TearFlagsLib.WasEntityFiredByPlayerMimic(laser) then
		TearFlagsLib.CheckLudovicoReset(laser, TearFlagsLib.GetTearPlayer(laser), TearFlagsLib.WeaponFlag.LASER)
	end
end

-- Misc
TearFlagsLib.CallbackFuncs.CheckLuck = function(_, player)
	TearFlagsLib.LuckCache = player.Luck
end

TearFlagsLib.CallbackFuncs.RegisterFlagsTracker = function(_, player, cache)
	player.TearFlags = player.TearFlags | TearFlagsLib.GuarenteedFlagTracker
end

TearFlagsLib.CallbackFuncs.CancelDamage = function(_, entity, amount, flags, source, cooldown)
	if TearFlagsLib.CancelDamage then return false end
end

TearFlagsLib.CallbackFuncs.CatchSplitTear = function(_, new, old, splitType)
	TearFlagsLib.GetSafeData(new).isSplitTear = true
	TearFlagsLib.CopyTearFlags(new, old, TearFlagsLib.WeaponFlag.TEAR, {wipe = true})
	TearFlagsLib.GetSafeData(new).checkedForFlags = true
end

TearFlagsLib.CallbackFuncs.CatchVasculitis = function(_, npc)
	for _, tear in pairs(Isaac.FindByType(2, TearFlagsLib.GetVasculitisTearVariant(npc))) do
		if TearFlagsLib.IsTearVasculitisTear(tear:ToTear(), npc) then
			Isaac.RunCallback(TearFlagsLib.Callback.POST_FIRE_VASCULITIS_TEAR, tear:ToTear(), npc)
		end
	end
end

TearFlagsLib.CallbackFuncs.PreFinger = function(_, familiar)
	TearFlagsLib.GetSafeData(familiar.Player).IsFingering = true
end

TearFlagsLib.CallbackFuncs.PostFinger = function(_, familiar)
	TearFlagsLib.GetSafeData(familiar.Player).IsFingering = false
end

TearFlagsLib.CallbackFuncs.PostBombTearFlags = function(_, _, _, flags, source) -- Avert your eyes young ones
	if flags & TearFlags.TEAR_SCATTER_BOMB == TearFlags.TEAR_SCATTER_BOMB and source and (TearFlagsLib.HasAnyTearFlags(source) or TearFlagsLib.HasAnyCustomVanillaTearFlags(source)) then
		TearFlagsLib.CatchScatterBombs = source
	end
end

TearFlagsLib.CallbackFuncs.BombUpdate = function(_, bomb) -- I'm so sorry, I wasn't strong enough to save you
	TearFlagsLib.CatchScatterBombs = nil
end

TearFlagsLib.CallbackFuncs.CatchSplitBombs = function(_, bomb)
	if TearFlagsLib.CatchScatterBombs then
		TearFlagsLib.CopyTearFlags(bomb, TearFlagsLib.CatchScatterBombs, TearFlagsLib.WeaponFlag.DR_FETUS, {wipe = true})
	end
end

TearFlagsLib.CallbackFuncs.WipeRoomEntitiesCache = function()
	TearFlagsLib.roomEntitiesCache = nil
end

TearFlagsLib.CallbackFuncs.CheckEntityLists = function()
	for key, list in pairs(TearFlagsLib.UpdateLists) do
		for i = #list, 1, -1 do
			local entity = list[i]
			if not entity:Exists() then
				table.remove(TearFlagsLib.UpdateLists[key], i)
			else
				Isaac.RunCallbackWithParam(TearFlagsLib.Callback.UPDATE_ENTITY_LIST, key, entity, key)
			end
		end
	end
end


TearFlagsLib.CallbackPairs = {
	-- Set Tearflags
	{Callback = ModCallbacks.MC_POST_FIRE_TEAR,			Function = TearFlagsLib.CallbackFuncs.PostFireTear},
	{Callback = ModCallbacks.MC_POST_TEAR_INIT,			Function = TearFlagsLib.CallbackFuncs.PostTearInit},
	{Callback = ModCallbacks.MC_FAMILIAR_UPDATE,		Function = TearFlagsLib.CallbackFuncs.PostFireFatesReward,	OptionalArgument = FamiliarVariant.FATES_REWARD},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = TearFlagsLib.CallbackFuncs.PostThrowCatchKnife,	OptionalArgument = 0},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = TearFlagsLib.CallbackFuncs.PostThrowCatchKnife2,	OptionalArgument = 1},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = TearFlagsLib.CallbackFuncs.ClubHitboxInit,		OptionalArgument = 4},
	{Callback = ModCallbacks.MC_POST_FIRE_SWORD,		Function = TearFlagsLib.CallbackFuncs.PostFireSword},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = TearFlagsLib.CallbackFuncs.KnifeUpdate},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = TearFlagsLib.CallbackFuncs.PostSpawnAquarius,			OptionalArgument = EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,	Function = TearFlagsLib.CallbackFuncs.EvaluateDarkArtsFlags,		Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,	Function = TearFlagsLib.CallbackFuncs.EvaluateLocust,			Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_FAMILIAR_INIT,			Function = TearFlagsLib.CallbackFuncs.UmbilicalWhipInit,			OptionalArgument = FamiliarVariant.UMBILICAL_BABY},
	{Callback = ModCallbacks.MC_POST_FIRE_BOMB,			Function = TearFlagsLib.CallbackFuncs.PostFireBomb},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = TearFlagsLib.CallbackFuncs.PostFireAirstrike,			OptionalArgument = EffectVariant.ROCKET},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = TearFlagsLib.CallbackFuncs.PostFireSmallAirstrike,	OptionalArgument = EffectVariant.SMALL_ROCKET},
	{Callback = ModCallbacks.MC_PRE_BRIMSTONE_SNEEZE,	Function = TearFlagsLib.CallbackFuncs.PreHemoptysis},
	{Callback = ModCallbacks.MC_POST_BRIMSTONE_SNEEZE,	Function = TearFlagsLib.CallbackFuncs.PostHemoptysis},

	-- Laser Handling
	{Callback = ModCallbacks.MC_POST_FIRE_BRIMSTONE,	Function = TearFlagsLib.CallbackFuncs.PostFireLaser},
	{Callback = ModCallbacks.MC_POST_FIRE_TECH_LASER,	Function = TearFlagsLib.CallbackFuncs.PostFireLaser},
	{Callback = ModCallbacks.MC_POST_FIRE_TECH_X_LASER,	Function = TearFlagsLib.CallbackFuncs.PostFireLaser},
	{Callback = ModCallbacks.MC_POST_LASER_INIT,		Function = TearFlagsLib.CallbackFuncs.CatchMegaBlast},
	-- {Callback = ModCallbacks.MC_POST_LASER_INIT,		Function = TearFlagsLib.CallbackFuncs.CatchSubLaser},
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE,		Function = TearFlagsLib.CallbackFuncs.CatchChancelessLasersNoHit},
	
	{Callback = ModCallbacks.MC_PRE_LASER_UPDATE,		Function = TearFlagsLib.CallbackFuncs.UpdateLaser},
	{Callback = ModCallbacks.MC_PRE_EFFECT_UPDATE,		Function = TearFlagsLib.CallbackFuncs.LaserSwirlUpdate,		OptionalArgument = EffectVariant.BRIMSTONE_SWIRL},
	{Callback = ModCallbacks.MC_PRE_EFFECT_UPDATE,		Function = TearFlagsLib.CallbackFuncs.LaserSwirlUpdate,		OptionalArgument = EffectVariant.TECH_DOT},
	{Callback = ModCallbacks.MC_PRE_EFFECT_UPDATE,		Function = TearFlagsLib.CallbackFuncs.BrimstoneBallUpdate,	OptionalArgument = EffectVariant.BRIMSTONE_BALL},

	{Callback = ModCallbacks.MC_PRE_LASER_UPDATE,		Function = TearFlagsLib.CallbackFuncs.PreMonstroLaser},
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE, 		Function = TearFlagsLib.CallbackFuncs.PostMonstroLaser},
	{Callback = ModCallbacks.MC_POST_LASER_INIT,		Function = TearFlagsLib.CallbackFuncs.CatchMonstroLaser},
	{Callback = ModCallbacks.MC_PRE_LASER_UPDATE,		Function = TearFlagsLib.CallbackFuncs.CatchTrisagionLaser},

	-- C Section :(
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE,		Function = TearFlagsLib.CallbackFuncs.CatchFetusLaserNoHit},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = TearFlagsLib.CallbackFuncs.CatchFetusSpiritSword},

	-- Apply Tearflag Effect
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = TearFlagsLib.CallbackFuncs.GenericCatchApplyTearFlags},

	{Callback = ModCallbacks.MC_PRE_LASER_COLLISION,			Function = TearFlagsLib.CallbackFuncs.PreLaserCollision},
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = TearFlagsLib.CallbackFuncs.ApplyLaserFlags,		OptionalArgument = EntityType.ENTITY_LASER},
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = TearFlagsLib.CallbackFuncs.ApplyOcularRiftFlags,	OptionalArgument = EntityType.ENTITY_EFFECT},
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = TearFlagsLib.CallbackFuncs.ApplyHemoptysisFlags},

	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,		Function = TearFlagsLib.CallbackFuncs.DrFetusDamage,			Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,		Function = TearFlagsLib.CallbackFuncs.EpicFetusDamage,		Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,		Function = TearFlagsLib.CallbackFuncs.ClubEpicFetusDamage,	Priority = CallbackPriority.LATE},

	{Callback = ModCallbacks.MC_POST_TEAR_DEATH, 		Function = TearFlagsLib.CallbackFuncs.CatchIpecac},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = TearFlagsLib.CallbackFuncs.ExplosionInit,			OptionalArgument = EffectVariant.BOMB_EXPLOSION},

	-- Chanceless Laser Flags
	{Callback = ModCallbacks.MC_EVALUATE_TEAR_HIT_PARAMS,	Function = TearFlagsLib.CallbackFuncs.EvaluateTearHitParams},

	-- Clear Ludo Flags
	{Callback = ModCallbacks.MC_POST_TEAR_UPDATE,		Function = TearFlagsLib.CallbackFuncs.ClearTearLudos},
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE,		Function = TearFlagsLib.CallbackFuncs.ClearLaserLudos},

	-- Misc
	{Callback = ModCallbacks.MC_EVALUATE_CACHE,			Function = TearFlagsLib.CallbackFuncs.CheckLuck,				Priority = 999999999, OptionalArgument = CacheFlag.CACHE_LUCK},
	{Callback = ModCallbacks.MC_EVALUATE_CACHE,			Function = TearFlagsLib.CallbackFuncs.RegisterFlagsTracker,	Priority = -99999999, OptionalArgument = CacheFlag.CACHE_TEARFLAG},
	{Callback = ModCallbacks.MC_ENTITY_TAKE_DMG,		Function = TearFlagsLib.CallbackFuncs.CancelDamage,			Priority = CallbackPriority.IMPORTANT},
	{Callback = ModCallbacks.MC_POST_NPC_DEATH,			Function = TearFlagsLib.CallbackFuncs.CatchVasculitis},
	{Callback = ModCallbacks.MC_POST_FIRE_SPLIT_TEAR,	Function = TearFlagsLib.CallbackFuncs.CatchSplitTear,		Priority = -99999999},
	{Callback = ModCallbacks.MC_POST_UPDATE,			Function = TearFlagsLib.CallbackFuncs.WipeRoomEntitiesCache},
	{Callback = ModCallbacks.MC_PRE_NEW_ROOM,			Function = TearFlagsLib.CallbackFuncs.WipeRoomEntitiesCache},
	{Callback = ModCallbacks.MC_POST_UPDATE,			Function = TearFlagsLib.CallbackFuncs.CheckEntityLists},

	-- The FINGER :(
	{Callback = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,	Function = TearFlagsLib.CallbackFuncs.PreFinger,		OptionalArgument = FamiliarVariant.FINGER},
	{Callback = ModCallbacks.MC_FAMILIAR_UPDATE, 		Function = TearFlagsLib.CallbackFuncs.PostFinger,	OptionalArgument = FamiliarVariant.FINGER},

	-- Scatter Bombs :(
	{Callback = ModCallbacks.MC_POST_BOMB_TEARFLAG_EFFECTS,	Function = TearFlagsLib.CallbackFuncs.PostBombTearFlags},
	{Callback = ModCallbacks.MC_POST_BOMB_UPDATE,			Function = TearFlagsLib.CallbackFuncs.BombUpdate},
	{Callback = ModCallbacks.MC_POST_BOMB_INIT,				Function = TearFlagsLib.CallbackFuncs.CatchSplitBombs},
}

function TearFlagsLib.RegisterCallbacks()
	-- Normally I really hate defining callbacks the way I have here
	-- Inline callbacks are far easier to understand imo
	-- But afaik you can't unregister inlined callbacks
	-- So alas

	-- c'est la vie
	for i, data in pairs(TearFlagsLib.CallbackPairs) do
		TearFlagsLib:AddPriorityCallback(data.Callback, data.Priority or CallbackPriority.DEFAULT, data.Function, data.OptionalArgument)
	end

	TearFlagsLib:AddCallback(TearFlagsLib.Callback.__META_RELOADDETECTOR, function() end)
end

function TearFlagsLib.UnregisterCallbacks()
	for i, data in pairs(TearFlagsLib.CallbackPairs) do
		-- print("remove callback", i, data.Callback, data.Function)
		TearFlagsLib:RemoveCallback(data.Callback, data.Function)
	end
end

-- Changed function names, maintained for compatibility
TearFlagsLib.CallTearFlagCallback 			= TearFlagsLib.ApplyWeaponTearFlags
TearFlagsLib.CallExplosionTearFlagCallback 	= TearFlagsLib.ApplyWeaponExplosionTearFlags
TearFlagsLib.CallPollTearFlagCallback 		= TearFlagsLib.PollTearFlags