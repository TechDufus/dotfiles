"""Three-way merge of Tern settings.json documents."""

_MISSING = object()


def _merge(repo, live, base, path, conflicts):
    merged = {}
    keys = list(live) + [k for k in repo if k not in live] + [k for k in base if k not in live and k not in repo]
    for key in keys:
        r, l, b = repo.get(key, _MISSING), live.get(key, _MISSING), base.get(key, _MISSING)
        if r == l or l == b:
            value = r  # agree, or only the repo changed it
        elif r == b:
            value = l  # only the app changed it
        elif isinstance(r, dict) and isinstance(l, dict) and (isinstance(b, dict) or b is _MISSING):
            value = _merge(r, l, b if isinstance(b, dict) else {}, path + [key], conflicts)
        else:
            value = r  # both changed it: the repo wins, the app's value is reported
            conflicts.append({
                "key": ".".join(path + [key]),
                "repo": None if r is _MISSING else r,
                "app": None if l is _MISSING else l,
            })
        if value is not _MISSING:
            merged[key] = value
    return merged


def tern_three_way_merge(repo, live, base):
    """Merge per key: a side that changed since `base` (the last synced document) wins.

    A key missing from one side but present in `base` was removed on that side. When both
    sides changed the same key differently, nested objects are merged key by key and
    anything else takes the repo's value and is listed in `conflicts`.
    """
    conflicts = []
    merged = _merge(repo or {}, live or {}, base or {}, [], conflicts)
    return {"merged": merged, "conflicts": conflicts}


class FilterModule:
    def filters(self):
        return {"tern_three_way_merge": tern_three_way_merge}
