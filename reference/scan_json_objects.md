# Find the top-level object ends in the unscanned part of a buffer

Vectorised: the positions of quotes not preceded by an odd run of
backslashes toggle the string state; braces outside strings move the
depth; a `}` that brings the depth back to zero ends an object. The
state (depth, string flag, bytes already scanned) carries across calls
so each byte is examined once.

## Usage

``` r
scan_json_objects(buf, state)
```
