import Bench "mo:bench-helper";
import Nat "mo:core/Nat";

import DecimalInt "../src/DecimalInt";

module {
  public func init() : Bench.V1 {
    let schema : Bench.Schema = {
      name = "DecimalInt arithmetic";
      description = "Exact, integer-backed base-ten arithmetic on DecimalInt values.";
      rows = ["add", "sub", "mul", "compare", "round", "toFloat", "toText"];
      cols = ["-"];
    };

    // Two operands with different scales and magnitudes well beyond 2 ** 53,
    // so the arbitrary-precision paths (rescaling, big-Int multiplication) are
    // exercised rather than trivially small values.
    let a = DecimalInt.new(123_456_789_012_345_678_901_234_567, 8); // large, 8 decimals
    let b = DecimalInt.new(987_654_321_098_765, 3); // large, 3 decimals

    let run : Bench.Runner = func(ri, ci) {
      let iterations = 1_000;
      switch (ri) {
        case (0) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.add(a, b);
          };
        };
        case (1) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.sub(a, b);
          };
        };
        case (2) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.mul(a, b);
          };
        };
        case (3) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.compare(a, b);
          };
        };
        case (4) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.round(a);
          };
        };
        case (5) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.toFloat(a);
          };
        };
        case (_) {
          for (_ in Nat.range(0, iterations)) {
            ignore DecimalInt.toText(a);
          };
        };
      };
    };

    Bench.V1(schema, run);
  };
};
