# Safe financial math for Motoko

## Overview

`safe-financial-math` provides small, dependency-light arithmetic helpers for
combining large integer token quantities (`Nat`) with floating-point prices
(`Float`) without the precision loss and rounding drift that plague naive
`Float` arithmetic.

The package is organised as a few modules:

- the root module (`mo:safe-financial-math`) — precision-safe `Nat`-by-`Float`
  multiplication (`multiplyNatByFloatMin` / `multiplyNatByFloatMax`) and decimal
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
- multiply-and-**ceil** for amounts you collect or require (never undercharge),

by evaluating the product in exact, unbounded integer arithmetic instead of in
floating point, so the bound holds for operands of any magnitude.

### Interface

Root module (`mo:safe-financial-math`):

```motoko
module {
  // Multiplies value by multiplier, flooring the result (safe payout amount).
  public func multiplyNatByFloatMin(value : Nat, multiplier : Float) : Nat;

  // Converts value to Float after truncating unrepresentable low-order bits.
  public func intToFloatFloor(value : Nat) : Float;

  // Multiplies value by multiplier, ceiling the result (safe required amount).
  public func multiplyNatByFloatMax(value : Nat, multiplier : Float) : Nat;

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

  public func add(a : DecimalInt, b : DecimalInt) : DecimalInt; // exact
  public func sub(a : DecimalInt, b : DecimalInt) : DecimalInt; // exact
  public func mul(a : DecimalInt, b : DecimalInt) : DecimalInt; // exact
  public func neg(a : DecimalInt) : DecimalInt;
  public func abs(a : DecimalInt) : DecimalNat; // magnitude as a DecimalNat

  public func compare(a : DecimalInt, b : DecimalInt) : Order.Order;
  public func equal(a : DecimalInt, b : DecimalInt) : Bool;

  public func round(d : DecimalInt) : Int; // nearest, half away from zero
  public func toFloat(d : DecimalInt) : Float; // approximate
  public func toText(d : DecimalInt) : Text;
};

```

`DecimalNat` module (`mo:safe-financial-math/DecimalNat`) — the non-negative
counterpart, backed by a `Nat`. It has the same interface minus `neg`/`abs`,
`sub` traps on underflow, and `round` returns a `Nat`:

```motoko
module {
  public type DecimalNat = { value : Nat; decimals : Int };

  public func new(value : Nat, decimals : Int) : DecimalNat;
  public func fromNat(n : Nat) : DecimalNat;

  public func add(a : DecimalNat, b : DecimalNat) : DecimalNat; // exact
  public func sub(a : DecimalNat, b : DecimalNat) : DecimalNat; // exact, traps on underflow
  public func mul(a : DecimalNat, b : DecimalNat) : DecimalNat; // exact

  public func compare(a : DecimalNat, b : DecimalNat) : Order.Order;
  public func equal(a : DecimalNat, b : DecimalNat) : Bool;

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
// Use the flooring variant for the payout so the canister never overpays.
let payout = FinancialMath.multiplyNatByFloatMin(4_000, 0.0125); // 50

// Use the ceiling variant for a required deposit so the canister never
// undercharges. The closest double to 0.0125 is 0.012500000000000000693..., so
// the exact product is 50.000000000000002775... and the ceiling is 51.
let required = FinancialMath.multiplyNatByFloatMax(4_000, 0.0125); // 51

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

`multiplyNatByFloatMin` and `multiplyNatByFloatMax` do not multiply in floating
point at all. Every finite `Float` is a dyadic rational, i.e. it denotes exactly
`numerator / 2 ** k` for some integers `numerator` and `k`, and that pair can be
recovered without losing a bit by doubling the `Float` until it becomes integral.
The functions then compute `value * numerator` and divide by `2 ** k` on
unbounded `Nat`s, rounding the quotient down (`Min`) or up (`Max`). Both results
are therefore exact bounds on the mathematical product for operands of any
magnitude, whereas a `Float` multiplication rounds its result to nearest and so
can land on the wrong side of the product as soon as the product exceeds
`2 ** 53`.

Note that the bound is on the product of `value` and the `Float`'s own value,
which is itself only the closest double to the decimal a caller writes: `0.0125`
denotes `0.012500000000000000693...`, so `multiplyNatByFloatMax(4_000, 0.0125)`
is `51`, not `50`. Reach for `DecimalNat`/`DecimalInt` when the multiplier itself
must be an exact decimal.

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

## Implementation notes

- `multiplyNatByFloatMin` and `multiplyNatByFloatMax` trap if `multiplier` is
  `NaN` or infinite (neither denotes a rational number).
- A negative `multiplier` returns the absolute value of the rounded product.
- `scaleFloat` never traps.
- In the `DecimalInt` module every operation is total. In `DecimalNat` every
  operation is total except `sub`, which traps when the result would be negative
  (a `Nat` cannot be negative).

## Copyright

MR Research AG, 2026

## Authors

Main author: AndyGura
Contributors: TimoHanke

## License

Apache-2.0
