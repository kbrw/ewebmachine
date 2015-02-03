# Changelog

## v2.0.7

* Bug fixes
  * All headers must be lower case to respect Plug.conn convention, updated tests

## v2.0.6

* Bug fixes
  * Debug call log size were O(n^2), make it O(n) removing `conn.private` from
    the log

## v2.0.5

* Enhancements
  * `{:halt,code}` works in more cases because it now `throws` the `conn` to
    break the decision flow.
  * Make it possible to use `Ewebmachine.Plug.Debug` not at the routing root,
    with relative assets. Thanks to @yrashk.
  * Make it possible to use a fuzzy `content_types_accepted` media type. 
    Thanks again to @yrashk.
  * little changes to allow to chain ewebmachine handler definitions and run
  * 2 nice plugs to handle errors after a run : `ErrorAsException` and `ErrorAsForward`
  * A macro to set common plug pipeline use cases : `resources_plugs`
  * Change Logging from a simple Agent to ETS
  * add this CHANGELOG

* Bug fixes
  * Bug in create path relative handling, use Conn.full_path to use the
    `script_name` and the `path_info`

## v2.0.4

* Bug fixes
  * Avoid module name collision with resource module function changing the
    naming scheme.

## v2.0.3

* Bug fixes
  * `Ewebmachine.Plug.Run` should run only if the `:machine_init` option has
    been set.

## v2.0.2

* Enhancements
  * Add `:default_plugs` option to `Ewebmachine.Builder.Resources`.

## v2.0.1

* Bug fixes
  * Makes `{:halt,code}` management works correctly, add test.

## v2.0.1

* Bug fixes
  * Makes `{:halt,code}` management works correctly.
