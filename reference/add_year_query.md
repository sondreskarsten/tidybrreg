# Append the `år` query parameter with its UTF-8 percent-encoding

The parameter name is non-ASCII.
[`httr2::req_url_query()`](https://httr2.r-lib.org/reference/req_url.html)
escapes names in the session's native encoding, which in a non-UTF-8
session renders the name as `<c3><a5>r` rather than `%C3%A5r`, so the
name is appended pre-encoded and the same bytes are sent in every
locale.

## Usage

``` r
add_year_query(req, year)
```
