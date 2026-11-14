
AddCSLuaFile()

ENT.Type = "nextbot"
ENT.Base = "base_nextbot"

ENT.PrintName = "Bryce NPC"
ENT.Category = "Custom NPCs"
ENT.Spawnable = true
ENT.AdminOnly = false

ENT.Model = "models/player/collection.mdl"

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------

-- HEALTH
ENT.MaxHealth = 100

-- MOVEMENT
ENT.WalkSpeed = 120
ENT.RunSpeed = 250

ENT.WalkAcceleration = 400
ENT.RunAcceleration = 700

ENT.GrowthMoveSpeedMultiplier = 0.8
ENT.TransformedSpeedMultiplier = 1.2

-- TRAVERSAL
ENT.JumpHeight = 180
ENT.StepHeight = 35
ENT.JumpGapsAllowed = true
ENT.ClimbAllowed = true
ENT.AvoidAllowed = true

ENT.StuckJump = true

-- TARGET DETECTION
ENT.SearchRadius = 1500
ENT.LoseTargetDistance = 2500

-- PATHFINDING
ENT.PathLookAhead = 300
ENT.PathTolerance = 20
ENT.RepathInterval = 0.2

-- WANDERING
ENT.WanderRadius = 400
ENT.WanderPause = 1.5
ENT.WanderMaxTime = 5

-- COMBAT
ENT.AttackDamage = 25
ENT.TransformedDamageMultiplier = 1.5

ENT.AttackRange = 70
ENT.AttackDelay = 1.0
ENT.AttackWindup = 0.25

-- ANIMATIONS
ENT.IdleActivity = ACT_IDLE
ENT.WalkActivity = ACT_WALK
ENT.RunActivity = ACT_RUN
ENT.AttackActivity = ACT_MELEE_ATTACK1
ENT.JumpActivity = ACT_JUMP

-- TRANSFORMATION
ENT.GrowthHealthThreshold = 0.5

ENT.GrowthScale = 3.0
ENT.GrowthDuration = 10

ENT.GrowthEffectInterval = 0.35
ENT.GrowthEffectRadius = 300

ENT.GrowthJumpIntervalMin = 1.2
ENT.GrowthJumpIntervalMax = 2.2


----------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------

function ENT:Initialize()

    ------------------------------------------------------------
    -- MODEL
    ------------------------------------------------------------

    if not util.IsValidModel(self.Model) then

        ErrorNoHalt(
            "[Bryce NPC] Invalid model: "
            .. tostring(self.Model)
            .. "\n"
        )

        self:Remove()
        return

    end

    self:SetModel(self.Model)

    ------------------------------------------------------------
    -- IDENTITY
    ------------------------------------------------------------

    self.BryceNPC = true

    ------------------------------------------------------------
    -- HEALTH
    ------------------------------------------------------------

    self:SetMaxHealth(self.MaxHealth)
    self:SetHealth(self.MaxHealth)

    ------------------------------------------------------------
    -- AI STATE
    ------------------------------------------------------------

    self.Enemy = nil
    self.NextAttack = 0

    self.ForceGrowth = false
    self.IsGrowing = false
    self.HasTransformed = false

    self.GrowthFinishTime = nil
    self.NextGrowthEffect = 0
    self.NextGrowthJump = 0

    ------------------------------------------------------------
    -- LOCOMOTION
    ------------------------------------------------------------

    self.loco:SetDesiredSpeed(self.WalkSpeed)
    self.loco:SetAcceleration(self.WalkAcceleration)

    self.loco:SetJumpHeight(self.JumpHeight)
    self.loco:SetStepHeight(self.StepHeight)

    self.loco:SetJumpGapsAllowed(self.JumpGapsAllowed)
    self.loco:SetClimbAllowed(self.ClimbAllowed)
    self.loco:SetAvoidAllowed(self.AvoidAllowed)

    self:StartActivity(self.IdleActivity)

    print("[Bryce NPC] Initialized successfully.")

end


----------------------------------------------------------------
-- MOVEMENT SPEED
----------------------------------------------------------------

function ENT:GetMovementSpeed(baseSpeed)

    if self.HasTransformed then

        return baseSpeed * self.TransformedSpeedMultiplier

    end

    if self.IsGrowing then

        return baseSpeed * self.GrowthMoveSpeedMultiplier

    end

    return baseSpeed

end


----------------------------------------------------------------
-- TRANSFORMATION VALIDATION
----------------------------------------------------------------

function ENT:ShouldTransform()

    if self.HasTransformed then
        return false
    end

    if self.IsGrowing then
        return false
    end

    if self.ForceGrowth then
        return true
    end

    return self:Health() <=
        self.MaxHealth * self.GrowthHealthThreshold

end


----------------------------------------------------------------
-- TARGET MANAGEMENT
----------------------------------------------------------------

function ENT:SetEnemy(enemy)

    if IsValid(enemy) then
        self.Enemy = enemy
    else
        self.Enemy = nil
    end

end


function ENT:GetEnemy()

    local enemy = self.Enemy

    -- Keep the current target if possible.
    if IsValid(enemy)
    and enemy:IsPlayer()
    and enemy:Alive() then

        local distance = self:GetRangeSquaredTo(
            enemy:GetPos()
        )

        if distance <= self.LoseTargetDistance ^ 2 then
            return enemy
        end

    end

    return self:FindEnemy()

end


function ENT:FindEnemy()

    local nearestEnemy = nil
    local shortestDistance = self.SearchRadius ^ 2

    for _, ply in ipairs(player.GetAll()) do

        if IsValid(ply) and ply:Alive() then

            local distance = self:GetRangeSquaredTo(
                ply:GetPos()
            )

            if distance < shortestDistance then

                shortestDistance = distance
                nearestEnemy = ply

            end

        end

    end

    self:SetEnemy(nearestEnemy)

    return nearestEnemy

end


----------------------------------------------------------------
-- TARGET VALIDATION
----------------------------------------------------------------

function ENT:CanAttack(target)

    if not IsValid(target) then
        return false
    end

    if not target:IsPlayer() or not target:Alive() then
        return false
    end

    return self:GetRangeSquaredTo(target:GetPos())
        <= self.AttackRange ^ 2

end


----------------------------------------------------------------
-- DYNAMIC CHASE SYSTEM
----------------------------------------------------------------

function ENT:ChaseEnemy()

    local enemy = self:GetEnemy()

    if not IsValid(enemy) then
        return "lost"
    end

    local path = Path("Follow")

    path:SetMinLookAheadDistance(self.PathLookAhead)
    path:SetGoalTolerance(self.PathTolerance)

    path:Compute(self, enemy:GetPos())

    if not path:IsValid() then
        return "failed"
    end

    while IsValid(self) and path:IsValid() do

        --------------------------------------------------------
        -- TRANSFORMATION INTERRUPT
        --------------------------------------------------------

        if self:ShouldTransform() then
            return "transform"
        end

        --------------------------------------------------------
        -- UPDATE TRANSFORMATION
        --------------------------------------------------------

        self:UpdateGrowth()

        --------------------------------------------------------
        -- MOVEMENT
        --------------------------------------------------------

        self.loco:SetDesiredSpeed(
            self:GetMovementSpeed(self.RunSpeed)
        )

        self.loco:SetAcceleration(self.RunAcceleration)

        --------------------------------------------------------
        -- TARGET
        --------------------------------------------------------

        enemy = self:GetEnemy()

        if not IsValid(enemy) then
            return "lost"
        end

        --------------------------------------------------------
        -- ATTACK RANGE
        --------------------------------------------------------

        if self:CanAttack(enemy) then
            return "ok"
        end

        --------------------------------------------------------
        -- RECOMPUTE PATH
        --------------------------------------------------------

        if path:GetAge() >= self.RepathInterval then

            path:Compute(self, enemy:GetPos())

            if not path:IsValid() then
                return "failed"
            end

        end

        --------------------------------------------------------
        -- FOLLOW PATH
        --------------------------------------------------------

        path:Update(self)

        --------------------------------------------------------
        -- STUCK DETECTION
        --------------------------------------------------------

        if self.loco:IsStuck() then

            self:HandleStuck()

            return "stuck"

        end

        coroutine.yield()

    end

    return "complete"

end


----------------------------------------------------------------
-- MELEE ATTACK
----------------------------------------------------------------

function ENT:AttackTarget(target)

    if not self:CanAttack(target) then
        return false
    end

    if CurTime() < self.NextAttack then
        return false
    end

    ------------------------------------------------------------
    -- DAMAGE
    ------------------------------------------------------------

    local damage = self.AttackDamage

    if self.HasTransformed then

        damage = damage * self.TransformedDamageMultiplier

    end

    self.NextAttack = CurTime() + self.AttackDelay

    ------------------------------------------------------------
    -- FACE TARGET
    ------------------------------------------------------------

    self.loco:FaceTowards(
        target:WorldSpaceCenter()
    )

    ------------------------------------------------------------
    -- ANIMATION
    ------------------------------------------------------------

    self:StartActivity(self.AttackActivity)

    ------------------------------------------------------------
    -- ATTACK WINDUP
    ------------------------------------------------------------

    coroutine.wait(self.AttackWindup)

    ------------------------------------------------------------
    -- REVALIDATE
    ------------------------------------------------------------

    if not IsValid(self) then
        return false
    end

    if not self:CanAttack(target) then
        return false
    end

    ------------------------------------------------------------
    -- APPLY DAMAGE
    ------------------------------------------------------------

    local damageInfo = DamageInfo()

    damageInfo:SetAttacker(self)
    damageInfo:SetInflictor(self)
    damageInfo:SetDamage(damage)
    damageInfo:SetDamageType(DMG_SLASH)

    target:TakeDamageInfo(damageInfo)

    return true

end


----------------------------------------------------------------
-- WANDERING
----------------------------------------------------------------

function ENT:Wander()

    if self:ShouldTransform() then
        return "transform"
    end

    self:StartActivity(self.WalkActivity)

    self.loco:SetDesiredSpeed(
        self:GetMovementSpeed(self.WalkSpeed)
    )

    self.loco:SetAcceleration(self.WalkAcceleration)

    ------------------------------------------------------------
    -- RANDOM DESTINATION
    ------------------------------------------------------------

    local direction = Vector(
        math.Rand(-1, 1),
        math.Rand(-1, 1),
        0
    )

    if direction:LengthSqr() < 0.01 then
        direction = Vector(1, 0, 0)
    end

    direction:Normalize()

    local destination = self:GetPos()
        + direction * math.Rand(
            200,
            self.WanderRadius
        )

    ------------------------------------------------------------
    -- PATH
    ------------------------------------------------------------

    local path = Path("Follow")

    path:SetMinLookAheadDistance(100)
    path:SetGoalTolerance(30)

    path:Compute(self, destination)

    if not path:IsValid() then

        self:StartActivity(self.IdleActivity)

        coroutine.wait(0.5)

        return "failed"

    end

    ------------------------------------------------------------
    -- FOLLOW WANDERING PATH
    ------------------------------------------------------------

    local startTime = CurTime()

    while IsValid(self) and path:IsValid() do

        --------------------------------------------------------
        -- TRANSFORMATION INTERRUPT
        --------------------------------------------------------

        if self:ShouldTransform() then
            return "transform"
        end

        --------------------------------------------------------
        -- UPDATE GROWTH
        --------------------------------------------------------

        self:UpdateGrowth()

        --------------------------------------------------------
        -- MOVEMENT
        --------------------------------------------------------

        self.loco:SetDesiredSpeed(
            self:GetMovementSpeed(self.WalkSpeed)
        )

        --------------------------------------------------------
        -- PLAYER DETECTION
        --------------------------------------------------------

        if IsValid(self:GetEnemy()) then
            return "enemy"
        end

        --------------------------------------------------------
        -- WANDER TIMEOUT
        --------------------------------------------------------

        if CurTime() - startTime >= self.WanderMaxTime then
            break
        end

        --------------------------------------------------------
        -- FOLLOW PATH
        --------------------------------------------------------

        path:Update(self)

        --------------------------------------------------------
        -- STUCK DETECTION
        --------------------------------------------------------

        if self.loco:IsStuck() then

            self:HandleStuck()

            return "stuck"

        end

        coroutine.yield()

    end

    ------------------------------------------------------------
    -- WANDER COMPLETE
    ------------------------------------------------------------

    if not IsValid(self) then
        return "failed"
    end

    self:StartActivity(self.IdleActivity)

    ------------------------------------------------------------
    -- INTERRUPTIBLE PAUSE
    ------------------------------------------------------------

    local pauseEnd = CurTime() + self.WanderPause

    while IsValid(self) and CurTime() < pauseEnd do

        if self:ShouldTransform() then
            return "transform"
        end

        self:UpdateGrowth()

        if IsValid(self:GetEnemy()) then
            return "enemy"
        end

        coroutine.wait(0.1)

    end

    return "complete"

end


----------------------------------------------------------------
-- STUCK RECOVERY
----------------------------------------------------------------

function ENT:HandleStuck()

    print("[Bryce NPC] Stuck! Attempting recovery.")

    -- Clear the engine's stuck status.
    self.loco:ClearStuck()

    -- Attempt a jump if grounded.
    if self.StuckJump and self.loco:IsOnGround() then

        self.loco:Jump(self.JumpActivity)

    end

end


----------------------------------------------------------------
-- TRANSFORMATION START
----------------------------------------------------------------

function ENT:GrowIntoColossus()

    if not IsValid(self) then
        return
    end

    if self.IsGrowing or self.HasTransformed then
        return
    end

    ------------------------------------------------------------
    -- INITIALIZE STATE
    ------------------------------------------------------------

    self.ForceGrowth = false
    self.IsGrowing = true

    self.GrowthFinishTime =
        CurTime() + self.GrowthDuration

    self.NextGrowthEffect = 0

    self.NextGrowthJump =
        CurTime() + 0.5

    print("[Bryce NPC] COLOSSUS TRANSFORMATION STARTED")

    ------------------------------------------------------------
    -- SOUND
    ------------------------------------------------------------

    self:EmitSound(
        "ambient/energy/zap1.wav",
        100,
        50
    )

    ------------------------------------------------------------
    -- MODEL GROWTH
    ------------------------------------------------------------

    self:SetModelScale(
        self.GrowthScale,
        self.GrowthDuration
    )

    -- IMPORTANT:
    -- Do not set movement speed to zero.
    -- Do not wait for the whole transformation here.
    -- The AI continues running independently.

end


----------------------------------------------------------------
-- TRANSFORMATION UPDATE
----------------------------------------------------------------

function ENT:UpdateGrowth()

    if not self.IsGrowing then
        return
    end

    if not IsValid(self) then
        return
    end

    local now = CurTime()

    ------------------------------------------------------------
    -- PROGRESS
    ------------------------------------------------------------

    local remaining = self.GrowthFinishTime - now

    local progress = math.Clamp(
        1 - remaining / self.GrowthDuration,
        0,
        1
    )

    ------------------------------------------------------------
    -- CORRUPTION PARTICLES
    ------------------------------------------------------------

    if now >= self.NextGrowthEffect then

        self.NextGrowthEffect =
            now + self.GrowthEffectInterval

        local radius = Lerp(
            progress,
            100,
            self.GrowthEffectRadius
        )

        local effect = EffectData()

        effect:SetOrigin(
            self:GetPos() + Vector(
                math.Rand(-radius, radius),
                math.Rand(-radius, radius),
                math.Rand(0, radius * 1.5)
            )
        )

        effect:SetScale(
            Lerp(progress, 1, 4)
        )

        util.Effect(
            "cball_explode",
            effect,
            true,
            true
        )

    end

    ------------------------------------------------------------
    -- RANDOM JUMPING
    ------------------------------------------------------------

    if now >= self.NextGrowthJump
    and self.loco:IsOnGround() then

        self.loco:Jump(self.JumpActivity)

        self.NextGrowthJump =
            now + math.Rand(
                self.GrowthJumpIntervalMin,
                self.GrowthJumpIntervalMax
            )

    end

    ------------------------------------------------------------
    -- TRANSFORMATION COMPLETE
    ------------------------------------------------------------

    if now >= self.GrowthFinishTime then

        self.IsGrowing = false
        self.HasTransformed = true

        self.GrowthFinishTime = nil

        self:EmitSound(
            "ambient/energy/weld2.wav",
            100,
            60
        )

        print(
            "[Bryce NPC] COLOSSUS TRANSFORMATION COMPLETE"
        )

    end

end


----------------------------------------------------------------
-- DEATH HANDLING
----------------------------------------------------------------

function ENT:OnKilled(damageInfo)

    print("[Bryce NPC] Eliminated.")

    hook.Run(
        "OnNPCKilled",
        self,
        damageInfo:GetAttacker(),
        damageInfo:GetInflictor()
    )

    self:BecomeRagdoll(damageInfo)

end


----------------------------------------------------------------
-- MAIN AI BEHAVIOR
----------------------------------------------------------------

function ENT:RunBehaviour()

    while IsValid(self) do

        --------------------------------------------------------
        -- AUTOMATIC TRANSFORMATION
        --------------------------------------------------------

        if self:ShouldTransform() then

            self:GrowIntoColossus()

        end

        --------------------------------------------------------
        -- UPDATE TRANSFORMATION
        --------------------------------------------------------

        self:UpdateGrowth()

        --------------------------------------------------------
        -- ACQUIRE TARGET
        --------------------------------------------------------

        local enemy = self:GetEnemy()

        if IsValid(enemy) then

            ----------------------------------------------------
            -- CHASE
            ----------------------------------------------------

            self:StartActivity(self.RunActivity)

            self.loco:SetDesiredSpeed(
                self:GetMovementSpeed(self.RunSpeed)
            )

            self.loco:SetAcceleration(self.RunAcceleration)

            ----------------------------------------------------
            -- ATTACK OR CHASE
            ----------------------------------------------------

            if self:CanAttack(enemy) then

                if CurTime() >= self.NextAttack then

                    self:AttackTarget(enemy)

                else

                    coroutine.wait(0.1)

                end

            else

                local result = self:ChaseEnemy()

                if result == "failed"
                or result == "stuck" then

                    coroutine.wait(0.25)

                end

            end

        else

            ----------------------------------------------------
            -- NO TARGET: WANDER
            ----------------------------------------------------

            self:Wander()

        end

        coroutine.yield()

    end

end


----------------------------------------------------------------
-- MANUAL TRANSFORMATION COMMAND
----------------------------------------------------------------

if SERVER then

    concommand.Add("bryce_grow", function(ply)

        --------------------------------------------------------
        -- PERMISSIONS
        --------------------------------------------------------

        if IsValid(ply) and not ply:IsAdmin() then

            ply:PrintMessage(
                HUD_PRINTCONSOLE,
                "[Bryce] Admin permission required.\n"
            )

            return

        end

        --------------------------------------------------------
        -- FIND NPCS
        --------------------------------------------------------

        local npcs = ents.FindByClass("npc_bryce")

        local found = 0
        local queued = 0
        local alreadyGrowing = 0

        for _, npc in ipairs(npcs) do

            if not IsValid(npc) then
                continue
            end

            found = found + 1

            print(
                "[Bryce] Found entity: "
                .. npc:GetClass()
            )

            ----------------------------------------------------
            -- SKIP TRANSFORMED NPCS
            ----------------------------------------------------

            if npc.HasTransformed or npc.IsGrowing then

                alreadyGrowing = alreadyGrowing + 1

                continue

            end

            ----------------------------------------------------
            -- QUEUE TRANSFORMATION
            ----------------------------------------------------

            npc.ForceGrowth = true

            queued = queued + 1

        end

        --------------------------------------------------------
        -- RESULTS
        --------------------------------------------------------

        print("--------------------------------")
        print("[Bryce] NPCs found: " .. found)
        print("[Bryce] Transformations queued: " .. queued)

        print(
            "[Bryce] Already transformed/growing: "
            .. alreadyGrowing
        )

        print("--------------------------------")

        if found == 0 then

            print(
                "[Bryce] No NPCs found. Expected class: npc_bryce"
            )

        end

        if IsValid(ply) then

            ply:PrintMessage(
                HUD_PRINTCONSOLE,
                "[Bryce] Found: " .. found
                .. " | Queued: " .. queued .. "\n"
            )

        end

    end)

end


----------------------------------------------------------------
-- END OF BRYCE NPC
----------------------------------------------------------------
