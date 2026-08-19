/// Arbitrary-precision decimal numbers backed by integers.
///
/// A `DecimalInt` is a pair of an integer `value` and an integer `decimals` that
/// together denote the real number `value * 10 ** (-decimals)`. For example
/// `{ value = 123; decimals = 2 }` denotes `1.23`, and
/// `{ value = 123; decimals = -2 }` denotes `12300`.
///
/// The motivation is to perform exact, integer-based arithmetic on token
/// amounts and prices without the precision loss of `Float`: because the
/// underlying `value` is an unbounded `Int`, addition, subtraction and
/// multiplication are always exact, no matter how large the numbers grow.
///
/// This module intentionally omits division: the quotient of two decimals is
/// not, in general, representable exactly in base ten, so a lossy operation
/// would break the exactness guarantee of the rest of the API. Convert to
/// `Float` explicitly with `toFloat` when an approximate quotient is needed.
///
/// ```motoko name=import
/// import DecimalInt "mo:safe-financial-math/DecimalInt";
/// ```
///
/// Copyright: 2026 MR Research AG
/// Main author: AndyGura
/// Contributors: TimoHanke

import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Float "mo:core/Float";
import Order "mo:core/Order";

import DecimalNat "./DecimalNat";
import { pow10 } "./utils";

module {

  /// A base-ten fixed-point number denoting `value * 10 ** (-decimals)`.
  ///
  /// `value`: the significant digits as an unbounded integer.
  /// `decimals`: the base-ten scale; a positive `decimals` places digits after
  /// the decimal point (e.g. `(123, 2)` is `1.23`), a negative `decimals`
  /// appends trailing zeros (e.g. `(123, -2)` is `12300`), and `0` denotes the
  /// integer `value` itself.
  public type DecimalInt = {
    value : Int;
    decimals : Int;
  };

  /// Returns the raw `value` of `d` rescaled so that it corresponds to
  /// `target` decimals, i.e. `d.value * 10 ** (target - d.decimals)`.
  ///
  /// The caller must ensure `target >= d.decimals` so that the exponent is
  /// non-negative and the rescaling is exact (no digits are dropped).
  func rescaleValue_(self : DecimalInt, target : Int) : Int {
    let shift = Int.abs(target - self.decimals);
    self.value * (pow10(shift) : Int);
  };

  /// Returns `n` as a `DecimalInt` with zero decimals.
  ///
  /// Example:
  /// ```motoko include=import
  /// let d = DecimalInt.fromInt(42); // 42
  /// ```
  ///
  /// Never traps.
  public func fromInt(n : Int) : DecimalInt {
    { value = n; decimals = 0 };
  };

  /// Constructs the `DecimalInt` denoting `value * 10 ** (-decimals)`.
  ///
  /// Example:
  /// ```motoko include=import
  /// let a = DecimalInt.new(123, 2); // 1.23
  /// let b = DecimalInt.new(123, -2); // 12300
  /// ```
  ///
  /// Never traps.
  public func new(value : Int, decimals : Int) : DecimalInt {
    { value = value; decimals = decimals };
  };

  /// Constructs a `DecimalInt` from a `Float`, keeping exactly `digits`
  /// significant decimal digits of its magnitude. The sign of `f` carries
  /// over to `value` unchanged.
  ///
  /// `f` is treated as the decimal number closest to its exact binary value —
  /// not as the shorter decimal a human may have written — so the result
  /// reproduces `f`'s own digits: `fromFloat(-0.1, 3)` returns `(-100, 3)`
  /// (`-0.100`), the significant digits of the double nearest `0.1`, not some
  /// "nicer" alternative. Digits beyond roughly the double's own 15-17
  /// significant digits reflect that binary representation error rather than
  /// genuine precision, so keep `digits` within that range when it matters.
  /// Any digits past the requested `digits` are truncated towards zero, not
  /// rounded to the nearest value.
  ///
  /// `digits` counts significant digits, not decimal places, so it does not
  /// bound the magnitude of `f`: `fromFloat(1_000_000_000.0, 5)` keeps all 5
  /// requested digits and represents the trailing zeros with a negative
  /// `decimals` instead of dropping them. A `digits` of `0` keeps none and
  /// always returns `0`. `f == 0.0` (or `-0.0`) is a special case for the same
  /// reason — it has no significant digits to count from — and always returns
  /// `0` regardless of `digits`.
  ///
  /// Example:
  /// ```motoko include=import
  /// let a = DecimalInt.fromFloat(1.23, 3); // 1.23
  /// let b = DecimalInt.fromFloat(-10_234.5678, 9); // -10234.5678
  /// let c = DecimalInt.fromFloat(1_000_000_000.0, 5); // 1_000_000_000, as 10_000 * 10 ** 5
  /// let d = DecimalInt.fromFloat(0.0, 5); // 0
  /// ```
  ///
  /// Traps if `f` is `NaN` or infinite: neither denotes a decimal number at
  /// all.
  public func fromFloat(f : Float, digits : Nat) : DecimalInt {
    if (f == 0) return new(0, 0);
    let div = if (f > 1 or f < -1) {
      2.302_585_092_994_045_6;
    } else {
      2.302_585_092_994_045_7;
    };
    let log10 = Float.floor(Float.log(Float.abs(f)) / div);
    let e = Float.fromInt(digits) - 1 - log10;
    new(
      Float.toInt(Float.floor(f * 10 ** e)),
      digits - Float.toInt(log10) - 1,
    );
  };

  /// Returns the exact sum `a + b`.
  ///
  /// Both operands are first rescaled to the finer (larger) of the two
  /// `decimals` so no precision is lost; the result carries that finer scale.
  ///
  /// Example:
  /// ```motoko include=import
  /// let sum = DecimalInt.add(DecimalInt.new(123, 2), DecimalInt.new(1, 0)); // 2.23
  /// ```
  ///
  /// Never traps.
  public func add(self : DecimalInt, other : DecimalInt) : DecimalInt {
    let target = Int.max(self.decimals, other.decimals);
    {
      value = rescaleValue_(self, target) + rescaleValue_(other, target);
      decimals = target;
    };
  };

  /// Returns the exact difference `a - b`.
  ///
  /// Both operands are first rescaled to the finer (larger) of the two
  /// `decimals` so no precision is lost; the result carries that finer scale.
  ///
  /// Example:
  /// ```motoko include=import
  /// let diff = DecimalInt.sub(DecimalInt.new(123, 2), DecimalInt.new(1, 0)); // 0.23
  /// ```
  ///
  /// Never traps.
  public func sub(self : DecimalInt, other : DecimalInt) : DecimalInt {
    let target = Int.max(self.decimals, other.decimals);
    {
      value = rescaleValue_(self, target) - rescaleValue_(other, target);
      decimals = target;
    };
  };

  /// Returns the exact product `a * b`.
  ///
  /// Multiplication is exact and needs no rescaling: the values are multiplied
  /// and the scales added (`decimals = a.decimals + b.decimals`).
  ///
  /// Example:
  /// ```motoko include=import
  /// let product = DecimalInt.mul(DecimalInt.new(123, 2), DecimalInt.new(5, 1)); // 0.615
  /// ```
  ///
  /// Never traps.
  public func mul(self : DecimalInt, other : DecimalInt) : DecimalInt {
    {
      value = self.value * other.value;
      decimals = self.decimals + other.decimals;
    };
  };

  /// Returns the additive inverse `-a`, preserving the scale.
  ///
  /// Never traps.
  public func neg(self : DecimalInt) : DecimalInt {
    { value = -self.value; decimals = self.decimals };
  };

  /// Returns the absolute value `|a|` as a `DecimalNat`, preserving the scale.
  ///
  /// Because the magnitude is always non-negative, the result is returned as a
  /// `DecimalNat` (a `Nat`-backed decimal).
  ///
  /// Never traps.
  public func abs(self : DecimalInt) : DecimalNat.DecimalNat {
    { value = Int.abs(self.value); decimals = self.decimals };
  };

  /// Compares `a` and `b` by their real value, returning an `Order.Order`.
  ///
  /// Values that denote the same real number compare `#equal` even when their
  /// representations differ, e.g. `(100, 2)` and `(1, 0)` both denote `1`.
  ///
  /// Example:
  /// ```motoko include=import
  /// let ord = DecimalInt.compare(DecimalInt.new(100, 2), DecimalInt.new(1, 0)); // #equal
  /// ```
  ///
  /// Never traps.
  public func compare(self : DecimalInt, other : DecimalInt) : Order.Order {
    let target = Int.max(self.decimals, other.decimals);
    Int.compare(rescaleValue_(self, target), rescaleValue_(other, target));
  };

  /// Returns `true` when `a` and `b` denote the same real number.
  ///
  /// Equality is by value, not by representation, so `(100, 2)` equals `(1, 0)`.
  ///
  /// Never traps.
  public func equal(self : DecimalInt, other : DecimalInt) : Bool {
    compare(self, other) == #equal;
  };

  /// Rounds `d` down to the nearest integer and returns it as an `Int`.
  ///
  /// A decimal with `decimals <= 0` already denotes an integer and is
  /// returned exactly (scaled up by the trailing zeros) without any rounding.
  ///
  /// Example:
  /// ```motoko include=import
  /// let r = DecimalInt.floor(DecimalInt.new(125, 2)); // 1 (1.25 rounds to 1)
  /// let s = DecimalInt.floor(DecimalInt.new(-175, 2)); // -2 (-1.75 rounds to -2)
  /// ```
  ///
  /// Never traps.
  public func floor(self : DecimalInt) : Int {
    if (self.decimals <= 0) {
      // No fractional part: value * 10 ** (-decimals) is already an integer.
      self.value * pow10(Int.abs(self.decimals));
    } else {
      let scale = pow10(Int.abs(self.decimals));
      let magnitude = Int.abs(self.value);
      let quotient = magnitude / scale;
      let remainder = magnitude % scale;
      // The division truncates towards zero, so a negative value with a
      // fractional part needs one more step away from zero to reach the floor.
      if (self.value < 0) {
        if (remainder > 0) -(quotient + 1) else -quotient;
      } else {
        quotient;
      };
    };
  };

  /// Rounds `d` up to the nearest integer and returns it as an `Int`.
  ///
  /// A decimal with `decimals <= 0` already denotes an integer and is
  /// returned exactly (scaled up by the trailing zeros) without any rounding.
  ///
  /// Example:
  /// ```motoko include=import
  /// let r = DecimalInt.ceil(DecimalInt.new(125, 2)); // 2 (1.25 rounds to 2)
  /// let s = DecimalInt.ceil(DecimalInt.new(-175, 2)); // -1 (-1.75 rounds to -1)
  /// ```
  ///
  /// Never traps.
  public func ceil(self : DecimalInt) : Int {
    if (self.decimals <= 0) {
      // No fractional part: value * 10 ** (-decimals) is already an integer.
      self.value * pow10(Int.abs(self.decimals));
    } else {
      let scale = pow10(Int.abs(self.decimals));
      let magnitude = Int.abs(self.value);
      let quotient = magnitude / scale;
      let remainder = magnitude % scale;
      // The division truncates towards zero, which is already the ceiling of a
      // negative value; a positive value with a fractional part needs one more
      // step away from zero.
      if (self.value < 0) {
        -quotient;
      } else if (remainder > 0) {
        quotient + 1;
      } else {
        quotient;
      };
    };
  };

  /// Rounds `d` to the nearest integer and returns it as an `Int`.
  ///
  /// Ties (a fractional part of exactly one half) are rounded away from zero.
  /// A decimal with `decimals <= 0` already denotes an integer and is returned
  /// exactly (scaled up by the trailing zeros) without any rounding.
  ///
  /// Example:
  /// ```motoko include=import
  /// let r = DecimalInt.round(DecimalInt.new(125, 2)); // 1 (1.25 rounds to 1)
  /// let s = DecimalInt.round(DecimalInt.new(150, 2)); // 2 (1.50 rounds to 2)
  /// ```
  ///
  /// Never traps.
  public func round(self : DecimalInt) : Int {
    if (self.decimals <= 0) {
      // No fractional part: value * 10 ** (-decimals) is already an integer.
      self.value * (pow10(Int.abs(self.decimals)) : Int);
    } else {
      let scale = pow10(Int.abs(self.decimals));
      let magnitude = Int.abs(self.value);
      let quotient = magnitude / scale;
      let remainder = magnitude % scale;
      let rounded = if (2 * remainder >= scale) quotient + 1 else quotient;
      if (self.value < 0) -rounded else rounded;
    };
  };

  /// Returns the closest `Float` to the real value of `d`.
  ///
  /// The conversion goes through IEEE 754 double arithmetic, so the result is
  /// only an approximation and may lose precision for values with many
  /// significant digits or a magnitude beyond `2 ** 53`.
  ///
  /// Example:
  /// ```motoko include=import
  /// let f = DecimalInt.toFloat(DecimalInt.new(123, 2)); // 1.23
  /// ```
  ///
  /// Never traps.
  public func toFloat(self : DecimalInt) : Float {
    Float.fromInt(self.value) / Float.pow(10.0, Float.fromInt(self.decimals));
  };

  /// Renders `d` as a base-ten decimal string.
  ///
  /// A negative value is prefixed with `-`. When `decimals <= 0` the result is
  /// an integer with `-decimals` trailing zeros (e.g. `(123, -2)` yields
  /// `"12300"`). When `decimals > 0` a decimal point is inserted so that
  /// exactly `decimals` fractional digits are shown, padding with leading zeros
  /// when necessary (e.g. `(5, 3)` yields `"0.005"` and `(1200, 2)` yields
  /// `"12.00"`).
  ///
  /// Example:
  /// ```motoko include=import
  /// let t = DecimalInt.toText(DecimalInt.new(123, 2)); // "1.23"
  /// ```
  ///
  /// Never traps.
  public func toText(self : DecimalInt) : Text {
    if (self.decimals <= 0) {
      Int.toText(self.value) # zeros_(Int.abs(self.decimals));
    } else {
      let fractionalDigits = Int.abs(self.decimals);
      let scale = pow10(fractionalDigits);
      let magnitude = Int.abs(self.value);
      let integerPart = magnitude / scale;
      let fractionalPart = magnitude % scale;
      let fractionalText = padLeft(Nat.toText(fractionalPart), fractionalDigits);
      let body = Nat.toText(integerPart) # "." # fractionalText;
      if (self.value < 0) "-" # body else body;
    };
  };

  /// Returns a string of `count` `'0'` characters.
  func zeros_(count : Nat) : Text {
    var result = "";
    var i = 0;
    while (i < count) {
      result #= "0";
      i += 1;
    };
    result;
  };

  /// Left-pads `text` with `'0'` characters up to a total width of `width`.
  ///
  /// If `text` is already at least `width` characters long it is returned
  /// unchanged.
  func padLeft(text : Text, width : Nat) : Text {
    let size = text.size();
    if (size >= width) {
      text;
    } else {
      zeros_(width - size) # text;
    };
  };

};
