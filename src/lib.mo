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
/// can go in the unsafe direction. In a financial setting this is dangerous:
/// rounding a payout up means a canister can pay out more than it took in.
/// The helpers here bound the rounding direction explicitly so callers can pick
/// the safe side (floor for what you pay out, ceil for what you collect), and
/// they get that bound by computing the product in exact integer arithmetic
/// rather than in floating point.
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

  /// Divides `dividend` by `2 ** bits`, rounding the quotient up.
  func shiftRightCeil(dividend : Nat, bits : Nat32) : Nat {
    let quotient = Prim.shiftRight(dividend, bits);
    // The shift dropped nothing exactly when it is undone by shifting back.
    if (Prim.shiftLeft(quotient, bits) == dividend) quotient else quotient + 1;
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
  /// The product is *not* computed in floating point. A `Float` has only a
  /// 53-bit mantissa, so both the conversion of a large `value` and the
  /// multiplication itself round to nearest, and either can push the result
  /// *above* the exact product — which is precisely what this function must
  /// never do. Instead `multiplier` is decomposed into the exact fraction
  /// `numerator / 2 ** k` that it denotes, and the multiplication and division
  /// are carried out on unbounded `Nat`s. The result is therefore exact for
  /// arbitrarily large operands.
  ///
  /// Note that the bound is on the product of `value` and the `Float` value of
  /// `multiplier`, which is itself only the closest double to the decimal a
  /// caller writes: `0.0125` denotes `0.012500000000000000693...`. Use
  /// `DecimalNat` when the multiplier has to be an exact decimal.
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
    let (numerator, exponent) = splitFloat(multiplier);
    let product = value * numerator;
    // Flooring a negative product rounds its magnitude up, because
    // `floor(-x) == -ceil(x)`.
    if (multiplier < 0.0) {
      shiftRightCeil(product, exponent);
    } else {
      Prim.shiftRight(product, exponent);
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
  /// Like `multiplyNatByFloatMin`, the product is computed in exact integer
  /// arithmetic rather than in floating point, where rounding to nearest can
  /// land *below* the exact product once the product exceeds `2 ** 53`.
  ///
  /// Example:
  /// ```motoko include=import
  /// // 4_000 * 0.012500000000000000693... = 50.000000000000002775...
  /// let required = FinancialMath.multiplyNatByFloatMax(4_000, 0.0125); // 51
  /// ```
  ///
  /// As the example shows, ceiling the exact product of a `Float` that only
  /// approximates a decimal can cost a unit of rounding. Use `DecimalNat` when
  /// the multiplier has to be an exact decimal.
  ///
  /// `multiplier` is expected to be a non-negative price. A negative
  /// `multiplier` returns the absolute value of the ceiled product rather than
  /// a negative number.
  ///
  /// Traps if `multiplier` is `NaN` or infinite.
  public func multiplyNatByFloatMax(value : Nat, multiplier : Float) : Nat {
    let (numerator, exponent) = splitFloat(multiplier);
    let product = value * numerator;
    // Ceiling a negative product rounds its magnitude down, because
    // `ceil(-x) == -floor(x)`.
    if (multiplier < 0.0) {
      Prim.shiftRight(product, exponent);
    } else {
      shiftRightCeil(product, exponent);
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
