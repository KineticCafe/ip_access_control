# CHANGELOG

## 1.0.1

- Modified GitHub Actions testing range, 1.10 to 1.15. The code is still
  compatible with 1.8 and 1.9, but recent tests have failed on compiling
  telemetry; they have been soft-deprecated and have been removed from the test
  matrix.

  NOTE: credo, dialyxir, and ex_doc are only configured for 1.15 or later.

- Added DCO checking (we will require sign-offs moving forward).

- Added Dependabot configuration and automerge.

- Updated dependencies to the latest versions and verified dialyzer
  cleanliness.

- Undid the formatting when I enabled `force_do_end_blocks: true` in
  `.formatter.exs`.

## 1.0.0

- Initial release, extracted from one of our projects originally based on
  `plug_ip_whitelist`.
