# 🏆 HARVESTED KNOWLEDGE VAULT

Generated from: level_0_rag.json

## 🔑 Topic: indicator handle context

### 📝 Snippet 1 (Source: vectorbt-master/examples/TelegramSignals.ipynb)
> { "cells": [ { "cell_type": "markdown", "metadata": {}, "source": [ "In this example, we will build a Telegram bot that sends a signal once any Bollinger Band has been crossed. We will periodically query for the latest OHLCV data of the selected cryptocurrencies and append this data to our data pool. Additionally to receiving signals, any Telegram user can join the group and ask the bot to provide him with the current information. If the price change is higher than some number of standard deviations from the mean, while crossing the band, the bot sends a funny GIF." ] }, { "cell_type": "code", "execution_count": 1, "metadata": {}, "outputs": [], "source": [ "import pandas as pd\n", "import vectorbt as vbt\n", "import logging" ] }, { "cell_type": "code", "execution_count": 2, "metadata": {}, "outputs": [], "source": [ "logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)\n", "logger = logging.getLogger(__name__)" ] }, { "cell_type": "cod...

### 📝 Snippet 2 (Source: vectorbt-master/docs/docs/getting-started/features.md)
> --- title: Features --- # Features :zap: ## Pandas - [x] **Pandas acceleration**: Compiled versions of most popular pandas functions, such as mapping, reducing, rolling, grouping, and resamping. For best performance, most operations are done strictly using NumPy and Numba. Attaches a custom accessor on top of Pandas to easily switch between Pandas and VectorBT functionality. ```pycon title="Compute the rolling z-score" >>> import vectorbt as vbt >>> import pandas as pd >>> import numpy as np >>> from numba import njit >>> big_ts = pd.DataFrame(np.random.uniform(size=(1000, 1000))) # pandas >>> @njit ... def zscore_nb(x): ... return (x[-1] - np.mean(x)) / np.std(x) >>> %timeit big_ts.rolling(2).apply(zscore_nb, raw=True) 482 ms ± 393 µs per loop (mean ± std. dev. of 7 runs, 1 loop each) # vectorbt >>> @njit ... def vbt_zscore_nb(i, col, x): ... return zscore_nb(x) >>> %timeit big_ts.vbt.rolling_apply(2, vbt_zscore_nb) 33.1 ms ± 1.17 ms per loop (mean ± std. dev. of 7 runs, 1 loop each) ...

### 📝 Snippet 3 (Source: nautilus_trader-develop/RELEASES.md)
> # NautilusTrader 1.223.0 Beta Released on TBD (UTC). This will be the final release with support for the dYdX v3 (legacy) API. Future releases will only support dYdX v4 (Cosmos-based). ### Enhancements - Added sandbox execution adapter in Rust - Added multi-account execution support (#3194), thanks @faysou - Added matching engine `queue_position` tracking heuristic for backtests - Added tracing subscriber for external Rust library logs (`use_tracing=True` in `LoggingConfig`, filter with `RUST_LOG` env var) - Added `use_market_order_acks` venue config option to generate `OrderAccepted` events for market orders before filling (mimics behavior of venues like Binance) - Added `oto_trigger_mode` venue config option to control whether OTO child orders activate on partial fills (PARTIAL) or only after full fill (FULL) (default PARTIAL) (#3454), thanks @godnight10061 - Added `request_funding_rates` and `FundingRateUpdate` Arrow serialization (#3467), thanks @dxwil - Added `optimize_file_loadin...

### 📝 Snippet 4 (Source: nautilus_trader-develop/docs/concepts/actors.md)
> # Actors An `Actor` receives data, handles events, and manages state. The `Strategy` class extends Actor with order management capabilities. **Key capabilities**: - Data subscription and requests (market data, custom data). - Event handling and publishing. - Timers and alerts. - Cache and portfolio access. - Logging. ## Basic example Actors support configuration through a pattern similar to strategies. ```python from nautilus_trader.config import ActorConfig from nautilus_trader.model import InstrumentId from nautilus_trader.model import Bar, BarType from nautilus_trader.common.actor import Actor class MyActorConfig(ActorConfig): instrument_id: InstrumentId # example value: "ETHUSDT-PERP.BINANCE" bar_type: BarType # example value: "ETHUSDT-PERP.BINANCE-15-MINUTE[LAST]-INTERNAL" lookback_period: int = 10 class MyActor(Actor): def __init__(self, config: MyActorConfig) -> None: super().__init__(config) # Custom state variables self.count_of_processed_bars: int = 0 def on_start(self) -> No...

### 💻 Snippet 5 (Source: nautilus_trader-develop/docs/concepts/architecture.md)
```
# Architecture This guide covers the architectural principles and structure of NautilusTrader: - Design philosophy and quality attributes. - Core components and how they interact. - Environment contexts (backtest, sandbox, live). - Framework organization and code structure. :::note Throughout the documentation, the term *"Nautilus system boundary"* refers to operations within the runtime of a single Nautilus node (also known as a "trader instance"). ::: ## Design philosophy The major architectural techniques and design patterns employed by NautilusTrader are: - [Domain driven design (DDD)](https://en.wikipedia.org/wiki/Domain-driven_design) - [Event-driven architecture](https://en.wikipedia.org/wiki/Event-driven_programming) - [Messaging patterns](https://en.wikipedia.org/wiki/Messaging_pattern) (Pub/Sub, Req/Rep, point-to-point) - [Ports and adapters](https://en.wikipedia.org/wiki/Hexagonal_architecture_(software)) - [Crash-only design](#crash-only-design) These techniques have been utilized to assist in achieving certain architectural quality attributes. ### Quality attributes Architectural decisions are often a trade-off between competing priorities. The below is a list of some of the most important quality attributes which are considered when making design and architectural decisions, roughly in order of 'weighting'. - Reliability - Performance - Modularity - Testability - Maintainability - Deployability ### Assurance-driven engineering NautilusTrader is incrementally adopting a high-assurance mindset: critical code paths should carry executable invariants that verify behaviour matches the business requirements. Practically this means we: - Identify the components whose failure has the highest blast radius (core domain types, risk and execution flows) and write down their invariants in plain language. - Codify those invariants as executable checks (unit tests, property tests, fuzzers, static assertions) that run in CI, keeping the feedback loop light. - Prefer zero-cost safety techniques built into Rust (ownership, `Result` surfaces, `panic = abort`) and add targeted formal tools only where they pay for themselves. - Track “assurance debt” alongside feature work so new integrations extend the safety net rather than bypass it. This approach preserves the platform’s delivery cadence while giving mission critical flows the additional scrutiny they need. Further reading: [High Assurance Rust](https://highassurance.rs/). ### Crash-only design NautilusTrader draws inspiration from [crash-only design](https://en.wikipedia.org/wiki/Crash-only_software) principles, particularly for handling unrecoverable faults. The core insight is that systems which can recover cleanly from crashes are more robust than those with separate (and rarely tested) graceful shutdown paths. Key principles: - **Unified recovery path** - Startup and crash recovery share the same code path, ensuring it is well-tested. - **Externalized state** - Critical state is meant to be persisted externally when configured, reducing data-loss risk; durability depends on the backing store. - **Fast restart** - The system is designed to restart quickly after a crash, minimizing downtime. - **Idempotent operations** - Operations are designed to be safely retried after restart. - **Fail-fast for unrecoverable errors** - Data corruption or invariant violations trigger immediate termination rather than attempting to continue in a compromised state. :::note The system does provide graceful shutdown flows (`stop`, `dispose`) for normal operation. These tear down clients, persist state, and flush writers. The crash-only philosophy applies specifically to *unrecoverable faults* where attempting graceful cleanup could cause further damage. ::: This design complements the [fail-fast policy](#data-integrity-and-fail-fast-policy), where unrecoverable errors result in immediate process termination. **References:** - [Crash-Only Software](https://www.usenix.org/conference/hotos-ix/crash-only-software) - Candea & Fox, HotOS 2003 (original research paper) - [Microreboot—A Technique for Cheap Recovery](https://www.usenix.org/conference/osdi-04/microreboot—-technique-cheap-recovery) - Candea et al., OSDI 2004 - [The properties of crash-only software](https://brooker.co.za/blog/2012/01/22/crash-only.html) - Marc Brooker's blog - [Crash-only software: More than meets the eye](https://lwn.net/Articles/191059/) - LWN.net article - [Recovery-Oriented Computing (ROC) Project](http://roc.cs.berkeley.edu/) - UC Berkeley/Stanford research ### Data integrity and fail-fast policy NautilusTrader prioritizes data integrity over availability for trading operations. The system employs a strict fail-fast policy for arithmetic operations and data handling to prevent silent data corruption that could lead to incorrect trading decisions. #### Fail-fast principles The system will fail fast (panic or return an error) when encountering: - Arithmetic overflow or underflow in operations on timestamps, prices, or quantities that exceed valid ranges. - Invalid data during deserialization including NaN, Infinity, or out-of-range values in market data or configuration. - Type conversion failures such as negative values where only positive values are valid (timestamps, quantities). - Malformed input parsing for prices, timestamps, or precision values. Rationale: In trading systems, corrupt data is worse than no data. A single incorrect price, timestamp, or quantity can cascade through the system, resulting in: - Incorrect position sizing or risk calculations. - Orders placed at wrong prices. - Backtests producing misleading results. - Silent financial losses. By crashing immediately on invalid data, NautilusTrader aims to provide: 1. **No silent corruption** - The fail-fast policy is intended to prevent invalid data from propagating; this relies on checks covering the inputs. 2. **Immediate feedback** - Issues are discovered during development and testing, not in production. 3. **Audit trail** - Crash logs clearly identify the source of invalid data. 4. **Deterministic behavior** - With deterministic ordering and configuration, the same invalid input should trigger the same failure; nondeterministic sources can vary outcomes. #### When fail-fast applies Panics are used for: - Programmer errors (logic bugs, incorrect API usage). - Data that violates fundamental invariants (negative timestamps, NaN prices). - Arithmetic that would silently produce incorrect results. Results or Options are used for: - Expected runtime failures (network errors, file I/O). - Business logic validation (order constraints, risk limits). - User input validation. - Library APIs exposed to downstream crates where callers need explicit error handling without relying on panics for control flow. #### Example scenarios ```rust // CORRECT: Panics on overflow - prevents data corruption let total_ns = timestamp1 + timestamp2; // Panics if result > u64::MAX // CORRECT: Rejects NaN during deserialization let price = serde_json::from_str("NaN"); // Error: "must be finite" // CORRECT: Explicit overflow handling when needed let total_ns = timestamp1.checked_add(timestamp2)?; // Returns Option<UnixNanos> ``` This policy is implemented throughout the core types (`UnixNanos`, `Price`, `Quantity`, etc.) and helps NautilusTrader maintain strong data correctness for production trading. In production deployments, the system is typically configured with `panic = abort` in release builds, ensuring that any panic results in a clean process termination that can be handled by process supervisors or orchestration systems. This aligns with the [crash-only design](#crash-only-design) principle, where unrecoverable errors lead to immediate restart rather than attempting to continue in a potentially corrupted state. ## System architecture The NautilusTrader codebase is actually both a framework for composing trading systems, and a set of default system implementations which can operate in various [environment contexts](#environment-contexts). ![Architecture](https://github.com/nautechsystems/nautilus_trader/blob/develop/assets/architecture-overview.png?raw=true "architecture") ### Core components The platform is built around several key components that work together to provide a comprehensive trading system: #### `NautilusKernel` The central orchestration component responsible for: - Initializing and managing all system components. - Configuring the messaging infrastructure. - Maintaining environment-specific behaviors. - Coordinating shared resources and lifecycle management. - Providing a unified entry point for system operations. #### `MessageBus` The backbone of inter-component communication, implementing: - **Publish/Subscribe patterns**: For broadcasting events and data to multiple consumers. - **Request/Response communication**: For operations requiring acknowledgment. - **Command/Event messaging**: For triggering actions and notifying state changes. - **Optional state persistence**: Using Redis for durability and restart capabilities. #### `Cache` High-performance in-memory storage system that: - Stores instruments, accounts, orders, positions, and more. - Provides performant fetching capabilities for trading components. - Maintains consistent state across the system. - Supports both read and write operations with optimized access patterns. #### `DataEngine` Processes and routes market data throughout the system: - Handles multiple data types (quotes, trades, bars, order books, custom data, and more). - Routes data to appropriate consumers based on subscriptions. - Manages data flow from external sources to internal components. #### `ExecutionEngine` Manages order lifecycle and execution: - Routes trading commands to the appropriate adapter clients. - Tracks order and position states. - Coordinates with risk management systems. - Handles execution reports and fills from venues. - Handles reconciliation of external execution state. #### `RiskEngine` Provides comprehensive risk management: - Pre-trade risk checks and validation. - Position and exposure monitoring. - Real-time risk calculations. - Configurable risk rules and limits. ### Environment contexts An environment context in NautilusTrader defines the type of data and trading venue you are working with. Understanding these contexts is crucial for effective backtesting, development, and live trading. Here are the available environments you can work with: - `Backtest`: Historical data with simulated venues. - `Sandbox`: Real-time data with simulated venues. - `Live`: Real-time data with live venues (paper trading or real accounts). ### Common core The platform has been designed to share as much common code between backtest, sandbox and live trading systems as possible. This is formalized in the `system` subpackage, where you will find the `NautilusKernel` class, providing a common core system 'kernel'. The *ports and adapters* architectural style enables modular components to be integrated into the core system, providing various hooks for user-defined or custom component implementations. ### Data and execution flow patterns Understanding how data and execution flow through the system is crucial for effective use of the platform: #### Data flow pattern 1. **External Data Ingestion**: Market data enters via venue-specific `DataClient` adapters where it is normalized. 2. **Data Processing**: The `DataEngine` handles data processing for internal components. 3. **Caching**: Processed data is stored in the high-performance `Cache` for fast access. 4. **Event Publishing**: Data events are published to the `MessageBus`. 5. **Consumer Delivery**: Subscribed components (Actors, Strategies) receive relevant data events. #### Execution flow pattern 1. **Command Generation**: User strategies create trading commands. 2. **Command Publishing**: Commands are sent through the `MessageBus`. 3. **Risk Validation**: The `RiskEngine` validates trading commands against configured risk rules. 4. **Execution Routing**: The `ExecutionEngine` routes commands to appropriate venues. 5. **External Submission**: The `ExecutionClient` submits orders to external trading venues. 6. **Event Flow Back**: Order events (fills, cancellations) flow back through the system. 7. **State Updates**: Portfolio and position states are updated based on execution events. #### Component state management All components follow a finite state machine pattern. The `ComponentState` enum defines both stable states and transitional states: ```mermaid stateDiagram-v2 [*] --> PRE_INITIALIZED PRE_INITIALIZED --> READY : register() READY --> STARTING : start() STARTING --> RUNNING RUNNING --> STOPPING : stop() STOPPING --> STOPPED STOPPED --> STARTING : start() STOPPED --> RESETTING : reset() RESETTING --> READY RUNNING --> RESUMING : resume() RESUMING --> RUNNING RUNNING --> DEGRADING : degrade() DEGRADING --> DEGRADED DEGRADED --> STOPPING : stop() DEGRADED --> FAULTING : fault() RUNNING --> FAULTING : fault() FAULTING --> FAULTED STOPPED --> DISPOSING : dispose() FAULTED --> DISPOSING : dispose() DISPOSING --> DISPOSED DISPOSED --> [*] ``` **Stable states:** - **PRE_INITIALIZED**: Component is instantiated but not yet ready to fulfill its specification. - **READY**: Component is configured and able to be started. - **RUNNING**: Component is operating normally and can fulfill its specification. - **STOPPED**: Component has successfully stopped. - **DEGRADED**: Component has degraded and may not meet its full specification. - **FAULTED**: Component has shut down due to a detected fault. - **DISPOSED**: Component has shut down and released all of its resources. **Transitional states:** - **STARTING**: Component is executing its actions on `start`. - **STOPPING**: Component is executing its actions on `stop`. - **RESUMING**: Component is being started again after its initial start. - **RESETTING**: Component is executing its actions on `reset`. - **DISPOSING**: Component is executing its actions on `dispose`. - **DEGRADING**: Component is executing its actions on `degrade`. - **FAULTING**: Component is executing its actions on `fault`. Transitional states are brief intermediate states that occur during state transitions. Components should not remain in transitional states for extended periods. #### Actor vs Component traits At the Rust implementation level, the system distinguishes between two complementary traits: ```mermaid classDiagram class Actor { <<trait>> +id() Ustr +handle(message) } class Component { <<trait>> +component_id() ComponentId +state() ComponentState +register() +start() +stop() +reset() +dispose() } class ActorRegistry { +insert(actor) +get(id) ActorRef } class ComponentRegistry { +insert(component) +get(id) ComponentRef } Actor <|.. Throttler : implements Actor <|.. Strategy : implements Component <|.. Strategy : implements Component <|.. DataEngine : implements Component <|.. ExecutionEngine : implements ActorRegistry --> Actor : manages ComponentRegistry --> Component : manages class Throttler { Actor only } class Strategy { Actor + Component } class DataEngine { Component only } class ExecutionEngine { Component only } ``` **`Actor` trait** - Message dispatch: - Provides the `handle` method for receiving messages dispatched through the actor registry. - Enables type-safe lookup and message dispatch by actor ID. - Used by components that need to receive targeted messages (strategies, throttlers). **`Component` trait** - Lifecycle management: - Manages state transitions (`start`, `stop`, `reset`, `dispose`). - Provides registration with the system kernel (`register`). - Tracks component state via the finite state machine described above. - Used by all system components that need lifecycle management. :::note All components can publish and subscribe to messages via the `MessageBus` directly - this is independent of the `Actor` trait. The `Actor` trait specifically enables the registry-based message dispatch pattern where messages are routed to a specific actor by ID. ::: This separation allows: - **Actor-only**: Lightweight message handlers without lifecycle (e.g., `Throttler`). - **Component-only**: System infrastructure with lifecycle but using direct MessageBus pub/sub (e.g., `DataEngine`, `ExecutionEngine`). - **Both traits**: Trading strategies that need lifecycle management AND targeted message dispatch. The traits are managed by separate registries to support their different access patterns - lifecycle methods are called sequentially, while message handlers may be invoked re-entrantly during callbacks. ### Messaging To facilitate modularity and loose coupling, an extremely efficient `MessageBus` passes messages (data, commands and events) between components. #### Threading model Within a node, the *kernel* consumes and dispatches messages on a single thread. The kernel encompasses: - The `MessageBus` and actor callback dispatch. - Strategy logic and order management. - Risk engine checks and execution coordination. - Cache reads and writes. This single-threaded core provides deterministic event ordering and helps maintain backtest-live parity, though live inputs and latency can still cause behavioral differences. Components consume messages synchronously in a pattern *similar* to the [actor model](https://en.wikipedia.org/wiki/Actor_model). :::note Of interest is the LMAX exchange architecture, which achieves award winning performance running on a single thread. You can read about their *disruptor* pattern based architecture in [this interesting article](https://martinfowler.com/articles/lmax.html) by Martin Fowler. ::: Background services use separate threads or async runtimes: - **Network I/O** - WebSocket connections, REST clients, and async data feeds. - **Persistence** - DataFusion queries and database operations via multi-threaded Tokio runtime. - **Adapters** - Async adapter operations via thread pool executors. These services communicate results back to the kernel via the `MessageBus`. The bus itself is thread-local, so each thread has its own instance, with cross-thread communication occurring through channels that ultimately deliver events to the single-threaded core. ## Framework organization The codebase is organized with a layering of abstraction levels, and generally grouped into logical subpackages of cohesive concepts. You can navigate to the documentation for each of these subpackages from the left nav menu. ### Core / low-Level - `core`: Constants, functions and low-level components used throughout the framework. - `common`: Common parts for assembling the frameworks various components. - `network`: Low-level base components for networking clients. - `serialization`: Serialization base components and serializer implementations. - `model`: Defines a rich trading domain model. ### Components - `accounting`: Different account types and account management machinery. - `adapters`: Integration adapters for the platform including brokers and exchanges. - `analysis`: Components relating to trading performance statistics and analysis. - `cache`: Provides common caching infrastructure. - `data`: The data stack and data tooling for the platform. - `execution`: The execution stack for the platform. - `indicators`: A set of efficient indicators and analyzers. - `persistence`: Data storage, cataloging and retrieval, mainly to support backtesting. - `portfolio`: Portfolio management functionality. - `risk`: Risk specific components and tooling. - `trading`: Trading domain specific components and tooling. ### System implementations - `backtest`: Backtesting componentry as well as a backtest engine and node implementations. - `live`: Live engine and client implementations as well as a node for live trading. - `system`: The core system kernel common between `backtest`, `sandbox`, `live` [environment contexts](#environment-contexts). ## Code structure The foundation of the codebase is the `crates` directory, containing a collection of Rust crates including a C foreign function interface (FFI) generated by `cbindgen`. The bulk of the production code resides in the `nautilus_trader` directory, which contains a collection of Python/Cython subpackages and modules. Python bindings for the Rust core are provided by statically linking the Rust libraries to the C extension modules generated by Cython at compile time (effectively extending the CPython API). ### Dependency flow ```mermaid flowchart TB subgraph trader["nautilus_trader<br/>Python / Cython"] end subgraph core["crates<br/>Rust"] end trader -->|"C API"| core ``` ### Rust crates The `crates/` directory contains the Rust implementation organized into focused crates with clear dependency boundaries. Feature flags control optional functionality - for example, `streaming` enables persistence for catalog-based data streaming, and `cloud` enables cloud storage backends (S3, Azure, GCP). Dependency flow (arrows point to dependencies): ```mermaid flowchart BT subgraph Foundation core model common system trading end subgraph Infrastructure serialization network cryptography persistence end subgraph Engines data execution portfolio risk end subgraph Runtime live backtest end adapters pyo3 model --> core common --> core common --> model system --> common trading --> common serialization --> model network --> common network --> cryptography persistence --> serialization data --> common execution --> common portfolio --> common risk --> portfolio live --> system live --> trading backtest --> system backtest --> persistence adapters --> live adapters --> network pyo3 --> adapters ``` **Crate categories:** | Category | Crates | Purpose | |----------------|-----------------------------------------------------------|----------------------------------------------------------| | Foundation | `core`, `model`, `common`, `system`, `trading` | Primitives, domain model, kernel, actor & strategy base. | | Engines | `data`, `execution`, `portfolio`, `risk` | Core trading engine components. | | Infrastructure | `serialization`, `network`, `cryptography`, `persistence` | Encoding, networking, signing, storage. | | Runtime | `live`, `backtest` | Environment-specific node implementations. | | External | `adapters/*` | Venue and data integrations. | | Bindings | `pyo3` | Python bindings. | **Feature flags:** | Feature | Crates | Effect | |-------------|----------------------------|------------------------------------------------------------| | `streaming` | `data`, `system`, `live` | Enables `persistence` dependency for catalog streaming. | | `cloud` | `persistence` | Enables cloud storage backends (S3, Azure, GCP, HTTP). | | `python` | most crates | Enables PyO3 bindings (auto-enables `streaming`, `cloud`). | | `defi` | `common`, `model`, `data` | Enables DeFi/blockchain data types. | :::note Both Rust and Cython are build dependencies. The binary wheels produced from a build do not require Rust or Cython to be installed at runtime. ::: ### Type safety The design of the platform prioritizes software correctness and safety at the highest level. The Rust codebase under `crates/` relies on the `rustc` compiler's guarantees for safe code. Any `unsafe` blocks are explicit opt-outs where we must uphold the required invariants ourselves (see the Rust section of the [Developer Guide](../developer_guide/rust.md)); overall memory and type safety depend on those invariants holding. Cython provides type safety at the C level at both compile time, and runtime: :::info If you pass an argument with an invalid type to a Cython implemented module with typed parameters, then you will receive a `TypeError` at runtime. ::: If a function or method's parameter is not explicitly typed to accept `None`, passing `None` as an argument will result in a `ValueError` at runtime. :::warning The above exceptions are not explicitly documented to prevent excessive bloating of the docstrings. ::: ### Errors and exceptions Every attempt has been made to accurately document the possible exceptions which can be raised from NautilusTrader code, and the conditions which will trigger them. :::warning There may be other undocumented exceptions which can be raised by Python's standard library, or from third party library dependencies. ::: ### Processes and threads :::warning **One node per process** Running multiple `TradingNode` or `BacktestNode` instances **concurrently** in the same process is not supported due to global singleton state: - **Backtest force-stop flag** - The `_FORCE_STOP` global flag is shared across all engines in the process. - **Logger mode and timestamps** - The logging subsystem uses global state; backtests flip between static and real-time modes. - **Runtime singletons** - Global Tokio runtime, callback registries, and other `OnceLock` instances are process-wide. **Sequential execution** of multiple nodes (one after another with proper disposal between runs) is fully supported and used in the test suite. For production deployments, add multiple strategies to a **single TradingNode** within a process. For parallel execution or workload isolation, run each node in its own separate process. ::: ## Related guides - [Overview](overview.md) - High-level introduction to NautilusTrader. - [Message Bus](message_bus.md) - Core messaging infrastructure.
```

### 📝 Snippet 6 (Source: ?)
> """ This module gathers tree-based methods, including decision, regression and randomized trees. Single and multi-output problems are both handled. """ # Authors: Gilles Louppe <g.louppe@gmail.com> # Peter Prettenhofer <peter.prettenhofer@gmail.com> # Brian Holt <bdholt1@gmail.com> # Noel Dawe <noel@dawe.me> # Satrajit Gosh <satrajit.ghosh@gmail.com> # Joly Arnaud <arnaud.v.joly@gmail.com> # Fares Hedayati <fares.hedayati@gmail.com> # Nelson Liu <nelson@nelsonliu.me> # # License: BSD 3 clause import copy import numbers from abc import ABCMeta, abstractmethod from math import ceil from numbers import Integral, Real import numpy as np from scipy.sparse import issparse from sklearn.base import ( BaseEstimator, ClassifierMixin, MultiOutputMixin, RegressorMixin, _fit_context, clone, is_classifier, ) from sklearn.utils import Bunch, check_random_state, compute_sample_weight from sklearn.utils._param_validation import Hidden, Interval, RealNotInt, StrOptions from sklearn.utils.multiclass impo...

### 📝 Snippet 7 (Source: ?)
> # [v4.1.0](https://github.com/perspective-dev/perspective/releases/tag/v4.1.0) _27 January 2026_ ([Full changelog](https://github.com/finos/perspective/compare/v4.1.0...v4.1.0)) **Breaking** - Add `table` to `ViewerConfig` [#3107](https://github.com/finos/perspective/pull/3107) Features - DuckDB Virtual Server [#3062](https://github.com/finos/perspective/pull/3062) Fixes - Support `client.table(view)` in Python [#3112](https://github.com/finos/perspective/pull/3112) - Fix Arrow decimal type conversion to float instead of integer [#3099](https://github.com/finos/perspective/pull/3099) - Fix viewport scroll regression in datagrid [#3098](https://github.com/finos/perspective/pull/3098) Misc - `&lt;PerspectiveWorkspace&gt;` React component [#3109](https://github.com/finos/perspective/pull/3109) - Fix windows Python builds [#3110](https://github.com/finos/perspective/pull/3110) - Convert `viewer-datagrid` to TypeScript [#3108](https://github.com/finos/perspective/pull/3108) # [v4.0.1](https...

### 💻 Snippet 8 (Source: ?)
```
// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓ // ┃ ██████ ██████ ██████ █ █ █ █ █ █▄ ▀███ █ ┃ // ┃ ▄▄▄▄▄█ █▄▄▄▄▄ ▄▄▄▄▄█ ▀▀▀▀▀█▀▀▀▀▀ █ ▀▀▀▀▀█ ████████▌▐███ ███▄ ▀█ █ ▀▀▀▀▀ ┃ // ┃ █▀▀▀▀▀ █▀▀▀▀▀ █▀██▀▀ ▄▄▄▄▄ █ ▄▄▄▄▄█ ▄▄▄▄▄█ ████████▌▐███ █████▄ █ ▄▄▄▄▄ ┃ // ┃ █ ██████ █ ▀█▄ █ ██████ █ ███▌▐███ ███████▄ █ ┃ // ┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫ // ┃ Copyright (c) 2017, the Perspective Authors. ┃ // ┃ ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ ┃ // ┃ This file is part of the Perspective library, distributed under the terms ┃ // ┃ of the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). ┃ // ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛ import { find, toArray } from "@lumino/algorithm"; import { CommandRegistry } from "@lumino/commands"; import { SplitPanel, Panel, DockPanel } from "@lumino/widgets"; import uniqBy from "lodash/uniqBy"; import { DebouncedFunc, DebouncedFuncLeading, isEqual } from "lodash"; import { throttle } from "lodash"; import debounce from "lodash/debounce"; import type { HTMLPerspectiveViewerElement, ViewerConfigUpdate, } from "@perspective-dev/viewer"; import type * as psp from "@perspective-dev/client"; import type * as psp_viewer from "@perspective-dev/viewer"; import injectedStyles from "../../../build/css/injected.css"; import { PerspectiveDockPanel } from "./dockpanel"; import { WorkspaceMenu } from "./menu"; import { createCommands } from "./commands"; import { PerspectiveViewerWidget } from "./widget"; class AsyncMutex { _lock: Promise<unknown> | null; constructor() { this._lock = null; } lock<A>(continuation: () => Promise<A>): Promise<A> { if (this._lock !== null) { return this._lock.then(() => this.lock(continuation)); } this._lock = new Promise((x, y) => continuation() .then((z) => { this._lock = null; x(z); }) .catch((e) => { this._lock = null; y(e); }), ); return this._lock as Promise<A>; } } export type PerspectiveSplitArea = { type: "split-area"; sizes: number[]; orientation: "horizontal" | "vertical"; children: PerspectiveLayout[]; }; export type PerspectiveTabArea = { type: "tab-area"; currentIndex: number; widgets: string[]; }; export type PerspectiveLayout = PerspectiveSplitArea | PerspectiveTabArea; export interface PerspectiveWorkspaceConfig { sizes: number[]; viewers: Record<string, psp_viewer.ViewerConfigUpdate>; detail: { main: PerspectiveLayout | null }; master?: { sizes: number[]; widgets: string[]; }; } const DEFAULT_WORKSPACE_SIZE = [1, 3]; let ID_COUNTER = 0; export function genId(workspace: PerspectiveWorkspaceConfig) { let i = `PERSPECTIVE_GENERATED_ID_${ID_COUNTER++}`; if (Object.keys(workspace.viewers).includes(i)) { i = genId(workspace); } return i; } /// This function takes a workspace config and viewer config and adds the /// viewer config to the workspace config, returning a new workspace config. /// This is a slightly different algorithm from the Lumino one, /// which will be used on internal workspace actions (such as duplication). /// It currently attaches the viewer using a split-right style, /// (see Lumino docklayout.ts for documentation on insert modes). export function addViewer( workspace: PerspectiveWorkspaceConfig, config: psp_viewer.ViewerConfigUpdate, id: string, ): PerspectiveWorkspaceConfig { const GOLDEN_RATIO = 0.618; /// ensures that the sum of the input is 1 /// keeps the relative size of the elements function normalize(sizes: number[]) { const sum = sizes.reduce((a, b) => a + b, 0); return sum === 1 ? sizes : sizes.map((size) => size / sum); } if (workspace.detail.main === null) { return { sizes: workspace.sizes, viewers: { ...workspace.viewers, [id]: config, }, detail: { main: { type: "split-area", sizes: [1], orientation: "horizontal", children: [ { type: "tab-area", currentIndex: 0, widgets: [id], }, ], }, }, master: workspace.master, }; } else if ( workspace.detail.main.type === "tab-area" || (workspace.detail.main.type === "split-area" && workspace.detail.main.orientation === "vertical") ) { return { sizes: workspace.sizes, viewers: { ...workspace.viewers, [id]: config, }, detail: { main: { type: "split-area", sizes: [0.5, 0.5], orientation: "horizontal", children: [ workspace.detail.main, { type: "tab-area", currentIndex: 0, widgets: [id], }, ], }, }, master: workspace.master, }; } else if ( workspace.detail.main.type === "split-area" && workspace.detail.main.orientation === "horizontal" ) { return { sizes: workspace.sizes, viewers: { ...workspace.viewers, [id]: config, }, detail: { main: { type: "split-area", sizes: normalize([ ...normalize(workspace.detail.main.sizes), GOLDEN_RATIO, ]), orientation: "horizontal", children: [ ...workspace.detail.main.children, { type: "tab-area", currentIndex: 0, widgets: [id], }, ], }, }, master: workspace.master, }; } else { throw new Error("Unknown workspace state"); } } export class PerspectiveWorkspace extends SplitPanel { private dockpanel: PerspectiveDockPanel; private detailPanel: Panel; private masterPanel: SplitPanel; client: psp.Client[]; element: HTMLElement; menu_elem: HTMLElement; private listeners: WeakMap<PerspectiveViewerWidget, () => void>; private indicator: HTMLElement; private commands: CommandRegistry; private _menu?: WorkspaceMenu; private _minimizedLayoutSlots?: Promise<DockPanel.ILayoutConfig>; private _minimizedLayout?: DockPanel.ILayoutConfig; private _maximizedWidget?: PerspectiveViewerWidget; private _last_updated_state?: PerspectiveWorkspaceConfig; _mutex: AsyncMutex; // private _context_menu?: Menu & { init_overlay?: () => void }; constructor(element: HTMLElement) { super({ orientation: "horizontal" }); this.addClass("perspective-workspace"); this.dockpanel = new PerspectiveDockPanel(this); this.detailPanel = new Panel(); this.detailPanel.layout!.fitPolicy = "set-no-constraint"; this.detailPanel.addClass("perspective-scroll-panel"); this.detailPanel.addWidget(this.dockpanel); this.masterPanel = new SplitPanel({ orientation: "vertical" }); this.masterPanel.addClass("master-panel"); this._mutex = new AsyncMutex(); this.dockpanel.layoutModified.connect(() => { this.workspaceUpdated(); }); this.addWidget(this.detailPanel); this.element = element; this.listeners = new WeakMap(); this.client = []; this.indicator = this.init_indicator(); this.commands = createCommands(this, this.indicator); this.menu_elem = document.createElement("perspective-workspace-menu"); this.menu_elem.attachShadow({ mode: "open" }); this.menu_elem.shadowRoot!.innerHTML = `<style>:host{position:absolute;}${injectedStyles}</style>`; this.element.shadowRoot!.insertBefore( this.menu_elem, this.element.shadowRoot!.lastElementChild!, ); element.addEventListener("contextmenu", (event) => this.showContextMenu(null, event), ); } get_context_menu(): WorkspaceMenu | undefined { return this._menu; } get_dock_panel(): PerspectiveDockPanel { return this.dockpanel; } init_indicator() { const exists = document.querySelector("body > perspective-indicator"); if (exists) { return exists as HTMLElement; } const indicator = document.createElement("perspective-indicator"); indicator.style.position = "fixed"; indicator.style.pointerEvents = "none"; document.body.appendChild(indicator); return indicator; } apply_indicator_theme() { const theme_name = JSON.parse( window .getComputedStyle(this.element) .getPropertyValue("--theme-name") .trim(), ); this.indicator.setAttribute("theme", theme_name); } /*************************************************************************** * * `<perspective-workspace>` Public API * */ async save(): Promise<PerspectiveWorkspaceConfig> { return await this._mutex.lock(async () => { const is_settings = this.dockpanel.mode === "single-document"; let detail = is_settings ? await this._minimizedLayoutSlots : await PerspectiveDockPanel.mapWidgets( async (widget) => ( widget as PerspectiveViewerWidget ).viewer.getAttribute("slot"), this.dockpanel.saveLayout(), ); const layout: PerspectiveWorkspaceConfig = { sizes: [...this.relativeSizes()], detail: detail as { main: PerspectiveLayout }, viewers: {}, master: undefined as | { widgets: string[]; sizes: number[] } | undefined, }; if (this.masterPanel.isAttached) { const master = { widgets: this.masterPanel.widgets.map( (widget) => ( widget as PerspectiveViewerWidget ).viewer.getAttribute("slot")!, ), sizes: [...this.masterPanel.relativeSizes()], }; layout.master = master; } // const viewers: Record<string, ViewerConfigUpdate> = {}; for (const widget of this.masterPanel.widgets) { const psp_widget = widget as PerspectiveViewerWidget; layout.viewers[psp_widget.viewer.getAttribute("slot")!] = await psp_widget.save(); } const widgets = PerspectiveDockPanel.getWidgets( is_settings ? this._minimizedLayout! : this.dockpanel.saveLayout(), ); await Promise.all( widgets.map(async (widget) => { const psp_widget = widget as PerspectiveViewerWidget; const slot = psp_widget.viewer.getAttribute("slot")!; layout.viewers[slot] = await psp_widget.save(); layout.viewers[slot]!.settings = false; }), ); return layout; }); } async restore(value: PerspectiveWorkspaceConfig) { await this._mutex.lock(async () => { const { sizes, master, detail, viewers: viewer_configs = {}, } = structuredClone(value); if (master && master.widgets!.length > 0) { this.setupMasterPanel(sizes || DEFAULT_WORKSPACE_SIZE); } else { if (this.masterPanel.isAttached) { this.detailPanel.removeClass("has-master-panel"); this.masterPanel.close(); } this.addWidget(this.detailPanel); } let tasks: Promise<void>[] = []; // Using ES generators as context managers .. for (const viewers of this._capture_viewers()) { for (const widgets of this._capture_widgets()) { for (const v of viewers) { v.removeAttribute("class"); } const callback = this._restore_callback.bind( this, viewer_configs, viewers, widgets, ); if (detail) { const detailLayout = await PerspectiveDockPanel.mapWidgets( (name: string) => callback.bind(this, false)(name), detail, ); this.dockpanel.mode = "multiple-document"; this.dockpanel.restoreLayout(detailLayout); tasks = tasks.concat( PerspectiveDockPanel.getWidgets(detailLayout).map( (x) => ( x as PerspectiveViewerWidget ).viewer.flush(), ), ); } if (master) { // tasks = tasks.concat( const tasks2: any[] = [], names: string[] = []; master.widgets!.map((name) => { names.push(name); tasks2.push(callback.bind(this, true)(name)); return name; }); // return name; tasks.push( Promise.all(tasks2).then((x) => { master.widgets = master.widgets!.map((name) => { const idx = names.indexOf(name); const task = x[idx]; return task; }); }), ); // const widgets = await Promise.all(tasks); // ); master.sizes && this.masterPanel.setRelativeSizes(master.sizes); } } } await Promise.all(tasks); }); } *_capture_widgets() { const widgets = this.getAllWidgets(); yield widgets; for (const widget of widgets) { if (!widget.node.isConnected) { widget.close(); } } } *_capture_viewers() { const viewers = Array.from( this.element.children, ) as HTMLPerspectiveViewerElement[]; yield viewers; const ending_widgets = this.getAllWidgets(); for (const viewer of viewers) { let widget = ending_widgets.find((x) => { const psp_widget = x as PerspectiveViewerWidget; return psp_widget.viewer === viewer; }); if ( !widget && Array.from(this.element.children).indexOf(viewer) > -1 ) { this.element.removeChild(viewer); viewer.delete(); viewer.free(); } } } async _restore_callback( viewers: Record<string, psp_viewer.ViewerConfigUpdate>, starting_viewers: HTMLPerspectiveViewerElement[], starting_widgets: PerspectiveViewerWidget[], master: boolean, widgetName: string, ) { let viewer_config; viewer_config = viewers[widgetName]; let viewer = !!widgetName && starting_viewers.find((x) => x.getAttribute("slot") === widgetName); let widget; if (viewer) { widget = starting_widgets.find((x) => x.viewer === viewer); if (widget) { await widget.restore({ ...viewer_config }); } else { widget = await this._createWidget({ config: { ...viewer_config }, viewer, }); } } else if (viewer_config) { widget = await this._createWidgetAndNode({ config: { ...viewer_config }, slot: widgetName, }); } else { throw new Error( `Could not find or create <perspective-viewer> for slot "${widgetName}"`, ); } if (master) { widget.viewer.classList.add("workspace-master-widget"); widget.viewer.toggleAttribute("selectable", true); widget.viewer.addEventListener( "perspective-select", this.onPerspectiveSelect.bind(this), ); // TODO remove event listener this.masterPanel.addWidget(widget); } return widget; } _validate(table: any) { if (!table || !("view" in table) || typeof table?.view !== "function") { throw new Error( "Only `perspective.Table()` instances can be added to `tables`", ); } return table; } _set_listener(name: string, table: psp.Table | Promise<psp.Table>) { if (table instanceof Promise) { table = table.then(this._validate); } else { this._validate(table); } } _delete_listener(name: string) { this.getAllWidgets().some((widget) => { const psp_widget = widget as PerspectiveViewerWidget; if (psp_widget.viewer.getAttribute("table") === name) { psp_widget.viewer.eject(); } }); } async update_widget_for_viewer(viewer: HTMLPerspectiveViewerElement) { let slot_name = viewer.getAttribute("slot"); if (!slot_name) { slot_name = this._gen_id(); viewer.setAttribute("slot", slot_name); } const table_name = viewer.getAttribute("table"); if (table_name) { const slot = this.node.querySelector(`slot[name=${slot_name}]`); if (!slot) { console.warn( `Undocked ${viewer.outerHTML}, creating default layout`, ); const widget = await this._createWidget({ // config: {}, viewer, }); this.dockpanel.addWidget(widget); this.dockpanel.activateWidget(widget); } } else { console.warn(`No table set for ${viewer.outerHTML}`); } } remove_unslotted_widgets(viewers: HTMLPerspectiveViewerElement[]) { const widgets = this.getAllWidgets(); for (const widget of widgets) { const psp_widget = widget as PerspectiveViewerWidget; let missing = viewers.indexOf(psp_widget.viewer) === -1; if (missing) { psp_widget.close(); } } } update_details_panel(viewers: HTMLPerspectiveViewerElement[]) { if (this.masterPanel.widgets.length === 0) { this.masterPanel.close(); } } /*************************************************************************** * * Workspace-level contextmenu actions * */ async duplicate(widget: PerspectiveViewerWidget): Promise<void> { if (this.dockpanel.mode === "single-document") { const _task = await this._maximizedWidget!.viewer.toggleConfig(false); this._unmaximize(); } const config = await widget.save(); config.settings = false; config.title = config.title ? `${config.title} (*)` : ""; const duplicate = await this._createWidgetAndNode({ config, slot: undefined, }); this.dockpanel.addWidget(duplicate, { mode: "split-right", ref: widget, }); await duplicate.viewer.flush(); } toggleMasterDetail(widget: PerspectiveViewerWidget) { const isGlobalFilter = widget.parent !== this.dockpanel; this.element.dispatchEvent( new CustomEvent("workspace-toggle-global-filter", { detail: { widget, isGlobalFilter: !isGlobalFilter, }, }), ); if (isGlobalFilter) { this.makeDetail(widget); } else { if (this.dockpanel.mode === "single-document") { this.toggleSingleDocument(widget); } this.makeMaster(widget); } } _maximize(widget: PerspectiveViewerWidget) { widget.viewer.classList.add("widget-maximize"); if (!this._minimizedLayout) { this._minimizedLayout = this.dockpanel.saveLayout(); this._minimizedLayoutSlots = PerspectiveDockPanel.mapWidgets( async (widget: PerspectiveViewerWidget) => widget.viewer.getAttribute("slot"), this.dockpanel.saveLayout(), ); } this._maximizedWidget = widget; this.dockpanel.mode = "single-document"; this.dockpanel.activateWidget(widget); } _unmaximize() { this._maximizedWidget!.viewer.classList.remove("widget-maximize"); this.dockpanel.mode = "multiple-document"; this.dockpanel.restoreLayout(this._minimizedLayout!); this._minimizedLayout = undefined; } toggleSingleDocument(widget: PerspectiveViewerWidget) { if (this.dockpanel.mode !== "single-document") { this._maximize(widget); } else { this._unmaximize(); } } async _filterViewer( viewer: HTMLPerspectiveViewerElement, filters: [string, string, string][], candidates: Set<string>, ) { const config = await viewer.save(); const table = await viewer.getTable(); const availableColumns = Object.keys(await table.schema()); const currentFilters = config.filter || []; const columnAvailable = (filter: [string, string, any]) => filter[0] && availableColumns.includes(filter[0]); const validFilters = filters.filter(columnAvailable); validFilters.push( ...currentFilters.filter( (x: [string, ..._: string[]]) => !candidates.has(x[0]), ), ); const newFilters = uniqBy(validFilters, (item) => item[0]); await viewer.restore({ filter: newFilters }); } async onPerspectiveSelect(event: CustomEvent) { const config = await ( event.target as HTMLPerspectiveViewerElement ).save(); const candidates = new Set([ ...(config["group_by"] || []), ...(config["split_by"] || []), ...(config.filter || []).map((x: [string, string, any]) => x[0]), ]); const filters = [...event.detail.config.filter]; toArray(this.dockpanel.widgets()).forEach((widget) => { this._filterViewer( (widget as PerspectiveViewerWidget).viewer, filters, candidates, ); }); } async makeMaster(widget: PerspectiveViewerWidget) { if (widget.viewer.hasAttribute("settings")) { await widget.toggleConfig(); } widget.viewer.classList.add("workspace-master-widget"); widget.viewer.toggleAttribute("selectable", true); if (!this.masterPanel.isAttached) { this.detailPanel.close(); this.setupMasterPanel(DEFAULT_WORKSPACE_SIZE); } this.masterPanel.addWidget(widget); widget.isHidden && widget.show(); widget.viewer.restyleElement(); widget.viewer.addEventListener( "perspective-select", this.onPerspectiveSelect.bind(this), ); } makeDetail(widget: PerspectiveViewerWidget) { widget.viewer.classList.remove("workspace-master-widget"); widget.viewer.toggleAttribute("selectable", false); this.dockpanel.addWidget(widget, { mode: `split-left` }); if (this.masterPanel.widgets.length === 0) { this.detailPanel.close(); this.masterPanel.close(); this.detailPanel.removeClass("has-master-panel"); this.addWidget(this.detailPanel); } widget.viewer.restyleElement(); widget.viewer.removeEventListener( "perspective-select", this.onPerspectiveSelect.bind(this), ); } /*************************************************************************** * * Context Menu * */ createContextMenu(widget: PerspectiveViewerWidget | null) { this._menu = new WorkspaceMenu( this.menu_elem.shadowRoot!, this.element, { commands: this.commands, }, ); const tabbar = find( this.dockpanel.tabBars(), (bar) => bar.currentTitle?.owner === widget, ); this._menu.init_overlay = () => { if (widget) { widget.addClass("context-focus"); widget.viewer.classList.add("context-focus"); tabbar && tabbar.node.classList.add("context-focus"); this.element.classList.add("context-menu"); this.addClass("context-menu"); if ( widget.viewer.classList.contains("workspace-master-widget") ) { this._menu!.node.classList.add("workspace-master-menu"); } else { this._menu!.node.classList.remove("workspace-master-menu"); } } }; if (widget?.parent === this.dockpanel || widget === null) { this._menu.addItem({ type: "submenu", command: "workspace:newmenu", submenu: (() => { const submenu = new WorkspaceMenu( this.menu_elem.shadowRoot!, this.element, { commands: this.commands, }, ); (async () => { const names = await Promise.all( this.client.map((c) => c.get_hosted_table_names()), ).then((x) => x.flat()); for (const table of names) { let args; if (widget !== null) { args = { table, widget_name: widget.viewer.getAttribute("slot"), }; } else { args = { table }; } submenu.insertItem(0, { command: "workspace:new", args, }); } })(); const widgets = PerspectiveDockPanel.getWidgets( this.dockpanel.saveLayout(), ); if (widgets.length > 0) { submenu.addItem({ type: "separator" }); } let seen = new Set(); for (const target_widget of widgets) { if (!seen.has(target_widget.title.label)) { let args; if (widget !== null) { args = { target_widget_name: target_widget.viewer.getAttribute( "slot", ), widget_name: widget.viewer.getAttribute("slot"), }; } else { args = { target_widget_name: target_widget.viewer.getAttribute( "slot", ), }; } submenu.addItem({ command: "workspace:newview", args, }); seen.add(target_widget.title.label); } } submenu.title.label = "New Table"; return submenu; })(), }); } if (widget) { const widget_name = widget.viewer.getAttribute("slot"); if (widget?.parent === this.dockpanel) { this._menu.addItem({ type: "separator" }); } this._menu.addItem({ command: "workspace:duplicate", args: { widget_name }, }); this._menu.addItem({ command: "workspace:master", args: { widget_name }, }); this._menu.addItem({ type: "separator" }); this._menu.addItem({ command: "workspace:settings", args: { widget_name }, }); this._menu.addItem({ command: "workspace:reset", args: { widget_name }, }); this._menu.addItem({ command: "workspace:export", args: { widget_name }, }); this._menu.addItem({ command: "workspace:copy", args: { widget_name }, }); this._menu.addItem({ type: "separator" }); this._menu.addItem({ command: "workspace:close", args: { widget_name }, }); this._menu.addItem({ command: "workspace:help", }); } this._menu.aboutToClose.connect(() => { if (widget) { this.element.classList.remove("context-menu"); this.removeClass("context-menu"); widget.removeClass("context-focus"); tabbar?.node?.classList.remove("context-focus"); } }); return this._menu; } showContextMenu(widget: PerspectiveViewerWidget | null, event: MouseEvent) { if (!event.shiftKey) { const menu = this.createContextMenu(widget); menu.init_overlay?.(); const rect = this.element.getBoundingClientRect(); menu.open(event.clientX - rect.x, event.clientY - rect.y, { host: this.menu_elem.shadowRoot as unknown as HTMLElement, }); event.preventDefault(); event.stopPropagation(); } } /*************************************************************************** * * Context Menu * */ clearLayout() { this.getAllWidgets().forEach((widget) => widget.close()); this.widgets.forEach((widget) => widget.close()); this.detailPanel.close(); if (this.masterPanel.isAttached) { this.detailPanel.removeClass("has-master-panel"); this.masterPanel.close(); } } setupMasterPanel(sizes: number[]) { this.detailPanel.addClass("has-master-panel"); this.addWidget(this.masterPanel); this.addWidget(this.detailPanel); this.setRelativeSizes(sizes); } async addViewer( config: psp_viewer.ViewerConfigUpdate, is_global_filter?: boolean, ) { await this._mutex.lock(async () => { if (this.dockpanel.mode === "single-document") { const _task = this._maximizedWidget!.viewer.toggleConfig(false); this._unmaximize(); } const widget = await this._createWidgetAndNode({ config }); if (is_global_filter) { if (!this.masterPanel.isAttached) { this.setupMasterPanel(DEFAULT_WORKSPACE_SIZE); } this.masterPanel.addWidget(widget); } else { if (!this.detailPanel.isAttached) { this.addWidget(this.detailPanel); } this.dockpanel.addWidget(widget, { mode: "split-right" }); } this.update(); }); } /********************************************************************* * Widget helper methods */ async _createWidgetAndNode({ config, slot: slotname, }: { config: psp_viewer.ViewerConfigUpdate; slot?: string; }) { const node = this._createNode(slotname); const table = config.table; const viewer = document.createElement("perspective-viewer"); viewer.setAttribute( "slot", node!.querySelector("slot")!.getAttribute("name")!, ); if (table) { viewer.setAttribute("table", table); } for (const client of this.client) { const tables = await client.get_hosted_table_names(); if (table && tables.indexOf(table) > -1) { await viewer.load(client); return await this._createWidget({ config, elem: node as HTMLElement, viewer, }); } } throw new Error(`Table "${table}" not found`); } _gen_id() { let genId = `PERSPECTIVE_GENERATED_ID_${ID_COUNTER++}`; if (this.element.querySelector(`[slot=${genId}]`)) { genId = this._gen_id(); } return genId; } _createNode(slotname?: string): HTMLElement { let node = this.node.querySelector(`slot[name=${slotname}]`); if (slotname === undefined || !node) { const slot = document.createElement("slot"); slotname = slotname || this._gen_id(); slot.setAttribute("name", slotname); const div = document.createElement("div"); div.classList.add("viewer-container"); div.appendChild(slot); node = document.createElement("div"); node.classList.add("workspace-widget"); node.appendChild(div); } else { node = node.parentElement!.parentElement; } return node as HTMLElement; } async _createWidget({ config, elem, viewer, }: { config?: psp_viewer.ViewerConfigUpdate; elem?: Element; viewer: HTMLPerspectiveViewerElement; }) { let node: HTMLElement = elem as HTMLElement; if (!node) { const slotname = viewer.getAttribute("slot") || undefined; node = this.node.querySelector(`slot[name=${slotname}]`)!; if (!node) { node = this._createNode(slotname)!; } else { node = node.parentElement!.parentElement!; } } const onAttach = () => { if (widget.viewer.parentElement !== this.element) { this.element.appendChild(widget.viewer); } const event = new CustomEvent("workspace-new-view", { detail: { config, widget }, }); this.element.dispatchEvent(event); }; const widget = new PerspectiveViewerWidget({ node, viewer, onAttach }); if (config) { await widget.restore(config); } widget.title.closable = true; this._addWidgetEventListeners(widget); return widget; } _addWidgetEventListeners(widget: PerspectiveViewerWidget) { if (this.listeners.has(widget)) { this.listeners.get(widget)!(); } const contextMenu = (event: MouseEvent) => this.showContextMenu(widget, event); const updated = async (event: CustomEvent) => { this.workspaceUpdated(); // Sometimes plugins or other external code fires this event and // does not populate this field! const config = typeof event.detail === "undefined" ? await widget.viewer.save() : event.detail; widget.title.label = config.title; widget._title = config.title; widget._is_pivoted = config.group_by?.length > 0; }; widget.node.addEventListener("contextmenu", contextMenu); // Settings const settings_before = (event: CustomEvent) => { if (event.detail && this.dockpanel.mode !== "single-document") { this._maximize(widget); } }; const settings_after = (event: CustomEvent) => { if (!event.detail && this.dockpanel.mode === "single-document") { this._unmaximize(); } }; widget.viewer.addEventListener( "perspective-status-indicator-click", (event) => { widget._titlebar_callback?.(event as MouseEvent); }, ); widget.viewer.addEventListener( "perspective-toggle-settings-before", settings_before, ); widget.viewer.addEventListener( "perspective-toggle-settings", settings_after, ); const delete_before = () => { if (!widget._deleted) { widget._deleted = true; widget.close(); } }; const delete_after = (event: CustomEvent) => { widget._titlebar?.handleEvent(event.detail as PointerEvent); }; widget.viewer.addEventListener( "perspective-table-delete-before", delete_before, ); widget.viewer.addEventListener( "perspective-statusbar-pointerdown", delete_after, ); // @ts-ignore widget.viewer.addEventListener("perspective-config-update", updated); this.listeners.set(widget, () => { widget.node.removeEventListener("contextmenu", contextMenu); widget.viewer.removeEventListener( "perspective-table-delete-before", delete_before, ); widget.viewer.removeEventListener( "perspective-table-delete", delete_after, ); widget.viewer.removeEventListener( "perspective-toggle-settings", settings_before, ); widget.viewer.removeEventListener( "perspective-toggle-settings", settings_after, ); // @ts-ignore widget.viewer.removeEventListener( "perspective-config-update", updated, ); }); } getWidgetByName(name: string): PerspectiveViewerWidget | null { return ( this.getAllWidgets().find( (x) => x.viewer.getAttribute("slot") === name, ) || null ); } getAllWidgets(): PerspectiveViewerWidget[] { return [ ...(this.masterPanel.widgets as PerspectiveViewerWidget[]), ...toArray(this.dockpanel.widgets()), ] as PerspectiveViewerWidget[]; } /*************************************************************************** * * `workspace-layout-update` event * */ _throttle?: DebouncedFuncLeading<() => Promise<void>>; async workspaceUpdated() { // if (!this._throttle) { // this._throttle = throttle(async () => { const layout = await this.save(); if (layout) { if (this._last_updated_state) { if (isEqual(this._last_updated_state, layout)) { return; } } this._last_updated_state = layout as any as PerspectiveWorkspaceConfig; this.element.dispatchEvent( new CustomEvent("workspace-layout-update", { detail: { layout }, }), ); } // }, 0); // } // this._throttle(); } }
```

### 📝 Snippet 9 (Source: ?)
> { "cells": [ { "cell_type": "markdown", "metadata": {}, "source": [ "### Function to call LLM" ] }, { "cell_type": "code", "execution_count": 1, "metadata": {}, "outputs": [], "source": [ "from openai import OpenAI\n", "from dotenv import load_dotenv\n", "import os\n", "\n", "load_dotenv()\n", "api_key = os.getenv(\"API_KEY\")\n", "\n", "client = OpenAI(api_key=api_key)\n", "\n", "def call_gpt(prompt):\n", " messages = [\n", " {\"role\": \"system\", \"content\": 'You are a well-trained data scientist specifically good at machine learning.'},\n", " {\"role\": \"user\", \"content\": prompt}\n", " ]\n", " response = client.chat.completions.create(\n", " model=\"gpt-4\",\n", " messages=messages,\n", " max_tokens=1000\n", " ).choices[0].message.content\n", " return response" ] }, { "cell_type": "markdown", "metadata": {}, "source": [ "### Code/ paper summaries" ] }, { "cell_type": "code", "execution_count": 2, "metadata": {}, "outputs": [], "source": [ "code_summaries = {\n", " 'MO-GAAL': \...

### 📝 Snippet 10 (Source: ?)
> @preconcurrency import Combine import SwiftUI /// A `ViewStore` is an object that can observe state changes and send actions. They are most /// commonly used in views, such as SwiftUI views, UIView or UIViewController, but they can be used /// anywhere it makes sense to observe state or send actions. /// /// In SwiftUI applications, a `ViewStore` is accessed most commonly using the ``WithViewStore`` /// view. It can be initialized with a store and a closure that is handed a view store and returns a /// view: /// /// ```swift /// var body: some View { /// WithViewStore(self.store, observe: { $0 }) { viewStore in /// VStack { /// Text("Current count: \(viewStore.count)") /// Button("Increment") { viewStore.send(.incrementButtonTapped) } /// } /// } /// } /// ``` /// /// View stores can also be observed directly by views, scenes, commands, and other contexts that /// support the `@ObservedObject` property wrapper: /// /// ```swift /// @ObservedObject var viewStore: ViewStore<State, Action...

### 💻 Snippet 11 (Source: article_1393.html)
```
// CONTEXT: Series: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles, Part: N/A, Title: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles

Introduction

There are three kinds of programs written in MQL4 and executed in the MetaTrader
4 Client Terminal:

- Expert Advisors;

- scripts;

- indicators.

Each of them is intended for solving a certain range of problems. Let us give a
brief description of the programs.

1. Brief Description of MQL4 User Programs

1.1. Expert Advisors

Expert Advisors (EAs) are the main kind of programs used to realize profitable trading
strategies. The distinctive features of an EA are listed below:

1. Ability to use embedded functions that support trades.

2. Ability to modify external settings manually.

3. Availability of rules that regulate launching of special function start(). It is launched tickwise. At the moment when a new tick incomes, parameters of the
entire environment available for this function are updated. For example, such variables
as bid and ask take new values. Having completed the code execution, namely - having reached operator
return, function start() finishes its operation and sleeps until a new tick incomes.

1.2. Scripts

Scripts are very similar to Expert Advisors, but their features are a bit different.
Main feautres of scripts are listed below:

1. Scripts can use the functions of trades, too.

2. Parameters of external settings cannot be changed in scripts.

3. The main feature of scripts is the rule, according to which special function
start() of a script will be launched only once, immediately after it has been attached
to the chart and initialized.

Expert Advisors and scripts are attached to the main window of a symbol, they cannot
have special subwindows.

1.3. Indicators

Unlike Expert Advisors and scripts, indicators have another intent:

1. The main feature of indicators is the possibility to draw continuous curves that
display one or another principle according to the idea implied in them.

2. Trade functions cannot be used in indicators.

3. Indicators are launched tickwise.

4. Regarding the parameters implied, the indicator can serve its purpose in the
main symbol window or in its own subwindow.

We listed above only main characteristics of custom programs, namely - those we
will need in our further speculations.

As we can see from the description above, no custom program has properties of all
programs: Expert Advisors and scripts cannot draw, indicators may not trade, etc.

If our trading system needs to use all properties of custom programs during trading,
the only solution will be simultaneous use of an Expert Advisor, a script and an
indicator.

2. Problem Statement

Let us consider criteria that provide necessity of simultaneous use of all custom
programs.

2.1. Timeliness

As we can see from the description above, no custom program has properties of all
programs: Expert Advisors and scripts cannot draw, indicators may not trade, etc.

If our trading system needs to use all properties of custom programs during trading,
the only solution will be simultaneous use of an Expert Advisor, a script and an
indicator.

2. Problem Statement

Let us consider criteria that provide necessity of simultaneous use of all custom
programs.

2.1. Timeliness

Any control by the user must be executed immediately. A program based on an Expert
Advisor is not always suitable for this purpose. The main disadvantage of Expert
Advisors is its inonsusceptibility to external actions. The reason for this limitation
is very simple: Expert Advisor's basic code is launched tickwise. What will happen
if the user commands the EA to close an order and the EA is waiting for the next
tick? The answer to this question depends on how the Expert Advisor has been written.
In some cases, the command will be executed, but with some delay.

The program can be organized in such a way that the main code of the Expert Advisor
is executed continuously, without breaks between ticks. For this purpose, it is
necessary to organize in special function

start() an infinite loop, in which the entire main code of the program will be placed. If
the environmental information is forcedly updated at the start of every loop, the
whole complex can work successfully. Disadvantage of a looped Expert Advisor is
the impossibility to open the setup panel. Try to loop an EA - and you won't be
able to set it up.

The same idea can be successfully realized using a script. This means an infinite
loop can be organized in a script. But there are no parameters to be set up in
scripts.

The customizability of the trading system and timeliness of executing all user's
commands in the continuous operation mode can be provided only using simultaneously
an Expert Advisor for setting up and a script for instant execution.

2.2. Awareness

In some cases, there is a necessity to get some information about trading. For example,
every trader would like to know that, at a certain moment (say two minutes prior
to important news being published), the dealing center has changed its normal 10
points of the minimal tolerable distance to place pending orders for 20 points.
Besides, as a rule, the trader wants to know the reason why the trade server refuses
to execute orders. This and other useful information can be shown as a text in
the indicator window. As well, on an on-going basis, the lines containing older
messages can be moved up to empty space for new messages from the trading system.
In this case, it is necessary to combine the trading Expert Advisor or a script
with a displaying indicator.

2.3. Controls

2.3. Controls

If you use a trading system that involves an enhanced interface, the controls (graphical
objects) are better to be placed in the indicator window. So we can be sure that
candle trend will not overlap our control items and, thus, will not disturb controlling.

2.4. System Requirements

The main requirement to the end product, in this case, is synchronous operation, so, developing a system based on all three types of programs, it is necessary
to dissociate tasks to be solved by all its components. Regarding special features
of each type of programs in our system, we can define the following properties
for them:

script - gives basic code containing analytical and trading functions;

Expert Advisor - provides setup panel;

indicator - provides subwindow field to display controls and information.

3. Software Solutions

Let us indicate at once that we consider here the structure of an application based
on three components within the minimum required range. If you decide to use the
application in practice, you will have to elaborate it by yourself as it concerns
analytical and trading operations. But the material given below is quite sufficient
for developing a structure.

3.1. Expert Advisor

Let us consider in details what an Expert Advisor consists of and how it works.

3. Software Solutions

Let us indicate at once that we consider here the structure of an application based
on three components within the minimum required range. If you decide to use the
application in practice, you will have to elaborate it by yourself as it concerns
analytical and trading operations. But the material given below is quite sufficient
for developing a structure.

3.1. Expert Advisor

Let us consider in details what an Expert Advisor consists of and how it works.

[CODE START]
// Expert.mq4
//====================================================== include =======
#include <stdlib.mqh>
#include <stderror.mqh>
#include <WinUser32.mqh>
//======================================================================
#include <Peremen_exp.mq4>  // Description of the EA variables.
#include <Metsenat_exp.mq4> // Predefinition of the EA variables.
#include <Del_GV_exp.mq4>  
// Deletion of all GlobalVariables created by the Expert Advisor.
#include <Component_exp.mq4> // Checking for availability of components.
#include <Component_uni.mq4>
// Message in the indicator that components are not available.
//======================================================================
//
//
//======================================================================
int init()  
  {
    Fishka=1;          // We are in init()  
    Metsenat_exp();   // Predefinition of the EA variables.
    Component_exp();  // Check for availability of components
    return;
 }
//=====================================================================
int start()
  {
    Fishka=2;         // We are in start()  
    Component_exp();  // Check for availability of components
    return;                                                                
 }
//=====================================================================
int deinit()
  {  
    Fishka=3;         // We are in deinit()  
    Component_exp();  // check for availability of components
    Del_GV_exp();     // Deletion of the Expert Advisor's GlobalVariable.
    return;
 }
//======================================================================
[CODE END]
In special function init(), two functions are working - Metsenat_exp() and Component_exp()

Metsenat_exp() - a function of predefinition of some variables.

Metsenat_exp() - a function of predefinition of some variables.

[CODE START]
// Metsenat_exp.mq4
//=================================================================
int Metsenat_exp()
 {
//============================================ Predefinitions =====
   Symb     = "_"+Symbol();
   GV       = "MyGrafic_GV_";
//============================================= GlobalVariable ====
   GV_Ind_Yes = GV+"Ind_Yes"   +Symb;      
// 0/1 confirms that the indicator is loaded
   GV_Scr_Yes = GV+"Scr_Yes"   +Symb;      
// 0/1 confirms that the script is loaded
//-------------------------------------------- Public Exposure ----
   GV_Exp_Yes = GV+"Exp_Yes"   +Symb;    
   GlobalVariableSet(GV_Exp_Yes, 1 );
   GV_Extern  = GV+"Extern"    +Symb;    
   GlobalVariableSet(GV_Extern,  1 );
//  AAA is used as an example:
   GV_AAA     = GV+"AAA"       +Symb;    
GlobalVariableSet(GV_AAA,   AAA );
//==================================================================
   return;
 }
//====================== End of Module =============================
[CODE END]
One of the tasks of the entire application maintenance is the task of tracking the
availability of all components. This is why all components (the script, the Expert
Advisor and the indicator) must trace each other and, if a component is not available,
stop working and inform the user about this. For this purpose, each program informs
about its availability at startup through publishing a global variable. In the
given case, in function Metsenat_exp() of the Expert Advisor, this will be done
in the line below:

[CODE START]
   GV_Exp_Yes = GV+"Exp_Yes"   +Symb;    
   GlobalVariableSet(GV_Exp_Yes, 1 );
[CODE END]
Function Metsenat_exp() is controlled by function init() of the EA, i.e., it is
used only once during loading or changing values of extern variables. The script
must 'know' about changed settings, this is why the Expert will inform the script
about it through changing the value of global variable GV_Extern:

[CODE START]
   GV_Extern  = GV+"Extern"    +Symb;    
   GlobalVariableSet(GV_Extern,  1 );
[CODE END]

Component_exp() - a function intended for completeness controlling. The further scenario depends
on the Expert Advisor's special function, in which the Component_exp() is used.

[CODE START]
// Component_exp.mq4
//===============================================================================================
int Component_exp()
 {
//===============================================================================================
   while( Fishka < 3 &&     // We are in init() or in start() and..
      (GlobalVariableGet(GV_Ind_Yes)!=1 ||
       GlobalVariableGet(GV_Scr_Yes)!=1))
    {                            // ..while a program is not available.
      Complect=0;                // Since one is inavailable, it is a deficiency
      GlobalVariableSet(GV_Exp_Yes, 1);
// Inform that the EA is available
//-----------------------------------------------------------------------------------------------
      if(GlobalVariableGet(GV_Ind_Yes)==1 &&
         GlobalVariableGet(GV_Scr_Yes)!=1)
        {//If there is an indicator but there is no scrip available, then..
         Graf_Text = "Script is not installed.";  
// Message text
         Component_uni();                            
// Write the message text in the indicator window.
        }
//-----------------------------------------------------------------------------------------------
      Sleep(300);
    }
//===============================================================================================
     if(Complect==0)
    {
      ObjectDelete("Necomplect_1");
// Deletion of unnecessary messages informing about inavailability of components  
      ObjectDelete("Necomplect_2");      
      ObjectsRedraw();              // For quick deletion
      Complect=1;        // If we have left the loop, it means that all components are available
    }
//===============================================================================================
   if(Fishka == 3 && GlobalVariableGet(GV_Ind_Yes)==1)
// We are in deinit(), and there is space to write the indicator into
    {
//-----------------------------------------------------------------------------------------------
      if(GlobalVariableGet(GV_Scr_Yes)!=1)  // If there is no script available,
       {
         Graf_Text = "Components Expert and Script are not installed";
// Message (since we are unloading)
         Component_uni();     // Write the message text in the indicator window
       }
//-----------------------------------------------------------------------------------------------
    }
//===============================================================================================
   return;
 }
//===================== End of the module =======================================================
[CODE END]
Availability of script and indicator is traced on the basis of reading values of
the corresponding global variables - GV_Scr_Yes and GV_Ind_Yes. If neither of the
components is available, the control will be given to the infinite loop until the
completeness is achieved, i.e., until both indicator and script are installed.
The application will inform user about the current state through function

Component_uni(). It is a universal function included in all components.

[CODE START]
// Component_uni.mq4
//================================================================
int Component_uni()
 {
//================================================================
//----------------------------------------------------------------
   Win_ind = WindowFind("Indicator");                
// What is our indicator's window number?
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   ObjectCreate ( "Necomplect_1", OBJ_LABEL, Win_ind, 0, 0  );
// Create an object in the indicator window
   ObjectSet    ( "Necomplect_1", OBJPROP_CORNER,        3  );
// coordinates related to the bottom-right corner
   ObjectSet    ( "Necomplect_1", OBJPROP_XDISTANCE,   450  );
// coordinates on X..
   ObjectSet    ( "Necomplect_1", OBJPROP_YDISTANCE,    16  );
// coordinates on Y..
   ObjectSetText("Necomplect_1", Graf_Text,10,"Courier New",Tomato);
// text, font, and color
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Graf_Text = "Application does not work.";
 // Message text
   ObjectCreate ( "Necomplect_2", OBJ_LABEL, Win_ind, 0, 0);
// Create an object in the indicator window
   ObjectSet    ( "Necomplect_2", OBJPROP_CORNER,        3);
// coordinates related to the bottom-right corner
   ObjectSet    ( "Necomplect_2", OBJPROP_XDISTANCE,   450);
// coordinates on Х..
   ObjectSet    ( "Necomplect_2", OBJPROP_YDISTANCE,     2);
// coordinates on Y..
   ObjectSetText("Necomplect_2", Graf_Text,10,"Courier New",Tomato);
// text, font, color
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   ObjectsRedraw();                                // Redrawing.
   return;
//================================================================
 }
//===================== End of module ============================
[CODE END]
As soon as the application is complete, the control in the EA will be given from
the loop to the sequent code where the unnecessary messagy about incompleteness
will be deleted.

When the EA is unloaded, special function deinit() will also call Component_exp(),
but for another purpose - to inform about the unloading at the current moment.

In the Expert Advisor's deinit(), function Del_GV_exp() will be called, as well.

 It is used to delete all GlobalVariables opened by the EA. According to the unwritten
rule, each program being unloaded must "clean the room", i.e., delete
global variables and graphical objects created before.

When the EA is unloaded, special function deinit() will also call Component_exp(),
but for another purpose - to inform about the unloading at the current moment.

In the Expert Advisor's deinit(), function Del_GV_exp() will be called, as well.

 It is used to delete all GlobalVariables opened by the EA. According to the unwritten
rule, each program being unloaded must "clean the room", i.e., delete
global variables and graphical objects created before.

[CODE START]
// Del_GV_exp.mq4
//=================================================================
int Del_GV_exp()
 {
//=================================================================
   GlobalVariableDel(GV_Exp_Yes      );
   GlobalVariableDel(GV_Extern       );
   GlobalVariableDel(GV_AAA          );
//=================================================================
   return;
 }
//====================== End of module ============================
[CODE END]
Thus, the Expert Advisor starts working and tracks the availability of the two other
components at all stages: once in init(), once in deinit() and at every tick -
in start(). This EA construction makes it possible to use the program for solving
our task - making the setup panel available. The file describing variables contains, as an example, variable ААА and its corresponding global variable GV_AAA,
the value of which is read from the script.

To get into details of how all this works, let us consider the structure of a script.

3.2. Script

Script code:

To get into details of how all this works, let us consider the structure of a script.

3.2. Script

Script code:

[CODE START]
// Script.mq4
//==================================================== include ====
#include <stdlib.mqh>
#include <stderror.mqh>
#include <WinUser32.mqh>
//=================================================================
#include <Peremen_scr.mq4>      
// File describing variables of the script.
#include <Metsenat_scr.mq4>      
// Predefining of variables of the script.  
#include <Mess_graf_scr.mq4>    
// List of graphical messages.
#include <Novator_scr.mq4>      
// Environment scanning, obtaining new values for some variables
#include <Del_GV_scr.mq4>        
// Deletion of all GlobalVariables created by the script.
#include <Component_scr.mq4>    
// Checking for components availability.
#include <Component_uni.mq4>    
// Message in the indicator about inavailability of components.
#include <Del_Obj_scr.mq4>      
// Deletion of all objects created by the program complex.
#include <Work_scr.mq4>          
// The main working function of the script.
//=================================================================
//
//
//=================================================================
int init()  
 {
   Fishka = 1;                                // We are in init()  
   Metsenat_scr();       // Predefining of variables of the script.
   return;
 }
//================================================================
int start()  
 {
   Fishka = 2;                               // We are in start()  
   while(true)
    {
      Component_scr();  // Checking for availability of components
      Work_scr();       // The main working function of the script.
    }
   return;
 }
//=================================================================
int deinit()
 {
   Fishka = 3;                                // We are in deinit()  
   Component_scr();      // Checking for availability of components
   Del_Obj_scr();          // Deletion of graphical objects created
   Del_GV_scr();        // Deletion of GlobalVariable of the script.
   return;
 }
//==================================================================
[CODE END]
The basis of the code is the availability of an infinite loop in special function
start(). In the script code, functions with similar names and contents are applied.
We turn our attention to their special features. At the beginning of every loop,
function

Component_scr() is called.

[CODE START]
// Component_scr.mq4  
//====================================================================
int Component_scr()
 {
//====================================================================
   Iter=0;                               // Zeroize iteration counter
   while (Fishka <3 &&              // We are in init() or in start()
      (GlobalVariableGet(GV_Ind_Yes)!=1 ||
       GlobalVariableGet(GV_Exp_Yes)!=1))
    {                                 // Until a program is available
      GlobalVariableSet(GV_Scr_Yes, 1);              
// Declare about the script availability
//--------------------------------------------------------------------
      Iter++;                                    // Iteration counter
      if(Iter==1)                         // Skip the first iteration
       {
         Sleep(500);
         continue;
       }
//--------------------------------------------------------------------
      if(Iter==2)             // Take measures on the second iteration
       {
         Complect=0; // Program is not available, it is incompleteness
         for (i=0;i<=31;i++)ObjectDelete(Name_Graf_Text[i]);
// Deletion of all strings
// Here, a function can be inserted that will zeroize trade queue.
       }
//--------------------------------------------------------------------
      if(GlobalVariableGet(GV_Ind_Yes)==1 &&
          GlobalVariableGet(GV_Exp_Yes)!=1)
       {                       // If there is an indicator, but no EA
         Graf_Text = "Expert has not been installed.";
// Message text
         Component_uni();                            
// Write the text message in the indicator window.
       }
//-----------------------------------------------------------------
      Sleep(300);
    }
//-----------------------------------------------------------------
   if(Complect==0)                // Process it once at completing.
    {
      ObjectDelete("Necomplect_1");
// Deletion of unnecessary messages..
      ObjectDelete("Necomplect_2");
// ..about incompleteness of components        
      Mess_graf_scr(1);
// Inform the user about completeness
      if( IsExpertEnabled())
// The button is enabled
       {
         Mess_graf_scr(3000);
         Knopka_Old = 1;
       }
      if(!IsExpertEnabled())
// The button is disabled
       {
         Mess_graf_scr(4000);
         Knopka_Old = 0;
       }
      Complect=1;
// The minimal installation completeness reached
      Redraw = 1;
// For quick deletion
    }
//====================================================================
   if(Fishka == 3 && GlobalVariableGet(GV_Ind_Yes)==1)      
// We are in deinit()  
    {
      for(i=0;i<=31;i++)ObjectDelete(Name_Graf_Text[i]);    
// Deletion of all strings
//--------------------------------------------------------------------
      if(GlobalVariableGet(GV_Exp_Yes)!=1)                
// There is indicator, but no Expert Advisor
         Graf_Text="Components Expert and Script are not installed.";

//====================================================================
   if(Fishka == 3 && GlobalVariableGet(GV_Ind_Yes)==1)      
// We are in deinit()  
    {
      for(i=0;i<=31;i++)ObjectDelete(Name_Graf_Text[i]);    
// Deletion of all strings
//--------------------------------------------------------------------
      if(GlobalVariableGet(GV_Exp_Yes)!=1)                
// There is indicator, but no Expert Advisor
         Graf_Text="Components Expert and Script are not installed.";
// Message (as we're unloading)
      if(GlobalVariableGet(GV_Exp_Yes)==1)
// If there are both indicator and EA, then..
         Graf_Text="The Script has not been installed.";
// Message (as we're unloading)
      Component_uni();   // Write the message in the indicator window.
//--------------------------------------------------------------------
      ObjectsRedraw();                    // For quick deletion
    }
//====================================================================
   return;
 }
//====================== End of module ===============================
[CODE END]
The first demand on a script is

continuity of its operation. During updating of extern variables, the Expert Advisor goes through the complete installation.
When pressing OK on the EA setup panel, it will be unloaded and give control to deinit(), then it will immediately
load again going through init() and start() sequentially. As a result, the Expert Advisorб though for a short
time, deletes from deinit() the global variable that confirms its availability.

In order the script does not suppose that the EA has not been loaded at all, function
Component_scr() contains a small block that disables making a decision at the first iteration:

[CODE START]
      Iter++;                         // Iteration counter
      if(Iter==1)              // Skip the first iteration
        {
          Sleep(500);
          continue;
        }
[CODE END]
Five hundred milliseconds will be, in most cases, enough for complete loading of
the Expert Advisor. If you use a more consuming code in the Expert Advisor's init(),
the time must be prolonged. If the EA has not been detected at the second iteration,
the decision will be made that the EA is not available at all, and the script stops
operating.

[CODE START]
      Complect = 0;    // A program is not available, incompleteness
[CODE END]
The expression "the script stops operating" is used in the preceding paragraph.
In our example, there is no code responsible for this phenomenon, just because
it is beyond the scope of our topic and this article. in the place where you can
put calling for the corresponding functions, there is a comment in the code.

[CODE START]
// Here, a function zeroizing trade counter can be inserted.
[CODE END]
In function

Work_scr() of a really working program, except for functions used in our example, other functions
are taken to be that are responsible for a certain order of events. For example,
if your program is adjusted to modify several orders, it will surely contain an
array, in which the queue for execution of trades will be stored if there is a
number of such trades occurring in the current tick.

If incompleteness occurs (for example, the Expert Advisor or the script has been
unloaded inadvertently) at the moment when such a queue takes place, it is necessary
to disable trading which can be achieved by zeroizing the above-mentioned array
of the trade queue and, perhaps, some other variables according to the situation.

The infinite loop of the script also contains function Work_scr(). This is the script main function where its entire main code must be placed.

If incompleteness occurs (for example, the Expert Advisor or the script has been
unloaded inadvertently) at the moment when such a queue takes place, it is necessary
to disable trading which can be achieved by zeroizing the above-mentioned array
of the trade queue and, perhaps, some other variables according to the situation.

The infinite loop of the script also contains function Work_scr(). This is the script main function where its entire main code must be placed.

[CODE START]
// Work_scr.mq4
//=================================================================
int Work_scr()  
 {
   Novator_scr();
//-----------------------------------------------------------------
   // Basic code of the entire application.
//------------------------------------------------ For example ----
   if(New_Tick==1)                             // At every new tick
    {                                                                    
      Alert ("The current value of ААА = ", AAA);
    }                                                                    
//-----------------------------------------------------------------
   if(Redraw==1)
    {
      ObjectsRedraw();                    // To display immediately
      Redraw=0;                         // Unflag objects redrawing
    }
//-----------------------------------------------------------------
   Mess_graf_scr(0);
   Sleep(1);                           // Just in case, from reload
   return;
 }
//====================== End of module ============================
[CODE END]
The Work_scr() contains function Novator_scr() intended for updating environmental variables used in the basic code.

[CODE START]
// Novator_scr.mq4  
//===================================================================
int Novator_scr()  
 {
//===================================================================
//---------------------------------------- Updating of settings -----
   if(GlobalVariableGet(GV_Extern)==1)
// There is an update in the EA
    {
      Metsenat_scr();         // Updating of the script variables.
      Mess_graf_scr(5000);    // Message about a new setting.
      Redraw=1;               // Redrawing at the end of the loop.
    }                                                                    
//--------------------------------- EA button state -----------------
   Knopka = 0;                                         // Preset
   if( IsExpertEnabled()) Knopka = 1;
// Check for the real state of the button

   if(Knopka==1 && Knopka_Old==0)
// If the state has changed for ON
    {
      Knopka_Old = 1;                // This will be the old one
      Mess_graf_scr(3);              // Inform the user about changes
    }
   if(Knopka==0 && Knopka_Old==1)
// If the state has changed for OFF
    {
      Knopka_Old = 0;                 // This will be the old one
      Mess_graf_scr(4);              // Inform the user about changes
    }
//-------------------------------------------------- New tick --------
   New_Tick=0;                              // First of all, zeroize
   if (RefreshRates()==true) New_Tick=1;
// It is easy to catch a new tick if you know how to do it
//--------------------------------------------------------------------
//====================================================================
   return;
 }
//=====================; End of module ===============================
[CODE END]

Let us consider the necessity of this function in more details. We mentioned at
the beginning of the article that every time when the EA is loaded, as well as
when its variables are updated, its subordinated function Metsenat_exp() sets the value of variable GV_Extern as 1. For the script, it means that the settings must be updated. For this purpose,
function Novator_scr() contains the following block:

[CODE START]
//---------------------------------------- Updating settings ----
   if (GlobalVariableGet(GV_Extern)==1)
// An update has taken place in the EA
    {
      Metsenat_scr();              // Updating script settings.
      Mess_graf_scr(5000);         // New setting message.
      Redraw=1;                    // Redrawing at the end of the loop.
    }
[CODE END]
The value of the above variable is analyzed here and, in case of necessity to update,
function

Metsenat_scr() is called, which makes the updating (reading of new values of global variables).

Metsenat_scr() is called, which makes the updating (reading of new values of global variables).

[CODE START]
// Metsenat_scr.mq4
//===================================================================
int Metsenat_scr()
  {
//========================================================== int ====
//======================================================= double ====
//======================================================= string ====
      MyGrafic    = "MyGrafic_";
    Mess_Graf   = "Mess_Graf_";
    Symb        = "_"+Symbol();
    GV          = "MyGrafic_GV_";
//=============================================== GlobalVariable ====
     GV_Ind_Yes  = GV+"Ind_Yes" +Symb;      
// 0/1 confirms that the indicator has been loaded
     GV_Exp_Yes  = GV+"Exp_Yes" +Symb;      
// 0/1 confirms that the EA has been loaded
//-------------------------------------------------- Publishing -----
     GV_Scr_Yes  = GV+"Scr_Yes" +Symb;    
    GlobalVariableSet(GV_Scr_Yes,          1 );
    GV_Extern   = GV+"Extern"  +Symb;    
    GlobalVariableSet(GV_Extern,           0 );
//--------------------------------------------------- Reading -------
                                             //  AAA is used as an example:
     GV_AAA      = GV+"AAA"     +Symb;    
   AAA  = GlobalVariableGet(GV_AAA);
//===================================================================
     return;
 }
//======================== End of module ============================
[CODE END]
Function Metsenat_scr(), in its turn, sets value of global variable GV_Extern as
0. In the subsequent history, this variable remains equal to 0 until the user opens
the EA's setup window.

Note that, in spite of the fact that due to its changed settings the EA goes through
all stages of unloading and loading, the script does not stop working during the
user is changing the settings or after that. Thus, the combined usage of the Expert
Advisor and the script helps to meet the requirement of operation continuity of the application and allows the user to change settings, i.e., to control the process.

In the subsequent blocks of function Novator_scr(), the EA's button is controlled that enables it to trade. Then a new tick is detected.
If your trading system assumes using of those and similar parameters, it is function Novator_scr() that is intended for such calculations.

For example, you can дcomplete this function with blocks that detect whether a

new bar has appeared, check whether critical event

time has come, detect whether the

trade terms have been changed (for example, spread size, minimal distance at which the stop
orders may be placed, etc.), as well as with other calculations necessary before
the basic analytical functions start operating.

For example, you can дcomplete this function with blocks that detect whether a

new bar has appeared, check whether critical event

time has come, detect whether the

trade terms have been changed (for example, spread size, minimal distance at which the stop
orders may be placed, etc.), as well as with other calculations necessary before
the basic analytical functions start operating.

Functions that make the basic content of the program are not shown in function Work_scr(). In the article named Considering Orders in a Large Program, we dealt with function Terminal() that considered orders. If you use the same considering principle in your trading system, function Terminal() should be included into function Work_scr() immediately after function Novator_scr().

The script has one more auxilliary function at its disposal - Mess_graf_scr() intended for displaying messages in the indicator window.

[CODE START]
// Mess_graf_scr.mq4
//====================================================================
int Mess_graf_scr(int Mess_Number)
 {
//====================================================================
   if(Mess_Number== 0)        // This happens in every loop Work
    {
      if(Time_Mess>0 && GetTickCount()-Time_Mess>15000)
// Color print has outdated within the last
       {                       // ..15 sec, let's color lines gray
         ObjectSet(Name_Graf_Text[1],OBJPROP_COLOR,Gray);
// Last 2 lines
         ObjectSet(Name_Graf_Text[2],OBJPROP_COLOR,Gray);
// The last 2 lines
         Time_Mess=0;         // Additional flag not to color in vain
         Redraw=1;            // Then redraw
       }
      return;                 // It was a little step into
    }
//--------------------------------------------------------------------
   Time_Mess=GetTickCount(); // Remember the message publishing time
   Por_Nom_Mess_Graf++;      // Count lines. This is just a name part.
   Stroka_2=0;            // Presume that message in one line
   if(Mess_Number>1000)      
// If a huge number occurs, the number will be brought to life,
// understand that the previous line is from the same message, i.e.,it
// should not be colored gray
    {
      Mess_Number=Mess_Number/1000;
      Stroka_2=1;
    }
//====================================================================
   switch(Mess_Number)
    {
//--------------------------------------------------------------------
      case 1:
         Graf_Text = "All necessary components installed.";
         Color_GT = LawnGreen;
         break;
//--------------------------------------------------------------------
      case 2:
         Graf_Text = " ";
         break;
//--------------------------------------------------------------------
      case 3:
         Graf_Text = "Expert Advisors enabled.";
         Color_GT = LawnGreen;
         break;
//--------------------------------------------------------------------
      case 4:
         Graf_Text = "Expert Advisors disabled.";
         Color_GT = Tomato;
         break;
//--------------------------------------------------------------------
      case 5:
         Graf_Text = "Expert Advisor settings have been updated.";
         Color_GT = White;
         break;
//---------------------------------------------------- default -------
      default:
         Graf_Text = "Line default "+ DoubleToStr( Mess_Number, 0);
         Color_GT = Tomato;
         break;
    }
//====================================================================
   ObjectDelete(Name_Graf_Text[30]);
// the 30th object is preempted, delete it
   int Kol_strok=Por_Nom_Mess_Graf;
   if(Kol_strok>30) Kol_strok=30;
//-----------------------------------------------------------------
   for(int lok=Kol_strok;lok>=2;lok--)
// Go through graphical text names
    {
      Name_Graf_Text[lok]=Name_Graf_Text[lok-1];        
// Reassign them (normalize)

break;
    }
//====================================================================
   ObjectDelete(Name_Graf_Text[30]);
// the 30th object is preempted, delete it
   int Kol_strok=Por_Nom_Mess_Graf;
   if(Kol_strok>30) Kol_strok=30;
//-----------------------------------------------------------------
   for(int lok=Kol_strok;lok>=2;lok--)
// Go through graphical text names
    {
      Name_Graf_Text[lok]=Name_Graf_Text[lok-1];        
// Reassign them (normalize)
      ObjectSet(Name_Graf_Text[lok],OBJPROP_YDISTANCE,2+14*(lok-1));
//Change Y value (normalize)
      if(lok==3 || lok==4 || (lok==2 && Stroka_2==0))
         ObjectSet(Name_Graf_Text[lok],OBJPROP_COLOR,Gray);
//Color old lines gray..
    }
//-------------------------------------------------------------------
   Graf_Text_Number=DoubleToStr( Por_Nom_Mess_Graf, 0);
//The unique part of the name unite with the message number
   Name_Graf_Text[1] = MyGrafic + Mess_Graf + Graf_Text_Number;
// Form the message name.
   Win_ind= WindowFind("Indicator");                    
//What is the window number of our indicator?

   ObjectCreate ( Name_Graf_Text[1],OBJ_LABEL, Win_ind,0,0);
// Create an object in the indicator window
   ObjectSet    ( Name_Graf_Text[1],OBJPROP_CORNER, 3   );  
// ..with coord, from the bottom-right corner..
   ObjectSet    ( Name_Graf_Text[1],OBJPROP_XDISTANCE,450);
// ..with coordinates on X..
   ObjectSet    ( Name_Graf_Text[1],OBJPROP_YDISTANCE, 2);  
// ..with coordinates on Y..
   ObjectSetText(Name_Graf_Text[1],Graf_Text,10,"Courier New",
                 Color_GT);
//text font color
   Redraw=1;                                  // Then redraw
//=================================================================
   return;
 }
//====================== End of module ============================
[CODE END]

There is no need to consider this function in all details. We can just mention some
of its special features.

1. All messages are displayed by graphical means.

2. The formal parameter to be passed to the function corresponds to the message
number.

3. If the value of the passed parameter lies between 1 and 999, the preceding text
line in the indicator window will lose the color. If this value exceeds 1000, the
message will be displayed, the number of which equals to the passed value divided
by 1000. In this latter case, the preceding line will not lose its color.

4. At the end of fifteen seconds after the last message, all lines will lose their
color.

5. Maintaining the possibility to discolor lines, the function should be activated
from time to time. So, there is a call at the end of function Work_scr():

[CODE START]
   Mess_graf_scr(0);
[CODE END]

In the article named Graphic Expert Advisor: AutoGraf, a really working program complex is represented where we use a similar function
that contains over 250 various messages. You can refer to this example to use all
or some of the messages in your trading.

3.3. Indicator

For our presentment to be complete, let us consider the indicator, as well, though
its code is rather simple.

[CODE START]
// Indicator.mq4
//===================================================; include ==========
#include <stdlib.mqh>
#include <stderror.mqh>
#include <WinUser32.mqh>
//=======================================================================
#include <Peremen_ind.mq4>      
// Description of the indicator variables.
#include <Metsenat_ind.mq4>      
// Predefining the indicator variables.
#include <Del_GV_ind.mq4>        
// Deletion of all GlobalVariables created by the indicator.
#include <Component_ind.mq4>    
// Check components for availability.
#include <Component_uni.mq4>    
// Message in the indicator about inavailability of components.
//=======================================================================
//
//
//=======================================================================
#property indicator_separate_window
//=======================================================================
//
//
//=======================================================================
int init()  
 {
   Metsenat_ind();
   return;
 }
//=======================================================================
int start()
 {
   if(Component_ind()==0) return; // Check for availability of components
   //...
   return;                                                          
 }
//=======================================================================
int deinit()
 {
   Del_GV_ind();             // Deletion of the indicator GlobalVariable.
   return;
 }
//=======================================================================
[CODE END]

Only one critical feature of an indicator should be emphasized here: Indicator is
shown in a separate window:

[CODE START]
#property indicator_separate_window
[CODE END]

Only one critical feature of an indicator should be emphasized here: Indicator is
shown in a separate window:

[CODE START]
#property indicator_separate_window
[CODE END]

Contents of functions Metsenat_ind() and Del_GV_ind() are similar to those of previously
considered functions used in the Expert Advisor and in the script.

Content of function Component_ind() is unsophisticated, too:

[CODE START]
// Component_ind.mq4
//===================================================================
int Component_ind()
 {
//===================================================================
   if(GlobalVariableGet(GV_Exp_Yes)==1 &&
      GlobalVariableGet(GV_Scr_Yes)==1)
//If all components are available
    {                        // State about the indicator available
      if(GlobalVariableGet(GV_Ind_Yes)!=1)
          GlobalVariableSet(GV_Ind_Yes,1);
      return(1);
    }
//--------------------------------------------------------------------
   if(GlobalVariableGet(GV_Scr_Yes)!=1 &&
      GlobalVariableGet(GV_Exp_Yes)!=1)
    {                           // If there is neither script nor EA  
      Graf_Text = "Components Expert and Script are not installed.";            
// Message text
      Component_uni();        // Write the info message in ind. window
    }
//=====================================================================
   return(0);
 }
//=====================; End of module ================================
[CODE END]
As we can see from the code, function Component_ind() gives a message only if two other components have not been loaded
- both the script and the Expert Advisor. If only one of programs is inavailable,
no actions will be made. This oresumes that, if they are available in the symbol
window, these programs will track the composition of the program complex and inform
the user about the results.

If it is necessary, the main property of the indicator - drawing - can be used,
too. In terms of the program complex, this property is not necessary, but it can
be used in the real trading, for example, to divide the subwindow into zones.

4. Practical Use

The order of attaching the application components to the symbol window does not
signify. However, it would be recommended to attach indicator as the first since
it allows us to read comments as soon as it is attached.

Thus, the following must be done to demonstrate how the application works.

1. Attach the indicator in the symbol window. This will be shown in the indicator window immediately:

Components Expert and Script are not installed

Application does not work.



2. Attach the Expert Advisor in the symbol window. Function Component_exp() will trigger and the following message
will appear in the indicator window:

The Script is not installed

Application does not work.



3. Attach the script in the symbol window. This event will be processed in function Component_scr()
of the script and displayed in the indicator window:

All necessary components are installed.

Components Expert and Script are not installed

Application does not work.



2. Attach the Expert Advisor in the symbol window. Function Component_exp() will trigger and the following message
will appear in the indicator window:

The Script is not installed

Application does not work.



3. Attach the script in the symbol window. This event will be processed in function Component_scr()
of the script and displayed in the indicator window:

All necessary components are installed.

Expert Advisors enabled.



If Expert Advisors were disabled, the message will look like this:

All necessary components are installed.

Expert Advisors disabled.



4. You can press the EA button several times and be sure that this event sequence
is processed by the application immediately and displayed in message lines:

Expert Advisors disabled.

Expert Advisors enabled.

Expert Advisors disabled.

Expert Advisors enabled.

Expert Advisors disabled.



Please note that, due to the script with the looped basic code used in the program
complex, the program response to the user's controls is not made in multiples of
ticks, but immediately.

As an example, we placed in function Work_scr() the tickwise dysplaying of a variable
from the EA settings using function Alert().

Let us consider this feature. Function Work_scr() is a part of the script. The basic
loop of the script has time to turn hundreds of times between ticks while the message
is given by function Alert() in multiples of ticks.

5. Open the EA setup toolbar and replace value AAA with 3. The script will track
this event and give a message in the indicator window:

Expert Advisors enabled.

Expert Advisors disabled.

Expert Advisors enabled.

Expert Advisors disabled.

EA settings have been updated.



The window of function Alert() will display the new value of variable AAA tickwise:

6. Now, you can load or unload any components in any sequence, play with EA button,
change value of ajustable variable, and make your own opinion about the quality
of the program complex.

Conclusion

The main thing we have reached using the described technology is that the script does not stop working regardless of whether events take place or not
in its environment. The script will stop working if it finds that one or both other components (indicator,
Expert Advisor) are not available.

The described principle of creating a program complex is, slightly modified, usedin
a really working application AutoGraf that was described in the article named Graphic Expert Advisor: AutoGraf .

SK. Dnepropetrovsk. 2006





              Translated from Russian by MetaQuotes Ltd.
Original article: https://www.mql5.com/ru/articles/1393



  Attached files |


      Download ZIP




      Exp_Scr_Ind.zip
      (33.24 KB)

SK. Dnepropetrovsk. 2006





              Translated from Russian by MetaQuotes Ltd.
Original article: https://www.mql5.com/ru/articles/1393



  Attached files |


      Download ZIP




      Exp_Scr_Ind.zip
      (33.24 KB)





    Warning: All rights to these materials are reserved by MetaQuotes Ltd. Copying or reprinting of these materials in whole or in part is prohibited.

      This article was written by a user of the site and reflects their personal views. MetaQuotes Ltd is not responsible for the accuracy of the information presented, nor for any consequences resulting from the use of the solutions, strategies or recommendations described.




    Other articles by this author



          My First "Grail"



          Considering Orders in a Large Program



          Graphic Expert Advisor: AutoGraf

// CONTEXT: Series: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles, Part: N/A, Title: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles | FILE: Exp_Scr_Ind.zip/Exp_Scr_Ind/include/stderror.mqh
//+------------------------------------------------------------------+
//|                                                     stderror.mqh |
//|                 Copyright © 2004-2005, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
//---- errors returned from trade server
#define ERR_NO_ERROR                                  0
#define ERR_NO_RESULT                                 1
#define ERR_COMMON_ERROR                              2
#define ERR_INVALID_TRADE_PARAMETERS                  3
#define ERR_SERVER_BUSY                               4
#define ERR_OLD_VERSION                               5
#define ERR_NO_CONNECTION                             6
#define ERR_NOT_ENOUGH_RIGHTS                         7
#define ERR_TOO_FREQUENT_REQUESTS                     8
#define ERR_MALFUNCTIONAL_TRADE                       9
#define ERR_ACCOUNT_DISABLED                         64
#define ERR_INVALID_ACCOUNT                          65
#define ERR_TRADE_TIMEOUT                           128
#define ERR_INVALID_PRICE                           129
#define ERR_INVALID_STOPS                           130
#define ERR_INVALID_TRADE_VOLUME                    131
#define ERR_MARKET_CLOSED                           132
#define ERR_TRADE_DISABLED                          133
#define ERR_NOT_ENOUGH_MONEY                        134
#define ERR_PRICE_CHANGED                           135
#define ERR_OFF_QUOTES                              136
#define ERR_BROKER_BUSY                             137
#define ERR_REQUOTE                                 138
#define ERR_ORDER_LOCKED                            139
#define ERR_LONG_POSITIONS_ONLY_ALLOWED             140
#define ERR_TOO_MANY_REQUESTS                       141
#define ERR_TRADE_MODIFY_DENIED                     145
#define ERR_TRADE_CONTEXT_BUSY                      146
//---- mql4 run time errors
#define ERR_NO_MQLERROR                            4000
#define ERR_WRONG_FUNCTION_POINTER                 4001
#define ERR_ARRAY_INDEX_OUT_OF_RANGE               4002
#define ERR_NO_MEMORY_FOR_FUNCTION_CALL_STACK      4003
#define ERR_RECURSIVE_STACK_OVERFLOW               4004
#define ERR_NOT_ENOUGH_STACK_FOR_PARAMETER         4005
#define ERR_NO_MEMORY_FOR_PARAMETER_STRING         4006
#define ERR_NO_MEMORY_FOR_TEMP_STRING              4007
#define ERR_NOT_INITIALIZED_STRING                 4008
#define ERR_NOT_INITIALIZED_ARRAYSTRING            4009
#define ERR_NO_MEMORY_FOR_ARRAYSTRING              4010
#define ERR_TOO_LONG_STRING                        4011

#define ERR_RECURSIVE_STACK_OVERFLOW               4004
#define ERR_NOT_ENOUGH_STACK_FOR_PARAMETER         4005
#define ERR_NO_MEMORY_FOR_PARAMETER_STRING         4006
#define ERR_NO_MEMORY_FOR_TEMP_STRING              4007
#define ERR_NOT_INITIALIZED_STRING                 4008
#define ERR_NOT_INITIALIZED_ARRAYSTRING            4009
#define ERR_NO_MEMORY_FOR_ARRAYSTRING              4010
#define ERR_TOO_LONG_STRING                        4011
#define ERR_REMAINDER_FROM_ZERO_DIVIDE             4012
#define ERR_ZERO_DIVIDE                            4013
#define ERR_UNKNOWN_COMMAND                        4014
#define ERR_WRONG_JUMP                             4015
#define ERR_NOT_INITIALIZED_ARRAY                  4016
#define ERR_DLL_CALLS_NOT_ALLOWED                  4017
#define ERR_CANNOT_LOAD_LIBRARY                    4018
#define ERR_CANNOT_CALL_FUNCTION                   4019
#define ERR_EXTERNAL_EXPERT_CALLS_NOT_ALLOWED      4020
#define ERR_NOT_ENOUGH_MEMORY_FOR_RETURNED_STRING  4021
#define ERR_SYSTEM_BUSY                            4022
#define ERR_INVALID_FUNCTION_PARAMETERS_COUNT      4050
#define ERR_INVALID_FUNCTION_PARAMETER_VALUE       4051
#define ERR_STRING_FUNCTION_INTERNAL_ERROR         4052
#define ERR_SOME_ARRAY_ERROR                       4053
#define ERR_INCORRECT_SERIES_ARRAY_USING           4054
#define ERR_CUSTOM_INDICATOR_ERROR                 4055
#define ERR_INCOMPATIBLE_ARRAYS                    4056
#define ERR_GLOBAL_VARIABLES_PROCESSING_ERROR      4057
#define ERR_GLOBAL_VARIABLE_NOT_FOUND              4058
#define ERR_FUNCTION_NOT_ALLOWED_IN_TESTING_MODE   4059
#define ERR_FUNCTION_NOT_CONFIRMED                 4060
#define ERR_SEND_MAIL_ERROR                        4061
#define ERR_STRING_PARAMETER_EXPECTED              4062
#define ERR_INTEGER_PARAMETER_EXPECTED             4063
#define ERR_DOUBLE_PARAMETER_EXPECTED              4064
#define ERR_ARRAY_AS_PARAMETER_EXPECTED            4065
#define ERR_HISTORY_WILL_UPDATED                   4066
#define ERR_TRADE_ERROR                            4067
#define ERR_END_OF_FILE                            4099
#define ERR_SOME_FILE_ERROR                        4100
#define ERR_WRONG_FILE_NAME                        4101
#define ERR_TOO_MANY_OPENED_FILES                  4102
#define ERR_CANNOT_OPEN_FILE                       4103
#define ERR_INCOMPATIBLE_ACCESS_TO_FILE            4104
#define ERR_NO_ORDER_SELECTED                      4105
#define ERR_UNKNOWN_SYMBOL                         4106
#define ERR_INVALID_PRICE_PARAM                    4107
#define ERR_INVALID_TICKET                         4108
#define ERR_TRADE_NOT_ALLOWED                      4109
#define ERR_LONGS__NOT_ALLOWED                     4110
#define ERR_SHORTS_NOT_ALLOWED                     4111
#define ERR_OBJECT_ALREADY_EXISTS                  4200
#define ERR_UNKNOWN_OBJECT_PROPERTY                4201

#define ERR_UNKNOWN_SYMBOL                         4106
#define ERR_INVALID_PRICE_PARAM                    4107
#define ERR_INVALID_TICKET                         4108
#define ERR_TRADE_NOT_ALLOWED                      4109
#define ERR_LONGS__NOT_ALLOWED                     4110
#define ERR_SHORTS_NOT_ALLOWED                     4111
#define ERR_OBJECT_ALREADY_EXISTS                  4200
#define ERR_UNKNOWN_OBJECT_PROPERTY                4201
#define ERR_OBJECT_DOES_NOT_EXIST                  4202
#define ERR_UNKNOWN_OBJECT_TYPE                    4203
#define ERR_NO_OBJECT_NAME                         4204
#define ERR_OBJECT_COORDINATES_ERROR               4205
#define ERR_NO_SPECIFIED_SUBWINDOW                 4206
#define ERR_SOME_OBJECT_ERROR                      4207

// CONTEXT: Series: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles, Part: N/A, Title: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles | FILE: Exp_Scr_Ind.zip/Exp_Scr_Ind/include/stdlib.mqh
//+------------------------------------------------------------------+
//|                                                       stdlib.mqh |
//|                      Copyright © 2004, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#import "stdlib.ex4"

string ErrorDescription(int error_code);
int    RGB(int red_value,int green_value,int blue_value);
bool   CompareDoubles(double number1,double number2);
string DoubleToStrMorePrecision(double number,int precision);
string IntegerToHexString(int integer_number);

// CONTEXT: Series: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles, Part: N/A, Title: Synchronization of Expert Advisors, Scripts and Indicators - MQL4 Articles | FILE: Exp_Scr_Ind.zip/Exp_Scr_Ind/include/WinUser32.mqh
//+------------------------------------------------------------------+
//|                                                    WinUser32.mqh |
//|                      Copyright © 2004, MetaQuotes Software Corp. |
//|                                       http://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#define   copyright "Copyright © 2004, MetaQuotes Software Corp."
#define   link      "http://www.metaquotes.net/"

#import "user32.dll"
   //---- messages
   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
   int      SendNotifyMessageA(int hWnd,int Msg,int wParam,int lParam);
   int      PostMessageA(int hWnd,int Msg,int wParam,int lParam);
   void     keybd_event(int bVk,int bScan,int dwFlags,int dwExtraInfo);
   void     mouse_event(int dwFlags,int dx,int dy,int dwData,int dwExtraInfo);
   //---- windows
   int      FindWindowA(string lpClassName ,string lpWindowName);
   int      SetWindowTextA(int hWnd,string lpString);
   int      GetWindowTextA(int hWnd,string lpString,int nMaxCount);
   int      GetWindowTextLengthA(int hWnd);
   int      GetWindow(int hWnd,int uCmd);

   int      UpdateWindow(int hWnd);
   int      EnableWindow(int hWnd,int bEnable);
   int      DestroyWindow(int hWnd);
   int      ShowWindow(int hWnd,int nCmdShow);
   int      SetActiveWindow(int hWnd);
   int      AnimateWindow(int hWnd,int dwTime,int dwFlags);
   int      FlashWindow(int hWnd,int dwFlags /*bInvert*/);
   int      CloseWindow(int hWnd);
   int      MoveWindow(int hWnd,int X,int Y,int nWidth,int nHeight,int bRepaint);
   int      SetWindowPos(int hWnd,int hWndInsertAfter ,int X,int Y,int cx,int cy,int uFlags);
   int      IsWindowVisible(int hWnd);
   int      IsIconic(int hWnd);
   int      IsZoomed(int hWnd);
   int      SetFocus(int hWnd);
   int      GetFocus();
   int      GetActiveWindow();
   int      IsWindowEnabled(int hWnd);
   //---- miscelaneouse
   int      MessageBoxA(int hWnd ,string lpText,string lpCaption,int uType);
   int      MessageBoxExA(int hWnd ,string lpText,string lpCaption,int uType,int wLanguageId);
   int      MessageBeep(int uType);
   int      GetSystemMetrics(int nIndex);
   int      ExitWindowsEx(int uFlags,int dwReserved);
   int      SwapMouseButton(int fSwap);
#import

//---- Window Messages
#define WM_NULL                        0x0000
#define WM_CREATE                      0x0001
#define WM_DESTROY                     0x0002
#define WM_MOVE                        0x0003
#define WM_SIZE                        0x0005
#define WM_ACTIVATE                    0x0006
#define WM_SETFOCUS                    0x0007
#define WM_KILLFOCUS                   0x0008

int      SwapMouseButton(int fSwap);
#import

//---- Window Messages
#define WM_NULL                        0x0000
#define WM_CREATE                      0x0001
#define WM_DESTROY                     0x0002
#define WM_MOVE                        0x0003
#define WM_SIZE                        0x0005
#define WM_ACTIVATE                    0x0006
#define WM_SETFOCUS                    0x0007
#define WM_KILLFOCUS                   0x0008
#define WM_ENABLE                      0x000A
#define WM_SETREDRAW                   0x000B
#define WM_SETTEXT                     0x000C
#define WM_GETTEXT                     0x000D
#define WM_GETTEXTLENGTH               0x000E
#define WM_PAINT                       0x000F
#define WM_CLOSE                       0x0010
#define WM_QUERYENDSESSION             0x0011
#define WM_QUIT                        0x0012
#define WM_QUERYOPEN                   0x0013
#define WM_ERASEBKGND                  0x0014
#define WM_SYSCOLORCHANGE              0x0015
#define WM_ENDSESSION                  0x0016
#define WM_SHOWWINDOW                  0x0018
#define WM_WININICHANGE                0x001A
#define WM_SETTINGCHANGE               0x001A // WM_WININICHANGE
#define WM_DEVMODECHANGE               0x001B
#define WM_ACTIVATEAPP                 0x001C
#define WM_FONTCHANGE                  0x001D
#define WM_TIMECHANGE                  0x001E
#define WM_CANCELMODE                  0x001F
#define WM_SETCURSOR                   0x0020
#define WM_MOUSEACTIVATE               0x0021
#define WM_CHILDACTIVATE               0x0022
#define WM_QUEUESYNC                   0x0023
#define WM_GETMINMAXINFO               0x0024
#define WM_PAINTICON                   0x0026
#define WM_ICONERASEBKGND              0x0027
#define WM_NEXTDLGCTL                  0x0028
#define WM_SPOOLERSTATUS               0x002A
#define WM_DRAWITEM                    0x002B
#define WM_MEASUREITEM                 0x002C
#define WM_DELETEITEM                  0x002D
#define WM_VKEYTOITEM                  0x002E
#define WM_CHARTOITEM                  0x002F
#define WM_SETFONT                     0x0030
#define WM_GETFONT                     0x0031
#define WM_SETHOTKEY                   0x0032
#define WM_GETHOTKEY                   0x0033
#define WM_QUERYDRAGICON               0x0037
#define WM_COMPAREITEM                 0x0039
#define WM_GETOBJECT                   0x003D
#define WM_COMPACTING                  0x0041
#define WM_WINDOWPOSCHANGING           0x0046
#define WM_WINDOWPOSCHANGED            0x0047
#define WM_COPYDATA                    0x004A
#define WM_CANCELJOURNAL               0x004B
#define WM_NOTIFY                      0x004E
#define WM_INPUTLANGCHANGEREQUEST      0x0050
#define WM_INPUTLANGCHANGE             0x0051
#define WM_TCARD                       0x0052
#define WM_HELP                        0x0053
#define WM_USERCHANGED                 0x0054

#define WM_WINDOWPOSCHANGING           0x0046
#define WM_WINDOWPOSCHANGED            0x0047
#define WM_COPYDATA                    0x004A
#define WM_CANCELJOURNAL               0x004B
#define WM_NOTIFY                      0x004E
#define WM_INPUTLANGCHANGEREQUEST      0x0050
#define WM_INPUTLANGCHANGE             0x0051
#define WM_TCARD                       0x0052
#define WM_HELP                        0x0053
#define WM_USERCHANGED                 0x0054
#define WM_NOTIFYFORMAT                0x0055
#define WM_CONTEXTMENU                 0x007B
#define WM_STYLECHANGING               0x007C
#define WM_STYLECHANGED                0x007D
#define WM_DISPLAYCHANGE               0x007E
#define WM_GETICON                     0x007F
#define WM_SETICON                     0x0080
#define WM_NCCREATE                    0x0081
#define WM_NCDESTROY                   0x0082
#define WM_NCCALCSIZE                  0x0083
#define WM_NCHITTEST                   0x0084
#define WM_NCPAINT                     0x0085
#define WM_NCACTIVATE                  0x0086
#define WM_GETDLGCODE                  0x0087
#define WM_SYNCPAINT                   0x0088
#define WM_NCMOUSEMOVE                 0x00A0
#define WM_NCLBUTTONDOWN               0x00A1
#define WM_NCLBUTTONUP                 0x00A2
#define WM_NCLBUTTONDBLCLK             0x00A3
#define WM_NCRBUTTONDOWN               0x00A4
#define WM_NCRBUTTONUP                 0x00A5
#define WM_NCRBUTTONDBLCLK             0x00A6
#define WM_NCMBUTTONDOWN               0x00A7
#define WM_NCMBUTTONUP                 0x00A8
#define WM_NCMBUTTONDBLCLK             0x00A9
#define WM_KEYFIRST                    0x0100
#define WM_KEYDOWN                     0x0100
#define WM_KEYUP                       0x0101
#define WM_CHAR                        0x0102
#define WM_DEADCHAR                    0x0103
#define WM_SYSKEYDOWN                  0x0104
#define WM_SYSKEYUP                    0x0105
#define WM_SYSCHAR                     0x0106
#define WM_SYSDEADCHAR                 0x0107
#define WM_KEYLAST                     0x0108
#define WM_INITDIALOG                  0x0110
#define WM_COMMAND                     0x0111
#define WM_SYSCOMMAND                  0x0112
#define WM_TIMER                       0x0113
#define WM_HSCROLL                     0x0114
#define WM_VSCROLL                     0x0115
#define WM_INITMENU                    0x0116
#define WM_INITMENUPOPUP               0x0117
#define WM_MENUSELECT                  0x011F
#define WM_MENUCHAR                    0x0120
#define WM_ENTERIDLE                   0x0121
#define WM_MENURBUTTONUP               0x0122
#define WM_MENUDRAG                    0x0123
#define WM_MENUGETOBJECT               0x0124
#define WM_UNINITMENUPOPUP             0x0125
#define WM_MENUCOMMAND                 0x0126
#define WM_CTLCOLORMSGBOX              0x0132
#define WM_CTLCOLOREDIT                0x0133

#define WM_MENUSELECT                  0x011F
#define WM_MENUCHAR                    0x0120
#define WM_ENTERIDLE                   0x0121
#define WM_MENURBUTTONUP               0x0122
#define WM_MENUDRAG                    0x0123
#define WM_MENUGETOBJECT               0x0124
#define WM_UNINITMENUPOPUP             0x0125
#define WM_MENUCOMMAND                 0x0126
#define WM_CTLCOLORMSGBOX              0x0132
#define WM_CTLCOLOREDIT                0x0133
#define WM_CTLCOLORLISTBOX             0x0134
#define WM_CTLCOLORBTN                 0x0135
#define WM_CTLCOLORDLG                 0x0136
#define WM_CTLCOLORSCROLLBAR           0x0137
#define WM_CTLCOLORSTATIC              0x0138
#define WM_MOUSEFIRST                  0x0200
#define WM_MOUSEMOVE                   0x0200
#define WM_LBUTTONDOWN                 0x0201
#define WM_LBUTTONUP                   0x0202
#define WM_LBUTTONDBLCLK               0x0203
#define WM_RBUTTONDOWN                 0x0204
#define WM_RBUTTONUP                   0x0205
#define WM_RBUTTONDBLCLK               0x0206
#define WM_MBUTTONDOWN                 0x0207
#define WM_MBUTTONUP                   0x0208
#define WM_MBUTTONDBLCLK               0x0209
#define WM_PARENTNOTIFY                0x0210
#define WM_ENTERMENULOOP               0x0211
#define WM_EXITMENULOOP                0x0212
#define WM_NEXTMENU                    0x0213
#define WM_SIZING                      0x0214
#define WM_CAPTURECHANGED              0x0215
#define WM_MOVING                      0x0216
#define WM_DEVICECHANGE                0x0219
#define WM_MDICREATE                   0x0220
#define WM_MDIDESTROY                  0x0221
#define WM_MDIACTIVATE                 0x0222
#define WM_MDIRESTORE                  0x0223
#define WM_MDINEXT                     0x0224
#define WM_MDIMAXIMIZE                 0x0225
#define WM_MDITILE                     0x0226
#define WM_MDICASCADE                  0x0227
#define WM_MDIICONARRANGE              0x0228
#define WM_MDIGETACTIVE                0x0229
#define WM_MDISETMENU                  0x0230
#define WM_ENTERSIZEMOVE               0x0231
#define WM_EXITSIZEMOVE                0x0232
#define WM_DROPFILES                   0x0233
#define WM_MDIREFRESHMENU              0x0234
#define WM_MOUSEHOVER                  0x02A1
#define WM_MOUSELEAVE                  0x02A3
#define WM_CUT                         0x0300
#define WM_COPY                        0x0301
#define WM_PASTE                       0x0302
#define WM_CLEAR                       0x0303
#define WM_UNDO                        0x0304
#define WM_RENDERFORMAT                0x0305
#define WM_RENDERALLFORMATS            0x0306
#define WM_DESTROYCLIPBOARD            0x0307
#define WM_DRAWCLIPBOARD               0x0308
#define WM_PAINTCLIPBOARD              0x0309
#define WM_VSCROLLCLIPBOARD            0x030A
#define WM_SIZECLIPBOARD               0x030B

#define WM_PASTE                       0x0302
#define WM_CLEAR                       0x0303
#define WM_UNDO                        0x0304
#define WM_RENDERFORMAT                0x0305
#define WM_RENDERALLFORMATS            0x0306
#define WM_DESTROYCLIPBOARD            0x0307
#define WM_DRAWCLIPBOARD               0x0308
#define WM_PAINTCLIPBOARD              0x0309
#define WM_VSCROLLCLIPBOARD            0x030A
#define WM_SIZECLIPBOARD               0x030B
#define WM_ASKCBFORMATNAME             0x030C
#define WM_CHANGECBCHAIN               0x030D
#define WM_HSCROLLCLIPBOARD            0x030E
#define WM_QUERYNEWPALETTE             0x030F
#define WM_PALETTEISCHANGING           0x0310
#define WM_PALETTECHANGED              0x0311
#define WM_HOTKEY                      0x0312
#define WM_PRINT                       0x0317
#define WM_PRINTCLIENT                 0x0318
#define WM_HANDHELDFIRST               0x0358
#define WM_HANDHELDLAST                0x035F
#define WM_AFXFIRST                    0x0360
#define WM_AFXLAST                     0x037F
#define WM_PENWINFIRST                 0x0380
#define WM_PENWINLAST                  0x038F
#define WM_APP                         0x8000

//---- keybd_event routines
#define KEYEVENTF_EXTENDEDKEY          0x0001
#define KEYEVENTF_KEYUP                0x0002
//---- mouse_event routines
#define MOUSEEVENTF_MOVE               0x0001 // mouse move
#define MOUSEEVENTF_LEFTDOWN           0x0002 // left button down
#define MOUSEEVENTF_LEFTUP             0x0004 // left button up
#define MOUSEEVENTF_RIGHTDOWN          0x0008 // right button down
#define MOUSEEVENTF_RIGHTUP            0x0010 // right button up
#define MOUSEEVENTF_MIDDLEDOWN         0x0020 // middle button down
#define MOUSEEVENTF_MIDDLEUP           0x0040 // middle button up
#define MOUSEEVENTF_WHEEL              0x0800 // wheel button rolled
#define MOUSEEVENTF_ABSOLUTE           0x8000 // absolute move

//---- GetSystemMetrics() codes
#define SM_CXSCREEN                    0
#define SM_CYSCREEN                    1
#define SM_CXVSCROLL                   2
#define SM_CYHSCROLL                   3
#define SM_CYCAPTION                   4
#define SM_CXBORDER                    5
#define SM_CYBORDER                    6
#define SM_CXDLGFRAME                  7
#define SM_CYDLGFRAME                  8
#define SM_CYVTHUMB                    9
#define SM_CXHTHUMB                    10
#define SM_CXICON                      11
#define SM_CYICON                      12
#define SM_CXCURSOR                    13
#define SM_CYCURSOR                    14
#define SM_CYMENU                      15
#define SM_CXFULLSCREEN                16
#define SM_CYFULLSCREEN                17
#define SM_CYKANJIWINDOW               18
#define SM_MOUSEPRESENT                19
#define SM_CYVSCROLL                   20
#define SM_CXHSCROLL                   21
#define SM_DEBUG                       22

#define SM_CYICON                      12
#define SM_CXCURSOR                    13
#define SM_CYCURSOR                    14
#define SM_CYMENU                      15
#define SM_CXFULLSCREEN                16
#define SM_CYFULLSCREEN                17
#define SM_CYKANJIWINDOW               18
#define SM_MOUSEPRESENT                19
#define SM_CYVSCROLL                   20
#define SM_CXHSCROLL                   21
#define SM_DEBUG                       22
#define SM_SWAPBUTTON                  23
#define SM_RESERVED1                   24
#define SM_RESERVED2                   25
#define SM_RESERVED3                   26
#define SM_RESERVED4                   27
#define SM_CXMIN                       28
#define SM_CYMIN                       29
#define SM_CXSIZE                      30
#define SM_CYSIZE                      31
#define SM_CXFRAME                     32
#define SM_CYFRAME                     33
#define SM_CXMINTRACK                  34
#define SM_CYMINTRACK                  35
#define SM_CXDOUBLECLK                 36
#define SM_CYDOUBLECLK                 37
#define SM_CXICONSPACING               38
#define SM_CYICONSPACING               39
#define SM_MENUDROPALIGNMENT           40
#define SM_PENWINDOWS                  41
#define SM_DBCSENABLED                 42
#define SM_CMOUSEBUTTONS               43
#define SM_SECURE                      44
#define SM_CXEDGE                      45
#define SM_CYEDGE                      46
#define SM_CXMINSPACING                47
#define SM_CYMINSPACING                48
#define SM_CXSMICON                    49
#define SM_CYSMICON                    50
#define SM_CYSMCAPTION                 51
#define SM_CXSMSIZE                    52
#define SM_CYSMSIZE                    53
#define SM_CXMENUSIZE                  54
#define SM_CYMENUSIZE                  55
#define SM_ARRANGE                     56
#define SM_CXMINIMIZED                 57
#define SM_CYMINIMIZED                 58
#define SM_CXMAXTRACK                  59
#define SM_CYMAXTRACK                  60
#define SM_CXMAXIMIZED                 61
#define SM_CYMAXIMIZED                 62
#define SM_NETWORK                     63
#define SM_CLEANBOOT                   67
#define SM_CXDRAG                      68
#define SM_CYDRAG                      69
#define SM_SHOWSOUNDS                  70
#define SM_CXMENUCHECK                 71 // Use instead of GetMenuCheckMarkDimensions()!
#define SM_CYMENUCHECK                 72
#define SM_SLOWMACHINE                 73
#define SM_MIDEASTENABLED              74
#define SM_MOUSEWHEELPRESENT           75
#define SM_XVIRTUALSCREEN              76
#define SM_YVIRTUALSCREEN              77
#define SM_CXVIRTUALSCREEN             78
#define SM_CYVIRTUALSCREEN             79
#define SM_CMONITORS                   80
#define SM_SAMEDISPLAYFORMAT           81

//---- GetWindow() Constants

#define SM_CYMENUCHECK                 72
#define SM_SLOWMACHINE                 73
#define SM_MIDEASTENABLED              74
#define SM_MOUSEWHEELPRESENT           75
#define SM_XVIRTUALSCREEN              76
#define SM_YVIRTUALSCREEN              77
#define SM_CXVIRTUALSCREEN             78
#define SM_CYVIRTUALSCREEN             79
#define SM_CMONITORS                   80
#define SM_SAMEDISPLAYFORMAT           81

//---- GetWindow() Constants
#define GW_HWNDFIRST                   0
#define GW_HWNDLAST                    1
#define GW_HWNDNEXT                    2
#define GW_HWNDPREV                    3
#define GW_OWNER                       4
#define GW_CHILD                       5

//---- AnimateWindow() Commands
#define AW_HOR_POSITIVE                0x00000001
#define AW_HOR_NEGATIVE                0x00000002
#define AW_VER_POSITIVE                0x00000004
#define AW_VER_NEGATIVE                0x00000008
#define AW_CENTER                      0x00000010
#define AW_HIDE                        0x00010000
#define AW_ACTIVATE                    0x00020000
#define AW_SLIDE                       0x00040000
#define AW_BLEND                       0x00080000

//---- MessageBox() Flags
#define MB_OK                       	0x00000000
#define MB_OKCANCEL                 	0x00000001
#define MB_ABORTRETRYIGNORE         	0x00000002
#define MB_YESNOCANCEL              	0x00000003
#define MB_YESNO                    	0x00000004
#define MB_RETRYCANCEL              	0x00000005
#define MB_ICONHAND                 	0x00000010
#define MB_ICONQUESTION             	0x00000020
#define MB_ICONEXCLAMATION          	0x00000030
#define MB_ICONASTERISK             	0x00000040
#define MB_USERICON                 	0x00000080
#define MB_ICONWARNING              	MB_ICONEXCLAMATION
#define MB_ICONERROR                	MB_ICONHAND
#define MB_ICONINFORMATION          	MB_ICONASTERISK
#define MB_ICONSTOP                 	MB_ICONHAND
#define MB_DEFBUTTON1               	0x00000000
#define MB_DEFBUTTON2               	0x00000100
#define MB_DEFBUTTON3               	0x00000200
#define MB_DEFBUTTON4               	0x00000300
#define MB_APPLMODAL                	0x00000000
#define MB_SYSTEMMODAL              	0x00001000
#define MB_TASKMODAL                	0x00002000
#define MB_HELP                     	0x00004000 // Help Button
#define MB_NOFOCUS                  	0x00008000
#define MB_SETFOREGROUND            	0x00010000
#define MB_DEFAULT_DESKTOP_ONLY     	0x00020000
#define MB_TOPMOST                  	0x00040000
#define MB_RIGHT                    	0x00080000
#define MB_RTLREADING               	0x00100000

//---- Dialog Box Command IDs
#define IDOK                           1
#define IDCANCEL                       2
#define IDABORT                        3
#define IDRETRY                        4
#define IDIGNORE                       5
#define IDYES                          6

#define MB_DEFAULT_DESKTOP_ONLY     	0x00020000
#define MB_TOPMOST                  	0x00040000
#define MB_RIGHT                    	0x00080000
#define MB_RTLREADING               	0x00100000

//---- Dialog Box Command IDs
#define IDOK                           1
#define IDCANCEL                       2
#define IDABORT                        3
#define IDRETRY                        4
#define IDIGNORE                       5
#define IDYES                          6
#define IDNO                           7
#define IDCLOSE                        8
#define IDHELP                         9

//+------------------------------------------------------------------+
```

### 💻 Snippet 12 (Source: article_12039.html)
```
// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles

Introduction

 In the previous article Developing a Replay System (Part 57): Breaking Down the Testing Service, I have explained in detail the source code needed to demonstrate a possible way of interaction between the modules we will use in our replay/simulator system.

 While this code gives us an idea of what we will actually need to implement, it still lacks an important detail that could be really useful for our system - the ability to use templates. You might think that this is not that important if you do not use or do not fully understand the benefits that templates give us, both in terms of coding and MetaTrader 5 settings.

 However, knowing, understanding and applying patterns significantly reduces our workload. There are things that are very easy to do with templates, but become extremely complex and difficult to implement if you try to program them directly. Maybe in the future I'll show you how to do some things using only templates, but for now we have other, more pressing tasks.

 To be honest, I thought I had achieved the point where the control and mouse modules did not need any improvement. However, due to some details that we will see in the following articles, both modules will still have to undergo minor changes. We will see this later, but for now, in this article, we will figure out how to turn the knowledge gained in the previous article into something feasible and functional. To do this, let's move on to a new topic.



 Modifying the old replay/simulator service

 Although it has been some time since we last made any modifications or improvements to the replay/simulator code, certain header files involved in building the replay/simulator executable have undergone changes. Perhaps the most notable change is the removal of the InterProcess.mqh header file, which has been replaced by Defines.mqh, a file with a much broader purpose.

 Since we have already made adjustments to the control and mouse modules to accommodate this new header file, we must now apply the same changes to the replay/simulation service. As a result, attempting to compile the replay/simulation service with the updated header file structure will lead to compilation errors, as illustrated in Figure 01.



 Figure 01. Attempt to compile replication/modeling service

 Among the various errors that may appear, you should first address the two highlighted ones. To resolve them, open the C_Simulation.mqh header file and modify the code as shown in the snippet below. The required change is minimal – simply remove line 04 and replace it with the adjustment shown in line 05. This modification ensures that C_Simulation.mqh conforms to the new framework we are implementing.

Figure 01. Attempt to compile replication/modeling service

 Among the various errors that may appear, you should first address the two highlighted ones. To resolve them, open the C_Simulation.mqh header file and modify the code as shown in the snippet below. The required change is minimal – simply remove line 04 and replace it with the adjustment shown in line 05. This modification ensures that C_Simulation.mqh conforms to the new framework we are implementing.


[CODE START]
01. //+------------------------------------------------------------------+
02. #property copyright "Daniel Jose"
03. //+------------------------------------------------------------------+
04. #include "..\..\Auxiliar\Interprocess.mqh"
05. #include "..\..\Defines.mqh"
06. //+------------------------------------------------------------------+
07. #define def_MaxSizeArray    16777216 // 16 Mbytes of positions
08. //+------------------------------------------------------------------+
09. class C_Simulation
10. {
11.    private   :
12. //+------------------------------------------------------------------+
13.       int       m_NDigits;
14.       bool       m_IsPriceBID;
[CODE END]
 A fragment of the source code of the C_Simulation.mqh file

 Just like we did in the C_Simulation.mqh header file, we will need to do something similar in the C_FilesBars.mqh file. To do this, open the C_FilesBars.mqh header file and change the code as shown below.


[CODE START]
01. //+------------------------------------------------------------------+
02. #property copyright "Daniel Jose"
03. //+------------------------------------------------------------------+
04. #include "..\..\Auxiliar\Interprocess.mqh"
05. #include "..\..\Defines.mqh"
06. //+------------------------------------------------------------------+
07. #define def_BarsDiary   1440
08. //+------------------------------------------------------------------+
09. class C_FileBars
10. {
11.    private   :
12.       int      m_file;
[CODE END]
 A fragment of the source code of the C_FilesBars.mqh file

 In both code fragments, we have removed the InterProcess.mqh header file and replaced it with Defines.mqh. With these two modifications, most of the code will align with the expected structure of the replay/simulator service. However, there is an issue. If you compare the contents of InterProcess.mqh and Defines.mqh, you will notice that Defines.mqh does not reference terminal global variables. Despite this, the replay/simulator system still refers to these variables.

 More specifically, these variables are used within the C_Replay.mqh file. However, this is not our only concern. In the future, I may decide to restructure the code further to improve its organization, stability, and flexibility. For now, however, I will focus on adapting the existing structure rather than making drastic changes to the entire system just for a minor improvement in flexibility and stability – although both are always worth enhancing.

More specifically, these variables are used within the C_Replay.mqh file. However, this is not our only concern. In the future, I may decide to restructure the code further to improve its organization, stability, and flexibility. For now, however, I will focus on adapting the existing structure rather than making drastic changes to the entire system just for a minor improvement in flexibility and stability – although both are always worth enhancing.

 To keep things clear, let's break this explanation into sections. The first issue we will address is a flaw that, while not critical, violates one of the core principles of object-oriented programming: encapsulation.



 Reviewing Code Encapsulation

 One of the most serious issues in any codebase is failing to adhere to fundamental object-oriented programming principles that ensure security and maintainability. For a long time, I have overlooked and misused a specific part of the code to facilitate direct access to certain data required for replay/simulator functionality.

 However, from this point forward, this practice will no longer be used. Specifically, I am referring to the encapsulation breach present in the C_ConfigService class.

 If you examine the header file for this class (C_ConfigService.mqh), you will notice a protected clause containing several variables. The existence of these variables in this section breaks encapsulation, even though they are only used within C_ConfigService and its derived class, C_Replay. It is not appropriate for these variables to be accessible outside C_ConfigService in their current form. If you review the C_Replay class, you will see that it modifies these variables, which is precisely what makes this approach problematic. In C++, there are ways to make class variables private while still allowing controlled access and manipulation outside the base class. However, these techniques often result in overly complex and difficult-to-maintain code. Additionally, they make future improvements significantly more challenging.

 Since MQL5 is derived from C++, it avoids incorporating certain risky practices that C++ allows. Therefore, it is more appropriate to adhere strictly to the three fundamental principles of object-oriented programming, including proper encapsulation.

Since MQL5 is derived from C++, it avoids incorporating certain risky practices that C++ allows. Therefore, it is more appropriate to adhere strictly to the three fundamental principles of object-oriented programming, including proper encapsulation.

 By modifying the C_ConfigService.mqh header file, we will restore proper encapsulation within our system. However, this change will require adjustments at higher levels of the codebase. Specifically, the C_Replay class, located in the C_Replay.mqh file, will undergo significant modifications. At the same time, we will take this opportunity to improve the code structure, making the replay/simulator service less nested. By implementing smaller, incremental changes, we can simplify maintenance and improve control over what is happening at each step. This will be particularly beneficial for future updates, as we will soon need to implement even more complex functionality that involves multiple interconnected components.

 Let's see what needs to be done to make things more suitable. To begin improving encapsulation, open the C_ConfigService.mqh header file and modify the code as shown in the following fragment. The rest of the code will remain unchanged, but the changes in this fragment will ensure that encapsulation is properly enforced.

[CODE START]
01. //+------------------------------------------------------------------+
02. #property copyright "Daniel Jose"
03. //+------------------------------------------------------------------+
04. #include "Support\C_FileBars.mqh"
05. #include "Support\C_FileTicks.mqh"
06. #include "Support\C_Array.mqh"
07. //+------------------------------------------------------------------+
08. class C_ConfigService : protected C_FileTicks
09. {
10.    protected:
11.         datetime m_dtPrevLoading;
12.         int      m_ReplayCount,
13.                  m_ModelLoading;
14. //+------------------------------------------------------------------+
15. inline void FirstBarNULL(void)
16.          {
17.             MqlRates rate[1];
18.             int c0 = 0;
19.            
20.             for(; (m_Ticks.ModePlot == PRICE_EXCHANGE) && (m_Ticks.Info[c0].volume_real == 0); c0++);
21.             rate[0].close = (m_Ticks.ModePlot == PRICE_EXCHANGE ? m_Ticks.Info[c0].last : m_Ticks.Info[c0].bid);
22.             rate[0].open = rate[0].high = rate[0].low = rate[0].close;
23.             rate[0].tick_volume = 0;
24.             rate[0].real_volume = 0;
25.             rate[0].time = macroRemoveSec(m_Ticks.Info[c0].time) - 86400;
26.             CustomRatesUpdate(def_SymbolReplay, rate);
27.             m_ReplayCount = 0;
28.          }
29. //+------------------------------------------------------------------+
30.    private   :
31.       enum eWhatExec {eTickReplay, eBarToTick, eTickToBar, eBarPrev};
32.       enum eTranscriptionDefine {Transcription_INFO, Transcription_DEFINE};
33.       struct st001
34.       {
35.          C_Array *pTicksToReplay, *pBarsToTicks, *pTicksToBars, *pBarsToPrev;
36.          int      Line;
37.       }m_GlPrivate;
38.       string    m_szPath;
39.       bool      m_AccountHedging;
40.       datetime  m_dtPrevLoading;
41.       int       m_ReplayCount,
42.                 m_ModelLoading;
43. //+------------------------------------------------------------------+
44. inline void FirstBarNULL(void)
45.          {
46.             MqlRates rate[1];
47.             int c0 = 0;
48.            
49.             for(; (m_Ticks.ModePlot == PRICE_EXCHANGE) && (m_Ticks.Info[c0].volume_real == 0); c0++);
50.             rate[0].close = (m_Ticks.ModePlot == PRICE_EXCHANGE ? m_Ticks.Info[c0].last : m_Ticks.Info[c0].bid);
51.             rate[0].open = rate[0].high = rate[0].low = rate[0].close;
52.             rate[0].tick_volume = 0;
53.             rate[0].real_volume = 0;
54.             rate[0].time = macroRemoveSec(m_Ticks.Info[c0].time) - 86400;
55.             CustomRatesUpdate(def_SymbolReplay, rate);
56.             m_ReplayCount = 0;
57.          }
58. //+------------------------------------------------------------------+
59. inline eTranscriptionDefine GetDefinition(const string &In, string &Out)
[CODE END]
 A fragment of the source code of the C_ConfigService.mqh file

Note that the contents of lines 11–13 have been moved to lines 40 and 42. This means that it will now be impossible to access these variables outside the body of the C_ConfigService class. Besides this, one more change was made. This change could have been ignored, but since some things won't be used outside the class, I decided to make the FirstBarNULL procedure private. So the content that was between lines 15 and 28 has been moved to lines 44 to 57.

 It is clear that when you make these changes to the actual file, the line numbers will be different because the removed code will no longer be part of the class code. However, I decided to leave everything in the fragment as is, for clarity. I think this way it will be clearer and easier to understand what has been changed.

 Great. Now, after making these changes, we will have to radically change the code present in the C_Replay.mqh file. But let's continue to separate things one from the other and look at this in the next topic.



 Restarting the implementation of the C_Replay class

 Although the title of this section may seem discouraging, implying that we are reinventing something that was already built, this is not the case. I want to emphasize that, while we do need to rework a large portion of the C_Replay class, the knowledge gained throughout this series of articles remains valuable. What we are doing is adapting to a new structure and methodology, as certain things can no longer be implemented the way they were before.

 The complete revised code for the C_Replay class is provided below.

[CODE START]
001. //+------------------------------------------------------------------+
002. #property copyright "Daniel Jose"
003. //+------------------------------------------------------------------+
004. #include "C_ConfigService.mqh"
005. //+------------------------------------------------------------------+
006. #define def_IndicatorControl   "Indicators\\Market Replay.ex5"
007. #resource "\\" + def_IndicatorControl
008. //+------------------------------------------------------------------+
009. #define def_CheckLoopService ((!_StopFlag) && (ChartSymbol(m_IdReplay) != ""))
010. //+------------------------------------------------------------------+
011. #define def_ShortNameIndControl "Market Replay Control"
012. //+------------------------------------------------------------------+
013. class C_Replay : public C_ConfigService
014. {
015.    private   :
016.       long      m_IdReplay;
017.       struct st00
018.       {
019.          ushort Position;
020.          short  Mode;
021.       }m_IndControl;
022. //+------------------------------------------------------------------+
023. inline bool MsgError(string sz0) { Print(sz0); return false; }
024. //+------------------------------------------------------------------+
025. inline void UpdateIndicatorControl(void)
026.          {
027.             uCast_Double info;
028.             int handle;
029.             double Buff[];
030.            
031.             if ((handle = ChartIndicatorGet(m_IdReplay, 0, def_ShortNameIndControl)) == INVALID_HANDLE) return;
032.             info.dValue = 0;
033.             if (CopyBuffer(handle, 0, 0, 1, Buff) == 1)
034.                info.dValue = Buff[0];
035.             IndicatorRelease(handle);
036.             if ((short)(info._16b[0]) != SHORT_MIN)
037.                m_IndControl.Mode = (short)info._16b[1];
038.             if (info._16b[0] != m_IndControl.Position)
039.             {
040.                if (((short)(info._16b[0]) != SHORT_MIN) && ((short)(info._16b[1]) == SHORT_MAX))
041.                   m_IndControl.Position = info._16b[0];
042.                info._16b[0] = m_IndControl.Position;
043.                info._16b[1] = (ushort)m_IndControl.Mode;
044.                EventChartCustom(m_IdReplay, evCtrlReplayInit, 0, info.dValue, "");
045.             }
046.          }
047. //+------------------------------------------------------------------+
048.       void SweepAndCloseChart(void)
049.          {
050.             long id;
051.            
052.             if ((id = ChartFirst()) > 0) do
053.             {
054.                if (ChartSymbol(id) == def_SymbolReplay)
055.                   ChartClose(id);
056.             }while ((id = ChartNext(id)) > 0);
057.          }
058. //+------------------------------------------------------------------+
059.    public   :
060. //+------------------------------------------------------------------+
061.       C_Replay()
062.          :C_ConfigService()
063.          {

051.            
052.             if ((id = ChartFirst()) > 0) do
053.             {
054.                if (ChartSymbol(id) == def_SymbolReplay)
055.                   ChartClose(id);
056.             }while ((id = ChartNext(id)) > 0);
057.          }
058. //+------------------------------------------------------------------+
059.    public   :
060. //+------------------------------------------------------------------+
061.       C_Replay()
062.          :C_ConfigService()
063.          {
064.             Print("************** Market Replay Service **************");
065.             srand(GetTickCount());
066.             SymbolSelect(def_SymbolReplay, false);
067.             CustomSymbolDelete(def_SymbolReplay);
068.             CustomSymbolCreate(def_SymbolReplay, StringFormat("Custom\\%s", def_SymbolReplay));
069.             CustomSymbolSetDouble(def_SymbolReplay, SYMBOL_TRADE_TICK_SIZE, 0);
070.             CustomSymbolSetDouble(def_SymbolReplay, SYMBOL_TRADE_TICK_VALUE, 0);
071.             CustomSymbolSetDouble(def_SymbolReplay, SYMBOL_VOLUME_STEP, 0);
072.             CustomSymbolSetString(def_SymbolReplay, SYMBOL_DESCRIPTION, "Symbol for replay / simulation");
073.             CustomSymbolSetInteger(def_SymbolReplay, SYMBOL_DIGITS, 8);
074.             SymbolSelect(def_SymbolReplay, true);
075.          }
076. //+------------------------------------------------------------------+
077.       bool OpenChartReplay(const ENUM_TIMEFRAMES arg1, const string szNameTemplate)
078.          {
079.             if (SymbolInfoDouble(def_SymbolReplay, SYMBOL_TRADE_TICK_SIZE) == 0)
080.                return MsgError("Asset configuration is not complete, it remains to declare the size of the ticket.");
081.             if (SymbolInfoDouble(def_SymbolReplay, SYMBOL_TRADE_TICK_VALUE) == 0)
082.                return MsgError("Asset configuration is not complete, need to declare the ticket value.");
083.             if (SymbolInfoDouble(def_SymbolReplay, SYMBOL_VOLUME_STEP) == 0)
084.                return MsgError("Asset configuration not complete, need to declare the minimum volume.");
085.             SweepAndCloseChart();
086.             m_IdReplay = ChartOpen(def_SymbolReplay, arg1);
087.             if (!ChartApplyTemplate(m_IdReplay, szNameTemplate + ".tpl"))
088.                Print("Failed apply template: ", szNameTemplate, ".tpl Using template default.tpl");
089.             else
090.                Print("Apply template: ", szNameTemplate, ".tpl");
091.
092.             return true;
093.          }
094. //+------------------------------------------------------------------+
095.       bool InitBaseControl(const ushort wait = 1000)
096.          {
097.             int handle;
098.            
099.             Print("Waiting for Mouse Indicator...");
100.             Sleep(wait);
101.             while ((def_CheckLoopService) && (ChartIndicatorGet(m_IdReplay, 0, "Indicator Mouse Study") == INVALID_HANDLE)) Sleep(200);

091.
092.             return true;
093.          }
094. //+------------------------------------------------------------------+
095.       bool InitBaseControl(const ushort wait = 1000)
096.          {
097.             int handle;
098.            
099.             Print("Waiting for Mouse Indicator...");
100.             Sleep(wait);
101.             while ((def_CheckLoopService) && (ChartIndicatorGet(m_IdReplay, 0, "Indicator Mouse Study") == INVALID_HANDLE)) Sleep(200);
102.             if (def_CheckLoopService)
103.             {
104.                Print("Waiting for Control Indicator...");
105.                if ((handle = iCustom(ChartSymbol(m_IdReplay), ChartPeriod(m_IdReplay), "::" + def_IndicatorControl, m_IdReplay)) == INVALID_HANDLE) return false;
106.                ChartIndicatorAdd(m_IdReplay, 0, handle);
107.                IndicatorRelease(handle);
108.                m_IndControl.Position = 0;
109.                m_IndControl.Mode = SHORT_MIN;
110.                UpdateIndicatorControl();
111.             }
112.            
113.             return def_CheckLoopService;
114.          }
115. //+------------------------------------------------------------------+
116.       bool LoopEventOnTime(void)
117.          {        
118.            
119.             while (def_CheckLoopService)
120.             {
121.                UpdateIndicatorControl();
122.                Sleep(250);
123.             }
124.            
125.             return false;
126.          }
127. //+------------------------------------------------------------------+
128.       ~C_Replay()
129.          {
130.             SweepAndCloseChart();
131.             SymbolSelect(def_SymbolReplay, false);
132.             CustomSymbolDelete(def_SymbolReplay);
133.             Print("Finished replay service...");
134.          }
135. //+------------------------------------------------------------------+
[CODE END]
 Source code of the C_Replay.mqh file

Although this code does not yet perform replay/simulation as it did previously, since certain components are still missing, its purpose is to enable the replay/simulation service to utilize elements not covered in the previous article. Among these elements is the ability to load previous bars, just as before, as well as the bars required for both replay and simulation. However, in this article, we will not yet be able to fully utilize these replay or simulation bars. Instead, they will be loaded and made available for when the system is capable of properly displaying them on the custom asset chart.

 There are several aspects of the code above that warrant further explanation. Many of its components may not be immediately clear, even to those with solid experience in MQL5. However, the explanations provided here will be aimed at those who genuinely want to understand why this code is being structured in this particular way.

 At the beginning of the code, in lines 5 to 11, we define certain parameters and include the compiled indicator file within the service executable. The reasoning behind this has been extensively discussed in previous articles in this series on replay/simulation. Therefore, I simply highlight this to remind you that it is not necessary to manually transfer the control indicator file.

 Then, in line 13, we establish a public inheritance from the C_ConfigService class. This is done to ensure that the workload is not concentrated solely in the C_Replay class; rather, it is distributed between C_Replay and C_ConfigService. This reinforces the importance of the changes made in the previous section, where we discussed the necessary modifications to properly encapsulate data and variables.

 The private section of the C_Replay class begins on line 15 and extends until line 58, where the public section begins. Let's first examine how the private section functions. It includes a small set of global variables, declared between in 16 to 21. Pay particular attention to line 21, where a variable is declared as a structure, meaning it contains additional nested data.

 In line 23, we define a small function whose sole purpose is to print an error message to the terminal and return false. But why return false here? Without this return value, we would need an additional line of code every time we print an error message to the terminal. For clarity, look at line 79, where we check a certain condition. If an error is detected, we would typically need two separate lines: one to print the error message and another to return an error indication. This would create unnecessary redundancy. However, by using the function declared in line 23, we can print the message and return a failure indication in a single step. This seen on line 80, simplifying the implementation. We combine things in such a way as to reduce our coding work.

Perhaps the most important section of the code is between lines 25 and 46. This code does some very important work for us. It manages and adjusts data from the control indicator. Before attempting to understand this section, ensure you fully comprehend how all related components interact. If in doubt, refer to previous articles explaining how the control indicator communicates with external components.

 Line 31 attempts to capture a handle for accessing the control indicator. If this fails, it is not a critical error. The function simply returns, skipping the rest of the procedure. If a handle is successfully captured, we reset the testing value, as shown in line 32. This is crucial and must be done correctly. Line 33 checks whether the indicator buffer is readable. If so, line 34 assigns the value to a test and adjustment variable. This section might undergo minor refinements in future articles, but the core logic will remain the same.

 Once the handle is no longer needed, line 35 releases it, and we enter the phase of testing and adjusting the retrieved information. Line 36 checks if the control indicator contains valid data. If so, we save information on whether the system is in paused mode or active play mode (replay/simulation). This saving is performed in line 37. This must be done before any modifications occur; otherwise, the retrieved data might be altered prematurely, compromising the integrity of information. The goal here is to ensure the service provides the latest form of control indicator – something that was previously done using a global terminal variable.

 Now pay attention to line 38. It compares the indicator buffer contents with the global positioning system. If a discrepancy is found, line 40 performs a secondary check to see if the control indicator has been initialized and if the system is in play mode. If both conditions are met, line 41 saves the buffer value. This is critical because, during pause mode, we do not want to update the data automatically. We want to allow the user to manually adjust the control indicator as needed.

 Finally, in lines 42 and 43, we assemble the information to be passed to the control indicator. This is transmitted via a custom event triggered in line 44. Once triggered, MetaTrader 5 takes over, executing its tasks while the service continues running in parallel.

 The code present in this procedure should be analyzed very carefully until it is really clear what is going on. Compared to the approach from the previous article, this version is more complex, despite performing essentially the same function. Once the control indicator is placed on the chart by MetaTrader 5, this code initializes it. From then on, it monitors its state. If the user changes the time frame, the service preserves the last known state of the indicator, ensuring that it is reinitialized with its previous settings upon returning to the chart.

Now let's look at code that was created with reusability in mind. It is located in line 48. The procedure simply closes all MetaTrader 5 chart windows containing symbols to be replicated. As you can see, there is nothing complicated. But since we need to do this at least twice, I decided to create this procedure to avoid duplicating code.

 So, from this point we move on to the public procedures of the C_Replay class. Basically, you can see that the code is not much different from what was before, at least with regard to the class constructor and destructor. Therefore, I will not make any further comments about them, since they have already been properly covered in previous articles where I explained the functioning of the C_Replay class. There are, however, three functions here that do deserve some explanation. Let's look at them in the order they appear in the code.

 The first function is called OpenChartReplay, which starts in line 77 and ends in line 93. It checks the integrity of the information collected by the boot system. This is necessary so that replay or simulator can actually be performed. However, it is in this function that we find something quite complex that, together with the InitBaseControl function, which we will talk about later, allows us to use the template.

 The issue of using a template is of great importance to us. It is necessary that it is used correctly and launched in the appropriate manner. But doing this is not as easy as many, including me, might have thought at first. In line 87 we try to add the template to the chart after previously opening it in line 86. The template to use is specified as one of the function arguments. In any case, the template will be placed on the chart, whether it is a user-specified template or a standard MetaTrader 5 template. But there is a detail here that is rarely mentioned: the template is not placed immediately. The ChartApplyTemplate function does not apply the template immediately. This function is asynchronous, meaning it can be executed within a few milliseconds of being called. And this is a problem for us.

 To understand the scale of the problem, we'll take a short break from the C_Replay class and look at the service code below.

To understand the scale of the problem, we'll take a short break from the C_Replay class and look at the service code below.


[CODE START]
01. //+------------------------------------------------------------------+
02. #property service
03. #property icon "/Images/Market Replay/Icons/Replay - Device.ico"
04. #property copyright "Daniel Jose"
05. #property version   "1.58"
06. #property description "Replay-Simulator service for MetaTrade 5 platform."
07. #property description "This is dependent on the Market Replay indicator."
08. #property description "For more details on this version see the article."
09. #property link "https://www.mql5.com/pt/articles/"
10. //+------------------------------------------------------------------+
11. #include <Market Replay\Service Graphics\C_Replay.mqh>
12. //+------------------------------------------------------------------+
13. input string            user00 = "Mini Dolar.txt";   //Replay Configuration File.
14. input ENUM_TIMEFRAMES   user01 = PERIOD_M5;          //Initial Graphic Time.
15. input string            user02 = "Default";          //Template File Name
16. //+------------------------------------------------------------------+
17. C_Replay *pReplay;
18. //+------------------------------------------------------------------+
19. void OnStart()
20. {
21.    pReplay = new C_Replay();
22.
23.    UsingReplay();  
24.    
25.    delete pReplay;
26. }
27. //+------------------------------------------------------------------+
28. void UsingReplay(void)
29. {
30.    if (!(*pReplay).SetSymbolReplay(user00)) return;
31.    if (!(*pReplay).OpenChartReplay(user01, user02)) return;
32.    if (!(*pReplay).InitBaseControl()) return;
33.    Print("Permission granted. Replay service can now be used...");
34.    while ((*pReplay).LoopEventOnTime());
35. }
36. //+------------------------------------------------------------------+
[CODE END]
 Source code of the replay/simulation service

 Notice that we perform tasks in a specific sequence, as seen between lines 30 and 34. After initializing via the constructor in line 21, we proceed to line 30 to verify that everything is correct with the loading process. Then, in line 31, we attempt to open the chart, and only after that, in line 32, do we load the necessary elements to control the service. If everything goes smoothly, in line 33, we print a message to the terminal, and in line 34, we enter the execution loop.

 At a glance, it seems like nothing unusual happens between opening the chart in line 31 and adding the controls in line 32. However, due to the use of the template loaded in the C_Replay class, some unforeseen issues may arise. To better understand the potential problem, let's revisit the class to examine the real complication of using a template.

At a glance, it seems like nothing unusual happens between opening the chart in line 31 and adding the controls in line 32. However, due to the use of the template loaded in the C_Replay class, some unforeseen issues may arise. To better understand the potential problem, let's revisit the class to examine the real complication of using a template.

 After instructing MetaTrader 5 to apply a template, as seen in line 87 of the C_Replay class, the code can execute much faster than it ideally should. As a result, in line 99, we inform the user that the service is waiting for the mouse indicator. If the mouse indicator is present in the template, it will load automatically; if not, the user will need to add it manually.

 This presents a problem because the function responsible for applying the template runs asynchronously. To mitigate the potential issues, we use line 100, where we pause the service for a short time to allow the chart to stabilize and the template application function to properly execute. Only after this wait do we verify on line 101 if the mouse indicator is present. This loop will continue until the mouse indicator appears on the chart or the chart is closed by the user.

 Once the mouse indicator is detected or the chart is closed, the code continues. If everything is as expected, we try to add the control indicator to the chart on line 105. While this works beautifully, there is an important detail: the control indicator will not be accepted if it is already part of the template. This is one of the modifications I'll show later, which prevents the control indicator from appearing in the template. A slight change will also be required for the mouse indicator, but that will come later. Without line 100, the chart would be closed shortly after opening, which is precisely what we aim to prevent.



 Conclusion

 Although there is a feeling that this is not the end, it is necessary to explain in detail why the chart closes immediately after applying the template. It's quite complicated, and other things need to be shown for you to really understand how this is possible, and why simply having line 100 prevents it. Therefore, I will reserve a more detailed discussion on the template and the necessary modifications in the indicator modules for the next article. This will help you fully grasp how these changes ensure the replay/simulation service works as expected.

 As you can see, this system is distinct from the testing service discussed in the previous article. Before I leave you, I will share a video showing the result of executing this system. Since it is not yet in the state shown in the video, there will be no attachment in this article.





 Demo video





              Translated from Portuguese by MetaQuotes Ltd.
Original article: https://www.mql5.com/pt/articles/12039



  Attached files |


      Download ZIP

Demo video





              Translated from Portuguese by MetaQuotes Ltd.
Original article: https://www.mql5.com/pt/articles/12039



  Attached files |


      Download ZIP




      Anexo.zip
      (420.65 KB)





    Warning: All rights to these materials are reserved by MetaQuotes Ltd. Copying or reprinting of these materials in whole or in part is prohibited.

      This article was written by a user of the site and reflects their personal views. MetaQuotes Ltd is not responsible for the accuracy of the information presented, nor for any consequences resulting from the use of the solutions, strategies or recommendations described.




    Other articles by this author



          Market Simulation (Part 07): Sockets (I)



          Market Simulation (Part 06): Transferring Information from MetaTrader 5 to Excel



          Market Simulation (Part 05): Creating the C_Orders Class (II)



          Market Simulation (Part 04): Creating the C_Orders Class (I)



          Market Simulation (Part 03): A Matter of Performance



          Market Simulation (Part 02): Cross Orders (II)



          Market Simulation (Part 01): Cross Orders (I)

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Services/Market Replay.mq5
//+------------------------------------------------------------------+
#property service
#property icon "/Images/Market Replay/Icons/Replay - Device.ico"
#property copyright "Daniel Jose"
#property version   "1.73"
#property description "Replay-Simulator service for MetaTrade 5 platform."
#property description "This is dependent on the Market Replay indicator."
#property description "For more details on this version see the article."

//+------------------------------------------------------------------+
#include <Market Replay\Service Graphics\C_Replay.mqh>
//+------------------------------------------------------------------+
input string 				user00 = "Mini Dolar.txt";		   //Replay Configuration File.
input ENUM_TIMEFRAMES 	user01 = PERIOD_M2;					//Initial Graphic Time.
input string				user02 = "Default";					//Template File Name
//+------------------------------------------------------------------+
C_Replay *pReplay;
//+------------------------------------------------------------------+
void OnStart()
{
	pReplay = new C_Replay();

	UsingReplay();

	delete pReplay;
}
//+------------------------------------------------------------------+
void UsingReplay(void)
{
	if (!(*pReplay).SetSymbolReplay(user00)) return;
	if (!(*pReplay).OpenChartReplay(user01, user02)) return;
	if (!(*pReplay).InitBaseControl()) return;
	Print("Permission granted. Replay service can now be used...");
	while ((*pReplay).LoopEventOnTime());
}
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Experts/Expert Advisor.mq5
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property description "Virtual Test..."
#property description "Demo version between interaction"
#property description "of Chart Trade and Expert Advisor"
#property version   "1.78"

//+------------------------------------------------------------------+
#include <Market Replay\Defines.mqh>
//+------------------------------------------------------------------+
class C_Decode
{
	private	:
		struct stInfoEvent
		{
			EnumEvents 	ev;
			string 		szSymbol;
			bool			IsDayTrade;
			ushort 		Leverange;
			double		PointsTake,
							PointsStop;
		}info[1];
	public	:
//+------------------------------------------------------------------+
		C_Decode()
			{
				info[0].szSymbol = _Symbol;
			}
//+------------------------------------------------------------------+
		bool Decode(const int id, const string sparam)
		{
			string Res[];

			if (StringSplit(sparam, '?', Res) != 6) return false;
			stInfoEvent loc = {(EnumEvents) StringToInteger(Res[0]), Res[1], (bool)(Res[2] == "D"), (ushort) StringToInteger(Res[3]), StringToDouble(Res[4]), StringToDouble(Res[5])};
			if ((id == loc.ev) && (loc.szSymbol == info[0].szSymbol)) info[0] = loc;

			ArrayPrint(info, 2);

			return true;
		}
}*GL_Decode;
//+------------------------------------------------------------------+
int OnInit()
{
	GL_Decode = new C_Decode;

	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnTick() {}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	switch (id)
	{
		case CHARTEVENT_CUSTOM + evChartTradeBuy		:
		case CHARTEVENT_CUSTOM + evChartTradeSell		:
		case CHARTEVENT_CUSTOM + evChartTradeCloseAll:
			GL_Decode.Decode(id - CHARTEVENT_CUSTOM, sparam);
			break;
	}
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	delete GL_Decode;
}
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Indicators/Chart Trade.mq5
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property description "Chart Trade Base Indicator."
#property description "See the articles for more details."
#property version   "1.77"
#property icon "/Images/Market Replay/Icons/Indicators.ico"

#property indicator_chart_window
#property indicator_plots 0
//+------------------------------------------------------------------+
#include <Market Replay\Chart Trader\C_ChartFloatingRAD.mqh>
//+------------------------------------------------------------------+
#define def_ShortName "Indicator Chart Trade"
//+------------------------------------------------------------------+
C_ChartFloatingRAD *chart = NULL;
//+------------------------------------------------------------------+
input ushort	user01 = 1;				//Leverage
input double 	user02 = 100.1;		//Finance Take
input double 	user03 = 75.4;			//Finance Stop
//+------------------------------------------------------------------+
int OnInit()
{
	chart = new C_ChartFloatingRAD(def_ShortName, new C_Mouse(0, "Indicator Mouse Study"), user01, user02, user03);

	if (_LastError >= ERR_USER_ERROR_FIRST) return INIT_FAILED;

	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
	return rates_total;
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	if (_LastError < ERR_USER_ERROR_FIRST)
		(*chart).DispatchMessage(id, lparam, dparam, sparam);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	switch (reason)
	{
		case REASON_INITFAILED:
			ChartIndicatorDelete(ChartID(), 0, def_ShortName);
			break;
		case REASON_CHARTCHANGE:
			(*chart).SaveState();
			break;
	}

	delete chart;
}
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Indicators/Market Replay.mq5
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property icon "/Images/Market Replay/Icons/Replay - Device.ico"
#property description "Control indicator for the Replay-Simulator service."
#property description "This one doesn't work without the service loaded."
#property version   "1.73"

#property indicator_chart_window
#property indicator_plots 0
#property indicator_buffers 1
//+------------------------------------------------------------------+
#include <Market Replay\Service Graphics\C_Controls.mqh>
//+------------------------------------------------------------------+
C_Controls *control = NULL;
//+------------------------------------------------------------------+
input long user00 = 0;		//ID
//+------------------------------------------------------------------+
double m_Buff[];
int    m_RatesTotal = 0;
//+------------------------------------------------------------------+
int OnInit()
{
	if (CheckPointer(control = new C_Controls(user00, "Market Replay Control", new C_Mouse(user00, "Indicator Mouse Study"))) == POINTER_INVALID)
		SetUserError(C_Terminal::ERR_PointerInvalid);
	if ((_LastError >= ERR_USER_ERROR_FIRST) || (user00 == 0))
	{
		Print("Control indicator failed on initialization.");
		return INIT_FAILED;
	}
	SetIndexBuffer(0, m_Buff, INDICATOR_DATA);
	ArrayInitialize(m_Buff, EMPTY_VALUE);

	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const int begin, const double &price[])
{
	(*control).SetBuffer(m_RatesTotal = rates_total, m_Buff);

	return rates_total;
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	(*control).DispatchMessage(id, lparam, dparam, sparam);
	(*control).SetBuffer(m_RatesTotal, m_Buff);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	switch (reason)
	{
		case REASON_TEMPLATE:
			Print("Modified template. Replay // simulation system shutting down.");
		case REASON_INITFAILED:
		case REASON_PARAMETERS:
		case REASON_REMOVE:
		case REASON_CHARTCLOSE:
			ChartClose(user00);
			break;
	}
	delete control;
}
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Indicators/Mouse Study.mq5
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
#property description "This is an indicator for graphical studies using the mouse."
#property description "This is an integral part of the Replay / Simulator system."
#property description "However it can be used in the real market."
#property version "1.70"
#property icon "/Images/Market Replay/Icons/Indicators.ico"

#property indicator_chart_window
#property indicator_plots 0
#property indicator_buffers 1
//+------------------------------------------------------------------+
double GL_PriceClose;
datetime GL_TimeAdjust;
//+------------------------------------------------------------------+
#include <Market Replay\Auxiliar\Study\C_Study.mqh>
//+------------------------------------------------------------------+
C_Study *Study 		= NULL;
//+------------------------------------------------------------------+
input color user02	= clrBlack;									//Price Line
input	color	user03	= clrPaleGreen;							//Positive Study
input color	user04	= clrLightCoral;							//Negative Study
//+------------------------------------------------------------------+
C_Study::eStatusMarket m_Status;
int m_posBuff = 0;
double m_Buff[];
//+------------------------------------------------------------------+
int OnInit()
{
	Study = new C_Study(0, "Indicator Mouse Study", user02, user03, user04);
	if (_LastError >= ERR_USER_ERROR_FIRST) return INIT_FAILED;
	MarketBookAdd((*Study).GetInfoTerminal().szSymbol);
	OnBookEvent((*Study).GetInfoTerminal().szSymbol);
	m_Status = C_Study::eCloseMarket;
	SetIndexBuffer(0, m_Buff, INDICATOR_DATA);
	ArrayInitialize(m_Buff, EMPTY_VALUE);

	return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated, const datetime& time[], const double& open[],
                const double& high[], const double& low[], const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[])
{
	GL_PriceClose = close[rates_total - 1];
	if (_Symbol == def_SymbolReplay)
		GL_TimeAdjust = spread[rates_total - 1] & (~def_MaskTimeService);
	m_posBuff = rates_total;
	(*Study).Update(m_Status);

	return rates_total;
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	(*Study).DispatchMessage(id, lparam, dparam, sparam);
	(*Study).SetBuffer(m_posBuff, m_Buff);

	ChartRedraw((*Study).GetInfoTerminal().ID);
}
//+------------------------------------------------------------------+

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
	(*Study).DispatchMessage(id, lparam, dparam, sparam);
	(*Study).SetBuffer(m_posBuff, m_Buff);

	ChartRedraw((*Study).GetInfoTerminal().ID);
}
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
	MqlBookInfo book[];
	C_Study::eStatusMarket loc = m_Status;

	if (symbol != (*Study).GetInfoTerminal().szSymbol) return;
	MarketBookGet((*Study).GetInfoTerminal().szSymbol, book);
	m_Status = (ArraySize(book) == 0 ? C_Study::eCloseMarket : (symbol == def_SymbolReplay ? C_Study::eInReplay : C_Study::eInTrading));
	for (int c0 = 0; (c0 < ArraySize(book)) && (m_Status != C_Study::eAuction); c0++)
		if ((book[c0].type == BOOK_TYPE_BUY_MARKET) || (book[c0].type == BOOK_TYPE_SELL_MARKET)) m_Status = C_Study::eAuction;
	if (loc != m_Status) (*Study).Update(m_Status);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
	MarketBookRelease((*Study).GetInfoTerminal().szSymbol);

	delete Study;
}
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Auxiliar/C_DrawImage.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Terminal.mqh"
//+------------------------------------------------------------------+

class C_DrawImage
{
//+------------------------------------------------------------------+
	private	:
		struct st_00
		{
			int	widthMap,
					heightMap;
			uint	Map[];
		}m_InfoImage[2];
		uint		m_Pixels[];
		string	m_szObjName,
					m_szRecName;
		long		m_ID;
//+------------------------------------------------------------------+
		void ReSizeImage(const int w, const int h, const uchar v, const int what)
			{
				double fx = (w * 1.0) / m_InfoImage[what].widthMap;
				double fy = (h * 1.0) / m_InfoImage[what].heightMap;
				uint pyi, pyf, pxi, pxf, tmp;
				uint uc;

				ArrayResize(m_Pixels, w * h);
				if ((m_InfoImage[what].widthMap == w) && (m_InfoImage[what].heightMap == h) && (v == 100)) ArrayCopy(m_Pixels, m_InfoImage[what].Map);
				else for (int cy = 0, y = 0; cy < m_InfoImage[what].heightMap; cy++, y += m_InfoImage[what].widthMap)
				{
					pyf = (uint)(fy * cy) * w;
					tmp = pyi = (uint)(fy * (cy - 1)) * w;
					for (int x = 0; x < m_InfoImage[what].widthMap; x++)
					{
						pxf = (uint)(fx * x);
						pxi = (uint)(fx * (x - 1));
						uc = (uchar(double((uc = m_InfoImage[what].Map[x + y]) >> 24) * macroTransparency(v)) << 24) | uc & 0x00FFFFFF;
						m_Pixels[pxf + pyf] = uc;
						for (pxi++; pxi < pxf; pxi++) m_Pixels[pxi + pyf] = uc;
					}
					for (pyi += w; pyi < pyf; pyi += w)
						for (int x = 0; x < w; x++)
							m_Pixels[x + pyi] = m_Pixels[x + tmp];
				}
			}
//+------------------------------------------------------------------+
		void Initilize(const int index, const color cFilter, const string szFile, const bool r180)
			{
				if (StringFind(szFile, "::") < 0) return;
				ResourceReadImage(szFile, m_InfoImage[index].Map, m_InfoImage[index].widthMap, m_InfoImage[index].heightMap);
				for (int pm = ArrayResize(m_Pixels, m_InfoImage[index].widthMap * m_InfoImage[index].heightMap), pi = 0; pi < pm;)
					for (int c0 = 0, pf = pi + (r180 ? m_InfoImage[index].widthMap - 1 : 0); c0 < m_InfoImage[index].widthMap; pi++, (r180 ? pf-- : pf++), c0++)
						m_Pixels[pf] = ((m_InfoImage[index].Map[pi] & 0x00FFFFFF) != cFilter ? m_InfoImage[index].Map[pi] : 0);
				ArraySwap(m_InfoImage[index].Map, m_Pixels);
				ArrayFree(m_Pixels);
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_DrawImage(C_Terminal *ptr, string szObjName, const color cFilter, const string szFile1, const string szFile2, const bool r180 = false)
			{
				(*ptr).CreateObjectGraphics(m_szObjName = szObjName, OBJ_BITMAP_LABEL);
				ObjectSetString(m_ID = (*ptr).GetInfoTerminal().ID, m_szObjName, OBJPROP_BMPFILE, m_szRecName = "::" + m_szObjName);
				Initilize(0, cFilter, szFile1, r180);
				if (szFile2 != NULL) Initilize(1, cFilter, szFile2, r180);
			}
//+------------------------------------------------------------------+
		~C_DrawImage()
			{
				ArrayFree(m_Pixels);

{
				(*ptr).CreateObjectGraphics(m_szObjName = szObjName, OBJ_BITMAP_LABEL);
				ObjectSetString(m_ID = (*ptr).GetInfoTerminal().ID, m_szObjName, OBJPROP_BMPFILE, m_szRecName = "::" + m_szObjName);
				Initilize(0, cFilter, szFile1, r180);
				if (szFile2 != NULL) Initilize(1, cFilter, szFile2, r180);
			}
//+------------------------------------------------------------------+
		~C_DrawImage()
			{
				ArrayFree(m_Pixels);
				ResourceFree(m_szRecName);
				ObjectDelete(m_ID, m_szObjName);
			}
//+------------------------------------------------------------------+
		void Paint(const int x, const int y, const int w, const int h, const uchar cView, const int what, const string tipics = "\n")
			{
				ReSizeImage(w, h, cView, what);
				ObjectSetInteger(m_ID, m_szObjName, OBJPROP_XDISTANCE, x);
				ObjectSetInteger(m_ID, m_szObjName, OBJPROP_YDISTANCE, y);
				ObjectSetString(m_ID, m_szObjName, OBJPROP_TOOLTIP, tipics);
				ResourceCreate(m_szRecName, m_Pixels, w, h, 0, 0, 0, COLOR_FORMAT_ARGB_NORMALIZE);
				ObjectSetString(m_ID, m_szObjName, OBJPROP_BMPFILE, what, m_szRecName);
				ChartRedraw(m_ID);
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Auxiliar/C_Mouse.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Terminal.mqh"
//+------------------------------------------------------------------+
#define def_MousePrefixName "MouseBase" + (string)GetInfoTerminal().SubWin + "_"
#define macro_NameObjectStudy (def_MousePrefixName + "T" + (string)ObjectsTotal(0))
//+------------------------------------------------------------------+

class C_Mouse : public C_Terminal
{
	public	:
		enum eStatusMarket {eCloseMarket, eAuction, eInTrading, eInReplay};
		enum eBtnMouse {eKeyNull = 0x00, eClickLeft = 0x01, eClickRight = 0x02, eSHIFT_Press = 0x04, eCTRL_Press = 0x08, eClickMiddle = 0x10};
		struct st_Mouse
		{
			struct st00
			{
				short		X_Adjusted,
							Y_Adjusted,
							X_Graphics,
							Y_Graphics;
				double 	Price;
				datetime dt;
			}Position;
			uchar	   ButtonStatus;
			bool	   ExecStudy;
		};
//+------------------------------------------------------------------+
	protected:
//+------------------------------------------------------------------+
		void CreateObjToStudy(int x, int w, string szName, color backColor = clrNONE) const
			{
				if (!m_OK) return;
				CreateObjectGraphics(szName, OBJ_BUTTON);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_STATE, true);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_BORDER_COLOR, clrBlack);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_COLOR, clrBlack);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_BGCOLOR, backColor);
			ObjectSetString(GetInfoTerminal().ID, szName, OBJPROP_FONT, "Lucida Console");
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_FONTSIZE, 10);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_XDISTANCE, x);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_YDISTANCE, TerminalInfoInteger(TERMINAL_SCREEN_HEIGHT) + 1);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_XSIZE, w);
				ObjectSetInteger(GetInfoTerminal().ID, szName, OBJPROP_YSIZE, 18);
			}
//+------------------------------------------------------------------+
	private	:
		enum eStudy {eStudyNull, eStudyCreate, eStudyExecute};
		struct st01
		{
			st_Mouse	Data;
			color		corLineH,
						corTrendP,
						corTrendN;
			eStudy	Study;
		}m_Info;
		struct st_Mem
		{
			bool 		CrossHair,
						IsFull;
			datetime dt;
			string	szShortName,
						szLineH,
						szLineV,
						szLineT,
						szBtnS;
		}m_Mem;
		bool m_OK;
//+------------------------------------------------------------------+
		void GetDimensionText(const string szArg, int &w, int &h)
			{
				TextSetFont("Lucida Console", -100, FW_NORMAL);
				TextGetSize(szArg, w, h);
				h += 5;
				w += 5;
			}
//+------------------------------------------------------------------+
		void CreateStudy(void)
			{
				if (m_Mem.IsFull)
				{
					CreateObjectGraphics(m_Mem.szLineV = macro_NameObjectStudy, OBJ_VLINE, m_Info.corLineH);
					CreateObjectGraphics(m_Mem.szLineT = macro_NameObjectStudy, OBJ_TREND, m_Info.corLineH);
				ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szLineT, OBJPROP_WIDTH, 2);
					CreateObjToStudy(0, 0, m_Mem.szBtnS = macro_NameObjectStudy);
				}
				m_Info.Study = eStudyCreate;
			}

void CreateStudy(void)
			{
				if (m_Mem.IsFull)
				{
					CreateObjectGraphics(m_Mem.szLineV = macro_NameObjectStudy, OBJ_VLINE, m_Info.corLineH);
					CreateObjectGraphics(m_Mem.szLineT = macro_NameObjectStudy, OBJ_TREND, m_Info.corLineH);
				ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szLineT, OBJPROP_WIDTH, 2);
					CreateObjToStudy(0, 0, m_Mem.szBtnS = macro_NameObjectStudy);
				}
				m_Info.Study = eStudyCreate;
			}
//+------------------------------------------------------------------+
		void ExecuteStudy(const double memPrice)
			{
				double v1 = GetInfoMouse().Position.Price - memPrice;
				int w, h;

				if (!CheckClick(eClickLeft))
				{
					m_Info.Study = eStudyNull;
					ChartSetInteger(GetInfoTerminal().ID, CHART_MOUSE_SCROLL, true);
					if (m_Mem.IsFull)	ObjectsDeleteAll(GetInfoTerminal().ID, def_MousePrefixName + "T");
				}else if (m_Mem.IsFull)
				{
					string sz1 = StringFormat(" %." + (string)GetInfoTerminal().nDigits + "f [ %d ] %02.02f%% ",
						MathAbs(v1), Bars(GetInfoTerminal().szSymbol, PERIOD_CURRENT, m_Mem.dt, GetInfoMouse().Position.dt) - 1, MathAbs((v1 / memPrice) * 100.0));
					GetDimensionText(sz1, w, h);
					ObjectSetString(GetInfoTerminal().ID, m_Mem.szBtnS, OBJPROP_TEXT, sz1);
					ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szBtnS, OBJPROP_BGCOLOR, (v1 < 0 ? m_Info.corTrendN : m_Info.corTrendP));
					ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szBtnS, OBJPROP_XSIZE, w);
					ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szBtnS, OBJPROP_YSIZE, h);
					ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szBtnS, OBJPROP_XDISTANCE, GetInfoMouse().Position.X_Adjusted - w);
					ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szBtnS, OBJPROP_YDISTANCE, GetInfoMouse().Position.Y_Adjusted - (v1 < 0 ? 1 : h));
					ObjectMove(GetInfoTerminal().ID, m_Mem.szLineT, 1, GetInfoMouse().Position.dt, GetInfoMouse().Position.Price);
					ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szLineT, OBJPROP_COLOR, (memPrice > GetInfoMouse().Position.Price ? m_Info.corTrendN : m_Info.corTrendP));
				}
				m_Info.Data.ButtonStatus = eKeyNull;
			}
//+------------------------------------------------------------------+
inline void DecodeAlls(int xi, int yi)
			{
				int w = 0;

				xi = (xi > 0 ? xi : 0);
				yi = (yi > 0 ? yi : 0);
				ChartXYToTimePrice(GetInfoTerminal().ID, m_Info.Data.Position.X_Graphics = (short)xi, m_Info.Data.Position.Y_Graphics = (short)yi, w, m_Info.Data.Position.dt, m_Info.Data.Position.Price);
				m_Info.Data.Position.dt = AdjustTime(m_Info.Data.Position.dt);
				m_Info.Data.Position.Price = AdjustPrice(m_Info.Data.Position.Price);
				ChartTimePriceToXY(GetInfoTerminal().ID, w, m_Info.Data.Position.dt, m_Info.Data.Position.Price, xi, yi);
				yi -= (int)ChartGetInteger(GetInfoTerminal().ID, CHART_WINDOW_YDISTANCE, GetInfoTerminal().SubWin);
				m_Info.Data.Position.X_Adjusted = (short) xi;

m_Info.Data.Position.dt = AdjustTime(m_Info.Data.Position.dt);
				m_Info.Data.Position.Price = AdjustPrice(m_Info.Data.Position.Price);
				ChartTimePriceToXY(GetInfoTerminal().ID, w, m_Info.Data.Position.dt, m_Info.Data.Position.Price, xi, yi);
				yi -= (int)ChartGetInteger(GetInfoTerminal().ID, CHART_WINDOW_YDISTANCE, GetInfoTerminal().SubWin);
				m_Info.Data.Position.X_Adjusted = (short) xi;
				m_Info.Data.Position.Y_Adjusted = (short) yi;
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_Mouse(const long id, const string szShortName)
			:C_Terminal(id),
			m_OK(false)
			{
				m_Mem.szShortName = szShortName;
			}
//+------------------------------------------------------------------+
		C_Mouse(const long id, const string szShortName, color corH, color corP, color corN)
			:C_Terminal(id)
			{
				if (!(m_OK = IndicatorCheckPass(m_Mem.szShortName = szShortName))) return;
				m_Mem.CrossHair = (bool)ChartGetInteger(GetInfoTerminal().ID, CHART_CROSSHAIR_TOOL);
				ChartSetInteger(GetInfoTerminal().ID, CHART_EVENT_MOUSE_MOVE, true);
				ChartSetInteger(GetInfoTerminal().ID, CHART_CROSSHAIR_TOOL, false);
				ZeroMemory(m_Info);
				m_Info.corLineH  = corH;
				m_Info.corTrendP = corP;
				m_Info.corTrendN = corN;
				m_Info.Study = eStudyNull;
				if (m_Mem.IsFull = (corP != clrNONE) && (corH != clrNONE) && (corN != clrNONE))
					CreateObjectGraphics(m_Mem.szLineH = (def_MousePrefixName + (string)ObjectsTotal(0)), OBJ_HLINE, m_Info.corLineH);
				ChartRedraw(GetInfoTerminal().ID);
			}
//+------------------------------------------------------------------+
		~C_Mouse()
			{
				if (!m_OK) return;
				ChartSetInteger(GetInfoTerminal().ID, CHART_EVENT_OBJECT_DELETE, false);
				ChartSetInteger(GetInfoTerminal().ID, CHART_EVENT_MOUSE_MOVE, ChartWindowFind(GetInfoTerminal().ID, m_Mem.szShortName) != -1);
				ChartSetInteger(GetInfoTerminal().ID, CHART_CROSSHAIR_TOOL, m_Mem.CrossHair);
				ObjectsDeleteAll(GetInfoTerminal().ID, def_MousePrefixName);
			}
//+------------------------------------------------------------------+
inline bool CheckClick(const eBtnMouse value)
			{
				return (GetInfoMouse().ButtonStatus & value) == value;
			}
//+------------------------------------------------------------------+
inline const st_Mouse GetInfoMouse(void)
			{
				if (!m_OK)
				{
					double Buff[];
					uCast_Double loc;
					int handle = ChartIndicatorGet(GetInfoTerminal().ID, 0, m_Mem.szShortName);

					ZeroMemory(m_Info.Data);
					if (CopyBuffer(handle, 0, 0, 1, Buff) == 1)
					{
						loc.dValue = Buff[0];
						m_Info.Data.ButtonStatus = loc._8b[0];
						DecodeAlls((int)loc._16b[1], (int)loc._16b[2]);
					}
					IndicatorRelease(handle);
				}

				return m_Info.Data;
			}
//+------------------------------------------------------------------+

double Buff[];
					uCast_Double loc;
					int handle = ChartIndicatorGet(GetInfoTerminal().ID, 0, m_Mem.szShortName);

					ZeroMemory(m_Info.Data);
					if (CopyBuffer(handle, 0, 0, 1, Buff) == 1)
					{
						loc.dValue = Buff[0];
						m_Info.Data.ButtonStatus = loc._8b[0];
						DecodeAlls((int)loc._16b[1], (int)loc._16b[2]);
					}
					IndicatorRelease(handle);
				}

				return m_Info.Data;
			}
//+------------------------------------------------------------------+
inline void SetBuffer(const int rates_total, double &Buff[])
			{
            uCast_Double info;

            info._8b[0] = (uchar)(m_Info.Study == C_Mouse::eStudyNull ? m_Info.Data.ButtonStatus : 0);
            info._16b[1] = (ushort) m_Info.Data.Position.X_Graphics;
            info._16b[2] = (ushort) m_Info.Data.Position.Y_Graphics;
            Buff[rates_total - 1] = info.dValue;
			}
//+------------------------------------------------------------------+
		void DispatchMessage(const int id, const long &lparam, const double &dparam, const string &sparam)
			{
				int w = 0;
				static double memPrice = 0;

				if (m_OK)
				{
					C_Terminal::DispatchMessage(id, lparam, dparam, sparam);
					switch (id)
					{
						case (CHARTEVENT_CUSTOM + evHideMouse):
							if (m_Mem.IsFull)	ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szLineH, OBJPROP_COLOR, clrNONE);
							break;
						case (CHARTEVENT_CUSTOM + evShowMouse):
							if (m_Mem.IsFull) ObjectSetInteger(GetInfoTerminal().ID, m_Mem.szLineH, OBJPROP_COLOR, m_Info.corLineH);
							break;
						case CHARTEVENT_MOUSE_MOVE:
							DecodeAlls((int)lparam, (int)dparam);
							if (m_Mem.IsFull) ObjectMove(GetInfoTerminal().ID, m_Mem.szLineH, 0, 0, m_Info.Data.Position.Price);
							if ((m_Info.Study != eStudyNull) && (m_Mem.IsFull)) ObjectMove(GetInfoTerminal().ID, m_Mem.szLineV, 0, m_Info.Data.Position.dt, 0);
							m_Info.Data.ButtonStatus = (uchar) sparam;
							if (CheckClick(eClickMiddle))
								if ((!m_Mem.IsFull) || ((color)ObjectGetInteger(GetInfoTerminal().ID, m_Mem.szLineH, OBJPROP_COLOR) != clrNONE)) CreateStudy();
							if (CheckClick(eClickLeft) && (m_Info.Study == eStudyCreate))
							{
								ChartSetInteger(GetInfoTerminal().ID, CHART_MOUSE_SCROLL, false);
								if (m_Mem.IsFull)	ObjectMove(GetInfoTerminal().ID, m_Mem.szLineT, 0, m_Mem.dt = GetInfoMouse().Position.dt, memPrice = GetInfoMouse().Position.Price);
								m_Info.Study = eStudyExecute;
							}
							if (m_Info.Study == eStudyExecute) ExecuteStudy(memPrice);
							m_Info.Data.ExecStudy = m_Info.Study == eStudyExecute;
							break;
						case CHARTEVENT_OBJECT_DELETE:
							if ((m_Mem.IsFull) && (sparam == m_Mem.szLineH))
								CreateObjectGraphics(m_Mem.szLineH, OBJ_HLINE, m_Info.corLineH);
							break;
					}
				}
			}
//+------------------------------------------------------------------+
};

m_Info.Study = eStudyExecute;
							}
							if (m_Info.Study == eStudyExecute) ExecuteStudy(memPrice);
							m_Info.Data.ExecStudy = m_Info.Study == eStudyExecute;
							break;
						case CHARTEVENT_OBJECT_DELETE:
							if ((m_Mem.IsFull) && (sparam == m_Mem.szLineH))
								CreateObjectGraphics(m_Mem.szLineH, OBJ_HLINE, m_Info.corLineH);
							break;
					}
				}
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
#undef macro_NameObjectStudy
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Auxiliar/C_PanelText.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "C_Terminal.mqh"
//+------------------------------------------------------------------+
//#define macroColorRGBA(A, B) ((uint)((B << 24) | (A & 0x00FF00) | ((A & 0xFF0000) >> 16) | ((A & 0x0000FF) << 16)))
//+------------------------------------------------------------------+

class C_PanelText
{
	protected:
		struct stTextSize
			{
				int 	width,
						height;
			};
	private	:
		int		m_width,
					m_height;
		uint		m_Pixel[];
		string	m_szObjName,
					m_szRcName;
		long 		m_id;
		stTextSize m_TextInfos;
	public	:
//+------------------------------------------------------------------+
		C_PanelText(int x, int y, int w, int h, string szFont, int FontSize, int sub = 0)
			:m_szObjName(NULL),
			 m_szRcName(NULL)
			{
				m_id = ChartID();
				ResetLastError();
				TextSetFont(szFont, FontSize, 0, 0);
				TextGetSize("M", m_TextInfos.width, m_TextInfos.height);
				if (((m_width = w) > 0) && ((m_height = h) > 0) && (ArrayResize(m_Pixel, w * h) > 0))
				{
					m_szRcName = "::" + (m_szObjName = "C_PanelText_" + (string)ObjectsTotal(m_id));
					if (ObjectCreate(m_id, m_szObjName, OBJ_BITMAP_LABEL, sub, 0, 0))	return;
				}
				SetUserError(C_Terminal::ERR_Unknown);
			}
//+------------------------------------------------------------------+
		~C_PanelText()
			{
				ArrayFree(m_Pixel);
				ObjectDelete(m_id, m_szObjName);
				ResourceFree(m_szRcName);
			}
//+------------------------------------------------------------------+
const int Resize(int x, int y, uchar fw, int h)
			{
				m_width = (fw * m_TextInfos.width);
				m_height = h;
				ObjectSetInteger(m_id, m_szObjName, OBJPROP_XDISTANCE, x - m_width);
				ObjectSetInteger(m_id, m_szObjName, OBJPROP_YDISTANCE, y);
				ArrayResize(m_Pixel, m_width * h);

				return m_width;
			}
//+------------------------------------------------------------------+
		void Update(void)
			{
				if (m_szRcName == NULL) return;
				if (ResourceCreate(m_szRcName, m_Pixel, m_width, m_height, 0, 0, 0, COLOR_FORMAT_ARGB_NORMALIZE))
				{
					ObjectSetString(m_id, m_szObjName, OBJPROP_BMPFILE, m_szRcName);
					ChartRedraw();
				}
			}
//+------------------------------------------------------------------+
inline void Erase(const uint clr = clrWhite, const uint ts = 0) { ArrayInitialize(m_Pixel, macroColorRGBA(clr, ts)); }
//+------------------------------------------------------------------+
inline const stTextSize TextOutFast(int x, int y, string text, const uint clr)
			{
				TextOut(text, x, y, 0, m_Pixel, m_width, m_height, clr, COLOR_FORMAT_ARGB_NORMALIZE);
				return m_TextInfos;
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Auxiliar/C_Terminal.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "Macros.mqh"
#include "..\Defines.mqh"
//+------------------------------------------------------------------+

class C_Terminal
{
//+------------------------------------------------------------------+
	protected:
		enum eErrUser {ERR_Unknown, ERR_FileAcess, ERR_PointerInvalid, ERR_NoMoreInstance};
//+------------------------------------------------------------------+
		struct st_Terminal
		{
			ENUM_SYMBOL_CHART_MODE 	 ChartMode;
			ENUM_ACCOUNT_MARGIN_MODE TypeAccount;
			long				ID;
			string			szSymbol;
			int				Width,
								Height,
								nDigits,
								SubWin,
								HeightBar;
			double			PointPerTick,
								ValuePerPoint,
								VolumeMinimal,
								AdjustToTrade;
		};
//+------------------------------------------------------------------+
	private	:
		st_Terminal m_Infos;
		struct mem
		{
			long 	Show_Descr,
					Show_Date;
			bool	AccountLock;
		}m_Mem;
//+------------------------------------------------------------------+
		void CurrentSymbol(void)
			{
				MqlDateTime mdt1;
				string sz0, sz1;
				datetime dt = macroGetDate(TimeCurrent(mdt1));
				enum eTypeSymbol {WIN, IND, WDO, DOL, OTHER} eTS = OTHER;

				sz0 = StringSubstr(m_Infos.szSymbol = _Symbol, 0, 3);
				for (eTypeSymbol c0 = 0; (c0 < OTHER) && (eTS == OTHER); c0++) eTS = (EnumToString(c0) == sz0 ? c0 : eTS);
				switch (eTS)
				{
					case DOL	:
					case WDO	: sz1 = "FGHJKMNQUVXZ"; break;
					case IND	:
					case WIN	: sz1 = "GJMQVZ"; 		break;
					default	: return;
				}
				for (int i0 = 0, i1 = mdt1.year - 2000, imax = StringLen(sz1);; i0 = ((++i0) < imax ? i0 : 0), i1 += (i0 == 0 ? 1 : 0))
					if (dt < macroGetDate(SymbolInfoInteger(m_Infos.szSymbol = StringFormat("%s%s%d", sz0, StringSubstr(sz1, i0, 1), i1), SYMBOL_EXPIRATION_TIME))) break;
			}
//+------------------------------------------------------------------+
inline void ChartChange(void)
			{
				int x, y, t;
				m_Infos.Width  = (int)ChartGetInteger(m_Infos.ID, CHART_WIDTH_IN_PIXELS);
				m_Infos.Height = (int)ChartGetInteger(m_Infos.ID, CHART_HEIGHT_IN_PIXELS);
				ChartTimePriceToXY(m_Infos.ID, 0, 0, 0, x, t);
				ChartTimePriceToXY(m_Infos.ID, 0, 0, m_Infos.PointPerTick * 100, x, y);
				m_Infos.HeightBar = (int)((t - y) / 100);
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_Terminal(const long id = 0, const uchar sub = 0)
			{
				m_Infos.ID = (id == 0 ? ChartID() : id);
				m_Mem.AccountLock = false;
				m_Infos.SubWin = (int) sub;
				CurrentSymbol();
				m_Mem.Show_Descr = ChartGetInteger(m_Infos.ID, CHART_SHOW_OBJECT_DESCR);
				m_Mem.Show_Date  = ChartGetInteger(m_Infos.ID, CHART_SHOW_DATE_SCALE);
				ChartSetInteger(m_Infos.ID, CHART_SHOW_OBJECT_DESCR, false);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_DELETE, true);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_CREATE, true);
				ChartSetInteger(m_Infos.ID, CHART_SHOW_DATE_SCALE, false);

m_Infos.SubWin = (int) sub;
				CurrentSymbol();
				m_Mem.Show_Descr = ChartGetInteger(m_Infos.ID, CHART_SHOW_OBJECT_DESCR);
				m_Mem.Show_Date  = ChartGetInteger(m_Infos.ID, CHART_SHOW_DATE_SCALE);
				ChartSetInteger(m_Infos.ID, CHART_SHOW_OBJECT_DESCR, false);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_DELETE, true);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_CREATE, true);
				ChartSetInteger(m_Infos.ID, CHART_SHOW_DATE_SCALE, false);
				m_Infos.nDigits = (int) SymbolInfoInteger(m_Infos.szSymbol, SYMBOL_DIGITS);
				m_Infos.Width   = (int)ChartGetInteger(m_Infos.ID, CHART_WIDTH_IN_PIXELS);
				m_Infos.Height  = (int)ChartGetInteger(m_Infos.ID, CHART_HEIGHT_IN_PIXELS);
				m_Infos.PointPerTick  = SymbolInfoDouble(m_Infos.szSymbol, SYMBOL_TRADE_TICK_SIZE);
				m_Infos.ValuePerPoint = SymbolInfoDouble(m_Infos.szSymbol, SYMBOL_TRADE_TICK_VALUE);
				m_Infos.VolumeMinimal = SymbolInfoDouble(m_Infos.szSymbol, SYMBOL_VOLUME_STEP);
				m_Infos.AdjustToTrade = m_Infos.ValuePerPoint / m_Infos.PointPerTick;
				m_Infos.ChartMode	= (ENUM_SYMBOL_CHART_MODE) SymbolInfoInteger(m_Infos.szSymbol, SYMBOL_CHART_MODE);
				if(m_Infos.szSymbol != def_SymbolReplay) SetTypeAccount((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE));
				ChartChange();
			}
//+------------------------------------------------------------------+
		~C_Terminal()
			{
				ChartSetInteger(m_Infos.ID, CHART_SHOW_DATE_SCALE, m_Mem.Show_Date);
				ChartSetInteger(m_Infos.ID, CHART_SHOW_OBJECT_DESCR, m_Mem.Show_Descr);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_DELETE, false);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_CREATE, false);
			}
//+------------------------------------------------------------------+
inline void SetTypeAccount(const ENUM_ACCOUNT_MARGIN_MODE arg)
			{
				if (m_Mem.AccountLock) return; else m_Mem.AccountLock = true;
				m_Infos.TypeAccount = (arg == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING ? arg : ACCOUNT_MARGIN_MODE_RETAIL_NETTING);
			}
//+------------------------------------------------------------------+
inline const st_Terminal GetInfoTerminal(void) const
			{
				return m_Infos;
			}
//+------------------------------------------------------------------+
const double AdjustPrice(const double arg) const
			{
				return NormalizeDouble(round(arg / m_Infos.PointPerTick) * m_Infos.PointPerTick, m_Infos.nDigits);
			}
//+------------------------------------------------------------------+
inline datetime AdjustTime(const datetime arg)
			{
				int nSeconds= PeriodSeconds();
				datetime	dt = iTime(m_Infos.szSymbol, PERIOD_CURRENT, 0);

				return (dt < arg ? ((datetime)(arg / nSeconds) * nSeconds) : iTime(m_Infos.szSymbol, PERIOD_CURRENT, Bars(m_Infos.szSymbol, PERIOD_CURRENT, arg, dt)));
			}
//+------------------------------------------------------------------+
inline double FinanceToPoints(const double Finance, const uint Leverage)
			{

inline datetime AdjustTime(const datetime arg)
			{
				int nSeconds= PeriodSeconds();
				datetime	dt = iTime(m_Infos.szSymbol, PERIOD_CURRENT, 0);

				return (dt < arg ? ((datetime)(arg / nSeconds) * nSeconds) : iTime(m_Infos.szSymbol, PERIOD_CURRENT, Bars(m_Infos.szSymbol, PERIOD_CURRENT, arg, dt)));
			}
//+------------------------------------------------------------------+
inline double FinanceToPoints(const double Finance, const uint Leverage)
			{
				double volume = m_Infos.VolumeMinimal + (m_Infos.VolumeMinimal * (Leverage - 1));

				return AdjustPrice(MathAbs(((Finance / volume) / m_Infos.AdjustToTrade)));
			};
//+------------------------------------------------------------------+
		void DispatchMessage(const int id, const long &lparam, const double &dparam, const string &sparam)
			{
				static string st_str = "";

				switch (id)
				{
					case CHARTEVENT_CHART_CHANGE:
						m_Infos.Width  = (int)ChartGetInteger(m_Infos.ID, CHART_WIDTH_IN_PIXELS);
						m_Infos.Height = (int)ChartGetInteger(m_Infos.ID, CHART_HEIGHT_IN_PIXELS);
						ChartChange();
						break;
					case CHARTEVENT_OBJECT_CLICK:
						if (st_str != sparam) ObjectSetInteger(m_Infos.ID, st_str, OBJPROP_SELECTED, false);
						if (ObjectGetInteger(m_Infos.ID, sparam, OBJPROP_SELECTABLE) == true)
							ObjectSetInteger(m_Infos.ID, st_str = sparam, OBJPROP_SELECTED, true);
						break;
					case CHARTEVENT_OBJECT_CREATE:
						if (st_str != sparam) ObjectSetInteger(m_Infos.ID, st_str, OBJPROP_SELECTED, false);
						st_str = sparam;
						break;
				}
			}
//+------------------------------------------------------------------+
inline void CreateObjectGraphics(const string szName, const ENUM_OBJECT obj, const color cor = clrNONE, const int zOrder = -1) const
			{
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_CREATE, 0, false);
				ObjectCreate(m_Infos.ID, szName, obj, m_Infos.SubWin, 0, 0);
				ObjectSetString(m_Infos.ID, szName, OBJPROP_TOOLTIP, "\n");
				ObjectSetInteger(m_Infos.ID, szName, OBJPROP_BACK, false);
				ObjectSetInteger(m_Infos.ID, szName, OBJPROP_COLOR, cor);
				ObjectSetInteger(m_Infos.ID, szName, OBJPROP_SELECTABLE, false);
				ObjectSetInteger(m_Infos.ID, szName, OBJPROP_SELECTED, false);
				ObjectSetInteger(m_Infos.ID, szName, OBJPROP_ZORDER, zOrder);
				ChartSetInteger(m_Infos.ID, CHART_EVENT_OBJECT_CREATE, 0, true);
			}
//+------------------------------------------------------------------+
		bool IndicatorCheckPass(const string szShortName)
			{
				string szTmp = szShortName + "_TMP";

				IndicatorSetString(INDICATOR_SHORTNAME, szTmp);
				m_Infos.SubWin = ((m_Infos.SubWin = ChartWindowFind(m_Infos.ID, szTmp)) < 0 ? 0 : m_Infos.SubWin);
				if (ChartIndicatorGet(m_Infos.ID, m_Infos.SubWin, szShortName) != INVALID_HANDLE)
				{
					ChartIndicatorDelete(m_Infos.ID, 0, szTmp);
					Print("Only one instance is allowed...");

bool IndicatorCheckPass(const string szShortName)
			{
				string szTmp = szShortName + "_TMP";

				IndicatorSetString(INDICATOR_SHORTNAME, szTmp);
				m_Infos.SubWin = ((m_Infos.SubWin = ChartWindowFind(m_Infos.ID, szTmp)) < 0 ? 0 : m_Infos.SubWin);
				if (ChartIndicatorGet(m_Infos.ID, m_Infos.SubWin, szShortName) != INVALID_HANDLE)
				{
					ChartIndicatorDelete(m_Infos.ID, 0, szTmp);
					Print("Only one instance is allowed...");
					SetUserError(C_Terminal::ERR_NoMoreInstance);

					return false;
				}
				IndicatorSetString(INDICATOR_SHORTNAME, szShortName);

				return true;
			}
//+------------------------------------------------------------------+
};

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Auxiliar/Macros.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#define macroRemoveSec(A) (A - (A % 60))
#define macroGetDate(A) (A - (A % 86400))
#define macroGetSec(A) 	(A - (A - (A % 60)))
#define macroGetTime(A) (A % 86400)
/*#define macroGetSec(A) 	(A - (A - (A % 60)))
#define macroGetMin(A) 	(int)((A - (A - ((A % 3600) - (A % 60)))) / 60)
#define macroGetHour(A)	(A - (A - ((A % 86400) - (A % 3600))))
#define macroHourBiggerOrEqual(A, B) ((A * 3600) < (B - (B - ((B % 86400) - (B % 3600)))))
#define macroMinusMinutes(A, B) (B - ((A * 60) + (B % 60)))
#define macroMinusHours(A, B) (B - (A * 3600))
#define macroAddHours(A, B) (B + (A * 3600))
#define macroAddMin(A, B) (B + (A * 60))
#define macroSetHours(A, B) ((A * 3600) + (B - ((B % 86400))))
#define macroSetMin(A, B) ((A * 60) + (B - (B % 3600)))
#define macroSetTime(A, B, C) ((A * 3600) + (B * 60) + (C - (C % 86400)))*/
//+------------------------------------------------------------------+
#define macroColorRGBA(A, B) ((uint)((B << 24) | (A & 0x00FF00) | ((A & 0xFF0000) >> 16) | ((A & 0x0000FF) << 16)))
#define macroTransparency(A) (((A > 100 ? 100 : (100 - A)) * 2.55) / 255.0)
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Auxiliar/Study/C_Study.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "..\C_Mouse.mqh"
//+------------------------------------------------------------------+
#define def_ExpansionPrefix def_MousePrefixName + "Expansion_"
//+------------------------------------------------------------------+

class C_Study : public C_Mouse
{
	private	:
//+------------------------------------------------------------------+
		struct st00
		{
			eStatusMarket 	Status;
			MqlRates 		Rate;
			string			szInfo,
								szBtn1,
								szBtn2,
								szBtn3;
			color				corP,
								corN;
			int				HeightText;
			bool				bvT, bvD, bvP;
		}m_Info;
//+------------------------------------------------------------------+
		void Draw(void)
			{
				double v1;

				if (m_Info.bvT)
				{
					ObjectSetInteger(GetInfoTerminal().ID, m_Info.szBtn1, OBJPROP_YDISTANCE, GetInfoMouse().Position.Y_Adjusted - 18);
					ObjectSetString(GetInfoTerminal().ID, m_Info.szBtn1, OBJPROP_TEXT, m_Info.szInfo);
				}
				if (m_Info.bvD)
				{
					v1 = NormalizeDouble((((GetInfoMouse().Position.Price - m_Info.Rate.close) / m_Info.Rate.close) * 100.0), 2);
					ObjectSetInteger(GetInfoTerminal().ID, m_Info.szBtn2, OBJPROP_YDISTANCE, GetInfoMouse().Position.Y_Adjusted - 1);
					ObjectSetInteger(GetInfoTerminal().ID, m_Info.szBtn2, OBJPROP_BGCOLOR, (v1 < 0 ? m_Info.corN : m_Info.corP));
					ObjectSetString(GetInfoTerminal().ID, m_Info.szBtn2, OBJPROP_TEXT, StringFormat("%.2f%%", MathAbs(v1)));
				}
			if (m_Info.bvP)
				{
					v1 = NormalizeDouble((((GL_PriceClose - m_Info.Rate.close) / m_Info.Rate.close) * 100.0), 2);
					ObjectSetInteger(GetInfoTerminal().ID, m_Info.szBtn3, OBJPROP_YDISTANCE, GetInfoMouse().Position.Y_Adjusted - 1);
					ObjectSetInteger(GetInfoTerminal().ID, m_Info.szBtn3, OBJPROP_BGCOLOR, (v1 < 0 ? m_Info.corN : m_Info.corP));
					ObjectSetString(GetInfoTerminal().ID, m_Info.szBtn3, OBJPROP_TEXT, StringFormat("%.2f%%", MathAbs(v1)));
				}
			}
//+------------------------------------------------------------------+
inline void CreateObjInfo(EnumEvents arg)
			{
				switch (arg)
				{
					case evShowBarTime:
						C_Mouse::CreateObjToStudy(2, 110, m_Info.szBtn1 = (def_ExpansionPrefix + (string)ObjectsTotal(0)), clrPaleTurquoise);
						m_Info.bvT = true;
						break;
					case evShowDailyVar:
						C_Mouse::CreateObjToStudy(2, 53, m_Info.szBtn2 = (def_ExpansionPrefix + (string)ObjectsTotal(0)));
						m_Info.bvD = true;
						break;
					case evShowPriceVar:
						C_Mouse::CreateObjToStudy(58, 53, m_Info.szBtn3 = (def_ExpansionPrefix + (string)ObjectsTotal(0)));
						m_Info.bvP = true;
						break;
				}
			}
//+------------------------------------------------------------------+
inline void RemoveObjInfo(EnumEvents arg)
			{
				string sz;

				switch (arg)
				{
					case evHideBarTime:
						sz = m_Info.szBtn1;
						m_Info.bvT = false;
						break;
					case evHideDailyVar:
						sz = m_Info.szBtn2;
						m_Info.bvD	= false;
						break;
					case evHidePriceVar:
						sz = m_Info.szBtn3;
						m_Info.bvP = false;
						break;
				}
				ChartSetInteger(GetInfoTerminal().ID, CHART_EVENT_OBJECT_DELETE, false);
				ObjectDelete(GetInfoTerminal().ID, sz);

{
				string sz;

				switch (arg)
				{
					case evHideBarTime:
						sz = m_Info.szBtn1;
						m_Info.bvT = false;
						break;
					case evHideDailyVar:
						sz = m_Info.szBtn2;
						m_Info.bvD	= false;
						break;
					case evHidePriceVar:
						sz = m_Info.szBtn3;
						m_Info.bvP = false;
						break;
				}
				ChartSetInteger(GetInfoTerminal().ID, CHART_EVENT_OBJECT_DELETE, false);
				ObjectDelete(GetInfoTerminal().ID, sz);
				ChartSetInteger(GetInfoTerminal().ID, CHART_EVENT_OBJECT_DELETE, true);
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_Study(long IdParam, string szShortName, color corH, color corP, color corN)
			:C_Mouse(IdParam, szShortName, corH, corP, corN)
			{
				if (_LastError >= ERR_USER_ERROR_FIRST) return;
				ZeroMemory(m_Info);
				m_Info.corP = corP;
				m_Info.corN = corN;
				CreateObjInfo(evShowBarTime);
				CreateObjInfo(evShowDailyVar);
				CreateObjInfo(evShowPriceVar);
				ResetLastError();
			}
//+------------------------------------------------------------------+
		void Update(const eStatusMarket arg)
			{
				int i0;
				datetime dt;

				if (m_Info.Rate.close == 0)
					m_Info.Rate.close = iClose(NULL, PERIOD_D1, ((_Symbol == def_SymbolReplay) || (macroGetDate(TimeCurrent()) != macroGetDate(iTime(NULL, PERIOD_D1, 0))) ? 0 : 1));
				switch (m_Info.Status = (m_Info.Status != arg ? arg : m_Info.Status))
				{
					case eCloseMarket	:
						m_Info.szInfo = "Closed Market";
						break;
					case eInReplay		:
					case eInTrading	:
						i0 = PeriodSeconds();
						dt = (m_Info.Status == eInReplay ? (datetime) GL_TimeAdjust : TimeCurrent());
						m_Info.Rate.time = (m_Info.Rate.time <= dt ? (datetime)(((ulong) dt / i0) * i0) + i0 : m_Info.Rate.time);
						if (dt > 0) m_Info.szInfo = TimeToString((datetime)m_Info.Rate.time - dt, TIME_SECONDS);
						break;
					case eAuction		:
						m_Info.szInfo = "Auction";
						break;
					default				:
						m_Info.szInfo = "ERROR";
				}
				Draw();
			}
//+------------------------------------------------------------------+
virtual void DispatchMessage(const int id, const long &lparam, const double &dparam, const string &sparam)
			{
				C_Mouse::DispatchMessage(id, lparam, dparam, sparam);
				switch (id)
				{
					case CHARTEVENT_CUSTOM + evHideBarTime:
						RemoveObjInfo(evHideBarTime);
						break;
					case CHARTEVENT_CUSTOM + evShowBarTime:
						CreateObjInfo(evShowBarTime);
						break;
					case CHARTEVENT_CUSTOM + evHideDailyVar:
						RemoveObjInfo(evHideDailyVar);
						break;
					case CHARTEVENT_CUSTOM + evShowDailyVar:
						CreateObjInfo(evShowDailyVar);
						break;
					case CHARTEVENT_CUSTOM + evHidePriceVar:
						RemoveObjInfo(evHidePriceVar);
						break;
					case CHARTEVENT_CUSTOM + evShowPriceVar:

RemoveObjInfo(evHideBarTime);
						break;
					case CHARTEVENT_CUSTOM + evShowBarTime:
						CreateObjInfo(evShowBarTime);
						break;
					case CHARTEVENT_CUSTOM + evHideDailyVar:
						RemoveObjInfo(evHideDailyVar);
						break;
					case CHARTEVENT_CUSTOM + evShowDailyVar:
						CreateObjInfo(evShowDailyVar);
						break;
					case CHARTEVENT_CUSTOM + evHidePriceVar:
						RemoveObjInfo(evHidePriceVar);
						break;
					case CHARTEVENT_CUSTOM + evShowPriceVar:
						CreateObjInfo(evShowPriceVar);
						break;
					case CHARTEVENT_MOUSE_MOVE:
						Draw();
						break;
				}
				ChartRedraw(GetInfoTerminal().ID);
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
#undef def_ExpansionPrefix
#undef def_MousePrefixName
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Chart Trader/C_AdjustTemplate.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "../Auxiliar/C_Terminal.mqh"
//+------------------------------------------------------------------+
#define def_PATH_BTN "Images\\Market Replay\\Chart Trade"
#define def_BTN_BUY	def_PATH_BTN + "\\BUY.bmp"
#define def_BTN_SELL	def_PATH_BTN + "\\SELL.bmp"
#define def_BTN_DT	def_PATH_BTN + "\\DT.bmp"
#define def_BTN_SW	def_PATH_BTN + "\\SW.bmp"
#define def_BTN_MAX	def_PATH_BTN + "\\MAX.bmp"
#define def_BTN_MIN	def_PATH_BTN + "\\MIN.bmp"
#define def_IDE_RAD	def_PATH_BTN + "\\IDE_RAD.tpl"
//+------------------------------------------------------------------+
#resource "\\" + def_BTN_BUY
#resource "\\" + def_BTN_SELL
#resource "\\" + def_BTN_DT
#resource "\\" + def_BTN_SW
#resource "\\" + def_BTN_MAX
#resource "\\" + def_BTN_MIN
#resource "\\" + def_IDE_RAD as string IdeRad;
//+------------------------------------------------------------------+

class C_AdjustTemplate
{
	private	:
		string m_szName[],
				m_szFind[],
				m_szReplace[],
				m_szFileName;
		int 	m_maxIndex,
				m_FileIn,
				m_FileOut;
		bool 	m_bFirst;
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_AdjustTemplate(const string szFile, const bool bFirst = false)
			:m_maxIndex(0),
			 m_szFileName(szFile),
			 m_bFirst(bFirst),
			 m_FileIn(INVALID_HANDLE),
			 m_FileOut(INVALID_HANDLE)
			{
				if (m_bFirst)
				{
					int handle = FileOpen(m_szFileName, FILE_TXT | FILE_WRITE);
					FileWriteString(handle, IdeRad);
					FileClose(handle);
				}
				if ((m_FileIn = FileOpen(m_szFileName, FILE_TXT | FILE_READ)) == INVALID_HANDLE)	SetUserError(C_Terminal::ERR_FileAcess);
				if ((m_FileOut = FileOpen(m_szFileName + "_T", FILE_TXT | FILE_WRITE)) == INVALID_HANDLE) SetUserError(C_Terminal::ERR_FileAcess);
			}
//+------------------------------------------------------------------+
		~C_AdjustTemplate()
			{
				FileClose(m_FileIn);
				FileClose(m_FileOut);
				FileMove(m_szFileName + "_T", 0, m_szFileName, FILE_REWRITE);
				ArrayResize(m_szName, 0);
				ArrayResize(m_szFind, 0);
				ArrayResize(m_szReplace, 0);
			}
//+------------------------------------------------------------------+
		void Add(const string szName, const string szFind, const string szReplace)
			{
				m_maxIndex++;
				ArrayResize(m_szName, m_maxIndex);
				ArrayResize(m_szFind, m_maxIndex);
				ArrayResize(m_szReplace, m_maxIndex);
				m_szName[m_maxIndex - 1] = szName;
				m_szFind[m_maxIndex - 1] = szFind;
				m_szReplace[m_maxIndex - 1] = szReplace;
			}
//+------------------------------------------------------------------+
		string Get(const string szName, const string szFind)
			{
				for (int c0 = 0; c0 < m_maxIndex; c0++) if ((m_szName[c0] == szName) && (m_szFind[c0] == szFind)) return m_szReplace[c0];

				return NULL;
			}
//+------------------------------------------------------------------+
		bool Execute(void)
			{
				string sz0, tmp, res[];
				int count0 = 0, i0;

				if ((m_FileIn == INVALID_HANDLE) || (m_FileOut == INVALID_HANDLE)) return false;
				while (!FileIsEnding(m_FileIn))
				{
					sz0 = FileReadString(m_FileIn);
					if (sz0 == "<object>") count0 = 1;
					if (sz0 == "</object>") count0 = 0;
					if (count0 > 0) if (StringSplit(sz0, '=', res) > 1)
					{
						if ((m_bFirst) && ((res[0] == "bmpfile_on") || (res[0] == "bmpfile_off")))
							sz0 = res[0] + "=\\Indicators\\Chart Trade.ex5::" + def_PATH_BTN + res[1];
						i0 = (count0 == 1 ? 0 : i0);
						for (int c0 = 0; (c0 < m_maxIndex) && (count0 == 1); i0 = c0, c0++) count0 = (res[1] == (tmp = m_szName[c0]) ? 2 : count0);
						for (int c0 = i0; (c0 < m_maxIndex) && (count0 == 2); c0++) if ((res[0] == m_szFind[c0]) && (tmp == m_szName[c0]))
						{

{
						if ((m_bFirst) && ((res[0] == "bmpfile_on") || (res[0] == "bmpfile_off")))
							sz0 = res[0] + "=\\Indicators\\Chart Trade.ex5::" + def_PATH_BTN + res[1];
						i0 = (count0 == 1 ? 0 : i0);
						for (int c0 = 0; (c0 < m_maxIndex) && (count0 == 1); i0 = c0, c0++) count0 = (res[1] == (tmp = m_szName[c0]) ? 2 : count0);
						for (int c0 = i0; (c0 < m_maxIndex) && (count0 == 2); c0++) if ((res[0] == m_szFind[c0]) && (tmp == m_szName[c0]))
						{
							if (StringLen(m_szReplace[c0])) sz0 =  m_szFind[c0] + "=" + m_szReplace[c0];
							else m_szReplace[c0] = res[1];
						}
					}
					if (FileWriteString(m_FileOut, sz0 + "\r\n") < 2) return false;
				};

				return true;
			}
//+------------------------------------------------------------------+
};
//+------------------------------------------------------------------+
#undef def_BTN_BUY
#undef def_BTN_SELL
#undef def_BTN_DT
#undef def_BTN_SW
#undef def_BTN_MAX
#undef def_BTN_MIN
#undef def_IDE_RAD
#undef def_PATH_BTN
//+------------------------------------------------------------------+

// CONTEXT: Series: Developing a Replay System, Part: 58, Title: Developing a Replay System (Part 58): Returning to Work on the Service - MQL5 Articles | FILE: Anexo.zip/Include/Market Replay/Chart Trader/C_ChartFloatingRAD.mqh
//+------------------------------------------------------------------+
#property copyright "Daniel Jose"
//+------------------------------------------------------------------+
#include "../Auxiliar/C_Mouse.mqh"
#include "C_AdjustTemplate.mqh"
//+------------------------------------------------------------------+
#define macro_NameGlobalVariable(A) StringFormat("ChartTrade_%u%s", GetInfoTerminal().ID, A)
#define macro_CloseIndicator(A)	{				\
					OnDeinit(REASON_INITFAILED);	\
					SetUserError(A);					\
					return;								\
											}
//+------------------------------------------------------------------+

class C_ChartFloatingRAD : private C_Terminal
{
	private	:
		enum eObjectsIDE {MSG_LEVERAGE_VALUE, MSG_TAKE_VALUE, MSG_STOP_VALUE, MSG_MAX_MIN, MSG_TITLE_IDE, MSG_DAY_TRADE, MSG_BUY_MARKET, MSG_SELL_MARKET, MSG_CLOSE_POSITION, MSG_NULL};
		struct st00
		{
			short		x, y, minx, miny,
						Leverage;
			string	szObj_Chart,
						szObj_Editable,
						szFileNameTemplate;
			long		WinHandle;
			double	FinanceTake,
						FinanceStop;
			bool		IsMaximized,
						IsDayTrade,
						IsSaveState;
			struct st01
			{
				short	 x, y, w, h;
				color  bgcolor;
				int 	 FontSize;
				string FontName;
			}Regions[MSG_NULL];
		}m_Info;
		C_Mouse 		*m_Mouse;
//+------------------------------------------------------------------+
		void CreateWindowRAD(int w, int h)
			{
				m_Info.szObj_Chart = "Chart Trade IDE";
				m_Info.szObj_Editable = m_Info.szObj_Chart + " > Edit";
				ObjectCreate(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJ_CHART, 0, 0, 0);
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_XDISTANCE, m_Info.x);
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_YDISTANCE, m_Info.y);
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_XSIZE, w);
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_YSIZE, h);
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_DATE_SCALE, false);
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_PRICE_SCALE, false);
				m_Info.WinHandle = ObjectGetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_CHART_ID);
			};
//+------------------------------------------------------------------+
		void AdjustEditabled(C_AdjustTemplate &Template, bool bArg)
			{
				for (eObjectsIDE c0 = MSG_LEVERAGE_VALUE; c0 <= MSG_STOP_VALUE; c0++)
					if (bArg)
					{
						Template.Add(EnumToString(c0), "bgcolor", NULL);
						Template.Add(EnumToString(c0), "fontsz", NULL);
						Template.Add(EnumToString(c0), "fontnm", NULL);
					}
					else
					{
						m_Info.Regions[c0].bgcolor = (color) StringToInteger(Template.Get(EnumToString(c0), "bgcolor"));
						m_Info.Regions[c0].FontSize = (int) StringToInteger(Template.Get(EnumToString(c0), "fontsz"));
						m_Info.Regions[c0].FontName = Template.Get(EnumToString(c0), "fontnm");
					}
			}
//+------------------------------------------------------------------+
inline void AdjustTemplate(const bool bFirst = false)
			{
#define macro_PointsToFinance(A) A * (GetInfoTerminal().VolumeMinimal + (GetInfoTerminal().VolumeMinimal * (m_Info.Leverage - 1))) * GetInfoTerminal().AdjustToTrade

				C_AdjustTemplate 	*Template;

				if (bFirst)
				{
					Template = new C_AdjustTemplate(m_Info.szFileNameTemplate = IntegerToString(GetInfoTerminal().ID) + ".tpl", true);
					for (eObjectsIDE c0 = MSG_LEVERAGE_VALUE; c0 <= MSG_CLOSE_POSITION; c0++)
					{
						(*Template).Add(EnumToString(c0), "size_x", NULL);

C_AdjustTemplate 	*Template;

				if (bFirst)
				{
					Template = new C_AdjustTemplate(m_Info.szFileNameTemplate = IntegerToString(GetInfoTerminal().ID) + ".tpl", true);
					for (eObjectsIDE c0 = MSG_LEVERAGE_VALUE; c0 <= MSG_CLOSE_POSITION; c0++)
					{
						(*Template).Add(EnumToString(c0), "size_x", NULL);
						(*Template).Add(EnumToString(c0), "size_y", NULL);
						(*Template).Add(EnumToString(c0), "pos_x", NULL);
						(*Template).Add(EnumToString(c0), "pos_y", NULL);
					}
					AdjustEditabled(Template, true);
				}else Template = new C_AdjustTemplate(m_Info.szFileNameTemplate);
				if (_LastError >= ERR_USER_ERROR_FIRST)
				{
					delete Template;

					return;
				}
				m_Info.Leverage = (m_Info.Leverage <= 0 ? 1 : m_Info.Leverage);
				m_Info.FinanceTake = macro_PointsToFinance(FinanceToPoints(MathAbs(m_Info.FinanceTake), m_Info.Leverage));
				m_Info.FinanceStop = macro_PointsToFinance(FinanceToPoints(MathAbs(m_Info.FinanceStop), m_Info.Leverage));
				(*Template).Add("MSG_NAME_SYMBOL", "descr", GetInfoTerminal().szSymbol);
				(*Template).Add("MSG_LEVERAGE_VALUE", "descr", IntegerToString(m_Info.Leverage));
				(*Template).Add("MSG_TAKE_VALUE", "descr", DoubleToString(m_Info.FinanceTake, 2));
				(*Template).Add("MSG_STOP_VALUE", "descr", DoubleToString(m_Info.FinanceStop, 2));
				(*Template).Add("MSG_DAY_TRADE", "state", (m_Info.IsDayTrade ? "1" : "0"));
				(*Template).Add("MSG_MAX_MIN", "state", (m_Info.IsMaximized ? "1" : "0"));
				if (!(*Template).Execute())
				{
					delete Template;

					macro_CloseIndicator(C_Terminal::ERR_FileAcess);
				};
				if (bFirst)
				{
					for (eObjectsIDE c0 = MSG_LEVERAGE_VALUE; c0 <= MSG_CLOSE_POSITION; c0++)
					{
						m_Info.Regions[c0].x = (short) StringToInteger((*Template).Get(EnumToString(c0), "pos_x"));
						m_Info.Regions[c0].y = (short) StringToInteger((*Template).Get(EnumToString(c0), "pos_y"));
						m_Info.Regions[c0].w = (short) StringToInteger((*Template).Get(EnumToString(c0), "size_x"));
						m_Info.Regions[c0].h = (short) StringToInteger((*Template).Get(EnumToString(c0), "size_y"));
					}
					m_Info.Regions[MSG_TITLE_IDE].w = m_Info.Regions[MSG_MAX_MIN].x;
					AdjustEditabled(Template, false);
				};
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_YSIZE, (m_Info.IsMaximized ? 210 : m_Info.Regions[MSG_TITLE_IDE].h + 6));
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_XDISTANCE, (m_Info.IsMaximized ? m_Info.x : m_Info.minx));
				ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_YDISTANCE, (m_Info.IsMaximized ? m_Info.y : m_Info.miny));

				delete Template;

				ChartApplyTemplate(m_Info.WinHandle, "/Files/" + m_Info.szFileNameTemplate);
				ChartRedraw(m_Info.WinHandle);

#undef macro_PointsToFinance
			}
//+------------------------------------------------------------------+

ObjectSetInteger(GetInfoTerminal().ID, m_Info.szObj_Chart, OBJPROP_YDISTANCE, (m_Info.IsMaximized ? m_Info.y : m_Info.miny));

				delete Template;

				ChartApplyTemplate(m_Info.WinHandle, "/Files/" + m_Info.szFileNameTemplate);
				ChartRedraw(m_Info.WinHandle);

#undef macro_PointsToFinance
			}
//+------------------------------------------------------------------+
		eObjectsIDE CheckMousePosition(const short x, const short y)
			{
				int xi, yi, xf, yf;

				for (eObjectsIDE c0 = MSG_LEVERAGE_VALUE; c0 <= MSG_CLOSE_POSITION; c0++)
				{
					xi = (m_Info.IsMaximized ? m_Info.x : m_Info.minx) + m_Info.Regions[c0].x;
					yi = (m_Info.IsMaximized ? m_Info.y : m_Info.miny) + m_Info.Regions[c0].y;
					xf = xi + m_Info.Regions[c0].w;
					yf = yi + m_Info.Regions[c0].h;
					if ((x > xi) && (y > yi) && (x < xf) && (y < yf)) return c0;
				}
				return MSG_NULL;
			}
//+------------------------------------------------------------------+
inline void DeleteObjectEdit(void)
			{
				ChartRedraw();
				ObjectsDeleteAll(GetInfoTerminal().ID, m_Info.szObj_Editable);
			}
//+------------------------------------------------------------------+
		template <typename T >
		void CreateObjectEditable(eObjectsIDE arg, T value)
			{
				long id = GetInfoTerminal().ID;

				DeleteObjectEdit();
				CreateObjectGraphics(m_Info.szObj_Editable, OBJ_EDIT, clrBlack, 0);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_XDISTANCE, m_Info.Regions[arg].x + m_Info.x + 3);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_YDISTANCE, m_Info.Regions[arg].y + m_Info.y + 3);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_XSIZE, m_Info.Regions[arg].w);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_YSIZE, m_Info.Regions[arg].h);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_BGCOLOR, m_Info.Regions[arg].bgcolor);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_ALIGN, ALIGN_CENTER);
				ObjectSetInteger(id, m_Info.szObj_Editable, OBJPROP_FONTSIZE, m_Info.Regions[arg].FontSize - 1);
				ObjectSetString(id, m_Info.szObj_Editable, OBJPROP_FONT, m_Info.Regions[arg].FontName);
				ObjectSetString(id, m_Info.szObj_Editable, OBJPROP_TEXT, (typename(T) == "double" ? DoubleToString(value, 2) : (string) value));
				ChartRedraw();
			}
//+------------------------------------------------------------------+
		bool RestoreState(void)
			{
				uCast_Double info;
				bool bRet;
				C_AdjustTemplate *Template;

				if (bRet = GlobalVariableGet(macro_NameGlobalVariable("POST"), info.dValue))
				{
					m_Info.x = (short) info._16b[0];
					m_Info.y = (short) info._16b[1];
					m_Info.minx = (short) info._16b[2];
					m_Info.miny = (short) info._16b[3];
					Template = new C_AdjustTemplate(m_Info.szFileNameTemplate = IntegerToString(GetInfoTerminal().ID) + ".tpl");
					if (_LastError >= ERR_USER_ERROR_FIRST) bRet = false; else
					{

bool bRet;
				C_AdjustTemplate *Template;

				if (bRet = GlobalVariableGet(macro_NameGlobalVariable("POST"), info.dValue))
				{
					m_Info.x = (short) info._16b[0];
					m_Info.y = (short) info._16b[1];
					m_Info.minx = (short) info._16b[2];
					m_Info.miny = (short) info._16b[3];
					Template = new C_AdjustTemplate(m_Info.szFileNameTemplate = IntegerToString(GetInfoTerminal().ID) + ".tpl");
					if (_LastError >= ERR_USER_ERROR_FIRST) bRet = false; else
					{
						(*Template).Add("MSG_LEVERAGE_VALUE", "descr", NULL);
						(*Template).Add("MSG_TAKE_VALUE", "descr", NULL);
						(*Template).Add("MSG_STOP_VALUE", "descr", NULL);
						(*Template).Add("MSG_DAY_TRADE", "state", NULL);
						(*Template).Add("MSG_MAX_MIN", "state", NULL);
						if (!(*Template).Execute()) bRet = false; else
						{
							m_Info.IsDayTrade = (bool) StringToInteger((*Template).Get("MSG_DAY_TRADE", "state")) == 1;
							m_Info.IsMaximized = (bool) StringToInteger((*Template).Get("MSG_MAX_MIN", "state")) == 1;
							m_Info.Leverage = (short)StringToInteger((*Template).Get("MSG_LEVERAGE_VALUE", "descr"));
							m_Info.FinanceTake = (double) StringToDouble((*Template).Get("MSG_TAKE_VALUE", "descr"));
							m_Info.FinanceStop = (double) StringToDouble((*Template).Get("MSG_STOP_VALUE", "descr"));
						}
					};
					delete Template;
				};

				GlobalVariablesDeleteAll(macro_NameGlobalVariable(""));

				return bRet;
			}
//+------------------------------------------------------------------+
	public	:
//+------------------------------------------------------------------+
		C_ChartFloatingRAD(string szShortName, C_Mouse *MousePtr, const short Leverage, const double FinanceTake, const double FinanceStop)
			:C_Terminal(0)
			{
				m_Mouse = MousePtr;
				m_Info.IsSaveState = false;
				if (!IndicatorCheckPass(szShortName)) return;
				if (!RestoreState())
				{
					m_Info.Leverage = Leverage;
					m_Info.IsDayTrade = true;
					m_Info.FinanceTake = FinanceTake;
					m_Info.FinanceStop = FinanceStop;
					m_Info.IsMaximized = true;
					m_Info.minx = m_Info.x = 115;
					m_Info.miny = m_Info.y = 64;
				}
				CreateWindowRAD(170, 210);
				AdjustTemplate(true);
			}
//+------------------------------------------------------------------+
		~C_ChartFloatingRAD()
			{
				ChartRedraw();
				ObjectsDeleteAll(GetInfoTerminal().ID, m_Info.szObj_Chart);
				if (!m_Info.IsSaveState)
					FileDelete(m_Info.szFileNameTemplate);

				delete m_Mouse;
			}
//+------------------------------------------------------------------+
		void SaveState(void)
			{
#define macro_GlobalVariable(A, B) if (GlobalVariableTemp(A)) GlobalVariableSet(A, B);

				uCast_Double info;

				info._16b[0] = m_Info.x;
				info._16b[1] = m_Info.y;
				info._16b[2] = m_Info.minx;
				info._16b[3] = m_Info.miny;
				macro_GlobalVariable(macro_NameGlobalVariable("POST"), info.dValue);
```

### 💻 Snippet 13 (Source: article_12510.html)
```
// CONTEXT: Series: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles, Part: N/A, Title: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles

Introduction

 We all need to read charts and any tool that can be helpful in this task will be very welcomed. Among tools that can be helpful in reading charts are indicators that are calculated based on prices, volume, another technical indicator or a combination of them, while there are many ideas that exist in the trading world. We have a lot of ready-made indicators built-in in the trading terminal and if we need to add some features to be suitable for our trading style, we can find some challenges because it may not be changeable in addition to that we may not find this indicator as a built-in in the trading terminal.

 In this article, I will share with you a method to overcome this challenge by benefiting from the iCustom function and creating your custom indicator following your terms and based on your preferences. We will also see an example, as we will create a custom Heiken Ashi technical indicator and we will use this custom indicator in trading system examples. We will cover that through the following topics:


 Custom Indicator and Heiken Ashi Definition
 Simple Heiken Ashi Indicator
 EA based on Custom Heiken Ashi Indicator
 Heiken Ashi - EMA System
 Conclusion

 After understanding what I share in the previous topics you should be able to create your custom indicator that will assist in reading charts and that you can use in your trading system. We will use the MQL5 (MetaQuotes Language) which is built into the MetaTrader 5 trading platform to write codes of indicators that will be created and EAs. If you do not know how to download and use them you can read the topic Writing MQL5 code in MetaEditor from a previous article, it can be helpful in that.

   Disclaimer: All information provided 'as is' only for educational purposes and is not prepared for trading purposes or advice. The information does not guarantee any kind of result. If you choose to use these materials on any of your trading accounts, you will do that at your own risk and you will be the only person responsible.

 Custom Indicator and Heiken Ashi definition

Disclaimer: All information provided 'as is' only for educational purposes and is not prepared for trading purposes or advice. The information does not guarantee any kind of result. If you choose to use these materials on any of your trading accounts, you will do that at your own risk and you will be the only person responsible.

 Custom Indicator and Heiken Ashi definition

 In this part, we will learn in more detail about the custom indicator and the Heiken Ashi indicator. As I mentioned in the introduction in the previous section, the custom indicator is the technical analysis tool that can be created by the user using the MQL5 programming language. It can be used in MetaTrader 5 to analyze and understand the market movement and can assist in taking informed investment decisions. There are many useful built-in technical indicators but sometimes we need to analyze and understand how the market is acting based on some additional and specific mathematical, statistical or technical concepts, and these concepts do not exist in the built-in indicator or there is no indicator can do the task. So, in such cases we have to create the indicator ourselves — and this is one of the features of the MetaTrader 5 platform as it helps us to create our own analytical or trading tools to meet our specific preferences and objectives.

 Let us consider the required steps to start creating your custom indicator:

 Open the MetaEditor IDE and choose the 'Indicators' folder in the Navigator



 Click the 'New' button to create a new program as shown in the below picture



 After that, the following window will be opened, in which you should choose the type of program to be created. Here we choose 'Custom Indicator'



 After clicking 'Next', the following window with the indicator details will be opened. Specify here the name for the custom indicator and then click 'Next'



 In the next windows, we proceed with determining more indicator details





 Once we complete setting the preferences and clicking 'Next' then 'Finish', the editor window will open, where we will write the code of the indicator.

 We will look at how to develop a custom indicator using Heiken Ashi as an example. So, we need to learn more about the Heiken Ashi technical indicator. It is a candlesticks-type charting method that can be used to present and analyze the market movement and it can be used in conjunction with other tools to get effective and better insights, based on which we can take informed trading decisions after finding good potential trading ideas and opportunities.

We will look at how to develop a custom indicator using Heiken Ashi as an example. So, we need to learn more about the Heiken Ashi technical indicator. It is a candlesticks-type charting method that can be used to present and analyze the market movement and it can be used in conjunction with other tools to get effective and better insights, based on which we can take informed trading decisions after finding good potential trading ideas and opportunities.

 The Heiken Ashi charts are similar to the normal candlestick technical charts but the calculation to plot these candles is different. Namely, there are two methods that differ. As we know, the normal candlesticks chart calculates prices based on actual open, high, low, and close prices in a specific period, but the Heiken Ashi takes into consideration the prices of the previous similar prices (open, high, low, and close) when calculating its candles.

 Here is how the relevant values for Heiken Ashi are calculated:




 Open = (open of previous candle + close of the previous candle) / 2
 Close = (open + close + high + low of the current candle) / 4
 High = the highest value from the high, open, or close of the current period
 Low = the lowest value from the low, open, or close of the current period

 Based on the calculation, the indicator constructs bull and bear candlesticks, and the colors of these candlesticks indicate the relevant direction of the market: if it is bullish or bearish. Below is an example that shows the traditional Japanese candlesticks and Heiken Ashi, so see the difference from a visual perspective.



 In the previous chart screenshot, the upper part shows the traditional candlesticks, while in the lower part there is the Heiken Ashi Indicator that appears as blue and red candlestick which define the market direction. The aim of this indicator as per its calculation is to filter and eliminate some of the noise in the market movement by smoothing data to avoid false signals.



 Simple Heiken Ashi Indicator

 In this part, we will create a simple Heiken Ashi indicator to be used in the MetaTrader 5. The indicator should continuously check prices (open, high, low, and close) and perform the mathematical computations to generate the haOpen, haHigh, haLow, and haClose values. Based on the calculations, the  indicator should plot the values on the chart as candlesticks in different colors: blue if the candlestick direction is candle and red if it is bearish. The candlesticks should be displayed in a separate window below the traditional chart as a sub-window.

 Let us view all the steps we need to complete to create this custom indicator.

 Determining the indicator settings by specifying additional parameters via #property and identifier values, as follows:

Let us view all the steps we need to complete to create this custom indicator.

 Determining the indicator settings by specifying additional parameters via #property and identifier values, as follows:


 (indicator_separate_window) to show the indicator in a separate window.
 (indicator_buffers) to determine the number of buffers for the indicator calculation.
 (indicator_plots) to determine the number of graphic series in the indicator. Graphic series are drawing styles that can be used when creating a custom indicator.
 (indicator_typeN) to determine the type of graphical plotting from the values of (ENUM_DRAW_TYPE), N is the number of graphic series that we determined in the last parameter and it starts from 1.
 (indicator_colorN) to determine the color of N,  N is also the number of graphic series that we determined before and it starts from 1.
 (indicator_widthN) to determine the thickness of N or graphic series also.
 (indicator_labelN) to set a label for N of the determined graphic series.


[CODE START]
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrBlue, clrRed
#property indicator_width1  2
#property indicator_label1  "Heiken Ashi Open;Heiken Ashi High;Heiken Ashi Low;Heiken Ashi Close"
[CODE END]
 Create five arrays for five buffers of the indicator (haOpen, haHigh, haLow, haClose, haColor) with double type.


[CODE START]
double haOpen[];
double haHigh[];
double haLow[];
double haClose[];
double haColor[];
[CODE END]
 Inside the OnInit(), this function is used to initialize a running indicator.


[CODE START]
int OnInit()
[CODE END]
 Sorting indicator buffers with a one-dimensional dynamic array of the double type by using the (SetIndexBuffer) function. Its parameters are:


 index: the number of the indicator buffer starting from 0 and this number must be less than the value that is declared in determined parameter of (indicator_buffers).
 buffer[]: the array that is declared in our custom indicator.
 data_type: the data type that we need to store in the indicator array.


[CODE START]
   SetIndexBuffer(0,haOpen,INDICATOR_DATA);
   SetIndexBuffer(1,haHigh,INDICATOR_DATA);
   SetIndexBuffer(2,haLow,INDICATOR_DATA);
   SetIndexBuffer(3,haClose,INDICATOR_DATA);
   SetIndexBuffer(4,haColor,INDICATOR_COLOR_INDEX);
[CODE END]
 Setting the value of the corresponding indicator property by using the (IndicatorSetInteger) function with the variant of calling in which we specify the property identifier. Its parameters are:

prop_id: the identifier of the property that can be one of the (ENUM_CUSTOMIND_PROPERTY_INTEGER), we will specify (INDICATOR_DIGITS).
 prop_value: the value of the property, we will specify (_Digits).


[CODE START]
IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
[CODE END]
 Setting the value of the corresponding string type property with the variant of calling in which we also specify the property identifier. Its parameters are:


 prop_id: the identifier of the property that can be one of the (ENUM_CUSTOMIND_PROPERTY_STRING), we will specify (INDICATOR_SHORTNAME) to use a short name for the indicator.
 prop_value: the value of the property, we will specify ("Simple Heiken Ashi").


[CODE START]
   IndicatorSetString(INDICATOR_SHORTNAME,"Simple Heiken Ashi");
[CODE END]
 Setting the value of the corresponding double type property of the corresponding indicator by using the (PlotIndexSetDouble) function. Its parameters are:


 plot_index: the index of the graphical plotting, we will specify 0.
 prop_id: one of the (ENUM_PLOT_PROPERTY_DOUBLE) values, it will be (PLOT_EMPTY_VALUE) for no drawing.
 prop_value: the value of the property.


[CODE START]
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
[CODE END]
 Then return (INIT_SUCCEEDED) as a part of the OnInit() function to terminate it by returning successful initialization.


[CODE START]
   return(INIT_SUCCEEDED);
[CODE END]
 Inside the OnCalculate function that is called in the indicator for processing price data changes with the type of calculations based on the current timeframe time series.


[CODE START]
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
[CODE END]
 Creating an integer 'start' variable, we will assign its value later:


[CODE START]
int start;
[CODE END]
 Using the 'if' statement to return indexes values (low, high, open, and close) and start value=1 if the prev_calculated is equal to 0 or return start value assigned to (prev_calculated-1):


[CODE START]
   if(prev_calculated==0)
     {
      haLow[0]=low[0];
      haHigh[0]=high[0];
      haOpen[0]=open[0];
      haClose[0]=close[0];
      start=1;
     }
   else
      start=prev_calculated-1;
[CODE END]
 Using the 'for' function for the main loop for the calculation, the 'for' operator consists of three expressions and executable operators.

 The three expressions will be:


 i=start: for the starting position.
 i<rates_total && !IsStopped(): for the conditions to finish the loop. IsStopped() checks the forced shutdown of the indicator.
 i++: add 1 to be the new i.

 The operations that we need to execute every time during the loop:

The three expressions will be:


 i=start: for the starting position.
 i<rates_total && !IsStopped(): for the conditions to finish the loop. IsStopped() checks the forced shutdown of the indicator.
 i++: add 1 to be the new i.

 The operations that we need to execute every time during the loop:

 Calculation for the double four variables


 haOpenVal: for the Heiken Ashi open value.
 haCloseVal: for the Heiken Ashi close value.
 haHighVal: for the Heiken Ashi high value.
 haLowVal: for the Heiken Ashi low value.

 Assigning calculated values in the previous step is the same as the following


 haLow[i]=haLowVal
 haHigh[i]=haHighVal
 haOpen[i]=haOpenVal
 haClose[i]=haCloseVal

 Checking if the open of Heiken Ashi value is lower than the close value, we need the indicator to draw a blue color candle or if not we need it to draw a red candlestick.


[CODE START]
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      double haOpenVal =(haOpen[i-1]+haClose[i-1])/2;
      double haCloseVal=(open[i]+high[i]+low[i]+close[i])/4;
      double haHighVal =MathMax(high[i],MathMax(haOpenVal,haCloseVal));
      double haLowVal  =MathMin(low[i],MathMin(haOpenVal,haCloseVal));

      haLow[i]=haLowVal;
      haHigh[i]=haHighVal;
      haOpen[i]=haOpenVal;
      haClose[i]=haCloseVal;

      //--- set candle color
      if(haOpenVal<haCloseVal)
         haColor[i]=0.0;
      else
         haColor[i]=1.0;
     }
[CODE END]
 Terminate the function by returning (rates_total) as a prev_calculated for the next call.


[CODE START]
return(rates_total);
[CODE END]
 Then we compile the code to make sure that there are no errors. The following is for the full code in one block:

//--- set candle color
      if(haOpenVal<haCloseVal)
         haColor[i]=0.0;
      else
         haColor[i]=1.0;
     }
[CODE END]
 Terminate the function by returning (rates_total) as a prev_calculated for the next call.


[CODE START]
return(rates_total);
[CODE END]
 Then we compile the code to make sure that there are no errors. The following is for the full code in one block:


[CODE START]
//+------------------------------------------------------------------+
//|                                             simpleHeikenAshi.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrBlue, clrRed
#property indicator_width1  2
#property indicator_label1  "Heiken Ashi Open;Heiken Ashi High;Heiken Ashi Low;Heiken Ashi Close"
double haOpen[];
double haHigh[];
double haLow[];
double haClose[];
double haColor[];
int OnInit()
  {
   SetIndexBuffer(0,haOpen,INDICATOR_DATA);
   SetIndexBuffer(1,haHigh,INDICATOR_DATA);
   SetIndexBuffer(2,haLow,INDICATOR_DATA);
   SetIndexBuffer(3,haClose,INDICATOR_DATA);
   SetIndexBuffer(4,haColor,INDICATOR_COLOR_INDEX);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"Simple Heiken Ashi");
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   return(INIT_SUCCEEDED);
  }
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int start;
   if(prev_calculated==0)
     {
      haLow[0]=low[0];
      haHigh[0]=high[0];
      haOpen[0]=open[0];
      haClose[0]=close[0];
      start=1;
     }
   else
      start=prev_calculated-1;
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      double haOpenVal =(haOpen[i-1]+haClose[i-1])/2;
      double haCloseVal=(open[i]+high[i]+low[i]+close[i])/4;
      double haHighVal =MathMax(high[i],MathMax(haOpenVal,haCloseVal));
      double haLowVal  =MathMin(low[i],MathMin(haOpenVal,haCloseVal));

haLow[i]=haLowVal;
      haHigh[i]=haHighVal;
      haOpen[i]=haOpenVal;
      haClose[i]=haCloseVal;
      if(haOpenVal<haCloseVal)
         haColor[i]=0.0;
      else
         haColor[i]=1.0;
     }
   return(rates_total);
  }
[CODE END]
 After compiling without errors, the indicator should become available in the 'Indicators' folder in the Navigator window, as in the following picture.



 Then double-click to execute it on the desired chart, the common window of the indicator information will appear after that:



 The Colors tab shows the default settings: blue color for up movement and red color down. If needed, you can edit these values to set your preferred colors. This tab looks as follows:



 After we press OK, the indicator will be attached to the chart and will appear as in the below picture:



 As you can see in the previous chart, we have the Simple Heiken Ashi indicator inserted into the chart in a separate sub-window. It has blue and red candlesticks as per the direction of these candles (bulls and bears). Now, we have a custom indicator that we have created in our MetaTrader 5 and we can use this custom indicator in any trading system. We will see in the upcoming topics how we can do that easily.



 EA based on Custom Heiken Ashi Indicator

 In this part, we will learn how to use any custom indicator in our trading system EA. We will create a simple Heiken Ashi System that can show us prices of the indicator (Open, High, Low, and Close) since we already know that they differ from actual prices as per the indicator's calculation.

 The way to do that is to choose to create a new Expert Advisor. So, below is the following full code:


[CODE START]
//+------------------------------------------------------------------+
//|                                             heikenAshiSystem.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
int heikenAshi;
int OnInit()
  {
   heikenAshi=iCustom(_Symbol,_Period,"My Files\\Heiken Ashi\\simpleHeikenAshi");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Print("Heiken Ashi System Removed");
  }
void OnTick()
  {
   double heikenAshiOpen[], heikenAshiHigh[], heikenAshiLow[], heikenAshiClose[];
   CopyBuffer(heikenAshi,0,0,1,heikenAshiOpen);
   CopyBuffer(heikenAshi,1,0,1,heikenAshiHigh);
   CopyBuffer(heikenAshi,2,0,1,heikenAshiLow);
   CopyBuffer(heikenAshi,3,0,1,heikenAshiClose);
   Comment("heikenAshiOpen ",DoubleToString(heikenAshiOpen[0],_Digits),
           "\n heikenAshiHigh ",DoubleToString(heikenAshiHigh[0],_Digits),
           "\n heikenAshiLow ",DoubleToString(heikenAshiLow[0],_Digits),
           "\n heikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
  }
[CODE END]
 Differences in this code:

 The type of the program is an Expert Advisor. So, the construction of this program will be different as it consists of three parts and they as follow:


 int OnInit(): it is used to initialize a running of the EA with its recommended type that returns an integer value.
 void OnDeinit: it is used to deinitialize a running of the EA that returns no value.
 void OnTick(): it is used to handle a new quote every tick and it returns no value.

 Outside the scope of the previous functions and before them we created an integer variable (heikenAshi)


[CODE START]
int heikenAshi;
[CODE END]
 Inside the scope of the OnInit(), we assigned the value of the iCustom function to the 'heikenAshi' variable. The iCustom function returns the handle of the custom indicator which will be the Simple Heiken Ashi here but you can use any custom indicator in your Indicators folder. Its parameters are:


 symbol: the symbol name, we used (_Symbol) for the current symbol.
 period: the time frame, we used the (_Period) for the current time frame.
 name: the name of the custom indicator with its path in the Indicators folder of your MetaTrader 5 and here we used "My Files\\Heiken Ashi\\simpleHeikenAshi".

 Then we terminated the function by returning (INIT_SUCCEEDED) for successful initialization.


[CODE START]
int OnInit()
  {
   heikenAshi=iCustom(_Symbol,_Period,"My Files\\Heiken Ashi\\simpleHeikenAshi");
   return(INIT_SUCCEEDED);
  }
[CODE END]
 Inside the scope of the OnDeinit() function, we used the print function to inform that the EA is removed in the expert


[CODE START]

void OnDeinit(const int reason)
  {
   Print("Heiken Ashi System Removed");
  }
[CODE END]
 Inside the scope of the OnTick() function, we used the following to complete our code:

 Creating four double-type variables for the Heiken Ashi prices (Open, High, Low, and Close)


[CODE START]
   double heikenAshiOpen[], heikenAshiHigh[], heikenAshiLow[], heikenAshiClose[];
[CODE END]
 Getting data of buffers of the custom indicator by using the CopyBuffer function. Its parameters are:


 indicator_handle: the indicator handle, we used (heikenAshi).
 buffer_num: the indicator buffer number, we used (0 for open, 1 for high, 2 for low, and 3 for close).
 start_pos: the first element position to copy, we used 0 for the current element.
 count: the amount of data to copy, we used 1 and we do not need here more than that.
 buffer[]: the array to copy, we used (heikenAshiOpen for Open, heikenAshiHigh for high, heikenAshiLow for low, and heikenAshiClose for close).

 Getting a comment on the chart with the current Heiken Ashi prices (Open, High, Low, and Close) by using the comment function:


[CODE START]
   Comment("heikenAshiOpen ",DoubleToString(heikenAshiOpen[0],_Digits),
           "\n heikenAshiHigh ",DoubleToString(heikenAshiHigh[0],_Digits),
           "\n heikenAshiLow ",DoubleToString(heikenAshiLow[0],_Digits),
           "\n heikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
[CODE END]
 After compiling this code without any errors and executing it we can find the EA attached to the chart. We can receive the signal the same in the following testing example:



 As we can see in the previous chart we have the indicator prices appear as a comment in the top left corner of the chart.



 Heiken Ashi - EMA System

 In this topic, we will combine another technical tool to see if the result will be better or not. The idea that we need to apply is to filter signals of the custom indicator by using the exponential moving average with prices. There are many methods to do that, we can create another Custom indicator for the EMA if we want to add more features to the EMA then we can use it in the EA as iCustom the same as we did to take your desired signals. We can also create a smoothed indicator by smoothing the indicator's values and then taking our signals. We can use the built-in iMA function in our EA to get our signals from it and we will use this method here for the sake of simplicity.

What we need to do is to let the EA continuously check values of the current 2 EMA (Fast and Slow) and Previous fast EMA and Heiken Ash close to determine the positions of every value. If the previous heikenAshiClose is greater than the previous fastEMAarray and the current fastEMA is greater than the current slowEMA value, the EA should return a buy signal and these values as a comment on the chart. If the previous heikenAshiClose is lower than the previous fastEMAarray and the current fastEMA is lower than the current slowEMA value, the EA should return a sell signal and these values as a comment on the chart.

 The following is the full code to create this EA:


[CODE START]
//+------------------------------------------------------------------+
//|                                          heikenAsh-EMASystem.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
input int fastEMASmoothing=9; // Fast EMA Period
input int slowEMASmoothing=18; // Slow EMA Period
int heikenAshi;
double fastEMAarray[], slowEMAarray[];
int OnInit()
  {
   heikenAshi=iCustom(_Symbol,_Period,"My Files\\Heiken Ashi\\simpleHeikenAshi");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   Print("Heiken Ashi-EMA System Removed");
  }

void OnTick()
  {
   double heikenAshiOpen[], heikenAshiHigh[], heikenAshiLow[], heikenAshiClose[];
   CopyBuffer(heikenAshi,0,0,3,heikenAshiOpen);
   CopyBuffer(heikenAshi,1,0,3,heikenAshiHigh);
   CopyBuffer(heikenAshi,2,0,3,heikenAshiLow);
   CopyBuffer(heikenAshi,3,0,3,heikenAshiClose);
   int fastEMA = iMA(_Symbol,_Period,fastEMASmoothing,0,MODE_SMA,PRICE_CLOSE);
   int slowEMA = iMA(_Symbol,_Period,slowEMASmoothing,0,MODE_SMA,PRICE_CLOSE);
   ArraySetAsSeries(fastEMAarray,true);
   ArraySetAsSeries(slowEMAarray,true);
   CopyBuffer(fastEMA,0,0,3,fastEMAarray);
   CopyBuffer(slowEMA,0,0,3,slowEMAarray);
   if(heikenAshiClose[1]>fastEMAarray[1])
     {
      if(fastEMAarray[0]>slowEMAarray[0])
        {
         Comment("Buy Signal",
                 "\nfastEMA ",DoubleToString(fastEMAarray[0],_Digits),
                 "\nslowEMA ",DoubleToString(slowEMAarray[0],_Digits),
                 "\nprevFastEMA ",DoubleToString(fastEMAarray[1],_Digits),
                 "\nprevHeikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
        }
     }
   if(heikenAshiClose[1]<fastEMAarray[1])
     {
      if(fastEMAarray[0]<slowEMAarray[0])
        {
         Comment("Sell Signal",
                 "\nfastEMA ",DoubleToString(fastEMAarray[0],_Digits),
                 "\nslowEMA ",DoubleToString(slowEMAarray[0],_Digits),
                 "\nprevFastEMA ",DoubleToString(fastEMAarray[1],_Digits),
                 "\nheikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
        }
     }
  }
[CODE END]
 Differences in this code are:

 Creating user inputs to set the fast EMA period and slow EMA period as per user preferences.


[CODE START]
input int fastEMASmoothing=9; // Fast EMA Period
input int slowEMASmoothing=18; // Slow EMA Period
[CODE END]
 Creating two arrays for fastEMA, and slowEMA.


[CODE START]
double fastEMAarray[], slowEMAarray[];
[CODE END]
 Setting the amount of data to copy to 3 in the CopyBuffer to get the previous closing values of the Heiken Ashi indicator


[CODE START]
   CopyBuffer(heikenAshi,0,0,3,heikenAshiOpen);
   CopyBuffer(heikenAshi,1,0,3,heikenAshiHigh);
   CopyBuffer(heikenAshi,2,0,3,heikenAshiLow);
   CopyBuffer(heikenAshi,3,0,3,heikenAshiClose);
[CODE END]
 Defining the fast and slow EMA by using the built-in function of iMA that returns the handle of the moving average indicator. Its parameters are:

[CODE START]
   CopyBuffer(heikenAshi,0,0,3,heikenAshiOpen);
   CopyBuffer(heikenAshi,1,0,3,heikenAshiHigh);
   CopyBuffer(heikenAshi,2,0,3,heikenAshiLow);
   CopyBuffer(heikenAshi,3,0,3,heikenAshiClose);
[CODE END]
 Defining the fast and slow EMA by using the built-in function of iMA that returns the handle of the moving average indicator. Its parameters are:


 symbol: the symbol name, we used (_Symbol) for the current one.
 period: the time, we used (_Period) for the current one.
 ma_period: the period that needed to smooth the average, we used (fastEMASmoothing and slowEMASmoothing) inputs.
 ma_shift: the shift of the indicator, we used 0.
 ma_method: the type of the moving average, we used MODE_SMA for the simple moving average.
 applied_price: the needed price type to be used in the calculation, we used the PRICE_CLOSE.


[CODE START]
   int fastEMA = iMA(_Symbol,_Period,fastEMASmoothing,0,MODE_SMA,PRICE_CLOSE);
   int slowEMA = iMA(_Symbol,_Period,slowEMASmoothing,0,MODE_SMA,PRICE_CLOSE);
[CODE END]
 Using the ArraySetAsSeries function to set the AS_SERIES flag. Its parameters are:


 array[]: the array, we used (fastEMAarray and slowEMA).
 flag: the array indexing direction, we used true.


[CODE START]
   ArraySetAsSeries(fastEMAarray,true);
   ArraySetAsSeries(slowEMAarray,true);
[CODE END]
 Getting the data of the buffer of the EMA indicator by using the CopyBuffer function.


[CODE START]
   CopyBuffer(fastEMA,0,0,3,fastEMAarray);
   CopyBuffer(slowEMA,0,0,3,slowEMAarray);
[CODE END]
 Conditions to return signals by using the 'if' statement:

 In case of buy signal

 If the previous heikenAshiClose > the previous fastEMAarray and the current fastEMAarray > the current slowEMAarray, the EA must return a buy signal and the following values:


 fastEMA
 slowEMA
 prevFastEMA
 prevHeikenAshiClose


[CODE START]
   if(heikenAshiClose[1]>fastEMAarray[1])
     {
      if(fastEMAarray[0]>slowEMAarray[0])
        {
         Comment("Buy Signal",
                 "\nfastEMA ",DoubleToString(fastEMAarray[0],_Digits),
                 "\nslowEMA ",DoubleToString(slowEMAarray[0],_Digits),
                 "\nprevFastEMA ",DoubleToString(fastEMAarray[1],_Digits),
                 "\nprevHeikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
        }
[CODE END]
 In case of sell signal

 If the previous heikenAshiClose < the previous fastEMAarray and the current fastEMAarray < the current slowEMAarray, the EA must return a sell signal and price values of:

If the previous heikenAshiClose < the previous fastEMAarray and the current fastEMAarray < the current slowEMAarray, the EA must return a sell signal and price values of:


 fastEMA
 slowEMA
 prevFastEMA
 prevHeikenAshiClose


[CODE START]
   if(heikenAshiClose[1]<fastEMAarray[1])
     {
      if(fastEMAarray[0]<slowEMAarray[0])
        {
         Comment("Sell Signal",
                 "\nfastEMA ",DoubleToString(fastEMAarray[0],_Digits),
                 "\nslowEMA ",DoubleToString(slowEMAarray[0],_Digits),
                 "\nprevFastEMA ",DoubleToString(fastEMAarray[1],_Digits),
                 "\nheikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
        }
     }
[CODE END]
 After compiling this code with errors and executing it we can get our signals as shown in the following testing examples.

 In the case of buy signal:



 As we can see in the previous chart we have the following signal as a comment in the top left corner:




 Buy Signal
 fastEMA
 prevFastEMA
 prevHeikenAshiClose

 In the case of sell signal:



 We have the following values as a signal on the chart:


 Sell Signal
 fastEMA
 prevFastEMA
 prevHeikenAshiClose

 Conclusion

 If you have understood everything that we discussed in this article, it is supposed that you are able to create your own Custom Heiken Ashi indicator or even add some more features as per your preferences. This will be very useful to read charts and take effective decisions based on your understanding. In addition to that you will be able to use this created custom indicator in your trading systems as Expert Advisors because we mentioned and used it in two trading systems as examples.


 Heiken Ashi System
 Heiken Ashi-EMA System

 I hope that you found this article useful for you and you got good insights about the topic of it or any related topic. I hope also that you tried to apply what you learned in the article as it will be very useful in your programming learning journey as practicing is a very important factor in effective education processes. Please note that you must test anything you learned in this article or in other resources before using it in your real account as it may be harmful if it is not suitable for you. The main objective of this article is educational only, so you have to be careful.

 If you found this article useful and you want to read more articles you can read more for me through my other authored articles. I hope you will find them useful too.



  Attached files |


      Download ZIP




      simpleHeikenAshi.mq5
      (2.49 KB)



      heikenAshiSystem.mq5
      (1.3 KB)



      heikenAsh-EMASystem.mq5
      (2.37 KB)





    Warning: All rights to these materials are reserved by MetaQuotes Ltd. Copying or reprinting of these materials in whole or in part is prohibited.

Attached files |


      Download ZIP




      simpleHeikenAshi.mq5
      (2.49 KB)



      heikenAshiSystem.mq5
      (1.3 KB)



      heikenAsh-EMASystem.mq5
      (2.37 KB)





    Warning: All rights to these materials are reserved by MetaQuotes Ltd. Copying or reprinting of these materials in whole or in part is prohibited.

      This article was written by a user of the site and reflects their personal views. MetaQuotes Ltd is not responsible for the accuracy of the information presented, nor for any consequences resulting from the use of the solutions, strategies or recommendations described.




    Other articles by this author



          How to build and optimize a cycle-based trading system (Detrended Price Oscillator - DPO)



          How to build and optimize a volume-based trading system (Chaikin Money Flow - CMF)



          MQL5 Integration: Python



          How to build and optimize a volatility-based trading system (Chaikin Volatility - CHV)



          Advanced Variables and Data Types in MQL5



          Building and testing Keltner Channel trading systems



          Building and testing Aroon Trading Systems

// CONTEXT: Series: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles, Part: N/A, Title: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles | FILE: simpleHeikenAshi.mq5
//+------------------------------------------------------------------+
//|                                             simpleHeikenAshi.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 5
#property indicator_plots   1
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrBlue, clrRed
#property indicator_width1  2
#property indicator_label1  "Heiken Ashi Open;Heiken Ashi High;Heiken Ashi Low;Heiken Ashi Close"
double haOpen[];
double haHigh[];
double haLow[];
double haClose[];
double haColor[];
int OnInit()
  {
   SetIndexBuffer(0,haOpen,INDICATOR_DATA);
   SetIndexBuffer(1,haHigh,INDICATOR_DATA);
   SetIndexBuffer(2,haLow,INDICATOR_DATA);
   SetIndexBuffer(3,haClose,INDICATOR_DATA);
   SetIndexBuffer(4,haColor,INDICATOR_COLOR_INDEX);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"Simple Heiken Ashi");
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,0.0);
   return(INIT_SUCCEEDED);
  }
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   int start;
   if(prev_calculated==0)
     {
      haLow[0]=low[0];
      haHigh[0]=high[0];
      haOpen[0]=open[0];
      haClose[0]=close[0];
      start=1;
     }
   else
      start=prev_calculated-1;
   for(int i=start; i<rates_total && !IsStopped(); i++)
     {
      double haOpenVal =(haOpen[i-1]+haClose[i-1])/2;
      double haCloseVal=(open[i]+high[i]+low[i]+close[i])/4;
      double haHighVal =MathMax(high[i],MathMax(haOpenVal,haCloseVal));
      double haLowVal  =MathMin(low[i],MathMin(haOpenVal,haCloseVal));

      haLow[i]=haLowVal;
      haHigh[i]=haHighVal;
      haOpen[i]=haOpenVal;
      haClose[i]=haCloseVal;
      if(haOpenVal<haCloseVal)
         haColor[i]=0.0;
      else
         haColor[i]=1.0;
     }
   return(rates_total);
  }

// CONTEXT: Series: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles, Part: N/A, Title: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles | FILE: heikenAshiSystem.mq5
//+------------------------------------------------------------------+
//|                                             heikenAshiSystem.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
int heikenAshi;
int OnInit()
  {
   heikenAshi=iCustom(_Symbol,_Period,"My Files\\Heiken Ashi\\simpleHeikenAshi");
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   Print("Heiken Ashi System Removed");
  }
void OnTick()
  {
   double heikenAshiOpen[], heikenAshiHigh[], heikenAshiLow[], heikenAshiClose[];
   CopyBuffer(heikenAshi,0,0,1,heikenAshiOpen);
   CopyBuffer(heikenAshi,1,0,1,heikenAshiHigh);
   CopyBuffer(heikenAshi,2,0,1,heikenAshiLow);
   CopyBuffer(heikenAshi,3,0,1,heikenAshiClose);
   Comment("heikenAshiOpen ",DoubleToString(heikenAshiOpen[0],_Digits),
           "\n heikenAshiHigh ",DoubleToString(heikenAshiHigh[0],_Digits),
           "\n heikenAshiLow ",DoubleToString(heikenAshiLow[0],_Digits),
           "\n heikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
  }

// CONTEXT: Series: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles, Part: N/A, Title: How to create a custom indicator (Heiken Ashi) using MQL5 - MQL5 Articles | FILE: heikenAsh-EMASystem.mq5
//+------------------------------------------------------------------+
//|                                          heikenAsh-EMASystem.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
input int fastEMASmoothing=9; // Fast EMA Period
input int slowEMASmoothing=18; // Slow EMA Period
int heikenAshi;
double fastEMAarray[], slowEMAarray[];
int OnInit()
  {
   heikenAshi=iCustom(_Symbol,_Period,"My Files\\Heiken Ashi\\simpleHeikenAshi");
   return(INIT_SUCCEEDED);
  }
void OnDeinit(const int reason)
  {
   Print("Heiken Ashi-EMA System Removed");
  }
void OnTick()
  {
   double heikenAshiOpen[], heikenAshiHigh[], heikenAshiLow[], heikenAshiClose[];
   CopyBuffer(heikenAshi,0,0,3,heikenAshiOpen);
   CopyBuffer(heikenAshi,1,0,3,heikenAshiHigh);
   CopyBuffer(heikenAshi,2,0,3,heikenAshiLow);
   CopyBuffer(heikenAshi,3,0,3,heikenAshiClose);
   int fastEMA = iMA(_Symbol,_Period,fastEMASmoothing,0,MODE_SMA,PRICE_CLOSE);
   int slowEMA = iMA(_Symbol,_Period,slowEMASmoothing,0,MODE_SMA,PRICE_CLOSE);
   ArraySetAsSeries(fastEMAarray,true);
   ArraySetAsSeries(slowEMAarray,true);
   CopyBuffer(fastEMA,0,0,3,fastEMAarray);
   CopyBuffer(slowEMA,0,0,3,slowEMAarray);
   if(heikenAshiClose[1]>fastEMAarray[1])
     {
      if(fastEMAarray[0]>slowEMAarray[0])
        {
         Comment("Buy Signal",
                 "\nfastEMA ",DoubleToString(fastEMAarray[0],_Digits),
                 "\nslowEMA ",DoubleToString(slowEMAarray[0],_Digits),
                 "\nprevFastEMA ",DoubleToString(fastEMAarray[1],_Digits),
                 "\nprevHeikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
        }
     }
   if(heikenAshiClose[1]<fastEMAarray[1])
     {
      if(fastEMAarray[0]<slowEMAarray[0])
        {
         Comment("Sell Signal",
                 "\nfastEMA ",DoubleToString(fastEMAarray[0],_Digits),
                 "\nslowEMA ",DoubleToString(slowEMAarray[0],_Digits),
                 "\nprevFastEMA ",DoubleToString(fastEMAarray[1],_Digits),
                 "\nheikenAshiClose ",DoubleToString(heikenAshiClose[0],_Digits));
        }
     }
  }
```

### 💻 Snippet 14 (Source: article_8508.html)
```
// CONTEXT: Series: Timeseries in DoEasy library, Part: 54, Title: Timeseries in DoEasy library (part 54): Descendant classes of abstract base indicator - MQL5 Articles

Table of contents


 Concept
 Improving library classes
 Indicator object classes
 Indicator object collection

  Testing
 What's next?



 Concept

 In the previous article creation of base abstract indicator object was considered. Today, create its descendant objects in which information about a specific indicator object created will be specified. Place all those objects to indicator collection, from which getting data and properties of each created indicator will be possible.
 Concept of descendant objects fully corresponds to the concept of object construction in the library and to their interconnections. Whereas, indicator collection will allow to quickly add event functionality to all indicator objects in furtherance. This will allow to easily set indicator events tracked and to use these events in our programs.


 Improving library classes

 As usual, start with adding necessary text messages of the library.

 In file \MQL5\Include\DoEasy\Data.mqh add new message indices:


[CODE START]
//--- CIndicatorDE
   MSG_LIB_TEXT_IND_TEXT_STATUS,                      // Indicator status
   MSG_LIB_TEXT_IND_TEXT_STATUS_STANDART,             // Standard indicator
   MSG_LIB_TEXT_IND_TEXT_STATUS_CUSTOM,               // Custom indicator
  
   MSG_LIB_TEXT_IND_TEXT_TYPE,                        // Indicator type
   MSG_LIB_TEXT_IND_TEXT_TIMEFRAME,                   // Indicator timeframe
   MSG_LIB_TEXT_IND_TEXT_HANDLE,                      // Indicator handle

   MSG_LIB_TEXT_IND_TEXT_GROUP,                       // Indicator group
   MSG_LIB_TEXT_IND_TEXT_GROUP_TREND,                 // Trend indicator
   MSG_LIB_TEXT_IND_TEXT_GROUP_OSCILLATOR,            // Oscillator
   MSG_LIB_TEXT_IND_TEXT_GROUP_VOLUMES,               // Volumes
   MSG_LIB_TEXT_IND_TEXT_GROUP_ARROWS,                // Arrow indicator
  
   MSG_LIB_TEXT_IND_TEXT_EMPTY_VALUE,                 // Empty value for plotting where nothing will be drawn
   MSG_LIB_TEXT_IND_TEXT_SYMBOL,                      // Indicator symbol
   MSG_LIB_TEXT_IND_TEXT_NAME,                        // Indicator name
   MSG_LIB_TEXT_IND_TEXT_SHORTNAME,                   // Indicator short name
  
//--- CIndicatorsCollection
   MSG_LIB_SYS_FAILED_ADD_IND_TO_LIST,                // Error. Failed to add indicator object to list
  
  };
//+------------------------------------------------------------------+

[CODE END]
 and next, add new messages corresponding to the newly added indices:

[CODE END]
 and next, add new messages corresponding to the newly added indices:


[CODE START]
   {"Indicator status"},
   {"Standard indicator"},
   {"Custom indicator"},
   {"Indicator type"},
   {"Indicator timeframe"},
   {"Indicator handle"},
   {"Indicator group"},
   {"Trend indicator"},
   {"Solid lineOscillator"},
   {"Volumes"},
   {"Arrow indicator"},
   {,"Empty value for plotting, for which there is no drawing"},
   {"Indicator symbol"},
   {"Indicator name"},
   {"Indicator shortname"},
  
   {"Error. Failed to add indicator object to list"},
  
  };
//+---------------------------------------------------------------------+

[CODE END]
 During creation of abstract indicator object class in the previous article we didn’t add one of object’s integer properties - standard indicator type. This type will correspond to enumeration types ENUM_INDICATOR and it will be required to search a specific indicator.
 If we want to find all MACD indicators which are stored in collection, first, we must get the list of all MACD indicators located in collection. To do this, we must sort the full list of indicator collection by type IND_MACD. And then, in the resulted list containing only IND_MACD, the choice by other target properties will be made.

 Add a new property of indicator object to file \MQL5\Include\DoEasy\Defines.mqh:



[CODE START]
//+------------------------------------------------------------------+
//| Indicator integer properties                                     |
//+------------------------------------------------------------------+
enum ENUM_INDICATOR_PROP_INTEGER
  {
   INDICATOR_PROP_STATUS = 0,                               // Indicator status (from enumeration  ENUM_INDICATOR_STATUS)
   INDICATOR_PROP_TYPE,                                     // Indicator type (from enumeration ENUM_INDICATOR)
   INDICATOR_PROP_TIMEFRAME,                                // Indicator timeframe
   INDICATOR_PROP_HANDLE,                                   // Indicator handle
   INDICATOR_PROP_GROUP,                                    // Indicator group
  };
#define INDICATOR_PROP_INTEGER_TOTAL (5)                    // Total number of indicator integer properties
#define INDICATOR_PROP_INTEGER_SKIP  (0)                    // Number of indicator properties not used in sorting
//+------------------------------------------------------------------+

[CODE END]
 and increase the total number of integer properties from 4 to 5.

 When adding a new property for the object we must set the ability to search and sort objects by this property.
 Add a new sorting criterion for enumeration:

[CODE END]
 and increase the total number of integer properties from 4 to 5.

 When adding a new property for the object we must set the ability to search and sort objects by this property.
 Add a new sorting criterion for enumeration:


[CODE START]
//+------------------------------------------------------------------+
//| Possible indicator sorting criteria                              |
//+------------------------------------------------------------------+
#define FIRST_INDICATOR_DBL_PROP          (INDICATOR_PROP_INTEGER_TOTAL-INDICATOR_PROP_INTEGER_SKIP)
#define FIRST_INDICATOR_STR_PROP          (INDICATOR_PROP_INTEGER_TOTAL-INDICATOR_PROP_INTEGER_SKIP+INDICATOR_PROP_DOUBLE_TOTAL-INDICATOR_PROP_DOUBLE_SKIP)
enum ENUM_SORT_INDICATOR_MODE
  {
//--- Sort by integer properties
   SORT_BY_INDICATOR_INDEX_STATUS = 0,                      // Sort by indicator status
   SORT_BY_INDICATOR_TYPE,                                  // Sort by indicator type
   SORT_BY_INDICATOR_TIMEFRAME,                             // Sort by indicator timeframe
   SORT_BY_INDICATOR_HANDLE,                                // Sort by indicator handle
   SORT_BY_INDICATOR_GROUP,                                 // Sort by indicator group
//--- Sort by real properties
   SORT_BY_INDICATOR_EMPTY_VALUE = FIRST_INDICATOR_DBL_PROP,// Sort by the empty value for plotting where nothing will be drawn
//--- Sort by string properties
   SORT_BY_INDICATOR_SYMBOL = FIRST_INDICATOR_STR_PROP,     // Sort by indicator symbol
   SORT_BY_INDICATOR_NAME,                                  // Sort by indicator name
   SORT_BY_INDICATOR_SHORTNAME,                             // Sort by indicator short name
  };
//+------------------------------------------------------------------+

[CODE END]
 Slightly improve the abstract indicator object class in \MQL5\Include\DoEasy\Objects\Indicators\IndicatorDE.mqh.

 Move the array of indicator parameters structures from the private class section to protected one (this array now will become available for descendant classes), and in private section declare a variable to store indicator type description:



[CODE START]
//+------------------------------------------------------------------+
//| Abstract indicator class                                         |
//+------------------------------------------------------------------+

class CIndicatorDE : public CBaseObj
  {
protected:
   MqlParam          m_mql_param[];                                              // Array of indicator parameters
private:
   long              m_long_prop[INDICATOR_PROP_INTEGER_TOTAL];                  // Integer properties
   double            m_double_prop[INDICATOR_PROP_DOUBLE_TOTAL];                 // Real properties
   string            m_string_prop[INDICATOR_PROP_STRING_TOTAL];                 // String properties
   string            m_ind_type;                                                 // Indicator type description
  

[CODE END]
 To public class section add two methods — for return of indicator type and for return of indicator type description:



[CODE START]
public:  
//--- Default constructor
                     CIndicatorDE(void){;}
//--- Destructor
                    ~CIndicatorDE(void);
                    
//--- Set buffer's (1) integer, (2) real and (3) string property
   void              SetProperty(ENUM_INDICATOR_PROP_INTEGER property,long value)   { this.m_long_prop[property]=value;                                        }
   void              SetProperty(ENUM_INDICATOR_PROP_DOUBLE property,double value)  { this.m_double_prop[this.IndexProp(property)]=value;                      }
   void              SetProperty(ENUM_INDICATOR_PROP_STRING property,string value)  { this.m_string_prop[this.IndexProp(property)]=value;                      }
//--- Return (1) integer, (2) real and (3) string buffer property from the properties array
   long              GetProperty(ENUM_INDICATOR_PROP_INTEGER property)        const { return this.m_long_prop[property];                                       }
   double            GetProperty(ENUM_INDICATOR_PROP_DOUBLE property)         const { return this.m_double_prop[this.IndexProp(property)];                     }
   string            GetProperty(ENUM_INDICATOR_PROP_STRING property)         const { return this.m_string_prop[this.IndexProp(property)];                     }
//--- Return description of buffer's (1) integer, (2) real and (3) string property
   string            GetPropertyDescription(ENUM_INDICATOR_PROP_INTEGER property);
   string            GetPropertyDescription(ENUM_INDICATOR_PROP_DOUBLE property);
   string            GetPropertyDescription(ENUM_INDICATOR_PROP_STRING property);
//--- Return the flag of the buffer supporting the property
   virtual bool      SupportProperty(ENUM_INDICATOR_PROP_INTEGER property)          { return true;       }
   virtual bool      SupportProperty(ENUM_INDICATOR_PROP_DOUBLE property)           { return true;       }
   virtual bool      SupportProperty(ENUM_INDICATOR_PROP_STRING property)           { return true;       }

//--- Compare CIndicatorDE objects by all possible properties (for sorting the lists by a specified indicator object property)
   virtual int       Compare(const CObject *node,const int mode=0) const;
//--- Compare CIndicatorDE objects by all properties (to search for equal indicator objects)
   bool              IsEqual(CIndicatorDE* compared_obj) const;
                    
//--- Set indicator’s (1) group, (2) empty value of buffers, (3) name, (4) short name
   void              SetGroup(const ENUM_INDICATOR_GROUP group)      { this.SetProperty(INDICATOR_PROP_GROUP,group);                         }
   void              SetEmptyValue(const double value)               { this.SetProperty(INDICATOR_PROP_EMPTY_VALUE,value);                   }
   void              SetName(const string name)                      { this.SetProperty(INDICATOR_PROP_NAME,name);                           }
   void              SetShortName(const string shortname)            { this.SetProperty(INDICATOR_PROP_SHORTNAME,shortname);                 }
  
//--- Return indicator’s (1) status, (2) group, (3) timeframe, (4) handle, (5) empty value of buffers, (6) name, (7) short name, (8) symbol, (9) type
   ENUM_INDICATOR_STATUS Status(void)                          const { return (ENUM_INDICATOR_STATUS)this.GetProperty(INDICATOR_PROP_STATUS);}
   ENUM_INDICATOR_GROUP  Group(void)                           const { return (ENUM_INDICATOR_GROUP)this.GetProperty(INDICATOR_PROP_GROUP);  }
   ENUM_TIMEFRAMES   Timeframe(void)                           const { return (ENUM_TIMEFRAMES)this.GetProperty(INDICATOR_PROP_TIMEFRAME);   }
   ENUM_INDICATOR    TypeIndicator(void)                       const { return (ENUM_INDICATOR)this.GetProperty(INDICATOR_PROP_TYPE);         }
   int               Handle(void)                              const { return (int)this.GetProperty(INDICATOR_PROP_HANDLE);                  }
   double            EmptyValue(void)                          const { return this.GetProperty(INDICATOR_PROP_EMPTY_VALUE);                  }
   string            Name(void)                                const { return this.GetProperty(INDICATOR_PROP_NAME);                         }
   string            ShortName(void)                           const { return this.GetProperty(INDICATOR_PROP_SHORTNAME);                    }
   string            Symbol(void)                              const { return this.GetProperty(INDICATOR_PROP_SYMBOL);                       }
  
//--- Return description of indicator’s (1) type, (2) status, (3) group, (4) timeframe, (5) empty value
   string            GetTypeDescription(void)                  const { return m_ind_type;                                                    }
   string            GetStatusDescription(void)                const;
   string            GetGroupDescription(void)                 const;
   string            GetTimeframeDescription(void)             const;

//--- Return description of indicator’s (1) type, (2) status, (3) group, (4) timeframe, (5) empty value
   string            GetTypeDescription(void)                  const { return m_ind_type;                                                    }
   string            GetStatusDescription(void)                const;
   string            GetGroupDescription(void)                 const;
   string            GetTimeframeDescription(void)             const;
   string            GetEmptyValueDescription(void)            const;
  
//--- Display the description of indicator object properties in the journal (full_prop=true - all properties, false - supported ones only)
   void              Print(const bool full_prop=false);
//--- Display a short description of indicator object in the journal (implementation in the descendants)
   virtual void      PrintShort(void) {;}

};
//+------------------------------------------------------------------+

[CODE END]
 In closed parametric constructor retrieve substring from indicator type input to leave indicator name only (for example, only MACD remains from IND_MACD which will be indicator type description) and write indicator type in object properties:



[CODE START]
//+------------------------------------------------------------------+
//| Closed parametric constructor                                    |
//+------------------------------------------------------------------+
CIndicatorDE::CIndicatorDE(ENUM_INDICATOR ind_type,
                           string symbol,
                           ENUM_TIMEFRAMES timeframe,
                           ENUM_INDICATOR_STATUS status,
                           ENUM_INDICATOR_GROUP group,
                           string name,
                           string shortname,
                           MqlParam &mql_params[])
  {
//--- Set collection ID to the object
   this.m_type=COLLECTION_INDICATORS_ID;
//--- Write description of indicator type
   this.m_ind_type=::StringSubstr(::EnumToString(ind_type),4);
//--- If parameter array size passed to constructor is more than zero
//--- fill in the array of object parameters with data from the array passed to constructor
   int count=::ArrayResize(m_mql_param,::ArraySize(mql_params));
   for(int i=0;i<count;i++)
     {
      this.m_mql_param[i].type=mql_params[i].type;
      this.m_mql_param[i].double_value=mql_params[i].double_value;
      this.m_mql_param[i].integer_value=mql_params[i].integer_value;
      this.m_mql_param[i].string_value=mql_params[i].string_value;
     }
//--- Create indicator handle
   int handle=::IndicatorCreate(symbol,timeframe,ind_type,count,this.m_mql_param);
  
//--- Save integer properties
   this.m_long_prop[INDICATOR_PROP_STATUS]                     = status;
   this.m_long_prop[INDICATOR_PROP_TYPE]                       = ind_type;
   this.m_long_prop[INDICATOR_PROP_GROUP]                      = group;
   this.m_long_prop[INDICATOR_PROP_TIMEFRAME]                  = timeframe;
   this.m_long_prop[INDICATOR_PROP_HANDLE]                     = handle;
  
//--- Save real properties
   this.m_double_prop[this.IndexProp(INDICATOR_PROP_EMPTY_VALUE)]=EMPTY_VALUE;
//--- Save string properties
   this.m_string_prop[this.IndexProp(INDICATOR_PROP_SYMBOL)]   = (symbol==NULL || symbol=="" ? ::Symbol() : symbol);
   this.m_string_prop[this.IndexProp(INDICATOR_PROP_NAME)]     = name;
   this.m_string_prop[this.IndexProp(INDICATOR_PROP_SHORTNAME)]= shortname;
  }
//+------------------------------------------------------------------+

[CODE END]
 Add code block for return of indicator type description in method returning description of indicator integer property:

[CODE END]
 Add code block for return of indicator type description in method returning description of indicator integer property:



[CODE START]
//+------------------------------------------------------------------+
//| Return description of indicator's integer property               |
//+------------------------------------------------------------------+
string CIndicatorDE::GetPropertyDescription(ENUM_INDICATOR_PROP_INTEGER property)
  {
   return
     (
      property==INDICATOR_PROP_STATUS        ?  CMessage::Text(MSG_LIB_TEXT_IND_TEXT_STATUS)+
         (!this.SupportProperty(property) ?  ": "+CMessage::Text(MSG_LIB_PROP_NOT_SUPPORTED) :
          ": "+this.GetStatusDescription()
         )  :
      property==INDICATOR_PROP_TYPE        ?  CMessage::Text(MSG_LIB_TEXT_IND_TEXT_TYPE)+
         (!this.SupportProperty(property) ?  ": "+CMessage::Text(MSG_LIB_PROP_NOT_SUPPORTED) :
          ": "+this.GetTypeDescription()
         )  :
      property==INDICATOR_PROP_GROUP          ?  CMessage::Text(MSG_LIB_TEXT_IND_TEXT_GROUP)+
         (!this.SupportProperty(property) ?  ": "+CMessage::Text(MSG_LIB_PROP_NOT_SUPPORTED) :
          ": "+this.GetGroupDescription()
         )  :
      property==INDICATOR_PROP_TIMEFRAME     ?  CMessage::Text(MSG_LIB_TEXT_IND_TEXT_TIMEFRAME)+
         (!this.SupportProperty(property) ?  ": "+CMessage::Text(MSG_LIB_PROP_NOT_SUPPORTED) :
          ": "+this.GetTimeframeDescription()
         )  :
      property==INDICATOR_PROP_HANDLE        ?  CMessage::Text(MSG_LIB_TEXT_IND_TEXT_HANDLE)+
         (!this.SupportProperty(property) ?  ": "+CMessage::Text(MSG_LIB_PROP_NOT_SUPPORTED) :
          ": "+(string)this.GetProperty(property)
         )  :
      ""
     );
  }
//+------------------------------------------------------------------+

[CODE END]

 Indicator object classes

 Now, create descendant objects of base abstract indicator which will specify all information on indicator object created. And those classes will serve to create different type indicators and to get data from them.

 In directory \MQL5\Include\DoEasy\Objects\Indicators\ create a new folder Standart, and in it create a new file IndAC.mqh of CIndAC class of Accelerator Oscillator standard indicator, inherited from abstract indicator base class which file is connected to the listing of this class.
 Since the class will be not big, let’s analyze its full listing:

In directory \MQL5\Include\DoEasy\Objects\Indicators\ create a new folder Standart, and in it create a new file IndAC.mqh of CIndAC class of Accelerator Oscillator standard indicator, inherited from abstract indicator base class which file is connected to the listing of this class.
 Since the class will be not big, let’s analyze its full listing:


[CODE START]
//+------------------------------------------------------------------+
//|                                                        IndAC.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                             https://mql5.com/en/users/artmedia70 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://mql5.com/en/users/artmedia70"
//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include "..\\IndicatorDE.mqh"
//+------------------------------------------------------------------+
//| Standard indicator Accelerator Oscillator                        |
//+------------------------------------------------------------------+

class CIndAC : public CIndicatorDE
  {
private:

public:
   //--- Constructor
                     CIndAC(const string symbol,const ENUM_TIMEFRAMES timeframe,MqlParam &mql_param[]) :
                        CIndicatorDE(IND_AC,symbol,timeframe,
                                     INDICATOR_STATUS_STANDART,
                                     INDICATOR_GROUP_OSCILLATOR,
                                     "Accelerator Oscillator",
                                     "AC("+symbol+","+TimeframeDescription(timeframe)+")",mql_param) {}
   //--- Supported indicator properties (1) real, (2) integer
   virtual bool      SupportProperty(ENUM_INDICATOR_PROP_DOUBLE property);

  
//--- Display a short description of indicator object in the journal
   virtual void      PrintShort(void);
  };
//+------------------------------------------------------------------+
//| Return 'true' if indicator supports a passed                     |
//| integer property, otherwise return 'false'                       |
//+------------------------------------------------------------------+
bool CIndAC::SupportProperty(ENUM_INDICATOR_PROP_INTEGER property)
  {
   return true;
  }
//+------------------------------------------------------------------+
//| Return 'true' if indicator supports a passed                     |
//| real property, otherwise return 'false'                          |
//+------------------------------------------------------------------+
bool CIndAC::SupportProperty(ENUM_INDICATOR_PROP_DOUBLE property)
  {
   return true;
  }
//+------------------------------------------------------------------+
//--- Display a short description of indicator object in the journal |
//+------------------------------------------------------------------+

void CIndAC::PrintShort(void)
  {
   ::Print(GetStatusDescription()," ",this.Name()," ",this.Symbol()," ",TimeframeDescription(this.Timeframe()));
  }
//+------------------------------------------------------------------+

[CODE END]
 Totally, we must make 38 such classes - according to the number of standard indicators (I do not make custom indicator yet, since its implementation will slightly differ).
 All these classes will have the same methods and they will differ only by the parameters being passed to the parent class from its constructor:


[CODE START]
   //--- Constructor
                     CIndAC(const string symbol,const ENUM_TIMEFRAMES timeframe,MqlParam &mql_param[]) :
                        CIndicatorDE(IND_AC,symbol,timeframe,
                                     INDICATOR_STATUS_STANDART,
                                     INDICATOR_GROUP_OSCILLATOR,
                                     "Accelerator Oscillator",
                                     "AC("+symbol+","+TimeframeDescription(timeframe)+")",mql_param) {}

[CODE END]
 In class inputs I pass the name of the symbol, timeframe and already filled structure of indicator parameters (in this example - Accelerator Oscillator).
 In initializing list pass to the closed parametric constructor of parent class (in order):


 indicator type — IND_AC, symbol name, timeframe
 indicator status - standard
 indicator group - oscillator
 indicator name - Accelerator Oscillator
 indicator short name - AC (symbol, timeframe) and filled structure of indicator parameters


 We already know all remaining methods by previous library objects we created and they perform the same tasks.
 Methods, which return the flag of supporting the integer and real properties by the object, return true  — all properties are supported by indicator objects.
 The method returning short indicator description returns the following string type:


[CODE START]
Standard indicator Accelerator Oscillator EURUSD H4

[CODE END]
 In all remaining files of similar indicator objects classes the difference will be only in class constructor - to parent class constructor the parameters corresponding to the indicator will be passed.

 For example, for indicator Accumulation/Distribution the class constructor will look as follows:


[CODE START]
   //--- Constructor
                     CIndAD(const string symbol,const ENUM_TIMEFRAMES timeframe,MqlParam &mql_param[]) :
                        CIndicatorDE(IND_AD,symbol,timeframe,
                                     INDICATOR_STATUS_STANDART,
                                     INDICATOR_GROUP_VOLUMES,
                                     "Accumulation/Distribution",
                                     "AD("+symbol+","+TimeframeDescription(timeframe)+")",mql_param) {}

[CODE END]
 As we see, here parameters corresponding to standard indicator AD are passed:

[CODE END]
 As we see, here parameters corresponding to standard indicator AD are passed:




 indicator type — IND_AD, symbol name, timeframe
 indicator status - standard
 indicator group - volumes
 indicator name - Accumulation/Distribution
 indicator short name - AC (symbol, timeframe) and filled structure of indicator parameters


 All files of descendant classes of abstract indicator base class are already implemented and they may be viewed in the files attached to the article in \MQL5\Include\DoEasy\Objects\Indicators\Standart folder.


 Indicator objects collection

 In accordance with the general concept of library objects construction and storage now, we must put into collection list all the indicator objects created. From this list we can always get a pointer to the required indicator by specified properties or the list of indicators which have common same properties. By the received pointer to the indicator we will be able to take all data returned by the indicator for further calculations.

 In folder \MQL5\Include\DoEasy\Collections\ create a new class in the file named IndicatorsCollection.mqh.


 Apart from the methods standard for the library which return required object lists from the collection, the class will contain one private method for creation of indicator object and multiple methods to create specific indicator objects in accordance with their type; as well as multiple methods to get pointers to created indicator objects also by their types. All methods of each group are identical to each other in accordance with their logic, therefore, consider only some of them as examples.


 So that the collection class of indicators had access to indicator classes that we created above, they must be connected to file listing:

[CODE START]
//+------------------------------------------------------------------+
//|                                         IndicatorsCollection.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                             https://mql5.com/en/users/artmedia70 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://mql5.com/en/users/artmedia70"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include "ListObj.mqh"
#include "..\Objects\Indicators\Standart\IndAC.mqh"
#include "..\Objects\Indicators\Standart\IndAD.mqh"
#include "..\Objects\Indicators\Standart\IndADX.mqh"
#include "..\Objects\Indicators\Standart\IndADXW.mqh"
#include "..\Objects\Indicators\Standart\IndAlligator.mqh"
#include "..\Objects\Indicators\Standart\IndAMA.mqh"
#include "..\Objects\Indicators\Standart\IndAO.mqh"
#include "..\Objects\Indicators\Standart\IndATR.mqh"
#include "..\Objects\Indicators\Standart\IndBands.mqh"
#include "..\Objects\Indicators\Standart\IndBears.mqh"
#include "..\Objects\Indicators\Standart\IndBulls.mqh"
#include "..\Objects\Indicators\Standart\IndBWMFI.mqh"
#include "..\Objects\Indicators\Standart\IndCCI.mqh"
#include "..\Objects\Indicators\Standart\IndChaikin.mqh"
#include "..\Objects\Indicators\Standart\IndDEMA.mqh"
#include "..\Objects\Indicators\Standart\IndDeMarker.mqh"
#include "..\Objects\Indicators\Standart\IndEnvelopes.mqh"
#include "..\Objects\Indicators\Standart\IndForce.mqh"
#include "..\Objects\Indicators\Standart\IndFractals.mqh"
#include "..\Objects\Indicators\Standart\IndFRAMA.mqh"
#include "..\Objects\Indicators\Standart\IndGator.mqh"
#include "..\Objects\Indicators\Standart\IndIchimoku.mqh"
#include "..\Objects\Indicators\Standart\IndMA.mqh"
#include "..\Objects\Indicators\Standart\IndMACD.mqh"
#include "..\Objects\Indicators\Standart\IndMFI.mqh"
#include "..\Objects\Indicators\Standart\IndMomentum.mqh"
#include "..\Objects\Indicators\Standart\IndOBV.mqh"
#include "..\Objects\Indicators\Standart\IndOsMA.mqh"
#include "..\Objects\Indicators\Standart\IndRSI.mqh"
#include "..\Objects\Indicators\Standart\IndRVI.mqh"
#include "..\Objects\Indicators\Standart\IndSAR.mqh"
#include "..\Objects\Indicators\Standart\IndStDev.mqh"
#include "..\Objects\Indicators\Standart\IndStoch.mqh"
#include "..\Objects\Indicators\Standart\IndTEMA.mqh"
#include "..\Objects\Indicators\Standart\IndTRIX.mqh"
#include "..\Objects\Indicators\Standart\IndVIDYA.mqh"
#include "..\Objects\Indicators\Standart\IndVolumes.mqh"
#include "..\Objects\Indicators\Standart\IndWPR.mqh"
//+------------------------------------------------------------------+

[CODE END]
 Further, have a look at the full listing of the class body and then analyze two methods of each group.


[CODE START]
//+------------------------------------------------------------------+
//| Indicator collection                                             |
//+------------------------------------------------------------------+

class CIndicatorsCollection : public CObject
  {
private:
   CListObj                m_list;                       // Indicator object list
   MqlParam                m_mql_param[];                // Array of indicator parameters

//--- Create a new indicator object
   CIndicatorDE           *CreateIndicator(const ENUM_INDICATOR ind_type,MqlParam &mql_param[],const string symbol_name=NULL,const ENUM_TIMEFRAMES period=PERIOD_CURRENT);

public:
//--- Return (1) itself, (2) indicator list, (3) list of indicators by type
   CIndicatorsCollection  *GetObject(void)               { return &this;                                       }
   CArrayObj              *GetList(void)                 { return &this.m_list;                                }
//--- Return indicator list by (1) status, (2) type, (3) timeframe, (4) group, (5) symbol, (6) name, (7) short name
   CArrayObj              *GetListIndByStatus(const ENUM_INDICATOR_STATUS status)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_STATUS,status,EQUAL);        }
   CArrayObj              *GetListIndByType(const ENUM_INDICATOR type)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_TYPE,type,EQUAL);            }
   CArrayObj              *GetListIndByTimeframe(const ENUM_TIMEFRAMES timeframe)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_TIMEFRAME,timeframe,EQUAL);  }
   CArrayObj              *GetListIndByGroup(const ENUM_INDICATOR_GROUP group)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_GROUP,group,EQUAL);          }
   CArrayObj              *GetListIndBySymbol(const string symbol)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_SYMBOL,symbol,EQUAL);        }
   CArrayObj              *GetListIndByName(const string name)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_NAME,name,EQUAL);            }
   CArrayObj              *GetListIndByShortname(const string shortname)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_SHORTNAME,shortname,EQUAL);  }
  
//--- Return the list of indicator objects by type of indicator, symbol and timeframe
   CArrayObj              *GetListAC(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListAD(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListADX(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListADXWilder(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListAlligator(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListAMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListAO(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListATR(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBands(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBearsPower(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBullsPower(const string symbol,const ENUM_TIMEFRAMES timeframe);

CArrayObj              *GetListAO(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListATR(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBands(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBearsPower(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBullsPower(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListChaikin(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListCCI(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListDEMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListDeMarker(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListEnvelopes(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListForce(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListFractals(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListFrAMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListGator(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListIchimoku(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListBWMFI(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListMomentum(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListMFI(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListOsMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListMACD(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListOBV(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListSAR(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListRSI(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListRVI(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListStdDev(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListStochastic(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListTEMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListTriX(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListWPR(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListVIDYA(const string symbol,const ENUM_TIMEFRAMES timeframe);

CArrayObj              *GetListStochastic(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListTEMA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListTriX(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListWPR(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListVIDYA(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CArrayObj              *GetListVolumes(const string symbol,const ENUM_TIMEFRAMES timeframe);
  
//--- Return the pointer to indicator object in the collection by indicator type and by its parameters
   CIndicatorDE           *GetIndAC(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CIndicatorDE           *GetIndAD(const string symbol,const ENUM_TIMEFRAMES timeframe,const ENUM_APPLIED_VOLUME applied_volume);
   CIndicatorDE           *GetIndADX(const string symbol,const ENUM_TIMEFRAMES timeframe,const int adx_period);
   CIndicatorDE           *GetIndADXWilder(const string symbol,const ENUM_TIMEFRAMES timeframe,const int adx_period);
   CIndicatorDE           *GetIndAlligator(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int jaw_period,
                                       const int jaw_shift,
                                       const int teeth_period,
                                       const int teeth_shift,
                                       const int lips_period,
                                       const int lips_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndAMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ama_period,
                                       const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int ama_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndAO(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CIndicatorDE           *GetIndATR(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   CIndicatorDE           *GetIndBands(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const double deviation,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndBearsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   CIndicatorDE           *GetIndBullsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);

const int ma_period,
                                       const int ma_shift,
                                       const double deviation,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndBearsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   CIndicatorDE           *GetIndBullsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   CIndicatorDE           *GetIndChaikin(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ma_period,
                                       const int slow_ma_period,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   CIndicatorDE           *GetIndCCI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndDEMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndDeMarker(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   CIndicatorDE           *GetIndEnvelopes(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price,
                                       const double deviation);
   CIndicatorDE           *GetIndForce(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   CIndicatorDE           *GetIndFractals(const string symbol,const ENUM_TIMEFRAMES timeframe);
   CIndicatorDE           *GetIndFrAMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndGator(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int jaw_period,
                                       const int jaw_shift,
                                       const int teeth_period,
                                       const int teeth_shift,

const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndGator(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int jaw_period,
                                       const int jaw_shift,
                                       const int teeth_period,
                                       const int teeth_shift,
                                       const int lips_period,
                                       const int lips_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndIchimoku(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int tenkan_sen,
                                       const int kijun_sen,
                                       const int senkou_span_b);
   CIndicatorDE           *GetIndBWMFI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   CIndicatorDE           *GetIndMomentum(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int mom_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndMFI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   CIndicatorDE           *GetIndMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndOsMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int signal_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndMACD(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int signal_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndOBV(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const ENUM_APPLIED_VOLUME applied_volume);

const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int signal_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndOBV(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   CIndicatorDE           *GetIndSAR(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const double step,
                                       const double maximum);
   CIndicatorDE           *GetIndRSI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndRVI(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   CIndicatorDE           *GetIndStdDev(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndStochastic(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int Kperiod,
                                       const int Dperiod,
                                       const int slowing,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_STO_PRICE price_field);
   CIndicatorDE           *GetIndTEMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndTriX(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndWPR(const string symbol,const ENUM_TIMEFRAMES timeframe,const int calc_period);
   CIndicatorDE           *GetIndVIDYA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int cmo_period,
                                       const int ema_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndVolumes(const string symbol,const ENUM_TIMEFRAMES timeframe,const ENUM_APPLIED_VOLUME applied_volume);
  
//--- Create a new indicator object by indicator type and places it to collection list

const int cmo_period,
                                       const int ema_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   CIndicatorDE           *GetIndVolumes(const string symbol,const ENUM_TIMEFRAMES timeframe,const ENUM_APPLIED_VOLUME applied_volume);
  
//--- Create a new indicator object by indicator type and places it to collection list
   int                     CreateAC(const string symbol,const ENUM_TIMEFRAMES timeframe);
   int                     CreateAD(const string symbol,const ENUM_TIMEFRAMES timeframe,const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateADX(const string symbol,const ENUM_TIMEFRAMES timeframe,const int adx_period);
   int                     CreateADXWilder(const string symbol,const ENUM_TIMEFRAMES timeframe,const int adx_period);
   int                     CreateAlligator(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int jaw_period,
                                       const int jaw_shift,
                                       const int teeth_period,
                                       const int teeth_shift,
                                       const int lips_period,
                                       const int lips_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateAMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ama_period,
                                       const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int ama_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateAO(const string symbol,const ENUM_TIMEFRAMES timeframe);
   int                     CreateATR(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateBands(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const double deviation,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateBearsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateBullsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateChaikin(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ma_period,
                                       const int slow_ma_period,

int                     CreateBearsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateBullsPower(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateChaikin(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ma_period,
                                       const int slow_ma_period,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateCCI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateDEMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateDeMarker(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateEnvelopes(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price,
                                       const double deviation);
   int                     CreateForce(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateFractals(const string symbol,const ENUM_TIMEFRAMES timeframe);
   int                     CreateFrAMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateGator(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int jaw_period,
                                       const int jaw_shift,
                                       const int teeth_period,
                                       const int teeth_shift,
                                       const int lips_period,
                                       const int lips_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);

const int jaw_shift,
                                       const int teeth_period,
                                       const int teeth_shift,
                                       const int lips_period,
                                       const int lips_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateIchimoku(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int tenkan_sen,
                                       const int kijun_sen,
                                       const int senkou_span_b);
   int                     CreateBWMFI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateMomentum(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int mom_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateMFI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateOsMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int signal_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateMACD(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int fast_ema_period,
                                       const int slow_ema_period,
                                       const int signal_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateOBV(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateSAR(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const double step,
                                       const double maximum);
   int                     CreateRSI(const string symbol,const ENUM_TIMEFRAMES timeframe,

int                     CreateOBV(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const ENUM_APPLIED_VOLUME applied_volume);
   int                     CreateSAR(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const double step,
                                       const double maximum);
   int                     CreateRSI(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateRVI(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ma_period);
   int                     CreateStdDev(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateStochastic(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int Kperiod,
                                       const int Dperiod,
                                       const int slowing,
                                       const ENUM_MA_METHOD ma_method,
                                       const ENUM_STO_PRICE price_field);
   int                     CreateTEMA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateTriX(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int ma_period,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateWPR(const string symbol,const ENUM_TIMEFRAMES timeframe,const int calc_period);
   int                     CreateVIDYA(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                       const int cmo_period,
                                       const int ema_period,
                                       const int ma_shift,
                                       const ENUM_APPLIED_PRICE applied_price);
   int                     CreateVolumes(const string symbol,const ENUM_TIMEFRAMES timeframe,const ENUM_APPLIED_VOLUME applied_volume);

//--- Constructor
                           CIndicatorsCollection();

  };
//+------------------------------------------------------------------+

[CODE END]
 Listing seems impressive, but, in fact, we have here only several groups of similar-type methods which differ from each other by the type of required indicator.

 The methods which return lists with required indicator types are standard for the library and we analyzed them repeatedly:


[CODE START]
//--- Return (1) itself, (2) indicator list, (3) list of indicators by type
   CIndicatorsCollection  *GetObject(void)               { return &this;                                       }
   CArrayObj              *GetList(void)                 { return &this.m_list;                                }
//--- Return indicator list by (1) status, (2) type, (3) timeframe, (4) group, (5) symbol, (6) name, (7) short name
   CArrayObj              *GetListIndByStatus(const ENUM_INDICATOR_STATUS status)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_STATUS,status,EQUAL);        }
   CArrayObj              *GetListIndByType(const ENUM_INDICATOR type)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_TYPE,type,EQUAL);            }
   CArrayObj              *GetListIndByTimeframe(const ENUM_TIMEFRAMES timeframe)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_TIMEFRAME,timeframe,EQUAL);  }
   CArrayObj              *GetListIndByGroup(const ENUM_INDICATOR_GROUP group)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_GROUP,group,EQUAL);          }
   CArrayObj              *GetListIndBySymbol(const string symbol)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_SYMBOL,symbol,EQUAL);        }
   CArrayObj              *GetListIndByName(const string name)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_NAME,name,EQUAL);            }
   CArrayObj              *GetListIndByShortname(const string shortname)
                             { return CSelect::ByIndicatorProperty(this.GetList(),INDICATOR_PROP_SHORTNAME,shortname,EQUAL);  }

[CODE END]
 In class constructor reset the array of indicator parameter structures, clear collection list, set sorted list flag for the list and assign indicator collection ID to it:


[CODE START]
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorsCollection::CIndicatorsCollection()
  {
   ::ArrayResize(this.m_mql_param,0);
   this.m_list.Clear();
   this.m_list.Sort();
   this.m_list.Type(COLLECTION_INDICATORS_ID);
  }
//+------------------------------------------------------------------+

[CODE START]
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CIndicatorsCollection::CIndicatorsCollection()
  {
   ::ArrayResize(this.m_mql_param,0);
   this.m_list.Clear();
   this.m_list.Sort();
   this.m_list.Type(COLLECTION_INDICATORS_ID);
  }
//+------------------------------------------------------------------+

[CODE END]
 The private method for creation of indicator object simply creates a new indicator object depending on the type of indicator created passed to the method and return the pointer to created object:

[CODE START]
//+------------------------------------------------------------------+
//| Create a new indicator object                                    |
//+------------------------------------------------------------------+
CIndicatorDE *CIndicatorsCollection::CreateIndicator(const ENUM_INDICATOR ind_type,MqlParam &mql_param[],const string symbol_name=NULL,const ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   string symbol=(symbol_name==NULL || symbol_name=="" ? ::Symbol() : symbol_name);
   ENUM_TIMEFRAMES timeframe=(period==PERIOD_CURRENT ? ::Period() : period);
   CIndicatorDE *indicator=NULL;
   switch(ind_type)
     {
      case IND_AC          : indicator=new CIndAC(symbol,timeframe,mql_param);         break;
      case IND_AD          : indicator=new CIndAD(symbol,timeframe,mql_param);         break;
      case IND_ADX         : indicator=new CIndADX(symbol,timeframe,mql_param);        break;
      case IND_ADXW        : indicator=new CIndADXW(symbol,timeframe,mql_param);       break;
      case IND_ALLIGATOR   : indicator=new CIndAlligator(symbol,timeframe,mql_param);  break;
      case IND_AMA         : indicator=new CIndAMA(symbol,timeframe,mql_param);        break;
      case IND_AO          : indicator=new CIndAO(symbol,timeframe,mql_param);         break;
      case IND_ATR         : indicator=new CIndATR(symbol,timeframe,mql_param);        break;
      case IND_BANDS       : indicator=new CIndBands(symbol,timeframe,mql_param);      break;
      case IND_BEARS       : indicator=new CIndBears(symbol,timeframe,mql_param);      break;
      case IND_BULLS       : indicator=new CIndBulls(symbol,timeframe,mql_param);      break;
      case IND_BWMFI       : indicator=new CIndBWMFI(symbol,timeframe,mql_param);      break;
      case IND_CCI         : indicator=new CIndCCI(symbol,timeframe,mql_param);        break;
      case IND_CHAIKIN     : indicator=new CIndCHO(symbol,timeframe,mql_param);        break;
      case IND_DEMA        : indicator=new CIndDEMA(symbol,timeframe,mql_param);       break;
      case IND_DEMARKER    : indicator=new CIndDeMarker(symbol,timeframe,mql_param);   break;
      case IND_ENVELOPES   : indicator=new CIndEnvelopes(symbol,timeframe,mql_param);  break;
      case IND_FORCE       : indicator=new CIndForce(symbol,timeframe,mql_param);      break;
      case IND_FRACTALS    : indicator=new CIndFractals(symbol,timeframe,mql_param);   break;
      case IND_FRAMA       : indicator=new CIndFRAMA(symbol,timeframe,mql_param);      break;
      case IND_GATOR       : indicator=new CIndGator(symbol,timeframe,mql_param);      break;
      case IND_ICHIMOKU    : indicator=new CIndIchimoku(symbol,timeframe,mql_param);   break;
      case IND_MA          : indicator=new CIndMA(symbol,timeframe,mql_param);         break;
      case IND_MACD        : indicator=new CIndMACD(symbol,timeframe,mql_param);       break;
      case IND_MFI         : indicator=new CIndMFI(symbol,timeframe,mql_param);        break;

case IND_GATOR       : indicator=new CIndGator(symbol,timeframe,mql_param);      break;
      case IND_ICHIMOKU    : indicator=new CIndIchimoku(symbol,timeframe,mql_param);   break;
      case IND_MA          : indicator=new CIndMA(symbol,timeframe,mql_param);         break;
      case IND_MACD        : indicator=new CIndMACD(symbol,timeframe,mql_param);       break;
      case IND_MFI         : indicator=new CIndMFI(symbol,timeframe,mql_param);        break;
      case IND_MOMENTUM    : indicator=new CIndMomentum(symbol,timeframe,mql_param);   break;
      case IND_OBV         : indicator=new CIndOBV(symbol,timeframe,mql_param);        break;
      case IND_OSMA        : indicator=new CIndOsMA(symbol,timeframe,mql_param);       break;
      case IND_RSI         : indicator=new CIndRSI(symbol,timeframe,mql_param);        break;
      case IND_RVI         : indicator=new CIndRVI(symbol,timeframe,mql_param);        break;
      case IND_SAR         : indicator=new CIndSAR(symbol,timeframe,mql_param);        break;
      case IND_STDDEV      : indicator=new CIndStDev(symbol,timeframe,mql_param);      break;
      case IND_STOCHASTIC  : indicator=new CIndStoch(symbol,timeframe,mql_param);      break;
      case IND_TEMA        : indicator=new CIndTEMA(symbol,timeframe,mql_param);       break;
      case IND_TRIX        : indicator=new CIndTRIX(symbol,timeframe,mql_param);       break;
      case IND_VIDYA       : indicator=new CIndVIDYA(symbol,timeframe,mql_param);      break;
      case IND_VOLUMES     : indicator=new CIndVolumes(symbol,timeframe,mql_param);    break;
      case IND_WPR         : indicator=new CIndWPR(symbol,timeframe,mql_param);        break;
      
      case IND_CUSTOM : break;
      default: break;
     }
   return indicator;
  }
//+------------------------------------------------------------------+

[CODE END]
 By default, as well temporarily and for custom indicator (its creation will be implemented in following articles) the method returns NULL.


 The method creating indicator object Accelerator Oscillator:


[CODE START]
//+------------------------------------------------------------------+
//| Create a new indicator object Accelerator Oscillator             |
//| and place it to the collection list                              |
//+------------------------------------------------------------------+
int CIndicatorsCollection::CreateAC(const string symbol,const ENUM_TIMEFRAMES timeframe)
  {
//--- AC indicator possesses no parameters - resize the array of parameter structures
   ::ArrayResize(this.m_mql_param,0);
//--- Create indicator object
   CIndicatorDE *indicator=this.CreateIndicator(IND_AC,this.m_mql_param,symbol,timeframe);
   if(indicator==NULL)
      return INVALID_HANDLE;
   int index=this.m_list.Search(indicator);
//--- If such indicator is already in the list
   if(index!=WRONG_VALUE)
     {
      //--- Get indicator object from the list and return indicator handle
      indicator=this.m_list.At(index);
      return indicator.Handle();
     }
//--- If such indicator is not in the list
   else
     {
      //--- If failed to add indicator object to the list
      //--- display the appropriate message and return INVALID_HANDLE
      if(!this.m_list.Add(indicator))
        {
         Print(CMessage::Text(MSG_LIB_SYS_FAILED_ADD_IND_TO_LIST));
         return INVALID_HANDLE;
        }
      //--- Return the handle of a new indicator added to the list
      return indicator.Handle();
     }
//--- Return INVALID_HANDLE
   return INVALID_HANDLE;
  }
//+------------------------------------------------------------------+

[CODE END]
 The method logic is described in its listing and it must not cause questions. Note that indicator object is created in the method of its creation CreateIndicator(), analyzed above. The method receives a type of IND_AC indicator. Since AC indicator possesses no inputs the array of indicator parameter structures is not required here. Therefore, the array is reset which points that we do not need to use it when creating an indicator in CIndicatorDE class which we considered in the previous article.




 Remaining methods for creation of other standard indicators are identical to that just analyzed in their logic and they differ only by specification of the required indicator and by filling of the array of indicator parameter structures where it is necessary.

 As example, consider the method of Alligator indicator creation where eight inputs are required and all of them are added to the array of indicator parameters in accordance with the order of consequence of those parameters with Alligator indicator and IND_ALLIGATOR type is passed to the method of indicator object creation:

[CODE START]
//+------------------------------------------------------------------+
//| Create new indicator object Alligator                            |
//| and place it to the collection list                              |
//+------------------------------------------------------------------+
int CIndicatorsCollection::CreateAlligator(const string symbol,const ENUM_TIMEFRAMES timeframe,
                                           const int jaw_period,
                                           const int jaw_shift,
                                           const int teeth_period,
                                           const int teeth_shift,
                                           const int lips_period,
                                           const int lips_shift,
                                           const ENUM_MA_METHOD ma_method,
                                           const ENUM_APPLIED_PRICE applied_price)
  {
//--- Add required indicator parameters to the array of parameter structures
   ::ArrayResize(this.m_mql_param,8);
   this.m_mql_param[0].type=TYPE_INT;
   this.m_mql_param[0].integer_value=jaw_period;
   this.m_mql_param[1].type=TYPE_INT;
   this.m_mql_param[1].integer_value=jaw_shift;
   this.m_mql_param[2].type=TYPE_INT;
   this.m_mql_param[2].integer_value=teeth_period;
   this.m_mql_param[3].type=TYPE_INT;
   this.m_mql_param[3].integer_value=teeth_shift;
   this.m_mql_param[4].type=TYPE_INT;
   this.m_mql_param[4].integer_value=lips_period;
   this.m_mql_param[5].type=TYPE_INT;
   this.m_mql_param[5].integer_value=lips_shift;
   this.m_mql_param[6].type=TYPE_INT;
   this.m_mql_param[6].integer_value=ma_method;
   this.m_mql_param[7].type=TYPE_INT;
   this.m_mql_param[7].integer_value=applied_price;
//--- Create indicator object
   CIndicatorDE *indicator=this.CreateIndicator(IND_ALLIGATOR,this.m_mql_param,symbol,timeframe);
   if(indicator==NULL)
      return INVALID_HANDLE;
   int index=this.m_list.Search(indicator);
//--- If such indicator is already in the list
   if(index!=WRONG_VALUE)
     {
      //--- Get indicator object from the list and return indicator handle
      indicator=this.m_list.At(index);
      return indicator.Handle();
     }
//--- If such indicator is not in the list
   else
     {
      //--- If failed to add indicator object to the list
      //--- display the appropriate message and return INVALID_HANDLE
      if(!this.m_list.Add(indicator))
        {
         Print(CMessage::Text(MSG_LIB_SYS_FAILED_ADD_IND_TO_LIST));
         return INVALID_HANDLE;
        }
      //--- Return the handle of a new indicator added to the list
      return indicator.Handle();
     }
//--- Return INVALID_HANDLE
   return INVALID_HANDLE;
  }
//+------------------------------------------------------------------+

[CODE END]
 These are all differences of each method from each other. Remaining methods for indicator creation will not be analyzed. They are available in the files attached to the article.

[CODE END]
 These are all differences of each method from each other. Remaining methods for indicator creation will not be analyzed. They are available in the files attached to the article.

 The method returning the list of all indicator objects Accelerator Oscillator which are in the collection list, by symbol and timeframe:



[CODE START]
//+------------------------------------------------------------------+
//| Return the list of indicator objects Accelerator Oscillator      |
//| by symbol and timeframe                                          |
//+------------------------------------------------------------------+
CArrayObj *CIndicatorsCollection::GetListAC(const string symbol,const ENUM_TIMEFRAMES timeframe)
  {
   CArrayObj *list=GetListIndByType(IND_AC);
   list=CSelect::ByIndicatorProperty(list,INDICATOR_PROP_SYMBOL,symbol,EQUAL);
   return CSelect::ByIndicatorProperty(list,INDICATOR_PROP_TIMEFRAME,timeframe,EQUAL);
  }
//+------------------------------------------------------------------+

[CODE END]
 First, get the list of all indicator objects Accelerator Oscillator which are in the collection list,
 then sort the received list by symbol
 and return the received list which is sorted once again, this time by timeframe.


 Remaining methods are fully identical to the above considered, save for the fact that first, we get the list of all required indicators in accordance with method setting.

 For example, to get the list of all indicator objects Accumulation/Distribution which are in the collection list, by symbol and timeframe, the method will be as follows:


[CODE START]
//+------------------------------------------------------------------+
//| Return the list of indicator objects  Accumulation/Distribution  |
//| by symbol and timeframe                                          |
//+------------------------------------------------------------------+
CArrayObj *CIndicatorsCollection::GetListAD(const string symbol,const ENUM_TIMEFRAMES timeframe)
  {
   CArrayObj *list=GetListIndByType(IND_AD);
   list=CSelect::ByIndicatorProperty(list,INDICATOR_PROP_SYMBOL,symbol,EQUAL);
   return CSelect::ByIndicatorProperty(list,INDICATOR_PROP_TIMEFRAME,timeframe,EQUAL);
  }
//+------------------------------------------------------------------+

[CODE END]
 Here, first get the list of all AD indicators, being in the collection and further, sort the list by symbol and timeframe as in the above considered method.


 Today implement only one method which returns the pointer to indicator object in the collection by indicator type and by its parameters - for Accelerator Oscillator indicator:

[CODE END]
 Here, first get the list of all AD indicators, being in the collection and further, sort the list by symbol and timeframe as in the above considered method.


 Today implement only one method which returns the pointer to indicator object in the collection by indicator type and by its parameters - for Accelerator Oscillator indicator:


[CODE START]
//+------------------------------------------------------------------+
//| Return pointer to indicator object Accelerator Oscillator        |
//+------------------------------------------------------------------+
CIndicatorDE *CIndicatorsCollection::GetIndAC(const string symbol,const ENUM_TIMEFRAMES timeframe)
  {
   CArrayObj *list=GetListAC(symbol,timeframe);
   return(list==NULL || list.Total()==0 ? NULL : list.At(0));
  }
//+------------------------------------------------------------------+

[CODE END]
 Since this indicator (and some other) possesses no inputs, when selecting it from collection list by symbol and timeframe, the list will contain only one indicator object (by index 0), which corresponds to type IND_AC and to requested symbol and timeframe.
 Whereas, the indicators which possess inputs require additional search methods by the array of indicator parameter structures to implement their search by specified parameters. This will be beyond the size of this article. Therefore, such methods will be analyzed in the next article.


 I will test only creation of one indicator object Accelerator Oscillator since this article has rather training purposes and doesn’t claim to be complete. In the previous article I already performed such test on creation of AC indicator object in collection class of buffers:


[CODE START]
//+------------------------------------------------------------------+
//| Create multi-symbol multi-period AC                              |
//+------------------------------------------------------------------+
int CBuffersCollection::CreateAC(const string symbol,const ENUM_TIMEFRAMES timeframe,const int id=WRONG_VALUE)
  {
//--- To check it, create indicator object, print its data and remove it at once
   ::ArrayResize(this.m_mql_param,0);
   CIndicatorDE *indicator=new CIndicatorDE(IND_AC,symbol,timeframe,INDICATOR_STATUS_STANDART,INDICATOR_GROUP_OSCILLATOR,"Accelerator Oscillator","AC("+symbol+","+TimeframeDescription(timeframe)+")",this.m_mql_param);
   indicator.Print();
   delete indicator;

//--- Create indicator handle and set default ID

[CODE END]
 Today, I will do the same thing: in the same method create Accelerator Oscillator indicator object, but this time using newly added classes.

//--- Create indicator handle and set default ID

[CODE END]
 Today, I will do the same thing: in the same method create Accelerator Oscillator indicator object, but this time using newly added classes.

 Looking ahead: we must “see” collection list in collection class of timeseries so that storage function for data of all indicators created in bar objects which “lie” in timeseries lists, open for us.
 Therefore, preliminary we need to include collection class of indicators to timeseries collection class in file \MQL5\Include\DoEasy\Collections\TimeSeriesCollection.mqh:


[CODE START]
//+------------------------------------------------------------------+
//|                                         TimeSeriesCollection.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                             https://mql5.com/en/users/artmedia70 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://mql5.com/en/users/artmedia70"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include "ListObj.mqh"
#include "..\Objects\Series\TimeSeriesDE.mqh"
#include "..\Objects\Symbols\Symbol.mqh"
#include "IndicatorsCollection.mqh"
//+------------------------------------------------------------------+

[CODE END]
 Further, in the private section of the class declare pointer to collection class of indicators:


[CODE START]
//+------------------------------------------------------------------+
//| Symbol timeseries collection                                     |
//+------------------------------------------------------------------+

class CTimeSeriesCollection : public CBaseObjExt
  {
private:
   CListObj                m_list;                    // List of applied symbol timeseries
   CIndicatorsCollection  *m_indicators;              // Pointer to collection object of indicators
//--- Return the timeseries index by symbol name
   int                     IndexTimeSeries(const string symbol);
public:

[CODE END]
 And in the end of class listing create initializing method through which the pointer to indicator collection object will be passed to the class in the main object of CEngine library:


[CODE START]
//--- Constructor
                           CTimeSeriesCollection();
//--- Get pointers to the indicator collection (the method is called in CollectionOnInit() method of the CEngine object)
   void                    OnInit(CIndicatorsCollection *indicators) { this.m_indicators=indicators;  }
  };
//+------------------------------------------------------------------+

[CODE END]
 In file of buffer collection class \MQL5\Include\DoEasy\Collections\BuffersCollection.mqh also declare the pointer to indicator collection object:


[CODE START]
//+------------------------------------------------------------------+
//| Collection of indicator buffers                                  |
//+------------------------------------------------------------------+

class CBuffersCollection : public CObject
  {
private:
   CListObj                m_list;                       // Buffer object list
   CTimeSeriesCollection  *m_timeseries;                 // Pointer to the timeseries collection object
   CIndicatorsCollection  *m_indicators;                 // Pointer to collection object of indicators
   MqlParam                m_mql_param[];                // Array of indicator parameters
//--- Return the index of the (1) last, (2) next drawn and (3) basic buffer
   int                     GetIndexLastPlot(void);
   int                     GetIndexNextPlot(void);
   int                     GetIndexNextBase(void);
//--- Create a new buffer object and place it to the collection list
   bool                    CreateBuffer(ENUM_BUFFER_STATUS status);
//--- Get data of the necessary timeseries and bars for working with a single buffer bar, and return the number of bars
   int                     GetBarsData(CBuffer *buffer,const int series_index,int &index_bar_period);

public:

[CODE END]
 To method of OnInit() class add setting for this pointer a value being passed by input parameter:


[CODE START]
//--- Constructor
                           CBuffersCollection();
//--- Get pointers to collections of timeseries and indicators (the method is called in CollectionOnInit() method of the CEngine object)
   void                    OnInit(CTimeSeriesCollection *timeseries,CIndicatorsCollection *indicators)
                             { this.m_timeseries=timeseries; this.m_indicators=indicators;   }
  };
//+------------------------------------------------------------------+

[CODE END]
 And in the method of creation of AC indicator change creation of indicator object made in the previous article to its creation and getting with the use of collection class of indicators:


[CODE START]
//+------------------------------------------------------------------+
//| Create multi-symbol multi-period AC                              |
//+------------------------------------------------------------------+
int CBuffersCollection::CreateAC(const string symbol,const ENUM_TIMEFRAMES timeframe,const int id=WRONG_VALUE)
  {
//--- To check it, create indicator object, print its data and remove it at once
//--- Parameters are not needed for AC, therefore, reset the array of indicator parameter structures
   ::ArrayResize(this.m_mql_param,0);
//--- Create AC indicator and add it to collection
   this.m_indicators.CreateAC(symbol,timeframe);
//--- Get from collection of AC indicator object
   CIndicatorDE *indicator=this.m_indicators.GetIndAC(symbol,timeframe);
//--- Display all data of the created indicator in the journal, display its short description and remove indicator object
   indicator.Print();
   indicator.PrintShort();
   delete indicator;

//--- Create indicator handle and set default ID

//--- Create indicator handle and set default ID

[CODE END]
 Now let's improve the CEngine class of library main object.
 In file \MQL5\Include\DoEasy\Engine.mqh add inclusion of indicator collection file to class listing:


[CODE START]
//+------------------------------------------------------------------+
//|                                                       Engine.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                             https://mql5.com/en/users/artmedia70 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://mql5.com/en/users/artmedia70"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include "Services\TimerCounter.mqh"
#include "Collections\HistoryCollection.mqh"
#include "Collections\MarketCollection.mqh"
#include "Collections\EventsCollection.mqh"
#include "Collections\AccountsCollection.mqh"
#include "Collections\SymbolsCollection.mqh"
#include "Collections\ResourceCollection.mqh"
#include "Collections\TimeSeriesCollection.mqh"
#include "Collections\BuffersCollection.mqh"
#include "Collections\IndicatorsCollection.mqh"
#include "TradingControl.mqh"
//+------------------------------------------------------------------+

[CODE END]
 In the private section of the class declare object of indicator collection class:


[CODE START]
//+------------------------------------------------------------------+
//| Library basis class                                              |
//+------------------------------------------------------------------+

class CEngine
  {
private:
   CHistoryCollection   m_history;                       // Collection of historical orders and deals
   CMarketCollection    m_market;                        // Collection of market orders and deals
   CEventsCollection    m_events;                        // Event collection
   CAccountsCollection  m_accounts;                      // Account collection
   CSymbolsCollection   m_symbols;                       // Symbol collection
   CTimeSeriesCollection m_time_series;                  // Timeseries collection
   CBuffersCollection   m_buffers;                       // Collection of indicator buffers
   CIndicatorsCollection m_indicators;                   // Indicator collection
   CResourceCollection  m_resource;                      // Resource list
   CTradingControl      m_trading;                       // Trading control object
   CPause               m_pause;                         // Pause object
   CArrayObj            m_list_counters;                 // List of timer counters
   int                  m_global_error;                  // Global error code
   bool                 m_first_start;                   // First launch flag
   bool                 m_is_hedge;                      // Hedge account flag
   bool                 m_is_tester;                     // Flag of working in the tester
   bool                 m_is_market_trade_event;         // Account trading event flag
   bool                 m_is_history_trade_event;        // Account history trading event flag
   bool                 m_is_account_event;              // Account change event flag
   bool                 m_is_symbol_event;               // Symbol change event flag
   ENUM_TRADE_EVENT     m_last_trade_event;              // Last account trading event
   int                  m_last_account_event;            // Last event in the account properties
   int                  m_last_symbol_event;             // Last event in the symbol properties
   ENUM_PROGRAM_TYPE    m_program;                       // Program type
   string               m_name;                          // Program name
//--- Return the counter index by id
   int                  CounterIndex(const int id) const;
//--- Return the first launch flag
   bool                 IsFirstStart(void);
//--- Work with (1) order, deal and position, (2) account events
   void                 TradeEventsControl(void);
   void                 AccountEventsControl(void);
//--- (1) Working with a symbol collection and (2) symbol list events in the market watch window
   void                 SymbolEventsControl(void);
   void                 MarketWatchEventsControl(void);
//--- Return the last (1) market pending order, (2) market order, (3) last position, (4) position by ticket
   COrder              *GetLastMarketPending(void);
   COrder              *GetLastMarketOrder(void);
   COrder              *GetLastPosition(void);
   COrder              *GetPosition(const ulong ticket);

void                 SymbolEventsControl(void);
   void                 MarketWatchEventsControl(void);
//--- Return the last (1) market pending order, (2) market order, (3) last position, (4) position by ticket
   COrder              *GetLastMarketPending(void);
   COrder              *GetLastMarketOrder(void);
   COrder              *GetLastPosition(void);
   COrder              *GetPosition(const ulong ticket);
//--- Return the last (1) removed pending order, (2) historical market order, (3) historical order (market or pending one) by its ticket
   COrder              *GetLastHistoryPending(void);
   COrder              *GetLastHistoryOrder(void);
   COrder              *GetHistoryOrder(const ulong ticket);
//--- Return the (1) first and the (2) last historical market orders from the list of all position orders, (3) the last deal
   COrder              *GetFirstOrderPosition(const ulong position_id);
   COrder              *GetLastOrderPosition(const ulong position_id);
   COrder              *GetLastDeal(void);
//--- Retrieve a necessary 'ushort' number from the packed 'long' value
   ushort               LongToUshortFromByte(const long source_value,const uchar index) const;
  
public:

[CODE END]
 In public section write two methods to return pointer to indicator collection objects and pointer to indicator list of this collection:


[CODE START]
//--- Return the bar index on the specified timeframe chart by the current chart's bar index
   int                  IndexBarPeriodByBarCurrent(const int series_index,const string symbol,const ENUM_TIMEFRAMES timeframe)
                          { return this.m_time_series.IndexBarPeriodByBarCurrent(series_index,symbol,timeframe);  }
                          
//--- Return (1) the indicator collection, (2) the indicator list from the collection
   CIndicatorsCollection *GetIndicatorsCollection(void)                                { return &this.m_indicators;           }
   CArrayObj           *GetListIndicators(void)                                        { return this.m_indicators.GetList();  }

[CODE END]
 These methods will be useful to us for calling indicator collection from our programs.

 Add to method CollectionOnInit() passing of the pointer to indicator collection to collection classes of buffers and timeseries:


[CODE START]
//--- Pass the pointers to all the necessary collections to the trading class and the indicator buffer collection class
   void                 CollectionOnInit(void)
                          {
                           this.m_trading.OnInit(this.GetAccountCurrent(),m_symbols.GetObject(),m_market.GetObject(),m_history.GetObject(),m_events.GetObject());
                           this.m_buffers.OnInit(this.m_time_series.GetObject(),this.m_indicators.GetObject());
                           this.m_time_series.OnInit(this.m_indicators.GetObject());
                          }

[CODE END]
 Now, in case of initializing of library the pointer to indicator collection object will be passed to all classes where access to indicator collection is necessary. They will be able to work with this collection.


 For now, these are all improvements necessary to create indicator collection class.




 Testing

 For testing we need the indicator from the previous article without any changes.
 Simply save it in a new folder \MQL5\Indicators\TestDoEasy\Part54\ under a new name TestDoEasyPart54.mq5.


 Compile the indicator and launch it on the chart.
 The following will be displayed in the journal: all parameters of created indicator Accelerator Oscillator in full , and then its short description:

For now, these are all improvements necessary to create indicator collection class.




 Testing

 For testing we need the indicator from the previous article without any changes.
 Simply save it in a new folder \MQL5\Indicators\TestDoEasy\Part54\ under a new name TestDoEasyPart54.mq5.


 Compile the indicator and launch it on the chart.
 The following will be displayed in the journal: all parameters of created indicator Accelerator Oscillator in full , and then its short description:


[CODE START]
Account 8550475: Artyom Trishkin (MetaQuotes Software Corp.) 10425.23 USD, 1:100, Hedge, Demo account MetaTrader 5
--- Initializing "DoEasy" library ---
Working with the current symbol only. Number of used symbols: 1
"EURUSD"
Working with the specified timeframe list:
"H4" "H1"
EURUSD symbol timeseries:
- "EURUSD" H1 timeseries: Requested: 1000, Actually: 0, Created: 0, On the server: 0
- "EURUSD" H4 timeseries: Requested: 1000, Actually: 1000, Created: 1000, On the server: 6231
Time of library initializing: 00:00:00.156

============= Beginning of the parameter list: "Standard indicator" =============
Indicator status: Standard indicator
Indicator type: AC
Indicator timeframe: H4
Indicator handle: 10
Indicator group: Oscillator
------
Empty value for plotting where nothing will be drawn: EMPTY_VALUE
------
Indicator symbol: EURUSD
Indicator name: "Accelerator Oscillator"
Indicator short name: "AC(EURUSD,H4)"
================== End of the parameter list: "Standard indicator" ==================

Standard indicator Accelerator Oscillator EURUSD H4
Buffer (P0/B0/C1): Histogram from zero line EURUSD H4
Buffer [P0/B2/C2]: Calculated buffer
"EURUSD" H1 timeseries created successfully:
- "EURUSD" H1 timeseries: Requested: 1000, Actually: 1000, Created: 1000, On the server: 6256

[CODE END]



 What's next?

 In the next article we will continue working on indicator collection class.


  All files of the current version of the library are attached below together with the test indicator file for MQL5. You can download them and test everything.
 Note, that at the moment indicator collection class is under development, therefore  it is strictly recommended not to use it in your programs.
 Leave your comments, questions and suggestions in the comments to the article.


 Back to contents

 Previous articles within the series:

All files of the current version of the library are attached below together with the test indicator file for MQL5. You can download them and test everything.
 Note, that at the moment indicator collection class is under development, therefore  it is strictly recommended not to use it in your programs.
 Leave your comments, questions and suggestions in the comments to the article.


 Back to contents

 Previous articles within the series:

 Timeseries in DoEasy library (part 35): Bar object and symbol timeseries list
 Timeseries in DoEasy library (part 36): Object of timeseries for all used symbol periods
 Timeseries in DoEasy library (part 37): Timeseries collection - database of timeseries by symbols and periods
 Timeseries in DoEasy library (part 38): Timeseries collection - real-time updates and accessing data from the program
 Timeseries in DoEasy library (part 39): Library-based indicators - preparing data and timeseries events
 Timeseries in DoEasy library (part 40): Library-based indicators - updating data in real time
 Timeseries in DoEasy library (part 41): Sample multi-symbol multi-period indicator
 Timeseries in DoEasy library (part 42): Abstract indicator buffer object class
 Timeseries in DoEasy library (part 43): Classes of indicator buffer objects
 Timeseries in DoEasy library (part 44): Collection class of indicator buffer objects
 Timeseries in DoEasy library (part 45): Multi-period indicator buffers
 Timeseries in DoEasy library (part 46): Multi-period multi-symbol indicator buffers
 Timeseries in DoEasy library (part 47): Multi-period multi-symbol standard indicators
 Timeseries in DoEasy library (part 48): Multi-period multi-symbol indicators on one buffer in subwindow
 Timeseries in DoEasy library (part 49): Multi-period multi-symbol multi-buffer standard indicators
 Timeseries in DoEasy library (part 50): Multi-period multi-symbol standard indicators with a shift
 Timeseries in DoEasy library (part 51): Composite multi-period multi-symbol standard indicators
 Timeseries in DoEasy library (part 52): Cross-platform nature of multi-period multi-symbol single-buffer standard indicators
 Timeseries in DoEasy library (part 53): Abstract base indicator class






              Translated from Russian by MetaQuotes Ltd.
Original article: https://www.mql5.com/ru/articles/8508



  Attached files |


      Download ZIP




      MQL5.zip
      (3835.27 KB)





    Warning: All rights to these materials are reserved by MetaQuotes Ltd. Copying or reprinting of these materials in whole or in part is prohibited.

      This article was written by a user of the site and reflects their personal views. MetaQuotes Ltd is not responsible for the accuracy of the information presented, nor for any consequences resulting from the use of the solutions, strategies or recommendations described.




    Other articles by this author

Warning: All rights to these materials are reserved by MetaQuotes Ltd. Copying or reprinting of these materials in whole or in part is prohibited.

      This article was written by a user of the site and reflects their personal views. MetaQuotes Ltd is not responsible for the accuracy of the information presented, nor for any consequences resulting from the use of the solutions, strategies or recommendations described.




    Other articles by this author



          How to publish code to CodeBase: A practical guide



          The View component for tables in the MQL5 MVC paradigm: Base graphical element



          Table and Header Classes based on a table model in MQL5: Applying the MVC concept



          Implementation of a table model in MQL5: Applying the MVC concept



          Post-Factum trading analysis: Selecting trailing stops and new stop levels in the strategy tester



          Visual assessment and adjustment of trading in MetaTrader 5



          Market Profile indicator (Part 2): Optimization and rendering on canvas

// CONTEXT: Series: Timeseries in DoEasy library, Part: 54, Title: Timeseries in DoEasy library (part 54): Descendant classes of abstract base indicator - MQL5 Articles | FILE: MQL5.zip/MQL5/Include/DoEasy/Collections/AccountsCollection.mqh
//+------------------------------------------------------------------+
//|                                           AccountsCollection.mqh |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                             https://mql5.com/en/users/artmedia70 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://mql5.com/en/users/artmedia70"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include "ListObj.mqh"
#include "..\Services\Select.mqh"
#include "..\Objects\Accounts\Account.mqh"
//+------------------------------------------------------------------+
//| Account collection                                               |
//+------------------------------------------------------------------+

class CAccountsCollection : public CBaseObjExt
  {
private:

   string            m_symbol;                                    // Current symbol
   CListObj          m_list_accounts;                             // Account object list
   int               m_index_current;                             // Index of an account object featuring the current account data
   int               m_last_event;                                // The last event
//--- Check the account object presence in the collection list
   bool              IsPresent(CAccount* account);
//--- Find and return the account object index with the current account data
   int               Index(void);
public:
//--- Return the full account collection list "as is"
   CArrayObj        *GetList(void)                                                                          { return &this.m_list_accounts;                                         }
//--- Return the list by selected (1) integer, (2) real and (3) string properties meeting the compared criterion
   CArrayObj        *GetList(ENUM_ACCOUNT_PROP_INTEGER property,long value,ENUM_COMPARER_TYPE mode=EQUAL)   { return CSelect::ByAccountProperty(this.GetList(),property,value,mode);}
   CArrayObj        *GetList(ENUM_ACCOUNT_PROP_DOUBLE property,double value,ENUM_COMPARER_TYPE mode=EQUAL)  { return CSelect::ByAccountProperty(this.GetList(),property,value,mode);}
   CArrayObj        *GetList(ENUM_ACCOUNT_PROP_STRING property,string value,ENUM_COMPARER_TYPE mode=EQUAL)  { return CSelect::ByAccountProperty(this.GetList(),property,value,mode);}
//--- Return (1) the current account object index and (2) event ID by its number in the list
   int               IndexCurrentAccount(void)                                                        const { return this.m_index_current;                                          }
   int               GetEventID(const int shift=WRONG_VALUE,const bool check_out=true);
//--- (1) Set and (2) return the current symbol
   void              SetSymbol(const string symbol)                                                         { this.m_symbol=symbol;                                  }
   string            GetSymbol(void)                                                                  const { return this.m_symbol;                                  }
//--- (1) Update data, (2) working with events of the current account
   virtual void      Refresh(void);
   void              RefreshAndEventsControl(void);

//--- Constructor, destructor
                     CAccountsCollection();
                    ~CAccountsCollection();
//--- Add the account object to the list
   bool              AddToList(CAccount* account);
//--- (1) Save account objects from the list to the files
//--- (2) Save account objects from the files to the list
   bool              SaveObjects(void);
   bool              LoadObjects(void);

  };

void              RefreshAndEventsControl(void);

//--- Constructor, destructor
                     CAccountsCollection();
                    ~CAccountsCollection();
//--- Add the account object to the list
   bool              AddToList(CAccount* account);
//--- (1) Save account objects from the list to the files
//--- (2) Save account objects from the files to the list
   bool              SaveObjects(void);
   bool              LoadObjects(void);

  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAccountsCollection::CAccountsCollection(void) : m_symbol(::Symbol())
  {
   this.m_list_accounts.Clear();
   this.m_list_accounts.Sort(SORT_BY_ACCOUNT_LOGIN);
   this.m_list_accounts.Type(COLLECTION_ACCOUNT_ID);
   ::ZeroMemory(this.m_tick);
//--- Create the folder for storing account files
   this.SetSubFolderName("Accounts");
   ::ResetLastError();
   if(!::FolderCreate(this.m_folder_name,FILE_COMMON))
      ::Print(DFUN,CMessage::Text(MSG_LIB_SYS_FAILED_CREATE_STORAGE_FOLDER),::GetLastError());
//--- Create the current account object and add it to the list
   CAccount* account=new CAccount();
   if(account!=NULL)
     {
      if(!this.AddToList(account))
        {
         ::Print(DFUN_ERR_LINE,CMessage::Text(MSG_LIB_SYS_FAILED_ADD_ACC_OBJ_TO_LIST));
         delete account;
        }
      else
         account.PrintShort();
     }
   else
      ::Print(DFUN,CMessage::Text(MSG_LIB_SYS_FAILED_CREATE_CURR_ACC_OBJ));

//--- Download account objects from the files to the collection
   this.LoadObjects();
//--- Save the current account index
   this.m_index_current=this.Index();
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAccountsCollection::~CAccountsCollection(void)
  {
//--- Save account objects from the list to the files
   this.SaveObjects();
  }
//+------------------------------------------------------------------+
//| Add the account object to the list                               |
//+------------------------------------------------------------------+
bool CAccountsCollection::AddToList(CAccount *account)
  {
   if(account==NULL)
      return false;
   if(!this.IsPresent(account))
      return this.m_list_accounts.Add(account);
   return false;
  }
//+------------------------------------------------------------------+
//| Check the account object presence in the collection list         |
//+------------------------------------------------------------------+
bool CAccountsCollection::IsPresent(CAccount *account)
  {
   int total=this.m_list_accounts.Total();
   if(total==0)
      return false;
   for(int i=0;i<total;i++)

if(!this.IsPresent(account))
      return this.m_list_accounts.Add(account);
   return false;
  }
//+------------------------------------------------------------------+
//| Check the account object presence in the collection list         |
//+------------------------------------------------------------------+
bool CAccountsCollection::IsPresent(CAccount *account)
  {
   int total=this.m_list_accounts.Total();
   if(total==0)
      return false;
   for(int i=0;i<total;i++)
     {
      CAccount* check=this.m_list_accounts.At(i);
      if(check==NULL)
         continue;
      if(check.IsEqual(account))
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//| Return the account object index with the current account data    |
//+------------------------------------------------------------------+
int CAccountsCollection::Index(void)
  {
   int total=this.m_list_accounts.Total();
   if(total==0)
      return WRONG_VALUE;
   for(int i=0;i<total;i++)
     {
      CAccount* account=this.m_list_accounts.At(i);
      if(account==NULL)
         continue;
      if(account.Login()==::AccountInfoInteger(ACCOUNT_LOGIN)    &&
         account.Company()==::AccountInfoString(ACCOUNT_COMPANY) &&
         account.Name()==::AccountInfoString(ACCOUNT_NAME)
        ) return i;
     }
   return WRONG_VALUE;
  }
//+------------------------------------------------------------------+
//| Save account objects from the list to the files                  |
//+------------------------------------------------------------------+
bool CAccountsCollection::SaveObjects(void)
  {
   bool res=true;
   int total=this.m_list_accounts.Total();
   if(total==0)
      return false;
   for(int i=0;i<total;i++)
     {
      CAccount* account=this.m_list_accounts.At(i);
      if(account==NULL)
         continue;
      string file_name=this.m_folder_name+"\\"+account.Server()+" "+(string)account.Login()+".bin";
      if(::FileIsExist(file_name,FILE_COMMON))
         ::FileDelete(file_name,FILE_COMMON);
      ::ResetLastError();
      int handle=::FileOpen(file_name,FILE_WRITE|FILE_BIN|FILE_COMMON);
      if(handle==INVALID_HANDLE)
        {
         ::Print(DFUN,CMessage::Text(MSG_LIB_SYS_FAILED_OPEN_FILE_FOR_WRITE),file_name,". ",CMessage::Text(MSG_LIB_SYS_ERROR),(string)::GetLastError());
         return false;
        }
      res &=account.Save(handle);
      ::FileClose(handle);
     }
   return res;
  }
//+------------------------------------------------------------------+
//| Save account objects from the files to the list                  |
//+------------------------------------------------------------------+
bool CAccountsCollection::LoadObjects(void)
  {
   bool res=true;
   string name="";
   long handle_search=::FileFindFirst(this.m_folder_name+"\\*",name,FILE_COMMON);
   if(handle_search!=INVALID_HANDLE)
     {
      do

}
   return res;
  }
//+------------------------------------------------------------------+
//| Save account objects from the files to the list                  |
//+------------------------------------------------------------------+
bool CAccountsCollection::LoadObjects(void)
  {
   bool res=true;
   string name="";
   long handle_search=::FileFindFirst(this.m_folder_name+"\\*",name,FILE_COMMON);
   if(handle_search!=INVALID_HANDLE)
     {
      do
        {
         string file_name=this.m_folder_name+"\\"+name;
         ::ResetLastError();
         int handle_file=::FileOpen(m_folder_name+"\\"+name,FILE_BIN|FILE_READ|FILE_COMMON);
         if(handle_file!=INVALID_HANDLE)
           {
            CAccount* account=new CAccount();
            if(account!=NULL)
              {
               if(!account.Load(handle_file))
                 {
                  delete account;
                  ::FileClose(handle_file);
                  res &=false;
                  continue;
                 }
               if(this.IsPresent(account))
                 {
                  delete account;
                  ::FileClose(handle_file);
                  res &=false;
                  continue;
                 }
               if(!this.AddToList(account))
                 {
                  delete account;
                  res &=false;
                 }
              }
           }
         ::FileClose(handle_file);
        }
      while(::FileFindNext(handle_search,name));
      ::FileFindClose(handle_search);
     }
   return res;
  }
//+------------------------------------------------------------------+
//| Update the current account data                                  |
//+------------------------------------------------------------------+

void CAccountsCollection::Refresh(void)
  {
   ::ResetLastError();
   if(!::SymbolInfoTick(::Symbol(),this.m_tick))
     {
      this.m_global_error=::GetLastError();
      return;
     }
   if(this.m_index_current==WRONG_VALUE)
      return;
   CAccount* account=this.m_list_accounts.At(this.m_index_current);
   if(account==NULL)
      return;
   account.Refresh();
  }
//+------------------------------------------------------------------+
//| Working with the current account events                          |
//+------------------------------------------------------------------+
void CAccountsCollection::RefreshAndEventsControl(void)
  {
   ::ResetLastError();
   if(!::SymbolInfoTick(::Symbol(),this.m_tick))
     {
      this.m_global_error=::GetLastError();
      return;
     }
   if(this.m_index_current==WRONG_VALUE)
      return;
   this.m_is_event=false;
   this.m_list_events.Clear();
   this.m_list_events.Sort();
   CAccount* account=this.m_list_accounts.At(this.m_index_current);
   if(account==NULL)
      return;
   account.Refresh();
   if(!account.IsEvent())
      return;
   CArrayObj *list=account.GetListEvents();
   if(list==NULL)
      return;
   this.m_is_event=true;
   this.m_event_code=account.GetEventCode();
   int n=list.Total();
   for(int j=0; j<n; j++)
     {
      CEventBaseObj *event=list.At(j);
      if(event==NULL)
         continue;
      this.m_last_event=event.ID();
      if(this.EventAdd((ushort)event.ID(),event.LParam(),event.DParam(),event.SParam()))
        {
         ::EventChartCustom(this.m_chart_id_main,(ushort)event.ID(),event.LParam(),event.DParam(),event.SParam());
        }
     }
  }
//+------------------------------------------------------------------+
//| Return the account event by its number in the list               |
//+------------------------------------------------------------------+
int CAccountsCollection::GetEventID(const int shift=WRONG_VALUE,const bool check_out=true)
  {
   CEventBaseObj *event=this.GetEvent(shift,check_out);
   if(event==NULL)
      return WRONG_VALUE;
   return (int)event.ID();
  }
//+------------------------------------------------------------------+

// CONTEXT: Series: Timeseries in DoEasy library, Part: 54, Title: Timeseries in DoEasy library (part 54): Descendant classes of abstract base indicator - MQL5 Articles | FILE: MQL5.zip/MQL5/Include/DoEasy/Collections/BuffersCollection.mqh
//+------------------------------------------------------------------+
//|                                            BuffersCollection.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                             https://mql5.com/en/users/artmedia70 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://mql5.com/en/users/artmedia70"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include files                                                    |
//+------------------------------------------------------------------+
#include "ListObj.mqh"
#include "..\Objects\Indicators\BufferArrow.mqh"
#include "..\Objects\Indicators\BufferLine.mqh"
#include "..\Objects\Indicators\BufferSection.mqh"
#include "..\Objects\Indicators\BufferHistogram.mqh"
#include "..\Objects\Indicators\BufferHistogram2.mqh"
#include "..\Objects\Indicators\BufferZigZag.mqh"
#include "..\Objects\Indicators\BufferFilling.mqh"
#include "..\Objects\Indicators\BufferBars.mqh"
#include "..\Objects\Indicators\BufferCandles.mqh"
#include "..\Objects\Indicators\BufferCalculate.mqh"
#include "TimeSeriesCollection.mqh"
//+------------------------------------------------------------------+
//| Collection of indicator buffers                                  |
//+------------------------------------------------------------------+
```

---
