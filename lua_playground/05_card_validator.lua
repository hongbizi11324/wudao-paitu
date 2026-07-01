-- =============================================
-- 武道牌途 · 卡牌验证器

-- Windows 下自动切换控制台编码到 UTF-8（防止乱码）
io.stdout:setvbuf("no")  -- 禁用缓冲
if io.popen then
    os.execute("chcp 65001 >nul")  -- 自动切到 UTF-8 代码页
end
-- Lua 独立工具：检查 33 张卡牌的数据完整性
--
-- 运行方式（在项目目录下）：
--   cd /mnt/e/godotsave/card/lua_playground
--   ../lua 05_card_validator.lua
--
-- 或者 Windows 下（配好 PATH 后）：
--   cd \mnt\e\godotsave\card\lua_playground
--   lua 05_card_validator.lua
-- =============================================

print("")
print("+========================================+")
print("|     武道牌途 · 卡牌数据验证器        |")
print("+========================================+")
print("")

-- ========== 第1步：定义所有卡牌数据 ==========

-- 先定义门派名称字典（id → 中文名）
-- 这是一个 table，键是字符串，值也是字符串
local school_names = {
    shaolin = "少林",
    wudang  = "武当",
    xiaoyao = "逍遥"
}

-- 卡牌类型枚举（和 CardData.gd 里的 CardType 一样）
-- ATTACK=0, SKILL=1, POWER=2, INNER=3, MOVEMENT=4
local type_names = { "ATTACK", "SKILL", "POWER", "INNER", "MOVEMENT" }

-- ========== 所有卡牌数据 ==========
-- 这是一个数组 table，每个元素是一个字典 table
-- 注意：Lua 数组从 1 开始计数！
local cards = {
    -- 注意：每个 card 里的字段就是我们要检查的"标准"
    -- 验证器会检查是否所有必需字段都存在、值是否合理

    -- ---- 通用基础牌 ----
    {
        id = "strike",          -- 卡牌 ID，必须唯一
        name = "打击",          -- 卡牌名
        cost = 1,               -- 费用（必须 0~3）
        card_type = 0,          -- ATTACK
        school = "",            -- 空字符串 = 通用牌
        damage = 6,             -- 伤害值
        desc = "造成6点伤害"     -- 描述
    },
    {
        id = "defend",
        name = "防御",
        cost = 1,
        card_type = 1,          -- SKILL
        school = "",
        block = 5,
        desc = "获得5点格挡"
    },
    {
        id = "bash",
        name = "重击",
        cost = 2,
        card_type = 0,
        school = "",
        damage = 10,
        desc = "造成10点伤害"
    },
    {
        id = "heal",
        name = "治疗",
        cost = 1,
        card_type = 1,
        school = "",
        heal = 4,
        desc = "回复4点生命"
    },
    {
        id = "meditate",
        name = "调息",
        cost = 0,
        card_type = 3,          -- INNER
        school = "",
        energy_gain = 1,
        desc = "获得1点内力"
    },
    {
        id = "punch",
        name = "普通拳脚",
        cost = 1,
        card_type = 0,
        school = "",
        damage = 2,
        desc = "造成2点伤害"
    },
    {
        id = "light_step",
        name = "轻身术",
        cost = 1,
        card_type = 4,          -- MOVEMENT
        school = "",
        draw = 1,
        desc = "抽1张牌"
    },
    {
        id = "double_strike",
        name = "连击",
        cost = 1,
        card_type = 0,
        school = "",
        damage = 4,
        repeat_count = 2,
        desc = "造成4点伤害，重复2次"
    },
    {
        id = "triple_stab",
        name = "三连刺",
        cost = 2,
        card_type = 0,
        school = "",
        damage = 3,
        repeat_count = 3,
        desc = "造成3点伤害，重复3次"
    },
    {
        id = "flowing_cloud_sword",
        name = "流云剑法",
        cost = 1,
        card_type = 0,
        school = "",
        damage = 3,
        draw = 1,
        desc = "造成3点伤害，抽1张牌"
    },
    {
        id = "sword_energy",
        name = "剑气纵横",
        cost = 2,
        card_type = 0,
        school = "",
        damage = 6,
        desc = "造成6点伤害"
    },
    {
        id = "whirlwind",
        name = "旋风",
        cost = 2,
        card_type = 0,
        school = "",
        damage = 8,
        draw = 1,
        desc = "造成8点伤害，抽1张牌"
    },
    {
        id = "iron_shirt",
        name = "铁布衫",
        cost = 1,
        card_type = 1,
        school = "",
        block = 4,
        desc = "获得4点格挡"
    },
    {
        id = "iron_wall",
        name = "铁壁",
        cost = 2,
        card_type = 1,
        school = "",
        block = 8,
        desc = "获得8点格挡"
    },
    {
        id = "golden_bell",
        name = "金钟罩",
        cost = 2,
        card_type = 1,
        school = "",
        block = 8,
        desc = "获得8点格挡"
    },
    {
        id = "tactics",
        name = "战术",
        cost = 1,
        card_type = 1,
        school = "",
        draw = 2,
        desc = "抽2张牌"
    },
    {
        id = "vigor",
        name = "活力",
        cost = 1,
        card_type = 1,
        school = "",
        heal = 3,
        draw = 1,
        desc = "回复3点生命，抽1张牌"
    },
    {
        id = "vajra_fist",
        name = "金刚拳",
        cost = 1,
        card_type = 0,
        school = "",
        damage = 3,
        block = 2,
        desc = "造成3点伤害，获得2点格挡"
    },

    -- ---- 🏯 少林 ----
    {
        id = "sl_fist",
        name = "罗汉拳",
        cost = 1,
        card_type = 0,
        school = "shaolin",
        damage = 4,
        desc = "造成4点伤害，获得1层禅意"
    },
    {
        id = "sl_iron",
        name = "铁布衫",
        cost = 1,
        card_type = 1,
        school = "shaolin",
        block = 6,
        desc = "获得6点格挡，获得1层禅意"
    },
    {
        id = "sl_golden",
        name = "金钟罩",
        cost = 2,
        card_type = 1,
        school = "shaolin",
        block = 8,
        desc = "获得8点格挡。消耗所有禅意，每层额外+3格挡"
    },
    {
        id = "sl_arhat",
        name = "罗汉伏魔",
        cost = 2,
        card_type = 0,
        school = "shaolin",
        damage = 6,
        desc = "造成6点伤害。消耗所有禅意，每层额外+4伤害"
    },
    {
        id = "sl_damo",
        name = "达摩一苇",
        cost = 3,
        card_type = 2,          -- POWER！
        school = "shaolin",
        desc = "核心：每回合开始时，获得2层禅意和3点格挡"
    },

    -- ---- ☯️ 武当 ----
    {
        id = "wd_taiji",
        name = "太极拳",
        cost = 1,
        card_type = 1,
        school = "wudang",
        block = 4,
        desc = "获得4点格挡，获得1层剑意"
    },
    {
        id = "wd_soft",
        name = "柔云剑",
        cost = 1,
        card_type = 0,
        school = "wudang",
        damage = 5,
        desc = "造成5点伤害。消耗1层剑意：伤害+4"
    },
    {
        id = "wd_steps",
        name = "梯云纵",
        cost = 2,
        card_type = 1,
        school = "wudang",
        block = 6,
        draw = 1,
        desc = "获得6点格挡，抽1张牌。消耗1层剑意：额外抽1张"
    },
    {
        id = "wd_heavy",
        name = "真武重剑",
        cost = 2,
        card_type = 0,
        school = "wudang",
        desc = "消耗所有剑意，每层造成5点伤害"
    },
    {
        id = "wd_twoway",
        name = "太极两仪",
        cost = 3,
        card_type = 2,          -- POWER！
        school = "wudang",
        desc = "核心：每回合首次受击时，获得2层剑意并回复2点生命"
    },

    -- ---- 🦋 逍遥 ----
    {
        id = "xy_beiming",
        name = "北冥神掌",
        cost = 1,
        card_type = 0,
        school = "xiaoyao",
        damage = 4,
        heal = 2,
        desc = "造成4点伤害，回复2点生命"
    },
    {
        id = "xy_lingbo",
        name = "凌波微步",
        cost = 1,
        card_type = 1,
        school = "xiaoyao",
        block = 6,
        desc = "获得6点格挡。本回合下一张牌费用-1"
    },
    {
        id = "xy_wuxiang",
        name = "小无相功",
        cost = 2,
        card_type = 1,
        school = "xiaoyao",
        desc = "复制弃牌堆最后一张非POWER牌到手牌（消耗）"
    },
    {
        id = "xy_zhemel",
        name = "天山折梅手",
        cost = 2,
        card_type = 0,
        school = "xiaoyao",
        damage = 7,
        desc = "造成7点伤害。若手牌≤3张，改为12点"
    },
    {
        id = "xy_bahuang",
        name = "八荒六合",
        cost = 3,
        card_type = 2,          -- POWER！
        school = "xiaoyao",
        desc = "核心：每回合开始时，回复3点生命，将1张随机基础牌加入手牌"
    }
}

-- ========== 第2步：验证函数 ==========

-- 验证结果统计
local results = {
    total = #cards,           -- # 是 Lua 取 table 长度的运算符
    passed = 0,
    failed = 0,
    errors = {}               -- 错误列表，每个元素是一条字符串
}

-- 辅助函数：往错误列表加一条记录
-- 参数：card_id = 卡牌 ID，msg = 错误描述
local function add_error(card_id, msg)
    table.insert(results.errors, "[X] " .. card_id .. "：" .. msg)
    results.failed = results.failed + 1
end

-- 辅助函数：往错误列表加一条"通过"记录（方便看清楚哪些卡没问题）
local function add_pass(card_id)
    -- 不记录通过的卡，只计数
    results.passed = results.passed + 1
end

-- ===== 验证规则1：费用检查 =====
-- 所有卡牌费用必须在 0~3 之间
local function check_cost(card)
    if card.cost < 0 or card.cost > 3 then
        -- 用 .. 做字符串拼接
        add_error(card.id, "费用 " .. card.cost .. " 超出范围（允许 0~3）")
        return false
    end
    return true
end

-- ===== 验证规则2：门派标签检查 =====
-- sl_ 开头的卡 school 必须是 shaolin
-- wd_ 开头的卡 school 必须是 wudang
-- xy_ 开头的卡 school 必须是 xiaoyao
-- 其他卡 school 必须是空字符串
local function check_school(card)
    -- string.match 是 Lua 的字符串匹配函数
    -- ^sl_ 表示以 sl_ 开头
    if string.match(card.id, "^sl_") then
        if card.school ~= "shaolin" then
            add_error(card.id, "少林卡缺少 school='shaolin'（当前：'" .. tostring(card.school) .. "'）")
            return false
        end
    elseif string.match(card.id, "^wd_") then
        if card.school ~= "wudang" then
            add_error(card.id, "武当卡缺少 school='wudang'（当前：'" .. tostring(card.school) .. "'）")
            return false
        end
    elseif string.match(card.id, "^xy_") then
        if card.school ~= "xiaoyao" then
            add_error(card.id, "逍遥卡缺少 school='xiaoyao'（当前：'" .. tostring(card.school) .. "'）")
            return false
        end
    else
        -- 通用牌，school 应该为空
        if card.school ~= "" then
            add_error(card.id, "通用牌 school 应为空（当前：'" .. card.school .. "'）")
            return false
        end
    end
    return true
end

-- ===== 验证规则3：POWER 卡类型检查 =====
-- 三张核心 POWER 卡的 card_type 必须为 2
local power_cards = { ["sl_damo"] = true, ["wd_twoway"] = true, ["xy_bahuang"] = true }
local function check_power_type(card)
    -- 如果是 POWER 核心卡，检查 card_type
    if power_cards[card.id] then
        if card.card_type ~= 2 then
            add_error(card.id, "核心 POWER 卡 card_type 必须为 2（当前：" .. card.card_type .. "）")
            return false
        end
    end
    return true
end

-- ===== 验证规则4：唯一 ID 检查 =====
-- 确保没有重复的 card_id
local function check_unique_ids(card_list)
    local seen = {}   -- 空 table，用来记录已经见过的 ID
    local has_dup = false
    
    for _, card in ipairs(card_list) do
        if seen[card.id] then
            add_error(card.id, "重复 ID！第一次出现在第 " .. seen[card.id] .. " 项")
            has_dup = true
        else
            seen[card.id] = _  -- _ 是当前索引（Lua 中常用 _ 表示不关心的值）
        end
    end
    
    return not has_dup
end

-- ===== 验证规则5：字段完整性检查 =====
-- 检查每个卡牌是否都有必需的字段
local function check_fields(card)
    if card.id == nil or card.id == "" then
        add_error("(未知)", "卡牌缺少 id 字段")
        return false
    end
    if card.name == nil or card.name == "" then
        add_error(card.id, "卡牌缺少 name 字段")
        return false
    end
    if card.desc == nil or card.desc == "" then
        add_error(card.id, "卡牌缺少 desc 字段")
        return false
    end
    if card.card_type == nil then
        add_error(card.id, "卡牌缺少 card_type 字段")
        return false
    end
    return true
end

-- ===== 验证规则6：平衡性检查 =====
-- 检查费用和伤害的比例是否合理（只是一个参考，不是硬性规则）
local function check_balance(card)
    if card.damage and card.damage > 0 then
        -- 每费伤害比
        local ratio = card.damage / (card.cost or 1)
        if ratio > 8 then
            -- 只是警告，不是错误
            -- 用 print 直接输出，不记录到错误列表
            print("[!] 警告：" .. card.id .. " 每费伤害 " .. string.format("%.1f", ratio) .. "，偏高")
        end
    end
end

-- ========== 第3步：执行验证 ==========

print("正在验证 " .. #cards .. " 张卡牌...")
print("")

-- 先检查唯一 ID（这个需要一次性检查所有卡）
check_unique_ids(cards)

-- 逐张卡检查
for _, card in ipairs(cards) do
    -- ipairs(cards) 遍历数组（按数字索引 1,2,3...）
    -- _ 是索引值（我们不需要），card 是卡牌数据
    
    -- 执行所有验证规则
    local ok = true
    
    -- Lua 的 and 是短路求值：如果前面为 false，后面就不执行了
    ok = check_fields(card) and ok
    ok = check_cost(card) and ok
    ok = check_school(card) and ok
    ok = check_power_type(card) and ok
    
    -- 平衡性检查只给警告，不影响通过/失败
    check_balance(card)
    
    if ok then
        add_pass(card.id)
    end
end

-- ========== 第4步：输出报告 ==========

print("")
print("+========================================+")
print("|            -- 验证报告 --                 |")
print("+========================================+")
print("")

-- string.format：Lua 的格式化输出，和 C 的 printf 类似
print(string.format("  总卡牌数：%d", results.total))
print(string.format("  通过：    %d", results.passed))
print(string.format("  失败：    %d", results.failed))
print("")

if results.failed > 0 then
    print("-- 错误详情 --")
    print("")
    for _, err in ipairs(results.errors) do
        print(err)
    end
    print("")
    print("结果：有 " .. results.failed .. " 个问题需要修复")
else
    print("结果： 全部通过！33 张卡牌数据完整")
end

print("")

-- ========== 第5步：统计摘要 ==========

-- 按门派统计卡牌数量
print("-- 门派分布 --")
print("")

local school_count = {}  -- key = school 名, value = 计数
for _, card in ipairs(cards) do
    local s = card.school
    if s == "" then
        s = "通用"
    else
        -- 查门派中文名，如果没有就原样显示
        s = school_names[s] or s
    end
    school_count[s] = (school_count[s] or 0) + 1
end

-- pairs 遍历字典（所有键），不像 ipairs 只遍历连续数字键
for name, count in pairs(school_count) do
    print("  " .. name .. "：" .. count .. " 张")
end

print("")
print("-- 费用分布 --")
print("")

local cost_count = {}
for _, card in ipairs(cards) do
    local c = tostring(card.cost) .. "费"
    cost_count[c] = (cost_count[c] or 0) + 1
end
for cost, count in pairs(cost_count) do
    print("  " .. cost .. "：" .. count .. " 张")
end

print("")
print("-- 类型分布 --")
print("")

local type_count = {}
for _, card in ipairs(cards) do
    local t = type_names[card.card_type + 1] or "未知"  -- Lua 从1开始，所以要+1
    type_count[t] = (type_count[t] or 0) + 1
end
for tname, count in pairs(type_count) do
    print("  " .. tname .. "：" .. count .. " 张")
end

print("")
print("+========================================+")
print("|            -- 验证完成 --                 |")
print("+========================================+")
print("")
