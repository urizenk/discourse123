# Discourse Custom Plugin

一个功能丰富的 Discourse 插件，包含每日签到、待办清单、徽章墙和自定义表情包功能。

## 功能特性

### 1. 每日签到系统 (170元)

- ✅ 签到按钮及界面
- ✅ 签到记录存储 (PostgreSQL)
- ✅ 连续签到天数统计
- ✅ 抽奖概率算法
- ✅ 奖品配置管理
- ✅ 中奖记录及展示

### 2. To Do List / Wish List (120元)

- ✅ 列表数据模型
- ✅ 列表增删改查 API
- ✅ 用户界面组件
- ✅ 拖拽排序功能
- ✅ 完成状态切换

### 3. 产品徽章墙 (75元)

- ✅ 徽章数据模型
- ✅ 徽章展示页面
- ✅ 徽章获取逻辑
- ✅ 用户徽章墙展示

### 4. 自定义用户表情包 (35元)

- ✅ 表情包上传接口
- ✅ 表情包管理界面
- ✅ 表情包选择器集成

## 安装方法

### 1. 添加到 app.yml

编辑 `/var/discourse/containers/app.yml`，在 `hooks` 部分添加：

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/urizenk/discourse-custom-plugin.git
```

### 2. 重建容器

```bash
cd /var/discourse
./launcher rebuild app
```

## 配置说明

安装后，在 Admin → Settings → Plugins 中可以配置：

### 签到系统设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| `checkin_enabled` | true | 启用签到功能 |
| `checkin_base_points` | 10 | 签到基础积分 |
| `checkin_consecutive_bonus` | 5 | 连续签到额外奖励 |
| `checkin_lottery_enabled` | true | 启用抽奖功能 |
| `checkin_lottery_prizes` | 10积分\|50积分\|100积分\|神秘大奖 | 奖品列表 |
| `checkin_lottery_probabilities` | 50\|30\|15\|5 | 中奖概率 |

### 待办清单设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| `todo_enabled` | true | 启用待办功能 |
| `todo_max_items` | 50 | 每用户最大待办数 |

### 徽章墙设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| `badge_wall_enabled` | true | 启用徽章墙 |
| `badge_wall_public` | true | 徽章墙公开可见 |

### 自定义表情设置

| 设置项 | 默认值 | 说明 |
|--------|--------|------|
| `custom_emoji_enabled` | true | 启用自定义表情 |
| `custom_emoji_max_per_user` | 20 | 每用户最大表情数 |
| `custom_emoji_max_size_kb` | 256 | 表情最大大小(KB) |

## API 接口

### 签到系统

```
GET  /custom-plugin/checkin          # 获取签到状态
POST /custom-plugin/checkin          # 执行签到
GET  /custom-plugin/checkin/history  # 签到历史
GET  /custom-plugin/checkin/lottery  # 抽奖状态
POST /custom-plugin/checkin/draw     # 执行抽奖
```

### 待办清单

```
GET    /custom-plugin/todos           # 获取待办列表
POST   /custom-plugin/todos           # 创建待办
PUT    /custom-plugin/todos/:id       # 更新待办
DELETE /custom-plugin/todos/:id       # 删除待办
PUT    /custom-plugin/todos/:id/toggle   # 切换完成状态
PUT    /custom-plugin/todos/:id/reorder  # 调整顺序
```

### 徽章墙

```
GET  /custom-plugin/badge-wall              # 获取徽章墙
GET  /custom-plugin/badge-wall/:user_id     # 查看用户徽章墙
POST /custom-plugin/badge-wall/collect/:id  # 收藏徽章
```

### 自定义表情

```
GET    /custom-plugin/custom-emoji      # 获取表情列表
POST   /custom-plugin/custom-emoji      # 上传表情
DELETE /custom-plugin/custom-emoji/:id  # 删除表情
```

## 数据库表

插件会创建以下数据表：

- `user_checkins` - 签到记录
- `user_todos` - 待办事项
- `user_badge_collections` - 徽章收藏
- `custom_emojis` - 自定义表情

## 技术栈

- Ruby on Rails (后端)
- PostgreSQL (数据库)
- Ember.js / Glimmer (前端)
- SCSS (样式)

## 版本要求

- Discourse 2.7.0 或更高版本
- Ruby 3.0+
- PostgreSQL 13+

## 许可证

MIT License

## 作者

Custom Development

## 费用汇总

| 模块 | 金额(元) |
|------|----------|
| 每日签到抽奖系统 | 170 |
| To Do List / Wish List | 120 |
| 产品徽章墙 | 75 |
| 自定义用户表情包 | 35 |
| **后端功能合计** | **400** |
