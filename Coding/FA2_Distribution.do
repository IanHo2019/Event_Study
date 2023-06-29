* This do file replicates Figure A2 in Miller (2023)
* Author: Ian He
* Date: Jun 29, 2023
* Stata Version: 18

clear all

global figdir "D:\research\Miller (2023)\Figures"

********************************************************************************
**# Costructing a (N * T) DID Data Structure
********************************************************************************

set obs 100

gen i = _n
gen treated = i > 50			// half of units get treated
gen E_i = 11 if treated == 1	// treatment time
expand 20						// number of time periods for each unit

bysort i: gen t = _n			// calendar time

xtset i t


********************************************************************************
**# Graphs
********************************************************************************
* graph set window fontface "Helvetica"

replace E_i=16 if treated==0	// mark never-treated units

* Determine some staggered treatment time
replace E_i=5 if treated==1 & i>=51 & i<=61
replace E_i=6 if treated==1 & i>=62 & i<=68
replace E_i=7 if treated==1 & i>=69 & i<=70
replace E_i=10 if treated==1 & i>=71 & i<=75
replace E_i=12 if treated==1 & i>=91


**# Panel A: PMF
twoway (histogram E_i if treated==1, discrete frequency start(4) barwidth(0.8) color(cranberry%70)) ///
	(histogram E_i if treated==0, discrete frequency start(4) barwidth(0.8) color(navy%50)), ///
	title("Distribution of Treated and Never-Treated Units by Event Date", size(medium)) ///
	xtitle("Event date") ///
	xlabel(5(1)12 16 "NA", nogrid) ///
	xscale(range(0 17)) yscale(range(0 1200)) ///
	text(1050 16 "never treated", size(small)) legend(off) ///
	name(dist_A, replace)


**# Panel B: CDF
sort E_i
cumul E_i, gen(cumul)
keep if cumul < 0.50			// drop never-treated units
keep cumul E_i

* Generate 4 obs denoting the first four periods
forvalues i = 1/4 {
	set obs `=_N+1'
	replace E_i= `i' if E_i == .
	replace cumul = 0 if cumul == .
}

* Generate 4 obs denoting the last three periods
forvalues i = 13/15 {
	set obs `=_N+1'
	replace E_i= `i' if E_i == .
	replace cumul = 0.5 if cumul == .
}

sort E_i cumul

twoway (line cumul E_i, lc(navy) lwidth(medthick)), ///
	title("Cumulative Distribution of Units by Event Date", size(medium)) ///
	ytitle("CDF") xtitle("Event Date") ///
	xlabel(1(1)15, nogrid) ylabel(0(0.1)1) ///
	legend(off) name(dist_B, replace)


* Combining panels
graph combine dist_A dist_B, iscale(0.6)

graph export "$figdir/Variation_in_Event_Dates.svg", replace
