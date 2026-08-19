import { test } "mo:test";
import Float "mo:core/Float";

import FinancialMath "../src/lib";

// `multiplyNatByFloatMin`/`multiplyNatByFloatMax` always round a Float product,
// which is a safe bound only while `value` and the product both stay below
// 2 ** 53. `multiplyNatByFloatMinSafe`/`multiplyNatByFloatMaxSafe` add a
// fallback to exact integer arithmetic above that limit, so they stay a safe
// bound at any magnitude. Both pairs are tested below, along with the boundary
// between the two regimes for the Safe versions and a demonstration of where
// the plain versions stop being a safe bound.
//
// Expected values were computed with exact rational arithmetic, so they check
// the implementation against the mathematical product rather than against
// itself.

let mantissaLimit : Nat = 9_007_199_254_740_992; // 2 ** 53

// ---------------------------------------------------------------------------
// intToFloatFloor
// ---------------------------------------------------------------------------

test(
  "intToFloatFloor: values within the mantissa convert exactly",
  func() {
    assert FinancialMath.intToFloatFloor(0) == 0.0;
    assert FinancialMath.intToFloatFloor(1) == 1.0;
    assert FinancialMath.intToFloatFloor(4_000) == 4_000.0;
    assert FinancialMath.intToFloatFloor(mantissaLimit - 1) == 9_007_199_254_740_991.0;
    assert FinancialMath.intToFloatFloor(mantissaLimit) == 9_007_199_254_740_992.0;
  },
);

test(
  "intToFloatFloor: truncates values above Float precision",
  func() {
    let value : Nat = 1_152_921_504_606_846_977; // 2 ** 60 + 1
    assert FinancialMath.intToFloatFloor(value) == 1_152_921_504_606_846_976.0;
    // 2 ** 53 + 1 is the smallest integer a Float cannot represent.
    assert FinancialMath.intToFloatFloor(mantissaLimit + 1) == 9_007_199_254_740_992.0;
  },
);

test(
  "intToFloatFloor: never rounds up, unlike a plain conversion",
  func() {
    let value : Nat = 1_152_921_504_606_846_975; // 2 ** 60 - 1
    // Doubles are 256 apart in this range, so the nearest one lies *above* the
    // value and a plain conversion overstates it.
    assert Float.fromInt(value) == 1_152_921_504_606_846_976.0;
    // Truncating the low-order bits first gives 2 ** 60 - 128 instead.
    assert FinancialMath.intToFloatFloor(value) == 1_152_921_504_606_846_848.0;
  },
);

// ---------------------------------------------------------------------------
// multiplyNatByFloatMin / multiplyNatByFloatMax
// ---------------------------------------------------------------------------
//
// These always round a plain Float product, which is a correct bound only
// while `value` and the product both stay below 2 ** 53. Every case in this
// section stays under that limit; the section further down shows what
// happens once it is crossed.

test(
  "multiplyNatByFloatMin: basic flooring",
  func() {
    assert FinancialMath.multiplyNatByFloatMin(4_000, 0.0125) == 50;
    assert FinancialMath.multiplyNatByFloatMin(1_000, 0.0125) == 12;
    assert FinancialMath.multiplyNatByFloatMin(100, 1.0) == 100;
    assert FinancialMath.multiplyNatByFloatMin(0, 1.5) == 0;
    assert FinancialMath.multiplyNatByFloatMin(10, 0.0) == 0;
  },
);

test(
  "multiplyNatByFloatMin: never rounds above the exact product",
  func() {
    // 3 * 0.5 = 1.5, floored to 1.
    assert FinancialMath.multiplyNatByFloatMin(3, 0.5) == 1;
    // 7 * (1 / 3) = 2.33..., floored to 2.
    assert FinancialMath.multiplyNatByFloatMin(7, 1.0 / 3.0) == 2;
    // 12_345 * 0.678 = 8_369.91, floored to 8_369.
    assert FinancialMath.multiplyNatByFloatMin(12_345, 0.678) == 8_369;
  },
);

test(
  "multiplyNatByFloatMax: basic ceiling",
  func() {
    // The closest double to 0.0125 is 0.012500000000000000693..., so the exact
    // product is 50.000000000000002775... A product this far below 2 ** 53 is
    // rounded as a Float, which absorbs the representation error of 0.0125
    // instead of charging a whole extra unit for it.
    assert FinancialMath.multiplyNatByFloatMax(4_000, 0.0125) == 50;
    // 0.015625 is 2 ** -6, so this product is exact and nothing is rounded up.
    assert FinancialMath.multiplyNatByFloatMax(4_096, 0.015_625) == 64;
    assert FinancialMath.multiplyNatByFloatMax(100, 1.0) == 100;
    assert FinancialMath.multiplyNatByFloatMax(0, 1.5) == 0;
  },
);

test(
  "multiplyNatByFloatMax: never rounds below the exact product",
  func() {
    // 3 * 0.5 = 1.5, ceiled to 2.
    assert FinancialMath.multiplyNatByFloatMax(3, 0.5) == 2;
    // 7 * (1 / 3) = 2.33..., ceiled to 3.
    assert FinancialMath.multiplyNatByFloatMax(7, 1.0 / 3.0) == 3;
    // 12_345 * 0.678 = 8_369.91, ceiled to 8_370.
    assert FinancialMath.multiplyNatByFloatMax(12_345, 0.678) == 8_370;
  },
);

test(
  "float path: an exactly representable multiplier leaves the product exact",
  func() {
    // These products are integers in binary floating point, so neither bound
    // moves them and both functions agree.
    assert FinancialMath.multiplyNatByFloatMin(4_096, 0.015_625) == 64; // 2 ** -6
    assert FinancialMath.multiplyNatByFloatMax(4_096, 0.015_625) == 64;
    assert FinancialMath.multiplyNatByFloatMin(1_000, 2.0) == 2_000;
    assert FinancialMath.multiplyNatByFloatMax(1_000, 2.0) == 2_000;
    assert FinancialMath.multiplyNatByFloatMin(mantissaLimit - 1, 1.0) == mantissaLimit - 1;
    assert FinancialMath.multiplyNatByFloatMax(mantissaLimit - 1, 1.0) == mantissaLimit - 1;
  },
);

test(
  "float path: a half-way product is floored by min and ceiled by max",
  func() {
    assert FinancialMath.multiplyNatByFloatMin(1_000, 0.015_625) == 15; // 15.625
    assert FinancialMath.multiplyNatByFloatMax(1_000, 0.015_625) == 16;
    assert FinancialMath.multiplyNatByFloatMin(12_345, 0.5) == 6_172; // 6_172.5
    assert FinancialMath.multiplyNatByFloatMax(12_345, 0.5) == 6_173;
  },
);

test(
  "float path: the Float rounding absorbs a decimal multiplier's error",
  func() {
    // Deliberate trade-off of the Float regime: a decimal multiplier is treated
    // as the decimal it was written as, not as the slightly larger double it
    // actually is, so `max` can come out one unit below the exact product.
    //
    // 4_000 * 0.0125 is exactly 50.000000000000002775..., yet the Float product
    // is 50.0 and both bounds return 50 rather than a strict 51.
    assert FinancialMath.multiplyNatByFloatMin(4_000, 0.0125) == 50;
    assert FinancialMath.multiplyNatByFloatMax(4_000, 0.0125) == 50;
    // Likewise 100 * 0.1 is exactly 10.000000000000000555..., and both bounds
    // return 10 instead of the strict ceiling of 11.
    assert FinancialMath.multiplyNatByFloatMin(100, 0.1) == 10;
    assert FinancialMath.multiplyNatByFloatMax(100, 0.1) == 10;
  },
);

test(
  "float path: a zero value or a zero multiplier gives zero",
  func() {
    assert FinancialMath.multiplyNatByFloatMin(0, 1_000.0) == 0;
    assert FinancialMath.multiplyNatByFloatMax(0, 1_000.0) == 0;
    assert FinancialMath.multiplyNatByFloatMin(10, 0.0) == 0;
    assert FinancialMath.multiplyNatByFloatMax(10, 0.0) == 0;
    assert FinancialMath.multiplyNatByFloatMin(0, 0.0) == 0;
    assert FinancialMath.multiplyNatByFloatMax(0, 0.0) == 0;
  },
);

test(
  "a negative multiplier returns the magnitude of the rounded product",
  func() {
    // floor(-1.5) == -2 and ceil(-1.5) == -1.
    assert FinancialMath.multiplyNatByFloatMin(3, -0.5) == 2;
    assert FinancialMath.multiplyNatByFloatMax(3, -0.5) == 1;
    // floor(-2.33...) == -3 and ceil(-2.33...) == -2.
    assert FinancialMath.multiplyNatByFloatMin(7, -(1.0 / 3.0)) == 3;
    assert FinancialMath.multiplyNatByFloatMax(7, -(1.0 / 3.0)) == 2;
    // An integral product is not moved in either direction.
    assert FinancialMath.multiplyNatByFloatMin(100, -1.0) == 100;
    assert FinancialMath.multiplyNatByFloatMax(100, -1.0) == 100;
    assert FinancialMath.multiplyNatByFloatMin(4_000, -0.0125) == 50;
    assert FinancialMath.multiplyNatByFloatMax(4_000, -0.0125) == 50;
  },
);

test(
  "min and max bracket the exact product",
  func() {
    let value : Nat = 12_345;
    let price = 0.678;
    let lo = FinancialMath.multiplyNatByFloatMin(value, price);
    let hi = FinancialMath.multiplyNatByFloatMax(value, price);
    assert lo <= hi;
    assert hi <= lo + 1;
  },
);

// ---------------------------------------------------------------------------
// multiplyNatByFloatMin / multiplyNatByFloatMax above 2 ** 53
// ---------------------------------------------------------------------------
//
// Neither function switches to exact arithmetic, so once a product crosses
// 2 ** 53 the Float rounding can land on either side of the exact product —
// including the unsafe side. Compare with the identically-named tests for the
// Safe versions further down, which get these exact.

test(
  "multiplyNatByFloatMax can round below the exact product once it exceeds 2 ** 53",
  func() {
    // The exact product is 27_021_597_764_222_973, but the nearest Float is
    // already the integer ...972, so ceiling it changes nothing: the result
    // comes out one unit *below* the exact product, which a ceiling must
    // never do. `multiplyNatByFloatMaxSafe` gets this right.
    assert FinancialMath.multiplyNatByFloatMax(9_007_199_254_740_991, 3.0) == 27_021_597_764_222_972;
    assert FinancialMath.multiplyNatByFloatMaxSafe(9_007_199_254_740_991, 3.0) == 27_021_597_764_222_973;
  },
);

test(
  "multiplyNatByFloatMin can round above the exact product once it exceeds 2 ** 53",
  func() {
    // The exact product is 18_000_000_000_000_003, but the nearest Float is
    // already the integer ...004, so flooring it changes nothing: the result
    // comes out one unit *above* the exact product, which a floor must never
    // do. `multiplyNatByFloatMinSafe` gets this right.
    assert FinancialMath.multiplyNatByFloatMin(6_000_000_000_000_001, 3.0) == 18_000_000_000_000_004;
    assert FinancialMath.multiplyNatByFloatMinSafe(6_000_000_000_000_001, 3.0) == 18_000_000_000_000_003;
  },
);

// ---------------------------------------------------------------------------
// The boundary at 2 ** 53, for the Safe versions
// ---------------------------------------------------------------------------

test(
  "exact arithmetic takes over as soon as the product exceeds 2 ** 53",
  func() {
    // Both values are below 2 ** 53 and both multipliers are exact, so only the
    // product leaves the range where Float can represent every integer. There
    // the Float product is rounded to a *different* integer, in the unsafe
    // direction for each function, and only exact arithmetic gets it right.

    // 9_007_199_254_740_991 * 3 rounds down to ...972 as a Float.
    assert FinancialMath.multiplyNatByFloatMaxSafe(9_007_199_254_740_991, 3.0) == 27_021_597_764_222_973;
    // 6_000_000_000_000_001 * 3 rounds up to ...004 as a Float.
    assert FinancialMath.multiplyNatByFloatMinSafe(6_000_000_000_000_001, 3.0) == 18_000_000_000_000_003;
  },
);

test(
  "the value 2 ** 53 and above is multiplied exactly",
  func() {
    // 2 ** 53 itself is still representable, but the product is no longer below
    // the limit, so it takes the exact path — with the same answer.
    assert FinancialMath.multiplyNatByFloatMinSafe(mantissaLimit, 1.0) == mantissaLimit;
    assert FinancialMath.multiplyNatByFloatMaxSafe(mantissaLimit, 1.0) == mantissaLimit;
    // 2 ** 53 + 1 cannot be represented as a Float at all, so only exact
    // arithmetic can return it unchanged.
    assert FinancialMath.multiplyNatByFloatMinSafe(mantissaLimit + 1, 1.0) == mantissaLimit + 1;
    assert FinancialMath.multiplyNatByFloatMaxSafe(mantissaLimit + 1, 1.0) == mantissaLimit + 1;
    // Halving it lands half-way between two integers: 4_503_599_627_370_496.5.
    assert FinancialMath.multiplyNatByFloatMinSafe(mantissaLimit + 1, 0.5) == 4_503_599_627_370_496;
    assert FinancialMath.multiplyNatByFloatMaxSafe(mantissaLimit + 1, 0.5) == 4_503_599_627_370_497;
  },
);

test(
  "exact path: a bound can be an integer no Float can represent",
  func() {
    // (2 ** 53 - 1) * (1 + 2 ** -52) is 9_007_199_254_740_992.99999..., so the
    // ceiling is 2 ** 53 + 1 — a value that has no Float representation and
    // therefore could never be produced by rounding a Float product.
    assert FinancialMath.multiplyNatByFloatMinSafe(mantissaLimit - 1, 1.000_000_000_000_000_2) == mantissaLimit;
    assert FinancialMath.multiplyNatByFloatMaxSafe(mantissaLimit - 1, 1.000_000_000_000_000_2) == mantissaLimit + 1;
  },
);

// ---------------------------------------------------------------------------
// Exact path: products at or above 2 ** 53
// ---------------------------------------------------------------------------

test(
  "multiplyNatByFloatMinSafe: precision-safe for values above 2 ** 53",
  func() {
    // 2 ** 60 does not fit into the 53-bit mantissa of a Float.
    let big : Nat = 1_152_921_504_606_846_976; // 2 ** 60
    // Multiplying by 1.0 must return exactly the same value, not a rounded one.
    assert FinancialMath.multiplyNatByFloatMinSafe(big, 1.0) == big;
    // Shift the value before multiplying, so flooring does not discard a
    // larger-than-necessary amount after the multiplier has been applied.
    assert FinancialMath.multiplyNatByFloatMinSafe(big, 0.5) == 576_460_752_303_423_488; // 2 ** 59
  },
);

test(
  "multiplyNatByFloatMaxSafe: never rounds below the exact product for big numbers",
  func() {
    let n : Nat = 50_000_000_000_000_000_000;
    let f : Float = 1_000.0;

    let res = FinancialMath.multiplyNatByFloatMaxSafe(n, f);
    assert res >= n * 1000;
    // The Float product lands 4_194_304 below the exact one, and a ceiling
    // cannot recover that because the rounded product is already an integer.
    assert res == n * 1000;
  },
);

test(
  "multiplyNatByFloatMinSafe: never rounds above the exact product for big numbers",
  func() {
    // Both operands are representable exactly, but their product is not: the
    // nearest double to 1.9e22 lies 2_097_152 *above* it, so a float
    // multiplication would round the payout up.
    let n : Nat = 19_000_000_000_000_000_000;
    let f : Float = 1_000.0;

    let res = FinancialMath.multiplyNatByFloatMinSafe(n, f);
    assert res <= n * 1000;
    assert res == n * 1000;
  },
);

test(
  "exactly representable products are neither floored nor ceiled",
  func() {
    // 2 ** 74 * 1_000 is far above the 53-bit mantissa limit, yet both bounds
    // have to return it unchanged, since the exact product is an integer.
    let n : Nat = 18_889_465_931_478_580_854_784; // 2 ** 74
    let exact = n * 1000;

    assert FinancialMath.multiplyNatByFloatMinSafe(n, 1_000.0) == exact;
    assert FinancialMath.multiplyNatByFloatMaxSafe(n, 1_000.0) == exact;
    // The double for 0.0125 is 3_602_879_701_896_397 / 2 ** 58, which divides
    // 2 ** 60 exactly, so this product is integral too.
    let big : Nat = 1_152_921_504_606_846_976; // 2 ** 60
    assert FinancialMath.multiplyNatByFloatMinSafe(big, 0.0125) == 14_411_518_807_585_588;
    assert FinancialMath.multiplyNatByFloatMaxSafe(big, 0.0125) == 14_411_518_807_585_588;
  },
);

test(
  "exact path: values far above 2 ** 53 are still bounded to one unit",
  func() {
    let n : Nat = 1_000_000_000_000_000_000_000_000_000_000; // 10 ** 30
    // 10 ** 30 * 0.012500000000000000693... is
    // 12_500_000_000_000_000_693_889_390_390.7..., which neither operand nor
    // product could come anywhere near expressing as a Float.
    assert FinancialMath.multiplyNatByFloatMinSafe(n, 0.0125) == 12_500_000_000_000_000_693_889_390_390;
    assert FinancialMath.multiplyNatByFloatMaxSafe(n, 0.0125) == 12_500_000_000_000_000_693_889_390_391;
  },
);

test(
  "exact path: a tiny multiplier keeps the low-order bits of a big value",
  func() {
    let big : Nat = 1_152_921_504_606_846_977; // 2 ** 60 + 1
    // The value alone is above the limit, so the product is evaluated exactly
    // even though it is small — the trailing 1 would otherwise be lost when
    // converting the value to a Float.
    assert FinancialMath.multiplyNatByFloatMinSafe(big, 1.0) == big;
    assert FinancialMath.multiplyNatByFloatMaxSafe(big, 1.0) == big;
    // 1e-10 is 7_378_697_629_483_821 / 2 ** 86, so the exact product is
    // 115_292_150.46...
    assert FinancialMath.multiplyNatByFloatMinSafe(big, 1.0e-10) == 115_292_150;
    assert FinancialMath.multiplyNatByFloatMaxSafe(big, 1.0e-10) == 115_292_151;
  },
);

test(
  "exact path: a zero multiplier gives zero for any value",
  func() {
    let n : Nat = 1_000_000_000_000_000_000_000_000_000_000; // 10 ** 30
    assert FinancialMath.multiplyNatByFloatMinSafe(n, 0.0) == 0;
    assert FinancialMath.multiplyNatByFloatMaxSafe(n, 0.0) == 0;
  },
);

test(
  "exact path: a negative multiplier returns the magnitude of the product",
  func() {
    // The exact product is 33_900_000_000_000_002_353.6..., so its floor is
    // ...353 and its ceiling ...354. Negating swaps them: `min` floors -x,
    // which rounds the magnitude up, and `max` ceils it, rounding down.
    let n : Nat = 50_000_000_000_000_000_000;
    assert FinancialMath.multiplyNatByFloatMinSafe(n, 0.678) == 33_900_000_000_000_002_353;
    assert FinancialMath.multiplyNatByFloatMaxSafe(n, 0.678) == 33_900_000_000_000_002_354;
    assert FinancialMath.multiplyNatByFloatMinSafe(n, -0.678) == 33_900_000_000_000_002_354;
    assert FinancialMath.multiplyNatByFloatMaxSafe(n, -0.678) == 33_900_000_000_000_002_353;
    // An integral product is not moved in either direction.
    let big : Nat = 1_152_921_504_606_846_976; // 2 ** 60
    assert FinancialMath.multiplyNatByFloatMinSafe(big, -0.5) == 576_460_752_303_423_488;
    assert FinancialMath.multiplyNatByFloatMaxSafe(big, -0.5) == 576_460_752_303_423_488;
  },
);

test(
  "min and max bracket the exact product for big numbers",
  func() {
    let n : Nat = 50_000_000_000_000_000_000;
    let price = 0.678;
    let lo = FinancialMath.multiplyNatByFloatMinSafe(n, price);
    let hi = FinancialMath.multiplyNatByFloatMaxSafe(n, price);
    assert lo <= hi;
    assert hi <= lo + 1;
  },
);

// ---------------------------------------------------------------------------
// Properties that hold in both regimes
// ---------------------------------------------------------------------------

// Values and prices spanning both regimes: below the limit, straddling it, and
// far above it, with exact, decimal and tiny multipliers.
let bothRegimes : [(Nat, Float)] = [
  (0, 0.0),
  (10, 0.0),
  (3, 0.5),
  (7, 1.0 / 3.0),
  (4_000, 0.0125),
  (12_345, 0.678),
  (9_007_199_254_740_991, 1.0),
  (9_007_199_254_740_991, 3.0),
  (9_007_199_254_740_992, 1.5),
  (9_007_199_254_740_993, 0.5),
  (1_152_921_504_606_846_976, 0.0125),
  (1_152_921_504_606_846_977, 1.0e-10),
  (50_000_000_000_000_000_000, 0.678),
  (50_000_000_000_000_000_000, 1_000.0),
  (1_000_000_000_000_000_000_000_000_000_000, 0.1),
];

// `multiplyNatByFloatMin`/`multiplyNatByFloatMax` floor and ceil the *same*
// Float value, so `min <= max <= min + 1` and the negation symmetry below hold
// regardless of magnitude — they are not specific to the safe regime, even
// though the bracketed value can drift from the exact product once it is
// crossed. The Safe versions get both properties too, and additionally keep
// the bracketed value pinned to the exact product at every magnitude.

test(
  "multiplyNatByFloatMin never exceeds multiplyNatByFloatMax, and never by more than one unit",
  func() {
    for ((value, price) in bothRegimes.vals()) {
      let lo = FinancialMath.multiplyNatByFloatMin(value, price);
      let hi = FinancialMath.multiplyNatByFloatMax(value, price);
      assert lo <= hi;
      assert hi <= lo + 1;
    };
  },
);

test(
  "negating the multiplier swaps multiplyNatByFloatMin and multiplyNatByFloatMax",
  func() {
    for ((value, price) in bothRegimes.vals()) {
      let lo = FinancialMath.multiplyNatByFloatMin(value, price);
      let hi = FinancialMath.multiplyNatByFloatMax(value, price);
      // The magnitude of the product is unchanged, but flooring and ceiling
      // trade places, so the bounds come back in the opposite order.
      assert FinancialMath.multiplyNatByFloatMin(value, -price) == hi;
      assert FinancialMath.multiplyNatByFloatMax(value, -price) == lo;
    };
  },
);

test(
  "multiplyNatByFloatMinSafe never exceeds multiplyNatByFloatMaxSafe, and never by more than one unit",
  func() {
    for ((value, price) in bothRegimes.vals()) {
      let lo = FinancialMath.multiplyNatByFloatMinSafe(value, price);
      let hi = FinancialMath.multiplyNatByFloatMaxSafe(value, price);
      assert lo <= hi;
      assert hi <= lo + 1;
    };
  },
);

test(
  "negating the multiplier swaps multiplyNatByFloatMinSafe and multiplyNatByFloatMaxSafe",
  func() {
    for ((value, price) in bothRegimes.vals()) {
      let lo = FinancialMath.multiplyNatByFloatMinSafe(value, price);
      let hi = FinancialMath.multiplyNatByFloatMaxSafe(value, price);
      assert FinancialMath.multiplyNatByFloatMinSafe(value, -price) == hi;
      assert FinancialMath.multiplyNatByFloatMaxSafe(value, -price) == lo;
    };
  },
);

// ---------------------------------------------------------------------------
// scaleFloat
// ---------------------------------------------------------------------------

test(
  "scaleFloat: zero decimals is identity",
  func() {
    assert FinancialMath.scaleFloat(42.5, 0) == 42.5;
  },
);

test(
  "scaleFloat: positive decimals scale up",
  func() {
    assert FinancialMath.scaleFloat(1.5, 2) == 150.0;
  },
);

test(
  "scaleFloat: negative decimals scale down",
  func() {
    assert FinancialMath.scaleFloat(150.0, -2) == 1.5;
  },
);

test(
  "scaleFloat: round trip",
  func() {
    let value = 3.14159;
    let scaled = FinancialMath.scaleFloat(value, 8);
    let restored = FinancialMath.scaleFloat(scaled, -8);
    assert Float.abs(restored - value) < 0.000_000_001;
  },
);
