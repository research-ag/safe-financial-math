import { test } "mo:test";

import DecimalNat "../src/DecimalNat";

test(
  "new and fromNat build the expected representation",
  func() {
    let a = DecimalNat.new(123, 2);
    assert a.value == 123 and a.decimals == 2;
    let b = DecimalNat.fromNat(42);
    assert b.value == 42 and b.decimals == 0;
  },
);

test(
  "fromFloat builds the expected representation",
  func() {
    let a = DecimalNat.fromFloat(1.23, 3);
    assert a.value == 123 and a.decimals == 2;

    let b = DecimalNat.fromFloat(10234.5678, 9);
    assert b.value == 102345678 and b.decimals == 4;

    let c = DecimalNat.fromFloat(1_000_000_000.0, 5);
    assert c.value == 10_000 and c.decimals == -5;

    let d = DecimalNat.fromFloat(0.0, 5);
    assert d.value == 0 and d.decimals == 0;
  },
);

test(
  "add rescales to the finer scale and stays exact",
  func() {
    // 1.23 + 1 = 2.23
    let sum = DecimalNat.add(DecimalNat.new(123, 2), DecimalNat.new(1, 0));
    assert DecimalNat.equal(sum, DecimalNat.new(223, 2));
    // 12300 + 0.001 = 12300.001
    let mixed = DecimalNat.add(DecimalNat.new(123, -2), DecimalNat.new(1, 3));
    assert DecimalNat.equal(mixed, DecimalNat.new(12_300_001, 3));
  },
);

test(
  "sub rescales to the finer scale and stays exact",
  func() {
    // 1.23 - 1 = 0.23
    let diff = DecimalNat.sub(DecimalNat.new(123, 2), DecimalNat.new(1, 0));
    assert DecimalNat.equal(diff, DecimalNat.new(23, 2));
  },
);

test(
  "mul adds the scales and is exact for huge values",
  func() {
    // 1.23 * 0.5 = 0.615
    let product = DecimalNat.mul(DecimalNat.new(123, 2), DecimalNat.new(5, 1));
    assert DecimalNat.equal(product, DecimalNat.new(615, 3));
    // A product far beyond 2 ** 53 stays exact.
    let big = DecimalNat.new(9_007_199_254_740_993, 0); // 2 ** 53 + 1
    let squared = DecimalNat.mul(big, big);
    assert squared.value == 9_007_199_254_740_993 * 9_007_199_254_740_993;
    assert squared.decimals == 0;
  },
);

test(
  "compare and equal use value, not representation",
  func() {
    assert DecimalNat.equal(DecimalNat.new(100, 2), DecimalNat.new(1, 0));
    assert DecimalNat.compare(DecimalNat.new(100, 2), DecimalNat.new(1, 0)) == #equal;
    assert DecimalNat.compare(DecimalNat.new(123, 2), DecimalNat.new(2, 0)) == #less;
    assert DecimalNat.compare(DecimalNat.new(3, 0), DecimalNat.new(123, 2)) == #greater;
  },
);

test(
  "floor truncates the fractional part",
  func() {
    assert DecimalNat.floor(DecimalNat.new(125, 2)) == 1; // 1.25 -> 1
    assert DecimalNat.floor(DecimalNat.new(175, 2)) == 1; // 1.75 -> 1
    assert DecimalNat.floor(DecimalNat.new(199, 2)) == 1; // 1.99 -> 1
    assert DecimalNat.floor(DecimalNat.new(200, 2)) == 2; // 2.00 -> 2, exact
    assert DecimalNat.floor(DecimalNat.new(1, 2)) == 0; // 0.01 -> 0
    assert DecimalNat.floor(DecimalNat.new(0, 2)) == 0; // 0.00 -> 0
    // decimals <= 0 already denotes an integer: no rounding, just trailing zeros.
    assert DecimalNat.floor(DecimalNat.new(123, 0)) == 123;
    assert DecimalNat.floor(DecimalNat.new(123, -2)) == 12_300;
    // Beyond 2 ** 53 the result is still exact.
    assert DecimalNat.floor(DecimalNat.new(900_719_925_474_099_399, 2)) == 9_007_199_254_740_993;
  },
);

test(
  "ceil rounds any fractional part up",
  func() {
    assert DecimalNat.ceil(DecimalNat.new(125, 2)) == 2; // 1.25 -> 2
    assert DecimalNat.ceil(DecimalNat.new(175, 2)) == 2; // 1.75 -> 2
    assert DecimalNat.ceil(DecimalNat.new(101, 2)) == 2; // 1.01 -> 2
    assert DecimalNat.ceil(DecimalNat.new(200, 2)) == 2; // 2.00 -> 2, exact
    assert DecimalNat.ceil(DecimalNat.new(1, 2)) == 1; // 0.01 -> 1
    assert DecimalNat.ceil(DecimalNat.new(0, 2)) == 0; // 0.00 -> 0
    // decimals <= 0 already denotes an integer: no rounding, just trailing zeros.
    assert DecimalNat.ceil(DecimalNat.new(123, 0)) == 123;
    assert DecimalNat.ceil(DecimalNat.new(123, -2)) == 12_300;
    // Beyond 2 ** 53 the result is still exact.
    assert DecimalNat.ceil(DecimalNat.new(900_719_925_474_099_301, 2)) == 9_007_199_254_740_994;
  },
);

test(
  "floor and ceil bracket round and each other",
  func() {
    // floor(x) <= round(x) <= ceil(x), and the two differ by exactly one unit
    // unless x is already an integer.
    let samples = [
      DecimalNat.new(0, 3),
      DecimalNat.new(1, 3),
      DecimalNat.new(1_500, 3),
      DecimalNat.new(2_000, 3),
      DecimalNat.new(7, 0),
      DecimalNat.new(7, -3),
    ];
    for (d in samples.vals()) {
      let lo = DecimalNat.floor(d);
      let hi = DecimalNat.ceil(d);
      assert lo <= DecimalNat.round(d) and DecimalNat.round(d) <= hi;
      // The bracket is tight, and exact values collapse onto one integer.
      let isExact = DecimalNat.equal(DecimalNat.fromNat(lo), d);
      assert (if (isExact) hi == lo else hi == lo + 1);
    };
  },
);

test(
  "round applies half-away-from-zero rounding",
  func() {
    assert DecimalNat.round(DecimalNat.new(125, 2)) == 1; // 1.25 -> 1
    assert DecimalNat.round(DecimalNat.new(150, 2)) == 2; // 1.50 -> 2
    assert DecimalNat.round(DecimalNat.new(149, 2)) == 1; // 1.49 -> 1
    assert DecimalNat.round(DecimalNat.new(123, -2)) == 12_300; // integer, no rounding
  },
);

test(
  "toFloat approximates the real value",
  func() {
    assert DecimalNat.toFloat(DecimalNat.new(123, 2)) == 1.23;
    assert DecimalNat.toFloat(DecimalNat.new(123, -2)) == 12_300.0;
    assert DecimalNat.toFloat(DecimalNat.new(5, 3)) == 0.005;
  },
);

test(
  "toText renders decimals in both directions",
  func() {
    assert DecimalNat.toText(DecimalNat.new(123, 2)) == "1.23";
    assert DecimalNat.toText(DecimalNat.new(123, -2)) == "12300";
    assert DecimalNat.toText(DecimalNat.new(123, 0)) == "123";
    assert DecimalNat.toText(DecimalNat.new(5, 3)) == "0.005";
    assert DecimalNat.toText(DecimalNat.new(1200, 2)) == "12.00";
  },
);
