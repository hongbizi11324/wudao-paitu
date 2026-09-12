-- ==============================================
-- 卡牌模块 · 通用基础牌（18张）
-- 先加载：建立 CardEffects 表和公共助手
--
-- 约定：每个函数都是纯函数——只读 ctx，返回结果清单 Dictionary，
-- 不调用任何写状态接口。清单由 GDScript 侧 CardExecutor 原子执行。
--
-- ctx 字段（全部只读）：
--   card_id, cost, card_type, damage, block, heal, draw, ["repeat"],
--   armor_break, school,
--   player_hp/max_hp/energy/max_energy/block/chan/jianyi,
--   enemy_hp/max_hp/block/intent_type/intent_value,
--   hand_size, discard_csv（弃牌堆逗号分隔）,
--   last_played_card_id/type, skill_played_this_turn,
--   energy_used_this_turn, cards_played_this_turn, actual_cost,
--   damage_bonus, block_bonus, punch_damage, meditate_gain
--
-- 结果清单字段：
--   damage, repeat_count, armor_break, block, heal, draw, energy_gain,
--   is_consumed, chan_add, chan_reset, jianyi_add, jianyi_reset, jianyi_minus,
--   add_card_id, discard_other_count, discard_all_others,
--   move_other_to_draw, move_draw_if_attack,
--   set_power, next_discount, next_two_discount
-- ==============================================

CardEffects = CardEffects or {}

-- 公共助手：从 ctx 构造基础结果（数值牌通用）
local function base(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = ctx.block + ctx.block_bonus,
        heal = ctx.heal,
        draw = ctx.draw,
        energy_gain = ctx.energy_gain,
        repeat_count = ctx["repeat"] or 1,
        armor_break = ctx.armor_break or 0,
        is_consumed = false,
    }
end

CardHelpers = { base = base }

-- ---------- 攻击 ----------

CardEffects.strike = function(ctx)
    return base(ctx)
end

CardEffects.bash = function(ctx)
    return base(ctx)
end

CardEffects.punch = function(ctx)
    local r = base(ctx)
    r["damage"] = ctx.punch_damage
    return r
end

CardEffects.double_strike = function(ctx)
    return base(ctx)
end

CardEffects.triple_stab = function(ctx)
    return base(ctx)
end

CardEffects.flowing_cloud_sword = function(ctx)
    return base(ctx)
end

CardEffects.sword_energy = function(ctx)
    return base(ctx)
end

CardEffects.whirlwind = function(ctx)
    return base(ctx)
end

CardEffects.vajra_fist = function(ctx)
    return base(ctx)
end

-- ---------- 技能 ----------

CardEffects.defend = function(ctx)
    return base(ctx)
end

CardEffects.iron_wall = function(ctx)
    return base(ctx)
end

CardEffects.iron_shirt = function(ctx)
    return base(ctx)
end

CardEffects.golden_bell = function(ctx)
    return base(ctx)
end

CardEffects.heal = function(ctx)
    return base(ctx)
end

CardEffects.vigor = function(ctx)
    return base(ctx)
end

CardEffects.tactics = function(ctx)
    return base(ctx)
end

-- ---------- 内功 / 身法 ----------

CardEffects.meditate = function(ctx)
    local r = base(ctx)
    r["energy_gain"] = ctx.meditate_gain
    return r
end

CardEffects.light_step = function(ctx)
    return base(ctx)
end
