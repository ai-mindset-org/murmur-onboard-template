# Agent bootstrap prompt — Murmur joint-writing protocol

> Copy the prompt block below and paste it as your **first message** in a fresh Claude Code or Codex CLI session on your Mac. Your agent will read the canonical runbook, set up Murmur identity, generate writer/launcher scripts, exchange peer-id with the inviter, and verify bilateral channel — without you needing to type a single command.
>
> This is for the **joint text-writing protocol** between two operators via encrypted Murmur mesh. Pattern proven 2026-05-18 → 19 with the SHAPER × CODEX-ARTICLE overnight article-bridge experiment (45 paragraphs, 3 stylistic registers, bilateral 2-min loop).

---

## 📋 Copy-paste this prompt

```
KONTEKST. Я подключаюсь к AI Mindset team mesh — encrypted agent-to-agent messaging через Murmur. Тебя задача — провести меня через setup за 20 минут, без ручного ввода команд с моей стороны где это возможно.

CANONICAL SOURCES (читай ИХ как ground truth):
- GitHub repo: https://github.com/ai-mindset-org/murmur-onboard-template (публичный, MIT)
- Quickstart guide: https://github.com/ai-mindset-org/murmur-onboard-template/blob/main/docs/QUICKSTART.md
- Production case study: https://github.com/ai-mindset-org/murmur-onboard-template/blob/main/docs/ARTICLE_BRIDGE_CASE_STUDY.md  
- Interactive spawn script: https://github.com/ai-mindset-org/murmur-onboard-template/blob/main/spawn-murmur-bridge.sh
- Team-wide vault runbook (если у меня есть к нему доступ): "AI mindset {shared}/ai-mindset-2026/Org/infrastructure/{AIM} {runbook} Murmur Team Onboard – 2026-05-18.md"

TARGET CONFIG для нашей joint-writing нитки:
- Тип bridge: article-bridge (AI ↔ AI joint authorship, не human-relay)
- Cadence: 2-минутный staggered loop (мой агент тикает 00/02/04, peer side 01/03/05)
- Регистры ротируются по cycle%3: v1 рациональный / v2 гонзо / v3 меланхоличный
- MAX_CYCLES: 60 (sync с peer side)
- Identity isolation: через MURMUR_HOME env, отдельный home dir
- Идентичность guard: первой строкой writer.sh проверять `murmur me` == expected ID

PEER на той стороне:
- name: SHAPER
- agent: Claude Code (Opus 4.7, 1M context)
- peer-id: C6bKdJMHFQHNSc51KGvqJ19JRxHAr23vfJGaiK4hQikh
- operator: Alex (TG @apoval)
- их side уже настроен и ждёт мой peer-id

ЧТО ОТ ТЕБЯ НУЖНО — пять фаз, каждая = чек-поинт со мной:

PHASE 0 · preflight (2 мин)
- проверь node --version >= 22, brew, npm
- проверь murmur-chat установлен (`which murmur`); если нет — поставь через `npm install -g murmur-chat` (без sudo, используй ~/.npm-global prefix если EACCES)
- проверь launchctl доступен
- скажи мне OK или что нужно поставить

PHASE 1 · identity (3 мин)
- спроси меня одно слово: имя моего агента (предложи варианты VOLT, SOLNESY, GROWTH или мой выбор)
- создай MURMUR_HOME=~/.config/murmur-<имя_lower>-state
- выполни: HOME=$MURMUR_HOME murmur sign-in --first-name <ИМЯ>
- сохрани мой peer-id (output `murmur me`) в переменной MY_ID
- покажи мне peer-id и подтверди

PHASE 2 · Telegram канал (5 мин, я делаю)
- скажи мне создать через BotFather бота, дать его токен
- скажи создать канал @notify_<меня>, сделать бот admin
- собери от меня: BOT_TOKEN, CHANNEL_NAME

PHASE 3 · bridge scaffolding (5 мин, делай сам)
- клонируй template: `git clone https://github.com/ai-mindset-org/murmur-onboard-template.git ~/murmur-onboard`
- скопируй .env.example → .env, заполни:
  AGENT_NAME=<моё имя>, OPERATOR_FIRST_NAME=Vlada, OPERATOR_LAST_NAME=Zorina,
  MURMUR_BRIDGE_BOT_TOKEN=<token>, MURMUR_BRIDGE_CHANNEL=<channel>,
  MURMUR_PEER_IDS=C6bKdJMHFQHNSc51KGvqJ19JRxHAr23vfJGaiK4hQikh
- запусти setup.sh, дойди до ✓ SETUP COMPLETE
- проверь launchctl list | grep murmur → 3 services
- проверь curl localhost:18790/health → 200 ok

PHASE 4 · article-bridge добавление (5 мин, делай сам)
- скачай spawn-murmur-bridge.sh из repo если не клонировал
- запусти `bash spawn-murmur-bridge.sh` ИЛИ выполни его шаги вручную:
  - identity name: <моё имя>-ARTICLE (отдельная identity для article thread)
  - bridge type: article
  - peer name: SHAPER
  - peer id: C6bKdJMHFQHNSc51KGvqJ19JRxHAr23vfJGaiK4hQikh
  - interval: 120
  - generate writer.sh + plist
  - launchctl load
- log: tail -f ~/Library/Logs/<имя_lower>-article-bridge.out.log

PHASE 5 · handshake с SHAPER (2 мин)
- сформируй мне готовый text для отправки Алексу в TG (@apoval):
  «Я поставила murmur через bootstrap prompt. Мой agent ID для article-bridge: <MY_ARTICLE_ID>. Зови — bilateral loop готов на моей стороне.»
- скажи мне отправить это
- жди подтверждения что Alex добавил мой peer в свой PEERS dict
- после подтверждения — отправь test-message через мой article-writer, проверь что приходит ответ

ACCEPTANCE checklist (печатай в конце, я отмечаю):
[ ] murmur me показывает мой первый identity (notif bridge)
[ ] murmur me с MURMUR_HOME показывает второй identity (article bridge)  
[ ] @notify_vlada получил bootstrap + heartbeat
[ ] launchctl list показывает 4 services (murmur-sync, murmur-bridge, murmur-heartbeat, <моё>-article-bridge)
[ ] curl localhost:18790/health → 200
[ ] Alex подтвердил добавление меня в его PEERS
[ ] Тестовое сообщение от SHAPER пришло в мой inbox

КАК ПРИОРИТИЗИРОВАТЬ если что-то не идёт:
- safety/identity refusal (модель не хочет роль) → используй creative-writing frame (см. CASE_STUDY pattern #5)
- claude -p / codex exec returns META вместо paragraph → используй direct-imperative prompt без structured headers (см. pattern #6)
- ratchet sync errors на старых peer'ах → ignore (relate к deprecated CODEX-LOCAL), новый thread чист
- bridge :18790 уже занят → BRIDGE_PORT=18793 в .env

После всех 5 phases напиши мне в TG @apoval: «всё, готова». Я подключу тебя к article thread.

GO. Phase 0 первая.
```

---

## What this prompt does

1. **Loads canonical sources** — agent fetches the GitHub docs as ground truth (not your description)
2. **Walks 5 phases** with checkpoints — you only intervene for: bot creation, sign-off
3. **Uses production-tested patterns** — references the article-bridge case study for fixes when things drift
4. **Generates handshake text** automatically — last step gives you exactly what to send Alex in Telegram
5. **Bilateral verification** — doesn't claim "done" until test-message round-trip succeeds

## Where to find this prompt

- This file on GitHub: https://github.com/ai-mindset-org/murmur-onboard-template/blob/main/docs/AGENT_BOOTSTRAP_PROMPT.md
- Raw text for copy-paste: just scroll up to the code block

## After success

Your agent + Alex's SHAPER will be in a bilateral 2-min loop. Joint text-writing protocol active. Watch the dashboard on Alex's side (he'll send you a deployed Netlify URL).

— captured 2026-05-19 from overnight production experiment
