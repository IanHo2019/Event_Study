* This do file imitates Figure A8 in Miller (2023)
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

gen treated = 1						// all units get treated
gen E_i = 8 + 4 * (i >= 6)			// various treatment time

expand 20							// number of time periods for each unit

bysort i: gen t = _n				// calendar time

xtset i t

gen etime = (t - E_i)				// event (or relative) time

gen TE = (etime >= 0) * (etime + 1)	// treatment effect
replace TE = 0 if treated == 0

gen Y0_pure = 6 * (E_i >= 10)		// level shift
gen eps = sqrt(0.2) * rnormal()		// error term
gen actual = Y0_pure + TE * treated
gen y = actual + eps				// observed outcome variable


********************************************************************************
**# Creating Variables Used for Estimation
********************************************************************************

* Generate relative time dummies
sum etime

forvalues i = `r(min)'/`r(max)' {
	if `i' < 0 {
		local j = abs(`i')
		gen D_pre`j' = (etime == `i')
	}
	
	if `i' >= 0 {
		gen D_post`i' = (etime == `i')
	}
}

* Generate indicators for unit types
egen unit_type = group(E_i)

* Calculate mean of observed outcomes within different groups
bysort t unit_type: egen meany = mean(y)

********************************************************************************
**# Constrained Regressions
********************************************************************************

* Average unit-type coefficients is zero
constraint define 1 1.unit_type + 2.unit_type = 0

* Normalize the average of pre-treatment coefficients to be zero
constraint define 2 D_pre10 + D_pre9 + D_pre8 + D_pre7 + D_pre6 + D_pre5 + D_pre4 + D_pre3 + D_pre2 + D_pre1 = 0

* Coefficients of a few earlier terms are the same
constraint define 3 D_pre11 = D_pre10
constraint define 4 D_pre10 = D_pre9
constraint define 5 D_pre9 = D_pre8
constraint define 6 D_pre8 = D_pre7

* Regressions
cnsreg y D_pre11 D_pre10 D_pre9 D_pre8 D_pre7 D_pre6 D_pre5 D_pre4 D_pre3 D_pre2 D_pre1 D_post* ibn.t ibn.unit_type, nocons vce(cluster i) constraints(1/6) collinear


********************************************************************************
**# Draw Graphs
********************************************************************************

* Create counterfactulal predictions by subtracting off the event-study coefficients.
gen cf = y
sum etime
forvalues i = `r(min)'/`r(max)' {
	if `i' < 0 {
		local j = abs(`i')
		replace cf = cf - _b[D_pre`j'] * D_pre`j'
	}
	
	if `i' >= 0 {
		replace cf = cf - _b[D_post`i'] * D_post`i'
	}
}

* Calculate means of counterfactual outcomes within treated/control group
bysort t unit_type: egen meancf = mean(cf)

* Visualize raw means
graph twoway (connected meancf meany t if unit_type == 2, msize(medium medium) msymbol(oh o) mcolor(orange blue) lc(orange blue) lwidth(medium medium) lpattern(dot solid)) ///
	(connected meancf meany t if unit_type == 1, msize(medium medium) msymbol(oh o) mcolor(orange blue) lc(orange blue) lwidth(medium medium) lpattern(dot solid)), ///
	xline(7.5 11.5) ///
	title("2) Raw Means for Treated, Control, and Counterfactual", position(11)) ///
	xtitle("Calendar Time") xlab(, nogrid) ///
	legend(order(2 "Treated" 1 "Counterfactual") rows(1) size(*0.8) position(6) region(lc(black))) ///
	name(raw_mean, replace)

* Store estimated results
matrix te = J(24, 3, .)

forvalues i = 1/24 {
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

gen etime = _n - 12
gen actual = (etime >= 0) * (etime + 1)	// actual effects

* Visualize estimated and actual effects
graph twoway (connected estimate actual etime if inrange(etime,-10,10), msize(medium medium) msymbol(o oh) mcolor(blue%70 cranberry) lc(blue%70 cranberry) lwidth(medium medium) lpattern(solid dot)) ///
	(rcap min95 max95 etime if inrange(etime,-10,10), lc(blue%70)), ///
	xline(-0.5) ///
	title("1) Estimated and Actual Treatement Effects", position(11)) ///
	xtitle("Event Time") xlab(, nogrid) ylab(0(5)15) yscale(range(-2,15)) ///
	legend(order(1 "Estimated" 3 "95% CIs" 2 "Actual") rows(1) size(*0.8) position(6) region(lc(black))) ///
	name(te, replace)

graph combine te raw_mean, xsize(8) ysize(4) title("Getting Close to Raw Timing-Based Data")
graph export "$figdir/Close_to_Raw_Timing_Data.pdf", replace