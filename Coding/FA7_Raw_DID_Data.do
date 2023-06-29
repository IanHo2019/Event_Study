* This do file imitates Figure A7 in Miller (2023)
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

gen TE = (etime >= 0) * (etime + 1)	// treatment effect
replace TE = 0 if treated == 0

gen Y0_pure = 4*treated				// level shift
gen eps = sqrt(0.4) * rnormal()		// error term
gen actual = Y0_pure + TE * treated
gen y = actual + eps				// observed outcome variable


********************************************************************************
**# Creating Variables Used for Estimation
********************************************************************************

forvalues i = 0/10 {
	* generate relative time dummies
	gen D_post`i' = (etime == `i')
	gen D_pre`i' = (etime == -`i')
	
	* drop if a dummy equals 0 for all units; that is, D_post10
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

* Calculate mean of observed outcomes within treated/control group
bysort t treated: egen meany = mean(y)

* Generate indicators for unit types
replace E_i = -999 if E_i == .
egen unit_type = group(E_i)
replace E_i = . if E_i == -999


********************************************************************************
**# Constrained Regressions
********************************************************************************

* Average unit-type coefficients is zero
constraint define 1 1.unit_type + 2.unit_type = 0

* Normalize the average of pre-treatment coefficients to be zero
constraint define 2 D_pre10 + D_pre9 + D_pre8 + D_pre7 + D_pre6 + D_pre5 + D_pre4 + D_pre3 + D_pre2 + D_pre1 = 0

* Regressions
cnsreg y D_pre10 D_pre9 D_pre8 D_pre7 D_pre6 D_pre5 D_pre4 D_pre3 D_pre2 D_pre1 D_post* ibn.t ibn.unit_type, nocons vce(cluster i) constraints(1 2) collinear


********************************************************************************
**# Draw Graphs
********************************************************************************

* Create counterfactulal predictions by subtracting off the event-study coefficients.
gen cf = y - _b[D_post0] * D_post0
replace cf = cf - _b[D_pre10] * D_pre10
forvalues i = 1/9 {
	qui replace cf = cf - _b[D_pre`i'] * D_pre`i'
	qui replace cf = cf - _b[D_post`i'] * D_post`i'
}

* Calculate means of counterfactual outcomes within treated/control group
bysort t treated: egen meancf = mean(cf)

* Visualize raw means
graph twoway (connected meancf meany t if treated == 1, msize(medium medium) msymbol(oh o) mcolor(orange blue) lc(orange blue) lwidth(medium medium) lpattern(dot solid)) ///
	(connected meany t if treated == 0, msize(medium) mcolor(cranberry) msymbol(oh) lc(cranberry) lwidth(medium) lpattern(dot)), ///
	xline(10.5) ///
	title("2) Raw Means for Treated, Control, and Counterfactual", position(11)) ///
	xtitle("Calendar Time") xlab(, nogrid) ///
	legend(order(2 "Treated" 3 "Control" 1 "Counterfactual") rows(1) size(*0.8) position(6) region(lc(black))) ///
	name(raw_mean, replace)

* Store estimated results
matrix te = J(20, 3, .)

forvalues i = 1/20 {
	local b = e(b)[1,`i']
	local lb = `b' + invnormal(0.025) * sqrt(e(V)[`i',`i'])
	local ub = `b' + invnormal(0.975) * sqrt(e(V)[`i',`i'])
	matrix te[`i',1] = e(b)[1,`i']
	matrix te[`i',2] = `lb'
	matrix te[`i',3] = `ub'
}

mat colnames te = estimate min95 max95

clear
svmat te, n(col)	// covert the matrix to variables

gen etime = _n - 11
gen actual = (etime >= 0) * (etime + 1)	// actual effects

* Visualize estimated and actual effects
graph twoway (connected estimate actual etime, msize(medium medium) msymbol(o oh) mcolor(blue%70 cranberry) lc(blue%70 cranberry) lwidth(medium medium) lpattern(solid dot)) ///
	(rcap min95 max95 etime, lc(blue%70)), ///
	xline(-0.5) ///
	title("1) Estimated and Actual Treatement Effects", position(11)) ///
	xtitle("Event Time") ///
	xlab(, nogrid) ylab(-2(2)12) ///
	legend(order(1 "Estimated" 3 "95% CIs" 2 "Actual") rows(1) size(*0.8) position(6) region(lc(black))) ///
	name(te, replace)

graph combine te raw_mean, xsize(8) ysize(4) title("Getting Close to Raw DID Data")
graph export "$figdir/Close_to_Raw_DID_Data.png", replace