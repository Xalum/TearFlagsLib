local mod = TearFlagsLib
mod.CallbackFuncs = {}

function mod.ApplyWeaponTearFlags(entity, player, source, weaponFlag, tryVanillaFlags, hitbox)
	-- Furniture is hard-blacklisted against receiving the effects of tearflags, you NEVER want to affect this stuff anyway so it's really stupid that it gets passed through the vanilla APPLY_TEARFLAG_EFFECTS callback
	if entity.Type == EntityType.ENTITY_GENERIC_PROP or mod.IsEntityBlacklisted(entity, source) or not entity:ToNPC() then return false end
	entity = entity:ToNPC()

	if Isaac.RunCallbackWithParam(mod.Callback.PRE_APPLY_TEARFLAG_EFFECTS, entity.Type, entity, player, source, weaponFlag, hitbox) then
		return false
	end

	local recursionKey = mod.SetAntiRecursion()
	for _, callbackData in ipairs(Isaac.GetCallbacks(mod.Callback.APPLY_TEARFLAG_EFFECT)) do
		if not callbackData.Param or (mod.HasTearFlags(source, callbackData.Param) and not mod.IsEntityBlacklisted(entity, source, callbackData.Param)) then
			callbackData.Function(callbackData.Mod, entity, player, source, weaponFlag, mod.GetTearFlagParams(source, callbackData.Param), hitbox)
		end
	end

	Isaac.RunCallbackWithParam(mod.Callback.POST_APPLY_TEARFLAG_EFFECTS, entity.Type, entity, player, source)
	mod.ClearAntiRecursion(recursionKey)

	if not tryVanillaFlags then return true end
	local flags = mod.GetCustomVanillaTearFlags(source) &~ mod.AgnosticGetVanillaTearFlags(source, true)
	if flags == mod.BitSetZero then return true end

	local params = mod.GetCustomVanillaTearFlagParams(source)
	mod.ApplyVanillaTearFlagEffectsToEntity(entity, flags, player, source, TearFlagsLib.FuzzyReplaceTable({DamageOverride = source.CollisionDamage}, params))

	return true
end

function mod.ApplyWeaponExplosionTearFlags(explosion, player, sourceBomb, weaponFlag)
	local recursionKey = mod.SetAntiRecursion()
	for _, callbackData in ipairs(Isaac.GetCallbacks(mod.Callback.APPLY_EXPLOSION_TEARFLAG_EFFECT)) do
		if not callbackData.Param or mod.HasTearFlags(sourceBomb, callbackData.Param) then
			callbackData.Function(callbackData.Mod, explosion, player, sourceBomb, weaponFlag, mod.GetTearFlagParams(sourceBomb, callbackData.Param))
		end
	end
	mod.ClearAntiRecursion(recursionKey)
end

function mod.PollTearFlags(weaponEntity, player, weaponFlag)
	mod.IsPollingForTearFlags = weaponFlag

	local cancel = Isaac.RunCallbackWithParam(mod.Callback.PRE_POLL_TEARFLAGS, weaponFlag, mod.Cast(weaponEntity), player, weaponFlag)
	if cancel then
		mod.IsPollingForTearFlags = nil
		return false
	end

	Isaac.RunCallbackWithParam(mod.Callback.POLL_TEARFLAGS, weaponFlag, mod.Cast(weaponEntity), player, weaponFlag)
	Isaac.RunCallbackWithParam(mod.Callback.POST_POLL_TEARFLAGS, weaponFlag, mod.Cast(weaponEntity), player, weaponFlag)

	mod.IsPollingForTearFlags = nil
	mod.GetSafeData(weaponEntity).checkedFlags = true

	return true
end


function mod.PollLocustTearFlags(locust, player)
	mod.IsPollingForTearFlags = mod.WeaponFlag.LOCUST

	Isaac.RunCallbackWithParam(mod.Callback.POLL_LOCUST_TEARFLAGS, locust.SubType, locust:ToFamiliar(), player)

	mod.IsPollingForTearFlags = nil
	mod.GetSafeData(locust).checkedFlags = true
end

function mod.PollChancelessTearFlags(weaponEntity, player, weaponFlag)
	mod.IsPollingForTearFlags = weaponFlag

	local oldColour = weaponEntity.Color

	if weaponEntity.TearFlags then
		weaponEntity.TearFlags = weaponEntity.TearFlags &~ mod.GuarenteedFlagTracker
	end

	Isaac.RunCallbackWithParam(mod.Callback.POLL_CHANCELESS_TEARFLAGS, weaponFlag, mod.Cast(weaponEntity), player, weaponFlag)

	mod.IsPollingForTearFlags = nil
	mod.GetSafeData(weaponEntity).checkedFlags = true
	weaponEntity.Color = oldColour
end

-- Weapons spawned by C Section fetuses can and will attempt to deal damage before the fetus has even finished firing
-- These little SHITS will deal damage before the fetus even polls for its own tear flags
-- The ramifications of polling for tearflags this early scare me
-- (Also used for Trisagion)
function mod.EmergencyPollTearFlags(tear)
	if not mod.GetSafeData(tear).checkedForFlags and mod.WasEntityFiredByPlayerMimic(tear) then
		mod.PollTearFlags(tear:ToTear(), mod.GetTearPlayer(tear), mod.WeaponFlag.TEAR)
		Isaac.RunCallback(mod.Callback.POST_REAL_FIRE_TEAR, tear:ToTear(), mod.GetTearPlayer(tear))
		mod.GetSafeData(tear).checkedForFlags = true
	end
end


-- Below this point is the inner workings of the TearFlagsLib beast, venture at your own risk or stay in the comfort and safety above

-- POST_REAL_FIRE_TEAR
mod.CallbackFuncs.PostFireTear = function(_, tear)
	if mod.WasEntityFiredByPlayerMimic(tear) and not mod.GetSafeData(tear).checkedForFlags then
		mod.PollTearFlags(tear, mod.GetTearPlayer(tear), mod.WeaponFlag.TEAR)
		Isaac.RunCallback(mod.Callback.POST_REAL_FIRE_TEAR, tear, mod.GetTearPlayer(tear))
	end

	mod.GetSafeData(tear).checkedForFlags = true
end

local fatesRewardTears = {}
mod.CallbackFuncs.PostTearInit = function(_, tear) -- This is sketchy af ngl
	if not mod.WasEntityFiredByPlayerMimic(tear) then return end

	if tear.Variant == TearVariant.BOBS_HEAD and mod.PlayerHasItemEffect(mod.GetTearPlayer(tear), CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD) then
		mod.GetSafeData(tear).isBobsHead = true
		mod.PollTearFlags(tear, mod.GetTearPlayer(tear), mod.WeaponFlag.BOBS_ROTTEN_HEAD)
	elseif (tear.Variant == TearVariant.KEY or tear.Variant == TearVariant.KEY_BLOOD) and mod.PlayerHasItemEffect(mod.GetTearPlayer(tear), CollectibleType.COLLECTIBLE_SHARP_KEY) then
		mod.GetSafeData(tear).isSharpKey = true
		mod.PollTearFlags(tear, mod.GetTearPlayer(tear), mod.WeaponFlag.SHARP_KEY)
	elseif tear.SpawnerType == EntityType.ENTITY_FAMILIAR and tear.SpawnerVariant == FamiliarVariant.FATES_REWARD and mod.WasEntityFiredByPlayerMimic(tear, true) then
		mod.GetSafeData(tear).isFatesReward = true
		table.insert(fatesRewardTears, tear)
	end
end

mod.CallbackFuncs.PostFireFatesReward = function()
	-- Fate's Fucking Reward
	for _, tear in pairs(fatesRewardTears) do
		if tear:Exists() and tear.FrameCount == 0 and not mod.GetSafeData(tear).checkedForFlags then
			mod.PollTearFlags(tear, mod.GetTearPlayer(tear), mod.WeaponFlag.TEAR)
			Isaac.RunCallback(mod.Callback.POST_REAL_FIRE_TEAR, tear, mod.GetTearPlayer(tear))
		end
		mod.GetSafeData(tear).checkedForFlags = true
	end
	fatesRewardTears = {}
end

-- POST_THROW_KNIFE/POST_CATCH_KNIFE
mod.CallbackFuncs.PostThrowCatchKnife = function(_, knife)
	if mod.WasEntityFiredByPlayerMimic(knife) then
		local data = mod.GetSafeData(knife)
		local isFlying = knife:IsFlying()

		if isFlying then
			local isReturning = data.lastFrameDistance and data.lastFrameDistance > knife.Position:Distance(knife.SpawnerEntity.Position)
			
			if not data.lastFrameWasFlying then
				if mod.IsKnifeSwingableAndThrowable(knife) then
					Isaac.RunCallbackWithParam(mod.Callback.POST_THROW_CLUB, knife.Variant, knife, mod.GetTearPlayer(knife))
					
					-- Only Clubs copy flags to Lasers spawned by their Technology synergy, Knives use "Chanceless Lasers"
					-- One shudders to think what the fuck they were thinking
					for _, laser in pairs(Isaac.FindByType(7)) do
						if laser.FrameCount == 0 and mod.IsLaserThrownClubTechnology(laser:ToLaser(), knife) then
							mod.GetSafeData(laser).checkedFlags = true
							mod.CopyTearFlags(laser, knife, mod.WeaponFlag.LASER, {wipe = true})
						end
					end
				else
					Isaac.RunCallbackWithParam(mod.Callback.POST_THROW_KNIFE, knife.Variant, knife, mod.GetTearPlayer(knife))
				end
			end

			if isReturning and not data.lastFrameWasReturning then
				data.lastFrameWasReturning = true
			end

			data.lastFrameWasReturning = isReturning
		elseif data.lastFrameWasFlying then
			if mod.IsKnifeSwingableAndThrowable(knife) then
				Isaac.RunCallbackWithParam(mod.Callback.POST_CATCH_CLUB, knife.Variant, knife, mod.GetTearPlayer(knife))
			else
				Isaac.RunCallbackWithParam(mod.Callback.POST_CATCH_KNIFE, knife.Variant, knife, mod.GetTearPlayer(knife))
			end

			mod.WipeTearFlags(knife, true)
			data.lastFrameWasReturning = false
		end

		data.lastFrameWasFlying = isFlying
		data.lastFrameDistance = knife.Position:Distance(knife.SpawnerEntity.Position)
	end
end

mod.CallbackFuncs.PostThrowCatchKnife2 = function(_, knife)
	if knife.FrameCount == 0 and mod.WasEntityFiredByPlayerMimic(knife) then
		Isaac.RunCallbackWithParam(mod.Callback.POST_THROW_KNIFE, knife.Variant, knife, mod.GetTearPlayer(knife))
	end
end

mod.CallbackFuncs.KnifeUpdate = function(_, knife)
	if mod.WasEntityFiredByPlayerMimic(knife) and mod.DoesKnifeVariantPollEveryFrame(knife.Variant) then
		mod.WipeTearFlags(knife)
		mod.PollTearFlags(knife, mod.GetTearPlayer(knife), mod.WeaponFlag.KNIFE)
	end
end

-- PRE_SWING_CLUB
mod.CallbackFuncs.ClubHitboxInit = function(_, knife)
	if knife.FrameCount > 0 then return end
	if not mod.WasEntityFiredByPlayerMimic(knife) or not mod.CanClubVariantHaveTearEffects(knife.Variant) then return end

	local parent = knife:GetHitboxParentKnife()

	if not parent then -- Evil Eye, Tainted Maggie
		mod.PollTearFlags(knife, mod.GetTearPlayer(knife), mod.WeaponFlag.CLUB)
	else
		if parent:GetSprite():GetFrame() > 0 then -- Cursed Eye
			knife.Color = parent.Color
			mod.CopyTearFlags(knife, parent, mod.WeaponFlag.CLUB, {wipe = true})
		elseif mod.IsClubCSectionClub(parent) then
			knife.Color = parent.Color
			mod.CopyTearFlags(knife, parent.Parent, mod.WeaponFlag.CLUB, {wipe = true})
		else -- Everything else
			mod.PollTearFlags(knife, mod.GetTearPlayer(knife), mod.WeaponFlag.CLUB)
			parent.Color = knife.Color
			mod.CopyTearFlags(parent, knife, mod.WeaponFlag.CLUB, {wipe = true})
		end
	end

	Isaac.RunCallback(mod.Callback.PRE_SWING_CLUB, knife, mod.GetTearPlayer(knife))
end

mod.CallbackFuncs.PostFireSword = function(_, sword)
	if mod.WasEntityFiredByPlayerMimic(sword) then
		mod.PollTearFlags(sword, mod.GetTearPlayer(sword), mod.WeaponFlag.SWORD)
	end
end

-- POST_SPAWN_AQUARIUS
mod.CallbackFuncs.PostSpawnAquarius = function(_, effect)
	if mod.WasEntityFiredByPlayerMimic(effect) then
		mod.PollTearFlags(effect, mod.GetTearPlayer(effect), mod.WeaponFlag.AQUARIUS)
	end
end

mod.CallbackFuncs.BrimstoneBallUpdate = function(_, effect)
	if mod.WasEntityFiredByPlayerMimic(effect) then
		mod.WipeTearFlags(effect)
		mod.PollTearFlags(effect, mod.GetTearPlayer(effect), mod.WeaponFlag.BRIMSTONE_BALL)
	end
end

-- POST_FIRE_LASER
function mod.EvaluateLaserTearFlags(laser)
	if mod.GetSafeData(laser).CanRollForFlags then
		mod.PollTearFlags(laser, mod.GetTearPlayer(laser), mod.WeaponFlag.LASER)
	end
end

mod.CallbackFuncs.PostFireLaser = function(_, laser)
	-- For some ungodly reason, Nicalis in their infinite wisdom decided to make it so that Lasers are capable of dealing damage BEFORE THEY FINISH INITIALISING
	-- This means that Lasers are capable of dealing damage before their usual TearFlag rolling
	-- As such, on top of rolling for flags every frame, lasers must also roll for flags when they're fired, which requires the use of THREE SEPARATE REPENTOGON CALLBACKS

	-- On the bright side, since REPENTOGON adds callbacks for Firing Lasers, I can also use this to tag which laser entities should recieve TearFlags
	-- For some goddamn reason, not every player-spawned laser gets random flags, can anyone on this Earth explain why? Probably not!

	-- On the not bright side, there are a couple of situations where I SHOULD be polling for flags but REPENTOGON doesn't give me easy access
	-- I will sort these out later (Later came and I kicked its ass!)

	if mod.FiringSplitLaser then
		mod.GetSafeData(laser).checkedFlags = true
		local source = mod.FiringSplitLaser.Spawner
		local params = mod.FiringSplitLaser.Params

		laser:ClearTearFlags(laser.TearFlags)
		mod.CopyTearFlags(laser, source, mod.WeaponFlag.LASER, {wipe = true})
		laser:AddTearFlags((source.TearFlags or source.Flags or mod.BitSetZero))
		laser:AddTearFlags(mod.GetCustomVanillaTearFlags(source))
		laser:ClearTearFlags(params.RemoveFlags or mod.BitSetZero)
		mod.ClearTearFlags(laser, params.RemoveCustomFlags or mod.BitSetInfinity.Zero)
		mod.WipeCustomVanillaTearFlags(laser)
	elseif mod.WasEntityFiredByPlayerMimic(laser) and not mod.IsLaserFinger(laser) then
		mod.GetSafeData(laser).CanRollForFlags = true
		mod.EvaluateLaserTearFlags(laser)
	end
end

mod.CallbackFuncs.CatchMegaBlast = function(_, laser)
	if laser.Variant ~= LaserVariant.GIANT_RED and laser.Variant ~= LaserVariant.GIANT_BRIM_TECH then return end
	if not mod.WasEntityFiredByPlayerMimic(laser) then return end

	mod.GetSafeData(laser).CanRollForFlags = true
	mod.EvaluateLaserTearFlags(laser)
end

mod.CallbackFuncs.CatchChancelessLasersNoHit = function(_, laser)
	if not mod.GetSafeData(laser).checkedFlags and mod.DidLaserCopyPlayerFlags(laser) then
		mod.PollChancelessTearFlags(laser, mod.GetTearPlayer(laser), mod.WeaponFlag.LASER)
	end
end

mod.CallbackFuncs.UpdateLaser = function(_, laser)
	if not mod.GetSafeData(laser).CanRollForFlags then return end

	mod.WipeTearFlags(laser)
	mod.EvaluateLaserTearFlags(laser)
end

mod.CallbackFuncs.LaserSwirlUpdate = function(_, effect)
	local player = mod.GetTearPlayer(effect)

	if player then
		mod.WipeTearFlags(effect)
		mod.PollTearFlags(effect, player, mod.WeaponFlag.ANTI_GRAV_LASER)
	end
end

-- Lasers fired by C Section fetuses (And Forgotten Swings x Technology)
mod.CallbackFuncs.CatchFetusLaserNoHit = function(_, laser)
	if mod.ShouldCopyLaserFlagsOnFirstUpdate(laser) then
		mod.GetSafeData(laser).checkedFlags = true
		mod.CopyTearFlags(laser, laser.Parent, mod.WeaponFlag.LASER, {wipe = true})
	end
end

-- Spirit swords held by C Section fetuses
mod.CallbackFuncs.CatchFetusSpiritSword = function(_, sword)
	if sword.FrameCount > 0 or mod.GetSafeData(sword).checkedFlags then return end
	if mod.IsSwordCSectionSword(sword) then
		mod.EmergencyPollTearFlags(sword.Parent)
		mod.GetSafeData(sword).checkedFlags = true
		mod.CopyTearFlags(sword, sword.Parent, mod.WeaponFlag.SWORD, {wipe = true})
	end
end

-- EVALUATE_DARK_ARTS_FLAGS
mod.CallbackFuncs.EvaluateDarkArtsFlags = function(_, entity, amount, flags, source, cooldown)
	if mod.AntiRecursion then return end

	if source and source.Type == 1000 and source.Variant == EffectVariant.DARK_SNARE and source.Entity and source.Entity.SpawnerEntity and not mod.GetSafeData(source.Entity).evaluatedTearFlags then
		local snare = source.Entity
		local player = mod.GetTearPlayer(snare)
		mod.PollTearFlags(snare, player, mod.WeaponFlag.DARK_ARTS)

		mod.GetSafeData(snare).evaluatedTearFlags = true
		mod.ApplyWeaponTearFlags(entity, player, snare, mod.WeaponFlag.DARK_ARTS, true)
	end
end

-- Locusts
mod.CallbackFuncs.EvaluateLocust = function(_, entity, amount, flags, source, cooldown)
	if mod.AntiRecursion then return end

	if source.Type == EntityType.ENTITY_FAMILIAR and source.Variant == FamiliarVariant.ABYSS_LOCUST then
		local locust = source.Entity:ToFamiliar()
		mod.PollLocustTearFlags(locust, locust.Player)
		mod.ApplyWeaponTearFlags(entity, locust.Player, locust, mod.WeaponFlag.LOCUST, true)
		mod.WipeTearFlags(source.Entity)
	end
end

-- Umbilical Whip
mod.CallbackFuncs.UmbilicalWhipInit = function(_, familiar)
	mod.PollTearFlags(familiar, familiar.Player, mod.WeaponFlag.UMBILICAL_WHIP)
end

-- Dr. Fetus
mod.CallbackFuncs.PostFireBomb = function(_, bomb)
	mod.PollTearFlags(bomb, mod.GetTearPlayer(bomb), mod.WeaponFlag.DR_FETUS)
end

-- Epic Fetus
mod.CallbackFuncs.PostFireAirstrike = function(_, effect)
	mod.PollTearFlags(effect, mod.GetTearPlayer(effect), mod.WeaponFlag.EPIC_FETUS)
end

mod.CallbackFuncs.PostFireSmallAirstrike = function(_, effect)
	mod.PollTearFlags(effect, mod.GetTearPlayer(effect), mod.WeaponFlag.CLUB_EPIC_FETUS)
end

-- Hemoptysis
mod.CallbackFuncs.PreHemoptysis = function(_, source)
	local player = source:ToPlayer() or mod.GetTearPlayer(source)

	mod.hemoptysisCache = source
	mod.hemoptysisDummy = mod.SpawnDummyEntity(player, mod.WeaponFlag.HEMOPTYSIS)
	mod.PollTearFlags(mod.hemoptysisDummy, player, mod.WeaponFlag.HEMOPTYSIS)
end

mod.CallbackFuncs.PostHemoptysis = function()
	mod.hemoptysisCache = nil
	mod.hemoptysisDummy = nil
end

-- Monstro's Lung x Technology
mod.CallbackFuncs.PreMonstroLaser = function(_, laser)
	if mod.GetTearPlayer(laser):HasCollectible(CollectibleType.COLLECTIBLE_MONSTROS_LUNG) and (mod.HasAnyTearFlags(laser) or mod.HasAnyCustomVanillaTearFlags(laser)) then
		mod.monstroLaser = laser
	end
end

mod.CallbackFuncs.PostMonstroLaser = function()
	mod.monstroLaser = nil
end

mod.CallbackFuncs.CatchMonstroLaser = function(_, laser)
	if mod.monstroLaser and laser.Position:Distance(mod.monstroLaser.EndPoint) < 0.01 then -- Unfortunately this is kind of a risky assumption all in all but Isaac is held together with sticks and hope so w/e man
		mod.GetSafeData(laser).checkedFlags = true
		mod.CopyTearFlags(laser, mod.monstroLaser, mod.WeaponFlag.LASER, {wipe = true})
	end
end

mod.CallbackFuncs.CatchTrisagionLaser = function(_, laser)
	if laser.FrameCount == 1 and mod.IsLaserTrisagion(laser) then
		if not mod.GetSafeData(laser).checkedFlags then
			mod.GetSafeData(laser).checkedFlags = true
			mod.CopyTearFlags(laser, laser.Parent, mod.WeaponFlag.LASER, {wipe = true})
		end
	end
end

-- APPLY_TEARFLAG_EFFECT
-- Generic
mod.CallbackFuncs.GenericCatchApplyTearFlags = function(_, npc, position, flags, source, damage)

	-- What a mess
	if not npc or not source then return end
	local weapon = mod.Cast(source)
	if mod.IsEntity.Sword(weapon) and weapon.SubType == 4 then weapon = weapon:GetHitboxParentKnife() or weapon end
	if not (mod.HasAnyTearFlags(weapon) or mod.HasAnyCustomVanillaTearFlags(weapon)) or mod.IsEntityBlacklisted(npc, weapon) then return end
	local player = weapon.Player or mod.GetTearPlayer(weapon)

	-- The real shit
	local weaponFlag
	local bonusArg

	if mod.IsEntity.Tear(weapon) then -- The Daily Driver/Ludovico Technique/Flat Stone
		weaponFlag = mod.WeaponFlag.TEAR
	elseif mod.IsEntity.Gello(weapon) then -- Gello
		weaponFlag = mod.WeaponFlag.UMBILICAL_WHIP
	elseif mod.IsEntity.Knife(weapon) then -- Mom's Knife/Sumptorium/Thrown Clubs (Forgotten/Berserk)
		weaponFlag = mod.WeaponFlag.KNIFE
	elseif mod.IsEntity.Club(weapon) then -- Berserk/Notched Axe/Forgotten
		weaponFlag = mod.WeaponFlag.CLUB
	elseif mod.IsEntity.Sword(weapon) then -- Spirit Sword
		weaponFlag, bonusArg = mod.WeaponFlag.SWORD, weapon.SubType == 4 and source:ToKnife() or nil
	elseif mod.IsEntity.Aquarius(weapon) then -- Aquarius
		weaponFlag = mod.WeaponFlag.AQUARIUS
	elseif mod.IsEntity.LaserSwirl(weapon) then -- Anti-Gravity/Lasers
		weaponFlag = mod.WeaponFlag.ANTI_GRAV_LASER
	elseif mod.IsEntity.BrimstoneBall(weapon) then -- Forgotten x Brimstone
		weaponFlag = mod.WeaponFlag.BRIMSTONE_BALL
	end

	if weaponFlag then
		mod.ApplyWeaponTearFlags(npc, player, weapon, weaponFlag, true, bonusArg)
	end

	-- print(source.Type, source.Variant, source.SubType)
end

-- Lasers
mod.CallbackFuncs.PreLaserCollision = function(_, laser, collider)
	if mod.ShouldPollLaserFlagsOnApply(laser) then
		if mod.IsLaserTrisagion(laser) then
			mod.EmergencyPollTearFlags(laser.Parent)
			mod.GetSafeData(laser).checkedFlags = true
			mod.CopyTearFlags(laser, laser.Parent, mod.WeaponFlag.LASER, {wipe = true})
		elseif mod.IsLaserCSectionTechnology(laser) then
			local fetus

			if laser.Parent.Type == 2 then
				fetus = laser.Parent
			end

			fetus = fetus or mod.EstimateCSectionParent(laser)
			if fetus then
				mod.EmergencyPollTearFlags(fetus)
				mod.GetSafeData(laser).checkedFlags = true
				mod.CopyTearFlags(laser, fetus, mod.WeaponFlag.LASER, {wipe = true})
			end
		elseif mod.IsLaserClubTechnology(laser) then
			mod.GetSafeData(laser).checkedFlags = true
			mod.CopyTearFlags(laser:ToLaser(), laser.Parent, mod.WeaponFlag.LASER, {wipe = true})
		else
			mod.GetSafeData(laser).CanRollForFlags = true
			mod.EvaluateLaserTearFlags(laser:ToLaser())
		end
	end

	if mod.DidLaserCopyPlayerFlags(laser) and not mod.GetSafeData(laser).checkedFlags then
		mod.PollChancelessTearFlags(laser:ToLaser(), mod.GetTearPlayer(laser), mod.WeaponFlag.LASER)
	end
end

mod.CallbackFuncs.ApplyLaserFlags = function(_, npc, position, flags, source, damage)
	if mod.HasAnyTearFlags(source) or mod.HasAnyCustomVanillaTearFlags(source) then
		mod.ApplyWeaponTearFlags(npc, mod.GetTearPlayer(source), source, mod.WeaponFlag.LASER, true)
	end
end

-- Ocular Rift
mod.CallbackFuncs.ApplyOcularRiftFlags = function(_, npc, position, flags, source, damage)
	if mod.IsEntityOcularRift(source) then
		local player = mod.GetTearPlayer(source)
		local color = source.Color

		mod.WipeTearFlags(source)
		mod.PollTearFlags(source, player, mod.WeaponFlag.OCULAR_RIFT)
		mod.ApplyWeaponTearFlags(npc, player, source, mod.WeaponFlag.OCULAR_RIFT, true)

		source.Color = color
	end
end

-- Hemoptysis
mod.CallbackFuncs.ApplyHemoptysisFlags = function(_, npc, position, flags, source, damage)
	if mod.hemoptysisCache and GetPtrHash(source) == GetPtrHash(mod.hemoptysisCache) then
		local player = source:ToPlayer() or mod.GetTearPlayer(source)

		if not mod.hemoptysisDummy then
			mod.hemoptysisDummy = mod.SpawnDummyEntity(player, mod.WeaponFlag.HEMOPTYSIS)
			mod.PollTearFlags(mod.hemoptysisDummy, player, mod.WeaponFlag.HEMOPTYSIS)
		end

		mod.ApplyWeaponTearFlags(npc, player, mod.hemoptysisDummy, mod.WeaponFlag.HEMOPTYSIS, true)
	end
end

-- Dr. Fetus
mod.CallbackFuncs.DrFetusDamage = function(_, entity, amount, flags, source, cooldown)
	if mod.AntiRecursion then return end
	if source.Type ~= 4 or not source.Entity:ToBomb().IsFetus or not (mod.HasAnyTearFlags(source.Entity) or mod.HasAnyCustomVanillaTearFlags(source.Entity)) then return end

	if flags & DamageFlag.DAMAGE_EXPLOSION > 0 then
		mod.ApplyWeaponTearFlags(entity, mod.GetTearPlayer(source.Entity), source.Entity:ToBomb(), mod.WeaponFlag.DR_FETUS, true)
	end
end

-- Epic Fetus
mod.CallbackFuncs.EpicFetusDamage = function(_, entity, amount, flags, source, cooldown)
	if mod.AntiRecursion then return end
	if source.Type ~= 1000 or source.Variant ~= EffectVariant.ROCKET or not (mod.HasAnyTearFlags(source.Entity) or mod.HasAnyCustomVanillaTearFlags(source.Entity)) then return end

	if flags & DamageFlag.DAMAGE_EXPLOSION > 0 then
		mod.ApplyWeaponTearFlags(entity, mod.GetTearPlayer(source.Entity), source.Entity:ToEffect(), mod.WeaponFlag.EPIC_FETUS, true)
	end
end

mod.CallbackFuncs.ClubEpicFetusDamage = function(_, entity, amount, flags, source, cooldown)
	if mod.AntiRecursion then return end
	if source.Type ~= 1000 or source.Variant ~= EffectVariant.SMALL_ROCKET or not (mod.HasAnyTearFlags(source.Entity) or mod.HasAnyCustomVanillaTearFlags(source.Entity)) then return end

	if flags & DamageFlag.DAMAGE_EXPLOSION > 0 then
		mod.ApplyWeaponTearFlags(entity, mod.GetTearPlayer(source.Entity), source.Entity:ToEffect(), mod.WeaponFlag.CLUB_EPIC_FETUS, true)
	end
end

mod.CallbackFuncs.CatchIpecac = function(_, tear)
	if tear.TearFlags & mod.EXPLOSIVE_TEARFLAGS ~= TearFlags.TEAR_NORMAL then
		local weapon = mod.GetSafeData(tear).isBobsHead and mod.WeaponFlag.BOBS_ROTTEN_HEAD or mod.WeaponFlag.TEAR

		for _, explosion in pairs(Isaac.FindByType(1000, EffectVariant.BOMB_EXPLOSION)) do
			if explosion.FrameCount == 0 and explosion.Position:Distance(tear.Position) == 0 then
				mod.ApplyWeaponExplosionTearFlags(explosion:ToEffect(), mod.GetTearPlayer(tear), tear, weapon)
			end
		end
	end
end

mod.CallbackFuncs.ExplosionInit = function(_, explosion)
	if not explosion.SpawnerEntity or not (mod.HasAnyTearFlags(explosion.SpawnerEntity) or mod.HasAnyCustomVanillaTearFlags(explosion.SpawnerEntity)) then return end

	if explosion.SpawnerType == 4 then
		mod.ApplyWeaponExplosionTearFlags(explosion, mod.GetTearPlayer(explosion.SpawnerEntity), explosion.SpawnerEntity:ToBomb(), mod.WeaponFlag.DR_FETUS)
	elseif explosion.SpawnerType == 1000 and explosion.SpawnerVariant == EffectVariant.ROCKET then
		mod.ApplyWeaponExplosionTearFlags(explosion, mod.GetTearPlayer(explosion.SpawnerEntity), explosion.SpawnerEntity:ToEffect(), mod.WeaponFlag.EPIC_FETUS)
	elseif explosion.SpawnerType == 1000 and explosion.SpawnerVariant == EffectVariant.SMALL_ROCKET then
		mod.ApplyWeaponExplosionTearFlags(explosion, mod.GetTearPlayer(explosion.SpawnerEntity), explosion.SpawnerEntity:ToEffect(), mod.WeaponFlag.CLUB_EPIC_FETUS)
	end
end

-- POST_CLEAR_LUDOVICO_FLAGS
function mod.CheckLudovicoReset(entity, player, weaponFlag)
	if entity.FrameCount // player.MaxFireDelay ~= (entity.FrameCount - 1) // player.MaxFireDelay then
		local oldFlags = mod.GetTearFlags(entity):Clone()

		mod.WipeBlacklists(entity)
		mod.WipeTearFlags(entity)

		Isaac.RunCallback(mod.Callback.POST_CLEAR_LUDOVICO_FLAGS, entity, player, weaponFlag, oldFlags)

		if weaponFlag == mod.WeaponFlag.LASER then
			mod.PollChancelessTearFlags(entity, player, weaponFlag)
		else
			mod.PollTearFlags(entity, player, weaponFlag)
		end
	end
end

mod.CallbackFuncs.EvaluateTearHitParams = function(_, player, params, weapon, damageScale, tearDisplacement, source)
	params.TearFlags = params.TearFlags &~ mod.GuarenteedFlagTracker
end

mod.CallbackFuncs.ClearTearLudos = function(_, tear)
	if tear:HasTearFlags(TearFlags.TEAR_LUDOVICO) and mod.WasEntityFiredByPlayerMimic(tear) then
		mod.CheckLudovicoReset(tear, mod.GetTearPlayer(tear), mod.WeaponFlag.LUDOVICO_TEAR)
	end

	if mod.GetSafeData(tear).pseudoLudo.canReset then
		local frequency = mod.GetSafeData(tear).pseudoLudo.frequency or mod.GetTearPlayer(tear).MaxFireDelay
		if tear.FrameCount // frequency ~= (tear.FrameCount - 1) // frequency then
			tear:ClearHitList()
		end
	end
end

mod.CallbackFuncs.ClearLaserLudos = function(_, laser)
	if laser.SubType == LaserSubType.LASER_SUBTYPE_RING_LUDOVICO and mod.WasEntityFiredByPlayerMimic(laser) then
		mod.CheckLudovicoReset(laser, mod.GetTearPlayer(laser), mod.WeaponFlag.LASER)
	end
end

-- Misc
mod.CallbackFuncs.CheckLuck = function(_, player)
	mod.LuckCache = player.Luck
end

mod.CallbackFuncs.RegisterFlagsTracker = function(_, player, cache)
	player.TearFlags = player.TearFlags | mod.GuarenteedFlagTracker
end

mod.CallbackFuncs.CancelDamage = function(_, entity, amount, flags, source, cooldown)
	if mod.CancelDamage then return false end
end

mod.CallbackFuncs.CatchSplitTear = function(_, new, old, splitType)
	mod.GetSafeData(new).isSplitTear = true
	mod.CopyTearFlags(new, old, mod.WeaponFlag.TEAR, {wipe = true})
	mod.GetSafeData(new).checkedForFlags = true
end

mod.CallbackFuncs.CatchVasculitis = function(_, npc)
	for _, tear in pairs(Isaac.FindByType(2, mod.GetVasculitisTearVariant(npc))) do
		if mod.IsTearVasculitisTear(tear:ToTear(), npc) then
			Isaac.RunCallback(mod.Callback.POST_FIRE_VASCULITIS_TEAR, tear:ToTear(), npc)
		end
	end
end

mod.CallbackFuncs.PreFinger = function(_, familiar)
	mod.GetSafeData(familiar.Player).IsFingering = true
end

mod.CallbackFuncs.PostFinger = function(_, familiar)
	mod.GetSafeData(familiar.Player).IsFingering = false
end

mod.CallbackFuncs.PostBombTearFlags = function(_, _, _, flags, source) -- Avert your eyes young ones
	if flags & TearFlags.TEAR_SCATTER_BOMB == TearFlags.TEAR_SCATTER_BOMB and source and (mod.HasAnyTearFlags(source) or mod.HasAnyCustomVanillaTearFlags(source)) then
		mod.CatchScatterBombs = source
	end
end

mod.CallbackFuncs.BombUpdate = function(_, bomb) -- I'm so sorry, I wasn't strong enough to save you
	mod.CatchScatterBombs = nil
end

mod.CallbackFuncs.CatchSplitBombs = function(_, bomb)
	if mod.CatchScatterBombs then
		mod.CopyTearFlags(bomb, mod.CatchScatterBombs, mod.WeaponFlag.DR_FETUS, {wipe = true})
	end
end

mod.CallbackFuncs.WipeRoomEntitiesCache = function()
	mod.roomEntitiesCache = nil
end

mod.CallbackFuncs.CheckEntityLists = function()
	for key, list in pairs(mod.UpdateLists) do
		for i = #list, 1, -1 do
			local entity = list[i]
			if not entity:Exists() then
				table.remove(mod.UpdateLists[key], i)
			else
				Isaac.RunCallbackWithParam(mod.Callback.UPDATE_ENTITY_LIST, key, entity, key)
			end
		end
	end
end


mod.CallbackPairs = {
	-- Set Tearflags
	{Callback = ModCallbacks.MC_POST_FIRE_TEAR,			Function = mod.CallbackFuncs.PostFireTear},
	{Callback = ModCallbacks.MC_POST_TEAR_INIT,			Function = mod.CallbackFuncs.PostTearInit},
	{Callback = ModCallbacks.MC_FAMILIAR_UPDATE,		Function = mod.CallbackFuncs.PostFireFatesReward,	OptionalArgument = FamiliarVariant.FATES_REWARD},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = mod.CallbackFuncs.PostThrowCatchKnife,	OptionalArgument = 0},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = mod.CallbackFuncs.PostThrowCatchKnife2,	OptionalArgument = 1},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = mod.CallbackFuncs.ClubHitboxInit,		OptionalArgument = 4},
	{Callback = ModCallbacks.MC_POST_FIRE_SWORD,		Function = mod.CallbackFuncs.PostFireSword},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = mod.CallbackFuncs.KnifeUpdate},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = mod.CallbackFuncs.PostSpawnAquarius,			OptionalArgument = EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,	Function = mod.CallbackFuncs.EvaluateDarkArtsFlags,		Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,	Function = mod.CallbackFuncs.EvaluateLocust,			Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_FAMILIAR_INIT,			Function = mod.CallbackFuncs.UmbilicalWhipInit,			OptionalArgument = FamiliarVariant.UMBILICAL_BABY},
	{Callback = ModCallbacks.MC_POST_FIRE_BOMB,			Function = mod.CallbackFuncs.PostFireBomb},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = mod.CallbackFuncs.PostFireAirstrike,			OptionalArgument = EffectVariant.ROCKET},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = mod.CallbackFuncs.PostFireSmallAirstrike,	OptionalArgument = EffectVariant.SMALL_ROCKET},
	{Callback = ModCallbacks.MC_PRE_BRIMSTONE_SNEEZE,	Function = mod.CallbackFuncs.PreHemoptysis},
	{Callback = ModCallbacks.MC_POST_BRIMSTONE_SNEEZE,	Function = mod.CallbackFuncs.PostHemoptysis},

	-- Laser Handling
	{Callback = ModCallbacks.MC_POST_FIRE_BRIMSTONE,	Function = mod.CallbackFuncs.PostFireLaser},
	{Callback = ModCallbacks.MC_POST_FIRE_TECH_LASER,	Function = mod.CallbackFuncs.PostFireLaser},
	{Callback = ModCallbacks.MC_POST_FIRE_TECH_X_LASER,	Function = mod.CallbackFuncs.PostFireLaser},
	{Callback = ModCallbacks.MC_POST_LASER_INIT,		Function = mod.CallbackFuncs.CatchMegaBlast},
	-- {Callback = ModCallbacks.MC_POST_LASER_INIT,		Function = mod.CallbackFuncs.CatchSubLaser},
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE,		Function = mod.CallbackFuncs.CatchChancelessLasersNoHit},
	
	{Callback = ModCallbacks.MC_PRE_LASER_UPDATE,		Function = mod.CallbackFuncs.UpdateLaser},
	{Callback = ModCallbacks.MC_PRE_EFFECT_UPDATE,		Function = mod.CallbackFuncs.LaserSwirlUpdate,		OptionalArgument = EffectVariant.BRIMSTONE_SWIRL},
	{Callback = ModCallbacks.MC_PRE_EFFECT_UPDATE,		Function = mod.CallbackFuncs.LaserSwirlUpdate,		OptionalArgument = EffectVariant.TECH_DOT},
	{Callback = ModCallbacks.MC_PRE_EFFECT_UPDATE,		Function = mod.CallbackFuncs.BrimstoneBallUpdate,	OptionalArgument = EffectVariant.BRIMSTONE_BALL},

	{Callback = ModCallbacks.MC_PRE_LASER_UPDATE,		Function = mod.CallbackFuncs.PreMonstroLaser},
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE, 		Function = mod.CallbackFuncs.PostMonstroLaser},
	{Callback = ModCallbacks.MC_POST_LASER_INIT,		Function = mod.CallbackFuncs.CatchMonstroLaser},
	{Callback = ModCallbacks.MC_PRE_LASER_UPDATE,		Function = mod.CallbackFuncs.CatchTrisagionLaser},

	-- C Section :(
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE,		Function = mod.CallbackFuncs.CatchFetusLaserNoHit},
	{Callback = ModCallbacks.MC_POST_KNIFE_UPDATE,		Function = mod.CallbackFuncs.CatchFetusSpiritSword},

	-- Apply Tearflag Effect
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = mod.CallbackFuncs.GenericCatchApplyTearFlags},

	{Callback = ModCallbacks.MC_PRE_LASER_COLLISION,			Function = mod.CallbackFuncs.PreLaserCollision},
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = mod.CallbackFuncs.ApplyLaserFlags,		OptionalArgument = EntityType.ENTITY_LASER},
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = mod.CallbackFuncs.ApplyOcularRiftFlags,	OptionalArgument = EntityType.ENTITY_EFFECT},
	{Callback = ModCallbacks.MC_POST_APPLY_TEARFLAG_EFFECTS,	Function = mod.CallbackFuncs.ApplyHemoptysisFlags},

	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,		Function = mod.CallbackFuncs.DrFetusDamage,			Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,		Function = mod.CallbackFuncs.EpicFetusDamage,		Priority = CallbackPriority.LATE},
	{Callback = ModCallbacks.MC_POST_ENTITY_TAKE_DMG,		Function = mod.CallbackFuncs.ClubEpicFetusDamage,	Priority = CallbackPriority.LATE},

	{Callback = ModCallbacks.MC_POST_TEAR_DEATH, 		Function = mod.CallbackFuncs.CatchIpecac},
	{Callback = ModCallbacks.MC_POST_EFFECT_INIT,		Function = mod.CallbackFuncs.ExplosionInit,			OptionalArgument = EffectVariant.BOMB_EXPLOSION},

	-- Chanceless Laser Flags
	{Callback = ModCallbacks.MC_EVALUATE_TEAR_HIT_PARAMS,	Function = mod.CallbackFuncs.EvaluateTearHitParams},

	-- Clear Ludo Flags
	{Callback = ModCallbacks.MC_POST_TEAR_UPDATE,		Function = mod.CallbackFuncs.ClearTearLudos},
	{Callback = ModCallbacks.MC_POST_LASER_UPDATE,		Function = mod.CallbackFuncs.ClearLaserLudos},

	-- Misc
	{Callback = ModCallbacks.MC_EVALUATE_CACHE,			Function = mod.CallbackFuncs.CheckLuck,				Priority = 999999999, OptionalArgument = CacheFlag.CACHE_LUCK},
	{Callback = ModCallbacks.MC_EVALUATE_CACHE,			Function = mod.CallbackFuncs.RegisterFlagsTracker,	Priority = -99999999, OptionalArgument = CacheFlag.CACHE_TEARFLAG},
	{Callback = ModCallbacks.MC_ENTITY_TAKE_DMG,		Function = mod.CallbackFuncs.CancelDamage,			Priority = CallbackPriority.IMPORTANT},
	{Callback = ModCallbacks.MC_POST_NPC_DEATH,			Function = mod.CallbackFuncs.CatchVasculitis},
	{Callback = ModCallbacks.MC_POST_FIRE_SPLIT_TEAR,	Function = mod.CallbackFuncs.CatchSplitTear,		Priority = -99999999},
	{Callback = ModCallbacks.MC_POST_UPDATE,			Function = mod.CallbackFuncs.WipeRoomEntitiesCache},
	{Callback = ModCallbacks.MC_PRE_NEW_ROOM,			Function = mod.CallbackFuncs.WipeRoomEntitiesCache},
	{Callback = ModCallbacks.MC_POST_UPDATE,			Function = mod.CallbackFuncs.CheckEntityLists},

	-- The FINGER :(
	{Callback = ModCallbacks.MC_PRE_FAMILIAR_UPDATE,	Function = mod.CallbackFuncs.PreFinger,		OptionalArgument = FamiliarVariant.FINGER},
	{Callback = ModCallbacks.MC_FAMILIAR_UPDATE, 		Function = mod.CallbackFuncs.PostFinger,	OptionalArgument = FamiliarVariant.FINGER},

	-- Scatter Bombs :(
	{Callback = ModCallbacks.MC_POST_BOMB_TEARFLAG_EFFECTS,	Function = mod.CallbackFuncs.PostBombTearFlags},
	{Callback = ModCallbacks.MC_POST_BOMB_UPDATE,			Function = mod.CallbackFuncs.BombUpdate},
	{Callback = ModCallbacks.MC_POST_BOMB_INIT,				Function = mod.CallbackFuncs.CatchSplitBombs},
}

function mod.RegisterCallbacks()
	-- Normally I really hate defining callbacks the way I have here
	-- Inline callbacks are far easier to understand imo
	-- But afaik you can't unregister inlined callbacks
	-- So alas

	-- c'est la vie
	for i, data in pairs(mod.CallbackPairs) do
		mod:AddPriorityCallback(data.Callback, data.Priority or CallbackPriority.DEFAULT, data.Function, data.OptionalArgument)
	end

	mod:AddCallback(mod.Callback.__META_RELOADDETECTOR, function() end)
end

function mod.UnregisterCallbacks()
	for i, data in pairs(mod.CallbackPairs) do
		-- print("remove callback", i, data.Callback, data.Function)
		mod:RemoveCallback(data.Callback, data.Function)
	end
end

-- Changed function names, maintained for compatibility
mod.CallTearFlagCallback 			= mod.ApplyWeaponTearFlags
mod.CallExplosionTearFlagCallback 	= mod.ApplyWeaponExplosionTearFlags
mod.CallPollTearFlagCallback 		= mod.PollTearFlags