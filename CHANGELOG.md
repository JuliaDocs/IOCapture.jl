# IOCapture.jl changelog

## Version `0.2.0`

* ![BREAKING][badge-breaking] ![Enhancement][badge-enhancement] The `iocapture` function has been renamed to `capture` and is no longer exported. The recommended way to refer to the function by fully qualifying the name (i.e. `IOCapture.capture`). ([#3][github-3], [#6][github-6])

  **For upgrading:** Instances of `iocapture` (or `IOCapture.iocapture`) should be replaced by `IOCapture.capture`.

* ![BREAKING][badge-breaking] ![Enhancement][badge-enhancement] The `throwerrors` keyword argument to `capture` (previously `iocapture`) has been renamed to `rethrow` and accepts now exception types as arguments (instead of `:interrupt`/`true`/`false`). ([#2][github-2], [#4][github-4], [#6][github-6])

  **For upgrading:**
  
  * Any uses of `throwerrors = ...` should be replaced by `rethrow = ...`.
  * `throwerrors = :interrupt` (or `rethrow = :interrupt`) should be replaced by `rethrow = InterrupException`.
  * `throwerrors = true` (or `rethrow = true`) should be replaced by `rethrow = Any`.
  * `throwerrors = false` (or `rethrow = false`) should be replaced by `rethrow = Union{}`.

## Version `0.1.1`

* ![Enhancement][badge-enhancement] `iocapture` now accepts the `color` keyword argument to enable the capturing of ANSI color sequences (on Julia 1.6 and above). ([#1][github-1])

## Version `0.1.0`

Initial release exporting the `iocapture` function.


[github-1]: https://github.com/JuliaDocs/IOCapture.jl/pull/1
[github-2]: https://github.com/JuliaDocs/IOCapture.jl/pull/2
[github-3]: https://github.com/JuliaDocs/IOCapture.jl/issues/3
[github-4]: https://github.com/JuliaDocs/IOCapture.jl/issues/4
[github-6]: https://github.com/JuliaDocs/IOCapture.jl/pull/6


[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-deprecation]: https://img.shields.io/badge/deprecation-orange.svg
[badge-feature]: https://img.shields.io/badge/feature-green.svg
[badge-enhancement]: https://img.shields.io/badge/enhancement-blue.svg
[badge-bugfix]: https://img.shields.io/badge/bugfix-purple.svg
[badge-security]: https://img.shields.io/badge/security-black.svg
[badge-experimental]: https://img.shields.io/badge/experimental-lightgrey.svg
[badge-maintenance]: https://img.shields.io/badge/maintenance-gray.svg

<!--
# Badges

![BREAKING][badge-breaking]
![Deprecation][badge-deprecation]
![Feature][badge-feature]
![Enhancement][badge-enhancement]
![Bugfix][badge-bugfix]
![Security][badge-security]
![Experimental][badge-experimental]
![Maintenance][badge-maintenance]
-->
