import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import {
  SettingsManager,
  type ExtensionAPI,
  type ExtensionContext,
  type ToolCallEvent,
  type ToolResultEvent,
} from "@mariozechner/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";

type InternalSettingsManager = SettingsManager & {
  globalSettings: Record<string, unknown>;
  markModified(field: string, nestedKey?: string): void;
  save(): void;
};

type TrackedWrite = {
  absolutePath: string;
  oldContent: string;
};

type SessionLineStatsEntry = {
  added: number;
  removed: number;
  path?: string;
  toolName?: string;
  toolCallId?: string;
};

type SessionLineStatsResetEntry = {
  reason?: string;
  timestamp: number;
};

const FAST_SETTINGS_KEY = "pi-codex-fast";
const LINE_STATS_ENTRY = "session-line-stats";
const LINE_STATS_RESET_ENTRY = "session-line-stats-reset";
const CONVENTIONAL_COMMIT_TYPES = [
  "build",
  "chore",
  "ci",
  "docs",
  "feat",
  "fix",
  "perf",
  "refactor",
  "revert",
  "style",
  "test",
] as const;
const CONVENTIONAL_COMMIT_PATTERN = new RegExp(
  `^(?:${CONVENTIONAL_COMMIT_TYPES.join("|")})(?:\\([\\w./-]+\\))?(?:!)?:\\s+\\S.+$`,
);
const SECRET_PATTERNS: Array<{ label: string; pattern: RegExp }> = [
  { label: "private key", pattern: /BEGIN [A-Z ]*PRIVATE KEY/ },
  { label: "OpenAI-style API key", pattern: /\bsk-[A-Za-z0-9]{16,}\b/ },
  { label: "GitHub token", pattern: /\bgh[pousr]_[A-Za-z0-9]{20,}\b/ },
  { label: "AWS access key", pattern: /\bAKIA[0-9A-Z]{16}\b/ },
  {
    label: "secret-like assignment",
    pattern: /(?:api[_-]?key|token|password|passwd|secret|client[_-]?secret|access[_-]?key)\s*[:=]\s*["'][^"'\n]{8,}["']/i,
  },
];

const settingsManagers = new Map<string, SettingsManager>();

function getSettingsManager(cwd: string): SettingsManager {
  const existing = settingsManagers.get(cwd);
  if (existing) return existing;

  const manager = SettingsManager.create(cwd);
  settingsManagers.set(cwd, manager);
  return manager;
}

function asObject(value: unknown): Record<string, unknown> | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  return value as Record<string, unknown>;
}

function mergeSettings(
  base: Record<string, unknown>,
  overrides: Record<string, unknown>,
): Record<string, unknown> {
  const merged: Record<string, unknown> = { ...base };
  for (const [key, overrideValue] of Object.entries(overrides)) {
    const baseValue = merged[key];
    if (
      baseValue &&
      typeof baseValue === "object" &&
      !Array.isArray(baseValue) &&
      overrideValue &&
      typeof overrideValue === "object" &&
      !Array.isArray(overrideValue)
    ) {
      merged[key] = mergeSettings(
        baseValue as Record<string, unknown>,
        overrideValue as Record<string, unknown>,
      );
      continue;
    }
    merged[key] = overrideValue;
  }
  return merged;
}

function getEffectiveSettings(settingsManager: SettingsManager): Record<string, unknown> {
  return mergeSettings(
    settingsManager.getGlobalSettings() as Record<string, unknown>,
    settingsManager.getProjectSettings() as Record<string, unknown>,
  );
}

function reportSettingsErrors(
  settingsManager: SettingsManager,
  ctx: ExtensionContext,
  action: "load" | "write",
): void {
  if (!ctx.hasUI) return;
  for (const { scope, error } of settingsManager.drainErrors()) {
    ctx.ui.notify(`status-footer: failed to ${action} ${scope} settings: ${error.message}`, "warning");
  }
}

function supportsPriorityServiceTier(ctx: ExtensionContext): boolean {
  return ctx.model?.provider === "openai" || ctx.model?.provider === "openai-codex";
}

function stripToolPathPrefix(rawPath: string): string {
  return rawPath.startsWith("@") ? rawPath.slice(1) : rawPath;
}

function resolveToolPath(cwd: string, rawPath: string): string {
  return path.resolve(cwd, stripToolPathPrefix(rawPath));
}

async function readFileOrEmpty(absolutePath: string): Promise<string> {
  try {
    return await fs.readFile(absolutePath, "utf8");
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ENOENT") return "";
    throw error;
  }
}

async function computeNumstat(oldContent: string, newContent: string): Promise<{ added: number; removed: number }> {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "pi-session-lines-"));
  const beforePath = path.join(tempDir, "before.txt");
  const afterPath = path.join(tempDir, "after.txt");

  try {
    await fs.writeFile(beforePath, oldContent, "utf8");
    await fs.writeFile(afterPath, newContent, "utf8");

    const { stdout } = await gitExec(["diff", "--no-index", "--numstat", "--no-color", "--", beforePath, afterPath]);
    const line = stdout
      .split(/\r?\n/)
      .map((value) => value.trim())
      .find(Boolean);

    if (!line) return { added: 0, removed: 0 };

    const [addedRaw, removedRaw] = line.split("\t");
    const added = Number(addedRaw);
    const removed = Number(removedRaw);
    return {
      added: Number.isFinite(added) ? added : 0,
      removed: Number.isFinite(removed) ? removed : 0,
    };
  } finally {
    await fs.rm(tempDir, { recursive: true, force: true });
  }
}

async function execCommand(
  command: string,
  args: string[],
  options?: { cwd?: string; allowExitCodes?: number[] },
): Promise<{ stdout: string; stderr: string; code: number }> {
  const { execFile } = await import("node:child_process");
  const allowExitCodes = new Set(options?.allowExitCodes ?? [0]);

  return await new Promise((resolve, reject) => {
    execFile(
      command,
      args,
      { cwd: options?.cwd, encoding: "utf8", maxBuffer: 1024 * 1024 },
      (error, stdout, stderr) => {
        if (error) {
          const codeValue = (error as NodeJS.ErrnoException & { code?: string | number }).code;
          const code = typeof codeValue === "number" ? codeValue : 1;
          if (allowExitCodes.has(code)) {
            resolve({ stdout, stderr, code });
            return;
          }
          reject(error);
          return;
        }

        resolve({ stdout, stderr, code: 0 });
      },
    );
  });
}

async function gitExec(
  args: string[],
  options?: { cwd?: string; allowExitCodes?: number[] },
): Promise<{ stdout: string; stderr: string; code: number }> {
  return await execCommand("git", args, { cwd: options?.cwd, allowExitCodes: options?.allowExitCodes ?? [0, 1] });
}

function getConventionalCommitError(message: string): string | null {
  if (CONVENTIONAL_COMMIT_PATTERN.test(message)) return null;
  return `Commit message must follow Conventional Commits (${CONVENTIONAL_COMMIT_TYPES.join(", ")}). Example: feat(pi): add commit slash commands`;
}

async function resolveCommitMessage(rawArgs: string, ctx: ExtensionContext): Promise<string | null> {
  const trimmed = rawArgs.trim();
  if (trimmed) return trimmed;
  if (!ctx.hasUI) {
    throw new Error("Commit message required. Usage: /commit feat(scope): subject");
  }

  const input = await ctx.ui.input("Conventional Commit", "feat(scope): subject");
  const value = input?.trim();
  return value ? value : null;
}

async function assertNoSecretsInStagedDiff(cwd: string): Promise<void> {
  const { stdout } = await gitExec(["diff", "--cached", "--no-color"], { cwd });
  const matched = SECRET_PATTERNS.find(({ pattern }) => pattern.test(stdout));
  if (!matched) return;
  throw new Error(`Possible secret detected in staged diff (${matched.label}). Review staged changes before commit.`);
}

async function getCurrentBranch(cwd: string): Promise<string> {
  const { stdout } = await gitExec(["rev-parse", "--abbrev-ref", "HEAD"], { cwd });
  return stdout.trim();
}

async function pushCurrentBranch(cwd: string): Promise<string> {
  const branch = await getCurrentBranch(cwd);
  const upstream = await gitExec(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"], {
    cwd,
    allowExitCodes: [0, 128],
  });

  if (upstream.code === 0 && upstream.stdout.trim()) {
    await gitExec(["push"], { cwd, allowExitCodes: [0] });
    return branch;
  }

  await gitExec(["push", "-u", "origin", "HEAD"], { cwd, allowExitCodes: [0] });
  return branch;
}

async function ensurePullRequest(cwd: string): Promise<{ url: string; created: boolean }> {
  await execCommand("gh", ["--version"], { cwd, allowExitCodes: [0] });

  const existing = await execCommand("gh", ["pr", "view", "--json", "url", "--jq", ".url"], {
    cwd,
    allowExitCodes: [0, 1],
  });
  const existingUrl = existing.stdout.trim();
  if (existing.code === 0 && existingUrl) {
    return { url: existingUrl, created: false };
  }

  await execCommand("gh", ["pr", "create", "--fill"], { cwd, allowExitCodes: [0] });
  const created = await execCommand("gh", ["pr", "view", "--json", "url", "--jq", ".url"], {
    cwd,
    allowExitCodes: [0],
  });
  return { url: created.stdout.trim(), created: true };
}

function loadPersistedFastMode(cwd: string): boolean | undefined {
  const settingsManager = getSettingsManager(cwd);
  settingsManager.reload();
  const settings = getEffectiveSettings(settingsManager);
  const extensionSettings = asObject(settings[FAST_SETTINGS_KEY]);
  return typeof extensionSettings?.enabled === "boolean" ? extensionSettings.enabled : undefined;
}

function persistFastMode(enabled: boolean, cwd: string): SettingsManager {
  const settingsManager = getSettingsManager(cwd) as InternalSettingsManager;
  settingsManager.reload();
  const globalSettings = settingsManager.getGlobalSettings() as Record<string, unknown>;
  const extensionSettings = asObject(globalSettings[FAST_SETTINGS_KEY]) ?? {};
  settingsManager.globalSettings[FAST_SETTINGS_KEY] = {
    ...extensionSettings,
    enabled,
  };
  settingsManager.markModified(FAST_SETTINGS_KEY);
  settingsManager.save();
  return settingsManager;
}

function isToolCallEventType<TInput>(toolName: string, event: ToolCallEvent): event is ToolCallEvent & { input: TInput } {
  return event.toolName === toolName;
}

function isToolResultEventType<TInput>(toolName: string, event: ToolResultEvent): event is ToolResultEvent & { input: TInput } {
  return event.toolName === toolName;
}

function diffStatsFromUnifiedDiff(diff: string): { added: number; removed: number } {
  let added = 0;
  let removed = 0;

  for (const line of diff.split(/\r?\n/)) {
    if (!line) continue;
    if (line.startsWith("+++") || line.startsWith("---") || line.startsWith("@@")) continue;
    if (line.startsWith("+")) added++;
    else if (line.startsWith("-")) removed++;
  }

  return { added, removed };
}

function formatCompactNumber(value: number): string {
  if (value < 1000) return `${value}`;
  if (value < 10_000) return `${(value / 1000).toFixed(1)}k`;
  if (value < 1_000_000) return `${Math.round(value / 1000)}k`;
  if (value < 10_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  return `${Math.round(value / 1_000_000)}M`;
}

function formatContextUsage(ctx: ExtensionContext, autoCompactEnabled: boolean, theme: ExtensionContext["ui"]["theme"]): string {
  const usage = ctx.getContextUsage();
  const contextWindow = usage?.contextWindow ?? ctx.model?.contextWindow ?? 0;
  const percentValue = usage?.percent ?? 0;
  const percent = usage?.percent !== null ? percentValue.toFixed(1) : "?";
  const autoIndicator = autoCompactEnabled ? " (auto)" : "";
  const display = `${percent}%/${formatCompactNumber(contextWindow)}${autoIndicator}`;

  if (usage?.percent === null) return theme.fg("dim", `?/${formatCompactNumber(contextWindow)}${autoIndicator}`);
  if (percentValue > 90) return theme.fg("error", display);
  if (percentValue > 70) return theme.fg("warning", display);
  return display;
}

export default function statusFooterExtension(pi: ExtensionAPI): void {
  const pendingWrites = new Map<string, TrackedWrite>();

  let fastModeEnabled = false;
  let autoCompactEnabled = true;
  let addedLines = 0;
  let removedLines = 0;
  let requestFooterRender: (() => void) | null = null;
  let settingsWriteQueue: Promise<void> = Promise.resolve();

  function renderFooter(ctx: ExtensionContext): void {
    ctx.ui.setFooter((tui, theme, footerData) => {
      requestFooterRender = () => tui.requestRender();
      const unsubscribeBranch = footerData.onBranchChange(() => tui.requestRender());

      return {
        dispose() {
          requestFooterRender = null;
          unsubscribeBranch();
        },
        invalidate() {},
        render(width: number): string[] {
          const leftParts = [
            theme.fg("success", `+${formatCompactNumber(addedLines)}`),
            theme.fg("error", `-${formatCompactNumber(removedLines)}`),
            formatContextUsage(ctx, autoCompactEnabled, theme),
            fastModeEnabled ? theme.fg("accent", "fast") : theme.fg("dim", "std"),
          ];

          const extraStatuses = [...footerData.getExtensionStatuses().entries()]
            .filter(([key, value]) => key !== "fast-priority" && value)
            .map(([, value]) => value);
          if (extraStatuses.length > 0) leftParts.push(extraStatuses.join(" "));

          const branch = footerData.getGitBranch();
          const model = ctx.model?.id ?? "no-model";
          const right = theme.fg("dim", branch ? `${model} (${branch})` : model);
          const left = leftParts.join(theme.fg("dim", " · "));

          const pad = " ".repeat(Math.max(1, width - visibleWidth(left) - visibleWidth(right)));
          return [truncateToWidth(left + pad + right, width)];
        },
      };
    });
  }

  function refreshFooter(): void {
    requestFooterRender?.();
  }

  function resetLineTotalsFromSession(ctx: ExtensionContext): void {
    addedLines = 0;
    removedLines = 0;

    const branch = ctx.sessionManager.getBranch();
    let startIndex = 0;
    for (let i = branch.length - 1; i >= 0; i--) {
      const entry = branch[i]!;
      if (entry.type === "custom" && entry.customType === LINE_STATS_RESET_ENTRY) {
        startIndex = i + 1;
        break;
      }
    }

    const relevantEntries = branch.slice(startIndex);
    const trackedToolCalls = new Set<string>();

    for (const entry of relevantEntries) {
      if (entry.type !== "custom" || entry.customType !== LINE_STATS_ENTRY) continue;
      const data = entry.data as SessionLineStatsEntry | undefined;
      if (!data) continue;
      addedLines += typeof data.added === "number" ? data.added : 0;
      removedLines += typeof data.removed === "number" ? data.removed : 0;
      if (data.toolCallId) trackedToolCalls.add(data.toolCallId);
    }

    for (const entry of relevantEntries) {
      if (entry.type !== "message" || entry.message.role !== "toolResult") continue;
      if (entry.message.toolName !== "edit") continue;
      if (trackedToolCalls.has(entry.message.toolCallId)) continue;

      const diff = (entry.message.details as { diff?: string } | undefined)?.diff;
      if (!diff) continue;

      const stats = diffStatsFromUnifiedDiff(diff);
      addedLines += stats.added;
      removedLines += stats.removed;
    }

    refreshFooter();
  }

  async function appendLineStats(
    added: number,
    removed: number,
    pathValue: string,
    toolName: string,
    toolCallId: string,
  ): Promise<void> {
    if (added === 0 && removed === 0) return;
    addedLines += added;
    removedLines += removed;
    pi.appendEntry<SessionLineStatsEntry>(LINE_STATS_ENTRY, {
      added,
      removed,
      path: pathValue,
      toolName,
      toolCallId,
    });
    refreshFooter();
  }

  function resetSessionLineStats(reason: string): void {
    addedLines = 0;
    removedLines = 0;
    pi.appendEntry<SessionLineStatsResetEntry>(LINE_STATS_RESET_ENTRY, {
      reason,
      timestamp: Date.now(),
    });
    refreshFooter();
  }

  function persistState(enabled: boolean, ctx: ExtensionContext): void {
    const cwd = ctx.cwd;
    settingsWriteQueue = settingsWriteQueue
      .catch(() => undefined)
      .then(async () => {
        const settingsManager = persistFastMode(enabled, cwd);
        await settingsManager.flush();
        reportSettingsErrors(settingsManager, ctx, "write");
      });

    void settingsWriteQueue.catch((error) => {
      if (!ctx.hasUI) return;
      const message = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`status-footer: failed to write settings: ${message}`, "warning");
    });
  }

  function notifyFastMode(ctx: ExtensionContext): void {
    if (!ctx.hasUI) return;
    if (!fastModeEnabled) {
      ctx.ui.notify("Fast mode disabled.", "info");
      return;
    }

    if (supportsPriorityServiceTier(ctx)) {
      ctx.ui.notify("Fast mode enabled. OpenAI/OpenAI Codex requests use service_tier=priority.", "info");
      return;
    }

    const modelLabel = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "no active model";
    ctx.ui.notify(`Fast mode enabled. Applies on OpenAI/OpenAI Codex models (current: ${modelLabel}).`, "info");
  }

  function setFastMode(enabled: boolean, ctx: ExtensionContext, options?: { persist?: boolean; notify?: boolean }): void {
    fastModeEnabled = enabled;
    if (options?.persist !== false) persistState(enabled, ctx);
    if (options?.notify !== false) notifyFastMode(ctx);
    refreshFooter();
  }

  function reloadCompactionState(ctx: ExtensionContext): void {
    try {
      const settingsManager = getSettingsManager(ctx.cwd);
      settingsManager.reload();
      autoCompactEnabled = settingsManager.getCompactionEnabled();
      reportSettingsErrors(settingsManager, ctx, "load");
    } catch (error) {
      autoCompactEnabled = true;
      if (ctx.hasUI) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`status-footer: failed to load compaction settings: ${message}`, "warning");
      }
    }
  }

  async function reloadFastModeState(
    ctx: ExtensionContext,
    options?: { includeStartupFlag?: boolean },
  ): Promise<void> {
    await settingsWriteQueue.catch(() => undefined);
    fastModeEnabled = false;

    try {
      const settingsManager = getSettingsManager(ctx.cwd);
      const persistedEnabled = loadPersistedFastMode(ctx.cwd);
      reportSettingsErrors(settingsManager, ctx, "load");
      if (typeof persistedEnabled === "boolean") {
        fastModeEnabled = persistedEnabled;
      }
    } catch (error) {
      if (ctx.hasUI) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`status-footer: failed to load settings: ${message}`, "warning");
      }
    }

    if (options?.includeStartupFlag && pi.getFlag("fast") === true) {
      fastModeEnabled = true;
    }

    refreshFooter();
  }

  async function trackSuccessfulWrite(event: ToolResultEvent & { input: { path: string } }, ctx: ExtensionContext): Promise<void> {
    const tracked = pendingWrites.get(event.toolCallId);
    pendingWrites.delete(event.toolCallId);
    if (!tracked) return;

    const newContent = await readFileOrEmpty(tracked.absolutePath);
    const { added, removed } = await computeNumstat(tracked.oldContent, newContent);
    await appendLineStats(added, removed, event.input.path, event.toolName, event.toolCallId);
  }

  async function runCommitWorkflow(
    rawArgs: string,
    ctx: ExtensionContext,
    options: { push: boolean; pullRequest: boolean },
  ): Promise<void> {
    const message = await resolveCommitMessage(rawArgs, ctx);
    if (!message) return;

    const validationError = getConventionalCommitError(message);
    if (validationError) {
      throw new Error(validationError);
    }

    await gitExec(["rev-parse", "--show-toplevel"], { cwd: ctx.cwd, allowExitCodes: [0] });

    const statusBefore = await gitExec(["status", "--short"], { cwd: ctx.cwd, allowExitCodes: [0] });
    if (!statusBefore.stdout.trim()) {
      throw new Error("No git changes to commit.");
    }

    await gitExec(["add", "-A"], { cwd: ctx.cwd, allowExitCodes: [0] });
    const stagedDiff = await gitExec(["diff", "--cached", "--stat"], { cwd: ctx.cwd, allowExitCodes: [0] });
    if (!stagedDiff.stdout.trim()) {
      throw new Error("No staged changes to commit after git add -A.");
    }

    await assertNoSecretsInStagedDiff(ctx.cwd);
    await gitExec(["commit", "-m", message], { cwd: ctx.cwd, allowExitCodes: [0] });
    resetSessionLineStats("git-commit");

    let branch = "";
    if (options.push || options.pullRequest) {
      branch = await getCurrentBranch(ctx.cwd);
      if (options.pullRequest && (branch === "main" || branch === "master")) {
        throw new Error("Refusing to open a PR from main/master. Create or switch to a feature branch first.");
      }
      branch = await pushCurrentBranch(ctx.cwd);
    }

    if (options.pullRequest) {
      const { url, created } = await ensurePullRequest(ctx.cwd);
      if (ctx.hasUI) {
        ctx.ui.notify(created ? `Committed, pushed, PR created: ${url}` : `Committed, pushed, PR already exists: ${url}`, "info");
      }
      return;
    }

    if (options.push) {
      if (ctx.hasUI) ctx.ui.notify(`Committed and pushed ${branch || "current branch"}.`, "info");
      return;
    }

    if (ctx.hasUI) {
      ctx.ui.notify("Committed changes and reset session line counters.", "info");
    }
  }

  pi.registerFlag("fast", {
    description: "Start with fast mode enabled (adds service_tier=priority to OpenAI/OpenAI Codex requests)",
    type: "boolean",
    default: false,
  });

  pi.registerCommand("codex-fast", {
    description: "Toggle OpenAI/OpenAI Codex priority service tier",
    handler: async (_args, ctx) => {
      setFastMode(!fastModeEnabled, ctx);
    },
  });

  pi.registerCommand("commit", {
    description: "git add -A + git commit with Conventional Commits enforcement",
    handler: async (args, ctx) => {
      await runCommitWorkflow(args, ctx, { push: false, pullRequest: false });
    },
  });

  pi.registerCommand("commit-push", {
    description: "git add -A + git commit + git push with Conventional Commits enforcement",
    handler: async (args, ctx) => {
      await runCommitWorkflow(args, ctx, { push: true, pullRequest: false });
    },
  });

  pi.registerCommand("commit-push-pr", {
    description: "git add -A + git commit + git push + gh pr create --fill",
    handler: async (args, ctx) => {
      await runCommitWorkflow(args, ctx, { push: true, pullRequest: true });
    },
  });

  pi.on("session_start", async (_event, ctx) => {
    pendingWrites.clear();
    renderFooter(ctx);
    reloadCompactionState(ctx);
    resetLineTotalsFromSession(ctx);
    await reloadFastModeState(ctx, { includeStartupFlag: true });
  });

  pi.on("session_switch", async (_event, ctx) => {
    pendingWrites.clear();
    renderFooter(ctx);
    reloadCompactionState(ctx);
    resetLineTotalsFromSession(ctx);
    await reloadFastModeState(ctx, { includeStartupFlag: true });
  });

  pi.on("session_fork", async (_event, ctx) => {
    pendingWrites.clear();
    resetLineTotalsFromSession(ctx);
  });

  pi.on("session_tree", async (_event, ctx) => {
    pendingWrites.clear();
    resetLineTotalsFromSession(ctx);
  });

  pi.on("model_select", async (_event, _ctx) => {
    refreshFooter();
  });

  pi.on("tool_call", async (event, ctx) => {
    if (isToolCallEventType<{ path: string }>("write", event) || isToolCallEventType<{ path: string }>("edit", event)) {
      const absolutePath = resolveToolPath(ctx.cwd, event.input.path);
      try {
        pendingWrites.set(event.toolCallId, {
          absolutePath,
          oldContent: await readFileOrEmpty(absolutePath),
        });
      } catch (error) {
        pendingWrites.set(event.toolCallId, {
          absolutePath,
          oldContent: "",
        });
        if (ctx.hasUI) {
          const message = error instanceof Error ? error.message : String(error);
          ctx.ui.notify(`status-footer: failed to snapshot previous file contents: ${message}`, "warning");
        }
      }
    }
  });

  pi.on("tool_result", async (event, ctx) => {
    if (event.isError) {
      pendingWrites.delete(event.toolCallId);
      return;
    }

    if (isToolResultEventType<{ path: string }>("write", event) || isToolResultEventType<{ path: string }>("edit", event)) {
      try {
        await trackSuccessfulWrite(event, ctx);
      } catch (error) {
        pendingWrites.delete(event.toolCallId);
        if (ctx.hasUI) {
          const message = error instanceof Error ? error.message : String(error);
          ctx.ui.notify(`status-footer: failed to track line stats: ${message}`, "warning");
        }
      }
    }
  });

  pi.on("before_provider_request", (event, ctx) => {
    const payload = event.payload;
    if (
      !fastModeEnabled ||
      !supportsPriorityServiceTier(ctx) ||
      !payload ||
      typeof payload !== "object" ||
      Array.isArray(payload)
    ) {
      return;
    }

    if (Object.prototype.hasOwnProperty.call(payload, "service_tier")) {
      return;
    }

    return {
      ...(payload as Record<string, unknown>),
      service_tier: "priority",
    };
  });
}
