import { test } "mo:test";
import DecimalInt "../src/DecimalInt";
import DecimalNat "../src/DecimalNat";

test(
  "DecimalInt supports dot notation",
  func() {
    let a = DecimalInt.new(123, 2);
    let b = DecimalInt.new(1, 0);
    assert a.add(b).equal(DecimalInt.new(223, 2));
    assert a.sub(b).equal(DecimalInt.new(23, 2));
    assert a.mul(b).equal(DecimalInt.new(123, 2));
    assert a.neg().equal(DecimalInt.new(-123, 2));
    assert a.compare(b) == #greater;
    assert a.round() == 1;
    assert a.toText() == "1.23";
    assert a.toFloat() == 1.23;
    assert DecimalInt.new(-123, 2).abs().equal(DecimalNat.new(123, 2));
  },
);

test(
  "DecimalNat supports dot notation",
  func() {
    let a = DecimalNat.new(123, 2);
    let b = DecimalNat.new(1, 0);
    assert a.add(b).equal(DecimalNat.new(223, 2));
    assert a.sub(b).equal(DecimalNat.new(23, 2));
    assert a.mul(b).equal(DecimalNat.new(123, 2));
    assert a.compare(b) == #greater;
    assert a.round() == 1;
    assert a.toText() == "1.23";
    assert a.toFloat() == 1.23;
  },
);
