* This do file imitates Figure A9 in Miller (2023)
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

gen TE = (etime == 0)				// treatment effect follows AR(1)
replace TE= (0.7 * TE[_n-1]) if etime >= 1
replace TE = 0 if treated == 0

gen Y0_pure = 0						// counterfactual
gen eps = sqrt(0.2) * rnormal()		// error term
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


********************************************************************************
**# Design Constraints
********************************************************************************

* Average unit-type coefficients is zero
constraint define 1 1.i + 2.i + 3.i + 4.i + 5.i + 6.i + 7.i + 8.i + 9.i + 10.i = 0

* Normalize the average of pre-treatment coefficients to be zero
constraint define 2 D_pre10 + D_pre9 + D_pre8 + D_pre7 + D_pre6 + D_pre5 + D_pre4 + D_pre3 + D_pre2 + D_pre1 = 0

* Pooling groups of 2
constraint define 10 D_pre10 = D_pre9
constraint define 11 D_pre8  = D_pre7
constraint define 12 D_pre6  = D_pre5
constraint define 13 D_pre4  = D_pre3
constraint define 14 D_pre2  = D_pre1
constraint define 15 D_post0 = D_post1
constraint define 16 D_post2 = D_post3
constraint define 17 D_post4 = D_post5
constraint define 18 D_post6 = D_post7
constraint define 19 D_post8 = D_post9

* Pooling groups of 3
constraint define 20 D_pre1  = D_pre2
constraint define 21 D_pre1  = D_pre3

constraint define 22 D_pre4  = D_pre5
constraint define 23 D_pre4  = D_pre6

constraint define 24 D_pre7  = D_pre8
constraint define 25 D_pre7  = D_pre9

constraint define 26 D_post0  = D_post1
constraint define 27 D_post2  = D_post1

constraint define 28 D_post3  = D_post4
constraint define 29 D_post3  = D_post5

constraint define 30 D_post6  = D_post7
constraint define 31 D_post6  = D_post8

* Pooling groups of 4
constraint define 41 D_pre1   = D_pre2
constraint define 42 D_pre2   = D_pre3
constraint define 43 D_pre3   = D_pre4

constraint define 44 D_pre5   = D_pre6
constraint define 45 D_pre6   = D_pre7
constraint define 46 D_pre7   = D_pre8

constraint define 47 D_pre9   = D_pre10

constraint define 48 D_post0  = D_post1
constraint define 49 D_post1  = D_post2
constraint define 50 D_post2  = D_post3

constraint define 51 D_post4  = D_post5
constraint define 52 D_post5  = D_post6
constraint define 53 D_post6  = D_post7

constraint define 54 D_post8  = D_post9


********************************************************************************
**# Run Regressions and Draw Graphs
********************************************************************************

forvalues i = 1/4 {
	if `i' == 1 {
		local panel = "1) Standard Event Study"
		local constr = ""
		local j = 1
	}
	
	if `i' == 2 {
		local panel = "2) Coefficients pooled in groups of 2"
		local constr = "10/19"
		local j = 2
	}
	
	if `i' == 3 {
		local panel = "3) Coefficients pooled in groups of 3"
		local constr = "20/31"
		local j = 3
	}
	
	if `i' == 4 {
		local panel = "4) Coefficients pooled in groups of 4"
		local constr = "41/54"
		local j = 4
	}
	
	preserve
	
	* Regression
	cnsreg y D_pre10 D_pre9 D_pre8 D_pre7 D_pre6 D_pre5 D_pre4 D_pre3 D_pre2 D_pre1 D_post* ibn.t ibn.i, nocons vce(cluster i) constraints(1 2 `constr') collinear

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
	gen actual = (etime == 0)	// actual effects
	replace actual = (0.7 * actual[_n-1]) if etime >= 1
	
	* Visualize estimated and actual effects
	graph twoway (connected actual estimate etime, msize(medium medlarge) msymbol(o o) mcolor(cranberry blue%70) lc(cranberry blue%70) lwidth(medium medium) lpattern(solid solid)) ///
		(line min95 max95 etime, lcolor(blue%50 blue%50) lpattern(dash dash)), ///
		xline(-0.5) yline(0, lc(gs8)) ///
		title("`panel'", position(11) size(medium)) ///
		xtitle("Event Time") ///
		xlab(, nogrid) ylab(-1(0.5)2) ///
		legend(order(2 "Estimated" 3 "95% CIs" 1 "Actual") rows(1) size(*0.8) position(6) region(lc(black))) ///
		name(model`j', replace)

	restore
}

grc1leg model1 model2 model3 model4, ///
	legendfrom(model1) cols(2) ///
	name(pool, replace)

graph export "$figdir\Pooling_Event_Study.png", replace