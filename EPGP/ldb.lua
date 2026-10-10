local mod = EPGP:NewModule("ldb")

local L = LibStub:GetLibrary("AceLocale-3.0"):GetLocale("EPGP")

local MINIMAP_ICON = "Interface\\Icons\\INV_Misc_Note_01"

mod.dbDefaults = {
  profile = {
    enabled = true,
    hideMinimap = false,
  },
  global = {
    minimapAngle = 225,
  },
}

local function AddLauncherTooltip(tooltip)
  tooltip:AddLine("EPGP "..(EPGP.version or ""))
  tooltip:AddLine(" ")
  tooltip:AddLine(L["Left-click to toggle the EPGP standings"], 0, 1, 0)
  tooltip:AddLine(L["Right-click to open the EPGP config"], 0, 1, 0)
  tooltip:AddLine(" ")
  local status = string.format(
    L["Decay=%s%% BaseGP=%s MinEP=%s Extras=%s%%"],
    "|cFFFFFFFF"..EPGP:GetDecayPercent().."|r",
    "|cFFFFFFFF"..EPGP:GetBaseGP().."|r",
    "|cFFFFFFFF"..EPGP:GetMinEP().."|r",
    "|cFFFFFFFF"..EPGP:GetExtrasPercent().."|r")
  local lines = {strsplit(" ", status)}
  for _, line in pairs(lines) do
    tooltip:AddLine(line)
  end
end

local function OpenEPGP()
  EPGP:ToggleUI()
end

local function OpenConfig()
  -- The first call only opens the frame on 3.3.5; the second selects EPGP.
  InterfaceOptionsFrame_OpenToCategory("EPGP")
  InterfaceOptionsFrame_OpenToCategory("EPGP")
end

local function UpdateMinimapButton(button)
  local angle = mod.db.global.minimapAngle or 225
  local radius = (Minimap:GetWidth() / 2) + 5
  local rad = math.rad(angle)
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER",
                  math.cos(rad) * radius, math.sin(rad) * radius)
end

local function CreateMinimapButton()
  if mod.minimapButton then return end

  local button = CreateFrame("Button", "EPGPMinimapButton", Minimap)
  button:SetWidth(31)
  button:SetHeight(31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")

  local overlay = button:CreateTexture(nil, "OVERLAY")
  overlay:SetWidth(53)
  overlay:SetHeight(53)
  overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlay:SetPoint("TOPLEFT")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetTexture(MINIMAP_ICON)
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("CENTER", button, "CENTER", 0, 1)

  button:SetScript("OnClick", function(self, mouseButton)
    if self.wasDragged then
      self.wasDragged = nil
      return
    end
    if mouseButton == "LeftButton" then
      OpenEPGP()
    else
      OpenConfig()
    end
  end)

  button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      cx, cy = cx / scale, cy / scale
      mod.db.global.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
      self.wasDragged = true
      UpdateMinimapButton(self)
    end)
  end)

  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    AddLauncherTooltip(GameTooltip)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  UpdateMinimapButton(button)
  mod.minimapButton = button
end

function mod:StopRecurringAward()
  if self.ldb then
    self.ldb.text = L["Idle"]
  end
end

function mod:RecurringAwardUpdate(event_type, reason, amount, time_left)
  if not self.ldb then return end
  local fmt, val = SecondsToTimeAbbrev(time_left)
  self.ldb.text = string.format(L["Next award in "] .. fmt, val)
end

function mod:OnEnable()
  local LDB = LibStub("LibDataBroker-1.1")
  if LDB and not self.ldb then
    self.ldb = LDB:NewDataObject(
      "epgp",
      {
        type = "data source",
        text = L["Idle"],
        label = "EPGP",
        icon = MINIMAP_ICON,
        OnClick =
          function(_, button)
            if button == "LeftButton" then
              OpenEPGP()
            else
              OpenConfig()
            end
          end,
        OnTooltipShow = AddLauncherTooltip,
      })

    EPGP.RegisterCallback(mod, "StopRecurringAward")
    EPGP.RegisterCallback(mod, "RecurringAwardUpdate")
  end

  self:UpdateMinimapVisibility()
end

function mod:UpdateMinimapVisibility()
  if self:IsEnabled() and not self.db.profile.hideMinimap then
    CreateMinimapButton()
    self.minimapButton:Show()
  elseif self.minimapButton then
    self.minimapButton:Hide()
  end
end

function mod:OnDisable()
  if self.minimapButton then
    self.minimapButton:Hide()
  end
end
