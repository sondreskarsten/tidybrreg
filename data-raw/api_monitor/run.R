source("data-raw/api_monitor/monitor.R")
source("data-raw/api_monitor/prevalence.R")

args <- commandArgs(trailingOnly = TRUE)
update <- "--update" %in% args
counts_path <- args[!grepl("^--", args)][1]

bp <- bayes_period(counts_path, update_baseline = update)
sr <- sources_run(update_baseline = update)

report <- paste(bp$report, "\n\n", sr$report, "\n")
cat(report)
writeLines(report, "data-raw/api_monitor/last_report.md")

if ((isTRUE(bp$drift) || isTRUE(sr$drift)) && !update) quit(status = 1)
