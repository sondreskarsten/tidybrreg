#' Get the fast C++ flatten function, JIT-compiling on first use
#'
#' Returns a compiled C++ function that replaces flatten_page_patches().
#' Only compiles when `options(tidybrreg.use_cpp = TRUE)` is set.
#' Requires Rcpp in Suggests. Compiled once per session (~10s) and
#' cached in .brregEnv.
#'
#' @keywords internal
get_flatten_cpp <- function() {
  if (exists(".flatten_cpp", envir = .brregEnv)) {
    return(get(".flatten_cpp", envir = .brregEnv))
  }

  if (!isTRUE(getOption("tidybrreg.use_cpp"))) {
    return(NULL)
  }

  if (!requireNamespace("Rcpp", quietly = TRUE)) {
    assign(".flatten_cpp", NULL, envir = .brregEnv)
    return(NULL)
  }

  cli::cli_alert_info("Compiling C++ flatten (one-time, ~10s)...")

  fn <- tryCatch({
    Rcpp::cppFunction(flatten_cpp_source(), plugins = "cpp11", rebuild = FALSE)
  }, error = function(e) {
    cli::cli_alert_warning("C++ compilation failed: {e$message}. Using R fallback.")
    NULL
  })

  assign(".flatten_cpp", fn, envir = .brregEnv)

  if (!is.null(fn)) cli::cli_alert_success("C++ flatten ready.")
  fn
}


#' C++ source for flatten_patches_cpp
#' @keywords internal
flatten_cpp_source <- function() {
'
#include <Rcpp.h>
using namespace Rcpp;

std::string slash_to_under(const std::string& s) {
  std::string out = s;
  for (size_t i = 0; i < out.size(); i++) if (out[i] == \'/\') out[i] = \'_\';
  return out;
}

String sexp_to_string(SEXP val) {
  if (Rf_isNull(val)) return NA_STRING;
  if (TYPEOF(val) == STRSXP && Rf_length(val) > 0) return String(CHAR(STRING_ELT(val, 0)));
  if (TYPEOF(val) == INTSXP && Rf_length(val) > 0) {
    int v = INTEGER(val)[0];
    if (v == NA_INTEGER) return NA_STRING;
    return String(std::to_string(v));
  }
  if (TYPEOF(val) == REALSXP && Rf_length(val) > 0) {
    double v = REAL(val)[0];
    if (ISNA(v)) return NA_STRING;
    if (v == (int)v) return String(std::to_string((int)v));
    return String(std::to_string(v));
  }
  if (TYPEOF(val) == LGLSXP && Rf_length(val) > 0) {
    int v = LOGICAL(val)[0];
    if (v == NA_LOGICAL) return NA_STRING;
    return String(v ? "true" : "false");
  }
  return NA_STRING;
}

// [[Rcpp::export]]
DataFrame flatten_patches_cpp(List raw_updates) {
  int n = raw_updates.size();
  int est = n * 8;

  std::vector<int> v_uid;          v_uid.reserve(est);
  std::vector<String> v_org;       v_org.reserve(est);
  std::vector<String> v_ctype;     v_ctype.reserve(est);
  std::vector<String> v_ts;        v_ts.reserve(est);
  std::vector<String> v_op;        v_op.reserve(est);
  std::vector<std::string> v_field; v_field.reserve(est);
  std::vector<String> v_val;       v_val.reserve(est);

  for (int i = 0; i < n; i++) {
    List u = as<List>(raw_updates[i]);

    int uid = NA_INTEGER;
    if (u.containsElementNamed("oppdateringsid")) {
      SEXP s = u["oppdateringsid"];
      if (TYPEOF(s) == INTSXP) uid = as<int>(s);
      else if (TYPEOF(s) == REALSXP) uid = (int)as<double>(s);
    }

    String org = NA_STRING;
    if (u.containsElementNamed("organisasjonsnummer")) {
      SEXP s = u["organisasjonsnummer"];
      if (!Rf_isNull(s) && TYPEOF(s) == STRSXP) org = String(CHAR(STRING_ELT(s, 0)));
    }

    String ctype = NA_STRING;
    if (u.containsElementNamed("endringstype")) {
      SEXP s = u["endringstype"];
      if (!Rf_isNull(s) && TYPEOF(s) == STRSXP) ctype = String(CHAR(STRING_ELT(s, 0)));
    }

    String ts = NA_STRING;
    if (u.containsElementNamed("dato")) {
      SEXP s = u["dato"];
      if (!Rf_isNull(s) && TYPEOF(s) == STRSXP) ts = String(CHAR(STRING_ELT(s, 0)));
    }

    if (!u.containsElementNamed("endringer")) continue;
    SEXP end_sexp = u["endringer"];
    if (Rf_isNull(end_sexp) || TYPEOF(end_sexp) != VECSXP) continue;
    List endringer(end_sexp);
    if (endringer.size() == 0) continue;

    for (int ei = 0; ei < endringer.size(); ei++) {
      List e = as<List>(endringer[ei]);

      String op_str = NA_STRING;
      std::string op_s = "";
      if (e.containsElementNamed("op")) {
        SEXP s = e["op"];
        if (!Rf_isNull(s) && TYPEOF(s) == STRSXP) {
          op_s = CHAR(STRING_ELT(s, 0));
          op_str = String(op_s);
        }
      }

      std::string path = "";
      if (e.containsElementNamed("path")) {
        SEXP s = e["path"];
        if (!Rf_isNull(s) && TYPEOF(s) == STRSXP) {
          path = CHAR(STRING_ELT(s, 0));
          if (!path.empty() && path[0] == \'/\') path = path.substr(1);
        }
      }

      bool is_remove = (op_s == "remove");
      bool no_value = !e.containsElementNamed("value") || Rf_isNull(e["value"]);

      if (is_remove || no_value) {
        v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
        v_ts.push_back(ts); v_op.push_back(op_str);
        v_field.push_back(slash_to_under(path)); v_val.push_back(NA_STRING);
        continue;
      }

      SEXP val = e["value"];

      if (Rf_isNull(val)) {
        v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
        v_ts.push_back(ts); v_op.push_back(op_str);
        v_field.push_back(slash_to_under(path)); v_val.push_back(NA_STRING);
        continue;
      }

      if (TYPEOF(val) != VECSXP) {
        v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
        v_ts.push_back(ts); v_op.push_back(op_str);
        v_field.push_back(slash_to_under(path)); v_val.push_back(sexp_to_string(val));
        continue;
      }

      List val_list(val);
      SEXP names_sexp = Rf_getAttrib(val, R_NamesSymbol);
      bool has_names = !Rf_isNull(names_sexp);

      if (has_names) {
        CharacterVector keys(names_sexp);
        for (int ki = 0; ki < keys.size(); ki++) {
          std::string cpath = path + "_" + as<std::string>(keys[ki]);
          SEXP child = val_list[ki];

          if (Rf_isNull(child)) {
            v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
            v_ts.push_back(ts); v_op.push_back(op_str);
            v_field.push_back(slash_to_under(cpath)); v_val.push_back(NA_STRING);
            continue;
          }

          if (TYPEOF(child) == VECSXP && Rf_isNull(Rf_getAttrib(child, R_NamesSymbol))) {
            List arr(child);
            for (int ai = 0; ai < arr.size(); ai++) {
              std::string apath = cpath + "_" + std::to_string(ai);
              SEXP av = arr[ai];
              v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
              v_ts.push_back(ts); v_op.push_back(op_str);
              v_field.push_back(slash_to_under(apath));
              v_val.push_back(Rf_isNull(av) ? NA_STRING : sexp_to_string(av));
            }
          } else {
            v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
            v_ts.push_back(ts); v_op.push_back(op_str);
            v_field.push_back(slash_to_under(cpath)); v_val.push_back(sexp_to_string(child));
          }
        }
        continue;
      }

      for (int ai = 0; ai < val_list.size(); ai++) {
        std::string apath = path + "_" + std::to_string(ai);
        SEXP av = val_list[ai];
        v_uid.push_back(uid); v_org.push_back(org); v_ctype.push_back(ctype);
        v_ts.push_back(ts); v_op.push_back(op_str);
        v_field.push_back(slash_to_under(apath));
        v_val.push_back(Rf_isNull(av) ? NA_STRING : sexp_to_string(av));
      }
    }
  }

  int k = v_uid.size();
  IntegerVector f_uid(k);
  CharacterVector f_org(k), f_ctype(k), f_ts(k), f_op(k), f_field(k), f_val(k);
  for (int i = 0; i < k; i++) {
    f_uid[i] = v_uid[i]; f_org[i] = v_org[i]; f_ctype[i] = v_ctype[i];
    f_ts[i] = v_ts[i]; f_op[i] = v_op[i]; f_field[i] = String(v_field[i]);
    f_val[i] = v_val[i];
  }

  return DataFrame::create(
    Named("update_id") = f_uid, Named("org_nr") = f_org,
    Named("change_type") = f_ctype, Named("timestamp") = f_ts,
    Named("operation") = f_op, Named("field") = f_field,
    Named("new_value") = f_val, Named("stringsAsFactors") = false
  );
}
'
}
