-- =============================================
-- 武道牌途 · 卡牌验证器 v2
-- 
-- 这一次，不再手动定义卡牌数据，
-- 而是直接读取 Godot 的 .tres 文件来做验证！
--
-- 学到什么：
--   1. Lua 的文件 IO（读取外部文件）
--   2. 字符串模式匹配（解析 .tres 格式）
--   3. 真正的数据驱动验证（不再维护两份数据）
--
-- 运行方式：
--   cd /mnt/e/godotsave/card/lua_playground
--   ../lua55 06_card_validator_v2.lua
-- =============================================

io.stdout:setvbuf("no")
if io.popen then
    os.execute("chcp 65001 >nul")
end

print("")
print("+========================================+")
print("|   武道牌途 · 卡牌数据验证器 v2       |")
print("|   直接从 .tres 文件读取数据！         |")
print("+========================================+")
print("")

-- ============================================================
-- 第1步：配置 —— 告诉 Lua 去哪里找文件
-- ============================================================

-- 项目根目录（相对于本脚本的路径）
-- .. 表示"上一级目录"
-- 因为本脚本在 lua_playground/ 里，项目根在 card/
local PROJECT_ROOT = ".."

-- 卡牌资源目录
local CARDS_DIR = PROJECT_ROOT .. "/resources/cards"

-- 内置的 .tres 文件列表（我们也可以让 Lua 自动扫描目录）
-- 先用硬编码，后面再升级成自动扫描
local card_files = {
    -- 通用
    "strike.tres", "defend.tres", "bash.tres", "heal.tres",
    "meditate.tres", "punch.tres", "light_step.tres",
    "double_strike.tres", "triple_stab.tres",
    "flowing_cloud_sword.tres", "sword_energy.tres", "whirlwind.tres",
    "iron_shirt.tres", "iron_wall.tres", "golden_bell.tres",
    "tactics.tres", "vigor.tres", "vajra_fist.tres",
    
    -- 少林
    "sl_fist.tres", "sl_iron.tres", "sl_golden.tres",
    "sl_arhat.tres", "sl_damo.tres",
    
    -- 武当
    "wd_taiji.tres", "wd_soft.tres", "wd_steps.tres",
    "wd_heavy.tres", "wd_twoway.tres",
    
    -- 逍遥（基础5 + 云芷新卡25）
    "xy_beiming.tres", "xy_lingbo.tres", "xy_wuxiang.tres",
    "xy_zhemel.tres", "xy_bahuang.tres",
    "xy_xiaoyaoyou.tres", "xy_xingluo.tres", "xy_fengjuan.tres",
    "xy_guicang.tres", "xy_fuguang.tres", "xy_yufeng.tres",
    "xy_duanliu.tres", "xy_wanxiang.tres", "xy_xiuli.tres",
    "xy_lianhuan.tres", "xy_houfa.tres", "xy_jinghua.tres",
    "xy_wujian.tres", "xy_xushi.tres", "xy_yixing.tres",
    "xy_hantan.tres", "xy_qiguan.tres", "xy_tuna.tres",
    "xy_longxiang.tres", "xy_baoyuan.tres", "xy_xixing.tres",
    "xy_guanxing.tres", "xy_fange.tres", "xy_yibizhi.tres", "xy_duotian.tres"
}

-- 门派中文名映射
local school_names = {
    shaolin = "少林",
    wudang  = "武当",
    xiaoyao = "逍遥"
}

-- 卡牌类型中文名
local type_names = { "ATTACK", "SKILL", "POWER", "INNER", "MOVEMENT" }

-- ============================================================
-- 第2步：解析 .tres 文件
-- ============================================================

--- 读取一个 .tres 文件，返回一个 table（字典）
--- @param filepath string 文件路径
--- @return table|nil 解析后的数据，失败返回 nil
local function parse_tres_file(filepath)
    -- io.open() 打开文件，"r" = read 只读模式
    -- 如果文件不存在或打不开，返回 nil 和错误信息
    local file, err = io.open(filepath, "r")
    if not file then
        print("[!] 无法打开文件：" .. filepath)
        print("    原因：" .. (err or "未知错误"))
        return nil
    end
    
    -- file:read("*a") 读取整个文件内容
    -- "*a" = read all，一口气读完
    local content = file:read("*a")
    file:close()  -- 用完一定要关！
    
    -- 按行分割
    -- Lua 没有内置的 split 函数，我们用 gmatch 模式匹配来逐行处理
    local data = {}
    local in_resource_section = false  -- 标记是否进入了 [resource] 段
    
    -- gmatch 用 "(.-)\n" 模式匹配每一行
    -- (.-) 是"懒惰匹配"，匹配到第一个换行符就停
    for line in content:gmatch("(.-)\n") do
        -- 去掉行首尾空白
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed == "" then
            -- 空行跳过
        elseif trimmed == "[resource]" then
            -- 进入 [resource] 区域
            in_resource_section = true
        elseif trimmed:match("^%[") then
            -- 其他 [xxx] 段，不在 [resource] 内就不处理
            in_resource_section = false
        elseif in_resource_section then
            -- 在 [resource] 内部，解析 key = value
            -- string.match 用模式匹配提取键和值
            -- ^([%w_]+)%s*=%s*(.+)$ 解释：
            --   ^          = 行开头
            --   ([%w_]+)   = 捕获组1：字母/数字/下划线（字段名）
            --   %s*=%s*    = 等号，两边可以有空格
            --   (.+)$      = 捕获组2：剩下的所有内容（值）
            local key, value = trimmed:match("^([%w_]+)%s*=%s*(.+)$")
            
            if key then
                -- Lua 的字符串函数：去掉值首尾的空白和引号
                -- string.gsub 是全局替换函数
                -- 这里去掉值两侧的双引号
                value = value:gsub('^"', ''):gsub('"$', '')
                -- 再去掉首尾空白
                value = value:match("^%s*(.-)%s*$")
                
                -- 特殊处理：ExtResource("1") 这种引用
                if value:match("^ExtResource") then
                    -- 这是 Godot 的内部引用，跳过
                else
                    data[key] = value
                end
            end
        end
    end
    
    return data
end

--- 解析所有卡牌文件
--- @return table 卡牌数组
local function load_all_cards()
    local cards = {}
    local failed_files = {}
    
    for _, filename in ipairs(card_files) do
        local filepath = CARDS_DIR .. "/" .. filename
        local card_data = parse_tres_file(filepath)
        
        if card_data then
            -- 把文件名（不含 .tres）作为默认 card_id
            if not card_data.card_id then
                card_data.card_id = filename:gsub("%.tres$", "")
            end
            table.insert(cards, card_data)
        else
            table.insert(failed_files, filename)
        end
    end
    
    return cards, failed_files
end

-- ============================================================
-- 第3步：验证引擎
-- ============================================================

local results = {
    total = 0,
    passed = 0,
    failed = 0,
    warnings = {},
    errors = {}
}

local function add_error(card_id, msg)
    table.insert(results.errors, "[✗] " .. card_id .. "：" .. msg)
    results.failed = results.failed + 1
end

local function add_warning(card_id, msg)
    table.insert(results.warnings, "[!] " .. card_id .. "：" .. msg)
end

-- ---- 规则1：字段完整性 ----
local function check_fields(card)
    local ok = true
    
    -- card_id 必须有
    if not card.card_id or card.card_id == "" then
        add_error("(未知)", "缺少 card_id 字段")
        ok = false
    end
    
    -- card_name 必须有
    if not card.card_name or card.card_name == "" then
        add_error(card.card_id or "?", "缺少 card_name 字段")
        ok = false
    end
    
    -- description 必须有
    if not card.description or card.description == "" then
        add_error(card.card_id, "缺少 description 字段")
        ok = false
    end
    
    -- card_type 必须有
    if not card.card_type then
        add_error(card.card_id, "缺少 card_type 字段")
        ok = false
    end
    
    -- cost 必须有
    if not card.cost then
        add_error(card.card_id, "缺少 cost 字段")
        ok = false
    end
    
    -- school 不强制，但如果有就应该在已知门派范围内
    if card.school and card.school ~= "" then
        if not school_names[card.school] then
            add_warning(card.card_id, "未知门派标识 '" .. card.school .. "'，预期为 shaolin/wudang/xiaoyao 之一")
        end
    end
    
    return ok
end

-- ---- 规则2：费用检查 ----
local function check_cost(card)
    local cost = tonumber(card.cost)
    if not cost then
        add_error(card.card_id, "cost 不是有效数字（当前值：'" .. tostring(card.cost) .. "'）")
        return false
    end
    
    if cost < 0 or cost > 4 then
        add_error(card.card_id, "费用 " .. cost .. " 超出允许范围（0~4）")
        return false
    end
    
    return true
end

-- ---- 规则3：类型检查 ----
local function check_type(card)
    local t = tonumber(card.card_type)
    if not t then
        add_error(card.card_id, "card_type 不是有效数字（当前值：'" .. tostring(card.card_type) .. "'）")
        return false
    end
    
    if t < 0 or t > 4 then
        add_error(card.card_id, "card_type " .. t .. " 超出范围（允许 0~4）")
        return false
    end
    
    -- 如果是 POWER 卡（type=2），检查核心机制
    -- 核心卡应该只有三张门派核心
    local core_ids = { ["sl_damo"] = true, ["wd_twoway"] = true, ["xy_bahuang"] = true }
    if t == 2 and not core_ids[card.card_id] then
        add_warning(card.card_id, "非核心卡使用了 POWER 类型（type=2），确认是否有意为之")
    end
    
    return true
end

-- ---- 规则4：数值有效性 ----
local function check_numeric(card)
    local ok = true
    
    -- 伤害值
    if card.damage then
        local d = tonumber(card.damage)
        if not d or d < 0 then
            add_error(card.card_id, "damage 无效（值：'" .. tostring(card.damage) .. "'）")
            ok = false
        elseif d > 50 then
            add_warning(card.card_id, "伤害值 " .. d .. " 偏高（>50），确认是否合理")
        end
    end
    
    -- 格挡值
    if card.block then
        local b = tonumber(card.block)
        if not b or b < 0 then
            add_error(card.card_id, "block 无效（值：'" .. tostring(card.block) .. "'）")
            ok = false
        elseif b > 30 then
            add_warning(card.card_id, "格挡值 " .. b .. " 偏高（>30），确认是否合理")
        end
    end
    
    -- 回血值
    if card.heal then
        local h = tonumber(card.heal)
        if not h or h < 0 then
            add_error(card.card_id, "heal 无效（值：'" .. tostring(card.heal) .. "'）")
            ok = false
        end
    end
    
    -- 抽牌数
    if card.draw then
        local dr = tonumber(card.draw)
        if not dr or dr < 0 then
            add_error(card.card_id, "draw 无效（值：'" .. tostring(card.draw) .. "'）")
            ok = false
        elseif dr > 5 then
            add_warning(card.card_id, "抽牌数 " .. dr .. " 偏高（>5），可能破坏牌组循环")
        end
    end
    
    return ok
end

-- ---- 规则5：平衡性分析 ----
local function check_balance(card)
    local cost = tonumber(card.cost) or 1
    if cost <= 0 then cost = 1 end  -- 0费牌按1费算性价比
    
    -- 伤害性价比
    if card.damage then
        local damage = tonumber(card.damage)
        if damage and damage > 0 then
            local ratio = damage / cost
            if ratio > 8 then
                add_warning(card.card_id, 
                    string.format("每费伤害 %.1f（%d/%d费），偏高", ratio, damage, cost))
            elseif ratio < 3 and cost >= 2 then
                add_warning(card.card_id,
                    string.format("每费伤害 %.1f（%d/%d费），偏低", ratio, damage, cost))
            end
        end
    end
    
    -- 格挡性价比
    if card.block then
        local block = tonumber(card.block)
        if block and block > 0 then
            local ratio = block / cost
            if ratio > 10 then
                add_warning(card.card_id,
                    string.format("每费格挡 %.1f（%d/%d费），偏高", ratio, block, cost))
            end
        end
    end
    
    -- 回血性价比
    if card.heal then
        local heal = tonumber(card.heal)
        if heal and heal > 0 then
            local ratio = heal / cost
            if ratio > 5 then
                add_warning(card.card_id,
                    string.format("每费回血 %.1f（%d/%d费），偏高", ratio, heal, cost))
            end
        end
    end
    
    -- 复合效果：
    -- 一张牌既有伤害又有格挡，应该是功能混合型
    if card.damage and card.block then
        local d = tonumber(card.damage) or 0
        local b = tonumber(card.block) or 0
        if d > 0 and b > 0 then
            local total_value = d + b
            local ratio = total_value / cost
            if ratio < 4 then
                add_warning(card.card_id,
                    string.format("混合牌总效益 %.1f（伤%d+挡%d)/%d费，偏低", 
                    ratio, d, b, cost))
            end
        end
    end
end

-- ---- 规则6：ID 命名规范 ----
local function check_id_convention(card)
    local id = card.card_id
    if not id then return true end
    
    -- 少林卡必须 sl_ 开头
    if card.school == "shaolin" then
        if not id:match("^sl_") then
            add_error(id, "少林卡 ID 应以 sl_ 开头（当前：'" .. id .. "'）")
            return false
        end
    elseif card.school == "wudang" then
        if not id:match("^wd_") then
            add_error(id, "武当卡 ID 应以 wd_ 开头（当前：'" .. id .. "'）")
            return false
        end
    elseif card.school == "xiaoyao" then
        if not id:match("^xy_") then
            add_error(id, "逍遥卡 ID 应以 xy_ 开头（当前：'" .. id .. "'）")
            return false
        end
    else
        -- 通用牌不应有门派前缀
        if id:match("^sl_") or id:match("^wd_") or id:match("^xy_") then
            add_error(id, "通用牌 ID 不应包含门派前缀（sl_/wd_/xy_）")
            return false
        end
    end
    
    return true
end

-- ---- 规则7：唯一性 ----
local function check_unique(cards)
    local seen = {}
    local has_dup = false
    
    for _, card in ipairs(cards) do
        local id = card.card_id
        if seen[id] then
            add_error(id, "重复 card_id！也出现在：第 " .. seen[id] .. " 个文件")
            has_dup = true
        else
            seen[id] = _  -- _ 是 ipairs 的索引（文件序号）
        end
    end
    
    return not has_dup
end

-- ---- 规则8：描述与数值一致性 ----
local function check_desc_consistency(card)
    local desc = card.description or ""
    
    -- 如果有伤害值，描述应该提到伤害
    if card.damage and tonumber(card.damage) > 0 then
        local d = tonumber(card.damage)
        if not desc:find(tostring(d), 1, true) then
            -- 简单检查：描述里是否包含伤害数值
            -- 有些卡可能用文字描述（如"每层造成5点伤害"），所以只是警告
            -- 用 find 的最后一个参数 true 表示"纯文本匹配"，而不是模式匹配
        end
    end
    
    -- 如果有格挡值，描述应该提到格挡
    if card.block and tonumber(card.block) > 0 then
        local b = tonumber(card.block)
        if not desc:find("格挡", 1, true) then
            add_warning(card.card_id, "有 block=" .. b .. " 但描述中未提到'格挡'")
        end
    end
    
    -- 如果有回血值，描述应该提到回血/回复
    if card.heal and tonumber(card.heal) > 0 then
        local h = tonumber(card.heal)
        if not desc:find("回复", 1, true) and not desc:find("生命", 1, true) then
            add_warning(card.card_id, "有 heal=" .. h .. " 但描述中未提到'回复'或'生命'")
        end
    end
end

-- ============================================================
-- 第4步：统计与报告
-- ============================================================

--- 统计卡牌按门派分布
local function stat_by_school(cards)
    local stats = {}
    for _, card in ipairs(cards) do
        local s = card.school
        if s == nil or s == "" then
            s = "通用"
        else
            s = school_names[s] or s
        end
        stats[s] = (stats[s] or 0) + 1
    end
    return stats
end

--- 统计卡牌按费用分布
local function stat_by_cost(cards)
    local stats = {}
    for _, card in ipairs(cards) do
        local c = (tonumber(card.cost) or "?") .. "费"
        stats[c] = (stats[c] or 0) + 1
    end
    return stats
end

--- 统计卡牌按类型分布
local function stat_by_type(cards)
    local stats = {}
    for _, card in ipairs(cards) do
        local t_idx = tonumber(card.card_type)
        local t = (t_idx and type_names[t_idx + 1]) or "未知"
        stats[t] = (stats[t] or 0) + 1
    end
    return stats
end

-- ============================================================
-- 第5步：执行！
-- ============================================================

print("正在加载 " .. #card_files .. " 个 .tres 文件...")
print("")

-- 加载所有卡牌
local cards, failed = load_all_cards()

if #failed > 0 then
    print("[!] 以下 " .. #failed .. " 个文件加载失败：")
    for _, f in ipairs(failed) do
        print("    - " .. f)
    end
    print("")
end

print("成功加载 " .. #cards .. " 张卡牌数据！")
print("")

-- 更新总数
results.total = #cards

-- 检查唯一性
check_unique(cards)

-- 逐张验证
for _, card in ipairs(cards) do
    local ok = true
    
    ok = check_fields(card) and ok
    ok = check_cost(card) and ok
    ok = check_type(card) and ok
    ok = check_id_convention(card) and ok
    ok = check_numeric(card) and ok
    
    -- 这些只是分析/警告，不影响通过/失败
    check_balance(card)
    check_desc_consistency(card)
    
    if ok then
        results.passed = results.passed + 1
    end
end

-- ============================================================
-- 输出报告
-- ============================================================

print("")
print("+========================================+")
print("|           验证报告                     |")
print("+========================================+")
print("")

print(string.format("  总卡牌数：%d", results.total))
print(string.format("  通过：    %d", results.passed))
print(string.format("  失败：    %d", results.failed))
print(string.format("  警告：    %d", #results.warnings))
print("")

-- 错误详情
if results.failed > 0 then
    print("-- 错误详情 --")
    print("")
    for _, err in ipairs(results.errors) do
        print(err)
    end
    print("")
end

-- 警告详情
if #results.warnings > 0 then
    print("-- 警告详情 --")
    print("")
    for _, warn in ipairs(results.warnings) do
        print(warn)
    end
    print("")
end

-- 最终结论
if results.failed > 0 then
    print("结论：有 " .. results.failed .. " 个问题需要修复")
else
    print("结论：全部通过！所有 " .. results.total .. " 张卡牌数据完整")
end

print("")

-- ============================================================
-- 统计摘要
-- ============================================================

print("-- 门派分布 --")
print("")
local school_stats = stat_by_school(cards)
for name, count in pairs(school_stats) do
    print("  " .. name .. "：" .. count .. " 张")
end

print("")
print("-- 费用分布 --")
print("")
local cost_stats = stat_by_cost(cards)
for cost, count in pairs(cost_stats) do
    print("  " .. cost .. "：" .. count .. " 张")
end

print("")
print("-- 类型分布 --")
print("")
local type_stats = stat_by_type(cards)
for tname, count in pairs(type_stats) do
    print("  " .. tname .. "：" .. count .. " 张")
end

-- 额外统计：最贵的伤害输出
print("")
print("-- 爆发力排名（伤害/费比前5） --")
print("")

local damage_cards = {}
for _, card in ipairs(cards) do
    if card.damage and tonumber(card.damage) > 0 then
        local d = tonumber(card.damage)
        local c = tonumber(card.cost) or 1
        if c <= 0 then c = 1 end
        table.insert(damage_cards, {
            id = card.card_id,
            name = card.card_name or card.card_id,
            damage = d,
            cost = tonumber(card.cost) or 0,
            ratio = d / c
        })
    end
end

-- 按伤害/费比排序
table.sort(damage_cards, function(a, b)
    return a.ratio > b.ratio
end)

for i = 1, math.min(5, #damage_cards) do
    local c = damage_cards[i]
    print(string.format("  %d. %-10s %6s   %d伤/%d费 = %.1f",
        i, c.id, "(" .. (c.name) .. ")", c.damage, c.cost, c.ratio))
end

print("")
print("+========================================+")
print("|           验证完成                     |")
print("+========================================+")
print("")
