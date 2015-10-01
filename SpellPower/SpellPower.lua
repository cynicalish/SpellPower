-----------------------------------------------------------------------------------------------
-- Client Lua Script for SpellPower
-- Copyright (c) Kaels. All rights reserved.
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- SpellPower Module Definition
-----------------------------------------------------------------------------------------------
local SpellPower = {}

-----------------------------------------------------------------------------------------------
-- Defaults
-----------------------------------------------------------------------------------------------

local defaults = {
	version = "0.2.3",
	runOnce = true,
	locked = false,
	meta = true,
	scale = 100,
	focusTextEnabled = true,
	focusBarEnabled = true,
	left = 0,
	top = 0,
	width = 360,
	height = 40,
	elementSpacing = 5,
	borderPadding = 5,
	combatOpacity = 0.7,
	noCombatOpacity = 0.4,
	bgMultiplier = 0.4
}

defaults.__index = defaults

-----------------------------------------------------------------------------------------------
-- Helpers and Misc Data
-----------------------------------------------------------------------------------------------

local function print(str)
	ChatSystemLib.PostOnChannel(2, str)	
end

function SpellPower:TestFunctionPleaseIgnore( handler, control, strText )
	for k,v in pairs(getmetatable(handler)) do
		print(k)
	end
	
	print("SpellPower Addon: This is debug text; please report it on Curse if you see it.")
end

local function recursiveCopy(fromTable, toTable)
	toTable = toTable or {}
	for k,v in pairs(fromTable) do
		if type(k) ~= "table" then
			if type(v) ~= "table" then
				toTable[k] = v
			else
				toTable[k] = recursiveCopy(v, toTable[k])
			end
		end
	end
	return toTable
end

local function round(x)
	return x % 2 ~= 0.5 and math.floor(x + 0.5) or x - 0.5
end

local function toNaturalNumber(arg)
	local num
	if not arg then
		return 0
	else
		num = tonumber(arg) or tonumber(arg,16)
		if not num and type(arg) == "string" and string.len(arg) ~= 0 then
			local i = 17
			while i <= 35 and not num do
				num = tonumber(arg, i)
				i = i + 1
			end
		end
		num = num or 0
	end
	return round(math.abs(num))
end

local classHasFocus = {
	Esper = true,
	Engineer = false,
	Medic = true,
	Spellslinger = true,
	Stalker = false,
	Warrior = false
}

local function doNothing() return end

local limits = {
	minScale = 50,
	maxScale = 200,
	minBarHeight = 4,
	minFocusHeight = 1,
	minOpacity = 0,
	maxOpacity = 1
}

local limitsMeta = {
	__index = function(t, k)
		if k == "screenWidth" then
			local screenX, _ = Apollo:GetScreenSize()
			return screenX or 1920
		elseif k == "screenHeight" then
			local _, screenY = Apollo:GetScreenSize()
			return screenY or 1080
		elseif k == "minBarWidth" then
			local numNodes = SpellPower:GetNumberResourceNodes()
			local minWidth = numNodes + (numNodes - 1) * SpellPower:GetElementSpacing()
			return minWidth
		end
	end,
	__newindex = doNothing,
	__metatable = doNothing
}

setmetatable(limits, limitsMeta)
-----------------------------------------------------------------------------------------------
-- Loading
-----------------------------------------------------------------------------------------------
function SpellPower:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

function SpellPower:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "SpellPower"
	local tDependencies = {}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
	Apollo.RegisterSlashCommand("spw", "OnConfigure", self)
	Apollo.RegisterSlashCommand("spellpower", "OnConfigure", self)
end

function SpellPower:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("SpellPower.xml")
	return self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

-----------------------------------------------------------------------------------------------
-- Saved Variables and Settings
-----------------------------------------------------------------------------------------------
local db = {}
setmetatable(db, defaults)

function SpellPower:OnSave(level)
	if level ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end
	return recursiveCopy(db)
end

function SpellPower:OnRestore(level, saveTable)
	if level ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end
	-- fix saved variables from old versions
	local fixedTable
	if not saveTable.version or saveTable.version ~= defaults.version then
		fixedTable = {}
		local pos = saveTable.position
		if pos then
			fixedTable.left = pos[1]
			fixedTable.top = pos[2]
			fixedTable.width = pos[3] - pos[1]
			fixedTable.height = pos[4] - pos[2]
		end
		for k,v in pairs(defaults) do
			local saveVal = saveTable[k]
			if saveVal ~= nil and saveVal ~= v then
				fixedTable[k] = saveVal
			end
		end
		saveTable = fixedTable
	end
	db = recursiveCopy(saveTable, db)
	db.version = defaults.version
end

function SpellPower:OnConfigure()
	if not self.optionsPanel then
		return
	else
		self.optionsPanel:Show(true)
		self:CenterOptionsPanel()
	end
end

function SpellPower:GetSize()
	return toNaturalNumber(db.width), toNaturalNumber(db.height)
end

function SpellPower:GetRealSize()
	return toNaturalNumber(db.width * db.scale / 100), toNaturalNumber(db.height * db.scale / 100)
end

function SpellPower:GetBorderPadding()
	return toNaturalNumber(db.borderPadding)
end

function SpellPower:GetElementSpacing()
	return toNaturalNumber(db.elementSpacing)
end

function SpellPower:GetMinimumSize()
	local minWidth = 2 * self:GetBorderPadding() + limits.minBarWidth
	local minHeight = 2 * self:GetBorderPadding() + limits.minBarHeight
	local width, height = self:GetSize()
	local spacing, padding = self:GetElementSpacing(), self:GetBorderPadding()
	if self.class and classHasFocus[self.class] then
		if db.focusBarEnabled then
			minHeight = minHeight + limits.minFocusHeight + spacing
		end
		height = height > minHeight and height or minHeight
		if db.focusTextEnabled then
			minWidth = minWidth + height + padding
		end
	end
	return toNaturalNumber(minWidth), toNaturalNumber(minHeight)
end

function SpellPower:GetMaximumSize()
	local scale = self:GetScale()
	return toNaturalNumber(limits.screenWidth * 100 / scale), toNaturalNumber(limits.screenHeight * 100 / scale)
end

function SpellPower:GetPosition()
	return toNaturalNumber(db.left), toNaturalNumber(db.top)
end

function SpellPower:GetMaximumPosition()
	local screenX, screenY = limits.screenWidth, limits.screenHeight
	local realWidth, realHeight = self:GetRealSize()
	return toNaturalNumber(screenX - realWidth), toNaturalNumber(screenY - realHeight)
end

function SpellPower:GetScale()
	return toNaturalNumber(db.scale)
end

function SpellPower:IsFocusTextEnabled()
	return db.focusTextEnabled
end

function SpellPower:IsFocusBarEnabled()
	return db.focusBarEnabled
end

function SpellPower:IsLocked()
	return db.locked
end

function SpellPower:IsMetaKeyRequired()
	return db.meta
end

function SpellPower:GetNumberResourceNodes()
	return self.numberResourceNodes or 1
end

function SpellPower:GetOpacity()
	return db.combatOpacity, db.noCombatOpacity, db.bgMultiplier
end

function SpellPower:RunOnce()
	if not db.runOnce then return end
	self:SetCenter()
	db.runOnce = false
end

function SpellPower:SetPosition(left, top)
	left, top = toNaturalNumber(left or db.left), toNaturalNumber(top or db.top)
	local maxleft, maxtop = self:GetMaximumPosition()
	
	left = left <= maxleft and left or maxleft
	top = top <= maxtop and top or maxtop
	
	db.left, db.top = left, top
	return self:DrawPanel()
end

function SpellPower:SetCenter(dimension)
	local left, top = self:GetPosition()
	local realWidth, realHeight = self:GetRealSize()
	if not dimension or dimension == "horizontal" then
		left = toNaturalNumber((limits.screenWidth - realWidth) / 2)
	end
			
	if not dimension or dimension == "vertical" then
		top = toNaturalNumber((limits.screenHeight - realHeight) / 2)
	end
	
	return self:SetPosition(left, top)
end

function SpellPower:SetSize(width, height)
	width = toNaturalNumber(width or db.width)
	height = toNaturalNumber(height or db.height)
	local minWidth, minHeight = self:GetMinimumSize()
	local maxWidth, maxHeight = self:GetMaximumSize()
	width =  width >= minWidth and width or minWidth
	width =  width <= maxWidth and width or maxWidth
	db.width = width
	height =  height >= minHeight and height or minHeight
	height =  height <= maxHeight and height or maxHeight
	db.height = height
	return self:SetPosition()
end

function SpellPower:SetScale(scale)
	scale = toNaturalNumber(scale)
	local minScale, maxScale = limits.minScale, limits.maxScale
	scale = scale >= minScale and scale or minScale
	scale = scale <= maxScale and scale or maxScale
	db.scale = scale
	return self:SetPosition()
end

function SpellPower:SetElementSpacing(spacing)
	db.elementSpacing = toNaturalNumber(spacing)
	return self:SetPosition()
end

function SpellPower:SetBorderPadding(padding)
	db.borderPadding = toNaturalNumber(padding)
	return self:SetPosition()
end

function SpellPower:SetFocusBarEnabled(enable)
	db.focusBarEnabled = enable
	return self:SetPosition()
end

function SpellPower:SetFocusTextEnabled(enable)
	db.focusTextEnabled = enable
	return self:SetPosition()
end

function SpellPower:SetLocked(locked)
	db.locked = locked
	return self:SetPosition()
end

function SpellPower:SetMetaKeyRequired(meta)
	db.meta = meta
	return self:SetPosition()
end

function SpellPower:SetOpacity(combatOpacity, noCombatOpacity, bgMultiplier)
	local min, max = limits.minOpacity, limits.maxOpacity
	if combatOpacity then
		combatOpacity = tonumber(combatOpacity) or 0
		combatOpacity = combatOpacity >= min and combatOpacity or min
		db.combatOpacity = round((combatOpacity <= max and combatOpacity or max) * 100) * 0.01
	end
	if noCombatOpacity then
		noCombatOpacity = tonumber(noCombatOpacity) or 0
		noCombatOpacity = noCombatOpacity >= min and noCombatOpacity or min
		db.noCombatOpacity = round((noCombatOpacity <= max and noCombatOpacity or max) * 100) * 0.01
	end
	if bgMultiplier then
		bgMultiplier = tonumber(bgMultiplier) or 0
		bgMultiplier = bgMultiplier >= min and bgMultiplier or min
		db.bgMultiplier = round((bgMultiplier <= max and bgMultiplier or max) * 100) * 0.01
		return self:DrawPanel()
	end
end

function SpellPower:IncrementPosition(xIncrement, yIncrement)
	xIncrement = xIncrement and tonumber(xIncrement) or 0
	yIncrement = yIncrement and tonumber(yIncrement) or 0
	local left, top = self:GetPosition()
	
	left = left + xIncrement
	top = top + yIncrement
	
	return self:SetPosition(left, top)
end

function SpellPower:IncrementSize(widthIncrement, heightIncrement)
	widthIncrement = widthIncrement and tonumber(widthIncrement) or 0
	heightIncrement = heightIncrement and tonumber(heightIncrement) or 0
	local width, height = self:GetSize()
	
	width = width + widthIncrement
	height = height + heightIncrement
	
	return self:SetSize(width, height)
end

function SpellPower:SavePosition()
	local left, top, right, bottom = self.resourcePanel:GetAnchorOffsets()
	db.width = toNaturalNumber(right - left)
	db.height = toNaturalNumber(bottom - top)
	return self:SetPosition(left, top)
end

-----------------------------------------------------------------------------------------------
-- Creating the panel
-----------------------------------------------------------------------------------------------

function SpellPower:DrawPanel()
	if not self.resourcePanel or not self.class then return end
	local left, top = self:GetPosition()
	local width, height = self:GetSize()
	local scale = self:GetScale() / 100
	local padding = self:GetBorderPadding()
	local spacing = self:GetElementSpacing()
	local _, _, bgmult = self:GetOpacity()

	self.resourcePanel:SetBGOpacity(bgmult)
	-- verify that settings are within allowable limits
	local maxwidth, maxheight = self:GetMaximumSize()
	if width > maxwidth or height > maxheight then
		return self:SetSize()
	end
	local maxleft, maxtop = self:GetMaximumPosition()
	if left > maxleft or top > maxtop then
		return self:SetPosition()
	end
	
	-- configure the panel itself
	self.resourcePanel:SetAnchorOffsets(left, top, left + width, top + height)
	self.resourcePanel:SetScale(scale)
	if self:IsLocked() then
		self.resourcePanel:RemoveStyle("Moveable")
	else
		self.resourcePanel:AddStyle("Moveable")
	end
	if self:IsMetaKeyRequired() then
		self.resourcePanel:AddStyle("RequireMetaKeyToMove")
	else
		self.resourcePanel:RemoveStyle("RequireMetaKeyToMove")
	end
	
	-- size the sub-panels
	local resourceContainer = self.resourcePanel:FindChild("BarContainer")
	assert(resourceContainer, "SpellPower: Error in DrawPanel: Missing resource bar!")
	
	local barWidth, barHeight, barContainerRight, barContainerBottom
	local focusTextContainer
	-- non-focus classes are easy
	if not classHasFocus[self.class] then
		resourceContainer:SetAnchorOffsets(0, 0, width, height)
		barWidth = width - 2 * padding
		barHeight = height - 2 * padding
		barContainerRight, barContainerBottom = width, height
	else
		-- why do you people want so many options
		focusTextContainer = self.resourcePanel:FindChild("FocusTextContainer")
		local focusText = focusTextContainer:FindChild("FocusText")
		if self:IsFocusTextEnabled() then		
			focusTextContainer:Show(true)
			barWidth = width - height - 2 * padding
			barContainerRight = width - height
		else
			focusTextContainer:Show(false)
			barWidth = width - 2 * padding
			barContainerRight = width
		end
		focusText:SetAnchorOffsets(-(padding), 0, height, height)
	end
	
	-- we want the focus bar to align with the resource nodes, so if the bar width isn't an even multiple, we'll shrink it a bit to match
	local nodes = self.resourceNodes
	if not nodes then return end
	local n = #nodes
	local nodeWidth = math.floor((barWidth - (n - 1) * spacing) / n)
	local extraSpace = barWidth - (n * nodeWidth + (n - 1) * spacing)
	barContainerRight = barContainerRight - extraSpace
	barWidth = barWidth - extraSpace
	if classHasFocus[self.class] and self:IsFocusTextEnabled() then
		focusTextContainer:SetAnchorOffsets(width - height - extraSpace, 0, width - extraSpace, height)
	end
	
	if classHasFocus[self.class] then
		local focusBarContainer = self.resourcePanel:FindChild("FocusBarContainer")
		local focusBar = focusBarContainer:FindChild("FocusBar")
		if self:IsFocusBarEnabled() then
			focusBarContainer:Show(true)
			local availableHeight = height - 2 * padding - spacing
			local focusHeight = math.floor(availableHeight / 5)
			barHeight = availableHeight - focusHeight
			focusBarContainer:SetAnchorOffsets(0, barHeight + padding + spacing, barContainerRight, height)
			focusBar:SetAnchorOffsets(padding, 0, barWidth + padding, focusHeight)
			barContainerBottom = barHeight + padding + spacing
		else
			focusBarContainer:Show(false)
			barHeight = height - 2 * padding
			barContainerBottom = height
		end
	end
	resourceContainer:SetAnchorOffsets(0, 0, barContainerRight, barContainerBottom)
	
	-- every class draws its nodes differently
	if not self.DrawNode then return end
	for i = 1, n do
		local nodeLeft = padding + (i - 1) * (nodeWidth + spacing)
		self:DrawNode(i, nodeLeft, padding, nodeWidth, barHeight)
	end		
end

function SpellPower:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.LoadSprites("SpellPower_SSRunes.xml")
	Apollo.LoadSprites("SpellPower_Misc.xml")
	self.optionsPanel = Apollo.LoadForm(self.xmlDoc, "OptionsPanel", nil, self)
	self.optionsPanel:Show(false)
	self.bDocLoaded = true
	if GameLib.GetPlayerUnit() then
		self:OnCharacterCreated()
	else
		Apollo.RegisterEventHandler("CharacterCreated", "OnCharacterCreated", self)
	end
end

function SpellPower:OnCharacterCreated()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then
		return
	end

	local classId =  unitPlayer:GetClassId()
	if classId == GameLib.CodeEnumClass.Engineer then
		self.class = "Engineer"
		--self:OnCreateEngineer()
	elseif classId == GameLib.CodeEnumClass.Esper then
		self.class = "Esper"
		--self:OnCreateEsper()
	elseif classId == GameLib.CodeEnumClass.Medic then
		self.class = "Medic"
		--self:OnCreateMedic()
	elseif classId == GameLib.CodeEnumClass.Spellslinger then
		self.class = "Spellslinger"
		self:OnCreateSlinger()
	elseif classId == GameLib.CodeEnumClass.Stalker then
		self.class = "Stalker"
		--self:OnCreateStalker()
	elseif classId == GameLib.CodeEnumClass.Warrior then
		self.class = "Warrior"
		--self:OnCreateWarrior()
	end
end

-----------------------------------------------------------------------------------------------
-- Spellslinger
-----------------------------------------------------------------------------------------------
local spellPowerPerNode = 25

local SpellslingerColors = {
	NoSurgeNoFull = "FF006E99",
	NoSurgeFull = "FF00B7FF",
	SurgeNoFull = "FF992400",
	SurgeFull = "FFFF3C00",
	Backdrop = "000000"
}

local function slingerDrawNode(self, nodeIndex, left, top, width, height)
	local node, rune = self.resourceNodes[nodeIndex], self.resourceRunes[nodeIndex]
	node:SetAnchorOffsets(left, top, left + width, top + height)
	rune:SetAnchorOffsets(toNaturalNumber((width - height) / 2), 0, toNaturalNumber((width + height) / 2), height)
end

function SpellPower:SetupSlingerResourceNodes()
	local unitPlayer = GameLib.GetPlayerUnit()
	local maxSpellpower = (unitPlayer and unitPlayer:GetMaxResource(4)) or 100
	self.maxSpellpower = maxSpellpower
	self.numberResourceNodes = maxSpellpower / spellPowerPerNode
	self.resourcePerNode = spellPowerPerNode
	self.smoothResourcePerNode = spellPowerPerNode * 100
	local numberNodes = self.numberResourceNodes
	self.resourceNodes = self.resourceNodes or {}
	self.resourceRunes = self.resourceRunes or {}
	self.bars = self.bars or {}
	for i = 1, numberNodes do
		self.resourceNodes[i] = self.resourcePanel:FindChild("SpellPowerBar"..i)
		self.resourceRunes[i] = self.resourceNodes[i]:FindChild("Full")
		self.bars[#self.bars + 1] = self.resourceNodes[i]
	end
	for i = numberNodes + 1, #self.resourceNodes do
		self.resourceNodes[i] = nil
		self.resourceRunes[i] = nil
	end
end

function SpellPower:OnCreateSlinger()
	Apollo.RegisterEventHandler("VarChange_FrameCount", "OnSlingerUpdateTimer", self)

    self.resourcePanel = Apollo.LoadForm(self.xmlDoc, "SlingerResourcePanel", nil, self)
	self.focusBar = self.resourcePanel:FindChild("FocusBar")
	self.focusText = self.resourcePanel:FindChild("FocusText")
	self.resourcePanel:ToFront()
	self.DrawNode = slingerDrawNode
		
	self:SetupSlingerResourceNodes()
	self.bars[#self.bars + 1] = self.focusBar

	self.fullBars = { }
	for i = 1, #self.bars do
		self.fullBars[i] = true
	end
	
	self:DrawPanel()
	
	self.lastRealUpdate = -1
	local unitPlayer = GameLib.GetPlayerUnit()
	if unitPlayer then
		self:OnSlingerUpdateTimer()
	end
	self:RunOnce()
end

function SpellPower:OnSlingerUpdateTimer()
	local unitPlayer = GameLib.GetPlayerUnit()
	if not unitPlayer then return end
	local maxResource = unitPlayer:GetMaxResource(4) or 100
	local resourcePerNode = self.resourcePerNode or 25
	local nodes = self.resourceNodes
	if not nodes then
		self:SetupSlingerResourceNodes()
	end
	local numberNodes = #nodes
	if resourcePerNode * numberNodes ~= maxResource then
		self:SetupSlingerResourceNodes()
	end
	local currentResource = unitPlayer:GetResource(4)
	local spellSurge = GameLib.IsSpellSurgeActive()
	local inCombat = unitPlayer:IsInCombat()
	
	-- Focus (game functions apparently call it Mana)
	local maxFocus = math.floor(unitPlayer:GetMaxFocus())
	maxFocus = (maxFocus > 0 and maxFocus) or 100
	local currentFocus = math.floor(unitPlayer:GetFocus()) or 0
	self.focusBar:SetMax(maxFocus)
	self.focusBar:SetProgress(currentFocus)
	self.focusBar:SetTooltip(String_GetWeaselString(Apollo.GetString("SpellslingerResource_FocusTooltip"), currentFocus, maxFocus))
	self.focusText:SetText(math.floor((currentFocus / maxFocus) * 100))

	-- Spellpower
	local spellpowerTooltip = String_GetWeaselString(Apollo.GetString("Spellslinger_SpellSurge"), currentResource, maxResource) 
	
	-- Smoothing
	currentResource, maxResource = currentResource * 100, maxResource * 100
	local smoothRPN = self.smoothResourcePerNode
	
	local lastRealUpdate = self.lastRealUpdate or currentResource
	self.lastRealUpdate = currentResource
	self.lastFakeValue = self.lastFakeValue or lastRealUpdate
	self.stepSize = self.stepSize or 0
	self.framesSinceUpdate = self.framesSinceUpdate or 0
	self.framesBetweenUpdates = self.framesBetweenUpdates or 1
	
	local realDifference = currentResource - lastRealUpdate
	local fakeDifference = currentResource - self.lastFakeValue
	if realDifference ~= 0 and self.framesSinceUpdate ~= 0 then
		local framesBetweenUpdates = math.ceil((9 * self.framesBetweenUpdates + self.framesSinceUpdate) / 10)
		self.framesBetweenUpdates = (framesBetweenUpdates > 0 and framesBetweenUpdates) or 1
		self.framesSinceUpdate = 0
		if fakeDifference < 1000 and fakeDifference > - 1000 then
			self.stepSize = math.ceil((9 * self.stepSize + (fakeDifference / self.framesBetweenUpdates)) / 10)
		end
	elseif realDifference == 0 and currentResource ~= maxResource then
		self.framesSinceUpdate = self.framesSinceUpdate + 1
	end
	
	local newValue = self.lastFakeValue + self.stepSize
	local newValueNode = math.floor(newValue / smoothRPN)
	local realValueNode = math.floor(self.lastRealUpdate / smoothRPN)
	if newValueNode == realValueNode and (fakeDifference < 1000 and fakeDifference > -1000) then
		currentResource = newValue
	end
	
	self.lastFakeValue = currentResource
	
	-- Setting Value
	for i = 1,numberNodes do
		local currentBar = self.resourceNodes[i]
		currentBar:SetMax(smoothRPN)
		if i <= realValueNode then
			currentBar:SetProgress(smoothRPN)
			self.fullBars[i] = true
			self.resourceRunes[i]:Show(inCombat)
		elseif i == realValueNode + 1 then
			local partialProgress = currentResource - (smoothRPN * (i - 1))
			partialProgress = (partialProgress > 0 and partialProgress) or 0
			partialProgress = partialProgress + (partialProgress / smoothRPN) * 150
			currentBar:SetProgress(partialProgress)
			self.fullBars[i] = false
			self.resourceRunes[i]:Show(false)
		else
			currentBar:SetProgress(0)
			self.fullBars[i] = false
			self.resourceRunes[i]:Show(false)
		end
		currentBar:SetTooltip(spellpowerTooltip)
	end
	
	local combatOpacity, noCombatOpacity = self:GetOpacity()
	self.resourcePanel:SetOpacity(inCombat and combatOpacity or noCombatOpacity)
	if spellSurge then
		for i = 1,#self.bars do
			local bar = self.bars[i]
			bar:SetBarColor(self.fullBars[i] and SpellslingerColors.SurgeFull or SpellslingerColors.SurgeNoFull)		
		end
		self.focusText:SetTextColor(SpellslingerColors.SurgeFull)
	else
		for i = 1,#self.bars do
			local bar = self.bars[i]
			bar:SetBarColor(self.fullBars[i] and SpellslingerColors.NoSurgeFull or SpellslingerColors.NoSurgeNoFull)
		end
		self.focusText:SetTextColor(SpellslingerColors.NoSurgeFull)
	end
	
	if self.userIsHoldingOptionsButton then
		self.userHoldingCount = self.userHoldingCount and self.userHoldingCount + 1 or 0
		if self.userHoldingCount > 5 then
			self:OptionsButtonClicked(self.userIsHoldingOptionsButton)
		end
	end
	
	-- a bit hacky, but I can't find an event that catches the player exiting combat
	--if (inCombat ~= self.inCombat) then
		--self:HelperToggleVisibilityPreferences(self.resourcePanel, unitPlayer)
		--self.inCombat = inCombat
	--end
end

---------------------------------------------------------------------------------------------------
-- OptionsPanel Functions
---------------------------------------------------------------------------------------------------


function SpellPower:CenterOptionsPanel()
	if not self.optionsPanel then return end
	local screenX, screenY = Apollo:GetScreenSize()
	local oldleft, oldtop, oldright, oldbottom = self.optionsPanel:GetAnchorOffsets()
	local width = toNaturalNumber(oldright - oldleft)
	local height = toNaturalNumber(oldbottom - oldtop)
	local left = toNaturalNumber((screenX - width) * self.optionsPanel:GetScale() / 2)
	local top = toNaturalNumber((screenY - height) * self.optionsPanel:GetScale() / 2)
	return self.optionsPanel:SetAnchorOffsets(left, top, left + width, top + height)
end

function SpellPower:MouseOverOptionsButton( handler, control, x, y )
	control:SetBGColor("xkcdCerulean")
end

function SpellPower:MouseOffOptionsButton( handler, control, x, y )
	control:SetBGColor("white")
	self.userIsHoldingOptionsButton = nil
	self.userHoldingCount = 0
end

local clickHoldButtons = {
	PositionLeft = true,
	PositionRight = true,
	PositionUp = true,
	PositionDown = true,
	Narrower = true,
	Wider = true,
	Shorter = true,
	Taller = true
}

function SpellPower:MouseDownOptionsButton( handler, control, mouseButton, nLastRelativeMouseX, nLastRelativeMouseY, doubleClick, stopPropagation )
	control:SetBGColor("xkcdElectricBlue")
	local name = control:GetName()
	if clickHoldButtons[name] then
		self.userIsHoldingOptionsButton = name
		self.userHoldingCount = 0
	end
end

function SpellPower:MouseUpOptionsButton( handler, control, mouseButton, x, y )
	handler:SetBGColor("xkcdCerulean")
	if control == handler then
		self:OptionsButtonClicked(handler:GetName())
	end
	self.userIsHoldingOptionsButton = nil
	self.userHoldingCount = 0
end

function SpellPower:OptionsButtonClicked(name, amount)
	amount = amount or 0
	if name == "LockButton" then
		self:SetLocked(not self:IsLocked())
	elseif name == "MetaButton" then
		self:SetMetaKeyRequired(not self:IsMetaKeyRequired())
	elseif name == "CenterHorizButton" then
		self:SetCenter("horizontal")
	elseif name == "CenterVertButton" then
		self:SetCenter("vertical")
	elseif name == "PositionLeft" then
		self:IncrementPosition(-1)
	elseif name == "PositionRight" then
		self:IncrementPosition(1)
	elseif name == "PositionUp" then
		self:IncrementPosition(nil, -1)
	elseif name == "PositionDown" then
		self:IncrementPosition(nil, 1)
	elseif name == "Narrower" then
		self:IncrementSize(-1)
	elseif name == "Wider" then
		self:IncrementSize(1)
	elseif name == "Shorter" then
		self:IncrementSize(nil, -1)
	elseif name == "Taller" then
		self:IncrementSize(nil, 1)
	elseif name == "XPosition" then
		self:IncrementPosition(amount)
	elseif name == "YPosition" then
		self:IncrementPosition(nil, amount)
	elseif name == "Width" then
		self:IncrementSize(amount)
	elseif name == "Height" then
		self:IncrementSize(nil, amount)
	elseif name == "BgOpacity" then
		local _, _, opacity = self:GetOpacity()
		self:SetOpacity(nil, nil, opacity + amount / 100)
	elseif name == "NoCombatOpacity" then
		local _, opacity, _ = self:GetOpacity()
		self:SetOpacity(nil, opacity + amount / 100)
	elseif name == "CombatOpacity" then
		local opacity, _ = self:GetOpacity()
		self:SetOpacity(opacity + amount / 100)
	elseif name == "Scale" then
		self:SetScale(self:GetScale() + amount)
	elseif name == "FocusText" then
		self:SetFocusTextEnabled(not self:IsFocusTextEnabled())
	elseif name == "FocusBar" then
		self:SetFocusBarEnabled(not self:IsFocusBarEnabled())
	end
	
	self:OptionsPanelRefreshValues()
end

function SpellPower:MouseWheelOption( handler, control, x, y, amount, consumeMouseWheel )
	if control == handler then
		self:OptionsButtonClicked(handler:GetName(), amount)
	end
end

function SpellPower:EditBoxChanged( box, _, text )
	local name = box:GetName()
	if name == "XPositionEditBox" then
		self:SetPosition(text)
	elseif name == "YPositionEditBox" then
		self:SetPosition(nil, text)
	elseif name == "ScaleEditBox" then
		self:SetScale(text)
		local scaleSlider = self.optionsPanel:FindChild("ScaleSlider")
		scaleSlider:SetMax(150)
		scaleSlider:SetProgress(self:GetScale() - 50)
	elseif name == "WidthEditBox" then
		self:SetSize(text)
	elseif name == "HeightEditBox" then
		self:SetSize(nil, text)
	elseif name == "BgOpacityEditBox" then
		self:SetOpacity(nil, nil, text)
	elseif name == "NoCombatOpacityEditBox" then
		self:SetOpacity(nil, text)
	elseif name == "CombatOpacityEditBox" then
		self:SetOpacity(text)
	end
end

local editBoxes
function SpellPower:TabToNextEditBox(box)
	self:OptionsPanelRefreshValues()
	if not editBoxes then
		local options = self.optionsPanel 
		editBoxes = {
			options:FindChild("XPositionEditBox"),
			options:FindChild("YPositionEditBox"),
			options:FindChild("ScaleEditBox"),
			options:FindChild("WidthEditBox"),
			options:FindChild("HeightEditBox"),
			options:FindChild("BgOpacityEditBox"),
			options:FindChild("NoCombatOpacityEditBox"),
			options:FindChild("CombatOpacityEditBox")
		}
	end
	local curIndex
	for i = 1,#editBoxes do
		if editBoxes[i] == box then
			curIndex = i
			break
		end
	end
	curIndex = curIndex < #editBoxes and curIndex or 0
	nextBox = editBoxes[curIndex + 1]
	nextBox:SetFocus()
end

function SpellPower:OptionsPanelRefreshValues()
	local options = self.optionsPanel
	
	local locked, meta = self:IsLocked(), self:IsMetaKeyRequired()
	
	local lockButton = options:FindChild("LockButton")
	lockButton:FindChild("On"):Show(locked)
	lockButton:FindChild("Off"):Show(not locked)
	
	local metaButton = options:FindChild("MetaButton")
	metaButton:FindChild("On"):Show(meta)
	metaButton:FindChild("Off"):Show(not meta)
	
	local left, top = self:GetPosition()	
	
	local xbox, ybox = options:FindChild("XPositionEditBox"), options:FindChild("YPositionEditBox")
	xbox:SetText(left)
	ybox:SetText(top)
	
	local scale = self:GetScale()
	local scalebox = options:FindChild("ScaleEditBox")
	scalebox:SetText(scale)
	
	local scaleSlider = options:FindChild("ScaleSlider")
	scaleSlider:SetMax(150)
	scaleSlider:SetProgress(scale - 50)
	
	local width, height = self:GetSize()
	local wbox, hbox = options:FindChild("WidthEditBox"), options:FindChild("HeightEditBox")
	wbox:SetText(width)
	hbox:SetText(height)
	
	local combatOpacity, noCombatOpacity, bgMultiplier = self:GetOpacity()
	local cbox, ncbox, bgbox = options:FindChild("CombatOpacityEditBox"), options:FindChild("NoCombatOpacityEditBox"), options:FindChild("BgOpacityEditBox")
	cbox:SetText(combatOpacity)
	ncbox:SetText(noCombatOpacity)
	bgbox:SetText(bgMultiplier)
	
	local ftext, fbar = self:IsFocusTextEnabled(), self:IsFocusBarEnabled()
	local ftbox, fbbox = options:FindChild("FocusText"), options:FindChild("FocusBar")
	ftbox:FindChild("On"):Show(ftext)
	ftbox:FindChild("Off"):Show(not ftext)
	fbbox:FindChild("On"):Show(fbar)
	fbbox:FindChild("Off"):Show(not fbar)
end

local isMouseDownOnSlider = false
function SpellPower:MouseOverSlider( handler, control, x, y )
	if control == handler then
		handler:SetBarColor(isMouseDownOnSlider and "xkcdElectricBlue" or "xkcdCerulean")
		local options = self.optionsPanel
		local name = handler:GetName()
		if name == "ScaleSlider" then
			local editbox = options:FindChild("ScaleEditBox")
			editbox:SetText(x + 50)	
			if isMouseDownOnSlider then
				handler:SetMax(150)
				handler:SetProgress(x)
				self:SetScale(x + 50)
			else
				if not self.resourcePanel then return end
				self.resourcePanel:SetScale((x + 50) / 100)
			end
		end
	end
end

function SpellPower:MouseOffSlider( handler, control, x, y )
	if control == handler then
		handler:SetBarColor("55FFFFFF")
		local options = self.optionsPanel
		local name = handler:GetName()
		if name == "ScaleSlider" then
			self:OptionsPanelRefreshValues()
			if not self.resourcePanel then return end
			self.resourcePanel:SetScale(self:GetScale() / 100)
		end
		isMouseDownOnSlider = false
	end
end

function SpellPower:MouseDownSlider( handler, control, mouseButton, x, y, doubleClick, stopPropagation )
	if control == handler then
		handler:SetBarColor("xkcdElectricBlue")
		local options = self.optionsPanel
		local name = handler:GetName()
		if name == "ScaleSlider" then
			local editbox = options:FindChild("ScaleEditBox")
			editbox:SetText(x + 50)	
			handler:SetMax(150)
			handler:SetProgress(x)
			self:SetScale(x + 50)
		end
		isMouseDownOnSlider = true
	end
end

function SpellPower:MouseUpSlider( handler, control, mouseButton, nLastRelativeMouseX, nLastRelativeMouseY )
	if control == handler then
		handler:SetBarColor("xkcdCerulean")
		isMouseDownOnSlider = false
	end
end

function SpellPower:CloseOptionsPanel( handler, control, mouseButton )
	self.optionsPanel:Show(false)
end

-----------------------------------------------------------------------------------------------
-- Misc
-----------------------------------------------------------------------------------------------

-- TODO: Implement combat toggle behaviour
function SpellPower:HelperToggleVisibilityPreferences(wndParent, unitPlayer, bInCombat)
	--local nVisibility = Apollo.GetConsoleVariable("hud.ResourceBarDisplay")

	--if nVisibility == 2 then --always off
		--wndParent:Show(false)
	--elseif nVisibility == 3 then --on in combat
		--wndParent:Show(bInCombat)
	--elseif nVisibility == 4 then --on out of combat
		--wndParent:Show(not bInCombat)
	--else
		wndParent:Show(true)
	--end
end

-----------------------------------------------------------------------------------------------
-- SpellPower Instance
-----------------------------------------------------------------------------------------------
local SpellPowerInst = SpellPower:new()
SpellPowerInst:Init()
