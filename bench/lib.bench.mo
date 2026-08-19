import Bench "mo:bench-helper";
import Nat "mo:core/Nat";

import FinancialMath "../src/lib";

module {
  public func init() : Bench.V1 {
    let schema : Bench.Schema = {
      name = "Safe financial math";
      description = "Precision-safe Nat-by-Float multiplication and decimal scaling, 1_000 calls per cell.";
      rows = ["multiplyNatByFloatMin", "multiplyNatByFloatMax", "scaleFloat"];
      // The multiplication helpers round the Float product while the value and
      // the product both stay below 2 ** 53, and evaluate it exactly on
      // unbounded Nats above that. "small" measures the first regime, "big" and
      // "huge" the second one at two operand sizes, and the sign of the price
      // selects which way the magnitude is rounded.
      cols = ["small +", "small -", "big +", "big -", "huge +", "huge -"];
    };

    // (value, price) per column. The price is a decimal that no Float
    // represents exactly, so the exact path has to recover the full 58-bit
    // fraction it denotes rather than a short one.
    let inputs : [(Nat, Float)] = [
      (4_000, 0.0125),
      (4_000, -0.0125),
      (1_152_921_504_606_846_976, 0.0125), // 2 ** 60
      (1_152_921_504_606_846_976, -0.0125),
      (1_000_000_000_000_000_000_000_000_000_000, 0.0125), // 10 ** 30
      (1_000_000_000_000_000_000_000_000_000_000, -0.0125),
    ];

    let run : Bench.Runner = func(ri, ci) {
      let iterations = 1_000;
      let (value, price) = inputs[ci];
      switch (ri) {
        case (0) {
          for (_ in Nat.range(0, iterations)) {
            ignore FinancialMath.multiplyNatByFloatMin(value, price);
          };
        };
        case (1) {
          for (_ in Nat.range(0, iterations)) {
            ignore FinancialMath.multiplyNatByFloatMax(value, price);
          };
        };
        // scaleFloat takes no Nat, so it only varies with the price and is
        // expected to cost the same across all columns.
        case (_) {
          for (_ in Nat.range(0, iterations)) {
            ignore FinancialMath.scaleFloat(price, 8);
          };
        };
      };
    };

    Bench.V1(schema, run);
  };
};
