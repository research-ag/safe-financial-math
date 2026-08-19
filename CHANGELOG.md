# Changelog

## 0.0.1

- initial version
- `multiplyNatByFloatMin`: precision-safe Nat-by-Float multiplication with
  flooring — the result is never above the exact product
- `multiplyNatByFloatMax`: precision-safe Nat-by-Float multiplication with
  ceiling — the result is never below the exact product
- both bounds are exact for operands of any magnitude: the multiplier is
  decomposed into the fraction `numerator / 2 ** k` it denotes and the product
  is evaluated on unbounded `Nat`s, so no intermediate `Float` rounding can push
  the result onto the unsafe side of the product
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
