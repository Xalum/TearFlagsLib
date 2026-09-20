Tear Flags Library (AKA. TearFlagsLib). By: Xalum, TaigaTreant, and GhostBroster
================================================================================

This document serves as an introduction to the capabilities of TearFlagsLib, and suggests a few best-practises.
This is not an extensive list of every Table, Function, and Callback added by TearFlagsLib. For complete understanding of the library, read `main.lua` and the first ~100 lines of `callbacks.lua`

`library.lua` contains a lot of functions which support TearFlagsLib's behaviour, they were not created with the intention of being used by mods which integrate TearFlagsLib, but are accessible under the global TearFlagsLib table nonetheless

Bundled with TearFlagsLib is the BitSetInfinity object. This object is accessible as `TearFlagsLib.BitSetInfinity`, and serves as an extended version of Isaac's inbuilt BitSet128.
BitSetInfinity objects do not support arithmetic operations, only bitwise operations, however do have a number of bonus quality of life features compared to BitSet128. For more information about BitSetInfinity, read `bitset_infinity.lua`

ALSO bundled with TearFlagsLib is the GetDataCache module, available globally under `GetDataCache`.
The function `GetDataCache.GetEntityData(entity)` serves as a 1-to-1 replacement for the ever-useful `entity:GetData()`, however boasts vastly improved performance metrics in larger mods with lots of `GetData` calls.
We recommended storing a reference to `GetDataCache.GetEntityData` in your mod variable for easy access, and to always use it instead of `GetData`.


Adding TearFlagsLib into your mod
=================================

In order to add TearFlagsLib to your mod, simply copy the entire tearflagslib folder into your mod's directory, and update the `mod.Source` value found in TearFlagsLib's `main.lua` to point towards the new folder location.
Then simply load TearFlagsLib's `main.lua` from your mod's code on initialisation using the standard `include()` function.



Important Tables
================

### TearFlagsLib.Flag

Stores all registered custom TearFlags, accessible as `TearFlagsLib.Flag.MY_TEARFLAG`

---
### TearFlagsLib.WeaponFlag

Stores all supported vanilla and registered custom WeaponFlags, accessible as `TearFlagsLib.WeaponFlag.MY_WEAPON`

By default contains the following flags: `TEAR`, `LASER`, `KNIFE`, `CLUB`, `AQUARIUS`, `DARK_ARTS`, `DR_FETUS`, `EPIC_FETUS`, `LOCUST`, `UMBILICAL_WHIP`, `BRIMSTONE_BALL`, `ANTI_GRAV_LASER`, `SWORD`, `OCULAR_RIFT`, `HEMOPTYSIS`, `CLUB_EPIC_FETUS`, `LUDOVICO_TEAR`, `BOBS_ROTTEN_HEAD`, `SHARP_KEY`

---
### TearFlagsLib.Callback

Stores all of TearFlagsLib's custom callbacks. More information about these callbacks is present later in this document



Important Functions
===================

### (BitSetInfinity) TearFlagsLib.RegisterTearFlag(str: FlagName)

Used to register new TearFlags into TearFlagsLib.Flag, this will automatically assign your Flag and optionally returns the corresponding BitSetInfinity value.
Best practise suggests that your Flag names should be appended with a unique identifier to avoid overlap, such as an abbreviation for your mod (e.g. `"FF_LAWN_DARTS"`, `"RET_CHOLERA"`).

Usable via 2 methods:
* `TearFlagsLib.RegisterTearFlag("MYMOD_MY_FLAG")`
* `TearFlagsLib.RegisterTearFlag({"MYMOD_MY_FLAG_1, MYMOD_MY_FLAG_2, MYMOD_MY_FLAG_3"})`

> [!NOTE]
> Flags can be accessed by any mod as `TearFlagsLib.Flag.MYMOD_MY_FLAG`, etc

---
### (BitSetInfinity) TearFlagsLib.RegisterWeapon(str: WeaponName)

Used to register new Weapons into TearFlagsLib.WeaponFlag, this will automatically assign your WeaponFlag and optionally returns the corresponding BitSetInfinity value.
Best practise suggests that your Weapon names should be appended with a unique identifier to avoid overlap, such as an abbreviation for your mod (e.g. `"FF_MALICE"`).

Usable via 2 methods:
* `TearFlagsLib.RegisterWeapon("MYMOD_MY_WEAPON")`
* `TearFlagsLib.RegisterWeapon({"MYMOD_MY_WEAPON_1, MYMOD_MY_WEAPON_2"})`

> [!NOTE]
> Weapons can be accessed by any mod as `TearFlagsLib.WeaponFlag.MYMOD_MY_WEAPON`, etc.

---
### (Void) TearFlagsLib.RegisterWeaponIdentityFunction(BitSetInfinity: WeaponFlag, Function: TestFunction)

Registration of an identity function allows your custom Weapons to be identified by `TearFlagsLib.EstimateWeaponFlagFromEntity`. This is highly recommended but not mandatory.
e.g:
```lua
	TearFlagsLib.RegisterWeaponIdentityFunction(TearFlagsLib.WeaponFlag.FF_MALICE, function(entity)
	    return (
	        entity.Type == FiendFolio.FF.BallOfMalice.ID
	        and entity.Variant == FiendFolio.FF.BallOfMalice.Var
	        and entity.SubType == FiendFolio.FF.BallOfMalice.Sub
	    )
	end)
```

----
### (Void) TearFlagsLib.AddTearFlags(Entity: WeaponEntity, BitSetInfinity: FlagsToAdd, Boolean: Force)

Used to add new custom TearFlags to an entity.
This function triggers the `PRE_ADD_TEARFLAG` and `POST_ADD_TEARFLAG` callbacks. Passing `true` to Force skips `PRE_ADD_TEARFLAG`
Consider forcing TearFlag addition for Familiars which use a specific TearFlag, or new Characters who's gimmick relies on their TearFlag

---
### (BitSetInfinity) TearFlagsLib.GetTearFlags(Entity: WeaponEntity)

Used to retrieve the BitSetInfinity bitmask containing all of an entity's custom TearFlags.

---
### (Boolean) TearFlagsLib.HasTearFlags(Entity: WeaponEntity, BitSetInfinity: FlagsToTest)

Used to confirm the presence of a custom TearFlag (or multiple TearFlags simultaneously) on an entity.

---
### (Boolean) TearFlagsLib.HasAnyTearFlags(Entity: WeaponEntity)

Used to test if a given weapon has gained any custom TearFlag. This is mostly an optimisation tool.

---
### (Void) TearFlagsLib.ClearTearFlags(Entity: WeaponEntity, BitSetInfinity: FlagsToRemove, Boolean: Force)

Used to remove custom TearFlags from an entity.
This function triggers the `PRE_REMOVE_TEARFLAG` and `POST_REMOVE_TEARFLAG` callbacks.

Passing `true` to Force skips `PRE_REMOVE_TEARFLAG`.

---
### (Void) TearFlagsLib.WipeTearFlags(Entity: WeaponEntity, Boolean: Force)

Shorthand function for removing all custom TearFlags from an entity.
This function triggers the `PRE_REMOVE_TEARFLAG` and `POST_REMOVE_TEARFLAG` callbacks.

Passing `true` to Force skips `PRE_REMOVE_TEARFLAG`.

---
### (Void) TearFlagsLib.CopyTearFlags(Entity: Recipient, Entity: Donor, BitSetInfinity: RecipientWeaponFlag, Table: Params)

Copies TearFlags and TearFlagParams from one entity to another.
This function triggers the `PRE_ADD_TEARFLAG`, `POST_ADD_TEARFLAG`, and `POST_COPY_TEARFLAGS` callbacks.

When TearFlags are copied, their associated TearFlagParams are also copied, unless a `DoNotCopyParams` boolean parameter exists in `Donor`'s params for that given TearFlag. 

The Params table can optionally take 2 parameters:
* `wipe` removes all TearFlags from the Recipient prior to copying TearFlags. This triggers the `PRE_REMOVE_TEARFLAG` and `POST_REMOVE_TEARFLAG` callbacks.
* `skipVanilla` prevents the copying of TearFlagsLib's custom Vanilla TearFlags

e.g:
```lua
TearFlagsLib.CopyTearFlags(tear, knife, TearFlagsLib.WeaponFlag.TEAR, {wipe = true})
```

---
### (Void) TearFlagsLib.SetTearFlagParams(Entity: WeaponEntity, BitSetInfinity: TearFlag, Table: NewParams, Boolean: Override)

Allows TearFlagsLib to store data related to the behaviour of TearFlags. Stored on a per-entity, per-flag basis.
When applying NewParams, existing parameters with different names than those in NewParams will remain on the entity.
Passing `true` to Override will wipe the existing parameter table before applying NewParams.

TearFlagParams are automatically cleared when their associated custom TearFlag is removed from `Entity`.
Setting a `KeepParamsOnFlagRemove` parameter to `true` will prevent this automatic removal.

---
### (Table) TearFlagsLib.GetTearFlagParams(Entity: WeaponEntity, BitSetInfinity: TearFlag)

Retrieves the TearFlagParams of a given TearFlag off of a given Entity.

---
### (Void) TearFlagsLib.ClearTearFlagParams(Entity: WeaponEntity, BitSetInfinity: TearFlag)

Resets the TearFlagParams of a given TearFlag on a given Entity to an empty table.

---
### (Float) TearFlagsLib.GetRealLuck(EntityPlayer: Player, Entity: WeaponEntity)

Returns the Luck stat of a given Player, accounting for any bonuses provided by the Teardrop Charm trinket.
The entity you want to apply TearFlags to should be provided if possible, as any weapon entities fired by Incubus-style familiars should not benefit from Teardrop Charm.

---
### (Float) TearFlagsLib.GetChance(Float: Luck, Float: BaseChance, Float: MaxChance, Float: LuckThreshold, Float: Scaler)

Returns a value from BaseChance to MaxChance as Luck scales from 0 to LuckThreshold.
Scaler will optionally stack the returned chance. Useful for making additional copies of an item stack the chance of applying an effect. This value is not required.

e.g:
Scale the chance of applying a TearFlag from 5% to 25% as Luck scales from 0 to 27, stacking the chance for every copy of an item owned.
```lua
	local rng = player:GetCollectibleRNG(myFunnyItem)
	local chance = TearFlagsLib.GetChance(TearFlagsLib.GetRealLuck(player, tear), 0.05, 0.25, 27, player:GetCollectibleNum(myFunnyItem))
	if rng:RandomFloat() < chance then
		TearFlagsLib.AddTearFlags(tear, TearFlagsLib.Flag.MY_FUNNY_TEARFLAG)
	end
```

---
### (BitSetInfinity) TearFlagsLib.EstimateWeaponFlagFromEntity(Entity: Entity)

Returns the expected WeaponFlag of any given entity, for custom Weapons an identity function must have been registered with `TearFlagsLib.RegisterWeaponIdentityFunction`.

> [!CAUTION]
> This function may return `nil` if a WeaponFlag cannot be identified. Usually due to there being no defined `WeaponIdentityFunction`.

---
### (Boolean) TearFlagsLib.ApplyWeaponTearFlags(EntityNPC: Target, EntityPlayer: Player, Entity: WeaponEntity, BitSetInfinity: WeaponFlag, Boolean: ApplyCustomVanillaFlags, BonusArg)

In order, the callbacks `PRE_APPLY_TEARFLAG_EFFECTS`, `APPLY_TEARFLAG_EFFECT`, and `POST_APPLY_TEARFLAG_EFFECTS` will be invoked.

The callback `APPLY_TEARFLAG_EFFECT` will be invoked once for every custom TearFlag on `WeaponEntity`, passing `Target`, `Player`, `WeaponEntity`, `WeaponFlag`, and `BonusArg`.

`BonusArg` is an entirely optional argument, passed directly to `APPLY_TEARFLAG_EFFECT` to provide extra weapon access for users applying their TearFlag effects.
By default this is only used for Spirit Sword.

Passing `true` to `ApplyCustomVanillaFlags` will automatically process any TearFlagsLib-stored Vanilla TearFlags such as Poison.
This is usually recommended for custom weapons with TearFlagsLib integration.

Returns whether TearFlag effect application was successful (i.e.: `false` if application was blocked by `PRE_APPLY_TEARFLAG_EFFECTS`).

---
### (Boolean) TearFlagsLib.PollTearFlags(Entity: WeaponEntity, EntityPlayer: Player, BitSetInfinity: WeaponFlag)

This function invokes the `POLL_TEARFLAGS` callback, and ensures the `FromPolling` boolean of `PRE/POST_ADD_TEARFLAG` is set correctly.
This is the intended way for custom Weapons to poll for custom TearFlags

Additionally invokes the `PRE_POLL_TEARFLAGS` and `POST_POLL_TEARFLAGS` callbacks.
Returns whether TearFlag polling was successful (i.e.: `false` if polling was blocked by `PRE_POLL_TEARFLAGS`)

---
### (BitSet128: TearFlags, Float: TearDamage) TearFlagsLib.PollVanillaTearFlags(EntityPlayer: Player, Entity: WeaponEntity, ...)

This function provides shorthand access to `EntityPlayer.GetTearHitParams`, and returns 2 values.
Value overrides can be provided as additional arguments if required.

2 values can be accepted from one function as follows:
```lua
	local flags, damage = TearFlagsLib.PollVanillaTearFlags(player, weapon)
```

When making a custom weapon, you should poll for Vanilla effects as frequently as you poll for custom ones, wiping existing effects when necessary.
`TearDamage` should be responded to as a modification of `player.Damage` in order for your weapon to respond to the effects of items like Tough Love.

> [!IMPORTANT]
> `TearFlags` are not stored on your WeaponEntity automatically, and must be added using `TearFlagsLib.AddCustomVanillaTearFlags`.


---
### (EntityTear: NewTear) TearFlagsLib.FireSplitTear(Entity: Spawner, Vector: Velocity, EntityPlayer: Player, Table: Params)

Enables the firing of split-tears from any entity type, while maintaining a number of base attributes from the `Spawner`.
By default, split tears are spawned with a 0.5x damage and scale multiplier relative to the `Spawner`, maintain `Spawner`'s TearFlags and Color, and (if applicable) inherit `Spawner`'s TearVariant.
The `TEAR_TRACTOR_BEAM`, `TEAR_SCATTER_BOMB`, and `TEAR_LUDOVICO` TearFlags are also removed by default.

This function will invoke the `PRE_ADD_TEARFLAG`, `POST_ADD_TEARFLAG`, and `POST_COPY_TEARFLAG` callbacks on NewTear, as well as REPENTOGON's `MC_POST_FIRE_SPLIT_TEAR` callback.

This function accepts a large number of optional parameters:

Variable Type | Name | Description
--- | --- | ---
BitSet128 | `RemoveFlags` | Removes any defined Vanilla TearFlags
BitSetInfinity | `RemoveCustomFlags` | Removes any defined Custom TearFlags
Vector | `PositionOverride` | NewTear position defaults to Spawner.Position, this takes priority
Color | `ColorOverride` | NewTear color defaults to Spawner.Color, this takes priority
Number | `DamageMult` | Defaults to 0.5
Number | `DamageOverride` | Damage is directly set to this value if provided, bypassing DamageMult
Number | `ScaleMult` | Defaults to 0.5
Number | `ScaleOverride` | Scale is directly set to this value if provided, bypassing ScaleMult
Number | `TearVariant` | If spawner is an EntityTear, defaults to spawner.Variant, otherwise defaults to `player:GetTearHitParams(...).TearVariant`
Boolean | `SkipRemoveOnSplitFlags` | Some TearFlags are removed automatically (e.g: Tractor Beam), pass true to allow these flags to stay
String | `SplitTearType` | Passed through to `MC_POST_FIRE_SPLIT_TEAR` in the SplitTearType argument

> [!IMPORTANT]
> It is highly recommended that the `RemoveCustomFlags` and `SplitTearType` params are almost always used.
> * To easily avoid infinite loops with split-tear-spawning TearFlags, pass the TearFlag currently spawning a split-tear to `RemoveCustomFlags`. This prevents the NewTear from inheriting the same split-tear-spawning TearFlag.
> * `SplitTearType` can be any string, however it is recommended to use a value similar to the name of your TearFlag (e.g: `"FF_LAWN_DARTS"`)

---
### (Void) TearFlagsLib.DamageEntity(Entity: Entity, Number: Amount, BitSet128: DamageFlags, Entity: WeaponEntity, Table: Params)

A wrapper for EntityNPC.TakeDamage which automatically handles a few extra things.
Damage dealt to Entity will automatically be applied with any DamageFlags which would usually be applied by certain vanilla TearFlags (e.g: Terra's `ROCK` TearFlag applying damage with the `CRUSH` DamageFlag)

Searches the `TearFlagParams` of every custom `TearFlag` applied to `WeaponEntity` looking for a `DamageParams` table. If `TearFlagParams.DamageParams` is found, certain attributes will apply effects in this function:
Variable Type | Param | Description
--- | --- | ---
BitSet128 | `DamageFlags` | Applies these DamageFlags when dealing damage to Entity
Number | `DamageMult` | Multiplies the amount of damage being dealt
Number | `ExtraDamage` | Adds this amount of extra damage to the damage being dealt, applied before DamageMult
Number | `ExtraDamageFlat` | Adds this amount of extra damage to the damage being dealt, applied after DamageMult

TearFlagParams can be applied to a WeaponEntity using the function `TearFlagsLib.SetTearFlagParams(WeaponEntity, TearFlag, NewParams, Override)`, which additionally takes its own optional parameters when calling:
Variable Type | Param | Description
--- | --- | ---
Entity | `DamageSource` | Overrides the entity passed to Entity:TakeDamage as the damage source. Defaults to `WeaponEntity`
Number | `DamageCooldown` | Overrides the number passed to Entity:TakeDamage as the damage cooldown. Defaults to 0
Boolean | `IgnoreVanillaDamageFlags` | Skips the automatic addition of DamageFlags to `Entity:TakeDamage(...)` based on the Vanilla TearFlags on WeaponEntity


Callbacks
=========

All of TearFlagsLib's callbacks are accessible under the TearFlagsLib.Callback table. e.g: `TearFlagsLib.Callback.POLL_TEARFLAGS`
Many of TearFlagsLib's callbacks support optional arguments upon declaration, an example of how to use optional arguments is as follows:
```lua
	mod:AddCallback(TearFlagsLib.Callback.POLL_TEARFLAGS, function(_, entity, player, weapon) 
		--
	end, TearFlagsLib.WeaponFlag.LASER)
```
Where `TearFlagsLib.WeaponFlag.LASER` is being passed as the optional argument for the callback `TearFlagsLib.CALLBACK.POLL_TEARFLAGS`.

---
### POLL_TEARFLAGS {Entity: WeaponEntity, EntityPlayer: Player, BitSetInfinity: WeaponFlag}

This callback is the standard method of TearFlag application, it is called whenever any weapon wants to determine which custom TearFlags it should have.
Notably this is the only callback where the WeaponFlags `BOBS_ROTTEN_HEAD`, and `SHARP_KEY` are ever used. These unique cases are considered Tear Semi-Weapons, and in all other callbacks simply use the `TEAR` WeaponFlag.

The `LOCUST` WeaponFlag does not call this callback, see `POLL_LOCUST_TEARFLAGS` for how to apply Locust TearFlags.

It is important to remember that applying TearFlags may be denied via the `PRE_ADD_TEARFLAG` callback.
As such, consider using `POST_ADD_TEARFLAG` to apply any important data and parameters for TearFlags you add during this callback.

Takes an optional `WeaponFlag` argument upon declaration.

---
### POLL_CHANCELESS_TEARFLAGS {Entity: WeaponEntity, EntityPlayer: Player, BitSetInfinity: WeaponFlag}

This callback is called only by certain Lasers which do not gain chance-based TearFlags like Common Cold, but which do gain chanceless TearFlags like Scorpio.
This callback should be used alongside `POLL_TEARFLAGS`, but only if the flag you are applying is never chance-based. Even chance-based flags which reach 100% chance are not applied to these Lasers.

Takes an optional `WeaponFlag` argument upon declaration, in case a custom modded weapon may have also decided to only apply chancless TearFlags. Do not assume WeaponEntity will always be an EntityLaser.

---
### POLL_LOCUST_TEARFLAGS {EntityFamiliar: Locust, EntityPlayer: Player}

Locusts are a special case, as they should gain TearFlags only based on the item that was absorbed to generate them.
It is important to remember that owning the Locust of an item is not the same as owning the item, most notably `:HasCollectible()` will return `false`.
In the base game, Locusts typically apply their item's TearFlag using a flat chance which does not scale with Luck.

Takes an optional `CollectibleType` argument upon declaration

---
### APPLY_TEARFLAG_EFFECT {EntityNPC: EffectTarget, EntityPlayer: Player, Entity: WeaponEntity, BitSetInfinity: WeaponFlag, Table: FlagParams, BonusArg}

This callback is the standard method of applying the effects of custom TearFlags to entities.

When applying the TearFlag effects of Spirit Sword, `BonusArg` will contain the hitbox entity applying the effect if applicable. `WeaponEntity` will always contain the actual sword.
In all other vanilla circumstances, `BonusArg` is nil

Takes an optional `TearFlag` argument upon declaration, this argument is so heavily recommended that you should consider it mandatory.

---
### APPLY_EXPLOSION_TEARFLAG_EFFECT {EntityEffect: Explosion, EntityPlayer: Player, Entity: WeaponEntity, BitSetInfinity: WeaponFlag, Table: FlagParams}

This callback is called once for every explosion summoned by a weapon with a given TearFlag. Such as Ipecac tears of Dr. Fetus bombs.

Takes an optional `TearFlag` argument upon declaration, this argument is so heavily recommended that you should consider it mandatory.

---
### POST_FIRE_VASCULITIS_TEAR {EntityTear: VasculitisTear, EntityNPC: Spawner}

When an enemy with a status effect dies, and it spawns tears through the Vasculitis item, those tears should gain a TearEffect which applies that status effect.
Please note, this callback triggers after the Spawner entity has already died, meaning the game may have already wiped its `:GetData()` table. To circumvent this, status effect ownership needs to be stored outside of the afflicted enemy.

---
### PRE_ADD_TEARFLAG (Entity: Recipient, EntityPlayer: Player, Boolean: FromPolling, BitSetInfinity: WeaponFlag, BitSetInfinity: TearFlag)

Called when a TearFlag is about to be applied to an Entity. Return `true` to prevent the TearFlag from being added.
* `FromPolling` defines whether this callback was triggered while a Weapon is polling for TearFlags. This may be `false` for example, if a custom TearFlag is being given to a Familiar's tears.
* `WeaponFlag` will be `nil` except in cases where `FromPolling` is true.

If `WeaponFlag` is nil, but needed, consider using `TearFlagsLib.EstimateWeaponFlagFromEntity` on the Recipient entity. Remember, this function may still return `nil`.

Takes an optional `TearFlag` argument upon declaration

---
### POST_ADD_TEARFLAG (Entity: Recipient, EntityPlayer: Player, Boolean: FromPolling, BitSetInfinity: WeaponFlag, BitSetInfinity: TearFlag)

Called after a TearFlag is applied to an Entity.
* `FromPolling` defines whether this callback was triggered while a Weapon is polling for TearFlags. This may be `false` for example, if a custom TearFlag is being given to a Familiar's tears.
* `WeaponFlag` will be `nil` except in cases where `FromPolling` is true.

This Callback is the intended place to apply important TearFlag parameters, for added compatibility with other mods or items which may want to apply your custom TearFlag.
If `WeaponFlag` is nil, but needed, consider using `TearFlagsLib.EstimateWeaponFlagFromEntity` on the Recipient entity. Remember, this function may still return `nil`.

Takes an optional `TearFlag` argument upon declaration

---
### POST_COPY_TEARFLAGS {Entity: Recipient, Entity: Donor, BitSetInfinity: RecipientWeaponFlag}

This callback is called whenever custom TearFlags are copied from one entity to another, such as when a Tear splits due to the effects of Cricket's Body, or when a swung Club passes its TearFlags onto a thrown Club.
This callback will always be called alongside (and after) `PRE_ADD_TEARFLAG` and `POST_ADD_TEARFLAG`, however, this is the only callback that passes the Donor entity.

Takes an optional `WeaponFlag` argument upon declaration, defining the Recipient entity this callback should be called for.

---
### PRE_REMOVE_TEARFLAG {Entity: Entity, EntityPlayer: Player, BitSetInfinity: TearFlag}

This callback is called before a TearFlag is about to be removed from an entity. Return `true` to prevent the TearFlag from being removed.

Takes an optional `TearFlag` argument upon declaration

---
### POST_REMOVE_TEARFLAG {Entity: Entity, EntityPlayer: Player, BitSetInfinity: TearFlag}

This callback is called after a TearFlag is removed from an entity. This should be used to erase any unecessary supporting data relating to the application of this TearFlag's effect.

Takes an optional `TearFlag` argument upon declaration

---
### POST_CLEAR_LUDOVICO_FLAGS {Entity: LudovicoEntity, EntityPlayer: Player, BitSetInfinity: WeaponFlag}

In order to gain new TearFlags, Ludovico Technique Tears and Knives periodically wipe their own TearFlags and poll for new ones. This callback is called after the removal of old TearFlags, and before new TearFlags are polled for.
This callback is called alongside `PRE_REMOVE_TEARFLAG` and `POST_REMOVE_TEARFLAG`, but exists for any Ludovico-specific synergy effects to be removed properly.

> [!NOTE]
> The `LUDOVICO_TEAR` WeaponFlag is used for this Callback instead of `TEAR`


Example
=======

What follows is a relatively minimal example of a new TearFlag which instantly kills whatever is hit by it.
* The TearFlag has a 5% chance to be applied at 0 luck, scaling to a 25% chance at 27 luck. It can only be applied if you have a custom item, and scales in chance based on how many copies you own.
* If the item was absorbed by Abyss, its locust has a flat 20% TearFlag application rate. A flat application rate is standard behaviour for Locusts in the base game.

```lua
	-- Get Item ID
	local item = Isaac.GetItemIdByName("My Item")

	-- Register New Tearflag
	TearFlagsLib.RegisterFlag("MYMOD_MY_FLAG")

	-- Apply TearFlag
	myMod:AddCallback(TearFlagsLib.Callback.POLL_TEARFLAGS, function(_, entity, player, weapon)
		if player:HasCollectible(item) then
			local rng = player:GetCollectibleRNG(item)
			local chance = TearFlagsLib.GetChance(TearFlagsLib.GetRealLuck(player, entity), 0.05, 0.25, 27, player:GetCollectibleNum(item))
			if rng:RandomFloat() < chance then
				TearFlagsLib.AddTearFlags(entity, TearFlagsLib.Flag.MYMOD_MY_FLAG)
			end
		end
	end)

	-- Apply TearFlag To Locust
	myMod:AddCallback(TearFlagsLib.Callback.POLL_LOCUST_TEARFLAGS, function(_, locust, player)
		local rng = player:GetCollectibleRNG(item)
		if rng:RandomFloat() < 0.2 then
			TearFlagsLib.AddTearFlags(locust, TearFlagsLib.Flag.MYMOD_MY_FLAG)
		end
	end, item)

	-- Apply TearFlag Effect
	myMod:AddCallback(TearFlagsLib.Callback.APPLY_TEARFLAG_EFFECT, function(_, npc, player, source, weapon, params)
		npc:Die()
	end, TearFlagsLib.Flag.MYMOD_MY_FLAG)
```
