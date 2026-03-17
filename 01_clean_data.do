/*===========================================================================
  01_build_dataset.do
  PEP Empirical Assignment — Card, Chetty & Weber (2007) Replication
  Author:  Mathilde Vallat

  Description:
    Loads sample_75_02.dta, merges with work_history.dta, applies the
    sample restrictions from Card, Chetty & Weber (2007), and constructs
    the running variables, monthly bins, polynomial controls, and
    censoring indicator needed for the RD figures and hazard models.

  INPUTS: data/raw/sample_75_02.dta  &  data/raw/work_history.dta
  OUTPUT: data/clean/analysis_dataset.dta
===========================================================================*/

* Adjust this path
global project "C:/Users/vallatm/Desktop/PEP/Mathilde_Vallat"
cd "$project"


*-------
* Setup
*-------

clear all                
capture log close        
set more off
set trace off             
prog drop _all
global raw     "$project/data/raw"
global clean   "$project/data/clean"
global output  "$project/output"

log using "output/logs/01_clean_data.log", text replace
use "$raw/sample_75_02.dta", clear

count
display "Raw observations before any restrictions: " r(N)

* The SP and EB eligibility cutoff is exactly 3 years = 1,095 days
global sp_cutoff = 3 * 365    // = 1095
* 31-day "month" for bucketing the running variable into bins
global bin_width = 31
* UI censoring threshold: 20 weeks = 140 days (for survival analysis)
global cens_threshold = 140

*------
* Merge
*------

sort penr file
merge 1:1 penr file using "$raw/work_history.dta"
tabulate _merge    // inspect match quality
keep if _merge == 3
drop _merge
count
display "Observations after merging with work history: " r(N)


*---------------------
* Sample restrictions
*---------------------

* Restrict to layoffs in calendar years 1981–2001
keep if endy > 1980 & endy < 2002
* Drop voluntary quits — their job search behaviour is self-selected
drop if volquit == 1
* Drop observations with missing or invalid region code
drop if region == 0
* Drop recalls to the same employer — these are not genuine new job searches
drop if recall == 1
* Tenure window: workers must have 1 to 5 years of tenure at the lost job
*     This keeps the sample in a range where the SP cutoff is economically
*     meaningful and where both sides of the RD have adequate mass.
keep if duration >= 365 & duration < 5 * 365
* Employment history window: same 1–5 year window applied to dempl5
*     (days employed in the past 5 years — the EB running variable)
keep if dempl5 >= 365 & dempl5 < 5 * 365
count
display "Observations after all sample restrictions: " r(N)


*------------------------------------------
* Harmonise region codes (avoid thin cells)
*------------------------------------------

replace region = 8 if region == 9
replace region = 5 if region == 3
replace region = 5 if region == 6
capture replace ne_region = 8 if ne_region == 9
capture replace ne_region = 5 if ne_region == 3
capture replace ne_region = 5 if ne_region == 6

*---------------------
* Treatment indicators
*---------------------

* Severance pay eligibility: worker's tenure at the lost job >= 3 years
* (capture drop in case the raw dataset already contains this variable)
capture drop sp_eligible
gen sp_eligible     = (duration >= $sp_cutoff)
label var sp_eligible "=1 if eligible for severance pay (tenure >= 1095 days)"
* Extended UI eligibility: days employed in past 5 years >= 3 years
* (capture drop in case the raw dataset already contains this variable)
capture drop eb_eligible
gen eb_eligible  = (dempl5   >= $sp_cutoff)
label var eb_eligible "=1 if eligible for 30-week UI (dempl5 >= 1095 days)"
tabulate sp_eligible,    miss
tabulate eb_eligible, miss

*-------------------------------------------
* Running variables recentered at the cutoff
*-------------------------------------------

gen rv_sp = duration - $sp_cutoff
label var rv_sp "Tenure minus SP cutoff (days, centred at 0)"
gen rv_eb = dempl5 - $sp_cutoff
label var rv_eb "dempl5 minus EB cutoff (days, centred at 0)"
summarize rv_sp rv_eb

*----------------------------------------------------
* Monthly category bins for RD binned-scatter figures
*----------------------------------------------------

* SP bins
gen bin_sp = .
replace bin_sp = int( rv_sp        / $bin_width) + 36  ///
    if rv_sp >= 0
replace bin_sp = int((rv_sp + 1)   / $bin_width) + 35  ///
    if rv_sp <  0
* EB bins
gen bin_eb = .
replace bin_eb = int( rv_eb        / $bin_width) + 36  ///
    if rv_eb >= 0
replace bin_eb = int((rv_eb + 1)   / $bin_width) + 35  ///
    if rv_eb <  0

* Drop outermost bins to avoid edge effects (bins 12 and 59 are boundary bins
* at the very ends of the 1–5 year window, which have fewer observations
* and can distort the visual fit at the extremes of figures)
replace bin_sp = . if bin_sp == 12 | bin_sp == 59
replace bin_eb = . if bin_eb == 12 | bin_eb == 59
label var bin_sp "Monthly SP tenure bin (35=just below cutoff, 36=just above)"
label var bin_eb "Monthly EB dempl5 bin (35=just below cutoff, 36=just above)"


*---------------------------
* Prior employment indicator
*---------------------------
gen had_prior_job = (dempl5 - duration > 30) if !missing(dempl5, duration)
label var had_prior_job "=1 if worker had prior employment (dempl5 > duration + 30 days)"

*------------------------------------------
* Additional outcome and control variables
*------------------------------------------

* Log wage controls
gen log_wage  = ln(wage0)
gen log_wage_sq = log_wage^2
label var log_wage  "Log daily wage at job loss"
label var log_wage_sq "Log daily wage squared"
* Age squared
gen age_sq = age^2
label var age_sq "Age squared"
* Education indicator (above_basic_ed = 1 if above basic schooling level)
gen above_basic_ed = (education > 1) if education != .
label var above_basic_ed "=1 if education above basic level"
* Wage change at re-employment (key outcome for model testing)
gen log_wage_growth = ln(ne_wage0) - ln(wage0)
label var log_wage_growth "Log re-employment wage minus log previous wage"
* Annual wage approximation (Austrian convention: daily wage × 14)
gen annual_wage = wage0 * 14
label var annual_wage "Approximate annual wage (daily × 14)"
* Blue-collar indicator from previous job (from work history)
capture gen prev_bluecollar = (last_etyp == 2) if last_etyp != .
capture label var prev_bluecollar "=1 if previous job was blue-collar"
* Verify these raw work_history variables survived the merge
capture confirm variable experience
if _rc != 0 display as error "WARNING: experience not found — check work_history merge"
capture confirm variable firms
if _rc != 0 display as error "WARNING: firms not found — check work_history merge"
* Work history derived variables (from work history)
capture gen  experience_sq      = experience^2          if !missing(experience)
capture gen  prev_had_nonedur   = (last_nonedur > 0)    if !missing(last_nonedur)
capture label var experience_sq      "Work experience squared (days)"
capture label var prev_had_nonedur   "=1 if positive nonemployment before current job"


*---------------------------------------------------------------
* Polynomial terms in the running variables for the hazard model
*----------------------------------------------------------------

* SP polynomials (scaled to years)
gen sp_poly1 = rv_sp / 365
gen sp_poly2 = sp_poly1^2
gen sp_poly3 = sp_poly1^3
gen sp_poly4 = sp_poly1^4    // available for higher-order robustness checks
* SP interactions: sp_eligible × polynomial (different slope above cutoff)
gen sp_x_poly1 = sp_eligible * sp_poly1
gen sp_x_poly2 = sp_eligible * sp_poly2
gen sp_x_poly3 = sp_eligible * sp_poly3
gen sp_x_poly4 = sp_eligible * sp_poly4
label var sp_poly1 "Recentered tenure in years (linear)"
label var sp_poly2 "Recentered tenure in years (squared)"
label var sp_poly3 "Recentered tenure in years (cubed)"
label var sp_x_poly1  "SP eligibility × sp_poly1"
label var sp_x_poly2  "SP eligibility × sp_poly2"
label var sp_x_poly3  "SP eligibility × sp_poly3"
* EB polynomials (scaled to years)
gen eb_poly1 = rv_eb / 365
gen eb_poly2 = eb_poly1^2
gen eb_poly3 = eb_poly1^3
gen eb_poly4 = eb_poly1^4
* EB interactions: eb_eligible × polynomial
gen eb_x_poly1 = eb_eligible * eb_poly1
gen eb_x_poly2 = eb_eligible * eb_poly2
gen eb_x_poly3 = eb_eligible * eb_poly3
gen eb_x_poly4 = eb_eligible * eb_poly4
label var eb_poly1    "Recentered dempl5 in years (linear)"
label var eb_poly2    "Recentered dempl5 in years (squared)"
label var eb_poly3    "Recentered dempl5 in years (cubed)"
label var eb_x_poly1 "EB eligibility × eb_poly1"
label var eb_x_poly2 "EB eligibility × eb_poly2"
label var eb_x_poly3 "EB eligibility × eb_poly3"

*-----------------
* Calendar dummies
*-----------------

tabulate endmo,  gen(mo_fe)   // 12 month-of-year indicators (Jan = omitted)
tabulate endy,   gen(yr_fe)    // year-of-job-loss indicators
tabulate region, gen(region_fe)     // region fixed effects

*-------------------------------------------
* Censoring indicator for survival analysis
*-------------------------------------------

* no_reemploy: =1 if the worker never found a new job by end of data.
* In the raw data, ne_start == 15887 is the sentinel value meaning "no next job observed".
capture drop no_reemploy
gen no_reemploy = (ne_start == 15887)
label var no_reemploy "=1 if no re-employment observed by end of data"
gen censored = (no_reemploy == 1) | (noneduration >= $cens_threshold)
label var censored "=1 if spell censored (no re-employment within 20-week window)"
gen neg_start = -start
sort penr neg_start
drop neg_start
by penr: gen spell_n  = _n
by penr: gen n_spells = _N

*----------------------
* Elements for analysis
*----------------------

gen nextjob_dur_mths  = 1 + int(ne_duration / $bin_width)
gen nextjob_censored = (ne_start + ne_duration >= td(1jul2003)) if indnemp == 1
replace nextjob_censored = 1 if ne_duration > 5 * 365
bysort benr endy endmo: gen firm_mth_layoffs = _N
capture drop multi_layoff
gen multi_layoff = (firm_mth_layoffs >= 4)

*------
* Save
*------

compress
save "$clean/analysis_dataset.dta", replace

display _newline "Clean dataset saved: data/clean/analysis_dataset.dta"

log close

// log using "$output/logs/codebook.log", text replace
// codebook
// log close