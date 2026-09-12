-- ==============================================
-- 武道牌途 · 战斗逻辑（Lua 热更）
--
-- Battle.trigger_powers(ctx) -> 结果清单
--   纯函数：只读 ctx（当前玩家的 POWER 状态），返回触发清单，
--   由 GDScript 侧 CardExecutor.apply_power_trigger 原子执行。
--
-- ctx 字段：
--   powers = { damo, twoway, bahuang, longxiang, xiaoyaoyou }（bool）
--
-- 清单字段：
--   reset_first_hit / block / heal / chan_add / bahuang_card / xiaoyaoyou
-- ==============================================

Battle = {}

Battle.trigger_powers = function(ctx)
    local powers = ctx.powers or {}
    local result = Dictionary{
        reset_first_hit = true,  -- 回合级标记统一在结算侧复位
        block = 0, heal = 0, chan_add = 0,
        bahuang_card = false, xiaoyaoyou = false,
    }

    -- 达摩一苇：每回合 禅意+2、格挡+3
    if powers.damo then
        result["chan_add"] = result["chan_add"] + 2
        result["block"] = result["block"] + 3
    end

    -- 八荒六合：每回合 回复3HP + 随机基础牌（随机在宿主侧执行）
    if powers.bahuang then
        result["heal"] = result["heal"] + 3
        result["bahuang_card"] = true
    end

    -- 逍遥游：手牌上限+2，攻击/内力牌费用-1
    if powers.xiaoyaoyou then
        result["xiaoyaoyou"] = true
    end

    return result
end

return Battle
