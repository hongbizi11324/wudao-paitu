#!/usr/bin/env node
/**
 * 武道牌途 MCP 服务器
 * ====================
 * 为 Godot 卡牌项目《武道牌途》提供 AI 辅助工具
 * 通过 Model Context Protocol (stdio) 暴露项目分析工具
 *
 * 使用方式：
 *   openclaw mcp set wdpt '{"command":"node","args":["/mnt/e/godotsave/card/mcp-server.js"]}'
 */

const fs = require('fs');
const path = require('path');

// ============================================================
// 项目路径
// ============================================================
const PROJECT_ROOT = '/mnt/e/godotsave/card';
const SCRIPTS_DIR = path.join(PROJECT_ROOT, 'scripts');
const SCENES_DIR = path.join(PROJECT_ROOT, 'scenes');
const CARDS_DIR = path.join(PROJECT_ROOT, 'resources/cards');
const AUTOLOAD_DIR = path.join(PROJECT_ROOT, 'autoload');
const ASSETS_DIR = path.join(PROJECT_ROOT, 'assets');

// ============================================================
// 工具函数
// ============================================================

function parseTres(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const data = {};
    const lines = content.split('\n');
    let currentSection = null;
    for (const line of lines) {
      const sectionMatch = line.match(/^\[(.+)\]$/);
      if (sectionMatch) {
        currentSection = sectionMatch[1];
        if (!data[currentSection]) data[currentSection] = {};
        continue;
      }
      const kvMatch = line.match(/^(\w+)\s*=\s*(.*)$/);
      if (kvMatch) {
        const key = kvMatch[1];
        let value = kvMatch[2].trim();
        // 去除引号
        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.slice(1, -1);
        }
        if (currentSection) {
          data[currentSection][key] = value;
        } else {
          data[key] = value;
        }
      }
    }
    return data;
  } catch (e) {
    return { _error: e.message };
  }
}

function readGdFile(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    return {
      path: filePath,
      name: path.basename(filePath),
      lines: lines.length,
      size: content.length,
      content: content,
      keyStructures: extractKeyStructures(lines)
    };
  } catch (e) {
    return { _error: e.message };
  }
}

function extractKeyStructures(lines) {
  const structures = [];
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();

    // 类定义
    const classMatch = trimmed.match(/^(class_name\s+\w+|extends\s+\w+)/);
    if (classMatch) {
      structures.push({ line: i + 1, type: 'class', text: classMatch[1] });
    }

    // 信号
    const signalMatch = trimmed.match(/^signal\s+(\w+)/);
    if (signalMatch) {
      structures.push({ line: i + 1, type: 'signal', text: signalMatch[1] });
    }

    // 枚举
    const enumMatch = trimmed.match(/^enum\s+(\w+)/);
    if (enumMatch) {
      structures.push({ line: i + 1, type: 'enum', text: enumMatch[1] });
    }

    // 函数/方法
    const funcMatch = trimmed.match(/^(func\s+\w+)/);
    if (funcMatch) {
      structures.push({ line: i + 1, type: 'function', text: funcMatch[1] });
    }

    // 变量
    const varMatch = trimmed.match(/^(var\s+\w+)/);
    if (varMatch) {
      structures.push({ line: i + 1, type: 'variable', text: varMatch[1] });
    }
  }
  return structures;
}

function listFiles(dir, ext = null) {
  try {
    const files = fs.readdirSync(dir);
    return files
      .filter(f => !ext || f.endsWith(ext))
      .filter(f => !f.endsWith('.uid'))
      .map(f => ({
        name: f,
        path: path.join(dir, f),
        size: fs.statSync(path.join(dir, f)).size
      }));
  } catch (e) {
    return [];
  }
}

// 解析卡牌 tres 文件为结构化数据
function parseCardResource(filePath) {
  const raw = parseTres(filePath);
  const cardId = path.basename(filePath, '.tres');
  const typeMap = { '0': 'ATTACK', '1': 'SKILL', '2': 'POWER', '3': 'INNER', '4': 'MOVEMENT' };
  return {
    id: cardId,
    name: raw?.resource?.card_name || cardId,
    type: typeMap[raw?.resource?.card_type] || 'UNKNOWN',
    cost: parseInt(raw?.resource?.cost || 0),
    damage: parseInt(raw?.resource?.damage || 0),
    block: parseInt(raw?.resource?.block || 0),
    heal: parseInt(raw?.resource?.heal || 0),
    draw: parseInt(raw?.resource?.draw || 0),
    repeat: parseInt(raw?.resource?.repeat || 0),
    retain: raw?.resource?.retain === 'true',
    energy_gain: parseInt(raw?.resource?.energy_gain || 0),
    armor_break: parseInt(raw?.resource?.armor_break || 0),
    description: raw?.resource?.description || ''
  };
}

function searchInFile(filePath, query) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const lines = content.split('\n');
    const matches = [];
    const lowerQuery = query.toLowerCase();
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().includes(lowerQuery)) {
        matches.push({
          line: i + 1,
          text: lines[i].trim(),
          file: path.basename(filePath)
        });
      }
    }
    return matches;
  } catch (e) {
    return [];
  }
}

// ============================================================
// MCP 协议实现
// ============================================================

class MCPServer {
  constructor() {
    this.buffer = '';
    this.tools = this.defineTools();
  }

  defineTools() {
    return [
      {
        name: 'project_info',
        description: '获取武道牌途项目概况：文件数、卡牌数、脚本数、场景数等',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'list_scripts',
        description: '列出项目的所有 GDScript 文件及其概要信息',
        inputSchema: {
          type: 'object',
          properties: {
            includeContent: {
              type: 'boolean',
              description: '是否同时返回脚本内容（默认 false）'
            }
          }
        }
      },
      {
        name: 'read_script',
        description: '读取指定脚本文件的完整内容',
        inputSchema: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: '脚本文件名（如 main.gd）'
            }
          },
          required: ['name']
        }
      },
      {
        name: 'list_cards',
        description: '列出所有卡牌及其基础属性（费用/伤害/格挡/类型等）',
        inputSchema: {
          type: 'object',
          properties: {
            detailed: {
              type: 'boolean',
              description: '是否显示详细属性（默认 false）'
            }
          }
        }
      },
      {
        name: 'read_card',
        description: '读取指定卡牌的完整数据',
        inputSchema: {
          type: 'object',
          properties: {
            cardId: {
              type: 'string',
              description: '卡牌 ID（如 strike、defend、bash）'
            }
          },
          required: ['cardId']
        }
      },
      {
        name: 'search_code',
        description: '在项目 GDScript 文件中搜索指定内容',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: '搜索关键词'
            }
          },
          required: ['query']
        }
      },
      {
        name: 'card_balance_report',
        description: '生成卡牌平衡性分析报告：费用/伤害比、类型分布、连击组合等',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'scene_structure',
        description: '分析场景文件结构，列出节点树信息',
        inputSchema: {
          type: 'object',
          properties: {
            sceneName: {
              type: 'string',
              description: '场景文件名（如 main.tscn），留空则列出所有场景概览'
            }
          }
        }
      },
      {
        name: 'dependency_graph',
        description: '分析项目中的类依赖关系：extends、class_name、preload 等',
        inputSchema: {
          type: 'object',
          properties: {}
        }
      },
      {
        name: 'error_database',
        description: '查询项目的踩坑记录数据库（错误总结）',
        inputSchema: {
          type: 'object',
          properties: {
            category: {
              type: 'string',
              description: '分类筛选（如 "语法"、"场景"、"逻辑"、"类型"），留空返回全部'
            }
          }
        }
      }
    ];
  }

  async handleRequest(request) {
    const { method, params, id } = request;

    try {
      switch (method) {
        case 'initialize':
          return this.handleInitialize(params);
        case 'tools/list':
          return { tools: this.tools };
        case 'tools/call':
          return await this.handleToolCall(params);
        default:
          throw new Error(`Unknown method: ${method}`);
      }
    } catch (error) {
      if (id !== undefined && id !== null) {
        return { error: { code: -32603, message: error.message } };
      }
      return null;
    }
  }

  handleInitialize(params) {
    return {
      protocolVersion: '2024-11-05',
      serverInfo: {
        name: '武道牌途 MCP',
        version: '1.0.0'
      },
      capabilities: {
        tools: {}
      }
    };
  }

  async handleToolCall(params) {
    const { name, arguments: args } = params;

    switch (name) {
      case 'project_info': return this.toolProjectInfo();
      case 'list_scripts': return this.toolListScripts(args);
      case 'read_script': return this.toolReadScript(args);
      case 'list_cards': return this.toolListCards(args);
      case 'read_card': return this.toolReadCard(args);
      case 'search_code': return this.toolSearchCode(args);
      case 'card_balance_report': return this.toolCardBalanceReport();
      case 'scene_structure': return this.toolSceneStructure(args);
      case 'dependency_graph': return this.toolDependencyGraph();
      case 'error_database': return this.toolErrorDatabase(args);
      default: throw new Error(`Unknown tool: ${name}`);
    }
  }

  toolProjectInfo() {
    const scripts = listFiles(SCRIPTS_DIR, '.gd');
    const scenes = listFiles(SCENES_DIR, '.tscn');
    const cards = listFiles(CARDS_DIR, '.tres');

    const projectGdPath = path.join(PROJECT_ROOT, 'project.godot');
    const projectConfig = parseTres(projectGdPath);

    const totalLoc = scripts.reduce((sum, s) => {
      try {
        const content = fs.readFileSync(s.path, 'utf-8');
        return sum + content.split('\n').length;
      } catch { return sum; }
    }, 0);

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          projectName: projectConfig?.application?.['config/name'] || '武道牌途',
          engine: 'Godot 4.7',
          rootScene: projectConfig?.application?.['run/main_scene'] || 'start_screen.tscn',
          resolution: `${projectConfig?.display?.['window/size/viewport_width'] || 1280}x${projectConfig?.display?.['window/size/viewport_height'] || 720}`,
          stretch: projectConfig?.display?.['window/stretch/mode'] || 'canvas_items',
          autoload: projectConfig?.autoload || {},
          fileCounts: {
            scripts: scripts.length,
            scenes: scenes.length,
            cardResources: cards.length,
            autoload: listFiles(AUTOLOAD_DIR, '.gd').length,
          },
          totalLinesOfCode: totalLoc,
          cardPool: 18,
          starterDeck: 10,
          realmCount: 9,
          maxFloor: '∞（每6层一个Boss）',
        }, null, 2)
      }]
    };
  }

  toolListScripts(args) {
    const includeContent = args?.includeContent || false;
    const files = listFiles(SCRIPTS_DIR, '.gd');
    // 也包含 autoload 脚本
    const autoloadFiles = listFiles(AUTOLOAD_DIR, '.gd');

    const allFiles = [...files, ...autoloadFiles].map(f => {
      const gd = readGdFile(f.path);
      const result = {
        name: gd.name,
        path: f.path.replace(PROJECT_ROOT, ''),
        lines: gd.lines,
        classes: gd.keyStructures.filter(s => s.type === 'class').map(s => s.text),
        functions: gd.keyStructures.filter(s => s.type === 'function').map(s => s.text),
        signals: gd.keyStructures.filter(s => s.type === 'signal').map(s => s.text),
        variables: gd.keyStructures.filter(s => s.type === 'variable').map(s => s.text),
      };
      if (includeContent) result.content = gd.content;
      return result;
    });

    return {
      content: [{
        type: 'text',
        text: JSON.stringify(allFiles, null, 2)
      }]
    };
  }

  toolReadScript(args) {
    const { name } = args;
    const searchPaths = [SCRIPTS_DIR, AUTOLOAD_DIR];

    for (const dir of searchPaths) {
      const filePath = path.join(dir, name);
      if (fs.existsSync(filePath)) {
        const gd = readGdFile(filePath);
        return {
          content: [{
            type: 'text',
            text: JSON.stringify({
              name: gd.name,
              path: gd.path.replace(PROJECT_ROOT, ''),
              lines: gd.lines,
              size: gd.size,
              structures: gd.keyStructures,
              content: gd.content
            }, null, 2)
          }]
        };
      }
    }

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ error: `文件 ${name} 未找到，可用脚本：${listFiles(SCRIPTS_DIR, '.gd').map(f => f.name).join(', ')}` })
      }]
    };
  }

  toolListCards(args) {
    const detailed = args?.detailed || false;
    const cardFiles = listFiles(CARDS_DIR, '.tres');
    const cards = cardFiles.map(f => parseCardResource(f.path));

    if (detailed) {
      return {
        content: [{
          type: 'text',
          text: JSON.stringify(cards, null, 2)
        }]
      };
    }

    // 简略表格形式
    const summary = cards.map(c => ({
      id: c.id,
      name: c.name,
      type: c.type,
      cost: c.cost,
      damage: c.damage || '-',
      block: c.block || '-',
      heal: c.heal || '-',
      draw: c.draw || '-',
      description: c.description
    }));

    // 按类型分组
    const byType = {};
    for (const c of summary) {
      if (!byType[c.type]) byType[c.type] = [];
      byType[c.type].push(c);
    }

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({ total: cards.length, byType, cards: summary }, null, 2)
      }]
    };
  }

  toolReadCard(args) {
    const { cardId } = args;
    const cardPath = path.join(CARDS_DIR, `${cardId}.tres`);

    if (!fs.existsSync(cardPath)) {
      const available = listFiles(CARDS_DIR, '.tres').map(f => f.name.replace('.tres', ''));
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ error: `卡牌 "${cardId}" 未找到`, availableCards: available })
        }]
      };
    }

    const card = parseCardResource(cardPath);
    return {
      content: [{
        type: 'text',
        text: JSON.stringify(card, null, 2)
      }]
    };
  }

  toolSearchCode(args) {
    const { query } = args;
    const searchDirs = [SCRIPTS_DIR, AUTOLOAD_DIR];
    const allMatches = [];

    for (const dir of searchDirs) {
      const files = listFiles(dir, '.gd');
      for (const file of files) {
        const matches = searchInFile(file.path, query);
        allMatches.push(...matches);
      }
    }

    // 去重并按行号分组
    const byFile = {};
    for (const m of allMatches) {
      if (!byFile[m.file]) byFile[m.file] = [];
      byFile[m.file].push(m);
    }

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          query,
          totalMatches: allMatches.length,
          files: Object.keys(byFile).length,
          results: byFile
        }, null, 2)
      }]
    };
  }

  toolCardBalanceReport() {
    const cardFiles = listFiles(CARDS_DIR, '.tres');
    const cards = cardFiles.map(f => parseCardResource(f.path));

    // 类型分布
    const typeDist = {};
    for (const c of cards) {
      typeDist[c.type] = (typeDist[c.type] || 0) + 1;
    }

    // 费用分布
    const costDist = {};
    for (const c of cards) {
      const key = `${c.cost}费`;
      costDist[key] = (costDist[key] || 0) + 1;
    }

    // 伤害卡（每费伤害率）
    const damageCards = cards.filter(c => c.damage > 0);
    const avgDmgPerCost = damageCards.length > 0
      ? (damageCards.reduce((s, c) => s + c.damage / c.cost, 0) / damageCards.length).toFixed(2)
      : 'N/A';

    // 格挡卡（每费格挡率）
    const blockCards = cards.filter(c => c.block > 0);
    const avgBlockPerCost = blockCards.length > 0
      ? (blockCards.reduce((s, c) => s + c.block / c.cost, 0) / blockCards.length).toFixed(2)
      : 'N/A';

    // 特定组合检测
    const combos = [];
    // 打击+连击：配合重复效果
    const hasDoubleStrike = cards.find(c => c.id === 'double_strike');
    const hasStrike = cards.find(c => c.id === 'strike');
    if (hasDoubleStrike && hasStrike) {
      combos.push({ combo: '双重打击', cards: ['strike', 'double_strike'], note: '6伤 + 5伤x2 = 16伤/2费' });
    }

    // 抽牌链
    const drawCards = cards.filter(c => c.draw > 0);
    if (drawCards.length > 0) {
      combos.push({ combo: '过牌循环', cards: drawCards.map(c => c.id), note: `${drawCards.length}张牌有抽牌效果` });
    }

    // 蓄力牌
    const innerCards = cards.filter(c => c.card_type === '3' || c.energy_gain > 0);
    if (innerCards.length > 0) {
      combos.push({ combo: '内力循环', cards: innerCards.map(c => c.id), note: `${innerCards.length}张牌产生内力` });
    }

    // 保留牌
    const retainCards = cards.filter(c => c.retain);
    if (retainCards.length > 0) {
      combos.push({ combo: '保留策略', cards: retainCards.map(c => c.id), note: '保留牌不会在回合末弃掉，可累积使用' });
    }

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          totalCards: cards.length,
          typeDistribution: typeDist,
          costDistribution: costDist,
          avgDamagePerCost: avgDmgPerCost,
          avgBlockPerCost: avgBlockPerCost,
          highestDamage: cards.reduce((best, c) => c.damage > (best.damage || 0) ? c : best, { damage: 0 }),
          highestBlock: cards.reduce((best, c) => c.block > (best.block || 0) ? c : best, { block: 0 }),
          selfHealCards: cards.filter(c => c.heal > 0).map(c => ({ id: c.id, heal: c.heal, cost: c.cost })),
          drawCards: cards.filter(c => c.draw > 0).map(c => ({ id: c.id, draw: c.draw, cost: c.cost })),
          retainCards: cards.filter(c => c.retain).map(c => c.id),
          armorBreakCards: cards.filter(c => c.armor_break > 0).map(c => ({ id: c.id, armorBreak: c.armor_break, cost: c.cost })),
          potentialCombos: combos,
          suggestions: this.generateBalanceSuggestions(cards)
        }, null, 2)
      }]
    };
  }

  generateBalanceSuggestions(cards) {
    const suggestions = [];

    // 检测是否有0费伤害牌且未做好平衡
    const zeroCostDamage = cards.filter(c => c.cost === 0 && c.damage > 0);
    if (zeroCostDamage.length > 0) {
      suggestions.push('存在0费伤害牌，注意不要破坏费用曲线');
    }

    // 检测是否有费用过高的牌却效果一般
    const expensiveCards = cards.filter(c => c.cost >= 3);
    for (const c of expensiveCards) {
      const eff = c.damage + c.block + c.heal * 1.5 + c.draw * 3;
      if (eff / c.cost < 4) {
        suggestions.push(`【${c.name}】${c.cost}费但效果值约${eff}，性价比偏低，考虑加强`);
      }
    }

    // 检测是否缺少某种类型的牌
    const types = new Set(cards.map(c => c.type));
    const allTypes = ['ATTACK', 'SKILL', 'POWER', 'INNER', 'MOVEMENT'];
    const missing = allTypes.filter(t => !types.has(t));
    if (missing.length > 0) {
      suggestions.push(`缺少以下卡牌类型：${missing.join(', ')}，可考虑补充`);
    }

    // 检测回复手段
    const healCards = cards.filter(c => c.heal > 0);
    if (healCards.length < 2) {
      suggestions.push('回复手段较少（仅1张治疗牌），战斗续航可能不足');
    }

    // 检测过牌能力
    const drawCards = cards.filter(c => c.draw > 0);
    if (drawCards.length < 2) {
      suggestions.push('过牌能力弱，牌组循环效率可能偏低');
    }

    if (suggestions.length === 0) suggestions.push('当前卡池平衡性良好，无需调整');

    return suggestions;
  }

  toolSceneStructure(args) {
    const { sceneName } = args;

    if (sceneName) {
      const scenePath = path.join(SCENES_DIR, sceneName);
      if (!fs.existsSync(scenePath)) {
        const available = listFiles(SCENES_DIR, '.tscn').map(f => f.name);
        return {
          content: [{
            type: 'text',
            text: JSON.stringify({ error: `场景 "${sceneName}" 未找到`, availableScenes: available })
          }]
        };
      }

      const content = fs.readFileSync(scenePath, 'utf-8');
      const lines = content.split('\n');
      const nodes = [];
      for (const line of lines) {
        const match = line.match(/^\[node\s+name="([^"]+)"(?:\s+type="([^"]+))?(?:\s+parent="([^"]+))?/);
        if (match) {
          nodes.push({
            name: match[1],
            type: match[2] || 'Node',
            parent: match[3] || '.'
          });
        }
      }

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            scene: sceneName,
            totalNodes: nodes.length,
            nodes: nodes,
            rawLines: lines.length
          }, null, 2)
        }]
      };
    }

    // 列出所有场景概览
    const scenes = listFiles(SCENES_DIR, '.tscn');
    const sceneInfo = scenes.map(s => {
      const content = fs.readFileSync(s.path, 'utf-8');
      const lines = content.split('\n');
      const nodeCount = lines.filter(l => l.startsWith('[node ')).length;
      return {
        name: s.name,
        size: s.size,
        nodes: nodeCount,
        lines: lines.length
      };
    });

    return {
      content: [{
        type: 'text',
        text: JSON.stringify(sceneInfo, null, 2)
      }]
    };
  }

  toolDependencyGraph() {
    const searchDirs = [SCRIPTS_DIR, AUTOLOAD_DIR];
    const deps = [];

    for (const dir of searchDirs) {
      const files = listFiles(dir, '.gd');
      for (const file of files) {
        const content = fs.readFileSync(file.path, 'utf-8');
        const lines = content.split('\n');
        const dependencies = {
          file: file.name,
          path: file.path.replace(PROJECT_ROOT, ''),
          extends: null,
          class_name: null,
          autoloads: [],
          preloads: [],
          scenes: []
        };

        for (const line of lines) {
          const trimmed = line.trim();
          const extMatch = trimmed.match(/^extends\s+(\S+)/);
          if (extMatch) dependencies.extends = extMatch[1];

          const clsMatch = trimmed.match(/^class_name\s+(\S+)/);
          if (clsMatch) dependencies.class_name = clsMatch[1];

          const loadMatch = trimmed.match(/(preload|load)\s*\(\s*"([^"]+)"/);
          if (loadMatch) {
            const target = loadMatch[2];
            if (target.endsWith('.gd')) {
              dependencies.autoloads.push(target);
            } else if (target.endsWith('.tscn')) {
              dependencies.scenes.push(target);
            } else {
              dependencies.preloads.push(target);
            }
          }
        }

        deps.push(dependencies);
      }
    }

    // 构建依赖图
    const classNames = {};
    for (const d of deps) {
      if (d.class_name) classNames[d.class_name] = d.file;
    }

    const graphEdges = [];
    for (const d of deps) {
      if (d.extends) {
        const target = classNames[d.extends] || d.extends;
        graphEdges.push({ from: d.file, to: target, type: 'extends' });
      }
      for (const s of d.scenes) {
        graphEdges.push({ from: d.file, to: path.basename(s), type: 'scene_ref' });
      }
    }

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          files: deps,
          classRegistry: classNames,
          dependencyEdges: graphEdges
        }, null, 2)
      }]
    };
  }

  toolErrorDatabase(args) {
    const category = args?.category || '';
    const errorPath = path.join(PROJECT_ROOT, '错误总结.md');

    if (!fs.existsSync(errorPath)) {
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ error: '错误总结文件不存在' })
        }]
      };
    }

    const content = fs.readFileSync(errorPath, 'utf-8');
    const lines = content.split('\n');

    // 解析分类
    const sections = [];
    let currentSection = null;
    let currentContent = [];

    for (const line of lines) {
      const sectionMatch = line.match(/^##\s+(.+)$/);
      if (sectionMatch) {
        if (currentSection) {
          sections.push({ title: currentSection, content: currentContent.join('\n') });
        }
        currentSection = sectionMatch[1];
        currentContent = [];
      } else {
        currentContent.push(line);
      }
    }
    if (currentSection) {
      sections.push({ title: currentSection, content: currentContent.join('\n') });
    }

    // 筛选
    let results = sections;
    if (category) {
      const lower = category.toLowerCase();
      results = sections.filter(s =>
        s.title.toLowerCase().includes(lower)
      );
    }

    return {
      content: [{
        type: 'text',
        text: JSON.stringify({
          total: sections.length,
          sections: results.map(s => ({
            title: s.title,
            preview: s.content.trim().substring(0, 500),
            fullContent: s.content
          }))
        }, null, 2)
      }]
    };
  }
}

// ============================================================
// 主循环：从 stdin 读取 JSON-RPC 请求，写入 stdout
// ============================================================

const server = new MCPServer();

// 发送 JSON-RPC 响应到 stdout
function sendResponse(response, id) {
  const message = id !== undefined && id !== null
    ? JSON.stringify({ jsonrpc: '2.0', id, ...response })
    : JSON.stringify({ jsonrpc: '2.0', ...response });
  process.stdout.write(message + '\n');
}

// 读取 stdin
let dataBuffer = '';
process.stdin.setEncoding('utf-8');
process.stdin.on('data', async (chunk) => {
  dataBuffer += chunk;
  const messages = dataBuffer.split('\n');
  dataBuffer = messages.pop(); // 保留未完成的行

  for (const msg of messages) {
    if (!msg.trim()) continue;
    try {
      const request = JSON.parse(msg);
      const { id, method } = request;

      // 处理通知（无 id 的请求，如 notifications/initialized）
      if (id === undefined || id === null) {
        continue; // 通知不需要响应
      }

      const result = await server.handleRequest(request);

      if (result && result.error) {
        sendResponse(result, id);
      } else if (result) {
        sendResponse({ result }, id);
      }
    } catch (e) {
      // 尝试解析错误
      try {
        const request = JSON.parse(msg);
        if (request.id !== undefined) {
          sendResponse({ error: { code: -32700, message: e.message } }, request.id);
        }
      } catch {
        // 完全无法解析
      }
    }
  }
});

process.stdin.on('end', () => {
  process.exit(0);
});

// MCP 协议要求严格按行处理，stdout 不能有额外输出
// 但我们可以把日志写到 stderr
function log(msg) {
  process.stderr.write(`[MCP] ${msg}\n`);
}

log('武道牌途 MCP 服务器已启动');
log(`项目: ${PROJECT_ROOT}`);
