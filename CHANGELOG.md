# Changelog

## 0.0.1

- initial version
- `multiplyNatByFloatMin`: Nat-by-Float multiplication with flooring, rounding
  a plain `Float` product
- `multiplyNatByFloatMax`: Nat-by-Float multiplication with ceiling, rounding a
  plain `Float` product
- both keep the representation error of a decimal multiplier from costing a
  unit (`multiplyNatByFloatMax(4_000, 0.0125)` is `50`, not `51`) at the cost
  of the result being up to one unit off the exact product; both are a safe
  bound only while `value` and the product stay below `2 ** 53`, above which
  the `Float` product can drift from the exact product by more than one unit
- `multiplyNatByFloatMinSafe` / `multiplyNatByFloatMaxSafe`: precision-safe
  counterparts that behave identically to `multiplyNatByFloatMin` /
  `multiplyNatByFloatMax` below `2 ** 53`, but switch to exact integer
  arithmetic once the product reaches that limit, where `Float` can no longer
  represent every integer and rounding to nearest can land arbitrarily far on
  the unsafe side of the product: the multiplier is decomposed into the
  fraction `numerator / 2 ** k` it denotes and the product is evaluated on
  unbounded `Nat`s, so the result is a safe bound at any magnitude
- `scaleFloat`: scale a Float by a power of ten
- `DecimalInt` module: arbitrary-precision, `Int`-backed decimal type
  (`value * 10 ** (-decimals)`) with exact `add`/`sub`/`mul`, `neg`/`abs`
  (`abs` returns a `DecimalNat`), `compare`/`equal`, and
  `floor`/`ceil`/`round`/`toFloat`/`toText` conversions
- `DecimalNat` module: the non-negative, `Nat`-backed counterpart with exact
  `add`/`sub` (traps on underflow)/`mul`, `compare`/`equal`, and
  `floor`/`ceil`/`round`/`toFloat`/`toText` conversions
- `DecimalInt.fromFloat` / `DecimalNat.fromFloat`: construct a decimal from a
  `Float` by keeping exactly `digits` significant decimal digits of it,
  reproducing the double's own digits rather than rounding to the nearest
  value or recovering the shorter decimal a human may have written; this pays
  the `Float` imprecision once, at the boundary, rather than compounding it
  across every subsequent exact operation. `f == 0.0` (or `-0.0`) always
  returns `0`, regardless of `digits`. Traps on `NaN` or infinite `f` (neither
  denotes a decimal number), and `DecimalNat.fromFloat` additionally traps on
  a negative `f`
- `floor` rounds towards negative infinity and `ceil` towards positive
  infinity, so in `DecimalInt` the direction is relative to the number line and
  not to zero (`floor(-1.75)` is `-2`, `ceil(-1.75)` is `-1`)
- benchmarks: added `bench/decimal-int.bench.mo` and `bench/decimal-nat.bench.mo`
  covering the decimal operations alongside the safe-float benchmarks in
  `bench/lib.bench.mo`
