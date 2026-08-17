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
