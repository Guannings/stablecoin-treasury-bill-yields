%let LIBPATH = .;   /* set to the folder holding Stablecoin_data_2020_2026.csv (repo: ../data) */

proc import out=work.panel
    datafile="&LIBPATH.\Stablecoin_data_2020_2026.csv"
    dbms=csv replace;
    getnames=yes;
run;

proc sort data=work.panel; by date; run;

data work.pre;
    set work.panel;
    by date;
    LagMcap    = lag(mcap_bn);
    LagLagMcap = lag2(mcap_bn);
    DSC        = 100 * (mcap_bn   - LagMcap   ) / LagMcap;
    LagDSC     = 100 * (LagMcap   - LagLagMcap) / LagLagMcap;
    LagTB      = lag(TB3MS);
    DY3M       = 100 * (TB3MS    - LagTB);
    LagFF      = lag(FEDFUNDS);
    DFF        = 100 * (FEDFUNDS - LagFF);
    POST_UST   = (date >= '01JUN2022'd);
run;

proc rank data=work.pre groups=4 out=work.ranked;
    var bill_share;
    ranks bs_q;
run;

data work.analysis;
    set work.ranked;
    SCAR       = (bs_q = 0);
    DSC_x_SCAR = LagDSC * SCAR;
    if cmiss(DY3M, LagDSC, SCAR, DFF, VIXCLS, POST_UST) = 0;
run;

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

title "Table 2. OLS regression of monthly change in 3-month T-bill yield";
proc reg data=work.analysis plots=none;
    model DY3M = LagDSC SCAR DSC_x_SCAR DFF VIXCLS POST_UST / vif;
    output out=work.resid r=uhat p=yhat;
    h_no_stable:      test LagDSC = 0, DSC_x_SCAR = 0;
    h_no_interaction: test DSC_x_SCAR = 0;
    h_scar_effect:    test LagDSC + DSC_x_SCAR = 0;
run; quit;

title "Table 3. OLS with Newey-West HAC standard errors";
proc autoreg data=work.analysis plots=none;
    model DY3M = LagDSC SCAR DSC_x_SCAR DFF VIXCLS POST_UST
                 / covest=neweywest dw=4 dwprob;
run;
title;

data work.rob;
    set work.analysis;
    LagVIX = lag(VIXCLS);
    DVIX   = VIXCLS - LagVIX;
run;

title "Table 4. Robustness check 1: DVIX instead of VIX in levels (HAC SEs)";
proc autoreg data=work.rob plots=none;
    model DY3M = LagDSC SCAR DSC_x_SCAR DFF DVIX POST_UST / covest=neweywest;
run;
title;

data work.rob2;
    set work.analysis;
    DSC_x_bs = LagDSC * bill_share;
run;

title "Table 5. Robustness check 2: continuous bill_share interaction (HAC SEs)";
proc autoreg data=work.rob2 plots=none;
    model DY3M = LagDSC bill_share DSC_x_bs DFF VIXCLS POST_UST / covest=neweywest;
run;
title;

title "Table 6. Correlation matrix among regressors";
proc corr data=work.rob nosimple noprob;
    var VIXCLS DVIX SCAR LagDSC DSC_x_SCAR;
run;
title;

title "Residual diagnostics";
proc univariate data=work.resid normal;
    var uhat;
    histogram uhat / normal;
    qqplot   uhat / normal(mu=est sigma=est);
run;
title;

ods rtf close;
