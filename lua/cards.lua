-- ==============================================
-- 武道牌途 · 全卡牌效果（Lua 热更）
--
-- CardEffects[card_id] = function(ctx) -> Dictionary
--
-- ctx 字段: card_id, cost, card_type, damage, block, heal, draw,
--   energy_gain, repeat, armor_break, school,
--   player_hp, player_max_hp, player_energy, player_max_energy, player_block,
--   player_chan, player_jianyi, player_next_card_discount,
--   enemy_hp, enemy_max_hp, enemy_block, enemy_intent_type, enemy_intent_value,
--   hand_size, last_played_card_id, last_played_card_type,
--   skill_played_this_turn, energy_used_this_turn, actual_cost,
--   damage_bonus, block_bonus
--
-- 返回 Dictionary: damage, block, heal, draw, energy_gain, armor_break,
--   repeat_count, is_consumed, special
-- ==============================================

CardEffects = {}

-- ========== 通用基础卡 ==========

CardEffects.strike = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.defend = function(ctx)
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.bash = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.punch = function(ctx)
    return Dictionary{
        damage = gd_get_punch_damage(),
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.meditate = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0,
        energy_gain = gd_get_meditate_gain(),
        is_consumed = false,
    }
end

CardEffects.heal = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = ctx.heal,
        draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.double_strike = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        repeat_count = ctx["repeat"] or 2,
        is_consumed = false,
    }
end

CardEffects.triple_stab = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        repeat_count = ctx["repeat"] or 3,
        is_consumed = false,
    }
end

CardEffects.light_step = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0,
        draw = ctx.draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.flowing_cloud_sword = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = ctx.draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.sword_energy = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.whirlwind = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = ctx.draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.iron_shirt = function(ctx)
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.iron_wall = function(ctx)
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.golden_bell = function(ctx)
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.tactics = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0,
        draw = ctx.draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.vigor = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = ctx.heal,
        draw = ctx.draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.vajra_fist = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

-- ========== 🏯 少林 ==========

CardEffects.sl_fist = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "chan_plus_1",
    }
end

CardEffects.sl_iron = function(ctx)
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "chan_plus_1",
    }
end

CardEffects.sl_golden = function(ctx)
    return Dictionary{
        damage = 0,
        block = ctx.block + ctx.block_bonus + ctx.player_chan * 3,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "chan_reset",
    }
end

CardEffects.sl_arhat = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus + ctx.player_chan * 4,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "chan_reset",
    }
end

CardEffects.sl_damo = function(ctx)
    gd_set_power("damo", true)
    gd_print("达摩一苇 激活！")
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
end

-- ========== ☯️ 武当 ==========

CardEffects.wd_taiji = function(ctx)
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "jianyi_plus_1",
    }
end

CardEffects.wd_soft = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.player_jianyi > 0 then
        return Dictionary{
            damage = dmg + 4, block = 0, heal = 0, draw = 0, energy_gain = 0,
            is_consumed = false,
            special = "jianyi_minus_1",
        }
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.wd_steps = function(ctx)
    local extra_draw = 0
    if ctx.player_jianyi > 0 then
        extra_draw = 1
        gd_player_jianyi_minus(1)
        gd_print("梯云纵 消耗1剑意 → 多抽1")
    end
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = extra_draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.wd_heavy = function(ctx)
    local dmg = ctx.player_jianyi * 5
    gd_print("真武重剑 消耗" .. ctx.player_jianyi .. "层剑意 → 伤害" .. dmg)
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "jianyi_reset",
    }
end

CardEffects.wd_twoway = function(ctx)
    gd_set_power("twoway", true)
    if host and host.player then
        host.player.first_hit_this_turn = true
    end
    gd_print("太极两仪 激活！")
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
end

-- ========== 🦋 逍遥 ==========

CardEffects.xy_beiming = function(ctx)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = ctx.heal, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_lingbo = function(ctx)
    gd_player_set_next_discount(1)
    gd_print("凌波微步 下张牌费用-1")
    return Dictionary{
        damage = 0, block = ctx.block + ctx.block_bonus,
        heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_wuxiang = function(ctx)
    -- 从弃牌堆找最后一张非POWER牌复制
    local discard_ids = gd_discard_pile_ids()
    local copied_id = nil
    local power_ids = { sl_damo = true, wd_twoway = true, xy_bahuang = true, xy_wuxiang = true }
    for i = #discard_ids, 1, -1 do
        if not power_ids[discard_ids[i]] then
            copied_id = discard_ids[i]
            break
        end
    end
    if copied_id then
        gd_add_card_to_hand(copied_id)
        gd_print("小无相功 复制 -> " .. copied_id)
    else
        gd_print("小无相功 弃牌堆无牌可复制")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
end

CardEffects.xy_zhemel = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.hand_size <= 3 then
        dmg = 12
        gd_print("天山折梅手 手牌≤3 → 伤害12")
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_bahuang = function(ctx)
    gd_set_power("bahuang", true)
    gd_print("八荒六合 激活！")
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
end

-- ========== 🦋 云芷新卡 ==========

CardEffects.xy_xiaoyaoyou = function(ctx)
    gd_set_power("xiaoyaoyou", true)
    gd_print("逍遥游 激活！")
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
end

CardEffects.xy_xingluo = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.hand_size >= 6 then
        dmg = dmg + 5
        gd_print("星落九天 手牌≥6 → 伤害" .. dmg)
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_fengjuan = function(ctx)
    local bonus = math.min(ctx.hand_size, 4)
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus + bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_guicang = function(ctx)
    local extra_draw = 2
    if ctx.hand_size >= 5 then
        extra_draw = 3
        gd_print("归藏于渊 手牌≥5 → 抽3")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0,
        draw = extra_draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_fuguang = function(ctx)
    local extra_draw = 1
    if ctx.hand_size <= 3 then
        extra_draw = 2
        gd_print("浮光掠影 手牌≤3 → 抽2")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0,
        draw = extra_draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_yufeng = function(ctx)
    local blk = ctx.block + ctx.block_bonus
    if ctx.hand_size >= 4 then
        blk = blk + 4
        gd_print("御风而行 手牌≥4 → 格挡" .. blk)
    end
    return Dictionary{
        damage = 0, block = blk, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_duanliu = function(ctx)
    -- 弃第一张手牌（非当前牌），伤害+3
    local hand_ids = gd_hand_card_ids()
    -- 找到不是当前牌的第一张
    local target_idx = -1
    for i, id in ipairs(hand_ids) do
        target_idx = i - 1  -- GDScript 索引从 0 开始
        break
    end
    if target_idx >= 0 then
        gd_discard_card_by_index(target_idx)
        gd_print("断水流 弃牌→伤害+3")
        return Dictionary{
            damage = ctx.damage + ctx.damage_bonus + 3,
            block = 0, heal = 0, draw = 0, energy_gain = 0,
            is_consumed = false,
        }
    end
    return Dictionary{
        damage = ctx.damage + ctx.damage_bonus,
        block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_wanxiang = function(ctx)
    local hand_size = ctx.hand_size
    local dmg = hand_size * 3
    gd_print("万象归一 手牌" .. hand_size .. "张 → 伤害" .. dmg)
    -- 弃掉所有手牌（非当前牌）
    local hand_ids = gd_hand_card_ids()
    -- 从后往前弃，避免索引错位
    for i = #hand_ids, 1, -1 do
        gd_discard_card_by_index(i - 1)
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_xiuli = function(ctx)
    -- 将1张手牌移至牌顶。若移除的是攻击牌，抽1
    local hand_ids = gd_hand_card_ids()
    if #hand_ids > 1 then
        gd_move_card_to_draw_pile(0)
        gd_print("袖里乾坤 移走1张手牌至牌顶")
        -- 判断移走的牌是否是攻击牌（card_type == 0）
        local moved_id = hand_ids[1]
        local path = "res://resources/cards/" .. moved_id .. ".tres"
        -- 简单判断：攻击牌以这些前缀开头或是基础攻击牌
        local attack_ids = {
            strike = true, bash = true, punch = true, double_strike = true,
            triple_stab = true, flowing_cloud_sword = true, sword_energy = true,
            whirlwind = true, vajra_fist = true, sl_fist = true, sl_arhat = true,
            wd_soft = true, wd_heavy = true, xy_beiming = true, xy_zhemel = true,
            xy_xingluo = true, xy_fengjuan = true, xy_duanliu = true, xy_wanxiang = true,
            xy_xixing = true, xy_fange = true, xy_duotian = true, xy_qiguan = true,
        }
        if attack_ids[moved_id] then
            gd_print("袖里乾坤 移走攻击牌 → 抽1")
            return Dictionary{
                damage = 0, block = 0, heal = 0, draw = 1, energy_gain = 0,
                is_consumed = false,
            }
        end
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_lianhuan = function(ctx)
    local blk = ctx.skill_played_this_turn * 2
    gd_print("连环计 本回合打出" .. ctx.skill_played_this_turn .. "张技能 → 格挡" .. blk)
    return Dictionary{
        damage = 0, block = blk, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_houfa = function(ctx)
    local blk = ctx.block + ctx.block_bonus
    local extra_draw = 0
    if ctx.last_played_card_type == 0 then  -- ATTACK
        blk = 8
        extra_draw = 1
        gd_print("后发制人 上张是攻击 → 格挡8, 抽1")
    end
    return Dictionary{
        damage = 0, block = blk, heal = 0, draw = extra_draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_jinghua = function(ctx)
    if ctx.last_played_card_id ~= "" and ctx.last_played_card_id ~= "xy_jinghua" then
        gd_add_card_to_hand(ctx.last_played_card_id)
        gd_print("镜花水月 复制 -> " .. ctx.last_played_card_id)
    else
        gd_print("镜花水月 无上一张牌，跳过")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_wujian = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.last_played_card_type == 1 then  -- SKILL
        dmg = dmg * 2
        gd_print("无间道 上张是技能 → 伤害" .. dmg)
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_xushi = function(ctx)
    -- 下2张牌费用-2，连续技能则-3
    local discount = 2
    if ctx.skill_played_this_turn > 0 and ctx.last_played_card_type == 1 then
        discount = 3
        gd_print("虚实相生 连续技能 → 下3减")
    else
        gd_print("虚实相生 下2减")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
        special = "set_discount_" .. discount,
    }
end

CardEffects.xy_yixing = function(ctx)
    local extra_draw = 1
    if ctx.last_played_card_type == 4 then  -- MOVEMENT
        extra_draw = 2
        gd_print("移形换影 上张是移动 → 抽2")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = extra_draw, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_hantan = function(ctx)
    local eg = 1
    if ctx.player_energy >= ctx.player_max_energy - 1 then
        eg = 2
        gd_print("寒潭映月 满内力 → 得2内力")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = eg,
        is_consumed = false,
    }
end

CardEffects.xy_qiguan = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.player_energy >= 2 then
        gd_player_spend_energy(2)
        dmg = dmg + 6
        gd_print("气贯长虹 额外+2内力 → 伤害" .. dmg)
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_tuna = function(ctx)
    local eg = 2
    if ctx.energy_used_this_turn <= ctx.actual_cost then
        eg = 3
        gd_print("吐纳归元 未额外消耗内力 → 回3内力")
    end
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = eg,
        is_consumed = false,
    }
end

CardEffects.xy_longxiang = function(ctx)
    gd_set_power("longxiang", true)
    gd_print("龙象般若 激活！")
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
end

CardEffects.xy_baoyuan = function(ctx)
    local blk = ctx.block + ctx.block_bonus
    if ctx.energy_used_this_turn == 0 then
        blk = blk + 5
        gd_print("抱元守一 未消耗内力 → 格挡" .. blk)
    end
    return Dictionary{
        damage = 0, block = blk, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_xixing = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.enemy_block > 0 then
        dmg = dmg + 5
        gd_player_heal(dmg)
        gd_print("吸星大法 敌有护盾 → 伤害" .. dmg .. ", 回" .. dmg .. "HP")
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_guanxing = function(ctx)
    local blk = ctx.block + ctx.block_bonus
    if ctx.enemy_intent_type == 1 then  -- DEFEND
        blk = 6
        gd_print("观星望斗 敌人防御 → 格挡6")
    end
    return Dictionary{
        damage = 0, block = blk, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_fange = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.enemy_intent_type == 0 then  -- ATTACK
        dmg = 16
        gd_print("反戈一击 敌人攻击 → 伤害" .. dmg)
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_yibizhi = function(ctx)
    local blk = ctx.enemy_intent_value
    gd_print("以彼之道 复制" .. blk .. "点格挡")
    return Dictionary{
        damage = 0, block = blk, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

CardEffects.xy_duotian = function(ctx)
    local dmg = ctx.damage + ctx.damage_bonus
    if ctx.enemy_max_hp > 0 and ctx.enemy_hp / ctx.enemy_max_hp < 0.3 then
        dmg = 30
        gd_print("夺天造化 敌人血量<30% → 伤害" .. dmg)
    end
    return Dictionary{
        damage = dmg, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = false,
    }
end

return CardEffects
