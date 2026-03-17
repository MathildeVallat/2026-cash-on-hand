/*==============================================================================
  02_figures.do
  PEP Empirical Assignment — Card, Chetty & Weber (2007) Replication  
  Author:  Mathilde Vallat
  
  Description:
    Creates validation figures:
	Figure II: Shows constant layoff frequency around the severance pay threshold
	Figures IIIa and IIIb: Validates similar worker characteristics across the eligibility threshold
	Figure IV: Confirms observable characteristics don't jump at the eligibility cutoff
	Creates result figures:
	Figure V: Shows ten-day jump in jobless duration at severance threshold
	Figure VI: Displays 10% drop in job-finding rates from severance pay
	Figure VIIIa: Shows seven-day increase in duration for extended benefits
	Figure VIIIb: Shows 7% drop in job-finding rates for extended benefits
	Figures Xa and Xb: Confirms no improvement in subsequent job match quality
  
  INPUT:    analysis_sample.dta
  OUTPUTs:  figures/
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

log using "$output/logs/02_figures.log", text replace
use "$clean/analysis_dataset.dta", clear

*------------------
* Global parameters
*------------------

* 31-day "month" for bucketing the running variable into bins
global bin_width = 31
* UI censoring threshold: 20 weeks = 140 days (for survival analysis)
global cens_threshold = 140

* ----------
* Figure II
* ----------

bysort bin_sp: gen freq_sp = _N
bysort bin_sp: gen idx_freq = _n
twoway scatter freq_sp bin_sp if idx_freq == 1, ///
    connect(l) msize(medsmall) ///
    xlabel(12(6)60) xline(35.5) ///
    graphregion(fcolor(white)) legend(off) ///
    title(Figure II) ///
    subtitle(Frequency of Layoffs by Job Tenure) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Number of Layoffs)
graph export "$output/figures/figII.png", replace
drop freq_sp idx_freq

* ------------
* Figure IIIa
* ------------

capture drop num_jobs mean_numjobs_sp idx_numjobs
gen num_jobs = last_breaks + 1
bysort bin_sp: egen mean_numjobs_sp = mean(num_jobs)
gen temp = (num_jobs == .)
bysort bin_sp temp: gen idx_numjobs = _n if num_jobs != .
drop temp

twoway ///
    scatter mean_numjobs_sp bin_sp if idx_numjobs == 1, ///
        msize(medsmall) xlabel(12(6)60) xline(35.5) ///
        graphregion(fcolor(white)) legend(off) ///
    || lfit mean_numjobs_sp bin_sp ///
        if idx_numjobs == 1 & bin_sp < 35.5 ///
    || lfit mean_numjobs_sp bin_sp ///
        if idx_numjobs == 1 & bin_sp > 35.5, ///
    title(Figure IIIa) ///
    subtitle(Number of Jobs Held by Job Tenure) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Mean Number of Jobs)
graph export "$output/figures/figIIIa.png", replace
drop mean_numjobs_sp idx_numjobs num_jobs

* -----------
* Figure IIIb
* -----------

bysort bin_sp: egen mean_wage_sp = mean(annual_wage)
gen temp = (wage0 == .)
bysort bin_sp temp: gen idx_wage = _n if wage0 != .
drop temp

twoway ///
    scatter mean_wage_sp bin_sp if idx_wage == 1, ///
        msize(medsmall) xlabel(12(6)60) xline(35.5) ///
        graphregion(fcolor(white)) legend(off) ///
    || lfit mean_wage_sp bin_sp ///
        if idx_wage == 1 & bin_sp < 35.5 ///
    || lfit mean_wage_sp bin_sp ///
        if idx_wage == 1 & bin_sp > 35.5, ///
    title(Figure IIIb) ///
    subtitle(Wage by Job Tenure) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Mean Annual Wage)
graph export "$output/figures/figIIIb.png", replace
drop mean_wage_sp idx_wage


* ---------
* Figure IV
* ---------

capture drop censored
gen censored = no_reemploy | noneduration >= $cens_threshold
stset noneduration, failure(censored == 0)

* Demean covariates (authors' approach) so intercept does not drive results
capture drop mean_* demean_*
foreach X of varlist female bluecollar austrian age age_sq above_basic_ed married ///
                      experience experience_sq log_wage log_wage_sq firms               ///
                      prev_bluecollar prev_had_nonedur {
    capture egen mean_`X'   = mean(`X')
    capture gen  demean_`X' = `X' - mean_`X'
}

stcox demean_female demean_bluecollar demean_austrian        ///
      demean_age demean_age_sq demean_above_basic_ed demean_married   ///
      demean_experience demean_experience_sq                        ///
      demean_log_wage demean_log_wage_sq demean_firms                ///
      demean_prev_bluecollar demean_prev_had_nonedur               ///
      region_fe* yr_fe* mo_fe*, nohr
predict predicted_hr

bysort bin_sp: egen avg_pred_hazard = mean(predicted_hr)
gen temp = (avg_pred_hazard == .)
bysort bin_sp temp: gen idx_pred = _n if avg_pred_hazard != .
drop temp

twoway ///
    scatter avg_pred_hazard bin_sp if idx_pred == 1, ///
        msize(medsmall) xlabel(12(6)60) xline(35.5) ///
        graphregion(fcolor(white)) legend(off) ///
    || lfit avg_pred_hazard bin_sp if bin_sp < 35.5 & idx_pred == 1 ///
    || lfit avg_pred_hazard bin_sp if bin_sp > 35.5 & idx_pred == 1, ///
    title(Figure IV) ///
    subtitle(Selection on Observables) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Mean Predicted Hazard Ratios)
graph export "$output/figures/figIV.png", replace
drop predicted_hr avg_pred_hazard idx_pred demean_*                          ///
     mean_female mean_bluecollar mean_austrian mean_age mean_age_sq    ///
     mean_above_basic_ed mean_married mean_experience mean_experience_sq           ///
     mean_log_wage mean_log_wage_sq mean_firms mean_prev_bluecollar mean_prev_had_nonedur


* --------
* Figure V
* --------

capture drop dur_under_2yr
gen dur_under_2yr = (noneduration <= 2*365)

capture drop avg_nonedur idx_cat
bysort bin_sp dur_under_2yr: gen idx_cat = _n if dur_under_2yr == 1
bysort bin_sp: egen avg_nonedur = mean(noneduration) if dur_under_2yr == 1
replace avg_nonedur = . if inlist(bin_sp, 12, 59)

twoway ///
    scatter avg_nonedur bin_sp if idx_cat == 1, ///
        msize(medsmall) xlabel(12(6)60) xline(35.5) ///
        graphregion(fcolor(white)) legend(off) ///
        yscale(range(142.5 167.5)) ylabel(145(5)165) ///
    || qfit avg_nonedur bin_sp ///
        if idx_cat == 1 & bin_sp < 35.5 ///
    || qfit avg_nonedur bin_sp ///
        if idx_cat == 1 & bin_sp > 35.5, ///
    title(Figure V) ///
    subtitle(Effect of Severance Pay on Nonemployment Durations) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Mean Nonemployment Duration (Days))
graph export "$output/figures/figV.png", replace
drop avg_nonedur idx_cat

* ----------
* Figure VI
* ----------

capture drop censored
gen censored = no_reemploy | noneduration >= $cens_threshold
stset noneduration, failure(censored == 0)

capture drop bin_dum*
tabulate bin_sp, gen(bin_dum)
capture drop idx_hazreg avg_hazard

stcox bin_dum1-bin_dum22 bin_dum24-bin_dum46 ///
    eb_eligible eb_poly1-eb_poly3 eb_x_poly1-eb_x_poly3 ///
    female bluecollar austrian age age_sq log_wage log_wage_sq ///
    mo_fe2-mo_fe12 yr_fe2-yr_fe21 married ///
    if bin_sp != ., nohr

bysort bin_sp: gen idx_hazreg = _n
gen avg_hazard = .
foreach k of numlist 1/22 24/46 {
    replace avg_hazard = _b[bin_dum`k'] ///
        if idx_hazreg == 1 & bin_dum`k' == 1
}
replace avg_hazard = 0 ///
    if idx_hazreg == 1 & bin_sp != . & avg_hazard == .

twoway ///
    scatter avg_hazard bin_sp if idx_hazreg == 1, ///
        xline(35.5) msize(medsmall) xlabel(12(6)60) ///
        graphregion(fcolor(white)) legend(off) ///
    || qfit avg_hazard bin_sp ///
        if bin_sp < 35.5 & idx_hazreg == 1 ///
    || qfit avg_hazard bin_sp ///
        if bin_sp > 35.5 & idx_hazreg == 1, ///
    title(Figure VI) ///
    subtitle(Job Finding Hazards Adjusted for Covariates) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Average Daily Job Finding Hazard in First 20 Weeks)
graph export "$output/figures/figVI.png", replace
drop idx_hazreg avg_hazard


gen weeks_nonemp = 1 + int(noneduration/7)
stset weeks_nonemp, failure(no_reemploy == 0)

* -------------
* Figure VIIIa
* -------------

* Reset censoring for noneduration
capture drop censored
gen censored = no_reemploy | noneduration >= $cens_threshold
stset noneduration, failure(censored == 0)
capture drop avg_nonedur idx_cat
bysort bin_eb dur_under_2yr: gen idx_cat = _n if dur_under_2yr == 1
bysort bin_eb: egen avg_nonedur = mean(noneduration) if dur_under_2yr == 1
replace avg_nonedur = . if inlist(bin_eb, 12, 59)

twoway ///
    scatter avg_nonedur bin_eb if idx_cat == 1, ///
        msize(medsmall) xlabel(12(6)60) xline(35.5) ///
        graphregion(fcolor(white)) legend(off) ///
        yscale(range(132.5 167.5)) ylabel(135(5)165) ///
    || qfit avg_nonedur bin_eb ///
        if idx_cat == 1 & bin_eb < 35.5 ///
    || qfit avg_nonedur bin_eb ///
        if idx_cat == 1 & bin_eb > 35.5, ///
    title(Figure VIIIa) ///
    subtitle(Effect of Benefit Extension on Nonemployment Durations) ///
    xtitle(Months Employed in Past Five Years) ///
    ytitle(Mean Nonemployment Duration (Days))
graph export "$output/figures/figVIIIa.png", replace
drop avg_nonedur idx_cat


* -------------
* Figure VIIIb
* -------------

capture drop bin_dum*
tabulate bin_eb, gen(bin_dum)

capture drop idx_hazreg avg_hazard
stcox bin_dum1-bin_dum22 bin_dum24-bin_dum46 ///
      sp_eligible sp_poly1-sp_poly3 sp_x_poly1-sp_x_poly3 if bin_eb != ., nohr
bysort bin_eb: gen idx_hazreg = _n
gen avg_hazard = .
foreach k of numlist 1/22 24/46 {
    replace avg_hazard = _b[bin_dum`k'] ///
        if idx_hazreg == 1 & bin_dum`k' == 1
}
replace avg_hazard = 0 ///
    if idx_hazreg == 1 & bin_eb != . & avg_hazard == .

twoway ///
    scatter avg_hazard bin_eb if idx_hazreg == 1, ///
        xline(35.5) msize(medsmall) xlabel(12(6)60) ///
        graphregion(fcolor(white)) legend(off) ///
    || qfit avg_hazard bin_eb ///
        if bin_eb < 35.5 & idx_hazreg == 1 ///
    || qfit avg_hazard bin_eb ///
        if bin_eb > 35.5 & idx_hazreg == 1, ///
    title(Figure VIIIb) ///
    subtitle(Effect of Extended Benefits on Job Finding Hazards) ///
    xtitle(Months Employed in Past Five Years) ///
    ytitle(Average Daily Job Finding Hazard in First 20 Weeks)
graph export "$output/figures/figVIIIb.png", replace
drop idx_hazreg avg_hazard bin_dum*

* ----------
* Figure Xa
* ----------

capture drop mean_wchange_sp idx_wchange
bysort bin_sp: egen mean_wchange_sp = mean(log_wage_growth)
gen temp = (log_wage_growth == .)
bysort bin_sp temp: gen idx_wchange = _n if log_wage_growth != .
drop temp

twoway ///
    scatter mean_wchange_sp bin_sp if idx_wchange == 1, ///
        msize(medsmall) xlabel(12(6)60) xline(35.5) ///
        graphregion(fcolor(white)) legend(off) ///
        yscale(range(-.1 0.01)) ylabel(-.1(.02)0) ///
    || lfit mean_wchange_sp bin_sp ///
        if idx_wchange == 1 & bin_sp < 35.5 ///
    || lfit mean_wchange_sp bin_sp ///
        if idx_wchange == 1 & bin_sp > 35.5, ///
    title(Figure Xa) ///
    subtitle(Effect of Severance Pay on Subsequent Wages) ///
    xtitle(Previous Job Tenure (Months)) ///
    ytitle(Wage Growth)
graph export "$output/figures/figXa.png", replace
drop mean_wchange_sp idx_wchange


* ----------
* Figure Xb
* ----------

* Set up survival time for NEXT-JOB duration
stset nextjob_dur_mths if indnemp == 1, failure(nextjob_censored == 0)

* Group-dummies Cox: one coefficient per SP tenure bin
capture drop bin_dum*
tabulate bin_sp, gen(bin_dum)

capture drop idx_hazreg_c mean_hazrate_c
stcox bin_dum1-bin_dum22 bin_dum24-bin_dum46 ///
	  if bin_sp != ., nohr
bysort bin_sp: gen idx_hazreg_c = _n
gen mean_hazrate_c = .
foreach k of numlist 1/22 24/46 {
	replace mean_hazrate_c = _b[bin_dum`k'] ///
		if idx_hazreg_c == 1 & bin_dum`k' == 1
}
replace mean_hazrate_c = 0 ///
	if idx_hazreg_c == 1 & bin_sp != . & mean_hazrate_c == .

twoway ///
	scatter mean_hazrate_c bin_sp if idx_hazreg_c == 1, ///
		xline(35.5) msize(medsmall) xlabel(12(6)60) ///
		graphregion(fcolor(white)) legend(off) ///
	|| qfit mean_hazrate_c bin_sp ///
		if bin_sp < 35.5 & idx_hazreg_c == 1 ///
	|| qfit mean_hazrate_c bin_sp ///
		if bin_sp > 35.5 & idx_hazreg_c == 1, ///
	title(Figure Xb) ///
	subtitle(Effect of Severance Pay on Subsequent Job Duration) ///
	xtitle(Previous Job Tenure (Months)) ///
	ytitle(Average Monthly Job Ending Hazard in Next Job)
graph export "$output/figures/figXb.png", replace
drop idx_hazreg_c mean_hazrate_c bin_dum*

capture log close
