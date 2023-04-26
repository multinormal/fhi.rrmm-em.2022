version 16.1

set graphics off

// Make forest plots to illustrate the need for the inversion
// step in meta-analysis of RHR.

capture frame drop inversion
frame create inversion
frame inversion {
  // Specify example (i.e., synthetic) data in which EM goes in
  // opposite directions. The RHRs and their SEs are specified
  // on the log RHR metric.
  input strL(study stratum) float(log_rhr se)
  // Studies 1 and 2 have +ve log RHR and therefore RHR > 1.
  "Study 1" "2 Lines of treatment"  0.3 0.2
  "Study 1" "3 Lines of treatment"  0.2 0.3
  "Study 2" "2 Lines of treatment"  0.4 0.3
  "Study 2" "3 Lines of treatment"  0.3 0.5
  // Studies 3 and 4 have -ve log RHR and therefore RHR < 1.
  "Study 3" "2 Lines of treatment" -0.3 0.2
  "Study 3" "3 Lines of treatment" -0.2 0.3
  "Study 4" "2 Lines of treatment" -0.4 0.3
  "Study 4" "3 Lines of treatment" -0.3 0.5
  end

  // Specify options to -meta forestplot-.
  local opts        columnopts(_id , title("")) nullrefline
  local opts `opts' xscale(range(0.25 4)) xlabel(0.25 "¼" 0.5 "½" 1 "1" 2 "2" 4 "4")

  // Run a meta-analysis of this non-inverted data.
  meta set log_rhr se , studylabel(stratum)
  meta forestplot , eform("RHR") subgroup(study) `opts'
  foreach ext in png eps {
    local this_figure "products/inversion-no.`ext'"
    local width = cond("`ext'" == "eps", "", "width(3000)")
    graph export "`this_figure'", replace `width'
  }

  // Now invert RHRs and re-run the meta-analysis.
  replace log_rhr = abs(log_rhr)
  meta update // Update the meta settings because the data have changed.
  meta forestplot , eform("RHR") subgroup(study) `opts'
  foreach ext in png eps {
    local this_figure "products/inversion-yes.`ext'"
    local width = cond("`ext'" == "eps", "", "width(3000)")
    graph export "`this_figure'", replace `width'
  }
}

set graphics on
