-- ==============================================
-- 卡牌模块 · 少林（6张）— 禅意流派
-- 叠禅意 → 消耗禅意换格挡/伤害
-- ==============================================

local H = CardHelpers

CardEffects.sl_fist = function(ctx)
    local r = H.base(ctx)
    r["chan_add"] = 1
    return r
end

CardEffects.sl_iron = function(ctx)
    local r = H.base(ctx)
    r["chan_add"] = 1
    return r
end

CardEffects.sl_golden = function(ctx)
    local r = H.base(ctx)
    r["block"] = ctx.block + ctx.block_bonus + ctx.player_chan * 3
    r["chan_reset"] = true
    return r
end

CardEffects.sl_arhat = function(ctx)
    local r = H.base(ctx)
    r["damage"] = ctx.damage + ctx.damage_bonus + ctx.player_chan * 4
    r["chan_reset"] = true
    return r
end

CardEffects.sl_damo = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
        set_power = "damo",
    }
end

-- 菩提心：POWER，每回合开始 禅意+1 格挡+1
CardEffects.sl_bodhi = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
        set_power = "bodhi",
    }
end
