# stablecoin-treasury-bill-yields

Does dollar-pegged stablecoin issuance push down short-term U.S. Treasury yields, and does the effect intensify when T-bills are scarce? A transparent monthly-frequency OLS test on U.S. data from January 2020 to April 2026 (T = 76 months, effective N = 74 after two lags), regressing the monthly change in the 3-month T-bill yield on lagged stablecoin market-cap growth, a bill-scarcity dummy, their interaction, and macro controls (change in the fed-funds rate, VIX, a post-UST-collapse dummy). The baseline specification produces the predicted negative signs on both stablecoin terms but is statistically insignificant. Under the more internally consistent specification — where volatility enters in monthly changes rather than levels — the state-dependent interaction term is large, negative, and marginally significant at the 10% level: β₃ = −2.37 (Newey–West HAC *t* = −1.89, *p* = 0.063), implying a yield decline of roughly 50 basis points per two-standard-deviation stablecoin inflow during scarcity months. The headline pattern of the BIS / Fed / arXiv literature survives at monthly frequency with a third-year-undergraduate toolkit — consistent in sign, larger in magnitude, and noisier. Built in SAS; the merged panel is reproducible from raw public APIs in Python.

## TL;DR

| Specification | Term | Estimate (bp) | HAC SE | t | p |
|---|---|---:|---:|---:|---:|
| Baseline (VIX in levels) | LagDSC (avg effect) | −0.047 | 0.071 | −0.66 | 0.510 |
| Baseline (VIX in levels) | LagDSC × SCAR (interaction) | −0.228 | 1.283 | −0.18 | 0.860 |
| **Preferred (VIX in changes)** | **LagDSC × SCAR** | **−2.375** | **1.255** | **−1.89** | **0.063** |
| Preferred (VIX in changes) | SCAR (level shift) | +17.00 | 6.011 | +2.83 | 0.006 |
| Both specs | DFF (fed-funds passthrough) | +0.44 to +0.92 | — | 4.2 to 6.7 | <.0001 |

Joint test that stablecoins have no effect (baseline): *F*(2,67) = 0.07, *p* = 0.93 — not rejected. Baseline adj. *R*² = 0.749. The only robust regressor across every specification is the contemporaneous change in the fed-funds rate, which is exactly what front-end yield theory predicts.

## What the result means

The baseline regression cannot distinguish the stablecoin coefficients from zero: with 74 monthly observations and a dependent variable whose standard deviation is 23 bp, the test has little power against the 2-to-3-bp daily-frequency effects reported in the literature. The signal only emerges in the state-dependent specification once volatility is entered as a monthly change — the form consistent with the rest of the (first-differenced) model. There, the interaction term says that during bill-scarcity months a one-percentage-point increase in lagged stablecoin growth predicts a ≈2.4 bp decline in the 3-month yield, so a two-standard-deviation inflow (≈22 pp) maps to a ≈50 bp conditional decline. That is directionally consistent with Ahmed and Aldasoro (2025) and Jacewitz (2025) but several times larger, which is what one expects when a clean daily-IV effect is aggregated up to noisy monthly OLS.

The honest takeaway is sign-consistent, significance-fragile: the data lean the way the front-end-demand mechanism predicts, the interaction is marginally significant in the preferred specification, but a monthly OLS on six years of data is underpowered to pin down the magnitude.

## Quickstart

The analysis runs in SAS. The merged panel ships with the repo, so you can reproduce every table without touching the raw data:

```sas
/* edit the LIBPATH at the top of the program to point at ./data */
%let LIBPATH = /path/to/stablecoin-treasury-bill-yields/data;
%include "/path/to/stablecoin-treasury-bill-yields/code/Stablecoin_Tbill_OLS.sas";
```

`Stablecoin_Tbill_OLS.sas` reads `Stablecoin_data_2020_2026.csv`, builds the model variables, and writes every table (descriptives, baseline OLS, HAC, two robustness checks, residual diagnostics) to an RTF. `Stablecoin_Tbill_OLS_min.sas` is a stripped-down version that runs only the baseline regression and the HAC table.

To rebuild the panel from scratch from the raw public sources:

```bash
cd code
python build_data.py     # merges DeFiLlama + FRED + Treasury MSPD into the monthly panel
python build_data2.py    # rebuild / refresh variant
```

`build_data.py` requires Python 3 with `pandas`.

## What's in this repo

| Path | Purpose |
|---|---|
| `paper/Stablecoin-Issuance-and-US-Treasury-Bill-Yields.pdf` | Full writeup: abstract, literature, hypotheses, data, model, results, robustness, conclusion. |
| `docs/MODEL.md` | Full mathematical derivation: variables, marginal effects, HAC inference, identification. |
| `code/Stablecoin_Tbill_OLS.sas` | Primary SAS program. Import → variable construction → descriptives → OLS → Newey–West HAC → two robustness checks → residual diagnostics. |
| `code/Stablecoin_Tbill_OLS_min.sas` | Minimal SAS program (baseline + HAC only). |
| `code/build_data.py` | Builds the merged monthly panel from the raw API dumps. |
| `code/build_data2.py` | Alternate / refresh build script. |
| `data/Stablecoin_data_2020_2026.csv` | The merged monthly panel actually used in estimation. |
| `data/raw/` | Raw source dumps (see table below). |
| `results/stablecoin_results-new.pdf` | SAS regression output (all tables). |
| `references/Stablecoin_refs.ris` | Bibliography (RIS). The cited working papers themselves are copyrighted and are **not** redistributed here. |

`data/raw/` contents:

| File | Series | Source |
|---|---|---|
| `defillama.json` | Total stablecoin market cap, daily | DeFiLlama API |
| `usdt.json`, `usdc.json` | Per-issuer market cap | DeFiLlama API |
| `tb3ms.csv` | 3-month T-bill rate, monthly | FRED (`TB3MS`) |
| `fedfunds.csv` | Effective fed-funds rate, monthly | FRED (`FEDFUNDS`) |
| `vixcls.csv` | CBOE VIX, daily | FRED (`VIXCLS`) |
| `mspd.json` | Marketable Treasury debt by category | U.S. Treasury Fiscal Data, MSPD Table 1 |

## Method

### Sample

Monthly U.S. data, 2020M1–2026M4. Two lags are lost building the lagged-growth regressor, leaving **N = 74** observations. Of these, 17 months fall in the bill-scarcity state and 47 fall after the Terra/UST collapse (June 2022 onward).

### Variables

Rate variables are in basis points; growth is in percent.

| Variable | Definition |
|---|---|
| `DY3M` | Monthly change in the 3-month T-bill yield, `100 × (TB3MS_t − TB3MS_{t-1})` |
| `LagDSC` | Lagged monthly % growth in total stablecoin market cap, `100 × (mcap_{t-1} − mcap_{t-2}) / mcap_{t-2}` |
| `DFF` | Monthly change in the effective fed-funds rate, bp |
| `SCAR` | Bill-scarcity dummy = 1 if `bill_share` is in its bottom quartile |
| `DSC_x_SCAR` | Interaction, `LagDSC` × `SCAR` |
| `POST_UST` | 1 for months ≥ June 2022 (Terra/UST collapse) |

### Model

The baseline specification is estimated by OLS:

```math
\Delta y_t^{3M} = \beta_0 + \beta_1\, \Delta SC_{t-1} + \beta_2\, SCAR_t + \beta_3\,(\Delta SC_{t-1} \times SCAR_t) + \beta_4\, \Delta FF_t + \beta_5\, VIX_t + \beta_6\, D_t^{\mathrm{UST}} + \varepsilon_t
```

where `DY3M` is the monthly change in the 3-month T-bill yield, `LagDSC` is lagged stablecoin market-cap growth, `SCAR` is the bill-scarcity dummy, `DFF` the fed-funds change, `VIX` the volatility control, and `POST_UST` the post-Terra/UST-collapse dummy.

> **Full mathematical derivation** — variable construction, the marginal-effect algebra behind H1/H2, the Newey–West HAC estimator, the joint F-tests, and the identification discussion — is in **[docs/MODEL.md](docs/MODEL.md)**.

The two hypotheses of interest are:

```math
H_1:\ \beta_1 < 0 \quad\text{(stablecoin inflows lower the average short-end yield)}
```

```math
H_2:\ \beta_3 < 0 \quad\text{(the effect is amplified when bills are scarce)}
```

and the total conditional effect during scarcity months is β₁ + β₃. Standard errors are reported both classically and with the Newey–West HAC estimator (4 lags) to handle serial correlation and heteroskedasticity in the monthly residuals.

## Data sources

- **Stablecoin market cap:** DeFiLlama API — total circulating USD-pegged stablecoin supply, resampled to end-of-month, converted to USD billions.
- **Interest rates and volatility:** FRED — `TB3MS` (3-month secondary-market T-bill rate), `FEDFUNDS` (effective fed-funds rate), `VIXCLS` (CBOE VIX, monthly mean of daily closes).
- **Bill scarcity:** U.S. Treasury Fiscal Data API, Monthly Statement of the Public Debt (MSPD) Table 1 — marketable bills as a share of total marketable debt; the bottom quartile of this share defines the scarcity state.

## Results

### Baseline regression — Newey–West HAC SE, N = 74, adj. R² = 0.749

| Variable | Estimate | HAC SE | t | p |
|---|---:|---:|---:|---:|
| Intercept | 1.953 | 5.002 | 0.39 | 0.698 |
| LagDSC | −0.047 | 0.071 | −0.66 | 0.510 |
| SCAR | −1.655 | 7.364 | −0.22 | 0.823 |
| LagDSC × SCAR | −0.228 | 1.283 | −0.18 | 0.860 |
| DFF | 0.920\*\*\* | 0.136 | 6.74 | <.0001 |
| VIX (level) | −0.005 | 0.230 | −0.02 | 0.984 |
| POST_UST | −1.471 | 2.514 | −0.59 | 0.560 |

Joint tests: no stablecoin effect *F*(2,67)=0.07, *p*=0.929; total scarcity effect β₁+β₃=0 not rejected, *F*(1,67)=0.06, *p*=0.800. Signs are as predicted on both stablecoin terms; none is individually or jointly significant.

### Preferred specification — HAC SE, VIX in changes, adj. R² = 0.774

| Variable | Estimate | HAC SE | t | p |
|---|---:|---:|---:|---:|
| Intercept | 2.042 | 2.091 | 0.98 | 0.332 |
| LagDSC | −0.076 | 0.060 | −1.26 | 0.214 |
| SCAR | 17.002 | 6.011 | 2.83 | 0.006 |
| **LagDSC × SCAR** | **−2.375** | **1.255** | **−1.89** | **0.063** |
| DFF | 0.437 | 0.103 | 4.23 | <.0001 |
| ΔVIX | −0.011 | 0.308 | −0.04 | 0.971 |
| POST_UST | −4.164 | 2.331 | −1.79 | 0.079 |

Entering volatility as a monthly change (`ΔVIX`) rather than a level is the internally consistent choice given that everything else in the model is first-differenced. In that specification the state-dependent interaction becomes economically large and marginally significant, while the fed-funds passthrough remains the dominant, highly significant driver throughout.

## Caveats and known limitations

Discussed at length in the paper; the short version:

- **Monthly aggregation is low-powered.** The literature identifies the effect on daily data with instruments; collapsing to monthly OLS discards most of the variation and inflates the point estimate. A non-rejection in the baseline is weak evidence, not evidence of no effect.
- **No causal identification.** Lagging the stablecoin regressor and adding macro controls mitigates but does not eliminate simultaneity; this is descriptive multiple regression, not an IV or event-study design. The point is to ask whether the published pattern *survives* at this frequency with undergraduate methods, not to improve on the identification.
- **Specification sensitivity.** The headline interaction is significant only when VIX enters in changes; it is insignificant when VIX enters in levels. The conclusion is reported as sign-consistent and significance-fragile for exactly this reason.
- **Quartile scarcity dummy is coarse.** `SCAR` is a bottom-quartile indicator of the bill share; a continuous interaction (robustness check 2) is also reported, but the discrete dummy is the headline.
- **Short, unusual sample.** 2020–2026 spans COVID, the fastest hiking cycle in decades, and the Terra/UST collapse. The `POST_UST` dummy absorbs a level shift but not regime-dependent slope changes.

## Future work

- A daily-frequency version with a Fed-funds-futures or crypto-idiosyncratic instrument to recover a clean causal estimate.
- Per-issuer decomposition (USDT vs USDC) using the raw issuer series already in `data/raw/`.
- A continuous, theory-grounded scarcity measure rather than a quartile dummy.
- Extending the sample as more post-2026 data accrue to raise power.

## References

Full bibliography in [`references/Stablecoin_refs.ris`](references/Stablecoin_refs.ris). Key sources:

- Ahmed, R., & Aldasoro, I. (2025). *Stablecoins and Safe Asset Prices.* BIS Working Paper No. 1270.
- Jacewitz, S. (2025). *Stablecoins Could Increase Treasury Demand, but Only by Reducing Demand for Other Assets.* Federal Reserve Bank of Kansas City.
- Ante, L., Saggu, A., & Fiedler, I. (2025). *The Stablecoin Discount.* arXiv:2505.12413.
- Vayanos, D., & Vila, J.-L. (2021). *A Preferred-Habitat Model of the Term Structure of Interest Rates.* NBER WP 15487.
- Greenwood, R., & Vayanos, D. (2014). *Bond Supply and Excess Bond Returns.* NBER WP 13806.

The cited working papers are copyrighted by their respective publishers and are **not** redistributed here.

## License

Code: MIT (see `LICENSE`). The paper PDF and figures are the author's academic work, © 2026 PARVAUX, all rights reserved.

---

## Notes

**Development.** The research question, specification, and interpretation are my own; AI assistance was used for coding and drafting.

**Scope.** Produced as an undergraduate Econometrics report. For educational and research purposes only — not financial advice, and not a causal estimate. A non-rejection of the null is not evidence that the null is true, and the reported magnitudes are best read as rough conditional correlations from a short monthly sample. Raw data are redistributed as static dumps for reproducibility and may differ from providers' current values. Software provided "as is", without warranty of any kind.
