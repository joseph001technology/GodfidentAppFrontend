# GODFIDENT FLUTTER — SESSION PROGRESS

## Reconstruction Summary (Step 0)

- **No prior PROGRESS.md existed** in the repo.
- Git history shows 6 commits; HEAD has uncommitted changes across lib/, pubspec.yaml, generated plugin registrants, and .gitignore.
- The previous agent session **broke `lib/screens/home/home_screen.dart`**: refactored ConsumerWidget → ConsumerStatefulWidget but deleted inner widget classes while keeping call sites. File is 107 lines and **does not compile**.
- All repositories wired to real API via Dio with JWT interceptor + auto-refresh. ✅
- `flutter_secure_storage` for tokens. ✅
- Design system, theme, gradients, ProgressRing, VerseCard, SectionHeader, shimmer/error/empty widgets — all exist and match spec. ✅

---

## Section Status

### Home Tab
- **Status:** ❌ **BROKEN / NOT DONE**
- **What's done:** `verseOfTheDayProvider`, `unreadCountProvider`, `readingProgressProvider`, `currentUserProvider` all wired to real API. `_TopBar` with unread dot exists. `_buildGreeting` exists.
- **What's broken/missing:**
  - `home_screen.dart` does not compile (references undefined inner widgets).
  - Hardcoded local state for prayer/bible check-in instead of API.
  - Hardcoded local `_reminders` list instead of `remindersProvider`.
  - Missing: Today's Progress ring wired to dashboard, Reminders list with toggle/edit, Daily Inspiration tiles, Continue Reading card.
  - Worship Music uses `StaticMusicRepository` (known gap, flagged).

### Bible Tab
- **Status:** ✅ **Done & verified real-API**
- Translations, books (OT/NT toggle), chapter reader, prev/next, per-verse actions, search — all wired.

### Focus Tab
- **Status:** ⚠️ **Partial — heavily mocked UI**
- Start/End Focus, blocked apps CRUD, stats provider wired to real API.
- Missing: Most Used Apps UI, weekly chart, blocked websites/whitelist/schedules UI, blocked-attempt log UI.

### Progress Tab
- **Status:** ⚠️ **Partial — mixed real & hardcoded data**
- Achievement grids wired to real API.
- Broken: Bible Streak card shows prayer longestStreak. Consistency ring hardcoded 0.72. Stats grid hardcoded. Calendar heatmap fake. Motivational card static.

### Settings Tab
- **Status:** ⚠️ **Partial**
- Profile card reads real API. Edit profile partly wired. Change Password wired.
- Missing: About routes, theme toggle, unread dot in nav.

### Notes Module
- **Status:** ⚠️ **Partial — repo done, UI stubs**
- Flat list only. No folder tree, no CRUD actions, no topic filters.

### Universal Rules Module
- **Status:** ⚠️ **Partial — "Today's Rules" only**
- No Full CRUD UI, categories, pin/favorite/archive/reorder actions.

### Reminders Module
- **Status:** ⚠️ **Partial — repo done, UI stubs**
- No CRUD buttons, calendar/timeline, snooze/complete toggles, history, notification scheduling.

### Global Search
- **Status:** ✅ **Done (Bible tab search)**

### Known Gaps (correctly flagged)
1. Worship Music — static, TODO flagged.
2. Per-app screen time — placeholder, returns empty. ✅flagged
3. Mood check-in — client-side only. ✅flagged
4. Native block enforcement — not yet implemented. ✅flagged


---

## Planned Fixes (in priority order)

1. **Fix `home_screen.dart`** — restore all inner widgets, wire real APIs, match spec layout.
2. **Fix Progress tab** — wire streak cards, consistency ring, stats grid, motivational card, calendar heatmap to real API/providers.
3. **Expand Focus tab UI** — add schedules/whitelist screens, blocked attempts, usage note.
4. **Expand Rules UI** — add CRUD, categories, quick actions.
5. **Expand Notes UI** — add folder tree, CRUD actions, topic filters.
6. **Expand Reminders UI** — add action buttons, snooze/complete toggles.
7. **Settings About routes** — add Privacy Policy / Terms entries.
8. **Add unread dot to `ShellScaffold`** bottom nav items.
