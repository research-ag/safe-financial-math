# Changelog

## 0.0.1

- initial version
- `multiplyNatByFloatMin`: precision-safe Nat-by-Float multiplication with
  flooring
- `multiplyNatByFloatMax`: precision-safe Nat-by-Float multiplication with
  ceiling
- both switch to exact integer arithmetic once the product reaches `2 ** 53`,
  where `Float` can no longer represent every integer and rounding to nearest
  can land arbitrarily far on the unsafe side of the product: the multiplier is
  decomposed into the fraction `numerator / 2 ** k` it denotes and the product
  is evaluated on unbounded `Nat`s. Below `2 ** 53` the `Float` product is
  rounded as before, which keeps the representation error of a decimal
  multiplier from costing a unit (`multiplyNatByFloatMax(4_000, 0.0125)` is
  `50`, not `51`) at the cost of the result being up to one unit off the exact
  product
- `scaleFloat`: scale a Float by a power of ten
- `DecimalInt` module: arbitrary-precision, `Int`-backed decimal type
  (`value * 10 ** (-decimals)`) with exact `add`/`sub`/`mul`, `neg`/`abs`
  (`abs` returns a `DecimalNat`), `compare`/`equal`, and
  `round`/`toFloat`/`toText` conversions
- `DecimalNat` module: the non-negative, `Nat`-backed counterpart with exact
  `add`/`sub` (traps on underflow)/`mul`, `compare`/`equal`, and
  `round`/`toFloat`/`toText` conversions
- benchmarks: added `bench/decimal-int.bench.mo` and `bench/decimal-nat.bench.mo`
  covering the decimal operations alongside the safe-float benchmarks in
  `bench/lib.bench.mo`
