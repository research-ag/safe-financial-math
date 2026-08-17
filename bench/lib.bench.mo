import Bench "mo:bench-helper";
import Nat "mo:core/Nat";

import FinancialMath "../src/lib";

module {
  public func init() : Bench.V1 {
    let schema : Bench.Schema = {
      name = "Safe financial math";
      description = "Precision-safe Nat-by-Float multiplication and decimal scaling.";
      rows = ["multiplyNatByFloatMin", "multiplyNatByFloatMax", "scaleFloat"];
      cols = ["1000"];
    };

    // A value larger than 2 ** 53 to exercise the mantissa-safe shift path.
    let big : Nat = 1_152_921_504_606_846_976; // 2 ** 60
    let price = 0.0125;

    let run : Bench.Runner = func(ri, ci) {
      let iterations = 1_000;
      switch (ri) {
        case (0) {
          for (_ in Nat.range(0, iterations)) {
            ignore FinancialMath.multiplyNatByFloatMin(big, price);
          };
        };
        case (1) {
          for (_ in Nat.range(0, iterations)) {
            ignore FinancialMath.multiplyNatByFloatMax(big, price);
          };
        };
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
