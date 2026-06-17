source("data-raw/api_monitor/monitor.R")

args <- commandArgs(trailingOnly = TRUE)
update <- "--update" %in% args
schema_path <- args[!grepl("^--", args)][1]

res <- api_monitor_run(schema_path = schema_path, update_baseline = update)

cat(res$report)
cat("\n")
writeLines(res$report, "data-raw/api_monitor/last_report.md")
writeLines(res$news, "data-raw/api_monitor/news_snippet.md")

if (isTRUE(res$drift) && !update) quit(status = 1)
