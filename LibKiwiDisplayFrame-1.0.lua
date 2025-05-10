-- ============================================================================
-- LibKiwiDisplayFrame-1.0 (C) 2025 MiCHaEL
-- Display frame code and helper functions for Kiwi addons
-- Display frame can be created as a Details plugin
-- ============================================================================

local _, addonTbl = ...

local lib = LibStub:NewLibrary("LibKiwiDisplayFrame-1.0", 1)
if not lib then return end

local media = LibStub("LibSharedMedia-3.0", true)

-- local references
local _G = _G
local type = type
local next = next
local print = print
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local select = select

-- locale table
local L = setmetatable( {}, { __index = function(t,k) return k; end } )
lib.L = L

-- default values
local DUMMY = function() end
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
--  Database defaults
--============================================================

lib.defaults = {
	visible = true,
	backColor = {0,0,0,.5},
	borderColor = {1,1,1,1},
	borderTexture = nil,
	rowColor = nil,
	rowColor2 = nil,
	rowTexture = nil,
	spacing = 1,
	fontName = nil,
	fontSize = nil,
	frameWidth = 2/3,
	frameMargin = 4,
	frameStrata = nil,
	framePos = {anchor='TOPLEFT', x=0, y=0},
}

--============================================================
--  Misc functions
--============================================================

-- table management fucntions
do
	local recurse, overwrite
	local function CopyTable(src, dst)
		if type(dst)~="table" then dst = {} end
		for k,v in pairs(src) do
			if recurse and type(v)=="table" then -- tables are always overwritten
				dst[k] = CopyTable(v,dst[k])
				elseif overwrite or dst[k]==nil then
				dst[k] = v
			end
		end
		return dst
	end
	-- copy table
	function lib:CopyTable(src, dst, nrecurse, noverwrite)
		recurse, overwrite = not nrecurse, not noverwrite
		return CopyTable(src, dst)
	end
	-- copy defaults, avoid ovewriting values in dest table
	function lib:CopyDefaults(src, dst, key)
		if key then
			dst[key] = dst[key] or {}
			dst = dst[key]
		end
		if not src then return dst or {} end
		recurse, overwrite = true, false
		return CopyTable(src, dst)
	end
	-- create nested table fields, ex: lib:SetTableValue(t,'a','b',{c=1}) => (t.a.b.c==1)
	function lib:SetTableValue(db, ...)
		for i=1,select('#',...)-2 do
			local k = select(i,...)
			db[k] = db[k] or {}
			db = db[k]
		end
		db[select(-2,...)] = select(-1,...)
	end
end

-- savedvariables and sections database management
do
	function lib:SetSavedVariables(sv, svDefaults)
		return type(sv)=='string' and lib:CopyDefaults(svDefaults, _G, sv) or sv
	end

	function lib:SetDatabaseProfile(db, pfDefaults, pfName, skipKeys, svDefaults)
		if not (type(db)=='table' and db.__iskdb) then
			db = { sv = lib:SetSavedVariables(db, svDefaults), __iskdb = true }
		end
		local sv = db.sv
		sv.profiles = sv.profiles or {}
		if type(pfName)~='string' then
			if sv.profileKeys and sv.profileKeys[lib.charKey] then -- load char profile specified in profileKeys only if exists
				pfName = lib.charKey
			elseif pfName==false then -- load charKey profile only if exists, create/load default otherwise
				pfName = sv.profiles[lib.charKey] and lib.charKey or 'Default'
			else -- pfName==true: Default profile | pfName==nil: charKey profile
				pfName = pfName=='true' and 'Default' or lib.charKey
			end
		elseif not skipKeys then
			lib:SetTableValue(sv, 'profileKeys', lib.charKey, pfName)
		end
		db.pfName = pfName
		db.profile = lib:CopyDefaults(pfDefaults, sv.profiles, pfName)
		return db, db.profile, pfName
	end

	function lib:GetDatabaseProfiles(db, svDefaults)
		local sv = db.__iskdb and db.sv or sv
		return sv.profiles or {}
	end

	function lib:DelDatabaseProfile(db, pfName)
		local sv = db.__iskdb and db.sv or sv
		sv.profiles[pfName] = nil
	end

	function lib:SetDatabaseSection(db, ...)
		db = db.__iskdb and db.sv or db
		local k, i = select(1,...), 1
		while type(k)=='string' do
			db[k] = db[k] or {}
			db = db[k]
			i = i + 1
			k = select(i,...)
		end
		return lib:CopyDefaults(k,db)
	end
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

-- standard dispatch event function
function lib:DispatchEvent(event,...)
	self[event](self,event,...)
end

--============================================================
-- Locale info
--============================================================

function lib:GetLocale()
	return L, GetLocale()
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
	function lib:RegisterCompartment(addon, mouseClick)
		if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
			local addonName = addon.addonName
			mouseClick = mouseClick or "MouseClick"
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
	function lib:RegisterMinimapIcon(addon, db, mouseClick, showTooltip)
		local addonName = addon.addonName
		addon.minimapIcon = db
		mouseClick = mouseClick or "MouseClick"
		showTooltip = showTooltip or "ShowTooltip"
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

	-- show tooltip
	local function ShowTooltip(self, tooltip)
		tooltip:AddDoubleLine(self.addonName, C_AddOns.GetAddOnMetadata(self.addonName, "Version"))
		if self.plugin then
			tooltip:AddLine(self.L["|cFFff4040Left or Right Click|r to open menu"], 0.2, 1, 0.2)
		else
			tooltip:AddLine(self.L["|cFFff4040Left Click|r toggle visibility\n|cFFff4040Right Click|r open menu"], 0.2, 1, 0.2)
		end
	end

	-- layout rows
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
			local color1 = self.dbframe.rowColor or ROW_COLOR_DEFAULT
			local color2 = self.dbframe.rowColor2 or ROW_COLOR_DEFAULT
			local texture = self.dbframe.rowTexture or ROW_TEXTURE_DEFAULT
			local offset = -margin
			for i=1,rows_count do
				local color = (i%2==1) and color1 or color2
				local row = rows_data[i] or self:CreateTexture(nil, "BACKGROUND")
				row:SetTexture(texture)
				row:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
				row:ClearAllPoints()
				row:SetPoint('TOPLEFT',   margin, offset)
				row:SetPoint('TOPRIGHT', -margin, offset)
				row:SetHeight( fheight - 1 )
				row:Show()
				offset = offset - fheight
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
		textLeft:SetPoint('TOPLEFT', config.frameMargin, -config.frameMargin-config.spacing/2)
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
		textRight:SetPoint('TOPRIGHT', -config.frameMargin, -config.frameMargin-config.spacing/2)
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
	function lib:CreateFrame(name, embed)
		local frame = CreateFrame('Frame', name, UIParent, BackdropTemplateMixin and "BackdropTemplate")
		frame:Hide()
		frame.addonName = name
		frame.menuMain = lib.menuMain
		frame.ShowDialog = lib.ShowDialog
		frame.EditDialog = lib.EditDialog
		frame.ConfirmDialog = lib.ConfirmDialog
		frame.MessageDialog = lib.MessageDialog
		frame.ShowMenu = lib.ShowMenu
		frame.ShowTooltip = ShowTooltip
		frame.LayoutRows = LayoutRows
		frame.LayoutFrame = LayoutFrame
		frame.LayoutContent = DUMMY
		frame.Updatecontent = DUMMY
		frame.textLeft = frame:CreateFontString()
		frame.textRight = frame:CreateFontString()
		frame.L = L
		lib:CopyTable(embed, frame, true)
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
	function lib:SetupPlugin(self, db, icon, version, description, author)
		local addonName = self.addonName
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

function lib:SetupAddon(frame, db, plugin, ...)
	local installed
	if plugin then
		installed = lib:SetupPlugin(frame, db, ...)
	end
	if not installed then
		return lib:SetupFrame(frame, db)
	end
end

--================================================================
-- Popup Menu definition:
-- lib:ShowMenu()
--================================================================

do
	local lkm
	-- references  current opened submenu data
	local frame, db
	-- here starts the definition of the KiwiFrame menu
	local function cfgWidth(info)
		db.frameWidth = info.value~=0 and math.max(frame:GetWidth()+info.value, 50) or frame.defaults.frameWidth
		frame:LayoutFrame()
	end
	local function cfgMargin(info)
		db.frameMargin = info.value~=0 and math.max( (db.frameMargin or 4) + info.value, 0) or 4
		frame:LayoutFrame()
	end
	local function cfgSpacing(info)
		db.spacing = info.value~=0 and math.max( db.spacing + info.value, 0) or 1
		frame.textLeft:SetText('')
		frame.textRight:SetText('')
		frame:LayoutFrame()
		frame:UpdateContent()
	end
	local function cfgFontSize(info)
		local font, size = frame:GetTextsFontInfo()
		db.fontSize = info.value~=0 and math.max( (size or FONT_SIZE_DEFAULT) + info.value, 5) or nil
		frame:LayoutFrame()
	end
	local function cfgStrata(info,_,_,checked)
		if checked==nil then return info.value == (db.frameStrata or 'MEDIUM') end
		db.frameStrata = info.value~='MEDIUM' and info.value or nil
		frame:LayoutFrame()
	end
	local function cfgAnchor(info,_,_,checked)
		if checked==nil then return info.value == db.framePos.anchor end
		db.framePos.anchor = info.value
		frame:SavePosition()
		frame:RestorePosition()
	end
	local function cfgFont(info,_,_,checked)
		if checked==nil then return info.value == (db.fontName or '') end
		db.fontName = info.value~='' and info.value or nil
		frame:LayoutFrame()
		lkm:refreshMenu()
	end
	local function cfgBorder(info,_,_,checked)
		if checked==nil then return info.value == (db.borderTexture or '') end
		db.borderTexture = info.value~='' and info.value or nil
		frame:LayoutFrame()
		lkm:refreshMenu()
	end
	local function cfgRowTexture(info,_,_,checked)
		if checked==nil then return info.value == (db.rowTexture or '') end
		db.rowTexture = info.value~='' and info.value or nil
		frame:LayoutFrame()
		lkm:refreshMenu()
	end
	local function cfgColor(info, ...)
		if select('#',...)==0 then return unpack( db[info.value] or ROW_COLOR_DEFAULT ) end
		db[info.value] = {...}
		frame:LayoutFrame()
	end
	local function isPlugin()
		return frame.plugin~=nil
	end
	-- submenu size
	local menuSize = {
		{ text = L['Higher (+)'],   value =  1 },
		{ text = L['Smaller (-)'],  value = -1 },
		{ text = L['Default'],      value =  0 },
	}
	-- menu main
	lib.menuMain = {
		{ text = L['Frame Strata'], hidden = isPlugin, default = { cf = cfgStrata, isNotRadio = false }, menuList = {
			{ text = L['HIGH'],    value = 'HIGH',   },
			{ text = L['MEDIUM'],  value = 'MEDIUM', },
			{ text = L['LOW'],     value = 'LOW',  	 },
		} },
		{ text = L['Frame Anchor'], hidden = isPlugin, default = { cf = cfgAnchor, isNotRadio = false }, menuList = {
			{ text = L['TOPLEFT'],     value = 'TOPLEFT',     },
			{ text = L['TOPRIGHT'],    value = 'TOPRIGHT',    },
			{ text = L['BOTTOMLEFT'],  value = 'BOTTOMLEFT',  },
			{ text = L['BOTTOMRIGHT'], value = 'BOTTOMRIGHT', },
			{ text = L['LEFT'],   	   value = 'LEFT',        },
			{ text = L['RIGHT'],  	   value = 'RIGHT',       },
			{ text = L['TOP'],    	   value = 'TOP',         },
			{ text = L['BOTTOM'], 	   value = 'BOTTOM',      },
			{ text = L['CENTER'], 	   value = 'CENTER',      },
		} },
		{ text = L['Frame Width'],  hidden = isPlugin, default = { func = cfgWidth, keepShownOnClick = 1 }, menuList = lib:CopyTable(menuSize) },
		{ text = L['Frame Border'], hidden = isPlugin, menuList = {
			{ text = L['Border Texture'], menuList = function() return lkm:defMediaMenu('border', cfgBorder) end },
			{ text = L['Border Color '],  hasColorSwatch = true, hasOpacity = true, value = 'borderColor', get = cfgColor, set = cfgColor },
		} },
		{ text = L['Frame Back'], hidden = isPlugin, menuList = {
			{ text = L['Background color '], hasColorSwatch = true, hasOpacity = true, value = 'backColor', get = cfgColor, set = cfgColor },
		} },
		{ text = L['Text Margin'],  default = { func = cfgMargin,   keepShownOnClick = 1 }, menuList = lib:CopyTable(menuSize) },
		{ text = L['Text Spacing'], default = { func = cfgSpacing,  keepShownOnClick = 1 }, menuList = lib:CopyTable(menuSize) },
		{ text = L['Text Size'],    default = { func = cfgFontSize, keepShownOnClick = 1 }, menuList = lib:CopyTable(menuSize) },
		{ text = L['Text Font'], menuList = function() return lkm:defMediaMenu('font', cfgFont, {[L['[Default]']] = ''}) end },
		{ text = L['Text Bars'], menuList = {
			{ text = L['Bars Texture'], menuList = function() return lkm:defMediaMenu('statusbar', cfgRowTexture, {[L['[None]']] = ''}) end },
			{ text = L['Odd Bars Color'],   hasColorSwatch = true, hasOpacity = true, value = 'rowColor', get = cfgColor, set = cfgColor },
			{ text = L['Even Bars Color'],   hasColorSwatch = true, hasOpacity = true, value = 'rowColor2', get = cfgColor, set = cfgColor },
		} },
	}
	-- show menu, this is embeded in created frames
	function lib:ShowMenu()
		lkm = lkm or LibStub("LibKiwiDropDownMenu-1.0", true)
		frame, db = self, self.dbframe
		lkm:showMenu(self.menuMain or lib.menuMain, self.addonName .. "PopupMenu", "cursor", 0 , 0, 2)
	end
end
