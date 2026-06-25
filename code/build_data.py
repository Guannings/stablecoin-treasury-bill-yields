#!/usr/bin/env python3
"""
Build the merged monthly panel for the Econometrics At-Home report.
Sample: Jan 2020 – Apr 2026.
Output: Stablecoin_data_2020_2026.csv  (in the Econometrics workspace folder)

Reads raw files already downloaded into the working directory:
  defillama.json   total stablecoin market cap (daily)
  tb3ms.csv        FRED 3-month T-bill rate (monthly)
  fedfunds.csv     FRED effective fed funds rate (monthly)
  vixcls.csv       FRED CBOE VIX (daily)
  mspd.json        Treasury Fiscal Data MSPD Table 1 (monthly, marketable debt)

Output columns:
  date           first of each month, YYYY-MM-DD
  mcap_bn        total stablecoin market cap, USD billions, end of month
  TB3MS          3-month T-bill rate, percent, monthly average
  FEDFUNDS       effective fed funds rate, percent, monthly average
  VIXCLS         CBOE VIX, monthly mean of daily closes
  bills_mil      marketable T-bills outstanding, $ millions, end of month
  marketable_mil total marketable Treasury debt, $ millions, end of month
  bill_share     bills_mil / marketable_mil  (a fraction in [0,1])
"""

import json
from datetime import datetime
import pandas as pd

START_DATE = "2020-01-01"
END_DATE   = "2026-04-30"
OUT_PATH   = "Stablecoin_data_2020_2026.csv"


# ---------------------------------------------------------------------------
# 1. DefiLlama -> monthly end-of-month stablecoin market cap (USD billions)
# ---------------------------------------------------------------------------

print("Processing DefiLlama...")
with open("defillama.json") as f:
    data = json.load(f)

rows = []
for row in data:
    d  = datetime.utcfromtimestamp(int(row["date"])).date()
    v  = row.get("totalCirculatingUSD", {})
    if isinstance(v, dict):
        mcap = float(v.get("peggedUSD", 0))
    else:
        mcap = float(v or 0)
    rows.append((d, mcap))

sc = pd.DataFrame(rows, columns=["date", "mcap_usd"])
sc["date"] = pd.to_datetime(sc["date"])
sc = sc.set_index("date").sort_index()

sc_eom = sc.resample("ME").last()
sc_eom.index = sc_eom.index.to_period("M").to_timestamp()
sc_eom["mcap_bn"] = sc_eom["mcap_usd"] / 1e9
print(f"  monthly obs: {len(sc_eom)}, range {sc_eom.index.min().date()} -> {sc_eom.index.max().date()}")
print(f"  latest: ${sc_eom['mcap_bn'].iloc[-1]:.1f}B")


# ---------------------------------------------------------------------------
# 2. FRED monthly series (TB3MS, FEDFUNDS)
# ---------------------------------------------------------------------------

def read_fred(path):
    df = pd.read_csv(path)
    date_col = df.columns[0]
    df[date_col] = pd.to_datetime(df[date_col])
    df = df.rename(columns={date_col: "date"}).set_index("date")
    df.iloc[:, 0] = pd.to_numeric(df.iloc[:, 0], errors="coerce")
    return df

tb = read_fred("tb3ms.csv")
ff = read_fred("fedfunds.csv")
print(f"  TB3MS: {tb.index.min().date()} -> {tb.index.max().date()}")
print(f"  FEDFUNDS: {ff.index.min().date()} -> {ff.index.max().date()}")


# ---------------------------------------------------------------------------
# 3. FRED daily VIX -> monthly mean
# ---------------------------------------------------------------------------

vx_daily = read_fred("vixcls.csv")
vx_monthly = vx_daily.resample("MS").mean()
print(f"  VIXCLS (monthly mean): {vx_monthly.index.min().date()} -> {vx_monthly.index.max().date()}")


# ---------------------------------------------------------------------------
# 4. Treasury MSPD -> bills outstanding, total marketable, bill_share
# ---------------------------------------------------------------------------

print("Processing MSPD...")
with open("mspd.json") as f:
    js = json.load(f)
mspd = pd.DataFrame(js["data"])
mspd["record_date"]   = pd.to_datetime(mspd["record_date"])
mspd["total_mil_amt"] = pd.to_numeric(mspd["total_mil_amt"], errors="coerce")
mspd = mspd[mspd["security_type_desc"] == "Marketable"].copy()

piv = mspd.pivot_table(index="record_date",
                      columns="security_class_desc",
                      values="total_mil_amt",
                      aggfunc="sum")
print(f"  MSPD security classes: {list(piv.columns)}")

# Sum of marketable categories; exclude any 'Total Marketable' row that the API
# might emit as a separate class (double-counts otherwise).
known_marketable = [c for c in piv.columns
                    if c.lower().strip() in {"bills", "notes", "bonds",
                                              "treasury inflation-protected securities",
                                              "floating rate notes",
                                              "federal financing bank"}]
bills      = piv["Bills"]
marketable = piv[known_marketable].sum(axis=1)
bs = pd.DataFrame({"bills_mil": bills, "marketable_mil": marketable})
bs["bill_share"] = bs["bills_mil"] / bs["marketable_mil"]
bs.index = bs.index.to_period("M").to_timestamp()
bs = bs.groupby(bs.index).last()
print(f"  bill_share range: {bs['bill_share'].min():.3f} – {bs['bill_share'].max():.3f}")
print(f"  bill_share at latest available date: {bs['bill_share'].iloc[-1]:.3f}")


# ---------------------------------------------------------------------------
# 5. Merge + trim
# ---------------------------------------------------------------------------

panel = (sc_eom[["mcap_bn"]]
         .join(tb,         how="outer")
         .join(ff,         how="outer")
         .join(vx_monthly, how="outer")
         .join(bs,         how="outer"))
panel = panel.loc[START_DATE:END_DATE].sort_index()
panel.index.name = "date"

required = ["mcap_bn", "TB3MS", "FEDFUNDS", "VIXCLS", "bill_share"]
panel_clean = panel.dropna(subset=required)
print(f"\nFinal merged panel: {len(panel_clean)} complete monthly observations")
print(f"  range: {panel_clean.index.min().date()} to {panel_clean.index.max().date()}")
print("\nFirst 3 rows:")
print(panel_clean.head(3).to_string())
print("\nLast 3 rows:")
print(panel_clean.tail(3).to_string())

panel_clean.to_csv(OUT_PATH, date_format="%Y-%m-%d", float_format="%.6f")
print(f"\nWrote {OUT_PATH}")
