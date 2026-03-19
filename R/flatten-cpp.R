#' Get the fast C++ flatten function, JIT-compiling on first use
#'
#' Returns a compiled C++ function that replaces flatten_page_patches().
#' Requires Rcpp in Suggests. Compiled once per session and cached in
#' .brregEnv. Returns NULL if Rcpp is not available.
#'
#' @keywords internal
get_flatten_cpp <- function() {
  if (exists(".flatten_cpp", envir = .brregEnv)) {
    return(get(".flatten_cpp", envir = .brregEnv))
  }

  if (!requireNamespace("Rcpp", quietly = TRUE)) {
    assign(".flatten_cpp", NULL, envir = .brregEnv)
    return(NULL)
  }

  cpp_src <- '
#include <Rcpp.h>
using namespace Rcpp;

// Replace "/" with "_" in a std::string
std::string slash_to_under(const std::string& s) {
  std::string out = s;
  for (auto& c : out) if (c == \'/\') c = \'_\';
  return out;
}

// Remove leading "/" from path
std::string strip_leading_slash(const std::string& s) {
  if (!s.empty() && s[0] == \'/\') return s.substr(1);
  return s;
}

// Get a string from a list element, or NA
String safe_string(List x, const char* key) {
  if (!x.containsElementNamed(key)) return NA_STRING;
  SEXP val = x[key];
  if (Rf_isNull(val)) return NA_STRING;
  if (TYPEOF(val) == STRSXP && Rf_length(val) > 0) return as<String>(val);
  if (TYPEOF(val) == INTSXP && Rf_length(val) > 0) return String(std::to_string(as<int>(val)));
  if (TYPEOF(val) == REALSXP && Rf_length(val) > 0) return String(std::to_string((int)as<double>(val)));
  return NA_STRING;
}

int safe_int(List x, const char* key) {
  if (!x.containsElementNamed(key)) return NA_INTEGER;
  SEXP val = x[key];
  if (Rf_isNull(val)) return NA_INTEGER;
  if (TYPEOF(val) == INTSXP) return as<int>(val);
  if (TYPEOF(val) == REALSXP) return (int)as<double>(val);
  return NA_INTEGER;
}

// Convert any SEXP scalar to string
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
    // Avoid trailing zeros for integers stored as double
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

  IntegerVector r_uid(est);
  CharacterVector r_org(est);
  CharacterVector r_ctype(est);
  CharacterVector r_ts(est);
  CharacterVector r_op(est);
  CharacterVector r_field(est);
  CharacterVector r_val(est);
  int k = 0;

  auto maybe_grow = [&]() {
    if (k >= r_uid.size()) {
      int new_size = r_uid.size() * 2;
      IntegerVector new_uid(new_size); CharacterVector new_org(new_size);
      CharacterVector new_ctype(new_size); CharacterVector new_ts(new_size);
      CharacterVector new_op(new_size); CharacterVector new_field(new_size);
      CharacterVector new_val(new_size);
      for (int i = 0; i < k; i++) {
        new_uid[i] = r_uid[i]; new_org[i] = r_org[i];
        new_ctype[i] = r_ctype[i]; new_ts[i] = r_ts[i];
        new_op[i] = r_op[i]; new_field[i] = r_field[i];
        new_val[i] = r_val[i];
      }
      r_uid = new_uid; r_org = new_org; r_ctype = new_ctype;
      r_ts = new_ts; r_op = new_op; r_field = new_field; r_val = new_val;
    }
  };

  auto emit = [&](int uid, String org, String ctype, String ts,
                   String op, const std::string& field, String val) {
    maybe_grow();
    r_uid[k] = uid; r_org[k] = org; r_ctype[k] = ctype;
    r_ts[k] = ts; r_op[k] = op;
    r_field[k] = field; r_val[k] = val;
    k++;
  };

  for (int i = 0; i < n; i++) {
    List u = raw_updates[i];
    int uid = safe_int(u, "oppdateringsid");
    String org = safe_string(u, "organisasjonsnummer");
    String ctype = safe_string(u, "endringstype");
    String ts = safe_string(u, "dato");

    if (!u.containsElementNamed("endringer")) continue;
    SEXP endringer_sexp = u["endringer"];
    if (Rf_isNull(endringer_sexp) || TYPEOF(endringer_sexp) != VECSXP) continue;
    List endringer(endringer_sexp);
    if (endringer.size() == 0) continue;

    for (int ei = 0; ei < endringer.size(); ei++) {
      List e = endringer[ei];
      String op_str = safe_string(e, "op");
      std::string path = "";
      if (e.containsElementNamed("path")) {
        SEXP ps = e["path"];
        if (!Rf_isNull(ps) && TYPEOF(ps) == STRSXP)
          path = as<std::string>(ps);
      }
      path = strip_leading_slash(path);

      bool is_remove = false;
      if (op_str != NA_STRING) {
        std::string op_s = as<std::string>(op_str);
        is_remove = (op_s == "remove");
      }

      if (is_remove || !e.containsElementNamed("value") || Rf_isNull(e["value"])) {
        emit(uid, org, ctype, ts, op_str, slash_to_under(path), NA_STRING);
        continue;
      }

      SEXP val = e["value"];

      // Scalar
      if (Rf_isNull(val)) {
        emit(uid, org, ctype, ts, op_str, slash_to_under(path), NA_STRING);
        continue;
      }

      if (TYPEOF(val) != VECSXP) {
        emit(uid, org, ctype, ts, op_str, slash_to_under(path), sexp_to_string(val));
        continue;
      }

      List val_list(val);

      // Named list (object) — depth 1
      if (!Rf_isNull(val_list.names())) {
        CharacterVector keys = val_list.names();
        for (int ki = 0; ki < keys.size(); ki++) {
          std::string child_path = path + "_" + as<std::string>(keys[ki]);
          SEXP child = val_list[ki];

          if (Rf_isNull(child)) {
            emit(uid, org, ctype, ts, op_str, slash_to_under(child_path), NA_STRING);
            continue;
          }

          // Child is unnamed list (array) — depth 2
          if (TYPEOF(child) == VECSXP && Rf_isNull(Rf_getAttrib(child, R_NamesSymbol))) {
            List arr(child);
            for (int ai = 0; ai < arr.size(); ai++) {
              std::string arr_path = child_path + "_" + std::to_string(ai);
              SEXP arr_val = arr[ai];
              emit(uid, org, ctype, ts, op_str, slash_to_under(arr_path),
                   Rf_isNull(arr_val) ? NA_STRING : sexp_to_string(arr_val));
            }
          } else if (TYPEOF(child) == VECSXP) {
            // Named child at depth 2 — serialize as string (shouldn't happen with brreg)
            emit(uid, org, ctype, ts, op_str, slash_to_under(child_path), NA_STRING);
          } else {
            emit(uid, org, ctype, ts, op_str, slash_to_under(child_path), sexp_to_string(child));
          }
        }
        continue;
      }

      // Unnamed list (array) — depth 1
      for (int ai = 0; ai < val_list.size(); ai++) {
        std::string arr_path = path + "_" + std::to_string(ai);
        SEXP arr_val = val_list[ai];
        emit(uid, org, ctype, ts, op_str, slash_to_under(arr_path),
             Rf_isNull(arr_val) ? NA_STRING : sexp_to_string(arr_val));
      }
    }
  }

  // Trim to actual size
  IntegerVector f_uid(k); CharacterVector f_org(k); CharacterVector f_ctype(k);
  CharacterVector f_ts(k); CharacterVector f_op(k);
  CharacterVector f_field(k); CharacterVector f_val(k);
  for (int i = 0; i < k; i++) {
    f_uid[i] = r_uid[i]; f_org[i] = r_org[i]; f_ctype[i] = r_ctype[i];
    f_ts[i] = r_ts[i]; f_op[i] = r_op[i]; f_field[i] = r_field[i]; f_val[i] = r_val[i];
  }

  return DataFrame::create(
    Named("update_id") = f_uid,
    Named("org_nr") = f_org,
    Named("change_type") = f_ctype,
    Named("timestamp") = f_ts,
    Named("operation") = f_op,
    Named("field") = f_field,
    Named("new_value") = f_val,
    Named("stringsAsFactors") = false
  );
}
'

  fn <- tryCatch({
    Rcpp::cppFunction(cpp_src, rebuild = FALSE)
  }, error = function(e) {
    NULL
  })

  assign(".flatten_cpp", fn, envir = .brregEnv)
  fn
}
