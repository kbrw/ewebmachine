# Changelog

## [Unreleased]

### Changed

* `Ewebmachine.Plug.Send.call` now threads the `conn` struct to keep the updates instead of reusing the original one.

## v2.2

* Code janitoring wrt elixir versions: supports 1.3 - 1.6
* Validated against Cowboy 1 & 2

## v2.1.5

* Fix
  * Compilation with Plulg > 1.5 (https://github.com/kbrw/ewebmachine/issues/38)

## v2.1.4

* Feature: allow to name resources modules

## v2.1.3

* Bug fixes
  * make it compatible with elixir 1.4 without warnings
  * fix related regression

## v2.0.9

* Bug fixes
  * Plug version spec and plug update to 1.0

## v2.0.8

* Bug fixes
  * `accept_helper` is used in non terminal decision, so halt conn in case of 415 (else in some case, 415 became 200)

## v2.0.7

* Bug fixes
  * All headers must be lower case to respect Plug.conn convention, updated tests
  * add PATCH to default known methods, currently no other support, so to use PATCH
    - set Accept-Patch in `option` with accepted media types, 
    - set handler for these types in `content-types-accepted`
    - implement `resources_exists` to convert `PATCH` method to `PUT` if the resource exists

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
