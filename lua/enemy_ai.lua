-- ==============================================
-- 武道牌途 · 敌人 AI（Lua 热更）
--
-- EnemyAI.plan_intent(ctx) -> Dictionary{intent_type, intent_value}
-- EnemyAI.execute_intent(ctx) -> Dictionary{damage_dealt, blocked}
--
-- IntentType: 0=ATTACK, 1=DEFEND
-- FloorType: 0=NORMAL, 1=ELITE, 2=BOSS
-- ==============================================

EnemyAI = {}

-- 意图规划
EnemyAI.plan_intent = function(ctx)
    local floor_type = ctx.floor_type or 0
    local hp = ctx.hp or 10
    local max_hp = ctx.max_hp or 10
    local current_floor = ctx.current_floor or 1
    local rng = ctx.rng or 0

    -- 基础攻击概率
    local attack_chance = 0.65
    if floor_type == 2 then  -- BOSS
        attack_chance = 0.7
    elseif floor_type == 1 then  -- ELITE
        attack_chance = 0.6
    end

    -- BOSS 狂暴阶段：HP < 33% 时必定攻击
    if floor_type == 2 and hp / max_hp < 0.33 then
        attack_chance = 1.0
    end

    local intent_type = 0  -- ATTACK
    local intent_value = 0

    if rng < attack_chance then
        -- 攻击意图
        intent_type = 0
        -- 伤害基础值 + 楼层缩放
        local base_damage = 6 + math.floor(current_floor * 1.5)
        if floor_type == 1 then base_damage = base_damage + 3 end  -- 精英
        if floor_type == 2 then base_damage = base_damage + 6 end  -- BOSS

        -- BOSS 三阶段递增
        if floor_type == 2 then
            if hp / max_hp < 0.33 then
                base_damage = math.floor(base_damage * 2.0)  -- 狂暴 2x
            elseif hp / max_hp < 0.66 then
                base_damage = math.floor(base_damage * 1.5)  -- 二阶段 1.5x
            end
        end

        intent_value = base_damage
    else
        -- 防御意图
        intent_type = 1
        local base_block = 4 + math.floor(current_floor * 0.8)
        if floor_type == 1 then base_block = base_block + 2 end
        if floor_type == 2 then base_block = base_block + 4 end
        intent_value = base_block
    end

    return Dictionary{
        intent_type = intent_type,
        intent_value = intent_value,
    }
end

-- 意图执行
EnemyAI.execute_intent = function(ctx)
    local intent_type = ctx.intent_type or 0
    local intent_value = ctx.intent_value or 0
    local floor_type = ctx.floor_type or 0
    local current_floor = ctx.current_floor or 1
    local player_hp = ctx.player_hp or 60
    local player_block = ctx.player_block or 0

    local result = Dictionary{
        damage_dealt = 0,
        blocked = 0,
        intent_type = intent_type,
    }

    if intent_type == 0 then  -- ATTACK
        local dmg = intent_value
        -- 精英/BOSS 额外伤甲穿透
        local armor_break = 0
        if floor_type == 1 then armor_break = 1 end
        if floor_type == 2 then armor_break = 2 end

        -- 计算格挡吸收
        local absorbed = math.min(player_block, dmg)
        result["blocked"] = absorbed
        result["damage_dealt"] = math.max(0, dmg - player_block)
        result["armor_break"] = armor_break
    else  -- DEFEND
        result["block_gained"] = intent_value
    end

    return result
end

return EnemyAI
