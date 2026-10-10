local mod = LootMaster:NewModule("EPGPLootmaster_Options")

--local LootMasterML = false

function mod:OnEnable()
  local options = {
    name = "EPGPLootMaster — Sixset, Ghost of Azeroth",
    type = "group",
    get = function(i) return LootMaster.db.profile[i[#i]] end,
    set = function(i, v) LootMaster.db.profile[i[#i]] = v end,
    args = {
        
        global = {
            order = 1,
            type = "group",
            hidden = function(info) return not LootMasterML end,
            name = "Загальні налаштування",
            
                args = {
                
                help = {
                    order = 0,
                    type = "description",
                    name = "EPGPLootMaster створено для розподілу здобичі за системою EP/GP. Цей аддон допомагає швидко і з меншою кількістю помилок роздавати здобич у системі EP/GP.",
                },
                
                
                
                no_ml = {
                    order = 2,
                    type = "description",
                    hidden = function(info) return LootMasterML end,
                    name = "\r\n\r\n|cFFFF8080WARNING: Alot of settings have been hidden because the EPGPLootmaster 'ML' module has been disabled. Please enabled it from the addon configuration screen.|r",
                },
                
                config_group = {
                    order = 12,
                    type = "group",
                    guiInline = true,
                    hidden = function(info) return not LootMasterML end,
                    name = "General config",
                    args = {
                        
                        use_epgplootmaster = {
                            order = 2,
                            type = "select",
			                width = "double",
                            set = function(i, v) 
                                LootMaster.db.profile.use_epgplootmaster = v;
                                if v == 'enabled' then
                                    LootMasterML:EnableTracking();
                                elseif v == 'disabled' then
                                    LootMasterML:DisableTracking();
                                else
                                    LootMasterML.current_ml = nil;
                                    LootMasterML:GROUP_UPDATE();
                                end                               
                                
                            end,
                            name = "Використання EPGPLootmaster",
                            desc = "Увімкнути EPGPLootmaster чи ні.",
                            values = {
                                ['enabled'] = 'Завжди використовувати EPGPLootmaster',
                                ['disabled'] = 'Ніколи не використовувати EPGPLootmaster',
                                ['ask'] = 'Питати щоразу'
                            },
                        },
                        
                        loot_timeout = {
                            order = 14,
                            type = "select",
			                width = "double",
                            name = "Час розподілу здобичі",
                            desc = "Скільки часу гравці мають на голосування.",
                            values = {
                                [0] = 'No timeout',
                                [10] = '10 секунд',
                                [15] = '15 секунд',
                                [20] = '20 секунд',
                                [30] = '30 секунд',
                                [40] = '40 секунд',
                                [50] = '50 секунд',
                                [60] = '1 хвилина',
                                [90] = '1 хв. 30 сек.',
                                [150] = '2 хв. 30 сек.',
                                [300] = '5 хвилин',
                            },
                        }, 
                        
                        --[[defaultMainspecGP = {
                            order = 15.1,
                            type = "input",                    
                            name = "Default mainspec GP",
                            desc = "Fill this field to override the GP value for mainspec loot.",
                            width = 'normal',
                            validate = function(data, value) if value=='' then return true end; if not strmatch(value, '^%s*%d+%s-%%?%s*$') then return false else return true end end,
                            set = function(i, v) 
                                
                                if v == '' or not v then
                                    v = ''
                                    LootMaster.db.profile.defaultMainspecGPPercentage = false;
                                    LootMaster.db.profile.defaultMainspecGPValue = nil;
                                else
                                    value, perc = strmatch(v, '^%s*(%d+)%s-(%%?)%s*$')
                                    LootMaster.db.profile.defaultMainspecGPPercentage = (perc~=nil and perc~='');
                                    LootMaster.db.profile.defaultMainspecGPValue = tonumber(value);
                                end                               
                                LootMaster.db.profile.defaultMainspecGP = v;
                            end,
                            usage = "\r\nEmpty: use normal GP value"..
                                    "\r\n50%: use 50% of normal GP value"..
                                    "\r\n25: all items are worth 25 GP"
                        },
                        
                        defaultMinorUpgradeGP = {
                            order = 15.2,
                            type = "input",                    
                            name = "Default minor upgrade GP",
                            desc = "Fill this field to override the GP value for minor upgrade mainspec loot.",
                            width = 'normal',
                            validate = function(data, value) if value=='' then return true end; if not strmatch(value, '^%s*%d+%s-%%?%s*$') then return false else return true end end,
                            set = function(i, v) 
                                
                                if v == '' or not v then
                                    v = ''
                                    LootMaster.db.profile.defaultMinorUpgradeGPPercentage = false;
                                    LootMaster.db.profile.defaultMinorUpgradeGPValue = nil;
                                else
                                    value, perc = strmatch(v, '^%s*(%d+)%s-(%%?)%s*$')
                                    LootMaster.db.profile.defaultMinorUpgradeGPPercentage = (perc~=nil and perc~='');
                                    LootMaster.db.profile.defaultMinorUpgradeGPValue = tonumber(value);
                                end                               
                                LootMaster.db.profile.defaultMinorUpgradeGP = v;
                            end,
                            usage = "\r\nEmpty: use normal GP value"..
                                    "\r\n50%: use 50% of normal GP value"..
                                    "\r\n25: all items are worth 25 GP"
                        },
                        
                        defaultOffspecGP = {
                            order = 15.3,
                            type = "input",                    
                            name = "Default offspec GP",
                            desc = "Fill this field to override the GP value for offspec loot.",
                            width = 'normal',
                            validate = function(data, value) if value=='' then return true end; if not strmatch(value, '^%s*%d+%s-%%?%s*$') then return false else return true end end,
                            set = function(i, v) 
                                
                                if v == '' or not v then
                                    v = ''
                                    LootMaster.db.profile.defaultOffspecGPPercentage = false;
                                    LootMaster.db.profile.defaultOffspecGPValue = nil;
                                else
                                    value, perc = strmatch(v, '^%s*(%d+)%s-(%%?)%s*$')
                                    LootMaster.db.profile.defaultOffspecGPPercentage = (perc~=nil and perc~='');
                                    LootMaster.db.profile.defaultOffspecGPValue = tonumber(value);
                                end                               
                                LootMaster.db.profile.defaultOffspecGP = v;
                            end,
                            usage = "\r\nEmpty: use normal GP value"..
                                    "\r\n50%: use 50% of normal GP value"..
                                    "\r\n25: all items are worth 25 GP"
                        },
                        
                        defaultGreedGP = {
                            order = 15.4,
                            type = "input",                    
                            name = "Default greed GP",
                            desc = "Fill this field to override the GP value for greed loot.",
                            width = 'normal',
                            validate = function(data, value) if value=='' then return true end; if not strmatch(value, '^%s*%d+%s-%%?%s*$') then return false else return true end end,
                            set = function(i, v) 
                                
                                if v == '' or not v then
                                    v = ''
                                    LootMaster.db.profile.defaultGreedGPPercentage = false;
                                    LootMaster.db.profile.defaultGreedGPValue = nil;
                                else
                                    value, perc = strmatch(v, '^%s*(%d+)%s-(%%?)%s*$')
                                    LootMaster.db.profile.defaultGreedGPPercentage = (perc~=nil and perc~='');
                                    LootMaster.db.profile.defaultGreedGPValue = tonumber(value);
                                end                               
                                LootMaster.db.profile.defaultGreedGP = v;
                            end,
                            usage = "\r\nEmpty: use normal GP value"..
                                    "\r\n50%: use 50% of normal GP value"..
                                    "\r\n25: all items are worth 25 GP"
                        },]]
                        
                        ignoreResponseCorrections = {
                            type = "toggle",
                            order = 17,
                            width = 'full',
                            name = "Приймати лише першу примітку до предмета.",
                            desc = "Зазвичай кандидати можуть надіслати кілька особистих повідомлень під час розподілу здобичі з боса, щоб змінити вибір. Наприклад, спочатку обрали основний спек, а потім вирішили змінити на невелике покращення, щоб річ дісталась тому, кому вона потрібніша. Якщо увімкнути цю функцію, зарахується лише перша відповідь.",
                        },
                        
                        allowCandidateNotes = {
                            type = "toggle",
                            order = 18,
                            width = 'full',
                            name = "Дозволити кандидатам додавати примітки до кожного предмета.",
                            desc = "Увімкніть, якщо хочете, щоб кандидати надсилали вам примітки. Примітка показується значком у вікні розподілу здобичі. Зніміть галочку, якщо це сповільнює розподіл.",
                        },
                        
                        filterEPGPLootmasterMessages = {
                            type = "toggle",
                            order = 19,
                            width = 'full',
                            name = "Фільтрувати особисті повідомлення про здобич.",
                            desc = "EPGPLootmaster можуть користуватися навіть ті, у кого його немає. Вони можуть шепнути Основний спек/Невелике покращення/Другий спек, і це піде в рейд. Увімкніть фільтрацію таких повідомлень.",
                        },
                        
                        audioWarningOnSelection = {
                            type = "toggle",
                            order = 20,
                            width = 'full',
                            name = "Програвати звукове попередження на початку розподілу здобичі.",
                            desc = "Програє звук, коли відкривається вибір здобичі і потрібна ваша відповідь.",
                        },
                    }
                },
                
                buttons_group = {
                    order = 12.5,
                    type = "group",
                    guiInline = true,
                    hidden = function(info) return not LootMasterML end,
                    name = "Кнопки вибору",
                    args = {
                        
                        help = {
                            order = 0,
                            type = "description",
                            name = "Тут налаштовуються кнопки вибору на екранах рейдерів. Переконайтеся, що кнопки відповідають значенням сортування нижче. Оберіть кількість кнопок, колір і відсоток.",
                        },
                        
                        buttonNum = {
                            type = "range",
                            width = 'full',
                            order = 1,
                            name = "Кількість кнопок розподілу здобичі:",
                            min = 1,
                            max = EPGPLM_MAX_BUTTONS,
                            step = 1,
                            desc = "Скільки кнопок показувати під час розподілу. Потрібна щонайменше одна кнопка; кнопка відмови завжди увімкнена.",
                        },
                        
                        
                        button1 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 1 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.1,
                            name = "button1",
                            desc = "Configure this selection button.",
                        },
                        
                        button2 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 2 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.2,
                            name = "button2",
                            desc = "Configure this selection button.",
                        },
                        
                        button3 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 3 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.3,
                            name = "button3",
                            desc = "Configure this selection button.",
                        },
                        
                        button4 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 4 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.4,
                            name = "button4",
                            desc = "Configure this selection button.",
                        },
                        
                        button5 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 5 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.5,
                            name = "button5",
                            desc = "Configure this selection button.",
                        },
                        
                        button6 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 6 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.6,
                            name = "button6",
                            desc = "Configure this selection button.",
                        },
                        
                        button7 = {
                            type = "input",
                            width = 'full',
                            hidden = function(info) return LootMaster.db.profile.buttonNum < 7 end,
                            dialogControl = "EPGPLMButtonConfigWidget",
                            order = 1.7,
                            name = "button7",
                            desc = "Configure this selection button.",
                        },
                        
                        btnTestPopup = {
                            order = 3,
                            type = "execute",
                            width = 'full',
                            name = "Відкрити тестове вікно розподілу здобичі",
                            desc = "Відкриває тестове вікно, щоб побачити, як це виглядає в клієнтів. Після тесту натисніть кнопку закриття.",
                            func = function()
                                local lootLink
                                for i=1, 20 do
                                  lootLink = GetInventoryItemLink("player", i)
                                  if lootLink then break end
                                end
                                if not lootLink then return end
                                
                                ml = LootMasterML        
                                local loot = ml:GetLoot(lootLink)
                                local added = false
                                if not loot then
                                    local lootID = ml:AddLoot(lootLink, true)
                                    loot = ml:GetLoot(lootID)
                                    loot.announced = false
                                    loot.manual = true
                                    added = true
                                end
                                if not loot then return self:Print('Unable to register loot.') end          
                                ml:AddCandidate(loot.id, UnitName('player'))
                                ml:AnnounceLoot(loot.id)
                                for i=1, LootMaster.db.profile.buttonNum do
                                  ml:AddCandidate(loot.id, 'Button ' .. i)
                                  ml:SetCandidateResponse(loot.id, 'Button ' .. i, LootMaster.RESPONSE['button'..i], true)
                                end
                                ml:ReloadMLTableForLoot(loot.link)
                            end
                        },
                    },
                },
                
                auto_hiding_group = {
                    order = 13,
                    type = "group",
                    guiInline = true,
                    hidden = function(info) return not LootMasterML end,
                    name = "Автоприховування здобичі",
                    args = {
                        
                        help = {
                            order = 0,
                            type = "description",
                            name = "Керує автоматичним приховуванням вікон EPGPLootmaster.",
                        },
                                
                        hideOnSelection = {
                            type = "toggle",
                            order = 16,
                            width = 'full',
                            name = "Ховати вікно розподілу здобичі, коли відкривається голосування.",
                            desc = "Автоматично ховає основне вікно розподілу, коли вам треба проголосувати за здобич.",
                        },
                        
                        hideMLOnCombat = {
                            type = "toggle",
                            order = 17,
                            width = 'full',
                            name = "Ховає розподіл здобичі під час бою.",
                            desc = "Автоматично ховає вікно розподілу здобичі, коли ви входите в бій, і відкриває його знову після бою.",
                        },
                        
                        hideSelectionOnCombat = {
                            type = "toggle",
                            order = 18,
                            width = 'full',
                            name = "Ховає голосування за здобич під час бою.",
                            desc = "Автоматично ховає вікно голосування, коли ви входите в бій, і відкриває його знову після бою.",
                        },
                    },
                },
                
                auto_announce_group = {
                    order = 14,
                    type = "group",
                    guiInline = true,
                    hidden = function(info) return not LootMasterML end,
                    name = "Автоматичне оголошення",
                    args = {
                        
                        help = {
                            order = 0,
                            type = "description",
                            name = "EPGP Lootmaster автоматично оголошує про розподіл здобичі.",
                        },
                                
                        auto_announce_threshold = {
                            order = 13,
                            type = "select",
                            width = 'full',
                            hidden = function(info) return not LootMasterML end,
                            name = "Поріг автоматичного оголошення",
                            desc = "Якість, починаючи з якої розподіл автоматично оголошується рейду. Усе цієї якості або вище оголошується само.",
                            values = {
                                [0] = 'Never auto announce',
                                [2] = ITEM_QUALITY2_DESC,
                                [3] = ITEM_QUALITY3_DESC,
                                [4] = ITEM_QUALITY4_DESC,
                                [5] = ITEM_QUALITY5_DESC,
                            },
                        },
                    },
                },
                
                
                AutoLootGroup = {
            
                            type = "group",
                            order = 16,
                            guiInline = true,
                            name = "Автоматична здобич",
                            desc = "Auto looting of items",
                            hidden = function(info) return not LootMasterML end,
                            args = {
                                
                                help = {
                                    order = 0,
                                    type = "description",
                                    name = "EPGP Lootmaster може автоматично віддавати певні предмети BoU і BoE обраному кандидату без запитань.",
                                },
                                
                                AutoLootThreshold = {
                                    order = 1,
                                    type = "select",
                                    width = 'full',
                                    hidden = function(info) return not LootMasterML end,
                                    name = "Поріг автоматичного розподілу (лише BoE і BoU)",
                                    desc = "Будь-який предмет BoE або BoU цієї якості або нижче автоматично віддається кандидату нижче.",
                                    values = {
                                        [0] = 'Never auto loot',
                                        [2] = ITEM_QUALITY2_DESC,
                                        [3] = ITEM_QUALITY3_DESC,
                                        [4] = ITEM_QUALITY4_DESC,
                                        [5] = ITEM_QUALITY5_DESC,
                                    },
                                },
                                
                                AutoLooter = {
                                    type = "select",
                                    style = 'dropdown',
                                    order = 2,
                                    width = 'full',
                                    name = "Ім'я кандидата за замовчуванням (з урахуванням регістру):",
                                    desc = "Введіть ім'я кандидата, який за замовчуванням отримує предмети BoE і BoU.",
                                    disabled = function(info) return (LootMaster.db.profile.AutoLootThreshold or 0)==0 end,
                                    values = function()
                                        local names = {}
                                        local name;
                                        local num = GetNumRaidMembers()
                                        if num>0 then
                                            -- we're in raid
                                            for i=1, num do 
                                                name = GetRaidRosterInfo(i)
                                                names[name] = name
                                            end
                                        else
                                            num = GetNumPartyMembers()
                                            if num>0 then
                                                -- we're in party
                                                for i=1, num do 
                                                    names[UnitName('party'..i)] = UnitName('party'..i)
                                                end
                                                names[UnitName('player')] = UnitName('player')
                                            else
                                                -- Just show everyone in guild.
                                                local num = GetNumGuildMembers(true);
                                                for i=1, num do repeat
                                                    name = GetGuildRosterInfo(i)
                                                    names[name] = name
                                                until true end     
                                            end                                   
                                        end
                                        sort(names)
                                        return names;
                                    end
                                },
                            }
                },
            
        
        
                MonitorGroup = {
                            type = "group",
                            order = 17,
                            guiInline = true,
                            hidden = function(info) return not LootMasterML end,
                            name = "контроль",
                            desc = "Надсилайте й отримуйте повідомлення контролю від рейд-лідера і дивіться, що обрав інший рейдер.",
                            args = {
                                
                                help = {
                                    order = 0,
                                    type = "description",
                                    name = "EPGP Lootmaster може показувати іншим учасникам рейду те саме вікно розподілу, що й рейд-лідеру, щоб вони допомагали роздавати здобич.",
                                },
                
                                monitor = {
                                    type = "toggle",
                                    set = function(i, v)
                                        LootMaster.db.profile[i[#i]] = v;
                                        if LootMasterML and LootMasterML.UpdateUI then
                                            LootMasterML.UpdateUI( LootMasterML );
                                        end
                                    end,
                                    order = 1,
                                    width = 'full',
                                    name = "Стежити за вхідним розподілом здобичі",
                                    desc = "Показує оновлення розподілу здобичі. Так ви бачите дії майстра здобичі і можете допомогти з рішенням.",
                                    disabled = false,
                                },
                                
                                monitorIncomingThreshold = {
                                    order = 2,
                                    width = 'normal',
                                    type = "select",
                                    name = "Показувати цієї якості і вище",
                                    desc = "Бачити вікно розподілу предметів цього порогу якості або вище.",
                                    disabled = function(info) return not LootMaster.db.profile.monitor end,
                                    values = {
                                        [2] = ITEM_QUALITY2_DESC,
                                        [3] = ITEM_QUALITY3_DESC,
                                        [4] = ITEM_QUALITY4_DESC,
                                        [5] = ITEM_QUALITY5_DESC,
                                    },
                                },
                                
                                monitorSend = {
                                    type = "toggle",
                                    order = 3.1,
                                    width = 'full',
                                    name = "Надсилати вікно розподілу здобичі всьому рейду",
                                    desc = "Надсилати оновлення розподілу. Інші учасники бачать, як розподільник працює з гравцями, і можуть допомогти з рішенням. Повідомлення йдуть лише якщо ви основний розподільник здобичі.",
                                    disabled = false,
                                },
                                
                                monitorSendAssistantOnly = {
                                    type = "toggle",
                                    order = 3.2,
                                    disabled = function(info) return not LootMaster.db.profile.monitorSend end,
                                    width = 'full',
                                    name = "Надсилати вікно розподілу лише помічникам рейд-лідера",
                                    desc = "Надсилає повідомлення про розподіл лише помічникам рейд-лідера. Залиште вимкненим, якщо розподіл мають бачити всі. Вимкнення також прискорює відкриття вікна.",
                                },
                                
                                hideResponses = {
                                    type = "toggle",
                                    disabled = function(info) return not LootMaster.db.profile.monitorSend end,
                                    order = 3.3,
                                    width = 'full',
                                    name = "Приховувати відповіді до кінця голосування",
                                    desc = "Ховає відповіді інших, поки гравець ще обирає. Так ніхто не підлаштовує вибір під чужі відповіді, і голосування йде швидше, бо люди не чекають решту.",
                                },
                                
                                monitorThreshold = {
                                    order = 4,
                                    width = 'normal',
                                    type = "select",
                                    name = "Надсилати цієї якості і вище",
                                    desc = "Надсилати повідомлення про предмети цього порогу якості або вище. (Зразки та подібне теж підпадають під цей поріг.)",
                                    disabled = function(info) return not LootMaster.db.profile.monitorSend end,
                                    values = {
                                        [2] = ITEM_QUALITY2_DESC,
                                        [3] = ITEM_QUALITY3_DESC,
                                        [4] = ITEM_QUALITY4_DESC,
                                        [5] = ITEM_QUALITY5_DESC,
                                    },
                                },
                                
                                hint = {
                                    order = 5,
                                    width = 'normal',
                                    hidden = function(info) return not LootMaster.db.profile.monitorSend end,
                                    type = "description",
                                    name = "Фільтруються лише предмети BoE і BoU.\r\nПредмети BoP завжди надсилають повідомлення.",
                                },
                            }
                },
                
                ExtraFunctionGroup = {
                            type = "group",
                            order = 18,
                            guiInline = true,
                            hidden = function(info) return not LootMasterML end,
                            name = "Додаткові функції",
                            args = {
                                
                                help = {
                                    order = 0,
                                    type = "description",
                                    name = "Кілька додаткових функцій, які можуть знадобитися.",
                                },
                                btnVersionCheck = {
                                  order = 1000,
                                  type = "execute",
                                  name = "Перевірка версії",
                                  desc = "Відкриває вікно перевірки версій.",
                                  func = function()
                                           LootMaster:ShowVersionCheckFrame()
                                         end
                                },
                                
                                btnRaidInfoCheck = {
                                  order = 2000,
                                  type = "execute",
                                  name = "Перевірка рейду",
                                  desc = "Перевіряє, чи гравці перебувають у рейдовому підземеллі.",
                                  func = function()
                                           LootMasterML:ShowRaidInfoLookup()
                                         end
                                }
                                
                                
                                
                
                                
                            }
                }
            },
        },
    },
  }

  local config = LibStub("AceConfig-3.0")
  local dialog = LibStub("AceConfigDialog-3.0")

  config:RegisterOptionsTable("EPGPLootMaster-Bliz", options)
  dialog:AddToBlizOptions("EPGPLootMaster-Bliz", "EPGPLootMaster", nil, 'global')
  --dialog:AddToBlizOptions("EPGPLootMaster-Bliz", "Monitor", "EPGPLootMaster", 'MonitorGroup')
  
end