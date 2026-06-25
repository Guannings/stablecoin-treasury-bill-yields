/*****************************************************************************
 * Program     : Stablecoin_Tbill_OLS.sas
 * Author      : Kuanmin Kuo
 * Date        : May 2026
 * Course      : Econometrics, At-Home Report
 *
 * Description : OLS test of whether U.S. stablecoin issuance compresses
 *               short-term Treasury yields, with a state-dependent (bill-
 *               scarcity) interaction. Monthly data, January 2020 through
 *               April 2026 (T = 76).
 *
 * Reference   : Ahmed, R., & Aldasoro, I. (2025).
 *                 "Stablecoins and Safe Asset Prices."
 *                 BIS Working Papers No. 1270. May 2025.
 *               Jacewitz, S. (2025). "Stablecoins Could Increase Treasury
 *                 Demand, but Only by Reducing Demand for Other Assets."
 *                 Federal Reserve Bank of Kansas City Economic Bulletin.
 *               Ante, L., Saggu, A., & Fiedler, I. (2025). "The Stablecoin
 *                 Discount." arXiv:2505.12413.
 *
 * Data        : One pre-merged CSV is provided alongside this program:
 *                 Stablecoin_data_2020_2026.csv
 *               Columns: date, mcap_bn, TB3MS, FEDFUNDS, VIXCLS,
 *                        bills_mil, marketable_mil, bill_share
 *               Sources of the underlying series:
 *                 DefiLlama API (monthly EOM stablecoin market cap, $B)
 *                 FRED (TB3MS, FEDFUNDS, VIXCLS)
 *                 U.S. Treasury Fiscal Data API, MSPD Table 1
 *                 (Marketable debt by category -> bill_share)
 *****************************************************************************/


/*============================================================================
 * 0. CONFIGURATION
 *
 * Change LIBPATH to the folder on your PC that contains
 * Stablecoin_data_2020_2026.csv .
 *============================================================================*/

%let LIBPATH = .;   /* set to the folder holding Stablecoin_data_2020_2026.csv (repo: ../data) */


/*============================================================================
 * 1. IMPORT THE PRE-MERGED MONTHLY PANEL
 *============================================================================*/

proc import out=work.panel
    datafile="&LIBPATH.\Stablecoin_data_2020_2026.csv"
    dbms=csv replace;
    getnames=yes;
run;

/* PROC IMPORT already reads "date" as a SAS date numeric with a date format. */
proc sort data=work.panel; by date; run;


/*============================================================================
 * 2. CONSTRUCT MODEL VARIABLES
 *
 *  DY3M_t       = monthly change in 3-month T-bill yield, basis points
 *               = 100 * (TB3MS_t - TB3MS_{t-1})
 *  LagDSC_t     = lagged monthly % growth in stablecoin market cap, %
 *               = 100 * (mcap_{t-1} - mcap_{t-2}) / mcap_{t-2}
 *  DFF_t        = monthly change in fed funds rate, basis points
 *  SCAR_t       = bill-scarcity dummy: 1 if bill_share is in bottom quartile
 *  DSC_x_SCAR_t = LagDSC_t * SCAR_t
 *  POST_UST_t   = 1 for months >= June 2022 (Terra/UST collapse)
 *============================================================================*/

data work.pre;
    set work.panel;
    by date;

    LagMcap    = lag(mcap_bn);
    LagLagMcap = lag2(mcap_bn);
    DSC        = 100 * (mcap_bn   - LagMcap   ) / LagMcap;       /* % */
    LagDSC     = 100 * (LagMcap   - LagLagMcap) / LagLagMcap;    /* % */

    LagTB      = lag(TB3MS);
    DY3M       = 100 * (TB3MS    - LagTB);                       /* bp */

    LagFF      = lag(FEDFUNDS);
    DFF        = 100 * (FEDFUNDS - LagFF);                       /* bp */

    POST_UST   = (date >= '01JUN2022'd);
run;

/* SCAR = bottom-quartile dummy for bill_share */
proc rank data=work.pre groups=4 out=work.ranked;
    var bill_share;
    ranks bs_q;
run;

data work.analysis;
    set work.ranked;
    SCAR        = (bs_q = 0);
    DSC_x_SCAR  = LagDSC * SCAR;
    /* drop the row that loses two lags (months 1 and 2) and any rows missing */
    if cmiss(DY3M, LagDSC, SCAR, DFF, VIXCLS, POST_UST) = 0;
run;


/*============================================================================
 * 3. DESCRIPTIVE STATISTICS  (Table 1 of your report)
 *
 * Open one RTF here that captures every table through section 8.
 *============================================================================*/

ods rtf file="&LIBPATH.\stablecoin_results.rtf" startpage=yes;

title "Table 1A. Descriptive statistics, continuous variables";
proc means data=work.analysis n mean stddev min p25 median p75 max maxdec=3;
    var DY3M LagDSC DFF VIXCLS bill_share;
run;

title "Table 1B. Frequency of dummies and the interaction";
proc freq data=work.analysis;
    tables SCAR POST_UST SCAR*POST_UST / nocol norow nopercent;
run;
title;


/*============================================================================
 * 4. MAIN OLS REGRESSION  (Table 2 of your report)
 *
 *  DY3M_t = b0 + b1 LagDSC_t + b2 SCAR_t + b3 (LagDSC_t * SCAR_t)
 *               + b4 DFF_t + b5 VIXCLS_t + b6 POST_UST_t + eps_t
 *============================================================================*/

title "Table 2. OLS regression of monthly change in 3-month T-bill yield";
proc reg data=work.analysis plots=none;
    model DY3M = LagDSC SCAR DSC_x_SCAR DFF VIXCLS POST_UST / vif;
    output out=work.resid r=uhat p=yhat;

    /* H0: stablecoins have no effect on yields */
    h_no_stable:      test LagDSC = 0, DSC_x_SCAR = 0;

    /* H0: no state dependence (no interaction) */
    h_no_interaction: test DSC_x_SCAR = 0;

    /* Total effect during scarcity periods: b1 + b3 = 0 */
    h_scar_effect:    test LagDSC + DSC_x_SCAR = 0;
run; quit;


/*============================================================================
 * 5. HAC (NEWEY-WEST) ROBUST STANDARD ERRORS
 *============================================================================*/

title "Table 3. Newey-West HAC standard errors, 4 lags";
proc autoreg data=work.analysis plots=none;
    model DY3M = LagDSC SCAR DSC_x_SCAR DFF VIXCLS POST_UST
                 / nlag=4 covest=neweywest dw=4 dwprob;
run;
title;


/*============================================================================
 * 6. ROBUSTNESS CHECK 1 -- VIX in changes instead of levels
 *============================================================================*/

data work.rob;
    set work.analysis;
    LagVIX = lag(VIXCLS);
    DVIX   = VIXCLS - LagVIX;
run;

title "Table 4. Robustness check 1: DVIX instead of VIX in levels";
proc autoreg data=work.rob plots=none;
    model DY3M = LagDSC SCAR DSC_x_SCAR DFF DVIX POST_UST / nlag=4 covest=neweywest;
run;
title;


/*============================================================================
 * 7. ROBUSTNESS CHECK 2 -- continuous bill_share interaction
 *============================================================================*/

data work.rob2;
    set work.analysis;
    DSC_x_bs = LagDSC * bill_share;
run;

title "Table 5. Robustness check 2: continuous bill_share interaction";
proc autoreg data=work.rob2 plots=none;
    model DY3M = LagDSC bill_share DSC_x_bs DFF VIXCLS POST_UST / nlag=4 covest=neweywest;
run;
title;


/*============================================================================
 * 8. RESIDUAL DIAGNOSTICS
 *============================================================================*/

title "Residual diagnostics";
proc univariate data=work.resid normal;
    var uhat;
    histogram uhat / normal;
    qqplot   uhat / normal(mu=est sigma=est);
run;
title;


/*============================================================================
 * 9. CLOSE THE RTF
 *============================================================================*/

ods rtf close;

/* End of program. */
