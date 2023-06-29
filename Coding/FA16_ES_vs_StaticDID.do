* This do file imitates Figure A16 in Miller (2023).
* Author: Ian He
* Date: Jun 28, 2023
* Stata Version: 18

clear all

global figdir "D:\research\Miller (2023)\Figures"

********************************************************************************
**# Data Generating Process
********************************************************************************

*set seed 230627
set seed 101

set obs 10							// number of units
gen i = _n

gen treated = (i > 5)				// half of units get treated
gen E_i = 11 if treated == 1		// various treatment time

expand 20							// number of time periods for each unit

bysort i: gen t = _n				// calendar time

xtset i t

gen etime = (t - E_i)				// event (or relative) time
gen treated_post = (etime >= 0)		// post-treatment dummy

gen TE = (etime >= 0) * (etime + 1)	// treatment effect
replace TE = 0 if treated == 0

gen Y0_pure = 0						// counterfactual
gen eps = sqrt(0.05) * rnormal()	// error term
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

drop D_pre1


********************************************************************************
**# Regressions
********************************************************************************

* DID model with no trends
xtreg y treated_post i.t, fe

matrix te = J(20, 3, .)

forvalues i = 1/20 {
	if `i' <= 10 {
		matrix te[`i',1] = 0
	}
	
	if `i' > 10 {
		matrix te[`i',1] = e(b)[1,1]
	}
}

* DID model with unit-specific trends
xtreg y treated_post i.t i.i#c.t, fe

forvalues i = 1/20 {
	if `i' <= 10 {
		matrix te[`i',2] = 0
	}
	
	if `i' > 10 {
		matrix te[`i',2] = e(b)[1,1]
	}
}

* Event study model with no trends
xtreg y D_pre10 D_pre9 D_pre8 D_pre7 D_pre6 D_pre5 D_pre4 D_pre3 D_pre2 D_post* i.t, fe

forvalues i = 1/20 {
	if `i' <= 9 {
		matrix te[`i',3] = e(b)[1,`i']
	}
	
	if `i' == 10 {
		matrix te[`i',3] = 0
	}
	
	if `i' > 10 {
		matrix te[`i',3] = e(b)[1,`i'-1]
	}
	
}

mat colnames te = DID_ntr DID_tr ES


********************************************************************************
**# Visualization
********************************************************************************

clear
svmat te, n(col)	// covert the matrix to variables

gen etime = _n - 11
gen actual = (etime >= 0) * (etime + 1)

* Comparison
graph twoway (connected ES actual etime, msize(medlarge medlarge) msymbol(o oh) lc(blue%70 cranberry) lpattern(solid dash)) ///
	(line DID_ntr DID_tr etime, lc(green orange) lwidth(medthick medthick)), ///
	xline(-0.5) ///
	title("Event Study v.s. Static DID Models") ///
	xtitle("Event Time") xlab(, nogrid) ///
	legend(order(1 "Event study" 3 "DID with no trends control" 2 "Actual effects" 4 "DID with trends control") rows(2) size(*0.8) span position(6) region(lc(black)))

graph export "$figdir/ES_vs_StaticDID.png", replace