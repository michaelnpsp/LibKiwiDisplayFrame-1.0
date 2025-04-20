-- ============================================================================
-- LibKiwiDisplayFrame-1.0 (C) 2025 MiCHaEL
-- Display frame code and helper functions for Kiwi addons
-- Display frame can be created as a Details plugin
-- ============================================================================

local lib = LibStub:NewLibrary("LibKiwiDisplayFrame-1.0", 1)
if not lib then return end

local media = LibStub("LibSharedMedia-3.0", true)

-- local references
local type = type
local next = next
local print = print
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local select = select

-- default values
local DUMMY = function() end
local SV_DEFAULTS = { global={}, profileKeys={}, profiles={} }
local COLOR_WHITE = {1,1,1,1}
local COLOR_TRANSPARENT = {0,0,0,0}
local FONT_SIZE_DEFAULT = 12
local ROW_COLOR_DEFAULT = {.2,.2,.2,.7}
local ROW_TEXTURE_DEFAULT = "Interface\\Buttons\\WHITE8X8"
local BACKDROP_DEF = { bgFile = "Interface\\Buttons\\WHITE8X8" }
local BACKDROP_CFG = {
	bgFile = "Interface\\Buttons\\WHITE8X8",
	edgeFile = nil, -- config.borderTexture
	tile = true, tileSize = 8, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

--============================================================
--  Useful constants
--============================================================

lib.realmKey = GetRealmName()
lib.charKey = UnitName("player") .. " - " .. lib.realmKey
lib.classKey = UnitClass("player")
lib.localeKey = GetLocale():lower()

--============================================================
--  Misc functions
--============================================================

-- copy table
function lib:CopyTable(src, dst)
	if type(dst)~="table" then dst = {} end
	for k,v in pairs(src) do
		if type(v)=="table" then
			dst[k] = lib:CopyTable(v,dst[k])
		elseif dst[k]==nil then
			dst[k] = v
		end
	end
	return dst
end

-- libDBIcon minimap helper
function lib:ToggleMinimapIcon(addonName, db)
	db.hide = not db.hide
	if db.hide then
		LibStub("LibDBIcon-1.0"):Hide(addonName)
	else
		LibStub("LibDBIcon-1.0"):Show(addonName)
	end
end

-- savedvariables initialization
function lib:LoadDatabase(svName)
	local sv = _G[svName]
	if not sv then sv = {}; _G[svName] = sv; end
	return lib:CopyTable(SV_DEFAULTS, sv)
end

--savedvariables profiles initialization
function lib:LoadProfile(svName, defaults, profileName)
	local sv = lib:LoadDatabase(svName)
	profileName = (profileName==true and 'Default') or profileName or sv.profileKeys[lib.charKey] or lib.charKey
	sv.profileKeys[lib.charKey] = profileName
	return sv.profiles[profileName], sv.global, sv
end

-- standard dispatch event function
function lib:DispatchEvent(event,...)
	self[event](self,event,...)
end

--============================================================
-- launcher icons register helper functions
-- lib:RegisterCompartment(addonName, addon, mouseClick)
-- lib:RegisterMinimapIcon(addonName, addon, db, mouseClick, showTooltip)
--============================================================

do
	local function call(func, self, arg1)
		if type(func)=='string' then
			self[func](self, arg1)
		elseif func then
			func(arg1)
		end
	end
	-- register compartment icon
	function lib:RegisterCompartment(addonName, addon, mouseClick)
		if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
			AddonCompartmentFrame:RegisterAddon({
				text = C_AddOns.GetAddOnInfo(addonName),
				icon = C_AddOns.GetAddOnMetadata(addonName, "IconTexture"),
				func = function(_,_,_,_,button) call(mouseClick, addon, button) end,
				registerForAnyClick = true,
				notCheckable = true,
			})
		end
	end
	-- register LibDBIcon
	function lib:RegisterMinimapIcon(addonName, addon, db, mouseClick, showTooltip)
		LibStub("LibDBIcon-1.0"):Register(addonName, LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
			type  = "launcher",
			label = C_AddOns.GetAddOnInfo(addonName),
			icon  = C_AddOns.GetAddOnMetadata(addonName, "IconTexture"),
			OnClick = function(_, button) call(mouseClick, addon, button) end,
			OnTooltipShow = function(tooltip) call(showTooltip, addon, tooltip) end,
		}) , db)
	end
end

--============================================================
--  dialogs
--============================================================

do
	StaticPopupDialogs["KIWIDISPLAYFRAME_DIALOG"] = { timeout = 0, whileDead = 1, hideOnEscape = 1, button1 = ACCEPT, button2 = CANCEL }

	function lib:ShowDialog(message, textDefault, funcAccept, funcCancel, textAccept, textCancel)
		local t = StaticPopupDialogs["KIWIDISPLAYFRAME_DIALOG"]
		t.OnShow = function (self) if textDefault then self.editBox:SetText(textDefault) end; self:SetFrameStrata("TOOLTIP") end
		t.OnHide = function(self) self:SetFrameStrata("DIALOG")	end
		t.hasEditBox = textDefault and true or nil
		t.text = message
		t.button1 = funcAccept and (textAccept or ACCEPT) or nil
		t.button2 = funcCancel and (textCancel or CANCEL) or nil
		t.OnCancel = funcCancel
		t.OnAccept = funcAccept and function (self)	funcAccept( textDefault and self.editBox:GetText() ) end or nil
		StaticPopup_Show("KIWIDISPLAYFRAME_DIALOG")
	end

	function lib:MessageDialog(message, funcAccept)
		lib:ShowDialog(message, nil, funcAccept or DUMMY)
	end

	function lib:ConfirmDialog(message, funcAccept, funcCancel, textAccept, textCancel)
		lib:ShowDialog(message, nil, funcAccept, funcCancel or DUMMY, textAccept, textCancel )
	end

	function lib:EditDialog(message, text, funcAccept, funcCancel)
		lib:ShowDialog(message, text or "", funcAccept, funcCancel or DUMMY)
	end
end

--============================================================
-- Create Frame Common
-- lib:CreateFrame(addonName)
--============================================================

do
	-- font set
	local function SetWidgetFont(widget, name, size)
		widget:SetFont(name or STANDARD_TEXT_FONT, size or FONT_SIZE_DEFAULT, 'OUTLINE')
		if not widget:GetFont() then
			widget:SetFont(STANDARD_TEXT_FONT, size or FONT_SIZE_DEFAULT, 'OUTLINE')
		end
	end

	-- Layout Rows
	local function LayoutRows(self)
		if self.dbframe.rowTexture then
			local sheight = self.textLeft:GetStringHeight()
			if sheight<=0 then C_Timer.After(0, function() LayoutRows(self) end); return end
			local rows_data = self.rows_data or {}
			local count = self.textLeft:GetNumLines()
			local spacing = self.dbframe.spacing
			local height = (sheight - (count-1)*spacing) / count
			local fheight = height + spacing
			local rows_count = math.floor( (self.textLeft:GetHeight()+spacing)/fheight + 0.01 )
			local margin = self.dbframe.frameMargin
			local color = self.dbframe.rowColor or ROW_COLOR_DEFAULT
			local texture = self.dbframe.rowTexture or ROW_TEXTURE_DEFAULT
			local offset = 0
			for i=1,rows_count do
				local row = rows_data[i] or self:CreateTexture(nil, "BACKGROUND")
				row:SetTexture(texture)
				row:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
				row:ClearAllPoints()
				row:SetPoint('TOPLEFT',   margin, -offset-margin)
				row:SetPoint('TOPRIGHT', -margin, -offset-margin)
				row:SetHeight(height)
				row:Show()
				offset = offset + fheight
				rows_data[i] = row
				i = i + 1
			end
			for i=rows_count+1,#rows_data do
				rows_data[i]:Hide()
			end
			self.rows_data = rows_data
		elseif self.rows_data then
			local rows, i = self.rows_data, 1
			while i<=#rows and rows[i]:IsVisible() do
				rows[i]:Hide()
				i = i + 1
			end
		end
	end

	-- layout main frame
	local function LayoutFrame(self)
		local config = self.dbframe
		local plugin = self.plugin
		local font, size = self:GetTextsFontInfo()
		-- background, border, strata
		self:SetBackdrop(nil)
		self:LayoutBackdrop()
		-- text left
		local textLeft = self.textLeft
		textLeft:ClearAllPoints()
		textLeft:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin)
		textLeft:SetJustifyH('LEFT')
		textLeft:SetJustifyV('TOP')
		textLeft:SetTextColor(1,1,1,1)
		textLeft:SetSpacing(config.spacing)
		SetWidgetFont(textLeft, font, size)
		textLeft:SetText('')
		-- display headers
		self:LayoutContent()
		-- text right
		local textRight = self.textRight
		textRight:ClearAllPoints()
		textRight:SetPoint('TOPRIGHT', -config.frameMargin, -config.frameMargin)
		textRight:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin)
		textRight:SetJustifyH('RIGHT')
		textRight:SetJustifyV('TOP')
		textRight:SetTextColor(1,1,1,1)
		textRight:SetSpacing(config.spacing)
		SetWidgetFont(textRight, font, size)
		textRight:SetText('')
		-- display content
		self:UpdateContent()
		-- adjust height
		self:UpdateContentSize()
		-- layout rows
		self:LayoutRows()
	end

	-- public method
	function lib:CreateFrame(name)
		local frame = CreateFrame('Frame', name, UIParent, BackdropTemplateMixin and "BackdropTemplate")
		frame:Hide()
		frame.ShowDialog = lib.ShowDialog
		frame.EditDialog = lib.EditDialog
		frame.ConfirmDialog = lib.ConfirmDialog
		frame.MessageDialog = lib.MessageDialog
		frame.ShowMenu = DUMMY
		frame.LayoutContent = DUMMY
		frame.Updatecontent = DUMMY
		frame.LayoutRows = LayoutRows
		frame.LayoutFrame = LayoutFrame
		frame.textLeft = frame:CreateFontString()
		frame.textRight = frame:CreateFontString()
		return frame
	end
end

--============================================================
-- Setup Standalone frame
-- lib:SetupFrame(db, frame)
--============================================================

do

	local function Script_OnMouseDown(self, button)
		if button == 'RightButton' then
			self:ShowMenu()
		end
	end

	-- frame script
	local function Script_OnDragStop(self)
		self:StopMovingOrSizing()
		self:SetUserPlaced(false)
		self:SavePosition()
		self:RestorePosition()
	end

	-- frame script
	local function UpdateFrameSize(self)
		local config = self.dbframe
		local width = config.frameWidth or 2/3
		self:SetHeight( self.textLeft:GetHeight() + config.frameMargin*2 )
		self:SetWidth( width>=1 and width or self.textLeft:GetWidth()/width+config.frameMargin*2 )
		self:SetScript("OnUpdate", nil)
	end

	-- frame method: restore main frame position
	local function RestorePosition(self)
		local config = self.dbframe
		self:ClearAllPoints()
		self:SetPoint( config.framePos.anchor, UIParent, 'CENTER', config.framePos.x, config.framePos.y )
	end

	-- frame method: save main frame position
	local function SavePosition(self)
		local p, cx, cy = self.dbframe.framePos, UIParent:GetCenter() -- we are assuming addon frame scale=1 in calculations
		local x = (p.anchor:find("LEFT")   and self:GetLeft())   or (p.anchor:find("RIGHT") and self:GetRight()) or self:GetLeft()+self:GetWidth()/2
		local y = (p.anchor:find("BOTTOM") and self:GetBottom()) or (p.anchor:find("TOP")   and self:GetTop())   or self:GetTop() -self:GetHeight()/2
		p.x, p.y = x-cx, y-cy
	end

	-- frame method: change frame visibility: nil == toggle visibility
	local function ToggleFrameVisibility(self, visible)
		if visible == nil then
			visible = not self:IsShown()
		end
		self:SetShown(visible)
		self.dbframe.visible = visible
	end

	-- frame method
	local function GetTextsFontInfo(self)
		return self.dbframe.fontName, self.dbframe.fontSize
	end

	-- frame method
	local function MouseClick(self, button)
		if button == 'RightButton' then
   			self:ShowMenu()
		else
			self:ToggleFrameVisibility()
		end
	end

	-- frame method
	local function LayoutBackdrop(self)
		local config = self.dbframe
		BACKDROP_CFG.edgeFile = config.borderTexture
		self:SetBackdrop( config.borderTexture and BACKDROP_CFG or BACKDROP_DEF )
		self:SetBackdropBorderColor( unpack(config.borderColor or COLOR_WHITE) )
		self:SetBackdropColor( unpack(config.backColor or COLOR_TRANSPARENT) )
		self:SetFrameStrata(config.frameStrata or 'MEDIUM')
	end

	-- frame method
	local function UpdateContentSize(self)
		self:SetScript("OnUpdate", UpdateFrameSize)
	end

	-- public method
	function lib:SetupFrame(frame, db)
		frame.dbframe = db or frame.dbframe
		frame.MouseClick = MouseClick
		frame.SavePosition = SavePosition
		frame.RestorePosition = RestorePosition
		frame.GetTextsFontInfo = GetTextsFontInfo
		frame.LayoutBackdrop = LayoutBackdrop
		frame.ToggleFrameVisibility = ToggleFrameVisibility
		frame.UpdateContentSize = UpdateContentSize
		frame:SetSize(1,1)
		frame:EnableMouse(true)
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnShow", frame.UpdateContent)
		frame:SetScript("OnMouseDown", Script_OnMouseDown)
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", Script_OnDragStop)
		frame:RestorePosition()
		frame:LayoutFrame()
		return true
	end

end

--============================================================
-- Setup Details Plugin frame
-- lib:SetupPlugin(frame, db, icon, description, version)
--============================================================

do
	-- frame method
	local function GetTextsFontInfo(self)
		local font = self.dbframe.fontName or media:Fetch("font", self.instance.row_info.font_face, true)
		local size = self.dbframe.fontSize or self.instance.row_info.font_size
		return font, size
	end

	-- frame method
	local function UpdateContentSize(self)
		local _, h = self.instance:GetSize()
		local th = h-self.dbframe.frameMargin*2
		self.textLeft:SetHeight(th)
		self.textRight:SetHeight(th)
	end

	-- frame script
	local function OnMouseDown(self, button)
		if button == 'LeftButton' or (button == 'RightButton' and IsShiftKeyDown()) then
			self:ShowMenu()
		else
			self.instance.windowSwitchButton:GetScript("OnMouseDown")(self.instance.windowSwitchButton, button)
		end
	end

	-- plugin method
	local function OnDetailsEvent(self, event, ...)
		local instance = self:GetPluginInstance()
		if instance and (event == "SHOW" or instance == select(1,...)) then
			self.Frame:SetSize(instance:GetSize())
			local frame = self.__kiwiFrame
			frame.instance = instance
			frame:SetFrameLevel(5)
			frame:LayoutFrame()
		end
	end

	-- public method
	function lib:SetupPlugin(addonName, self, db, icon, version, description, author)
		-- gather addon metadata
		icon = icon or C_AddOns.GetAddOnMetadata(addonName,"IconTexture")
		version = version or C_AddOns.GetAddOnMetadata(addonName, "Version")
		description = description or C_AddOns.GetAddOnMetadata(addonName, "Notes")
		author = author or C_AddOns.GetAddOnMetadata(addonName, "Author")
		-- access details addon
		local Details = _G.Details
		if not Details then
			print( string.format("%s warning: this addon is configured as a Details plugin but Details addon is not installed!", self:GetName()) )
			return
		end
		-- setup frame functions
		self.dbframe = db or self.dbframe
		self.LayoutBackdrop = DUMMY
		self.ToggleFrameVisibility = DUMMY
		self.MouseClick = self.ShowMenu
		self.GetTextsFontInfo = GetTextsFontInfo
		self.UpdateContentSize = UpdateContentSize
		self:SetScript("OnMouseDown", OnMouseDown)
		-- create&install details plugin
		local Plugin = Details:NewPluginObject("Details_"..self:GetName())
		Plugin:SetPluginDescription(description)
		self.plugin = Plugin
		Plugin.__kiwiFrame = self
		Plugin.OnDetailsEvent = OnDetailsEvent
		local install= Details:InstallPlugin("RAID", self:GetName(), icon, Plugin, "DETAILS_PLUGIN_"..strupper(self:GetName()), 1, author, version)
		if type(install) == "table" and install.error then
			print(install.error)
		end
		Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_ENDRESIZE")
		Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_SIZECHANGED")
		Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_STARTSTRETCH")
		Details:RegisterEvent(Plugin, "DETAILS_INSTANCE_ENDSTRETCH")
		Details:RegisterEvent(Plugin, "DETAILS_OPTIONS_MODIFIED")
		-- reparent frame to details frame
		self:Hide()
		self:SetParent(Plugin.Frame)
		self:ClearAllPoints()
		self:SetAllPoints()
		self:Show()
		return true
	end
end

--================================================================
-- Setup frame: Standalone or Details plugin
-- lib:SetupAddon(frame, db, plugin, icon, description, version)
--================================================================

function lib:SetupAddon(addonName, frame, db, plugin, ...)
	local installed
	if plugin then
		installed = lib:SetupPlugin(addonName, frame, db, ...)
	end
	if not installed then
		return lib:SetupFrame(frame, db)
	end
end
