#!/usr/bin/env python3
"""Grid live relay (KKP-GRID-RELAY-1.0).

Runs on a GitHub Actions schedule. Fetches ISO/RTO real-time load and fuel mix
through the open-source gridstatus library (the operators' public endpoints do
not allow browser access), plus EIA-930 when an EIA_API_KEY secret is set, and
writes live.json and door.json for the static Grid app. Nothing is estimated:
an ISO that fails is reported with its error, not filled in.

  python tools/grid/relay.py --previous previous.json --out out/
"""
import argparse
import concurrent.futures as cf
import json
import math
import os
import platform
import sys
import time
from datetime import datetime, timedelta, timezone

ISOS = [
    ("CAISO", "California ISO", "CAISO", {}),
    ("ERCOT", "Electric Reliability Council of Texas", "Ercot", {}),
    ("ISONE", "ISO New England", "ISONE", {}),
    ("MISO", "Midcontinent ISO", "MISO", {}),
    ("NYISO", "New York ISO", "NYISO", {}),
    ("SPP", "Southwest Power Pool", "SPP", {}),
    ("PJM", "PJM Interconnection", "PJM", {"needs": "PJM_API_KEY"}),
]
HISTORY_HOURS = 24
CALL_TIMEOUT = 75


def now_utc():
    return datetime.now(timezone.utc)


def iso_time(ts):
    try:
        import pandas as pd
        t = pd.Timestamp(ts)
        if t.tzinfo is None:
            t = t.tz_localize("UTC")
        return t.tz_convert("UTC").strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return str(ts)


def time_col(df):
    for c in ("Interval End", "Interval Start", "Time", "time"):
        if c in df.columns:
            return c
    return None


def latest_row(df):
    tc = time_col(df)
    if tc:
        df = df.sort_values(tc)
    return df.iloc[-1], (df.iloc[-1][tc] if tc else None)


def call_with_timeout(fn, *a):
    with cf.ThreadPoolExecutor(max_workers=1) as ex:
        return ex.submit(fn, *a).result(timeout=CALL_TIMEOUT)


def fetch_iso(code, cls_name):
    import gridstatus
    iso = getattr(gridstatus, cls_name)()
    out = {"load_mw": None, "time": None, "fuel_mix": None, "fuel_time": None, "errors": {}}
    try:
        df = call_with_timeout(iso.get_load, "today")
        row, t = latest_row(df)
        col = "Load" if "Load" in df.columns else [c for c in df.columns if c.lower() == "load"][0]
        v = float(row[col])
        if math.isfinite(v):
            out["load_mw"], out["time"] = round(v, 1), iso_time(t)
    except Exception as e:  # noqa: BLE001
        out["errors"]["load"] = f"{type(e).__name__}: {str(e)[:200]}"
    try:
        df = call_with_timeout(iso.get_fuel_mix, "today")
        row, t = latest_row(df)
        skip = {"Time", "Interval Start", "Interval End", "time"}
        mix = {}
        for c in df.columns:
            if c in skip:
                continue
            try:
                v = float(row[c])
            except (TypeError, ValueError):
                continue
            if math.isfinite(v):
                mix[str(c)] = round(v, 1)
        out["fuel_mix"], out["fuel_time"] = mix, iso_time(t)
    except Exception as e:  # noqa: BLE001
        out["errors"]["fuel_mix"] = f"{type(e).__name__}: {str(e)[:200]}"
    if code == "ERCOT":
        try:
            st = call_with_timeout(iso.get_status, "latest")
            out["status"] = getattr(st, "status", None)
            out["reserves_mw"] = getattr(st, "reserves", None)
        except Exception as e:  # noqa: BLE001
            out["errors"]["status"] = f"{type(e).__name__}: {str(e)[:200]}"
    return out


def fetch_eia(key):
    import requests
    base = "https://api.eia.gov/v2/electricity/rto"
    start = (now_utc() - timedelta(hours=50)).strftime("%Y-%m-%dT%H")

    def get(route, facets):
        params = [("api_key", key), ("frequency", "hourly"), ("data[0]", "value"), ("start", start),
                  ("sort[0][column]", "period"), ("sort[0][direction]", "desc"), ("length", "5000")]
        for k, vs in facets.items():
            params += [(f"facets[{k}][]", v) for v in vs]
        r = requests.get(f"{base}/{route}/data/", params=params, timeout=60)
        r.raise_for_status()
        return r.json()

    regions = ["CAL", "CAR", "CENT", "FLA", "MIDA", "MIDW", "NE", "NW", "NY", "SE", "SW", "TEN", "TEX"]
    balance = get("region-data", {"respondent": ["US48"]})
    fuel = get("fuel-type-data", {"respondent": ["US48"]})
    reg = get("region-data", {"respondent": regions, "type": ["D"]})
    rows = lambda d: (d.get("response") or {}).get("data") or []  # noqa: E731
    series = {}
    for r in rows(balance):
        series.setdefault(r["type"], []).append({"t": r["period"], "v": float(r["value"]) if r["value"] is not None else None})
    for k in series:
        series[k].sort(key=lambda p: p["t"])
    fuel_by = {}
    for r in rows(fuel):
        if r["value"] is not None:
            fuel_by.setdefault(r["period"], {})[r["fueltype"]] = float(r["value"])
    hours = sorted(fuel_by)
    full = [h for h in hours if len(fuel_by[h]) >= 6]
    fh = full[-1] if full else (hours[-1] if hours else None)
    regs = {}
    for r in rows(reg):
        if r["value"] is not None:
            regs.setdefault(r["respondent"], []).append({"t": r["period"], "v": float(r["value"])})
    for k in regs:
        regs[k].sort(key=lambda p: p["t"])
    return {"series": series, "fuelHour": fh, "fuel": fuel_by.get(fh), "regions": regs}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--previous", default="")
    ap.add_argument("--out", default="out")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    prev = {}
    if a.previous and os.path.exists(a.previous):
        try:
            prev = json.load(open(a.previous, encoding="utf-8"))
        except Exception:  # noqa: BLE001
            prev = {}
    t0 = time.time()
    isos = {}
    jobs = {}
    with cf.ThreadPoolExecutor(max_workers=4) as ex:
        for code, name, cls_name, meta in ISOS:
            if meta.get("needs") and not os.environ.get(meta["needs"]):
                isos[code] = {"name": name, "skipped": f"set the {meta['needs']} repository secret to enable"}
                continue
            jobs[code] = (name, ex.submit(fetch_iso, code, cls_name))
        for code, (name, fut) in jobs.items():
            try:
                isos[code] = {"name": name, **fut.result(timeout=CALL_TIMEOUT * 3)}
            except Exception as e:  # noqa: BLE001
                isos[code] = {"name": name, "errors": {"fetch": f"{type(e).__name__}: {str(e)[:200]}"}}
    cutoff = now_utc() - timedelta(hours=HISTORY_HOURS)
    for code, d in isos.items():
        hist = list(((prev.get("isos") or {}).get(code) or {}).get("history") or [])
        if d.get("load_mw") is not None and d.get("time"):
            if not hist or hist[-1][0] != d["time"]:
                hist.append([d["time"], d["load_mw"]])
        keep = []
        for t, v in hist:
            try:
                if datetime.fromisoformat(t.replace("Z", "+00:00")) >= cutoff:
                    keep.append([t, v])
            except ValueError:
                continue
        d["history"] = keep[-400:]
    eia = None
    eia_error = None
    if os.environ.get("EIA_API_KEY"):
        try:
            eia = fetch_eia(os.environ["EIA_API_KEY"])
        except Exception as e:  # noqa: BLE001
            eia_error = f"{type(e).__name__}: {str(e)[:200]}"
    else:
        eia_error = "set the EIA_API_KEY repository secret to enable"
    try:
        import gridstatus
        gs_version = getattr(gridstatus, "__version__", "?")
    except Exception:  # noqa: BLE001
        gs_version = None
    run = os.environ.get("GITHUB_RUN_ID")
    repo = os.environ.get("GITHUB_REPOSITORY", "nicholaskouns-create/Identity")
    snap = {
        "schema": "KKP-GRID-RELAY-1.0",
        "generated_utc": now_utc().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "elapsed_s": round(time.time() - t0, 1),
        "run": f"https://github.com/{repo}/actions/runs/{run}" if run else None,
        "versions": {"python": platform.python_version(), "gridstatus": gs_version},
        "isos": isos,
        "eia": eia,
        "eia_error": eia_error,
        "note": "Values are the publishers' own real-time numbers as returned by their public endpoints at generated_utc. Missing values carry their error.",
    }
    us48 = None
    if eia and eia.get("series", {}).get("D"):
        last = [p for p in eia["series"]["D"] if p.get("v") is not None]
        if last:
            us48 = {"mw": last[-1]["v"], "hour": last[-1]["t"]}
    door = {"generated_utc": snap["generated_utc"], "us48": us48,
            "isos_live": sum(1 for d in isos.values() if d.get("load_mw") is not None),
            "iso_load_mw": round(sum(d.get("load_mw") or 0 for d in isos.values()), 1)}
    json.dump(snap, open(os.path.join(a.out, "live.json"), "w", encoding="utf-8"), separators=(",", ":"))
    json.dump(door, open(os.path.join(a.out, "door.json"), "w", encoding="utf-8"), separators=(",", ":"))
    with open(os.path.join(a.out, "README.md"), "w", encoding="utf-8") as fh:
        fh.write("# grid-live\n\nMachine-written snapshot branch for Grid (identity/grid). Rewritten every run by "
                 "`.github/workflows/grid-live.yml`; history is not kept here.\n")
    print(json.dumps({k: (v.get("load_mw"), v.get("time"), list((v.get("errors") or {}).keys()) or v.get("skipped")) for k, v in isos.items()}, indent=1))
    print("eia:", "ok" if eia else eia_error)
    return 0


if __name__ == "__main__":
    sys.exit(main())
