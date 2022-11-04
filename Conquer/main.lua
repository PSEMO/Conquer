-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------


--Physics.
local physics = require( "physics" )
physics.start()
physics.setGravity( 0, 0 )

--Background.
local background = display.newImageRect("pixel2.png", 1.5 * display.contentWidth, 1.5 * display.contentHeight)
background.x = display.contentCenterX
background.y = display.contentCenterY

--Player.
local player = display.newRect(0, 0,  4, 4)
local playerRadius = 4
local PlayerEaten = 2
local playerRotation = 0
player:setFillColor( 1, 1, 0 )
player.x = display.contentCenterX
player.y = display.contentCenterY

--Players gun.
local gun = display.newRect(0, 0, playerRadius / 3, playerRadius)
gun:setFillColor(0, 0, 0, 0)
gun.anchorY = playerRadius

--Auto attack timer UI display.
local autoAttackUI = display.newRect(0, 0, playerRadius * 2, playerRadius / 4)
local autoAttackStopWatch = 0
local autoAttackCoolDown = 1 * 1000
autoAttackUI:setFillColor(0, 0, 0, 0)

--Only player and bullets are dynamic, to be able to detect those collisions
physics.addBody( player, "dynamic", {radius=2, isSensor = true })

--Current point player collected (is corralated to player object radius)
local pointCount = 0
local maxPointCount = 0
local pointText = display.newText( pointCount, display.contentCenterX, 20, native.systemFont, 40 )
pointText:setFillColor( 0.2, 0.4, 0.8 )

--Rush timer UI display.
local rushUI = display.newRect(0, 0, playerRadius * 2, playerRadius / 4)

--Default speed and current speed
local moveSpeed = 1
local defaultSpeed = 1

--Rush duration
local SpeedDuration = 1
local canRush = true

--holds all keys. True if they are pressed down or being held down. false if not
local keyDownList = {}

--holds all enemies in the scene and a 'false' if they are dead 
local EnemyList = {}

--We hold these to respawn them if they are too low
local enemyNumber = 0
local pointObjNumber = 0

--Holds the next enemy id (also holds the last id of enemy_List array)
local enemyID = 1

--if we just shoot, timer goes off at playerUpdate
local shot = false

--vision limiter, using a png for it
local vision = display.newImageRect("vision.png", 2732, 2732)
vision.x = display.contentCenterX
vision.y = display.contentCenterY

--Delta.time and last frames event.time to calculate delta.time
local deltaTime  = 0
local lastTime = 0

--Upgrade visuals
local AttackSpeedUI = display.newRoundedRect(0, 0, 160, 12, 2)
local AttackPenetrationUI = display.newRoundedRect(0, 0, 160, 12, 2)
local RushSpeedUI = display.newRoundedRect(0, 0, 160, 12, 2)
--Upgrade visuals
local AttackSpeedText = display.newText("[1] - higher attack speed", display.contentCenterX, 25, native.systemFont, 12)
local AttackPenetrationText = display.newText("[2] - higher bullet penetration", display.contentCenterX, 25, native.systemFont, 12)
local RushSpeedText = display.newText("[3] - higher rush speed", display.contentCenterX, 25, native.systemFont, 12)

--Penetration number that player can deal
local penetrationUpgrade = 1

--Positions LevelUp UI elements in playerUpdate(), if its true
local LevelUpUI = false

local speedMultiplier = 2.4

--Does nothing for now
local isGameEnded = false

--Called when a key is pressed
function keyHandler(event)
    --Saves a key and if it is pressed down or not (true if button is down, false if button is not down)
    if event.phase == "up" then
        keyDownList[event.keyName] = false
        print(event.keyName)
    elseif event.phase == "down" then
        keyDownList[event.keyName] = true
        --print( event.keyName )
    end
end

--Creates upgrade visuals
function CreateLevelSelectionUI()

    --We delete old visuals (we can just not create them if they already exist too, I just didn't have enough debug time)
    DeleteLevelSelectionUI()
    LevelUpUI = true
    
    local scaleForUI = playerRadius / 4
    if(playerRadius / 4 > 5) then
        scaleForUI = 5
    end

    --AttackSpeed upgrade visuals settings
    AttackSpeedText = display.newText( "[1] - higher attack speed", display.contentCenterX, 20, native.systemFont, 12 )
    AttackSpeedText:setFillColor(1, 1, 1)
    AttackSpeedUI = display.newRoundedRect(0, 0, 170, 15, 2)
    AttackSpeedUI:setFillColor(0.3, 0.3, 0.3, 0.7)
    AttackSpeedUI.strokeWidth = 3
    AttackSpeedUI:setStrokeColor(0, 0, 0, 0.7)
    
    --AttackPenetration upgrade visuals settings
    AttackPenetrationText = display.newText( "[2] - higher bullet penetration", display.contentCenterX, 20, native.systemFont, 12 )
    AttackPenetrationText:setFillColor(1, 1, 1)
    AttackPenetrationUI = display.newRoundedRect(0, 0, 170, 15, 2)
    AttackPenetrationUI:setFillColor(0.3, 0.3, 0.3, 0.7)
    AttackPenetrationUI.strokeWidth = 3
    AttackPenetrationUI:setStrokeColor(0, 0, 0, 0.7)
    
    --RushSpeed upgrade visuals settings
    RushSpeedText = display.newText( "[3] - higher rush speed", display.contentCenterX, 20, native.systemFont, 12 )
    RushSpeedText:setFillColor(1, 1, 1)
    RushSpeedUI = display.newRoundedRect(0, 0, 170, 15, 2)
    RushSpeedUI:setFillColor(0.3, 0.3, 0.3, 0.7)
    RushSpeedUI.strokeWidth = 3
    RushSpeedUI:setStrokeColor(0, 0, 0, 0.7)
end

function DeleteLevelSelectionUI()
    
    LevelUpUI = false

    DeleteGivenObj(AttackSpeedUI)
    DeleteGivenObj(AttackSpeedText)

    DeleteGivenObj(AttackPenetrationUI)
    DeleteGivenObj(AttackPenetrationText)

    DeleteGivenObj(RushSpeedUI)
    DeleteGivenObj(RushSpeedText)
end

--Runs every frame
function playerUpdate(event)

    --deleting other frames time from the new one to get delta time (current frames time)
    deltaTime = event.time - lastTime
    lastTime = event.time

--Button presses

    --makes current displacement speed "speedMultiplier" times the default if given button is pressed and
    --if there is duration left
    --if duration goes below 500 * 0.1 player needs to wait until its back 100%
    if keyDownList["leftShift"] and canRush then
        moveSpeed = defaultSpeed * speedMultiplier
        SpeedDuration = SpeedDuration - deltaTime
    else
        moveSpeed = defaultSpeed

        if(SpeedDuration < 500)
        then
            SpeedDuration = SpeedDuration + deltaTime
        else
            SpeedDuration = 500
            canRush = true
            rushUI:setFillColor(1, 1, 1, 1)
        end
    end
    if(SpeedDuration < 500 * 0.1) then
        canRush = false
        rushUI:setFillColor(0, 0, 0, 1)
    end
    rushUI.xScale = SpeedDuration / 500

    --shoots if hasAGun() and we did not just shoot
    if keyDownList["space"] then
        if hasAGun() then
            if not shot then
                Shoot()
                shot = true
                autoAttackUI:setFillColor(0, 0, 0, 1)
            end
        end
    end

    --basic movements based on a key list
    if keyDownList["left"] or keyDownList["a"] then
        player.x = player.x - moveSpeed
    end
    if keyDownList["right"] or keyDownList["d"] then
        player.x = player.x + moveSpeed
    end
    if keyDownList["up"] or keyDownList["w"] then
        player.y = player.y - moveSpeed
    end 
    if keyDownList["down"] or keyDownList["s"] then
        player.y = player.y + moveSpeed 
    end

    --if(isGameEnded) then
    --    keyDownList["r"]
    --end

    --if keyDownList["l"] then
    --    pointChanged(10)
    --end
--Others

    --sets a timer and changes autoAttackUI.xScale according to it
    if(shot)
    then
        autoAttackStopWatch = autoAttackStopWatch + deltaTime
        autoAttackUI.xScale = autoAttackStopWatch / autoAttackCoolDown

        if(autoAttackStopWatch > autoAttackCoolDown)
        then
            autoAttackStopWatch = 0
            shot = false
            autoAttackUI.xScale = 1
            autoAttackUI:setFillColor(1, 1, 1, 1)
        end
    end

    --rush and shoot UI distance in between
    local distance = playerRadius * 0.5
    if(playerRadius / 4 > 5) then
        distance = 22 * 0.5
    end

    --if player has leveled up checks level up buttons
    if(LevelUpUI)
    then
        local isChosenUpgrade = false

        if keyDownList["1"] then
            autoAttackCoolDown = autoAttackCoolDown * 0.9
            isChosenUpgrade = true
        end
        if keyDownList["2"] then
            penetrationUpgrade = penetrationUpgrade + 1
            isChosenUpgrade = true
        end
        if keyDownList["3"] then
            speedMultiplier = speedMultiplier + 0.5
            isChosenUpgrade = true
        end 
        --if keyDownList["4"] then
        --    --
        --    isChosenUpgrade = true
        --end

        --to make them stay after selection
        if(isChosenUpgrade) then
            DeleteLevelSelectionUI()
        end
    end

--location things

    --locates UIs, gun and vision according to player pos

    EnemyTowardsPlayer()

    vision.x = player.x
    vision.y = player.y

    gun.x = player.x
    gun.y = player.y

    autoAttackUI.x = player.x
    autoAttackUI.y = player.y - (playerRadius * 1.1) - distance

    rushUI.x = player.x
    rushUI.y = player.y - (playerRadius * 1.1)

    if(LevelUpUI)
    then
        AttackSpeedUI.x = player.x - (AttackSpeedUI.contentWidth / 2) - 5
        AttackSpeedUI.y = player.y + AttackSpeedUI.contentHeight + 5
    
        AttackPenetrationUI.x = AttackSpeedUI.x
        AttackPenetrationUI.y = AttackSpeedUI.y + AttackPenetrationUI.contentHeight + 5
    
        RushSpeedUI.x = AttackPenetrationUI.x
        RushSpeedUI.y = AttackPenetrationUI.y + RushSpeedUI.contentHeight + 5
    
        AttackSpeedText.x = AttackSpeedUI.x
        AttackSpeedText.y = AttackSpeedUI.y
    
        AttackPenetrationText.x = AttackPenetrationUI.x
        AttackPenetrationText.y = AttackPenetrationUI.y
    
        RushSpeedText.x = RushSpeedUI.x
        RushSpeedText.y = RushSpeedUI.y
    end
end

--Bullet reaches to a destination within bullettime
function Shoot()

    local bulletTime = 10000
	local newLaser = display.newCircle(playerRadius * 1.2 * math.cos(math.rad(playerRotation + 270)) + vision.x,
    playerRadius * 1.2 * math.sin(math.rad(playerRotation + 270)) + vision.y,  playerRadius / 4.5 )
    
	physics.addBody( newLaser, "dynamic", { isSensor=true } )
    
    newLaser:setFillColor(0, 0, 0, 1)

	newLaser:toFront()
    ReOrderToFront()

    --destination is decided by rotations direction * 2000
	transition.to( newLaser, {
    x = player.x + math.cos(math.rad(playerRotation + 270)) * 2000,
    y = player.y + math.sin(math.rad(playerRotation + 270)) * 2000,
    time=bulletTime
	} )

    newLaser.type = "bullet"
    newLaser.r = playerRadius / 5

    newLaser.penetrated = 0

    timer.performWithDelay(bulletTime, function() DeleteGivenObj(newLaser) end)
end

function DeleteGivenObj(ObjToDelete)

    display.remove(ObjToDelete)
end

--Create object at given place.
--Only used for creating two objects; one green infront of player, one red at the back of the player.
function createObjectThere(type, aX, aY)
    local r = 3
    if(type == "point") then
        r = 2
    end

    local CurrentObject = display.newCircle(aX, aY, r)

    --if a point is to be created
    if(type == "point")
    then
        CurrentObject.type = "point"
        CurrentObject:setFillColor(0, 1, 0)
        pointObjNumber = pointObjNumber + 1
    end

    if(type == "enemy")
    then
        CurrentObject.type = "enemy"
        CurrentObject:setFillColor( 1, 0, 0)
        enemyNumber = enemyNumber + 1


        CurrentObject.enemyID = enemyID
        EnemyList[enemyID] = CurrentObject

        enemyID = enemyID + 1
    end

    CurrentObject.r = r;
    
    timer.performWithDelay(1, function() addRB(CurrentObject, r) end)
end

--Creates a random object in random position and size within screen limits
function createObject(type)
    
    local x = math.random(0, display.contentWidth)
    local y = math.random(0, display.contentHeight)
    local r = math.random(1 , 5 + math.log(playerRadius))--add a code to not spawn these near player.x player.y----------------------------------------
    local CurrentObject = display.newCircle(x, y, r)
    
    --if a point is to be created
    if(type == "point")
    then
        CurrentObject.type = "point"
        CurrentObject:setFillColor(0, 1, 0)
        pointObjNumber = pointObjNumber + 1
    end

    --if an enemy is to be created. Adds enemy to enemy_List array. EnemyID still holds the 'last added ID + 1'
    --CurrentObject.enemyID exists to find collided object within array if we ever collide with it later.
    if(type == "enemy")
    then
        CurrentObject.type = "enemy"
        CurrentObject:setFillColor( 1, 0, 0)
        enemyNumber = enemyNumber + 1


        CurrentObject.enemyID = enemyID
        EnemyList[enemyID] = CurrentObject

        enemyID = enemyID + 1
    end

    CurrentObject.r = r;
    
    --Delay is needed due to a box2d & Solar2d limitation. Runs the very next frame.
    timer.performWithDelay(1, function() addRB(CurrentObject, r) end)
end

--We add static collider to detect collision. Only used to addBody with delay
function addRB(ObjToChange, radius)

    physics.addBody( ObjToChange, "static", {radius=radius, isSensor = true })
end

--To resize player, we delete the old one and create it from nothing.
function ReCreatePlayer()

    DeleteGivenObj(player)
    DeleteGivenObj(gun)
    DeleteGivenObj(autoAttackUI)
    DeleteGivenObj(rushUI)

    createPlayer()
end

--Creates a brand new player, only used to resize player.
function createPlayer()

    gun = display.newRect(player.x, player.y, playerRadius / 3, playerRadius * 1.2)

    local scaleForUI = playerRadius / 4
    if(playerRadius / 4 > 5) then
        scaleForUI = 5
    end

    autoAttackUI = display.newRect(0, 0, playerRadius * 2, scaleForUI)
    rushUI = display.newRect(0, 0, playerRadius * 2, scaleForUI)

    if(hasAGun())
    then
        gun:setFillColor(0, 0, 0, 1)
        if(not shot) then
            autoAttackUI:setFillColor(1, 1, 1, 1)
        else
            autoAttackUI:setFillColor(0, 0, 0, 1)
        end
        gun.anchorY = playerRadius
        gun.rotation = playerRotation
    else
        gun:setFillColor(0, 0, 0, 0)
        autoAttackUI:setFillColor(0, 0, 0, 0)
    end
    

    player = display.newRect(player.x, player.y, playerRadius, playerRadius)
    player:setFillColor( 1, 1, 0)

    player.rotation = playerRotation
    
    physics.addBody( player, "dynamic", {playerRadius, isSensor = true })

    vision.x = player.x
    vision.y = player.y

    gun.x = player.x
    gun.y = player.y

    rushUI.x = player.x
    rushUI.y = player.y - (playerRadius * 1.1)

    --re 'toFront's some objects
    ReOrderToFront()
end

--True if player has a gun, false if not
function hasAGun()
    return (playerRadius > 8)
end

--(event.object1 and event.object2 collides in this engine)
local function onGlobalCollision( event )---------------------------------------------------------------------------------------

    if ( event.phase == "began" )
    then
        local _other
        local charCollided = true
        --saves the object that is not player 
        if(event.object1 == player)
        then
            _other = event.object2
        elseif(event.object2 == player)
        then
            _other = event.object1
        else
            charCollided = false
        end

        if(charCollided)
        then
            if(_other.type ~= "bullet")
            then
                --is point and player collided?
                if(_other.type == "point" and event.object1 == player or event.object2 == player)
                then
                --if player is bigger or they are equal but player is in its smallest stage
                    if(playerRadius > _other.r + 1 or playerRadius > _other.r and playerRadius == 2)
                    then
                        -----------------------------------------------------------------------
                        --This is a simplified version of:
                        --'Get bigger/slower/add_point "(pi * r * r) / (squareRadius * 4)" times. Delete collided point object.'
                        PlayerEaten = PlayerEaten + ((_other.r * _other.r * 0.75))

                        levelUp()

                        pointObjNumber = pointObjNumber - 1
                        DeleteGivenObj(_other)
                    end
                end
                --is enemy and player collided?
                if(_other.type == "enemy" and event.object1 == player or event.object2 == player)
                then
                    --Delete the enemy, lower point, delete the enemy from enemy_List layer
                    pointChanged(-10)
                    DeleteGivenObj(_other)
                    enemyNumber = enemyNumber - 1

                    EnemyList[_other.enemyID] = false
                end
            end

        else--A bullet is collided with something
            

            local bullet

            if(event.object1.type == "bullet")
            then
                bullet = event.object1
                _other = event.object2
            elseif(event.object2.type == "bullet")
            then
                bullet = event.object2
                _other = event.object1
            end

            if(_other.type == "enemy") then
                enemyNumber = enemyNumber - 1
                EnemyList[_other.enemyID] = false

                DeleteGivenObj( _other )

                bullet.penetrated = bullet.penetrated + 1

            elseif(_other.type == "point") then
                pointObjNumber = pointObjNumber - 1
                PlayerEaten = PlayerEaten + _other.r
                levelUp()

                DeleteGivenObj( _other )

                bullet.penetrated = bullet.penetrated + 1
            end

            if(bullet.penetrated > penetrationUpgrade) then
                
                DeleteGivenObj(bullet)
            end
        end

        CheckPointAndEnemy()
    end
end

--Get bigger
function levelUp()

    while PlayerEaten > playerRadius
    do
        PlayerEaten = PlayerEaten - (playerRadius - 1)

        playerRadius = playerRadius + 1
        --Delay is needed due to a box2d & Solar2d limitation. Runs the very next frame.
        timer.performWithDelay(1, function() ReCreatePlayer() end)

        pointChanged(1)

        defaultSpeed = defaultSpeed * 0.992
    end

    --Makes vision bigger as the cube gets bigger
    if(playerRadius > 10)
    then
        local scaleValue = math.log10(playerRadius)

        if scaleValue > 1 then
        vision:scale(scaleValue / vision.xScale, scaleValue / vision.yScale) end
    end
end

--Checks point and enemy count and spawns new ones if needed
function CheckPointAndEnemy()
    if pointObjNumber < 45 then
        while pointObjNumber < 50 do
            createObject("point")
        end
        --Makes enemies appear front of point objects
        EnemyToFront()
    end

    if enemyNumber < 10 then
        while enemyNumber < 20 do
            createObject("enemy")
        end
    end

    --re 'toFront's some objects
    ReOrderToFront()
end

--makes these appear before others in the given order
function ReOrderToFront()

    vision:toFront()
    gun:toFront()
    player:toFront()
    pointText:toFront()
    rushUI:toFront()

    if(hasAGun()) then
        autoAttackUI:toFront()
    end

    if(LevelUpUI) 
    then
        AttackSpeedUI:toFront()
        AttackSpeedText:toFront()

        AttackPenetrationUI:toFront()
        AttackPenetrationText:toFront()

        RushSpeedUI:toFront()
        RushSpeedText:toFront()
    end
end

--travels all enemies and places them front since enemyID stores next id to be used, enemyID is also array.length
function EnemyToFront()
    local i = 1
    while i < enemyID
    do
        if (EnemyList[i] ~= false)
        then
            EnemyList[i]:toFront()
        end
        i = i + 1
    end
end

--travels all enemies and makes them move towards player.
--Speed is according to their radius
function EnemyTowardsPlayer()
    local i = 1

    while i < enemyID
    do
        if (EnemyList[i] ~= false)
        then
            local changeX = 0
            local changeY = 0
            local speed = 0.5
            if(EnemyList[i].r > 2) then
                speed = speed / math.log(EnemyList[i].r)
            end

            local _Radian = RadianBetweenTwoPoints(player.x, player.y, EnemyList[i].x, EnemyList[i].y)

            EnemyList[i].x = EnemyList[i].x + (math.cos(_Radian) * speed)
            EnemyList[i].y = EnemyList[i].y + (math.sin(_Radian) * speed)
        end
        i = i + 1
    end
end 

--Shows score
local function KYS()

    local EndText = display.newText( "", display.contentCenterX, display.contentCenterY, native.systemFont, 100 )
    EndText.text = "Max Score: "..maxPointCount
    gameEnded(EndText)
end

--Shows "you won!""
local function YouWon()

    local EndText = display.newText( "", display.contentCenterX, display.contentCenterY, native.systemFont, 100 )
    EndText.text = "You Won!"
    gameEnded(EndText)
end

--Removes event listeners creates a transparent black image over everything
--Deletes vision and point shower text
function gameEnded(EndText)

    --mouse listener does not work on editor but is replacemant for touch listener in final build
    Runtime:removeEventListener( "mouse", RotateToMousePos )
    --Runtime:removeEventListener( "touch", RotateToMousePos )--works only when left click is held down
    Runtime:removeEventListener( "collision", onGlobalCollision )
    Runtime:removeEventListener( "key", keyHandler )
    Runtime:removeEventListener( "enterFrame", playerUpdate )

    isGameEnded = true

    local DeadScreenForeGround = display.newImageRect("pixel.png", display.contentWidth * 2, display.contentHeight * 2)
    DeadScreenForeGround.x = display.contentCenterX
    DeadScreenForeGround.y = display.contentCenterY

    DeadScreenForeGround:setFillColor( 0, 0, 0, 0.5 )
    DeadScreenForeGround:toFront()

    DeleteGivenObj(vision)
    DeleteGivenObj(pointText)
    

    EndText:setFillColor(0.392, 0.392, 0.863)--Bright midnight blue
    EndText:toFront()
    --player dies here.
end

--updates text and point_Count
function pointChanged(x)
	pointCount = pointCount + x
	pointText.text = pointCount

    if(pointCount > maxPointCount)
    then
        maxPointCount = pointCount
    elseif(pointCount < 0)
    then
        if(maxPointCount > 100) then
            YouWon()
        else
            KYS()
        end
    end

    --opens upgrade screen if score is mod of 4, for the first time for every number.
    if(maxPointCount > 10 and maxPointCount == pointCount)
    then
        if(math.fmod(maxPointCount, 4) == 0)
        then
            CreateLevelSelectionUI()
        end
    end
end

--Rotates to Mouse Position
local function RotateToMousePos( event )
    
    playerRotation = AngleBetweenTwoPoints(player.x, player.y, event.x, event.y)
    player.rotation = playerRotation
    vision.rotation = playerRotation
    gun.rotation = playerRotation
end

--This is magic, just don't touch it
function AngleBetweenTwoPoints(aX, aY, bX, bY)

    return ((math.atan2(aY - bY, aX - bX) * 57.29578) - 90)
end

--This also is magic, just don't touch it
function RadianBetweenTwoPoints(aX, aY, bX, bY)

    return (math.atan2(aY - bY, aX - bX))
end

--I call spawner last so they appear on top of everything that is not managed with ':toFront' (background)
CheckPointAndEnemy()

DeleteLevelSelectionUI()
CreateLevelSelectionUI()
DeleteLevelSelectionUI()

createObjectThere("point", player.x, player.y - 40)
createObjectThere("enemy", player.x, player.y + 40)

--these are event listeners

--mouse listener does not work on editor but is replacemant for touch listener in final build
Runtime:addEventListener( "mouse", RotateToMousePos)--DON'T FORGET TO CHANGE REMOVE EVENT LISTENER TOO
--Runtime:addEventListener( "touch", RotateToMousePos)--works only when left click is held down
Runtime:addEventListener( "collision", onGlobalCollision )
Runtime:addEventListener("key", keyHandler)
Runtime:addEventListener("enterFrame", playerUpdate)    