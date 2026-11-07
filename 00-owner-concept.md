# Swarm platform rebuild: owner concept (Alexis, 2026-10-05)

Status: THOUGHTS, not decisions. The owner's direction, to be researched and turned into a vision, a C4 module map and sequence scenarios. Goal: assemble a lightweight platform WITHOUT the board first; the board is rethought later as a plugin with configurable flows.

## Owner's words (verbatim, Russian)

> кажется что нам надо сделать пересборку роя. будет платформа которая будет состоять из нескольких минимально связанных модулей
> - сешн менеджер - отвечает только за удержание сессии, использует под капотом модуль контекст менеджер который позволит восстанавливать контексты, перекидывать их в юнифайд формат и передавать в разные сессии - как тейковер,
> - контекст менеджер умеет управлять сессиями и оборачивать stdin и stdout для разных агентов которые стартует через ланчер. обертка нужна чтоб инжектить сообщения внутрь контекста извне от разных плагинов. т.е это будет плагинистый контекст менеджер где будут разные ин/аут провайдеры, скажем что если мы хотим выстроить мост общения через матрикс, то будет провайдер который будет подписываться на матрикс канал или каналы и транслейтить сообщения в ин, а аут будет хендлить сообщения и отправлять аут в тот же матрикс канал и таких провайдеров может быть масса. в том числе и например гол провайдер будет связкой между бордой и ином агента или вообще гол менеджером который не привязан к борде - это даже более гранулярный вариант, что-то типа умного ральф лупа.
> контекст менеджер наверное даже можно побить на менеджер и внутри контекст бридж который по сути как модуль внешний и построенный на плагинистой системе, с выраженным абстрактным интерфейсом плагина, и мы сможем кучу разных подключать которые будут как-то взаимодействовать с внешним миром или торчать хвосты для агента чтоб агент например рекурсивно мог себе гол выставить или снять и чтоб гол его подпинывал. Голы скорей всего не нейтив а именно инъекция в stdin, т.к кодекс жестко лажает с голами и вейтами.
> - ланчер также имеет важный кусок: он умеет смещать хоум так чтоб не слетела авторизация клода/кодекса, но чтоб мы могли скилы и тулы и инструкции подкинуть конкретно те что мы задекларим ему в манифесте.
> - борда будет просто как плагин флоу и мы её пока даже не внедряем в платформу, но держим это в голове. борда состоит из пары вещей - менеджмент задач как сейчас это сделано и внешняя конфигурация флоу: по сути мы конфижим борду снаружи тем, какие типы задач у нас есть, как они вкладываются друг в друга и какие у каждого типа задач жизненные циклы и переходы от открытия до закрытия (сейчас в борду зашит дев флоу, а я хочу это вынести как конфигурабл абстракцию). плюс у каждого типа задач и у статуса для исполнения будет припинена роль, на кого её надо ставить если она переходит в какой-то новый стейт: дев задачи в разработку на девелопера, в тест на тестировщика, в анализ на солюшн архитекта; дизайн задачи: анализ - на продакта, дизайн - на дизайнера, ревью - продакта.
> - другой большой кусок борды это спавн, который должен просто ограничиваться единым интерфейсом, а уже для каждого провайдера моделей, будь то локальная или ремоутная, - тот же ланчер будет правильно ланчить. учитывая что роли это по факту скилы с инструкциями - это прям тот же ланчер, который умеет по-разному спавнить интерактивно и неинтерактивно, и чтоб можно было коннектиться к ним, т.е им достанется тот же контекст менеджер через ланчер, чтоб возможно передавать часть контекста в заспавненного (может не передавать), и ин/ауты пинить, возможно на какие-то новые чаты, т.е передать ему например канал в матрикс / конфигурацию к матрикс провайдеру.
> - также есть ремот харнес, и по сути ланчер должен уметь ланчить и ремот харнес агента - только пока под вопросом, а как мы таких ремотов будем подрубать к конкретному проекту (сейчас как-то уже делаем, тоже надо подумать).
> собрать всё это (ланчеры, агент менеджмент, кураторы, a2a) в легковесную платформу.

Product-management layout (as a2a already roughly does it):

```
meta-context
  ├── #lobby, #broadcast, #system (projection for the meta-keeper)
  └── Space: product-X (NOT a repo; product keeper X_keeper)
      ├── #X-lobby, #X-broadcast, #X-system (for the X keeper)
      └── #X-<project> ← orchestrator (local or remote), one REPO each
```

## Structured reading (English)

Modules, minimally coupled:
1. **Session manager**: only HOLDS sessions (keeps them alive). Uses the context manager to restore contexts, convert them to a unified format, and hand them to other sessions (takeover).
2. **Context manager**: manages sessions and WRAPS stdin/stdout of agents started via the launcher, so plugins can inject messages into the context from outside.
   - Split: manager + **context bridge** (an external module on a plugin system with an explicit abstract plugin interface).
   - **In/out providers** (plugins): e.g. a Matrix provider subscribes to channel(s) and translates messages into stdin; outputs go back to the same channel. Many providers.
   - **Goal provider / goal manager**: a link between a board (or no board at all) and the agent's stdin; a smart "Ralph loop". The agent can recursively set or clear its own goal and get nudged by it. Goals are stdin injection, NOT native (Codex fails with native goals and waits).
3. **Launcher**: relocates HOME so Claude/Codex auth survives, while injecting exactly the skills, tools and instructions declared in a manifest. Spawns interactive and non-interactive; launches local agents and remote-harness agents; gives spawned agents the context manager (optional context transfer, I/O pinned e.g. to a new Matrix channel).
4. **Board** (later, a plugin, NOT in the first platform): task management + EXTERNAL flow configuration (task types, nesting, per-type lifecycle and transitions, a role pinned per type and status: dev → developer, test → tester, analysis → solution architect; design tasks: analysis → product, design → designer, review → product). Its **spawn** becomes one interface over the launcher (roles = skills + instructions).
5. **Remote harness**: the launcher can launch a remote-harness agent; open question how remotes attach to a specific project.
6. Existing parts to compose: launchers, agents-management, curator(s), a2a, rwh, worker-jail, mandates, plus ideas from herdr.

## Asks
- Inventory what exists and roughly how it works; a common vision; a C4 module diagram; sequence scenarios (keeper start, worker start, remote-worker start, ...).
- Ask the task-board maintainer about anything missing or unclear.
- Check relux-works/wiki for interaction schemes (not necessarily canon).
