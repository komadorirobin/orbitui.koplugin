-- bookshelf_view_mode.lua
-- Which presentation the shelf grid uses: covers or list.
--
-- Deliberately a pure function of its inputs rather than state anywhere, so
-- the whole decision is testable headless and there is exactly one place that
-- answers "which mode am I in".
--
-- ── THE MODEL: a chip pin, defaulting to AUTO ──────────────────────────────
--
-- Unset retains OrbitUI's legacy policy: covers collapsed at the top level,
-- list when expanded or drilled in. Explicit Auto uses the 5.4.3 drill-level
-- choices below, including at the expanded top level. Explicit covers/list/
-- spines pins apply at every depth. No stored preference is migrated.

local ViewMode = {}

ViewMode.COVERS = "covers"
ViewMode.LIST   = "list"
ViewMode.AUTO   = "auto"
-- Physical bookcase style, explicitly pinned or chosen for an Auto level.
ViewMode.SPINES = "spines"

-- effective(expanded, in_folder) -> ViewMode.COVERS | ViewMode.LIST
--
-- The legacy unset/search policy: a list wherever the reader is scanning many items
-- (expanded, or drilled into anything), covers on the two rows under the
-- hero. A pinned chip never reaches this -- the caller checks the pin first.
function ViewMode.effective(expanded, in_folder)
    if expanded or in_folder then return ViewMode.LIST end
    return ViewMode.COVERS
end

-- ── AUTO BY LEVEL (5.4.3) ──────────────────────────────────────────────────
--
-- An Auto chip says which style each drill level wears: Level 1 its top level
-- (collapsed OR expanded, maintainer 2026-10-11: levels are drill depth, not
-- screen size), Level 2 everything drilled into below it (folders in folders,
-- series inside an author). Each is covers, list or spines, cycled from two
-- buttons in Shelf style as the sort levels are. Unset is today's Auto: covers
-- on top, a list inside. Expanded at the top level now follows Level 1, so an
-- explicitly saved Auto shelf shows covers expanded where it showed a list.
-- OrbitUI's unset shelves still use effective(), not this level policy.
--
-- A shelf of shelves has only Level 1: opening a sub-shelf switches to it
-- (its own Show as and levels), so nothing in it is ever drilled into.
ViewMode.LEVEL_KEYS     = { "view_level1", "view_level2" }
ViewMode.LEVEL_DEFAULTS = { ViewMode.COVERS, ViewMode.LIST }
ViewMode.LEVEL_CYCLE    = { ViewMode.COVERS, ViewMode.LIST, ViewMode.SPINES }

-- levelMode(value, level) -> the style stored for that level, or its default
-- for absence or anything this build does not know.
function ViewMode.levelMode(value, level)
    if value == ViewMode.COVERS or value == ViewMode.LIST or value == ViewMode.SPINES then
        return value
    end
    return ViewMode.LEVEL_DEFAULTS[level] or ViewMode.COVERS
end

-- auto(tab, drilled) -> the style an Auto chip shows: Level 2's when drilled
-- into anything, else Level 1's.
function ViewMode.auto(tab, drilled)
    tab = tab or {}
    if drilled then return ViewMode.levelMode(tab[ViewMode.LEVEL_KEYS[2]], 2) end
    return ViewMode.levelMode(tab[ViewMode.LEVEL_KEYS[1]], 1)
end

-- nextLevelMode(value, level, no_spines) -> the next style in the cycle from
-- the one that level shows now; spines left out for a catalogue.
function ViewMode.nextLevelMode(value, level, no_spines)
    local cur = ViewMode.levelMode(value, level)
    local cycle = ViewMode.LEVEL_CYCLE
    for i, m in ipairs(cycle) do
        if m == cur then
            local nxt = cycle[i % #cycle + 1]
            if no_spines and nxt == ViewMode.SPINES then nxt = cycle[(i + 1) % #cycle + 1] end
            return nxt
        end
    end
    return ViewMode.LEVEL_DEFAULTS[level]
end

-- ── LIST DENSITY BY LEVEL (5.4.4) ──────────────────────────────────────────
--
-- An Auto shelf showing a list on BOTH levels has two sets of list columns and
-- rows, one per level (maintainer: a list of authors and the list of one
-- author's books want different densities). Level 2's are the same keys with
-- LEVEL2_SUFFIX, stored on the tab beside Level 1's. Unset, Level 2 follows
-- Level 1, so a shelf set up before this looks as it did. Anywhere else (one
-- level a list, or a List pin) there is one set, the plain keys, as before.
ViewMode.LEVEL2_SUFFIX = "_l2"
-- true: unset follows Level 1. list_rows_expanded is the zoom of an expanded
-- list, tied to its own level's row count and cleared to mean "fill at the new
-- height", so Level 2's never borrows Level 1's.
ViewMode.LEVEL_LIST_KEYS = { list_columns = true, list_rows = true, list_rows_expanded = false }

-- listLevelsSplit(tab) -> true when the tab is Auto with List on both levels.
function ViewMode.listLevelsSplit(tab)
    tab = tab or {}
    return ViewMode.chipOverride(tab[ViewMode.CHIP_KEY]) == ViewMode.AUTO
        and ViewMode.auto(tab, false) == ViewMode.LIST
        and ViewMode.auto(tab, true) == ViewMode.LIST
end

-- densityKeys(tab, key, level) -> the key to read first, and the key to fall
-- back to (nil when there is none). Level 2 of a split tab reads its own key
-- and, for columns and rows, falls back to Level 1's; everything else is the
-- plain key alone.
function ViewMode.densityKeys(tab, key, level)
    local inherits = ViewMode.LEVEL_LIST_KEYS[key]
    if level == 2 and inherits ~= nil and ViewMode.listLevelsSplit(tab) then
        return key .. ViewMode.LEVEL2_SUFFIX, inherits and key or nil
    end
    return key, nil
end

function ViewMode.isList(mode) return mode == ViewMode.LIST end
function ViewMode.isSpines(mode) return mode == ViewMode.SPINES end

-- ── THE PER-CHIP OVERRIDE ──────────────────────────────────────────────────
--
-- A chip may pin itself to either mode, outranking the Auto policy.
-- Stored as tab.view_mode, persisted with the rest of the chip by
-- TabModel.save, and edited in the same picker as the chip's folder tile style
-- -- as its own SECTION of that picker, not as extra values in it.
--
-- The two were briefly one field, with "list" living among the tile styles.
-- The maintainer split them, and the reason is that they are genuinely
-- independent: a chip needs to be able to say "divider cards" without also
-- asserting a view mode, and "always a list" without throwing away the tile
-- style it would use if it ever showed tiles again. Merged, every tile style
-- silently meant "and never a list here", which also quietly reinterpreted
-- every chip in every existing library -- group_display has shipped for
-- several releases.
--
-- UNSET is the fourth state and the fork default: AUTO. Absence rather than a
-- sentinel keeps existing profiles on the automatic policy, while AUTO is
-- also accepted as an explicit stored value alongside the other two.
-- No labels here, and no gettext require: this file is a pure function of its
-- arguments so the whole decision is testable headless, and pulling in i18n for
-- three strings would end that. The chip editor owns the wording.
ViewMode.CHIP_KEY = "view_mode"

-- chipOverride(value) -> COVERS | LIST | AUTO | nil
--
-- nil for anything this build does not recognise -- including the absence
-- that means the automatic default -- so a hand-edited chip, or one written
-- by a later release, falls back safely rather than reaching a renderer as a
-- mode it has no branch for.
function ViewMode.chipOverride(value)
    if value == ViewMode.LIST or value == ViewMode.COVERS
            or value == ViewMode.AUTO or value == ViewMode.SPINES then
        return value
    end
    return nil
end

-- chipPin(value) -> COVERS | LIST | AUTO | SPINES
-- Native helper: OrbitUI's widget and editor handle the legacy unset policy
-- before using this Covers-default resolver.
--
-- chipOverride answers "is there a recognised value stored?" and returns nil
-- for absence. chipPin answers the question the CALLER usually has -- "which
-- mode is this chip in?" -- and absence is not a missing answer to that one:
-- unset IS covers, and has been since the default flipped.
--
-- Both exist because the difference matters in exactly one place: the picker
-- needs chipOverride to know whether to light the Auto radio, and chipPin to
-- know which density controls belong to the mode. It had only the first, so
-- a Covers chip -- stored as nil -- failed a `mode ~= COVERS` test and was
-- offered the list's column and row nudges, controls for a view it is
-- pinned away from.
function ViewMode.chipPin(value)
    return ViewMode.chipOverride(value) or ViewMode.COVERS
end

return ViewMode
