/// Safe fixed-point financial math for Motoko.
///
/// This module provides arithmetic helpers for combining large integer token
/// quantities (`Nat`) with floating-point prices (`Float`) while mitigating the
/// precision loss and rounding drift inherent to IEEE 754 doubles.
///
/// A `Float` in Motoko is a 64-bit IEEE 754 double with a 53-bit mantissa. Any
/// integer larger than `2 ** 53` cannot be represented exactly, so a naive
/// `Float.fromInt(value) * price` rounds to nearest twice — once when
/// converting the token amount, and once when multiplying — and either rounding
/// can go in the unsafe direction, by an amount far larger than one token. In a
/// financial setting this is dangerous: rounding a payout up means a canister
/// can pay out more than it took in.
///
/// The helpers here bound the rounding direction explicitly so callers can pick
/// the safe side (floor for what you pay out, ceil for what you collect). While
/// the product stays below `2 ** 53` they round the `Float` result, which is
/// then less than one unit away from the exact product; above `2 ** 53` they
/// switch to exact integer arithmetic, where no rounding can creep in at all.
///
/// ```motoko name=import
/// import FinancialMath "mo:safe-financial-math";
/// ```
///
/// Copyright: 2026 MR Research AG
/// Main author: AndyGura
/// Contributors: TimoHanke

import Prim "mo:prim";
import Float "mo:core/Float";
import Int "mo:core/Int";

module {

  /// `2 ** 53`: up to this magnitude every integer is representable as a
  /// `Float`, so a `Float` product that stays below it — and was formed from an
  /// exactly converted `value` — is less than one unit away from the exact
  /// product, which makes flooring or ceiling it meaningful. Above it, `Float`
  /// arithmetic has to be abandoned for exact integer arithmetic.
  let mantissaLimit : Nat = 9_007_199_254_740_992;
  let mantissaLimitAsFloat : Float = 9_007_199_254_740_992.0;

  /// Splits the magnitude of a finite `Float` into an exact
  /// `(numerator, exponent)` pair, so that
  /// `Float.abs(value) == numerator / 2 ** exponent` holds *exactly*.
  ///
  /// Every finite IEEE 754 double is a dyadic rational, so such a pair always
  /// exists: doubling a `Float` only increments its binary exponent and never
  /// loses a bit, so repeatedly doubling until the value becomes integral
  /// yields the numerator, and the number of doublings yields `exponent`.
  ///
  /// Traps if `value` is `NaN` or infinite, neither of which denotes a
  /// rational number.
  func splitFloat(value : Float) : (Nat, Nat32) {
    var numerator = Prim.floatAbs(value);
    // `NaN` and infinity are the only doubles for which `x - x` is not `0.0`.
    // They have to be rejected up front: a `NaN` would never become integral
    // in the loop below.
    if (numerator - numerator != 0.0) {
      Prim.trap("FinancialMath: multiplier must be a finite number");
    };
    var exponent : Nat32 = 0;
    while (numerator != Prim.floatFloor(numerator)) {
      numerator *= 2.0;
      exponent += 1;
    };
    (Prim.abs(Prim.floatToInt(numerator)), exponent);
  };

  /// Returns `floor(value * Float.abs(multiplier))`, computed exactly:
  /// `multiplier` is the fraction `numerator / 2 ** exponent`, so the product is
  /// a multiplication and a right shift on unbounded `Nat`s.
  ///
  /// Traps if `multiplier` is `NaN` or infinite.
  func multiplyFloor(value : Nat, multiplier : Float) : Nat {
    let (numerator, exponent) = splitFloat(multiplier);
    Prim.shiftRight(value * numerator, exponent);
  };

  /// Returns `ceil(value * Float.abs(multiplier))`, computed exactly.
  ///
  /// Traps if `multiplier` is `NaN` or infinite.
  func multiplyCeil(value : Nat, multiplier : Float) : Nat {
    let (numerator, exponent) = splitFloat(multiplier);
    let product = value * numerator;
    let quotient = Prim.shiftRight(product, exponent);
    // The shift dropped nothing exactly when it is undone by shifting back.
    if (Prim.shiftLeft(quotient, exponent) == product) quotient else quotient + 1;
  };

  /// Converts a `Nat` to a `Float`, truncating the integer first when it is
  /// larger than the 53-bit mantissa can represent.
  ///
  /// The truncation is performed by shifting right until the value fits,
  /// then shifting left again before the conversion. This makes the returned
  /// floating-point value correspond to a lower integer rather than allowing
  /// the conversion to round the value up.
  public func intToFloatFloor(value : Nat) : Float {
    var high = Prim.shiftRight(value, 53);
    var shift : Nat32 = 0;
    while (high != 0) {
      high := Prim.shiftRight(high, 1);
      shift += 1;
    };
    Prim.intToFloat(Prim.shiftLeft(Prim.shiftRight(value, shift), shift));
  };

  /// Multiplies a `Nat` `value` by a `Float` `multiplier` and returns the
  /// floored result as a `Nat`, without any intermediate loss of precision.
  ///
  /// Use this when the result is an amount you are going to *pay out* (e.g. the
  /// base tokens a bidder receives), so that rounding never works against the
  /// canister: the returned value is always less than or equal to the exact
  /// mathematical product of `value` and `multiplier`.
  ///
  /// As long as `value` and the product both stay below `2 ** 53`, the product
  /// is computed in floating point: every integer in that range is
  /// representable, so the `Float` result is less than one unit away from the
  /// exact product, and flooring it absorbs the difference. This is also what
  /// keeps a `Float` that merely approximates a decimal from costing a unit of
  /// rounding — `0.0125` denotes `0.012500000000000000693...`, and the example
  /// below still yields the expected `50`.
  ///
  /// Above `2 ** 53` that reasoning breaks down: not every integer is
  /// representable any more, so both the conversion of `value` and the
  /// multiplication round to nearest and either can push the result *above* the
  /// exact product — which is precisely what this function must never do. For
  /// those products `multiplier` is instead decomposed into the exact fraction
  /// `numerator / 2 ** k` that it denotes, and the multiplication and division
  /// are carried out on unbounded `Nat`s, so the result is exact no matter how
  /// large the operands are.
  ///
  /// Example:
  /// ```motoko include=import
  /// let payout = FinancialMath.multiplyNatByFloatMin(4_000, 0.0125); // 50
  /// ```
  ///
  /// `multiplier` is expected to be a non-negative price. A negative
  /// `multiplier` returns the absolute value of the floored product rather than
  /// a negative number.
  ///
  /// Traps if `multiplier` is `NaN` or infinite.
  public func multiplyNatByFloatMin(value : Nat, multiplier : Float) : Nat {
    if (value <= mantissaLimit) {
      // The conversion is exact here, so the multiplication below rounds at
      // most once. A `NaN` or infinite product fails this test and falls
      // through to the exact path, which rejects both.
      let product = multiplier * Prim.intToFloat(value);
      if (Prim.floatAbs(product) < mantissaLimitAsFloat) {
        return Prim.abs(Prim.floatToInt(Prim.floatFloor(product)));
      };
    };
    // Flooring a negative product rounds its magnitude up, because
    // `floor(-x) == -ceil(x)`.
    if (multiplier < 0.0) {
      multiplyCeil(value, multiplier);
    } else {
      multiplyFloor(value, multiplier);
    };
  };

  /// Multiplies a `Nat` `value` by a `Float` `multiplier` and returns the
  /// ceiled result as a `Nat`, without any intermediate loss of precision.
  ///
  /// Use this when the result is an amount you are going to *collect* or
  /// require as a minimum (e.g. the quote tokens a bidder must lock for a
  /// margin), so that rounding never works against the canister: the returned
  /// value is always greater than or equal to the exact mathematical product of
  /// `value` and `multiplier`.
  ///
  /// Like `multiplyNatByFloatMin`, products below `2 ** 53` are computed in
  /// floating point and larger ones in exact integer arithmetic, where rounding
  /// to nearest can otherwise land *below* the exact product.
  ///
  /// Below `2 ** 53` the guarantee is therefore the weaker one that the result
  /// is the ceiling of the *rounded* product, which can be one unit below the
  /// exact product. That is the deliberate trade for treating a `Float` as the
  /// decimal it was written as: the double nearest `0.0125` is
  /// `0.012500000000000000693...`, so a strict ceiling of `4_000 * 0.0125`
  /// would be `51` rather than the `50` in the example below. Use `DecimalNat`
  /// when the multiplier has to be an exact decimal and the collected amount
  /// must never be short.
  ///
  /// Example:
  /// ```motoko include=import
  /// let required = FinancialMath.multiplyNatByFloatMax(4_000, 0.0125); // 50
  /// ```
  ///
  /// `multiplier` is expected to be a non-negative price. A negative
  /// `multiplier` returns the absolute value of the ceiled product rather than
  /// a negative number.
  ///
  /// Traps if `multiplier` is `NaN` or infinite.
  public func multiplyNatByFloatMax(value : Nat, multiplier : Float) : Nat {
    if (value <= mantissaLimit) {
      // The conversion is exact here, so the multiplication below rounds at
      // most once. A `NaN` or infinite product fails this test and falls
      // through to the exact path, which rejects both.
      let product = multiplier * Prim.intToFloat(value);
      if (Prim.floatAbs(product) < mantissaLimitAsFloat) {
        return Prim.abs(Prim.floatToInt(Prim.floatCeil(product)));
      };
    };
    // Ceiling a negative product rounds its magnitude down, because
    // `ceil(-x) == -floor(x)`.
    if (multiplier < 0.0) {
      multiplyFloor(value, multiplier);
    } else {
      multiplyCeil(value, multiplier);
    };
  };

  /// Scales a `Float` `value` by a power of ten given by `decimals`.
  ///
  /// Returns `value * (10 ** decimals)`. A positive `decimals` shifts the
  /// decimal point to the right (multiplies), a negative `decimals` shifts it to
  /// the left (divides), and `0` returns `value` unchanged. This is convenient
  /// for converting between the raw integer scale of a token (with a fixed
  /// number of `decimals`) and a human-scale floating-point value.
  ///
  /// Example:
  /// ```motoko include=import
  /// let up = FinancialMath.scaleFloat(1.5, 2); // 150.0
  /// let down = FinancialMath.scaleFloat(150.0, -2); // 1.5
  /// ```
  ///
  /// Never traps.
  public func scaleFloat(value : Float, decimals : Int) : Float {
    if (decimals == 0) {
      value;
    } else if (decimals > 0) {
      value * Float.pow(10.0, Int.toFloat(decimals));
    } else {
      value / Float.pow(10.0, Int.toFloat(-decimals));
    };
  };

};
