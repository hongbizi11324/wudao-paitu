-- ==============================================
-- 卡牌模块 · 武当（5张）— 剑意流派
-- 叠剑意 → 消耗剑意换伤害/抽牌
-- ==============================================

local H = CardHelpers

CardEffects.wd_taiji = function(ctx)
    local r = H.base(ctx)
    r["jianyi_add"] = 1
    return r
end

CardEffects.wd_soft = function(ctx)
    local r = H.base(ctx)
    if ctx.player_jianyi > 0 then
        r["damage"] = ctx.damage + ctx.damage_bonus + 4
        r["jianyi_minus"] = 1
    end
    return r
end

CardEffects.wd_steps = function(ctx)
    local r = H.base(ctx)
    if ctx.player_jianyi > 0 then
        r["draw"] = (ctx.draw or 0) + 1
        r["jianyi_minus"] = 1
    end
    return r
end

CardEffects.wd_heavy = function(ctx)
    return Dictionary{
        damage = ctx.player_jianyi * 5,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        jianyi_reset = true,
    }
end

CardEffects.wd_twoway = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
        set_power = "twoway",
    }
end

-- 三清剑：剑意≥2 时，额外抽1张并获得1内力
CardEffects.wd_sanqing = function(ctx)
    local r = H.base(ctx)
    if ctx.player_jianyi >= 2 then
        r["draw"] = (ctx.draw or 0) + 1
        r["energy_gain"] = (ctx.energy_gain or 0) + 1
    end
    return r
end
