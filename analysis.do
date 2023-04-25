version 16.1

clear all
set graphics off
set seed 1234

// Define the outcomes.
global outcomes OS PFS

// Define the factors of interest.
global factors lot refract

// Define the data files for the factors.
local lot_file     "data_lot.raw"
local refract_file "data_refract.raw"

// Define title fragments for the factors.
local lot_title     "lines of treatment"
local refract_title "refractory status"

// Define the variable for the factors.
local lot_var     lot
local refract_var refract

// Define the number of studies to show in each panel of the article figures
// that show estimates of HR (i.e., this addresses the problem that forest plots
// with lots of studies and estimates are too long to be readable).
local studies_per_panel 3

// Define the figure file types to export.
local exts png eps

// Create a wrapper around -meta summarize- that can be used within a call to -statsby-,
// and that, in addition to returning whatever -meta summarize- returns in r(), also
// returns the value of a specified variable, whose values are assumed to be constant
// within a particular call of the function by -statsby-.
program define mymeta, rclass
  version 16.1
  syntax varname [if] [in] // TODO: Can we remove [in]?
  summarize `varlist' `if' `in'
  local sum = r(mean) // Use of mean prevents counting multiple totals.
  return scalar `varlist' = `sum'
  meta summarize `if' `in'
  return add
end

foreach factor of global factors {
  frame create `factor'
  frame `factor' {
    import delimited "``factor'_file'", varnames(1)

    // The data contain two publications for the CASTOR trial, so drop the
    // earlier trial.
    drop if author == "Palumbo"

    // Generate a variable that identifies the study.
    rename comparison Comparison
    generate Study = author + " " + string(year) + " (" + strtrim(trial) + ")" ///
                     + ": " + strtrim(Comparison)
    order Study, first
    drop author year trial

    // Trim the outcome and LOT variables.
    replace outcome        = strtrim(outcome)
    replace ``factor'_var' = strtrim(``factor'_var')

    // Label the variables that get exposed in plots or exported data.
    label variable Study            "Study: Treatment 1 vs Treatment 2"
    label variable Comparison       "Comparison"
    local factor_var_label        = strproper("``factor'_var'")
    label variable ``factor'_var'   "`factor_val_label'"
    label variable outcome          "Outcome"
    label variable e1               "Events (arm 1)"   // Arm 1 is the treatment named on the left in the comparison variable.
    label variable n1               "Patients (arm 1)" // Arm 1 is the treatment named on the left in the comparison variable.
    label variable e2               "Events (arm 2)"   // Arm 2 is the treatment named on the right in the comparison variable.
    label variable n2               "Patients (arm 2)" // Arm 2 is the treatment named on the right in the comparison variable.
    label variable n                "Patients"         // Total patients in a subgroup.
    label variable hr               "HR"
    label variable hr_lb            "Lower 95% CI Bound on HR"
    label variable hr_ub            "Upper 95% CI Bound on HR"
    label variable source           "Source"
    label variable pval             "p-value"

    // Add a column for use in checking the data.
    generate check = ""
    label variable check            "Data Extraction Errors"

    // Export the data for double-checking.
    export excel Study ``factor'_var' outcome hr* pval source check           ///
      using "products/Exported Data.xlsx",                                    ///
      sheet("`factor'", modify) firstrow(varlabels)

    // Convert HRs to log scale and impute SE for meta-analysis.
    generate log_hr = log(hr)
    generate log_lb = log(hr_lb)
    generate log_ub = log(hr_ub)
    assert   log_lb < log_hr
    assert   log_hr < log_ub
    generate se     = (log_ub - log_lb) / (2 * 1.96)

    // Compute total numbers of patients included in subgroup analyses if possible and not given.
    replace n = n1 + n2 if !missing(n1) & !missing(n2) & missing(n)

    // Compute the total number of patients included in subgroup analyses in each study.
    // TODO: Document this, which preserves the original order after the sort.
    tempvar idx
    generate `idx' = _n
    bysort Study outcome: egen total_n = total(n)
    label variable total_n "Patients"
    sort `idx'

    // Make string columns with numbers of events and participants.
    tostring e1 e2 n1 n2 , replace
    forvalues arm = 1/2 {
      replace e`arm' = "-" if e`arm' == "."
      replace n`arm' = "-" if n`arm' == "."
      generate en`arm' = e`arm' + " / " + n`arm'
    }

    // Perform meta-analyses of log HR (for OS and PFS) subgrouped by study.
    foreach outcome of global outcomes {
      local predicate outcome == "`outcome'"
      tempvar s_id
      encode Study if `predicate', generate(`s_id')
      tempvar panel // The forest plot panel number the study will be shown in.
      generate `panel' = 1 + floor((`s_id' - 1) / `studies_per_panel')

      // Set up for meta-analysis, but not we are really just making forest plots
      // to look at within-study differences in these analyses.
      meta set log_hr se, studylabel(``factor'_var')

      // Make a single, potentially long forest plot.
      meta forest _id _plot en1 en2 n _esci if `predicate', subgroup(Study) ///
           nogbhomtests nooverall noohetstats noohomtest transform("Hazard Ratio":exp) ///
           nogmarkers /// Do not show the study-level meta-analysis estimates.
           nullrefline ///
           columnopts(_id, title("`:variable label Study'")) ///
           columnopts(en1, title("Treatment 1") supertitle("Events / Patients")) ///
           columnopts(en2, title("Treatment 2") supertitle("Events / Patients")) ///
           title("Hazard ratio for `outcome' by study and ``factor'_title'")
      foreach ext of local exts {
        local this_figure "products/`factor'_`outcome'_single_panel.`ext'"
        local width = cond("`ext'" == "eps", "", "width(3000)")
        graph export "`this_figure'", replace `width'
      }

      // Make a plot for each panel (i.e., split up the potentially long plot).
      levelsof `panel' if `predicate'
      foreach this_panel in `r(levels)' {
        meta forest _id _plot en1 en2 n _esci if `predicate' & `panel' == `this_panel', subgroup(Study) ///
             nogbhomtests nooverall noohetstats noohomtest transform("Hazard Ratio":exp) ///
             nogmarkers      /// Do not show the study-level meta-analysis estimates.
             nullrefline     ///
             columnopts(_id, title("`:variable label Study'")) ///
             columnopts(en1, title("Treatment 1") supertitle("Events / Patients")) ///
             columnopts(en2, title("Treatment 2") supertitle("Events / Patients")) ///
             nonotes         ///
             crop(0.03125 4) ///
             xscale(range(0.03125 4)) xlabel(0.03125 "1/32" 0.125 "1/8" 0.5 "1/2" 2 "2")
        foreach ext of local exts {
          local this_figure "products/`factor'_`outcome'_panel_`this_panel'.`ext'"
          local width = cond("`ext'" == "eps", "", "width(3000)")
          graph export "`this_figure'", replace `width'
        }
      }
    }

    // Meta-analyze ratios of hazard ratios.
    foreach outcome of global outcomes {
      frame put * if outcome == "`outcome'", into(`outcome'_tmp)
      frame `outcome'_tmp {
        // Compute ratios of hazard ratios and their SEs.
        sort Study, stable
        generate ref                    = .
        by Study: replace  ref          = log_hr[_n]     if _n == 1
        by Study: replace  ref          = log_hr[_n - 1] if _n != 1
        by Study: generate norm_log_hr  = abs(log_hr - ref)

        generate ref_se                 = .
        by Study: replace ref_se        = se[_n]     if _n == 1
        by Study: replace ref_se        = se[_n - 1] if _n != 1
        generate theta_hat = log_hr - ref
        generate phi       = sqrt((se^2) + (ref_se^2))
        generate E_X2      = (theta_hat^2) + (phi^2)
        generate E2_X      = (1/c(pi)) * ///
                             exp(-((theta_hat^2)/(phi^2))) *                  ///
                              (                                               ///
                                (sqrt(2) * phi) +                             ///
                                exp((theta_hat^2) / (2 * (phi^2))) *          ///
                                theta_hat * sqrt(c(pi)) *                     ///
                                (2 * normal(theta_hat/phi) - 1)               ///
                              )^2
        by Study: replace se = sqrt(E_X2 - E2_X)

        by Study: drop if _n == 1 // Drop ref. levels, which by definition have RHR = 1.

        // Meta-analysis of RHRs.
        sort ``factor'_var', stable // Ensure that the forest plots show LOT in a sensible order.
        meta set norm_log_hr se, studylabel("")

        // Make a regular forest plot, which will probably be very long and thin,
        // but shows all study estimates, subgroup estimates, and overall estimate.
        meta forest, subgroup(Study)                                           ///
             nogbhomtests transform("Ratio of Hazard Ratios":exp)              ///
             nullrefline                                                       ///
             title("Ratio of hazard ratios for `outcome' with respect to ``factor'_title'")
        foreach ext of local exts {
          local this_figure "products/`factor'_rel_`outcome'.`ext'"
          local width = cond("`ext'" == "eps", "", "width(3000)")
          graph export "`this_figure'", replace `width'
        }

        // Make a compact (rather than long and thin) plot suitable for inclusion
        // in a journal paper.
        statsby , by(Study) clear : mymeta total_n
        meta set theta se, studylabel(Study)
        meta forest _id _plot _esci N total_n p _weight,                      ///
             columnopts(_id, title("`:variable label Study'"))                ///
             columnopts(N, title("RHRs"))                                     ///
             columnopts(total_n, title("  Patients"))                         ///
             columnopts(p, title("{it:p}-value") format("%9.3f"))             ///
             nogbhomtests transform("Mean RHR":exp)                           ///
             nullrefline                                                      ///
             title("Ratio of hazard ratios for `outcome' (``factor'_title')")
        foreach ext of local exts {
          local this_figure "products/compact_`factor'_rel_`outcome'.`ext'"
          local width = cond("`ext'" == "eps", "", "width(3000)")
          graph export "`this_figure'", replace `width'
        }

        // NOTE: ORIGINAL DATA ON RHR IS REPLACED BY STATSBY RESULTS.
      }
      frame drop `outcome'_tmp
    }
  }
}

set graphics on
