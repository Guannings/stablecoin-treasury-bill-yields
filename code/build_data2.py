#!/usr/bin/env python3
"""
Rebuild the merged monthly panel using ONLY USDT + USDC stablecoin market cap
(the two fiat-reserve-backed issuers whose proceeds map mechanically into
T-bill demand). Sample: Jan 2020 - Apr 2026.

Reads raw files in the working directory:
  usdt.json, usdc.json   DefiLlama per-stablecoin history (id 1 and id 2)
  tb3ms.csv, fedfunds.csv, vixcls.csv   FRED
  mspd.json   Treasury MSPD Table 1

Overwrites: Stablecoin_data_2020_2026.csv  (in the Econometrics workspace folder)
"""

import json
from datetime import datetime
import pandas as pd

START_DATE = "2020-01-01"
END_DATE   = "2026-04-30"
OUT_PATH   = "Stablecoin_data_2020_2026.csv"


def llama_series(path):
    """Read one DefiLlama per-stablecoin JSON into a daily mcap_usd Series."""
    with open(path) as f:
        data = json.load(f)
    rows = []
    for row in data:
        d = datetime.utcfromtimestamp(int(row["date"])).date()
        v = row.get("totalCirculatingUSD", {})
        mcap = float(v.get("peggedUSD", 0)) if isinstance(v, dict) else float(v or 0)
        rows.append((d, mcap))
    s = pd.DataFrame(rows, columns=["date", "mcap"])
    s["date"] = pd.to_datetime(s["date"])
    return s.set_index("date").sort_index()["mcap"]


print("Processing USDT + USDC...")
usdt = llama_series("usdt.json")
usdc = llama_series("usdc.json")
# Align on the union of dates, fill gaps, then sum the two issuers
combined = pd.concat([usdt, usdc], axis=1, keys=["usdt", "usdc"]).sort_index()
combined = combined.ffill().fillna(0)
combined["sc"] = combined["usdt"] + combined["usdc"]

sc_eom = combined[["sc"]].resample("ME").last()
sc_eom.index = sc_eom.index.to_period("M").to_timestamp()
sc_eom["mcap_bn"] = sc_eom["sc"] / 1e9
print(f"  monthly obs: {len(sc_eom)}, latest USDT+USDC: ${sc_eom['mcap_bn'].iloc[-1]:.1f}B")


def read_fred(path):
    df = pd.read_csv(path)
    dc = df.columns[0]
    df[dc] = pd.to_datetime(df[dc])
    df = df.rename(columns={dc: "date"}).set_index("date")
    df.iloc[:, 0] = pd.to_numeric(df.iloc[:, 0], errors="coerce")
    return df

tb = read_fred("tb3ms.csv")
ff = read_fred("fedfunds.csv")
vx_monthly = read_fred("vixcls.csv").resample("MS").mean()
vx_monthly.columns = ["VIXCLS"]

print("Processing MSPD...")
with open("mspd.json") as f:
    mspd = pd.DataFrame(json.load(f)["data"])
mspd["record_date"]   = pd.to_datetime(mspd["record_date"])
mspd["total_mil_amt"] = pd.to_numeric(mspd["total_mil_amt"], errors="coerce")
mspd = mspd[mspd["security_type_desc"] == "Marketable"].copy()
piv = mspd.pivot_table(index="record_date", columns="security_class_desc",
                      values="total_mil_amt", aggfunc="sum")
known = [c for c in piv.columns if c.lower().strip() in
         {"bills", "notes", "bonds", "treasury inflation-protected securities",
          "floating rate notes", "federal financing bank"}]
bs = pd.DataFrame({"bills_mil": piv["Bills"], "marketable_mil": piv[known].sum(axis=1)})
bs["bill_share"] = bs["bills_mil"] / bs["marketable_mil"]
bs.index = bs.index.to_period("M").to_timestamp()
bs = bs.groupby(bs.index).last()

panel = (sc_eom[["mcap_bn"]]
         .join(tb, how="outer").join(ff, how="outer")
         .join(vx_monthly, how="outer").join(bs, how="outer"))
panel = panel.loc[START_DATE:END_DATE].sort_index()
panel.index.name = "date"

required = ["mcap_bn", "TB3MS", "FEDFUNDS", "VIXCLS", "bill_share"]
clean = panel.dropna(subset=required)
print(f"\nFinal panel: {len(clean)} complete monthly obs, "
      f"{clean.index.min().date()} to {clean.index.max().date()}")
print(clean.head(2).to_string())
print("...")
print(clean.tail(2).to_string())

clean.to_csv(OUT_PATH, date_format="%Y-%m-%d", float_format="%.6f")
print(f"\nOverwrote {OUT_PATH}")
