/// Safe fixed-point financial math for Motoko.
///
/// This module provides arithmetic helpers for combining large integer token
/// quantities (`Nat`) with floating-point prices (`Float`) while mitigating the
/// precision loss and rounding drift inherent to IEEE 754 doubles.
///
/// A `Float` in Motoko is a 64-bit IEEE 754 double with a 53-bit mantissa. Any
/// integer larger than `2 ** 53` cannot be represented exactly, so a naive
/// `Float.fromInt(value) * price` can silently round the token amount *up*
/// before the multiplication even happens. In a financial setting this is
/// dangerous: rounding a payout up means a canister can pay out more than it
/// took in. The helpers here bound the rounding direction explicitly so callers
/// can pick the safe side (floor for what you pay out, ceil for what you
/// collect).
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
  /// floored result as a `Nat`, compensating for IEEE 754 precision loss.
  ///
  /// Use this when the result is an amount you are going to *pay out* (e.g. the
  /// base tokens a bidder receives), so that rounding never works against the
  /// canister: the returned value is always less than or equal to the exact
  /// mathematical product.
  ///
  /// Because `Float` only has a 53-bit mantissa, an integer larger than
  /// `2 ** 53` cannot be converted to `Float` exactly and is rounded up. To
  /// avoid this, `value` is truncated to a representable lower integer before
  /// it is converted and multiplied. This keeps the low-order bits from
  /// inflating the product.
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
  /// Traps if `multiplier` is `NaN` or infinite (the intermediate
  /// float-to-integer conversion is undefined for those values).
  public func multiplyNatByFloatMin(value : Nat, multiplier : Float) : Nat {
    multiplier * intToFloatFloor(value)
    |> Prim.floatFloor(_)
    |> Prim.abs(Prim.floatToInt(_));
  };

  /// Multiplies a `Nat` `value` by a `Float` `multiplier` and returns the
  /// ceiled result as a `Nat`.
  ///
  /// Use this when the result is an amount you are going to *collect* or
  /// require as a minimum (e.g. the quote tokens a bidder must lock for a
  /// margin), so that rounding never works against the canister: the returned
  /// value is always greater than or equal to the exact mathematical product.
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
  /// Traps if `multiplier` is `NaN` or infinite (the intermediate
  /// float-to-integer conversion is undefined for those values).
  public func multiplyNatByFloatMax(value : Nat, multiplier : Float) : Nat {
    multiplier * Prim.intToFloat(value)
    |> Prim.floatCeil(_)
    |> Prim.abs(Prim.floatToInt(_));
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
