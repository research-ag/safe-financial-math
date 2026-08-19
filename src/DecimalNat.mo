/// Arbitrary-precision decimal numbers backed by integers.
///
/// A `DecimalNat` is a pair of a non-negative `value` (`Nat`) and an integer
/// `decimals` that together denote the real number `value * 10 ** (-decimals)`.
/// For example
/// `{ value = 123; decimals = 2 }` denotes `1.23`, and
/// `{ value = 123; decimals = -2 }` denotes `12300`.
///
/// The motivation is to perform exact, integer-based arithmetic on token
/// amounts and prices without the precision loss of `Float`: because the
/// underlying `value` is an unbounded `Nat`, addition, subtraction and
/// multiplication are always exact, no matter how large the numbers grow.
/// Use `DecimalInt` instead when values may become negative.
///
/// This module intentionally omits division: the quotient of two decimals is
/// not, in general, representable exactly in base ten, so a lossy operation
/// would break the exactness guarantee of the rest of the API. Convert to
/// `Float` explicitly with `toFloat` when an approximate quotient is needed.
///
/// ```motoko name=import
/// import DecimalNat "mo:safe-financial-math/DecimalNat";
/// ```
///
/// Copyright: 2026 MR Research AG
/// Main author: AndyGura
/// Contributors: TimoHanke

import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Float "mo:core/Float";
import Order "mo:core/Order";
import Runtime "mo:core/Runtime";
import { pow10 } "./utils";

module {

  /// A base-ten fixed-point number denoting `value * 10 ** (-decimals)`.
  ///
  /// `value`: the significant digits as an unbounded non-negative integer.
  /// `decimals`: the base-ten scale; a positive `decimals` places digits after
  /// the decimal point (e.g. `(123, 2)` is `1.23`), a negative `decimals`
  /// appends trailing zeros (e.g. `(123, -2)` is `12300`), and `0` denotes the
  /// integer `value` itself.
  public type DecimalNat = {
    value : Nat;
    decimals : Int;
  };

  /// Returns the raw `value` of `d` rescaled so that it corresponds to
  /// `target` decimals, i.e. `d.value * 10 ** (target - d.decimals)`.
  ///
  /// The caller must ensure `target >= d.decimals` so that the exponent is
  /// non-negative and the rescaling is exact (no digits are dropped).
  func rescaleValue_(self : DecimalNat, target : Int) : Nat {
    let shift = target - self.decimals;
    if (shift > 0) {
      self.value * pow10(Int.abs(shift));
    } else if (shift == 0) {
      self.value;
    } else {
      Runtime.trap("DecimalNat.rescaleValue_: target decimals must be >= d.decimals");
    };
  };

  /// Returns `n` as a `DecimalNat` with zero decimals.
  ///
  /// Example:
  /// ```motoko include=import
  /// let d = DecimalNat.fromNat(42); // 42
  /// ```
  ///
  /// Never traps.
  public func fromNat(n : Nat) : DecimalNat {
    { value = n; decimals = 0 };
  };

  /// Constructs the `DecimalNat` denoting `value * 10 ** (-decimals)`.
  ///
  /// Example:
  /// ```motoko include=import
  /// let a = DecimalNat.new(123, 2); // 1.23
  /// let b = DecimalNat.new(123, -2); // 12300
  /// ```
  ///
  /// Never traps.
  public func new(value : Nat, decimals : Int) : DecimalNat {
    { value = value; decimals = decimals };
  };

  /// Returns the exact sum `a + b`.
  ///
  /// Both operands are first rescaled to the finer (larger) of the two
  /// `decimals` so no precision is lost; the result carries that finer scale.
  ///
  /// Example:
  /// ```motoko include=import
  /// let sum = DecimalNat.add(DecimalNat.new(123, 2), DecimalNat.new(1, 0)); // 2.23
  /// ```
  ///
  /// Never traps.
  public func add(self : DecimalNat, other : DecimalNat) : DecimalNat {
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
  /// let diff = DecimalNat.sub(DecimalNat.new(123, 2), DecimalNat.new(1, 0)); // 0.23
  /// ```
  ///
  /// Traps if the result underflows.
  public func sub(self : DecimalNat, other : DecimalNat) : DecimalNat {
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
  /// let product = DecimalNat.mul(DecimalNat.new(123, 2), DecimalNat.new(5, 1)); // 0.615
  /// ```
  ///
  /// Never traps.
  public func mul(self : DecimalNat, other : DecimalNat) : DecimalNat {
    {
      value = self.value * other.value;
      decimals = self.decimals + other.decimals;
    };
  };

  /// Compares `a` and `b` by their real value, returning an `Order.Order`.
  ///
  /// Values that denote the same real number compare `#equal` even when their
  /// representations differ, e.g. `(100, 2)` and `(1, 0)` both denote `1`.
  ///
  /// Example:
  /// ```motoko include=import
  /// let ord = DecimalNat.compare(DecimalNat.new(100, 2), DecimalNat.new(1, 0)); // #equal
  /// ```
  ///
  /// Never traps.
  public func compare(self : DecimalNat, other : DecimalNat) : Order.Order {
    let target = Int.max(self.decimals, other.decimals);
    Nat.compare(rescaleValue_(self, target), rescaleValue_(other, target));
  };

  /// Returns `true` when `a` and `b` denote the same real number.
  ///
  /// Equality is by value, not by representation, so `(100, 2)` equals `(1, 0)`.
  ///
  /// Never traps.
  public func equal(self : DecimalNat, other : DecimalNat) : Bool {
    compare(self, other) == #equal;
  };

  /// Rounds `d` down to the nearest integer and returns it as an `Nat`.
  ///
  /// A decimal with `decimals <= 0` already denotes an integer and is
  /// returned exactly (scaled up by the trailing zeros) without any rounding.
  ///
  /// Example:
  /// ```motoko include=import
  /// let r = DecimalNat.floor(DecimalNat.new(125, 2)); // 1 (1.25 rounds to 1)
  /// let s = DecimalNat.floor(DecimalNat.new(175, 2)); // 1 (1.75 rounds to 1)
  /// ```
  ///
  /// Never traps.
  public func floor(self : DecimalNat) : Nat {
    if (self.decimals <= 0) {
      // No fractional part: value * 10 ** (-decimals) is already an integer.
      self.value * pow10(Int.abs(self.decimals));
    } else {
      // The division truncates, which for a non-negative value is the floor.
      self.value / pow10(Int.abs(self.decimals));
    };
  };

  /// Rounds `d` up to the nearest integer and returns it as an `Nat`.
  ///
  /// A decimal with `decimals <= 0` already denotes an integer and is
  /// returned exactly (scaled up by the trailing zeros) without any rounding.
  ///
  /// Example:
  /// ```motoko include=import
  /// let r = DecimalNat.ceil(DecimalNat.new(125, 2)); // 2 (1.25 rounds to 2)
  /// let s = DecimalNat.ceil(DecimalNat.new(175, 2)); // 2 (1.75 rounds to 2)
  /// ```
  ///
  /// Never traps.
  public func ceil(self : DecimalNat) : Nat {
    if (self.decimals <= 0) {
      // No fractional part: value * 10 ** (-decimals) is already an integer.
      self.value * pow10(Int.abs(self.decimals));
    } else {
      let scale = pow10(Int.abs(self.decimals));
      let quotient = self.value / scale;
      if (self.value % scale > 0) quotient + 1 else quotient;
    };
  };

  /// Rounds `d` to the nearest integer and returns it as an `Nat`.
  ///
  /// Ties (a fractional part of exactly one half) are rounded up (away from
  /// zero). A decimal with `decimals <= 0` already denotes an integer and is
  /// returned exactly (scaled up by the trailing zeros) without any rounding.
  ///
  /// Example:
  /// ```motoko include=import
  /// let r = DecimalNat.round(DecimalNat.new(125, 2)); // 1 (1.25 rounds to 1)
  /// let s = DecimalNat.round(DecimalNat.new(150, 2)); // 2 (1.50 rounds to 2)
  /// ```
  ///
  /// Never traps.
  public func round(self : DecimalNat) : Nat {
    if (self.decimals <= 0) {
      // No fractional part: value * 10 ** (-decimals) is already an integer.
      self.value * pow10(Int.abs(self.decimals));
    } else {
      let scale = pow10(Int.abs(self.decimals));
      let quotient = self.value / scale;
      let remainder = self.value % scale;
      if (2 * remainder >= scale) quotient + 1 else quotient;
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
  /// let f = DecimalNat.toFloat(DecimalNat.new(123, 2)); // 1.23
  /// ```
  ///
  /// Never traps.
  public func toFloat(self : DecimalNat) : Float {
    Float.fromInt(self.value) / Float.pow(10.0, Float.fromInt(self.decimals));
  };

  /// Renders `d` as a base-ten decimal string.
  ///
  /// When `decimals <= 0` the result is an integer with `-decimals` trailing
  /// zeros (e.g. `(123, -2)` yields `"12300"`). When `decimals > 0` a decimal
  /// point is inserted so that exactly `decimals` fractional digits are shown,
  /// padding with leading zeros when necessary (e.g. `(5, 3)` yields `"0.005"`
  /// and `(1200, 2)` yields
  /// `"12.00"`).
  ///
  /// Example:
  /// ```motoko include=import
  /// let t = DecimalNat.toText(DecimalNat.new(123, 2)); // "1.23"
  /// ```
  ///
  /// Never traps.
  public func toText(self : DecimalNat) : Text {
    if (self.decimals <= 0) {
      Nat.toText(self.value) # zeros_(Int.abs(self.decimals));
    } else {
      let fractionalDigits = Int.abs(self.decimals);
      let scale = pow10(fractionalDigits);
      let magnitude = Int.abs(self.value);
      let integerPart = magnitude / scale;
      let fractionalPart = magnitude % scale;
      let fractionalText = padLeft(Nat.toText(fractionalPart), fractionalDigits);
      Nat.toText(integerPart) # "." # fractionalText;
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
