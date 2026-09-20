local mod = TearFlagsLib
local game = Game()
mod.roomEntitiesCache = nil

mod.SPLITSHOT_TEAR_FLAGS 		= TearFlags.TEAR_SPLIT | TearFlags.TEAR_QUADSPLIT | TearFlags.TEAR_BONE | TearFlags.TEAR_BURSTSPLIT | TearFlags.TEAR_LASERSHOT
mod.STICKY_TEAR_FLAGS 			= TearFlags.TEAR_STICKY | TearFlags.TEAR_BOOGER | TearFlags.TEAR_SPORE
mod.EXPLOSIVE_TEARFLAGS 		= TearFlags.TEAR_EXPLOSIVE | TearFlags.TEAR_BURN
mod.PIERCING_TEARFLAGS      	= TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_PIERCING | TearFlags.TEAR_PERSISTENT | TearFlags.TEAR_LASERSHOT
mod.FETUS_LASER_TEAR_FLAGS		= TearFlags.TEAR_FETUS_TECH | TearFlags.TEAR_FETUS_TECHX	
mod.NO_REMOVE_TEAR_FLAGS		= TearFlags.TEAR_EXPLOSIVE | TearFlags.TEAR_MYSTERIOUS_LIQUID_CREEP
mod.REMOVE_ON_SPLITSHOT_FLAGS	= TearFlags.TEAR_TRACTOR_BEAM | TearFlags.TEAR_SCATTER_BOMB | TearFlags.TEAR_LUDOVICO

mod.playerMimickingFamiliarMap = mod.playerMimickingFamiliarMap or {}
mod.RegisterPlayerMimicFamiliar({
	FamiliarVariant.INCUBUS,
	FamiliarVariant.FATES_REWARD,
	FamiliarVariant.SPRINKLER,
	FamiliarVariant.TWISTED_BABY,
	FamiliarVariant.UMBILICAL_BABY,
	FamiliarVariant.BLOOD_BABY,
	FamiliarVariant.CAINS_OTHER_EYE,
})

-- Generally speaking effects that spawn tears which apply tear effects just fire the tear AS their Parent Player
-- However Evil Eye is a special case that actually swings Bone Clubs as The Forgotton
-- These clubs are not parented to The Forgotton, they're owned by the Evil Eye
-- But Evil Eye is supposed to get TearFlags, so this has to be handled
mod.playerMimickingEffectMap = mod.playerMimickingFamiliarMap or {}
mod.RegisterPlayerMimicEffect({
	EffectVariant.EVIL_EYE,
})

local function getClosestPointOnLine(testPosition, lineOrigin, lineEnd)
	local heading = lineEnd - lineOrigin
	local magnitude = heading:Length()
	heading:Normalize()

	local lhs = testPosition - lineOrigin
	local dot = lhs:Dot(heading)
	dot = math.min(math.max(0, dot), magnitude)
	return lineOrigin + heading * dot
end

local function truncateDecimals(value, numDigits)
	local whole = math.floor(value)
	local totalDigits = string.len(tostring(whole)) + numDigits + 1
	local truncatedString = string.sub(tostring(value), 1,  totalDigits)
	return tonumber(truncatedString)
end

function mod.GetRoomEntities()
	mod.roomEntitiesCache = mod.roomEntitiesCache or Isaac.GetRoomEntities()
	return mod.roomEntitiesCache
end

function mod.ForAllEntities(func)
	for _, entity in pairs(mod.GetRoomEntities()) do
		if entity:Exists() then
			func(entity)
		end
	end
end

function mod.IsKnifeSwingable(knife)
	return (
		knife.Variant == KnifeVariant.BONE_CLUB or
		knife.Variant == KnifeVariant.BONE_SCYTHE or
		knife.Variant == KnifeVariant.DONKEY_JAWBONE or
		knife.Variant == KnifeVariant.BAG_OF_CRAFTING or
		knife.Variant == KnifeVariant.NOTCHED_AXE or
		knife.Variant == KnifeVariant.SPIRIT_SWORD or
		knife.Variant == KnifeVariant.TECH_SWORD
	)
end

function mod.IsKnifeSwinging(knife)
	local animation = knife:GetSprite():GetAnimation()

	return (
		animation == "Swing" or
		animation == "Swing2" or
		animation == "SwingDown" or
		animation == "SwingDown2" or

		animation == "AttackRight" or -- Spirit Sword
		animation == "AttackLeft" or
		animation == "AttackUp" or
		animation == "AttackDown" or
		animation == "SpinRight" or
		animation == "SpinLeft" or
		animation == "SpinUp" or
		animation == "SpinDown"
	)
end

function mod.DoesKnifeVariantPollEveryFrame(variant)
	return (
		variant == KnifeVariant.MOMS_KNIFE or
		variant == KnifeVariant.SUMPTORIUM
	)
end

function mod.IsKnifeSwingableAndThrowable(knife)
	return (
		knife.Variant == KnifeVariant.BONE_CLUB or
		knife.Variant == KnifeVariant.BONE_SCYTHE or
		knife.Variant == KnifeVariant.DONKEY_JAWBONE
	)
end

function mod.IsKnifeThrowable(knife)
	return mod.IsKnifeVariantTrueKnife(knife.Variant) or mod.IsKnifeSwingableAndThrowable(knife)
end

function mod.CanClubVariantHaveTearEffects(variant)
	return (
		variant == KnifeVariant.BONE_CLUB or
		variant == KnifeVariant.BONE_SCYTHE or
		variant == KnifeVariant.DONKEY_JAWBONE or
		variant == KnifeVariant.NOTCHED_AXE
	)
end

function mod.IsKnifeVariantClub(variant)
	return (
		variant == KnifeVariant.BONE_CLUB or
		variant == KnifeVariant.BONE_SCYTHE or
		variant == KnifeVariant.DONKEY_JAWBONE or
		variant == KnifeVariant.BAG_OF_CRAFTING or
		variant == KnifeVariant.NOTCHED_AXE
	)
end

function mod.IsKnifeVariantSword(variant)
	return (
		variant == KnifeVariant.SPIRIT_SWORD or
		variant == KnifeVariant.TECH_SWORD
	)
end

function mod.IsKnifeVariantTrueKnife(variant)
	return (
		variant == KnifeVariant.MOMS_KNIFE or
		variant == KnifeVariant.SUMPTORIUM
	)
end

function mod.GetSwingingKnifeHitboxScaler(knife)
	if knife.Variant == KnifeVariant.BONE_SCYTHE then
		return 3
	end

	return 2
end

function mod.GetSwingingKnifeCapsulePositionRadius(knife)
	local scaler = mod.GetSwingingKnifeHitboxScaler(knife)
	local capsuleRadius = knife.Size * scaler * knife.SpriteScale.X
	local knifeVectorDirection = Vector(0, 1):Rotated(knife.SpriteRotation)
	local capsulePosition = knife.Position - knife.SpawnerEntity.Velocity + knifeVectorDirection * capsuleRadius

	return capsulePosition, capsuleRadius 
end

function mod.DoesEntityCollideWithSwingingKnife(entity, knife)
	local position, radius = mod.GetSwingingKnifeCapsulePositionRadius(knife)
	return entity.Position:Distance(position) < entity.Size + radius
end

function mod.AreEntitiesSame(entity1, entity2)
	return entity1 and entity2 and GetPtrHash(entity1) == GetPtrHash(entity2)
end

function mod.GetTearPlayer(tear, strict)
	if strict and not (tear.SpawnerEntity or tear.Parent) then return end

	local parent = tear.SpawnerEntity or tear.Parent or Isaac.GetPlayer()
	local familiar = parent:ToFamiliar()
	local effect = parent:ToEffect()

	if familiar then
		parent = familiar.Player
	end

	if effect then
		parent = (parent.SpawnerEntity or parent.Parent) or Isaac.GetPlayer()
	end

	return parent:ToPlayer() or Isaac.GetPlayer()
end

function mod.IsFamiliarPlayerMimic(familiar)
	return mod.playerMimickingFamiliarMap[familiar.Variant]
end

function mod.WasEntityFiredByPlayerMimic(entity, explicit)
	if not entity.SpawnerEntity then
		return false
	end

	local player = entity.SpawnerEntity:ToPlayer()
	if player and not explicit then
		return true
	end

	local familiar = entity.SpawnerEntity:ToFamiliar()
	if familiar and mod.playerMimickingFamiliarMap[familiar.Variant] then
		return true
	end

	local effect = entity.SpawnerEntity:ToEffect()
	if effect and mod.playerMimickingEffectMap[effect.Variant] then
		return true
	end

	return false
end

function mod.ShouldEntityGetTearCollisionEffects(entity, tear)
	return (
		entity:ToNPC() and
		not entity:HasEntityFlags(EntityFlag.FLAG_ICE_FROZEN) and
		not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
	)
end

function mod.ShouldEntityGetKnifeCollisionEffects(entity, knife)
	return (
		entity:ToNPC() and
		entity:Exists() and
		entity.EntityCollisionClass > 0 and
		entity.FrameCount > 1 and
		not entity:IsDead() and
		not entity:HasEntityFlags(EntityFlag.FLAG_ICE_FROZEN) and
		not entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
	)
end

function mod.GetCapsule(locus1, locus2, radius) -- Nobody is allowed to talk to me
	return {
		Locus1 = locus1,
		Locus2 = locus2,
		Radius = radius,
	}
end

function mod.GenerateCapsuleFromEntity(entity)
	local scaler = math.min(entity.SizeMulti.X, entity.SizeMulti.Y)
	local stretcher = math.max(entity.SizeMulti.X, entity.SizeMulti.Y)
	local trueRadius = entity.Size * scaler
	
	local stretchDirection = Vector.Zero
	if entity.SizeMulti.X > entity.SizeMulti.Y then stretchDirection = Vector(1, 0) end
	if entity.SizeMulti.Y > entity.SizeMulti.X then stretchDirection = Vector(0, 1) end

	local locusOffset = stretchDirection * (stretcher * entity.Size - trueRadius)

	return {
		Locus1 = entity.Position + locusOffset:Rotated(entity.SpriteRotation),
		Locus2 = entity.Position - locusOffset:Rotated(entity.SpriteRotation),
		Radius = trueRadius,
	}
end

function mod.SimulateCapsuleCapsuleCollision(capsule1, capsule2)
	local capsules = {capsule1, capsule2}

	for i, hostCapsule in pairs(capsules) do
		local testCapsule = capsules[i % 2 + 1]
		for _, point in pairs({testCapsule.Locus1, testCapsule.Locus2}) do
			local closestPoint = getClosestPointOnLine(point, hostCapsule.Locus1, hostCapsule.Locus2)
			local distance = truncateDecimals(closestPoint:Distance(point), 3)
			-- print("\nLine:", testCapsule.Locus1, testCapsule.Locus2, "\nPoint:", point, "\nClosest:", closestPoint, "\nDistance:", distance)

			if distance <= hostCapsule.Radius + testCapsule.Radius then
				return true
			end
		end
	end

	return false
end

function mod.DoesCapsuleCollideWithEntity(capsule, entity)
	return mod.SimulateCapsuleCapsuleCollision(capsule, mod.GenerateCapsuleFromEntity(entity))
end

function mod.GetLaserSampleCapsules(laser)
	local samples = laser:GetSamples()
	local capsules = {}

	for i = 1, #samples do
		local position = samples:Get(i - 1)
		local radius = laser.Radius

		if i == #samples then
			capsules[i-1].Locus2 = position
		elseif i > 1 then
			capsules[i] = capsules[i] or {}
			capsules[i].Locus1 = position
			capsules[i].Radius = radius
			capsules[i-1].Locus2 = position
		else
			capsules[1] = capsules[1] or {}
			capsules[1].Locus1 = position
			capsules[1].Radius = radius
		end
	end

	return capsules
end

function mod.CanLaserDamageThisFrame(laser)
	return (
		laser.FrameCount == 0 or
		(laser.FrameCount > 2 and laser.FrameCount % 2 == 1)
	)
end

function mod.CanBrimstoneBallDamageThisFrame()
	return game:GetFrameCount() % 2 == 0 -- Crazy stuff
end

function mod.CostumeStickyTear(tear)
	if tear.TearFlags & TearFlags.TEAR_SPORE > 0 then
		tear:ChangeVariant(TearVariant.SPORE)
	elseif tear.TearFlags & TearFlags.TEAR_BOOGER > 0 then
		tear:ChangeVariant(TearVariant.BOOGER)
	elseif tear.TearFlags & TearFlags.TEAR_STICKY > 0 then
		tear:ChangeVariant(TearVariant.METALLIC)
	end
end

function mod.GetVasculitisTearVariant(npc)
	local variant = (REPENTANCE_PLUS and 26) or 1

	if npc:HasEntityFlags(EntityFlag.FLAG_BURN) then
		variant = 5
	end
	
	if npc:HasEntityFlags(EntityFlag.FLAG_ICE) then
		variant = 41
	end

	return variant
end

function mod.IsTearVasculitisTear(tear, comparator)
	local level = game:GetLevel()
	local stageFactor = level:GetStage() * 0.3 + 3.2
	local numTears = math.min(16, math.ceil(comparator.MaxHitPoints / stageFactor))
	local tearDamage = math.max(stageFactor, comparator.MaxHitPoints / numTears)

	return (
		tear.FrameCount == 0 and
		tear.CollisionDamage - tearDamage < 0.0001 and -- I hate floating point numbers
		tear.Position:Distance(comparator.Position + tear.PosDisplacement) - (REPENTANCE_PLUS and (comparator.Size + 1) or 0) < 0.0001
	)
end

function mod.CopyTable(oldTable)
	local newTable = {}
	for key, value in pairs(oldTable) do
		if type(value) == "table" then
			newTable[key] = mod.CopyTable(value)
		else
			newTable[key] = value
		end
	end
	return newTable
end

function mod.FuzzyReplaceTable(oldTable, newTable)
	for key, value in pairs(newTable) do
		oldTable[key] = value
	end

	return oldTable
end

function mod.AgnosticGetVanillaTearFlags(entity, skipPlayerCheck)
	local flags = mod.BitSetZero
	entity = mod.Cast(entity)

	if (entity.TearFlags or entity.Flags) and entity.Type ~= 1 then
		flags = flags | (entity.TearFlags or entity.Flags)
	end

	if not skipPlayerCheck then
		local player = entity.Type == 1 and entity or mod.GetTearPlayer(entity, true)
		if player then
			flags = flags | player.TearFlags
		end
	end
	
	return flags
end

function mod.PlayerHasItemEffect(player, item)
	return player:GetEffects():HasCollectibleEffect(item)
end

function mod.IsEntityAntiGravLaserSpawner(entity)
	return entity.Type == EntityType.ENTITY_EFFECT and (
		entity.Variant == EffectVariant.BRIMSTONE_SWIRL or
		entity.Variant == EffectVariant.TECH_DOT
	)
end

function mod.IsEntitySpiritSword(entity)
	return entity.Type == EntityType.ENTITY_KNIFE and (
		entity.Variant == KnifeVariant.SPIRIT_SWORD or
		entity.Variant == KnifeVariant.TECH_SWORD
	)
end

function mod.IsEntityOcularRift(entity)
	return entity.Type == EntityType.ENTITY_EFFECT and (
		entity.Variant == EffectVariant.RIFT
	)
end

function mod.IsLaserTrisagion(laser)
	return (
		laser.Variant == 3 and
		laser.SubType == 0 and
		laser.Parent and
		laser.Parent.Type == 2 and
		laser:ToLaser():HasTearFlags(TearFlags.TEAR_LASERSHOT)
	)
end

function mod.IsLaserIncubusTechnology(source)
	return (
		source.Variant == LaserVariant.THIN_RED and
		mod.WasEntityFiredByPlayerMimic(source, true)
	)
end

function mod.IsLaserCSectionTechnology(source, isFetusParent)
	if isFetusParent then
		return (
			source.Parent and
			source.Parent.Type == 2 and
			source:ToLaser().TearFlags & mod.FETUS_LASER_TEAR_FLAGS ~= mod.BitSetZero
		)
	else
		return source:ToLaser().TearFlags & mod.FETUS_LASER_TEAR_FLAGS ~= mod.BitSetZero
	end
end

function mod.IsLaserClubTechnology(source)
	return (
		source.Parent and
		source.Parent.Type == 8 and
		mod.CanClubVariantHaveTearEffects(source.Parent.Variant)
	)
end

function mod.IsLaserThrownClubTechnology(laser, club)
	return (
		mod.AreEntitiesSame(laser.SpawnerEntity, club.SpawnerEntity) and
		laser.EndPoint:Distance(club.Position + Vector.FromAngle(club.Rotation) * 16) < 2 -- I've seen this miss by up to 1.5, so 2 seems safe, even if it's not as accurate as I would like
	)
end

function mod.IsLaserFinger(laser)
	return (
		laser.SpawnerEntity and
		mod.GetSafeData(laser.SpawnerEntity).IsFingering
	)
end

function mod.ShouldCopyLaserFlagsOnFirstUpdate(source)
	return not mod.GetSafeData(source).checkedFlags and (
		mod.IsLaserCSectionTechnology(source, true) or
		mod.IsLaserClubTechnology(source)
	)
end

function mod.ShouldPollLaserFlagsOnApply(source)
	return not mod.GetSafeData(source).checkedFlags and (
		mod.IsLaserIncubusTechnology(source) or
		mod.IsLaserCSectionTechnology(source) or
		mod.IsLaserClubTechnology(source) or
		mod.IsLaserTrisagion(source)
	)
end

function mod.DidLaserCopyPlayerFlags(source)
	return (
		source:ToLaser().TearFlags & mod.GuarenteedFlagTracker == mod.GuarenteedFlagTracker
		and not mod.GetSafeData(source).CanRollForFlags
	)
end

function mod.IsSwordCSectionSword(source)
	return (
		source.Parent and
		source.Parent.Type == 2 and
		source:ToKnife().TearFlags & TearFlags.TEAR_FETUS_SWORD ~= mod.BitSetZero
	)
end

function mod.IsClubCSectionClub(source)
	return (
		source.Parent and
		source.Parent.Type == 2 and
		source:ToKnife().TearFlags & TearFlags.TEAR_FETUS_BONE ~= mod.BitSetZero
	)
end

function mod.EstimateCSectionParent(source)
	local dist = 9e9
	local closest = nil

	for _, tear in pairs(Isaac.FindByType(2)) do
		local player = mod.GetTearPlayer(tear)
		if mod.AreEntitiesSame(player, source.SpawnerEntity) and tear.Position:Distance(source.Position) < dist then
			dist = tear.Position:Distance(source.Position)
			closest = tear
		end
	end

	return closest
end

function mod.SetTearScale(tear, scale)
	local scytheMod = tear.Variant == 8 and 0.5 or 1
	tear.Scale = scale * scytheMod
end

function mod.TryChangeTearVariant(tear, variant)
	if tear.Variant ~= variant then
		tear:ChangeVariant(variant)
	end
end

function mod.PlayerHasLudoKnife(player)
	local weapon = player:GetActiveWeaponEntity()

	return (
		player:HasWeaponType(WeaponType.WEAPON_KNIFE) and
		weapon and
		weapon:ToKnife() and
		weapon:ToKnife().TearFlags & TearFlags.TEAR_LUDOVICO ~= 0
	)
end

function mod.Cast(entity)
	if entity.Type == 1 then
		return entity:ToPlayer()
	elseif entity.Type == 2 then
		return entity:ToTear()
	elseif entity.Type == 3 then
		return entity:ToFamiliar()
	elseif entity.Type == 4 then
		return entity:ToBomb()
	elseif entity.Type == 5 then
		return entity:ToPickup()
	elseif entity.Type == 6 then
		return entity:ToSlot()
	elseif entity.Type == 7 then
		return entity:ToLaser()
	elseif entity.Type == 8 then
		return entity:ToKnife()
	elseif entity.Type == 9 then
		return entity:ToProjectile()
	elseif entity.Type >= 1000 then
		return entity:ToEffect()
	else
		return entity:ToNPC()
	end
end

function mod.SpawnDummyEntity(player, weaponFlag, positionOverride) -- Spawns an entity that removes itself after the current update cycle
	local dummy = Isaac.CreateTimer(function() end, 0, 0, false)
	mod.GetSafeData(dummy).dummyWeaponIdentity = weaponFlag
	dummy.Parent = player
	dummy.Position = positionOverride or player.Position

	return dummy
end

function mod.GetVanillaTearFlagDamageFlags(source)
	local flags = mod.AgnosticGetVanillaTearFlags(source, true) | mod.GetCustomVanillaTearFlags(source)
	local damageFlags = 0

	if flags & TearFlags.TEAR_MULLIGAN == TearFlags.TEAR_MULLIGAN then
		damageFlags = damageFlags | DamageFlag.DAMAGE_SPAWN_FLY
	end

	if flags & TearFlags.TEAR_EXPLOSIVE == TearFlags.TEAR_EXPLOSIVE then
		damageFlags = damageFlags | DamageFlag.DAMAGE_EXPLOSION
	end

	if flags & TearFlags.TEAR_HP_DROP == TearFlags.TEAR_HP_DROP then
		if mod.GetTearPlayer(source):GetCollectibleRNG(CollectibleType.COLLECTIBLE_GIMPY):RandomFloat() < 1/3 then -- Gimpy doesn't even actually use this anymore but SOMETHING probably does
			damageFlags = damageFlags | DamageFlag.DAMAGE_SPAWN_RED_HEART
		end
	end

	if flags & TearFlags.TEAR_ROCK == TearFlags.TEAR_ROCK then
		damageFlags = damageFlags | DamageFlag.DAMAGE_CRUSH
	end

	if flags & TearFlags.TEAR_COIN_DROP_DEATH == TearFlags.TEAR_COIN_DROP_DEATH then
		damageFlags = damageFlags | DamageFlag.DAMAGE_SPAWN_COIN
	end

	if flags & TearFlags.TEAR_CARD_DROP_DEATH == TearFlags.TEAR_CARD_DROP_DEATH then
		damageFlags = damageFlags | DamageFlag.DAMAGE_SPAWN_CARD
	end

	if flags & TearFlags.TEAR_RUNE_DROP_DEATH == TearFlags.TEAR_RUNE_DROP_DEATH then
		damageFlags = damageFlags | DamageFlag.DAMAGE_SPAWN_RUNE
	end

	return damageFlags
end

-- Monstro's Lung replication by Ghostbroster and TaigaTreant
function mod.GetMonstroBurstInfo(pos, baseVel, num, baseFallSpeed, baseFallAccel, rng)
    local out = {}
    local rng = rng or Isaac.GetPlayer():GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)

    for i = 1, (num or 14) do
        local a = rng:RandomFloat(-1, 1)
        local b = rng:RandomFloat(-1, 1) * math.pi * 2

        local tearVelX = math.cos(b) * a * 3.5 + baseVel.X
        local tearVelY = math.sin(b) * a * 3.5 + baseVel.Y

        local fallingSpeed = rng:RandomFloat(0, 0.2) - (baseFallSpeed or -0.18337345)
        local fallingAccel = baseFallAccel or 0

        if fallingAccel > 0.0 then
            fallingSpeed = fallingSpeed - rng:RandomFloat() * 10.0
        else
            fallingSpeed = (fallingSpeed - rng:RandomFloat() * 15.0) + 5.0
            fallingAccel = fallingAccel + 0.5
        end

        table.insert(out, {
            Pos = pos,
            Vel = Vector(tearVelX, tearVelY),
            ScaleMult = rng:RandomInt(0, 1) * 0.4 + 0.9 + rng:RandomFloat(-1, 1) * 0.05,
            FallingSpeed = fallingSpeed,
            FallingAcceleration = fallingAccel,
        })
    end

    return out
end


function mod.GetPlayerMonstroBurstInfo(player, pos, vel, num, rng, ignoreShotSpeed)
	if not ignoreShotSpeed then
        vel = vel * player.ShotSpeed
    end
    return mod.GetMonstroBurstInfo(pos, vel, num, player.TearFallingSpeed, player.TearFallingAcceleration, rng)
end

function mod.GetMonstroBombBurstInfo(pos, baseVel, num, rng)
    local out = {}
    local rng = rng or Isaac.GetPlayer():GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)

    for i = 1, (num or 5) do
        local a = rng:RandomFloat(-1, 1)
        local b = rng:RandomFloat(-1, 1) * math.pi * 2
        local velX = math.cos(b) * a * 3.5 + baseVel.X
        local velY = math.sin(b) * a * 3.5 + baseVel.Y
        local vel = Vector(velX, velY) * rng:RandomFloat(0.4, 1.0)

        table.insert(out, {
            Pos = pos,
            Vel = vel,
            ScaleMult = rng:RandomFloat(0.15) + rng:RandomInt(1) * 0.2 + 0.4,
            FallSpeed = -1 - rng:RandomFloat(8),
            FallAcceleration = 0.8,
            Height = rng:RandomInt(-8, -4),
            ExplosionCountdown = rng:RandomInt(15, 30)
        })
    end

    return out
end

-- Temporary, some laser functions aren't in release rgon yet
local rgonUpdated = getmetatable(EntityLaser).__class.SetInitSound ~= nil
function mod.GetMonstroLaserBurstInfo(pos, baseDir, num)
    local out = {}
    local rng = rng or Isaac.GetPlayer():GetCollectibleRNG(CollectibleType.COLLECTIBLE_MONSTROS_LUNG)
    baseDir = baseDir:Normalized()

    for i = 1, (num or 6) do
        local a = 50 * rng:RandomFloat()
        local b = 2 * rng:RandomFloat() * math.pi

        local x = math.cos(b) * a + baseDir.X * 70
        local y = math.sin(b) * a + baseDir.Y * 70

        local chainSegmentDistance = math.sqrt(x * x + y * y)

        if chainSegmentDistance > 0 then
            x = x * (1/chainSegmentDistance)
            y = y * (1/chainSegmentDistance)
        end

        local laserPos = pos + baseDir * 10
        local laserDir = Vector(x,y):Normalized()

        table.insert(out, {
            Pos = laserPos,
            Dir = laserDir,
            ScaleMult = rng:RandomInt(1) * 0.4 + 0.9 + rng:RandomFloat(0.05),
            ChainSegmentDistance = chainSegmentDistance,
            NumChainedLasers = rng:RandomInt(3, 4),
            RgonUpdated = rgonUpdated,
        })
    end

    return out
end

function mod.IsLaserVariantBrimstone(variant)
	return (
		variant == LaserVariant.THICK_RED
		or variant == LaserVariant.SHOOP
		or variant == LaserVariant.BRIM_TECH
		or variant == LaserVariant.THICKER_RED
		or variant == LaserVariant.THICK_BROWN
		or variant == LaserVariant.THICKER_BRIM_TECH
	)
end

function mod.RemoveUserDataValueFromTable(value, tbl)
	for i = #tbl, 1, -1 do
		if mod.AreEntitiesSame(value, tbl[i]) then
			table.remove(tbl, i)
		end
	end
end

-- Entity identification shorthands for flag application
mod.IsEntity = {
	-- Tears
	Tear 	= function(entity) return entity.Type == 2 end,

	-- Familiars
	Gello 	= function(entity) return entity.Type == 3 and entity.Variant == 240 end,

	-- Lasers
	Laser 	= function(entity) return entity.Type == 7 end,

	-- Knives
	Knife 	= function(entity) return entity.Type == 8 and mod.IsKnifeThrowable(entity) and entity.SubType ~= 4 end,
	Club 	= function(entity) return entity.Type == 8 and entity.SubType == 4 and not mod.IsKnifeVariantSword(entity.Variant) end,
	Sword 	= function(entity) return entity.Type == 8 and mod.IsKnifeVariantSword(entity.Variant) end,

	-- Effects
	Aquarius = function(entity) return entity.Type == 1000 and entity.Variant == EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL end,
	LaserSwirl = function(entity) return mod.IsEntityAntiGravLaserSpawner(entity) end,
	BrimstoneBall = function(entity) return entity.Type == 1000 and entity.Variant == EffectVariant.BRIMSTONE_BALL end,
	OcularRift = function(entity) return entity.Type == 1000 and entity.Variant == EffectVariant.RIFT end,
}