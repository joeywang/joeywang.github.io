---
layout: post
title: "Agent 基建的三层爆发：电脑、运行时、技能方法论"
date: 2026-08-10 09:12:00 +0100
author: "Joey Wang"
description: "从 Prime Agent、Cloudflare Computer、agent-skills、mattpocock/skills 和 Superpowers 看 Agent 基础设施正在如何从聊天框走向持久工作台、长任务运行时和工程方法论。"
tags: [ai, agents, engineering, infrastructure, hermes]
categories: [AI, Engineering]
---

# Agent 基建的三层爆发：电脑、运行时、技能方法论

这几天 GitHub 上一批 Agent 相关项目突然变得很热。表面上看，它们都在讲 “AI coding agent” 或 “agent skills”。但放在一起看，我觉得更准确的判断是：

**Agent 正在从聊天框，变成一种有工作台、有运行时、有工程方法论的执行系统。**

这不是又一轮 prompt trick 的热闹。真正值得注意的是基础设施在补齐。

以前我们问模型一个问题，模型回答。后来我们给它工具，让它能读文件、跑命令、查网页。再后来我们给它 memory，让它不必每次从零开始。

现在的问题变成了：

```text
一个 Agent 要长期可靠地干活，周围到底需要什么？
```

这五个项目刚好可以拆成三层。

## 第一层：给 Agent 一台电脑

代表项目是 [cloudflare/computer](https://github.com/cloudflare/computer)。它的描述很直接：Give your agent a computer。

这里的 “computer” 不是一台完整虚拟机的营销说法，而是一个 Agent 需要的最小工作台：

- 一个可以持久读写的文件系统；
- 一个统一的执行接口；
- 多种可插拔的执行后端；
- 可以围绕 agent session 保存和恢复的工作状态。

它的文档里提到 SQLite-backed virtual filesystem，也提到通过 `workspace.runtime` 选择不同执行后端。这个抽象很重要，因为 Agent 如果只有聊天记录，就没有真正的工作现场。

一个严肃的 Agent 不应该只会说：

```text
我会创建一个文件。
```

它应该真的有地方创建文件、修改文件、运行检查、留下结果：

```text
workspace
  -> files
  -> commands
  -> outputs
  -> receipts
```

这也是我越来越觉得 Agent 系统里 “workspace” 应该成为一等对象的原因。聊天记录是交互界面，不是完整工作台。

对本地优先的系统来说，这个 workspace 未必需要在 Cloudflare 上。它可以是本地目录、git worktree、容器、数据库、QMD collection，或者这些东西的组合。关键不是技术选型，而是这个概念本身：**Agent 需要一个可恢复、可审计、可清理的工作现场。**

## 第二层：长任务需要运行时，不只是更长上下文

代表项目是 [PrimeIntellect-ai/prime-agent](https://github.com/PrimeIntellect-ai/prime-agent)。它把自己描述成 self-improving RLM agent for coding workflows and long-running autonomous tasks。

这里最值得看的不是 “它也能写代码”。能写代码已经不是新鲜事。

真正值得看的是它围绕长任务做的结构：background agents、daemon、worker、kernel、persistence、heartbeats、schedules、subagents、skills。换句话说，它不是把 Agent 当成一次性对话，而是当成一个可以脱离终端、继续推进任务、之后再被重新接上的运行实体。

这解决的是一个很现实的问题：

```text
长任务不是一次回答。
长任务是一条会中断、会等待、会失败、会恢复的轨迹。
```

如果 Agent 只是一个聊天窗口，那么断线、超时、上下文丢失、人离开电脑，都会把工作变得脆弱。长任务需要的是运行时边界：

```text
goal
  -> current frontier
  -> background execution
  -> heartbeat
  -> evidence receipt
  -> reattach / resume
```

这和普通 “把 context window 变大” 不是一回事。更长上下文可以让模型看到更多历史，但它不能自动解决：

- 当前任务推进到哪一步；
- 哪一步需要人批准；
- 上一次真实验证结果是什么；
- 失败后应该从哪里恢复；
- 哪些证据可以重新读取。

所以我更关心的是 goal register、frontier、gate、receipt 这些词，而不是单纯的 “agent memory”。Memory 很容易变成一个什么都往里塞的垃圾场。长任务需要的其实是更结构化的状态。

## 第三层：技能不是提示词，是工程方法论的包装

另外三个项目都和 skills 有关，但侧重点不同。

[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) 更像生产级工程技能包。它不只是放一堆提示词，而是把 skills、agents、hooks、commands、references、evals 和 docs 组织在一起。它强调技能应该 specific、verifiable、battle-tested、minimal。

[mattpocock/skills](https://github.com/mattpocock/skills) 的气质不太一样。它像是从一个真实工程师的 `.agents` 目录里提炼出来的工作习惯：handoff、grilling、writing-for-agents、架构和交付流程。它有一种很实用的味道：少一点平台感，多一点 “我真的每天这样用”。

[obra/superpowers](https://github.com/obra/superpowers) 则更像一套 agentic skills framework 加软件开发方法论。它强调的不只是单个技能，而是如何用技能组织开发流程、子 Agent、计划、review 和修复循环。

这三个项目合在一起说明了一件事：

```text
Skill 不应该只是“更好的提示词”。
Skill 应该是可复用的工程行为单元。
```

一个好的 Agent skill 至少应该回答：

- 什么时候触发？
- 先读什么上下文？
- 做哪些步骤？
- 哪些地方必须停下来问人？
- 用什么证据证明完成？
- 如果失败，怎么恢复？

如果一个 skill 只是在说 “请写高质量代码”，那它几乎没有价值。真正有价值的 skill 应该把资深工程师脑内的流程压缩下来：如何澄清需求，如何写计划，如何做最小改动，如何跑验证，如何请求 review，如何交接给另一个 Agent。

## 这三层为什么会同时爆发

我觉得原因很简单：大家已经意识到，单个模型能力再强，也不能单独构成可靠系统。

一个能干活的 Agent 至少需要这三件事：

```text
workspace      -> 它在哪里工作
runtime        -> 它如何持续工作
methodology    -> 它按什么方式工作
```

没有 workspace，Agent 只能在对话里想象文件和结果。

没有 runtime，Agent 很难处理长任务、失败恢复和异步等待。

没有 methodology，Agent 可能会写代码，但不会像工程师一样交付。

所以这五个项目看起来分散，其实在补同一张图：

```text
agent request
  -> workspace with files/tools
  -> runtime with state/recovery
  -> skills with engineering discipline
  -> verified artifact
```

这也是我觉得 “Agent 基建” 这个词比 “AI 编码工具” 更准确的原因。

## 对我自己的启发

我现在更愿意把 Agent 系统看成一个分层架构，而不是一个聪明模型外面包一点工具。

对一个本地优先、长期使用的个人 Agent 来说，比较理想的形态应该是：

```text
stable preferences      -> memory
rich notes/research     -> QMD / docs
repeatable procedures   -> skills
repeated deterministic  -> scripts / commands
scheduled checks        -> cron / no-agent jobs
long-horizon work       -> goal register + receipts
code work               -> worktree / sandbox / CI
public outputs          -> reviewed blog/social pipeline
```

模型负责判断和综合。工具负责观察和执行。脚本负责重复。技能负责方法。文档负责长期知识。Git 负责历史。人负责边界、价值判断和授权。

这比 “让 Agent 自动化一切” 更保守，但也更可靠。

## 不要被星标带跑

这类项目很容易让人兴奋。星标暴涨会制造一种 “必须马上安装” 的冲动。

我不太认同这个顺序。

对 Agent 基础设施，正确顺序应该是：

```text
先读架构
再看边界
再做小实验
最后才考虑采用
```

尤其是能执行代码、写文件、联网、长期运行的系统，一定要先看清楚：

- 文件系统边界在哪里；
- 命令执行有没有隔离；
- 凭证如何处理；
- 任务状态保存在哪里；
- telemetry 默认行为是什么；
- 失败后如何恢复；
- 人类审批点能不能强制执行。

越像基础设施，越不能只看 demo。

## 我会优先研究什么

如果只选几个方向继续看，我会这样排：

1. **Prime Agent 的长任务运行时**：daemon、worker、kernel、persistence、heartbeat、resume。
2. **Cloudflare Computer 的 workspace 抽象**：虚拟文件系统、执行后端、agent tool interface。
3. **Superpowers 的方法论**：subagent-driven development、plan-scoped workspace、review/fix loop。
4. **agent-skills 的技能质量标准**：specific、verifiable、battle-tested、minimal。
5. **mattpocock/skills 的实战习惯**：handoff、grilling、writing-for-agents。

我不一定会直接采用任何一个项目。但我会把它们当成一组很好的设计样本。

因为真正的问题不是 “哪个 Agent 框架会赢”。真正的问题是：

```text
一个长期和人一起工作的 Agent，
需要哪些基础设施才能可靠地完成真实工作？
```

这五个项目给出的答案越来越清楚了：

它需要一台电脑。  
它需要一个运行时。  
它需要一套工程方法论。

而模型，只是这个系统里最聪明、也最不应该单独承担全部责任的那一层。

## 参考项目

- [PrimeIntellect-ai/prime-agent](https://github.com/PrimeIntellect-ai/prime-agent)
- [cloudflare/computer](https://github.com/cloudflare/computer)
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)
- [mattpocock/skills](https://github.com/mattpocock/skills)
- [obra/superpowers](https://github.com/obra/superpowers)
