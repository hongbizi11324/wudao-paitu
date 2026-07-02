-- =============================================
-- Wudao Paitu - Deck Strength Analyzer
-- 
-- Reads all .tres cards, scores a deck on:
--   1. Cost curve
--   2. Attack/block/heal efficiency
--   3. Draw/energy sustain
--   4. Combo synergy detection
-- =============================================

io.stdout:setvbuf("no")
if io.popen then
    os.execute("chcp 65001 >nul")
end

print("")
print("+========================================+")
print("|   Wudao Paitu - Deck Analyzer         |")
print("+========================================+")
print("")

-- ============================================================
-- Step 1: Scan directory and parse all .tres files
-- ============================================================

local CARDS_DIR = "E:\\godotsave\\card\\resources\\cards"

local function scan_card_files(dir)
    local cmd = 'dir /b "' .. dir .. '\\*.tres"'
    local handle = io.popen(cmd)
    if not handle then return {} end
    local files = {}
    for file in handle:lines() do
        table.insert(files, file)
    end
    handle:close()
    return files
end

local function parse_tres_file(filepath)
    local file = io.open(filepath, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    local data = {}
    local in_resource = false
    for line in content:gmatch("(.-)\n") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed == "[resource]" then
            in_resource = true
        elseif trimmed:match("^%[") then
            in_resource = false
        elseif in_resource then
            local key, value = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
            if key then
                value = value:gsub('^"', ''):gsub('"$', '')
                value = value:match("^%s*(.-)%s*$")
                if not value:match("^ExtResource") then
                    data[key] = value
                end
            end
        end
    end
    return data
end

local function load_all_cards()
    local files = scan_card_files(CARDS_DIR)
    local cards = {}
    for _, filename in ipairs(files) do
        local filepath = CARDS_DIR .. "\\" .. filename
        local data = parse_tres_file(filepath)
        if data then
            if not data.card_id or data.card_id == "" then
                data.card_id = filename:gsub("%.tres$", "")
            end
            cards[data.card_id] = data
        end
    end
    return cards
end

-- ============================================================
-- Step 2: Scoring engine
-- ============================================================

local function to_num(val, default)
    if val == nil then return default or 0 end
    local n = tonumber(val)
    if not n then return default or 0 end
    return n
end

local function to_bool(val)
    if val == nil then return false end
    if type(val) == "string" then
        return val == "true" or val == "True" or val == "1"
    end
    return false
end

-- Dimension 1: Cost curve (0-30 pts)
local function score_curve(cards_list, all_cards)
    local total_cost = 0
    local count = #cards_list
    if count == 0 then return 0, {} end
    local dist = { c0 = 0, c1 = 0, c2 = 0, c3 = 0 }
    for _, id in ipairs(cards_list) do
        local card = all_cards[id]
        if card then
            local c = to_num(card.cost, 1)
            total_cost = total_cost + c
            if c == 0 then dist.c0 = dist.c0 + 1
            elseif c == 1 then dist.c1 = dist.c1 + 1
            elseif c == 2 then dist.c2 = dist.c2 + 1
            elseif c == 3 then dist.c3 = dist.c3 + 1 end
        end
    end
    local avg = total_cost / count
    dist.avg = avg
    local score = 30
    if avg < 0.8 then score = 20
    elseif avg <= 1.5 then score = 30
    elseif avg <= 2.0 then score = 25 - (avg - 1.5) * 10
    else score = 20 - (avg - 2.0) * 5 end
    if dist.c3 > count * 0.3 then score = score - 5 end
    return math.max(0, math.floor(score)), dist
end

-- Dimension 2: Attack/block/heal (0-45 pts)
local function score_basic(cards_list, all_cards)
    local total_damage = 0
    local total_block = 0
    local total_heal = 0
    local damage_cards = 0
    local block_cards = 0
    local card_count = #cards_list
    if card_count == 0 then return 0, {} end
    for _, id in ipairs(cards_list) do
        local card = all_cards[id]
        if card then
            local d = to_num(card.damage, 0)
            local b = to_num(card.block, 0)
            local h = to_num(card.heal, 0)
            local rpt = to_num(card["repeat"], 0)
            local times = math.max(1, rpt)
            total_damage = total_damage + d * times
            total_block = total_block + b * times
            total_heal = total_heal + h
            if d > 0 then damage_cards = damage_cards + 1 end
            if b > 0 then block_cards = block_cards + 1 end
        end
    end
    local score = 0
    if damage_cards > 0 then
        score = score + math.min(20, (total_damage / card_count) * 3)
    end
    if block_cards > 0 then
        score = score + math.min(15, (total_block / card_count) * 2)
    end
    if total_heal > 0 then
        score = score + math.min(10, total_heal * 2)
    end
    if damage_cards > 0 and block_cards == 0 then score = score - 3 end
    if block_cards > 0 and damage_cards == 0 then score = score - 5 end
    return math.floor(score), {
        dmg = total_damage, blk = total_block, heal = total_heal,
        dmg_cnt = damage_cards, blk_cnt = block_cards,
        dmg_per = card_count > 0 and math.floor(total_damage / card_count * 10) / 10 or 0,
        blk_per = card_count > 0 and math.floor(total_block / card_count * 10) / 10 or 0
    }
end

-- Dimension 3: Draw/energy sustain (0-25 pts)
local function score_draw(cards_list, all_cards)
    local total_draw = 0
    local draw_cards = 0
    local total_energy = 0
    local retain_cards = 0
    for _, id in ipairs(cards_list) do
        local card = all_cards[id]
        if card then
            local d = to_num(card.draw, 0)
            local eg = to_num(card.energy_gain, 0)
            local rt = to_bool(card.retain)
            total_draw = total_draw + d
            if d > 0 then draw_cards = draw_cards + 1 end
            total_energy = total_energy + eg
            if rt then retain_cards = retain_cards + 1 end
        end
    end
    local score = 0
    score = score + math.min(15, total_draw * 4)
    score = score + math.min(10, total_energy * 5)
    score = score + retain_cards * 2
    return math.floor(score), {
        draw = total_draw, draw_cnt = draw_cards,
        energy = total_energy, retain = retain_cards
    }
end

-- Dimension 4: Combo synergy (0-40 pts)
local function score_combo(cards_list, all_cards)
    local score = 0
    local combos = {}
    local set = {}
    for _, id in ipairs(cards_list) do set[id] = true end

    -- Shaolin
    if set["sl_fist"] and set["sl_arhat"] then
        score = score + 8
        table.insert(combos, "Shaolin combo: Fist -> Arhat burst")
    end
    if set["sl_iron"] and set["sl_arhat"] then
        score = score + 5
        table.insert(combos, "Shaolin combo: Iron -> Arhat")
    end
    if set["sl_damo"] then
        score = score + 6
        table.insert(combos, "Shaolin power: Damo auto-chan+block")
    end

    -- Wudang
    if set["wd_taiji"] and set["wd_heavy"] then
        score = score + 8
        table.insert(combos, "Wudang combo: Taiji -> Heavy burst")
    end
    if set["wd_taiji"] and set["wd_soft"] then
        score = score + 5
        table.insert(combos, "Wudang combo: Taiji -> Soft bonus")
    end
    if set["wd_twoway"] then
        score = score + 6
        table.insert(combos, "Wudang power: Twoway counter")
    end

    -- Xiaoyao
    if set["xy_lingbo"] and set["xy_zhemel"] then
        score = score + 6
        table.insert(combos, "Xiaoyao combo: Lingbo -> Zhemel discount")
    end
    if set["xy_wuxiang"] then
        score = score + 4
        table.insert(combos, "Xiaoyao utility: Wuxiang copy")
    end
    if set["xy_bahuang"] then
        score = score + 6
        table.insert(combos, "Xiaoyao power: Bahuang regen")
    end

    -- Universal
    if set["double_strike"] and set["triple_stab"] then
        score = score + 3
        table.insert(combos, "Multi-hit synergy")
    end
    if set["meditate"] and set["whirlwind"] then
        score = score + 3
        table.insert(combos, "Energy cycle: Meditate -> Whirlwind")
    end

    -- Mixed school penalty
    local schools = {}
    for _, id in ipairs(cards_list) do
        if id:match("^sl_") then schools["shaolin"] = true end
        if id:match("^wd_") then schools["wudang"] = true end
        if id:match("^xy_") then schools["xiaoyao"] = true end
    end
    local cnt = 0
    for _ in pairs(schools) do cnt = cnt + 1 end
    if cnt >= 2 then
        score = score - 4
        table.insert(combos, "WARNING: Mixed schools reduce synergy")
    end

    return math.floor(score), combos
end

-- Combined score
local function analyze_deck(card_ids, all_cards)
    local curve_score, curve_data = score_curve(card_ids, all_cards)
    local basic_score, basic_data = score_basic(card_ids, all_cards)
    local draw_score, draw_data = score_draw(card_ids, all_cards)
    local combo_score, combos = score_combo(card_ids, all_cards)
    local total = curve_score + basic_score + draw_score + combo_score
    local grade = "D"
    if total >= 90 then grade = "S"
    elseif total >= 75 then grade = "A"
    elseif total >= 60 then grade = "B"
    elseif total >= 45 then grade = "C"
    else grade = "D" end
    return {
        total = total, grade = grade,
        curve = { score = curve_score, data = curve_data },
        basic = { score = basic_score, data = basic_data },
        draw = { score = draw_score, data = draw_data },
        combo = { score = combo_score, data = combos }
    }
end

-- ============================================================
-- Step 3: Report output
-- ============================================================

local function print_line()
    print("  " .. string.rep("-", 52))
end

local function print_report(name, ids, result, cards)
    print("")
    print("  [" .. name .. "]")
    print_line()
    print(string.format("  Total: %d/100  Grade: %s", result.total, result.grade))
    print_line()
    print(string.format("  Cards: %d", #ids))

    local cd = result.curve.data
    print(string.format("  Curve: 0:%d 1:%d 2:%d 3:%d avg:%.2f [%d pts]",
        cd.c0, cd.c1, cd.c2, cd.c3, cd.avg, result.curve.score))

    local bd = result.basic.data
    print(string.format("  Stats: dmg:%d blk:%d heal:%d dmg/card:%.1f blk/card:%.1f [%d pts]",
        bd.dmg, bd.blk, bd.heal, bd.dmg_per, bd.blk_per, result.basic.score))

    local dd = result.draw.data
    print(string.format("  Draw: total:%d energy:%d retain:%d [%d pts]",
        dd.draw, dd.energy, dd.retain, result.draw.score))

    local combos = result.combo.data
    if #combos > 0 then
        print_line()
        for _, c in ipairs(combos) do
            print("    " .. c)
        end
    end
    print(string.format("  Combo: [%d pts]", result.combo.score))
    print_line()
    print("")
end

-- ============================================================
-- Step 4: Run analysis on test decks
-- ============================================================

print("Loading cards...")
local all_cards = load_all_cards()
local card_count = 0
for _ in pairs(all_cards) do card_count = card_count + 1 end
print("Loaded " .. card_count .. " cards")
print("")

local test_decks = {
    {
        name = "Shaolin",
        ids = {
            "strike", "strike", "defend", "defend",
            "sl_fist", "sl_fist", "sl_fist",
            "sl_iron", "sl_iron",
            "sl_arhat", "sl_arhat",
            "sl_golden", "sl_damo",
            "meditate", "meditate",
            "punch", "punch", "punch"
        }
    },
    {
        name = "Wudang",
        ids = {
            "strike", "strike", "defend", "defend",
            "wd_taiji", "wd_taiji", "wd_taiji",
            "wd_soft", "wd_soft",
            "wd_heavy", "wd_heavy",
            "wd_steps", "wd_twoway",
            "meditate", "meditate",
            "flowing_cloud_sword", "flowing_cloud_sword",
            "light_step", "light_step"
        }
    },
    {
        name = "Xiaoyao",
        ids = {
            "strike", "strike", "defend", "defend",
            "xy_beiming", "xy_beiming", "xy_beiming",
            "xy_lingbo", "xy_lingbo",
            "xy_zhemel", "xy_zhemel",
            "xy_wuxiang", "xy_bahuang",
            "meditate", "meditate",
            "double_strike", "double_strike",
            "tactics", "vigor"
        }
    },
    {
        name = "Starter Deck",
        ids = {
            "punch", "punch", "punch",
            "meditate", "meditate", "meditate",
            "strike", "defend",
            "light_step", "light_step"
        }
    },
    {
        name = "Mixed",
        ids = {
            "strike", "strike", "strike", "strike",
            "bash", "bash",
            "iron_wall", "iron_wall",
            "heal", "heal",
            "sl_fist", "wd_taiji", "xy_beiming"
        }
    }
}

for _, deck in ipairs(test_decks) do
    local result = analyze_deck(deck.ids, all_cards)
    print_report(deck.name, deck.ids, result, all_cards)
end

-- Rankings
print("+========================================+")
print("|              RANKINGS                  |")
print("+========================================+")
print("")

local rankings = {}
for _, deck in ipairs(test_decks) do
    local result = analyze_deck(deck.ids, all_cards)
    table.insert(rankings, { name = deck.name, score = result.total, grade = result.grade })
end

table.sort(rankings, function(a, b) return a.score > b.score end)

for i, r in ipairs(rankings) do
    local medal = (i == 1 and "GOLD" or i == 2 and "SILVER" or i == 3 and "BRONZE" or "    ")
    print(string.format("  %s  #%d: %s  %d pts [%s]", medal, i, r.name, r.score, r.grade))
end

print("")
print("+========================================+")
print("|            DONE                        |")
print("+========================================+")
print("")
