-- ==============================================
-- 卡牌模块 · 云芷专属（25张）— 手牌管理 + 内力博弈 + 意图预读
-- 类型常量：ATTACK=0 SKILL=1 POWER=2 INNER=3 MOVEMENT=4
-- 意图常量：ATTACK=0 DEFEND=1
-- ==============================================

local H = CardHelpers

-- 逍遥游：POWER，手牌上限+2、攻击/内力牌费用-1
CardEffects.xy_xiaoyaoyou = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
        set_power = "xiaoyaoyou",
    }
end

-- 龙象般若：POWER，剩余内力×2转为伤害加成（加成在执行器结算）
CardEffects.xy_longxiang = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
        set_power = "longxiang",
    }
end

-- ---------- 条件攻击 ----------

-- 星落九天：手牌≥6 → 伤害+5
CardEffects.xy_xingluo = function(ctx)
    local r = H.base(ctx)
    if ctx.hand_size >= 6 then
        r["damage"] = r["damage"] + 5
    end
    return r
end

-- 风卷残云：伤害+手牌数（至多4）
CardEffects.xy_fengjuan = function(ctx)
    local r = H.base(ctx)
    r["damage"] = r["damage"] + math.min(ctx.hand_size, 4)
    return r
end

-- 无间道：上一张是技能 → 伤害翻倍
CardEffects.xy_wujian = function(ctx)
    local r = H.base(ctx)
    if ctx.last_played_card_type == 1 then
        r["damage"] = r["damage"] * 2
    end
    return r
end

-- 气贯长虹：额外消耗2内力 → 伤害+6
CardEffects.xy_qiguan = function(ctx)
    local r = H.base(ctx)
    if ctx.player_energy >= 2 then
        r["damage"] = r["damage"] + 6
        r["energy_gain"] = -2
    end
    return r
end

-- 吸星大法：敌有护盾 → 伤害+5，并按伤害回血
CardEffects.xy_xixing = function(ctx)
    local r = H.base(ctx)
    if ctx.enemy_block > 0 then
        r["damage"] = r["damage"] + 5
        r["heal"] = r["damage"]
    end
    return r
end

-- 反戈一击：敌人攻击意图 → 固定16伤害
CardEffects.xy_fange = function(ctx)
    local r = H.base(ctx)
    if ctx.enemy_intent_type == 0 then
        r["damage"] = 16
    end
    return r
end

-- 夺天造化：敌人血量<30% → 固定30伤害
CardEffects.xy_duotian = function(ctx)
    local r = H.base(ctx)
    if ctx.enemy_max_hp > 0 and ctx.enemy_hp / ctx.enemy_max_hp < 0.3 then
        r["damage"] = 30
    end
    return r
end

-- 断水流：弃1张其他手牌 → 伤害+3
CardEffects.xy_duanliu = function(ctx)
    local r = H.base(ctx)
    if ctx.hand_size > 1 then
        r["damage"] = r["damage"] + 3
        r["discard_other_count"] = 1
    end
    return r
end

-- 万象归一：伤害=手牌数×3，弃掉所有其他手牌
CardEffects.xy_wanxiang = function(ctx)
    return Dictionary{
        damage = ctx.hand_size * 3,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        discard_all_others = true,
    }
end

-- ---------- 条件防御 / 技能 ----------

-- 御风而行：手牌≥4 → 格挡+4
CardEffects.xy_yufeng = function(ctx)
    local r = H.base(ctx)
    if ctx.hand_size >= 4 then
        r["block"] = r["block"] + 4
    end
    return r
end

-- 连环计：格挡=本回合已出技能数×2
CardEffects.xy_lianhuan = function(ctx)
    return Dictionary{
        damage = 0,
        block = ctx.skill_played_this_turn * 2,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

-- 后发制人：上一张是攻击 → 格挡8、抽1
CardEffects.xy_houfa = function(ctx)
    local r = H.base(ctx)
    if ctx.last_played_card_type == 0 then
        r["block"] = 8
        r["draw"] = (ctx.draw or 0) + 1
    end
    return r
end

-- 抱元守一：本回合未消耗内力 → 格挡+5
CardEffects.xy_baoyuan = function(ctx)
    local r = H.base(ctx)
    if ctx.energy_used_this_turn == 0 then
        r["block"] = r["block"] + 5
    end
    return r
end

-- 观星望斗：敌人防御意图 → 格挡6
CardEffects.xy_guanxing = function(ctx)
    local r = H.base(ctx)
    if ctx.enemy_intent_type == 1 then
        r["block"] = 6
    end
    return r
end

-- 以彼之道：格挡=敌人意图数值
CardEffects.xy_yibizhi = function(ctx)
    return Dictionary{
        damage = 0,
        block = ctx.enemy_intent_value,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

-- 虚实相生：下2张牌费用-2；若上一张也是技能 → -3
CardEffects.xy_xushi = function(ctx)
    local r = H.base(ctx)
    if ctx.skill_played_this_turn > 0 and ctx.last_played_card_type == 1 then
        r["next_two_discount"] = 3
    else
        r["next_two_discount"] = 2
    end
    return r
end

-- ---------- 抽牌 / 内力 ----------

-- 归藏于渊：抽2；手牌≥5 → 抽3
CardEffects.xy_guicang = function(ctx)
    local r = H.base(ctx)
    r["draw"] = (ctx.draw or 0) + 2
    if ctx.hand_size >= 5 then
        r["draw"] = r["draw"] + 1
    end
    return r
end

-- 浮光掠影：抽1；手牌≤3 → 抽2
CardEffects.xy_fuguang = function(ctx)
    local r = H.base(ctx)
    r["draw"] = (ctx.draw or 0) + 1
    if ctx.hand_size <= 3 then
        r["draw"] = r["draw"] + 1
    end
    return r
end

-- 移形换影：抽1；上一张是身法 → 抽2
CardEffects.xy_yixing = function(ctx)
    local r = H.base(ctx)
    r["draw"] = (ctx.draw or 0) + 1
    if ctx.last_played_card_type == 4 then
        r["draw"] = r["draw"] + 1
    end
    return r
end

-- 寒潭映月：得1内力；内力接近上限 → 得2
CardEffects.xy_hantan = function(ctx)
    local r = H.base(ctx)
    if ctx.player_energy >= ctx.player_max_energy - 1 then
        r["energy_gain"] = 2
    else
        r["energy_gain"] = 1
    end
    return r
end

-- 吐纳归元：回2内力；本回合未额外消耗内力 → 回3
CardEffects.xy_tuna = function(ctx)
    local r = H.base(ctx)
    if ctx.energy_used_this_turn <= ctx.actual_cost then
        r["energy_gain"] = 3
    else
        r["energy_gain"] = 2
    end
    return r
end

-- ---------- 复制 / 手牌调整 ----------

-- 镜花水月：复制上一张打出的非POWER牌到手牌
CardEffects.xy_jinghua = function(ctx)
    local r = H.base(ctx)
    local last_ok = ctx.last_played_card_id ~= ""
            and ctx.last_played_card_id ~= "xy_jinghua"
            and ctx.last_played_card_type ~= 2
    if last_ok then
        r["add_card_id"] = ctx.last_played_card_id
    end
    return r
end

-- 袖里乾坤：将1张其他手牌移到牌顶；移走攻击牌则抽1
CardEffects.xy_xiuli = function(ctx)
    local r = H.base(ctx)
    if ctx.hand_size > 1 then
        r["move_other_to_draw"] = true
        r["move_draw_if_attack"] = true
    end
    return r
end
