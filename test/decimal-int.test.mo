import { test } "mo:test";

import DecimalInt "../src/DecimalInt";

test(
  "new and fromInt build the expected representation",
  func() {
    let a = DecimalInt.new(123, 2);
    assert a.value == 123 and a.decimals == 2;
    let b = DecimalInt.fromInt(42);
    assert b.value == 42 and b.decimals == 0;
  },
);

test(
  "fromFloat builds the expected representation",
  func() {
    let a = DecimalInt.fromFloat(1.23, 3);
    assert a.value == 123 and a.decimals == 2;

    let b = DecimalInt.fromFloat(-10234.5678, 9);
    assert b.value == -102345678 and b.decimals == 4;

    let c = DecimalInt.fromFloat(1_000_000_000.0, 5);
    assert c.value == 10_000 and c.decimals == -5;

    let d = DecimalInt.fromFloat(0.0, 5);
    assert d.value == 0 and d.decimals == 0;
  },
);

test(
  "add rescales to the finer scale and stays exact",
  func() {
    // 1.23 + 1 = 2.23
    let sum = DecimalInt.add(DecimalInt.new(123, 2), DecimalInt.new(1, 0));
    assert DecimalInt.equal(sum, DecimalInt.new(223, 2));
    // 12300 + 0.001 = 12300.001
    let mixed = DecimalInt.add(DecimalInt.new(123, -2), DecimalInt.new(1, 3));
    assert DecimalInt.equal(mixed, DecimalInt.new(12_300_001, 3));
  },
);

test(
  "sub rescales to the finer scale and stays exact",
  func() {
    // 1.23 - 1 = 0.23
    let diff = DecimalInt.sub(DecimalInt.new(123, 2), DecimalInt.new(1, 0));
    assert DecimalInt.equal(diff, DecimalInt.new(23, 2));
    // 1 - 1.23 = -0.23
    let neg = DecimalInt.sub(DecimalInt.new(1, 0), DecimalInt.new(123, 2));
    assert DecimalInt.equal(neg, DecimalInt.new(-23, 2));
  },
);

test(
  "mul adds the scales and is exact for huge values",
  func() {
    // 1.23 * 0.5 = 0.615
    let product = DecimalInt.mul(DecimalInt.new(123, 2), DecimalInt.new(5, 1));
    assert DecimalInt.equal(product, DecimalInt.new(615, 3));
    // A product far beyond 2 ** 53 stays exact.
    let big = DecimalInt.new(9_007_199_254_740_993, 0); // 2 ** 53 + 1
    let squared = DecimalInt.mul(big, big);
    assert squared.value == 9_007_199_254_740_993 * 9_007_199_254_740_993;
    assert squared.decimals == 0;
  },
);

test(
  "neg and abs preserve the scale",
  func() {
    assert DecimalInt.equal(DecimalInt.neg(DecimalInt.new(123, 2)), DecimalInt.new(-123, 2));
    assert DecimalInt.equal(DecimalInt.abs(DecimalInt.new(-123, 2)), DecimalInt.new(123, 2));
  },
);

test(
  "compare and equal use value, not representation",
  func() {
    assert DecimalInt.equal(DecimalInt.new(100, 2), DecimalInt.new(1, 0));
    assert DecimalInt.compare(DecimalInt.new(100, 2), DecimalInt.new(1, 0)) == #equal;
    assert DecimalInt.compare(DecimalInt.new(123, 2), DecimalInt.new(2, 0)) == #less;
    assert DecimalInt.compare(DecimalInt.new(3, 0), DecimalInt.new(123, 2)) == #greater;
  },
);

test(
  "floor rounds towards negative infinity",
  func() {
    assert DecimalInt.floor(DecimalInt.new(125, 2)) == 1; // 1.25 -> 1
    assert DecimalInt.floor(DecimalInt.new(175, 2)) == 1; // 1.75 -> 1
    assert DecimalInt.floor(DecimalInt.new(199, 2)) == 1; // 1.99 -> 1
    assert DecimalInt.floor(DecimalInt.new(200, 2)) == 2; // 2.00 -> 2, exact
    assert DecimalInt.floor(DecimalInt.new(1, 2)) == 0; // 0.01 -> 0
    assert DecimalInt.floor(DecimalInt.new(0, 2)) == 0; // 0.00 -> 0
    // Negative values round away from zero, not towards it.
    assert DecimalInt.floor(DecimalInt.new(-125, 2)) == -2; // -1.25 -> -2
    assert DecimalInt.floor(DecimalInt.new(-175, 2)) == -2; // -1.75 -> -2
    assert DecimalInt.floor(DecimalInt.new(-1, 2)) == -1; // -0.01 -> -1
    assert DecimalInt.floor(DecimalInt.new(-100, 2)) == -1; // -1.00 -> -1, exact
    assert DecimalInt.floor(DecimalInt.new(-200, 2)) == -2; // -2.00 -> -2, exact
    // decimals <= 0 already denotes an integer: no rounding, just trailing zeros.
    assert DecimalInt.floor(DecimalInt.new(123, 0)) == 123;
    assert DecimalInt.floor(DecimalInt.new(123, -2)) == 12_300;
    assert DecimalInt.floor(DecimalInt.new(-123, -2)) == -12_300;
    // Beyond 2 ** 53 the result is still exact.
    assert DecimalInt.floor(DecimalInt.new(900_719_925_474_099_399, 2)) == 9_007_199_254_740_993;
    assert DecimalInt.floor(DecimalInt.new(-900_719_925_474_099_301, 2)) == -9_007_199_254_740_994;
  },
);

test(
  "ceil rounds towards positive infinity",
  func() {
    assert DecimalInt.ceil(DecimalInt.new(125, 2)) == 2; // 1.25 -> 2
    assert DecimalInt.ceil(DecimalInt.new(175, 2)) == 2; // 1.75 -> 2
    assert DecimalInt.ceil(DecimalInt.new(101, 2)) == 2; // 1.01 -> 2
    assert DecimalInt.ceil(DecimalInt.new(200, 2)) == 2; // 2.00 -> 2, exact
    assert DecimalInt.ceil(DecimalInt.new(1, 2)) == 1; // 0.01 -> 1
    assert DecimalInt.ceil(DecimalInt.new(0, 2)) == 0; // 0.00 -> 0
    // Negative values round towards zero.
    assert DecimalInt.ceil(DecimalInt.new(-125, 2)) == -1; // -1.25 -> -1
    assert DecimalInt.ceil(DecimalInt.new(-175, 2)) == -1; // -1.75 -> -1
    assert DecimalInt.ceil(DecimalInt.new(-1, 2)) == 0; // -0.01 -> 0
    assert DecimalInt.ceil(DecimalInt.new(-100, 2)) == -1; // -1.00 -> -1, exact
    assert DecimalInt.ceil(DecimalInt.new(-200, 2)) == -2; // -2.00 -> -2, exact
    // decimals <= 0 already denotes an integer: no rounding, just trailing zeros.
    assert DecimalInt.ceil(DecimalInt.new(123, 0)) == 123;
    assert DecimalInt.ceil(DecimalInt.new(123, -2)) == 12_300;
    assert DecimalInt.ceil(DecimalInt.new(-123, -2)) == -12_300;
    // Beyond 2 ** 53 the result is still exact.
    assert DecimalInt.ceil(DecimalInt.new(900_719_925_474_099_301, 2)) == 9_007_199_254_740_994;
    assert DecimalInt.ceil(DecimalInt.new(-900_719_925_474_099_399, 2)) == -9_007_199_254_740_993;
  },
);

test(
  "floor and ceil bracket round and each other",
  func() {
    // floor(x) <= round(x) <= ceil(x), and the two differ by exactly one unit
    // unless x is already an integer.
    let samples = [
      DecimalInt.new(0, 3),
      DecimalInt.new(1, 3),
      DecimalInt.new(1_500, 3),
      DecimalInt.new(-1, 3),
      DecimalInt.new(-1_500, 3),
      DecimalInt.new(2_000, 3),
      DecimalInt.new(-2_000, 3),
      DecimalInt.new(7, 0),
      DecimalInt.new(-7, 0),
      DecimalInt.new(7, -3),
      DecimalInt.new(-7, -3),
    ];
    for (d in samples.vals()) {
      let lo = DecimalInt.floor(d);
      let hi = DecimalInt.ceil(d);
      assert lo <= DecimalInt.round(d) and DecimalInt.round(d) <= hi;
      // The bracket is tight, and exact values collapse onto one integer.
      let isExact = DecimalInt.equal(DecimalInt.fromInt(lo), d);
      assert (if (isExact) hi == lo else hi == lo + 1);
      // ceil is the mirror image of floor: ceil(x) == -floor(-x).
      assert hi == -DecimalInt.floor(DecimalInt.neg(d));
    };
  },
);

test(
  "round applies half-away-from-zero rounding",
  func() {
    assert DecimalInt.round(DecimalInt.new(125, 2)) == 1; // 1.25 -> 1
    assert DecimalInt.round(DecimalInt.new(150, 2)) == 2; // 1.50 -> 2
    assert DecimalInt.round(DecimalInt.new(149, 2)) == 1; // 1.49 -> 1
    assert DecimalInt.round(DecimalInt.new(-150, 2)) == -2; // -1.50 -> -2
    assert DecimalInt.round(DecimalInt.new(123, -2)) == 12_300; // integer, no rounding
  },
);

test(
  "toFloat approximates the real value",
  func() {
    assert DecimalInt.toFloat(DecimalInt.new(123, 2)) == 1.23;
    assert DecimalInt.toFloat(DecimalInt.new(123, -2)) == 12_300.0;
    assert DecimalInt.toFloat(DecimalInt.new(5, 3)) == 0.005;
  },
);

test(
  "toText renders decimals in both directions",
  func() {
    assert DecimalInt.toText(DecimalInt.new(123, 2)) == "1.23";
    assert DecimalInt.toText(DecimalInt.new(123, -2)) == "12300";
    assert DecimalInt.toText(DecimalInt.new(123, 0)) == "123";
    assert DecimalInt.toText(DecimalInt.new(5, 3)) == "0.005";
    assert DecimalInt.toText(DecimalInt.new(1200, 2)) == "12.00";
    assert DecimalInt.toText(DecimalInt.new(-123, 2)) == "-1.23";
    assert DecimalInt.toText(DecimalInt.new(-5, 3)) == "-0.005";
  },
);
