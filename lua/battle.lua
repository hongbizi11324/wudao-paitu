-- ==============================================
-- 武道牌途 · 战斗逻辑（Lua 热更）
--
-- Battle.trigger_powers(ctx) -> void
-- Battle.on_turn_start(ctx) -> Dictionary
-- ==============================================

Battle = {}

-- 每回合开始时触发 POWER 效果
Battle.trigger_powers = function(ctx)
    -- 重置太极两仪标记
    if host and host.player then
        host.player.first_hit_this_turn = true
    end

    -- 达摩一苇：每回合+2禅意+3格挡
    if gd_get_power("damo") then
        gd_player_chan_plus(2)
        gd_player_add_block(3)
        gd_print("达摩一苇：禅意+2，格挡+3")
    end

    -- 八荒六合：每回合回3HP + 随机基础牌
    if gd_get_power("bahuang") then
        gd_player_heal(3)
        local base_pool = {"strike", "defend", "punch", "meditate"}
        -- 简单随机：用时间戳取模
        local idx = math.fmod(os.time(), #base_pool) + 1
        local card_id = base_pool[idx]
        gd_add_card_to_hand(card_id)
        gd_print("八荒六合：回复3HP，获得 " .. card_id)
    end

    -- 逍遥游：手牌上限+2，攻击/内力牌费用-1
    if gd_get_power("xiaoyaoyou") then
        if host and host.player then
            host.player.hand_limit_mod = 2
            host.player.attack_discounted = true
        end
        gd_print("逍遥游：手牌上限+2，攻击/内力牌费用-1")
    end
end

-- 回合开始时计算
Battle.on_turn_start = function(ctx)
    local turn = ctx.turn or 0
    local is_player_turn = ctx.is_player_turn or true

    local result = Dictionary{
        draw_count = 0,
        energy_refill = 0,
    }

    if is_player_turn then
        result["draw_count"] = 4
        result["energy_refill"] = true
    end

    return result
end

return Battle
