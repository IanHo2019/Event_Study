* This do file imitates Figure A4 in Miller (2023)
* Author: Ian He
* Date: Jun 28, 2023
* Stata Version: 18

clear all

global figdir "D:\research\Miller (2023)\Figures"

********************************************************************************
**# Data Generating Process
********************************************************************************

set seed 230627

set obs 10							// number of units
gen i = _n

gen treated = (i > 5)				// half of units get treated
gen E_i = 11 if treated == 1		// treatment time

expand 20							// number of time periods for each unit

bysort i: gen t = _n				// calendar time

xtset i t

gen etime = (t - E_i)				// event (or relative) time

gen TE = (etime >= 0 & treated != 0)	// treatment effect

gen Y0_pure = treated
gen eps = sqrt(0.3) * rnormal()		// error term
gen actual = Y0_pure + TE * treated
gen y = actual + eps				// observed outcome variable


********************************************************************************
**# Creating Variables Used for Estimation
********************************************************************************

forvalues i = 0/10 {
	* generate relative time dummies
	gen D_post`i' = (etime == `i')
	gen D_pre`i' = (etime == -`i')
	
	* drop if a dummy equals 0 for all units
	sum D_post`i'
	if r(mean) == 0 {
		drop D_post`i'
	}

	sum D_pre`i'
	if r(mean) == 0 {
		drop D_pre`i'
	}
}

drop D_pre0


********************************************************************************
**# Constrained Regressions
********************************************************************************

* Normalize coefficient of event time -1 dummy to be zero
constraint define 1 D_pre1 = 0

* Average unit-type coefficients is zero
constraint define 2 1.i + 2.i + 3.i + 4.i + 5.i + 6.i + 7.i + 8.i + 9.i + 10.i = 0

* Normalize the average of pre-treatment coefficients to be zero
constraint define 3 D_pre10 + D_pre9 + D_pre8 + D_pre7 + D_pre6 + D_pre5 + D_pre4 + D_pre3 + D_pre2 + D_pre1 = 0

* Regressions
cnsreg y D_pre* D_post* ibn.t ibn.i, nocons vce(cluster i) constraints(1 2) collinear
parmest, saving("$figdir\counterfactual_normalization1.dta", replace)

cnsreg y D_pre* D_post* ibn.t ibn.i, ///
	nocons vce(cluster i) constraints(2 3) collinear
parmest, saving("$figdir\counterfactual_normalization2.dta", replace)


********************************************************************************
**# Draw Graphs
********************************************************************************

use "$figdir\counterfactual_normalization1.dta", clear

rename estimate b1
rename min95 lb1
rename max95 ub1
keep parm b1 lb1 ub1

merge 1:1 parm using "$figdir\counterfactual_normalization2.dta"

rename estimate b2
rename min95 lb2
rename max95 ub2
keep parm b1 lb1 ub1 b2 lb2 ub2

keep if _n >= 31

gen pre_post = substr(parm, 4, 1)
gen treated = (pre_post=="o")

gen etime = substr(parm, -1, 1)
destring etime, replace

replace etime = -1 * etime if treated==0
replace etime = -10 if etime==0 & treated==0

sort etime

local title1 = "1) Normalize Period -1"
local title2 = "2) Normalize Average Periods -10 to -1"

forvalues p = 1/2 {
	graph twoway (line lb`p' ub`p' etime, lpattern(dash dash) lcolor(brown brown)) ///
		(connected treated b`p' etime, mc(cranberry navy) msize(medium large) msymbol(oh o) lc(cranberry navy) lwidth(medthin medium) lpattern(dot solid)), ///
		xline(-0.5, lcolor(red) lp(solid)) ///
		yline(0 , lpattern(dash) lcolor(gs8)) ///
		title("`title`p''", position(11)) ///
		xtitle("Event Time") xlab(, nogrid) yscale(range(-1.5,3.5)) ///
		legend(order(4 "Estimated Effects" 1 "95% CIs" 3 "Actual Effects") rows(1) size(*0.8) position(6) region(lc(black))) ///
		name(cn`p', replace)
}

grc1leg cn1 cn2, ///
	legendfrom(cn1) rows(1) name(cn, replace)
gr draw cn, xsize(8) ysize(4)

graph export "$figdir/Different_Counterfactual_Normalizations.pdf", replace