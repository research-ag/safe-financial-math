# Safe financial math for Motoko

## Overview

`safe-financial-math` provides small, dependency-light arithmetic helpers for
combining large integer token quantities (`Nat`) with floating-point prices
(`Float`) without the precision loss and rounding drift that plague naive
`Float` arithmetic.

The package is organised as a few modules:

- the root module (`mo:safe-financial-math`) — `Nat`-by-`Float` multiplication,
  both a plain, cheaper form (`multiplyNatByFloatMin` / `multiplyNatByFloatMax`)
  and a precision-safe form for operands that may exceed `2 ** 53`
  (`multiplyNatByFloatMinSafe` / `multiplyNatByFloatMaxSafe`), plus decimal
  scaling (`scaleFloat`);
- `mo:safe-financial-math/DecimalInt` — an arbitrary-precision, `Int`-backed
  `DecimalInt` type for exact, signed base-ten arithmetic with no `Float`
  involved;
- `mo:safe-financial-math/DecimalNat` — the non-negative counterpart backed by
  a `Nat`, for quantities that can never be negative (`sub` traps on
  underflow).

### Links

The package is published on [MOPS](https://mops.one/safe-financial-math) and [GitHub](https://github.com/research-ag/safe-financial-math).

The API documentation can be found [here](https://mops.one/safe-financial-math/docs).

For updates, help, questions, feedback and other requests related to this package join us on:

- [OpenChat group](https://oc.app/2zyqk-iqaaa-aaaar-anmra-cai)
- [Twitter](https://twitter.com/mr_research_ag)
- [Dfinity forum](https://forum.dfinity.org/)

### Motivation

A Motoko `Float` is a 64-bit IEEE 754 double with a 53-bit mantissa. Any integer
larger than `2 ** 53` cannot be represented exactly, so a naive
`Float.fromInt(value) * price` rounds to nearest twice — once when converting
the token amount and once when multiplying — and either rounding can go in the
unsafe direction. In a financial setting this is dangerous: rounding a payout up
means a canister can pay out more than it took in and drain its own reserves.

This package makes the rounding direction explicit and bounds it safely:

- multiply-and-**floor** for amounts you pay out (never overpay), and
- multiply-and-**ceil** for amounts you collect or require (never undercharge).

While the product stays below `2 ** 53`, where every integer is still
representable, the `Float` result is at most one unit away from the exact
product and rounding it is enough — this is what `multiplyNatByFloatMin` /
`multiplyNatByFloatMax` do, always. Above `2 ** 53` that is no longer enough:
`multiplyNatByFloatMinSafe` / `multiplyNatByFloatMaxSafe` detect the crossing
and fall back to exact, unbounded integer arithmetic, so the bound holds at any
magnitude, at the cost of being slower whenever that fallback is taken.

### Interface

Root module (`mo:safe-financial-math`):

```motoko
module {
  // Multiplies value by multiplier, flooring the result. Cheap, but only a
  // safe payout amount while value and the product stay below 2 ** 53.
  public func multiplyNatByFloatMin(value : Nat, multiplier : Float) : Nat;

  // Multiplies value by multiplier, ceiling the result. Cheap, but only a
  // safe required amount while value and the product stay below 2 ** 53.
  public func multiplyNatByFloatMax(value : Nat, multiplier : Float) : Nat;

  // Like multiplyNatByFloatMin, but falls back to exact integer arithmetic
  // above 2 ** 53, so it is a safe payout amount at any magnitude.
  public func multiplyNatByFloatMinSafe(value : Nat, multiplier : Float) : Nat;

  // Like multiplyNatByFloatMax, but falls back to exact integer arithmetic
  // above 2 ** 53, so it is a safe required amount at any magnitude.
  public func multiplyNatByFloatMaxSafe(value : Nat, multiplier : Float) : Nat;

  // Converts value to Float after truncating unrepresentable low-order bits.
  public func intToFloatFloor(value : Nat) : Float;

  // Scales value by 10 ** decimals (positive scales up, negative scales down).
  public func scaleFloat(value : Float, decimals : Int) : Float;
};

```

`DecimalInt` module (`mo:safe-financial-math/DecimalInt`) — a `DecimalInt`
denotes `value * 10 ** (-decimals)`, so `(123, 2)` is `1.23` and `(123, -2)` is
`12300`:

```motoko
module {
  public type DecimalInt = { value : Int; decimals : Int };

  public func new(value : Int, decimals : Int) : DecimalInt;
  public func fromInt(n : Int) : DecimalInt;
  public func fromFloat(f : Float, digits : Nat) : DecimalInt; // f's own digits, not rounded to nearest

  public func add(a : DecimalInt, b : DecimalInt) : DecimalInt; // exact
  public func sub(a : DecimalInt, b : DecimalInt) : DecimalInt; // exact
  public func mul(a : DecimalInt, b : DecimalInt) : DecimalInt; // exact
  public func neg(a : DecimalInt) : DecimalInt;
  public func abs(a : DecimalInt) : DecimalNat; // magnitude as a DecimalNat

  public func compare(a : DecimalInt, b : DecimalInt) : Order.Order;
  public func equal(a : DecimalInt, b : DecimalInt) : Bool;

  public func floor(d : DecimalInt) : Int; // towards -infinity
  public func ceil(d : DecimalInt) : Int; // towards +infinity
  public func round(d : DecimalInt) : Int; // nearest, half away from zero
  public func toFloat(d : DecimalInt) : Float; // approximate
  public func toText(d : DecimalInt) : Text;
};

```

`DecimalNat` module (`mo:safe-financial-math/DecimalNat`) — the non-negative
counterpart, backed by a `Nat`. It has the same interface minus `neg`/`abs`,
`sub` traps on underflow, and `floor`/`ceil`/`round` return a `Nat`:

```motoko
module {
  public type DecimalNat = { value : Nat; decimals : Int };

  public func new(value : Nat, decimals : Int) : DecimalNat;
  public func fromNat(n : Nat) : DecimalNat;
  public func fromFloat(f : Float, digits : Nat) : DecimalNat; // f's own digits, not rounded to nearest; traps if f < 0

  public func add(a : DecimalNat, b : DecimalNat) : DecimalNat; // exact
  public func sub(a : DecimalNat, b : DecimalNat) : DecimalNat; // exact, traps on underflow
  public func mul(a : DecimalNat, b : DecimalNat) : DecimalNat; // exact

  public func compare(a : DecimalNat, b : DecimalNat) : Order.Order;
  public func equal(a : DecimalNat, b : DecimalNat) : Bool;

  public func floor(d : DecimalNat) : Nat; // truncates the fractional part
  public func ceil(d : DecimalNat) : Nat; // rounds any fractional part up
  public func round(d : DecimalNat) : Nat; // nearest, half up
  public func toFloat(d : DecimalNat) : Float; // approximate
  public func toText(d : DecimalNat) : Text;
};

```

## Usage

### Install with mops

You need `mops` installed. In your project directory run:

```
mops add safe-financial-math
```

In the Motoko source file import the package as:

```
import FinancialMath "mo:safe-financial-math";
```

### Example

```motoko
import FinancialMath "mo:safe-financial-math";

// A bidder buys 4_000 base units at a clearing price of 0.0125 quote per unit.
// Both operands are well below 2 ** 53, so the plain variants are enough.
// Use the flooring variant for the payout so the canister never overpays.
let payout = FinancialMath.multiplyNatByFloatMin(4_000, 0.0125); // 50

// Use the ceiling variant for a required deposit so the canister never
// undercharges.
let required = FinancialMath.multiplyNatByFloatMax(4_000, 0.0125); // 50

// When value or the product might exceed 2 ** 53 (e.g. quantities in a
// token's smallest denomination), use the Safe variants instead so the bound
// holds at any magnitude.
let bigPayout = FinancialMath.multiplyNatByFloatMinSafe(50_000_000_000_000_000_000, 0.0125);

// Convert a human price into a token's raw integer scale (8 decimals).
let scaled = FinancialMath.scaleFloat(0.0125, 8); // 1_250_000.0

```

```motoko
import DecimalNat "mo:safe-financial-math/DecimalNat";

// Exact base-ten arithmetic with no Float rounding, for arbitrarily large
// non-negative numbers.
let price = DecimalNat.new(123, 2); // 1.23
let qty = DecimalNat.new(4_000, 0); // 4000
let total = DecimalNat.mul(price, qty); // 4920.00

let owed = DecimalNat.round(total); // 4920
let shown = DecimalNat.toText(total); // "4920.00"

// Pin a Float price to a fixed number of significant decimal digits, once,
// at the boundary where it enters exact arithmetic. fromFloat keeps the
// double's own digits rather than rounding to the nearest value, so pick
// enough digits to cover the precision that matters.
let clearingPrice = DecimalNat.fromFloat(0.0125, 3); // 0.0125

```

### Build & test

We need up-to-date versions of `node`, `moc` and `mops` installed.

Then run:

```
git clone git@github.com:research-ag/safe-financial-math.git
mops install
mops test
```

### Benchmark

Run

```
mops bench
```

### Format the code

We use `prettier` with the `prettier-plugin-motoko` plugin (configured in `.prettierrc`). The CI checks formatting on every pull request.

To format the code locally run:

```
npx -y prettier --plugin prettier-plugin-motoko --write '**/*.{mo,json,md}'
```

To only check the formatting (as CI does) run:

```
npx -y prettier --plugin prettier-plugin-motoko --check '**/*.{mo,json,md}'
```

## Design

`multiplyNatByFloatMin` and `multiplyNatByFloatMax` are the cheap, simple
functions: they always convert `value` to a `Float`, multiply, and floor or
ceil the result. Every integer below `2 ** 53` is representable, and `value` is
converted exactly, so as long as `value` and the product both stay under that
limit the `Float` product is off by less than one unit and the rounding step
absorbs the error. It also absorbs the error in the multiplier itself, which
matters in practice: the double nearest `0.0125` is
`0.012500000000000000693...`, so a _strict_ ceiling of `4_000 * 0.0125` would
be `51`, and this path returns the expected `50`. The price of that
convenience is twofold: below `2 ** 53` the result can be one unit off the
exact product — reach for `DecimalNat`/`DecimalInt` when the multiplier has to
be an exact decimal and even a single unit must not be lost — and at or above
`2 ** 53` the guarantee lapses entirely, since these two functions never check
for it.

`multiplyNatByFloatMinSafe` and `multiplyNatByFloatMaxSafe` are the drop-in
replacements that stay correct at any magnitude, at the cost of a fallback path
that is slower once it is taken. They pick their strategy from the magnitude of
the product: below `2 ** 53` they behave exactly like the plain functions
above. At or above `2 ** 53` that reasoning breaks down: integers are no longer
all representable, so a rounding error is no longer bounded by one unit, and
both the conversion of `value` and the multiplication round to nearest — in
whichever direction happens to be closer, including the unsafe one. Multiplying
`50_000_000_000_000_000_000` by `1_000.0` in `Float`, for instance, lands
4_194_304 _below_ the exact product, and a `ceil` cannot recover that because
the result is already an integer. So above the limit the product is instead
evaluated exactly: every finite `Float` is a dyadic rational, i.e. it denotes
exactly `numerator / 2 ** k` for integers `numerator` and `k`, and that pair is
recovered without losing a bit by doubling the `Float` until it becomes
integral. The functions then compute `value * numerator` on unbounded `Nat`s
and shift right by `k`, rounding the quotient down (`MinSafe`) or up
(`MaxSafe`). Those results are exact bounds on the mathematical product for
operands of any size.

`intToFloatFloor` is a standalone helper for the reverse direction — getting a
`Nat` into a `Float` without the conversion rounding it up. It right-shifts
`value` until it fits into 53 bits and left-shifts the truncated value back
before converting, so the resulting `Float` is at most `value`.

`scaleFloat` is a thin, total helper around `Float.pow(10.0, decimals)` for
converting between a token's raw integer scale and human-scale values.

The `DecimalInt` and `DecimalNat` modules represent a number as a `value` and an
integer `decimals`, denoting `value * 10 ** (-decimals)`. `DecimalInt` backs the
`value` with an unbounded `Int` (allowing negatives), while `DecimalNat` backs
it with an unbounded `Nat` (non-negative only, so `sub` traps on underflow).
Because the underlying value is unbounded, `add`, `sub` and `mul` are always
exact regardless of magnitude: `add`/`sub` first rescale both operands to the
finer of the two scales, and `mul` multiplies the values and adds the scales.
`DecimalInt.abs` returns a `DecimalNat` since a magnitude is never negative.
Division is deliberately omitted, as the quotient is not, in general,
representable exactly in base ten — convert to `Float` with `toFloat` when an
approximate quotient is needed.

`fromFloat(f, digits)` is the entry point from `Float`: it keeps exactly
`digits` significant decimal digits of `f` and returns them as an exact
decimal, so every arithmetic operation from that point on is exact — the
`Float` imprecision is paid once, at the boundary, rather than compounding
across every subsequent operation. It reproduces `f`'s own digits rather than
rounding to the nearest value or recovering the shorter decimal a human may
have written: the double nearest `0.1` is `0.1000000000000000055...`, so
`fromFloat(0.1, 3)` returns `(100, 3)` (`0.100`), the first three digits of
that double, not a special-cased `0.1`. That also means digits past the
double's own precision (roughly 15-17 significant digits) reflect
representation error rather than the value the caller intended, so `digits`
should stay within the range that is actually meaningful for a given `f`.
`digits` counts significant digits rather than decimal places, so a whole
number like `1_000_000_000.0` at `digits = 5` keeps all 5 digits and pushes
the rest into a negative `decimals` instead of losing them. `f == 0.0` (or
`-0.0`) is a special case handled the same way as `digits = 0`, since it has
no significant digits to count from either: it always returns `0`, regardless
of `digits`. `DecimalNat.fromFloat` traps on a negative `f`, and both trap on
`NaN` and infinity, neither of which denotes a decimal number at all.

Both modules convert to an integer with three explicitly directed roundings, so
the direction is a choice at the call site rather than a property of the
representation: `floor` towards negative infinity (the safe payout amount),
`ceil` towards positive infinity (the safe required amount), and `round` to the
nearest integer with ties going away from zero. In `DecimalNat` all three are
non-negative and `floor` is a plain truncation, whereas in `DecimalInt` the
direction is relative to the number line and not to zero: `floor(-1.75)` is
`-2` and `ceil(-1.75)` is `-1`. A decimal whose `decimals` is `0` or negative
already denotes an integer, so all three return it exactly, without rounding.

## Implementation notes

- All four multiplication functions trap if `multiplier` is `NaN` or infinite
  (neither denotes a rational number).
- `multiplyNatByFloatMin` and `multiplyNatByFloatMax` are a safe bound only
  while `value` and the product both stay below `2 ** 53`; above that they
  keep computing a `Float` product, which can drift from the exact product by
  more than one unit in either direction. Below the limit they can still be
  one unit off the exact product, in exchange for tolerating the
  representation error of a decimal multiplier.
- `multiplyNatByFloatMinSafe` and `multiplyNatByFloatMaxSafe` are exact bounds
  on the mathematical product once the product reaches `2 ** 53`; below that
  they behave identically to the plain functions, including the possible
  one-unit gap.
- A negative `multiplier` returns the absolute value of the rounded product,
  for all four functions.
- `scaleFloat` never traps.
- In the `DecimalInt` module every operation is total except `fromFloat`,
  which traps on `NaN` or infinite `f`. In `DecimalNat` every operation is
  total except `sub`, which traps when the result would be negative (a `Nat`
  cannot be negative), and `fromFloat`, which additionally traps on a
  negative `f`.
- `fromFloat` truncates any digits past the requested `digits`, rather than
  rounding to the nearest value, and returns `0` for `f == 0.0` (or `-0.0`)
  regardless of `digits`.

## Copyright

MR Research AG, 2026

## Authors

Main author: AndyGura
Contributors: TimoHanke

## License

Apache-2.0
