-- ==============================================
-- 卡牌模块 · 逍遥核心（5张）— 北冥/凌波/小无相/折梅/八荒
-- ==============================================

local H = CardHelpers

-- 北冥神掌：伤害+回血
CardEffects.xy_beiming = function(ctx)
    return H.base(ctx)
end

-- 凌波微步：下一张牌费用-1
CardEffects.xy_lingbo = function(ctx)
    local r = H.base(ctx)
    r["next_discount"] = 1
    return r
end

-- 小无相功：复制弃牌堆最后一张非POWER牌到手牌（本牌消耗）
CardEffects.xy_wuxiang = function(ctx)
    local copied_id = nil
    local power_ids = {
        sl_damo = true, wd_twoway = true,
        xy_bahuang = true, xy_xiaoyaoyou = true, xy_wuxiang = true,
        xy_longxiang = true,
    }
    -- discard_csv 为逗号分隔的弃牌堆（旧→新），从最新的往前找
    local ids = {}
    if ctx.discard_csv and ctx.discard_csv ~= "" then
        for id in string.gmatch(ctx.discard_csv, "[^,]+") do
            table.insert(ids, id)
        end
    end
    for i = #ids, 1, -1 do
        if not power_ids[ids[i]] then
            copied_id = ids[i]
            break
        end
    end
    local r = Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
    }
    if copied_id then
        r["add_card_id"] = copied_id
    end
    return r
end

-- 天山折梅手：手牌≤3 → 固定12伤害
CardEffects.xy_zhemel = function(ctx)
    local r = H.base(ctx)
    if ctx.hand_size <= 3 then
        r["damage"] = 12
    end
    return r
end

-- 八荒六合：POWER，本牌消耗
CardEffects.xy_bahuang = function(ctx)
    return Dictionary{
        damage = 0, block = 0, heal = 0, draw = 0, energy_gain = 0,
        is_consumed = true,
        set_power = "bahuang",
    }
end

-- 太虚步：抽2张；本回合未打出攻击牌 → 额外得1内力
CardEffects.xy_taixu = function(ctx)
    local r = H.base(ctx)
    r["draw"] = (ctx.draw or 0) + 2
    if ctx.attacks_played_this_turn == 0 then
        r["energy_gain"] = (ctx.energy_gain or 0) + 1
    end
    return r
end
