version 16.1

// Make forest plots to illustrate the need for the inversion
// step in meta-analysis of RHR.

capture frame drop inversion
frame create inversion
frame inversion {
  // Specify example (i.e., synthetic) data in which EM goes in
  // opposite directions. The RHRs and their SEs are specified
  // on the log RHR metric.
  input strL study_stratum float log_rhr float se
  // Studies 1 and 2 have +ve log RHR and therefore RHR > 1.
  "Study 1 — 2 Lines of treatment" 0.3      0.2
  "Study 1 — 3 Lines of treatment" 0.2      0.3
  "Study 2 — 2 Lines of treatment" 0.4      0.3
  "Study 2 — 3 Lines of treatment" 0.3      0.5
  // Studies 3 and 4 have -ve log RHR and therefore RHR < 1.
  "Study 3 — 2 Lines of treatment" -0.3      0.2
  "Study 3 — 3 Lines of treatment" -0.2      0.3
  "Study 4 — 2 Lines of treatment" -0.4      0.3
  "Study 5 — 3 Lines of treatment" -0.3      0.5
  end

  // Run a meta-analysis of this non-inverted data.
  meta set log_rhr se , studylabel(study_stratum)
  meta summarize

  // Now invert RHRs and re-run the meta-analysis.
  replace log_rhr = abs(log_rhr)
  meta update // Update the meta settings because the data have changed.
  meta summarize  

}
