module {
  let POW_10_LUT = [
    1,
    10,
    100,
    1_000,
    10_000,
    100_000,
    1_000_000,
    10_000_000,
    100_000_000,
    1_000_000_000,
    10_000_000_000,
    100_000_000_000,
    1_000_000_000_000,
    10_000_000_000_000,
    100_000_000_000_000,
    1_000_000_000_000_000,
    10_000_000_000_000_000,
    100_000_000_000_000_000,
    1_000_000_000_000_000_000,
  ];

  /// Returns `10 ** exponent` as a `Nat`.
  ///
  /// Computed by repeated multiplication so the result is exact for any
  /// exponent (subject only to available memory), unlike a `Float`-based
  /// power. Used internally to rescale and split decimal values.
  public func pow10(exponent : Nat) : Nat {
    if (exponent < 19) {
      return POW_10_LUT[exponent];
    };
    var result : Nat = POW_10_LUT[18];
    var i = 18;
    while (i < exponent) {
      result *= 10;
      i += 1;
    };
    result;
  };
};
