# The Econometric Model — Math & Identification

This page derives the model behind the repository in full: the variable construction, the regression equation, the marginal-effect algebra that defines the two hypotheses, the estimator, and the inference. It is the mathematical companion to the paper in [`paper/`](../paper) and the SAS program in [`code/`](../code).

All rate variables are in **basis points (bp)**, stablecoin growth is in **percent (pp)**, and the sample is monthly, 2020M1–2026M4, with *T* = 76 raw months and *N* = 74 after two months are lost building the lagged growth term.

---

## 1. Notation

Let *r*ₜ be the 3-month Treasury-bill secondary-market rate (FRED `TB3MS`, in %), *f*ₜ the effective fed-funds rate (`FEDFUNDS`, %), SCₜ the end-of-month combined USDT + USDC market cap (USD), and *b*ₜ the marketable-bill share of total marketable Treasury debt (Treasury MSPD).

The regressors are all built as **changes, growth rates, or 0/1 indicators** — never levels:

```math
\Delta y_t^{3M} = 100\,(r_t - r_{t-1}) \qquad \text{(dependent variable, bp)}
```

```math
\Delta SC_{t-1} = 100\cdot\frac{SC_{t-1} - SC_{t-2}}{SC_{t-2}} \qquad \text{(lagged stablecoin growth, pp)}
```

```math
\Delta FF_t = 100\,(f_t - f_{t-1}) \qquad \text{(fed-funds change, bp)}
```

```math
SCAR_t = \mathbf{1}\!\left\{\, b_t \le Q_{0.25}(b) \,\right\} \qquad \text{(bill-scarcity dummy)}
```

```math
D_t^{UST} = \mathbf{1}\!\left\{\, t \ge \text{2022M6} \,\right\} \qquad \text{(post-Terra/UST structural break)}
```

where *Q*₀.₂₅(*b*) is the in-sample lower quartile of the bill share, so SCARₜ = 1 in the 25% of months with the scarcest bills (17 of 74 months). The volatility control Vₜ is either the level VIXₜ (baseline) or its change ΔVIXₜ = VIXₜ − VIXₜ₋₁ (preferred specification).

---

## 2. The regression model

The model is estimated by ordinary least squares:

```math
\Delta y_t^{3M} = \beta_0 + \beta_1\,\Delta SC_{t-1} + \beta_2\,SCAR_t + \beta_3\,\big(\Delta SC_{t-1}\cdot SCAR_t\big) + \beta_4\,\Delta FF_t + \beta_5\,V_t + \beta_6\,D_t^{UST} + \varepsilon_t
```

In matrix form, stack the regressors into a design matrix X whose rows are

```math
\mathbf{x}_t = (1,\ \Delta SC_{t-1},\ SCAR_t,\ \Delta SC_{t-1}\cdot SCAR_t,\ \Delta FF_t,\ V_t,\ D_t^{UST})'
```

with coefficient vector β = (β₀, …, β₆)′, giving

```math
\mathbf{y} = X\boldsymbol\beta + \boldsymbol\varepsilon, \qquad X \in \mathbb{R}^{N\times 7}.
```

### Why differences, not levels

Treasury yields and stablecoin market cap are highly persistent (near unit-root) in levels. Regressing one persistent series on another invites **spurious regression** — inflated *t*-statistics and a high *R*² that reflect common trends rather than a real relationship. Differencing and using growth rates produces approximately **stationary** series (constant mean and variance), which is the regime under which the OLS standard errors and *t*/*F* tests behave correctly. This is also why mixing one *level* regressor (VIXₜ) among differenced ones is functionally inconsistent, motivating the preferred ΔVIXₜ specification.

---

## 3. Marginal effects and state-dependence

The interaction term makes the effect of stablecoin growth **conditional on the scarcity state**. Taking the partial derivative of the conditional mean with respect to lagged stablecoin growth:

```math
\frac{\partial\, \mathbb{E}\!\left[\Delta y_t^{3M}\mid \mathbf{x}_t\right]}{\partial\, \Delta SC_{t-1}} \;=\; \beta_1 + \beta_3\, SCAR_t \;=\;
\begin{cases}
\beta_1 & \text{normal months } (SCAR_t = 0)\\[4pt]
\beta_1 + \beta_3 & \text{scarcity months } (SCAR_t = 1)
\end{cases}
```

So β₁ is the slope when bills are abundant, and β₁ + β₃ is the slope when bills are scarce. The interaction coefficient β₃ is exactly the **extra** yield response attributable to scarcity.

This yields the two testable hypotheses:

```math
H_1:\ \beta_1 < 0 \qquad \text{(stablecoin inflows lower the average short-end yield)}
```

```math
H_2:\ \beta_3 < 0 \qquad \text{(the effect is amplified when bills are scarce)}
```

and a derived joint prediction that the **total effect during scarcity months** is negative:

```math
\beta_1 + \beta_3 < 0.
```

### Translating the coefficient into basis points

Using the preferred specification, β₁ = −0.076 and β₃ = −2.375, so during scarcity the slope is

```math
\hat\beta_1 + \hat\beta_3 = -0.076 - 2.375 \approx -2.45 \ \text{bp per pp of stablecoin growth.}
```

The sample standard deviation of ΔSCₜ₋₁ is σ ≈ 11.0 pp. A **two-standard-deviation inflow** is 2σ ≈ 22 pp, which maps to a conditional yield change of

```math
22 \times (-2.45) \approx -54 \ \text{bp} \;\approx\; -50 \ \text{bp},
```

the "roughly 50 basis points per two-sigma inflow during scarcity months" quoted in the abstract. Because the estimate is imprecise, this is best read as an order of magnitude, not a point forecast.

---

## 4. Estimation: OLS

The coefficient vector is the usual least-squares solution,

```math
\hat{\boldsymbol\beta} = (X'X)^{-1} X'\mathbf{y}, \qquad \hat{\boldsymbol\varepsilon} = \mathbf{y} - X\hat{\boldsymbol\beta},
```

implemented in `PROC REG` (point estimates) in `code/Stablecoin_Tbill_OLS.sas`. The point estimates are identical under classical or HAC inference — only the standard errors differ.

---

## 5. Inference: Newey–West HAC standard errors

Monthly macro residuals are typically **serially correlated and heteroskedastic**, which biases the classical OLS variance σ²(*X*′*X*)⁻¹. The preferred inference therefore uses the **heteroskedasticity- and autocorrelation-consistent (HAC)** estimator of Newey and West:

```math
\widehat{\mathrm{Var}}_{\text{NW}}(\hat{\boldsymbol\beta}) = (X'X)^{-1}\,\hat{\mathbf{S}}\,(X'X)^{-1},
```

with the long-run variance estimated by a Bartlett-kernel-weighted sum of autocovariances:

```math
\hat{\mathbf{S}} = \sum_{t=1}^{N} \hat\varepsilon_t^{\,2}\,\mathbf{x}_t\mathbf{x}_t' \;+\; \sum_{\ell=1}^{L} w_\ell \sum_{t=\ell+1}^{N} \hat\varepsilon_t\,\hat\varepsilon_{t-\ell}\big(\mathbf{x}_t\mathbf{x}_{t-\ell}' + \mathbf{x}_{t-\ell}\mathbf{x}_t'\big), \qquad w_\ell = 1 - \frac{\ell}{L+1}.
```

The Bartlett weights wℓ decline linearly with lag ℓ and guarantee a positive-semidefinite variance matrix. The bandwidth is *L* = 4 lags, implemented via `PROC AUTOREG ... / covest=neweywest`. HAC widens the standard errors where the classical estimator is too optimistic; it leaves β̂ unchanged and, importantly, **does not require normally distributed residuals**.

---

## 6. Joint hypothesis tests

Linear restrictions of the form *H*₀: *R*β = **q** are tested with the Wald/*F* statistic

```math
F = \frac{1}{m}\,\big(R\hat{\boldsymbol\beta} - \mathbf{q}\big)'\,\Big[R\,\widehat{\mathrm{Var}}(\hat{\boldsymbol\beta})\,R'\Big]^{-1}\,\big(R\hat{\boldsymbol\beta} - \mathbf{q}\big),
```

where *m* is the number of restrictions. Three tests are reported:

| Null | Restriction matrix *R*, **q** | Meaning |
|---|---|---|
| β₁ = β₃ = 0 | two rows, **q** = **0** | stablecoins have **no effect at all** |
| β₃ = 0 | one row, *q* = 0 | **no state-dependence** (no interaction) |
| β₁ + β₃ = 0 | (0,1,0,1,0,0,0), *q* = 0 | **zero total effect** in scarcity months |

In the baseline, the first test gives *F* = 0.07 (*p* = 0.93) — the data cannot reject "no stablecoin effect."

---

## 7. Goodness of fit

```math
R^2 = 1 - \frac{\sum_t \hat\varepsilon_t^{\,2}}{\sum_t (\Delta y_t^{3M} - \overline{\Delta y^{3M}})^2}, \qquad \bar R^2 = 1 - (1-R^2)\,\frac{N-1}{N-k},
```

with *k* = 7 parameters. The baseline reaches *R*² = 0.770 (adj. *R*² = 0.749), but a variance decomposition shows almost all explanatory power comes from the single fed-funds term ΔFFₜ (β₄ ≈ 0.92, close to the theoretical one-for-one pass-through), **not** from the stablecoin variables.

---

## 8. Residual diagnostics

Classical exact *t* and *F* tests assume normal errors (Wooldridge MLR.6). `PROC UNIVARIATE` on the baseline residuals reports mean 0 by construction, standard deviation 11.21 bp, **skewness 0.39** and **kurtosis 3.52** — close to the normal benchmarks of 0 and 3. Formal tests (Shapiro–Wilk *W* = 0.892, *p* < 0.001) still reject normality, driven by a few large outliers in months of sharp policy movement. This does not threaten the headline inference because the reported standard errors are HAC, which are asymptotically valid without the normality assumption.

---

## 9. Identification: what the coefficient does and does not mean

Stablecoin growth enters with a **one-month lag**. Since yields and stablecoin flows are jointly determined within a month, a contemporaneous specification would conflate the two directions of causation; lagging removes the most obvious simultaneity. It does **not**, however, deliver clean causal identification — that would require an instrument (as in the daily-frequency IV literature). The estimated β₁ and β₃ should therefore be read as **conditional correlations** consistent with, but not proof of, the front-end-demand mechanism. The contribution of this repository is to ask whether the published daily-IV pattern *survives* at monthly frequency with a transparent OLS toolkit — and the answer is sign-consistent but significance-fragile.

---

*Development: the research question, specification, and interpretation are my own; AI assistance was used for coding and drafting. For educational and research purposes only — not financial advice, and not a causal estimate.*
