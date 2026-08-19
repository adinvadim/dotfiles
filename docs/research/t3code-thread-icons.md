# T3 Code: how thread/sidebar icons are resolved

Repo: [pingdotgg/t3code](https://github.com/pingdotgg/t3code) (MIT, public). All line refs below are
against commit `cebac353defde6211c9e8c3d8ecd140c92042930` (main, 2026-08-18) — the repo is under
active development so exact paths may drift.

## 1. Exact lookup order / candidate paths

The resolver lives in
[`apps/server/src/project/ProjectFaviconResolver.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/server/src/project/ProjectFaviconResolver.ts).
`resolvePath(cwd, faviconPath?)` runs these checks **in order** and returns on the first hit:

1. **Stored per-project override** — the `faviconPath` argument passed in (this is the value the
   user picked in Settings; see §4). If it resolves to an existing file, done.
2. **`t3.json` `iconPath`** — loaded via `T3ProjectFileLoader`, checked only if the override above
   didn't resolve. Comment in source: *"A t3.json iconPath takes precedence over the well-known
   locations."*
3. **Well-known candidate paths**, checked in this exact order (quoted verbatim from
   `FAVICON_CANDIDATES`):

   ```ts
   const FAVICON_CANDIDATES = [
     "favicon.svg",
     "favicon.ico",
     "favicon.png",
     "public/favicon.svg",
     "public/favicon.ico",
     "public/favicon.png",
     "app/favicon.ico",
     "app/favicon.png",
     "app/icon.svg",
     "app/icon.png",
     "app/icon.ico",
     "src/favicon.ico",
     "src/favicon.svg",
     "src/app/favicon.ico",
     "src/app/icon.svg",
     "src/app/icon.png",
     "assets/icon.svg",
     "assets/icon.png",
     "assets/logo.svg",
     "assets/logo.png",
     ".idea/icon.svg",
   ] as const;
   ```

4. **HTML/source `<link rel="icon">` scraping**, checked in this order (quoted verbatim from
   `ICON_SOURCE_FILES`):

   ```ts
   const ICON_SOURCE_FILES = [
     "index.html",
     "public/index.html",
     "app/routes/__root.tsx",
     "src/routes/__root.tsx",
     "app/root.tsx",
     "src/root.tsx",
     "src/index.html",
   ] as const;
   ```

   For each file it reads the source and extracts an icon href via two regexes: an HTML
   `<link rel="icon"|"shortcut icon" href="...">` tag, or (for `.tsx` route files using
   metadata-object icon declarations) a brace-delimited object containing both `rel: "icon"` and
   `href: "..."`. The extracted href is resolved as `public/<href>` first, then `<href>` relative
   to the project root (`resolveIconHref`), and each candidate is checked for existence.

If nothing matches, `resolvePath` returns `null` and the client falls back to a generic folder
icon (see §2).

## 2. How threads inherit project icons

Threads don't resolve icons themselves — everything is per-**project**, and threads just render
whichever project they belong to.

- The client component is
  [`apps/web/src/components/ProjectFavicon.tsx`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/web/src/components/ProjectFavicon.tsx).
  It takes `{ environmentId, cwd, faviconPath? }`, requests a signed asset URL for the
  `"project-favicon"` resource kind, and renders the image, or a `FolderIcon` fallback if
  resolution fails / the image 404s.
- `apps/web/src/components/Sidebar.tsx` renders `<ProjectFavicon environmentId=... cwd=...
  faviconPath={project.faviconPath} />` next to threads grouped under a project — the thread rows
  in the sidebar, `ThreadCommandSubtitle.tsx`, `ChatHeader.tsx`, and `CommandPalette.tsx` all pull
  the same `project.faviconPath` value off the project record and pass it straight into
  `ProjectFavicon`. There's no thread-level icon override — a thread's icon is always its parent
  project's icon.
- On the server, `apps/server/src/assets/AssetAccess.ts` `issueAssetUrl()` handles the
  `"project-favicon"` resource: it normalizes the workspace root, calls
  `ProjectFaviconResolver.resolvePath(workspaceRoot, input.projectFaviconPath)`, hashes the
  resolved file's bytes (SHA-256) into the served filename for cache-busting, and signs a
  short-lived URL (`ASSET_ROUTE_PREFIX = "/api/assets"`). If resolution fails it returns a stable
  `PROJECT_FAVICON_FALLBACK_MARKER` filename, which the client checks via
  `isProjectFaviconFallbackUrl` to decide whether to show the folder fallback icon instead of an
  `<img>`.
- The persisted per-project override field is `faviconPath: string | null` on the project
  projection (see e.g. `apps/server/src/persistence/Migrations/040_ProjectionProjectFaviconPath.test.ts`
  and `apps/server/src/persistence/Layers/ProjectionProjects.ts` / `Services/ProjectionProjects.ts`).
  A "project group" (multiple checkouts of the same repo across environments) shares one
  `faviconPath` — `ProjectSettingsPanel.tsx`'s `updateAllMembers()` fans a single edit out to
  every member project so all checkouts and all threads under them show the same icon.

## 3. How a user can add icons to their own repos (recommended file names)

Anything in the `FAVICON_CANDIDATES` list (§1, step 3) is picked up with **zero configuration** —
no settings, no `t3.json` needed. The most broadly-recommended, framework-agnostic choices, in the
resolver's own priority order:

- `favicon.svg` (repo root) — checked first, SVG preferred.
- `favicon.ico` / `favicon.png` (repo root) — classic fallback.
- `public/favicon.svg|ico|png` — for projects that keep static assets under `public/`.
- `app/icon.svg|png|ico` or `src/app/icon.svg|png` — for Next.js App Router-style layouts
  (`app/` directory convention).
- `assets/logo.svg|png` or `assets/icon.svg|png` — generic "assets" convention.

All of SVG, PNG, ICO, JPEG, GIF, AVIF, and WebP are accepted (per
[`docs/user/project-settings.md`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/docs/user/project-settings.md)),
though the built-in `FAVICON_CANDIDATES` list itself only probes for `.svg/.ico/.png` filenames —
JPEG/GIF/AVIF/WebP files need either a `t3.json` `iconPath` pointing at them or the manual
"Choose file" override in Settings (§4), since they aren't in the auto-probed filename list.

If none of the well-known paths exist but the repo has a standard `index.html` (or a TanStack/
React Router `__root.tsx` / `root.tsx`) with a `<link rel="icon" href="...">` tag, that's honored
too — so a normal Vite/CRA app with a `<link rel="icon" href="/favicon.svg">` in its HTML template
works without any T3-specific setup, even if the target file lives at an unlisted path.

## 4. Overrides — `t3.json` and Settings

Two override layers exist, and the stored Settings pick beats everything, including `t3.json`:

- **`t3.json` `iconPath`** — checked-in, shared with the whole team. Schema (from
  [`packages/contracts/src/t3ProjectFile.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/packages/contracts/src/t3ProjectFile.ts)):

  ```ts
  iconPath: Schema.optionalKey(
    trimmedNonEmpty({
      description:
        'Workspace-relative path to the project icon (e.g. "assets/logo.svg"). Checked before T3 Code\'s built-in icon locations.',
    }, T3_PROJECT_FILE_PATH_MAX_LENGTH),
  ),
  ```

  `t3.json` lives at the workspace root, file name constant `T3_PROJECT_FILE_NAME = "t3.json"`,
  JSON Schema published at `https://t3.codes/schema/t3.json`. Loaded via
  `apps/server/src/project/T3ProjectFileLoader.ts`; malformed/unreadable files are logged and
  treated as absent rather than erroring.

- **Settings → Projects → (select project) → Appearance → "Project icon" → "Choose file"** — a
  per-project-group override stored server-side as `faviconPath` on the project record. UI code:
  `apps/web/src/components/settings/ProjectSettingsPanel.tsx` (~line 784: `SettingsRow title="Project
  icon" description={faviconPath ?? "Automatic"}`, with a reset button that sets it back to `null`
  = "Automatic"). This is what `docs/user/project-settings.md` describes as steps 1–4 ("Open
  Settings and select Projects... Under Appearance, select Choose a project file... To use
  automatic detection again, select Automatic"); the current button label in code is "Choose file"
  (aria-label "Choose a project icon file") rather than literally "Choose a project file", so the
  doc text is describing the same control with slightly paraphrased wording.

  This is exactly the `faviconPath` argument threaded through
  `ProjectFaviconResolver.resolvePath(cwd, faviconPath)` — it's checked **before** `t3.json`
  `iconPath` and before the built-in candidate list (§1, step 1). Per `ProjectSettingsPanel.tsx`'s
  `updateAllMembers`, this override applies to *every checkout* in the project group at once (the
  doc text: *"The selected path applies to each checkout in the project group and appears on your
  connected clients."*).

### Priority summary

```
Settings override (faviconPath, per project group)
  > t3.json iconPath
    > built-in FAVICON_CANDIDATES (fixed order, svg > ico > png per location)
      > <link rel="icon"> scraped from index.html / root route files
        > (none found) folder-icon fallback in the client
```

## Sources

- [`docs/user/project-settings.md`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/docs/user/project-settings.md)
- [`apps/server/src/project/ProjectFaviconResolver.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/server/src/project/ProjectFaviconResolver.ts)
- [`apps/server/src/project/T3ProjectFileLoader.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/server/src/project/T3ProjectFileLoader.ts)
- [`packages/contracts/src/t3ProjectFile.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/packages/contracts/src/t3ProjectFile.ts)
- [`packages/shared/src/t3ProjectFile.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/packages/shared/src/t3ProjectFile.ts)
- [`apps/web/src/components/ProjectFavicon.tsx`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/web/src/components/ProjectFavicon.tsx)
- [`apps/server/src/assets/AssetAccess.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/server/src/assets/AssetAccess.ts)
- [`packages/contracts/src/assets.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/packages/contracts/src/assets.ts)
- [`apps/web/src/components/Sidebar.tsx`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/web/src/components/Sidebar.tsx)
- [`apps/web/src/components/settings/ProjectSettingsPanel.tsx`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/web/src/components/settings/ProjectSettingsPanel.tsx)
- [`apps/server/src/persistence/Migrations/040_ProjectionProjectFaviconPath.test.ts`](https://github.com/pingdotgg/t3code/blob/cebac353defde6211c9e8c3d8ecd140c92042930/apps/server/src/persistence/Migrations/040_ProjectionProjectFaviconPath.test.ts)
