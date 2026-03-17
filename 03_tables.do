/*==============================================================================
  03_tables.do
  PEP Empirical Assignment — Card, Chetty & Weber (2007) Replication
  Author:  Mathilde Vallat

  Description:
    Replicates Table II:
    "Effects of Severance Pay and EB on Nonemployment Durations: Hazard Model Estimates"

  INPUTS:   data/clean/analysis_dataset.dta
  OUTPUTS:  output/tables/table2_hazard.tex
            output/tables/table2_hazard.csv
==============================================================================*/

* Adjust this path
global project "C:/Users/vallatm/Desktop/PEP/Mathilde_Vallat"
cd "$project"


clear all                
capture log close        
set more off
set trace off             
prog drop _all
global raw     "$project/data/raw"
global clean   "$project/data/clean"
global output  "$project/output"

capture mkdir "$output/tables"
log using "$output/logs/03_tables.log", text replace

use "$clean/analysis_dataset.dta", clear

*---------------------
* Set up survival data
*--------------------

stset noneduration, failure(censored == 0)

*-----------------------
* Define covariate lists
*----------------------

* RD polynomial controls (always included in every column)
local rd_poly  "sp_poly1 sp_poly2 sp_poly3 sp_x_poly1 sp_x_poly2 sp_x_poly3"
local rd_poly  "`rd_poly' eb_poly1 eb_poly2 eb_poly3 eb_x_poly1 eb_x_poly2 eb_x_poly3"
* Basic controls (Columns 2, 4, 5)
local basic_controls "female married austrian bluecollar age age_sq"
local basic_controls "`basic_controls' log_wage log_wage_sq"
local basic_controls "`basic_controls' mo_fe2-mo_fe12 yr_fe2-yr_fe21"
* Full controls (Column 3): basic controls PLUS firm/worker history variables
* Check availability of full-control variables
foreach v in dg_size experience experience_sq prev_bluecollar last_recall ///
             prev_had_nonedur last_nonedur n_spells above_basic_ed {
    capture confirm variable `v'
    if _rc != 0 {
        display as error "WARNING: `v' not found — Column 3 may have issues"
    }
}
* Build the full-control variable list
local full_controls "`basic_controls'"
local full_controls "`full_controls' dg_size experience experience_sq"
local full_controls "`full_controls' had_prior_job"
local full_controls "`full_controls' prev_bluecollar last_recall"
local full_controls "`full_controls' prev_had_nonedur last_nonedur n_spells"
local full_controls "`full_controls' above_basic_ed"
local full_controls "`full_controls' iagrmining icarsales ihotel imanufact iservice itransport iwholesale"
local full_controls "`full_controls' region_fe2-region_fe6"


*-----------------------------------
* Column 1: No controls, full sample
*------------------------------------
eststo col1: stcox sp_eligible eb_eligible `rd_poly', nohr vce(cluster penr)

*-------------------------------------
* Column 2: Basic controls, full sample
*--------------------------------------
eststo col2: stcox sp_eligible eb_eligible `rd_poly' `basic_controls', ///
    nohr vce(cluster penr)

*-------------------------------------
* Column 3: Full controls, full sample
*--------------------------------------
eststo col3: stcox sp_eligible eb_eligible `rd_poly' `full_controls', ///
    nohr vce(cluster penr)

*-------------------------------------
* Column 4: Basic controls, reweighted
*-------------------------------------
capture drop censored
gen censored = no_reemploy|noneduration>=140
stset noneduration, failure(censored==0)

eststo col4: stcox sp_eligible eb_eligible `rd_poly' `basic_controls', ///
    nohr vce(cluster penr)
* Reset stset to unweighted for the remaining column
stset noneduration, failure(censored == 0)

*---------------------------------------
* Column 5: Basic controls, >= 4 layoffs
*-------------------------------------
eststo col5: stcox sp_eligible eb_eligible `rd_poly' `basic_controls' ///
if multi_layoff == 1, nohr vce(cluster penr)

	
*--------------
* Export Table
*--------------

* Install esttab if not already available
capture which esttab
if _rc != 0 {
    ssc install estout, replace
}
esttab col1 col2 col3 col4 col5 ///
    using "$output/tables/table2_hazard.tex", ///
    replace ///
    label ///
    keep(sp_eligible eb_eligible) ///
    order(sp_eligible eb_eligible) ///
    b(%9.3f) se(%9.3f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    title("Effects of Severance Pay and EB on Nonemployment Durations: Hazard Model Estimates") ///
    mtitles("No controls" "Basic controls" "Full controls" "Reweighted" "$\geq$4 layoffs") ///
    scalars("N Observations") ///
    nonotes ///
    addnotes( ///
        "Cox hazard model estimates (log-hazard coefficients). Nonemployment durations" ///
        "censored at 20 weeks (140 days). All columns include cubic polynomials in job" ///
        "tenure and months worked, interacted with SP and EB indicators. Standard errors" ///
        "clustered by individual in parentheses." ///
        "* p<0.10, ** p<0.05, *** p<0.01" ///
    ) ///
    booktabs

* Also export a CSV version for convenience
esttab col1 col2 col3 col4 col5 ///
    using "$output/tables/table2_hazard.csv", ///
    replace ///
    label ///
    keep(sp_eligible eb_eligible) ///
    order(sp_eligible eb_eligible) ///
    b(%9.4f) se(%9.4f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("No controls" "Basic controls" "Full controls" "Reweighted" ">=4 layoffs")


*----------------------
* Display results in log
*-----------------------

display _newline(2) "=== Table II: Summary of key coefficients ==="
esttab col1 col2 col3 col4 col5, ///
    keep(sp_eligible eb_eligible) ///
    order(sp_eligible eb_eligible) ///
    b(%9.4f) se(%9.4f) ///
    star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("No controls" "Basic controls" "Full controls" "Reweighted" ">=4 layoffs") ///
    scalars("N Observations") ///
    title("Table II — Card, Chetty & Weber (2007) Replication")



eststo clear
log close