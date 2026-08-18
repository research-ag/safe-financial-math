import { test } "mo:test";
import Float "mo:core/Float";

import FinancialMath "../src/lib";

test(
  "intToFloatFloor: truncates values above Float precision",
  func() {
    let value : Nat = 1_152_921_504_606_846_977; // 2 ** 60 + 1
    assert FinancialMath.intToFloatFloor(value) == 1_152_921_504_606_846_976.0;
  },
);

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
  },
);

test(
  "multiplyNatByFloatMin: precision-safe for values above 2 ** 53",
  func() {
    // 2 ** 60 does not fit into the 53-bit mantissa of a Float.
    let big : Nat = 1_152_921_504_606_846_976; // 2 ** 60
    // Multiplying by 1.0 must return exactly the same value, not a rounded one.
    assert FinancialMath.multiplyNatByFloatMin(big, 1.0) == big;
    // Shift the value before multiplying, so flooring does not discard a
    // larger-than-necessary amount after the multiplier has been applied.
    assert FinancialMath.multiplyNatByFloatMin(big, 0.5) == 576_460_752_303_423_488; // 2 ** 59
  },
);

test(
  "multiplyNatByFloatMax: basic ceiling",
  func() {
    assert FinancialMath.multiplyNatByFloatMax(4_000, 0.0125) == 50;
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
