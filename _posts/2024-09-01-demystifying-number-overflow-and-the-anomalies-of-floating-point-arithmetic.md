---
layout: post
title: "Integer Overflow and Floating-Point Precision: Ruby vs JS"
description: "Why 0.1 + 0.2 doesn't equal 0.3, how Ruby's arbitrary-precision integers avoid overflow, and how JavaScript's BigInt does the same for large integers."
date: 2024-09-01 00:00 +0000
categories: [Engineering]
tags: [ruby, javascript, debugging]
---
<audio controls preload="metadata" src="/assets/audio/demystifying-number-overflow-and-the-anomalies-of-floating-point-arithmetic-summary.ogg">
  Your browser does not support the audio element.
</audio>

Two number problems come up often enough to be worth knowing cold: what happens when a number gets bigger than its type can hold, and why `0.1 + 0.2` doesn't equal `0.3`. Neither is a bug in the language, both are consequences of how numbers are represented in memory.

## Number overflow

Overflow happens when a calculation produces a value larger than the maximum a variable's type can hold. Depending on the language and type, that shows up as a crash, a wrapped-around value, or silent promotion to a bigger type.

### Ruby integers don't overflow

Ruby integers grow arbitrarily large, limited only by available memory, so `Integer` overflow isn't something you need to guard against. Floats are a different story: they still follow the IEEE 754 standard, which has a real maximum representable value.

```ruby
# Float in Ruby: IEEE 754
# 1. sign bit 1 bits
# 2. exponent 11 bits
# 3. mantissa/fraction 52 bits

puts 1e308      # 1e308
puts 1e309      # => Infinity

Float::MAX      # => 1.7976931348623157e+308
Float::INFINITY # => Infinity

# Be careful about the float overflow
def main(num1, num2)
  (num1 + num2) / 2.0
end
```

## Why `0.1 + 0.2` is not `0.3`

Floating-point numbers are stored in binary, and most decimal fractions, `0.1` included, have no exact binary representation. Each one is stored as the nearest approximation, and arithmetic on approximations produces rounding error.

```ruby
0.1 + 0.2       # => 0.30000000000000004
(2e+16 + 0.5) == (2e+16 + 0.0) + 0.5 # => true
```

In practice this means: never compare floats for exact equality, use a tolerance instead, and for money or anything else where precision actually matters, reach for a decimal or arbitrary-precision type rather than a float.

## JavaScript and Ruby, side by side

JavaScript represents both integers and floats with a single `Number` type, which is a `float64` under the hood. That's fine until you need an integer bigger than `Number.MAX_SAFE_INTEGER`, which is where `BigInt` comes in.

```javascript
function bigIntMean(a, b) {
    const aBigInt = BigInt(a);
    const bBigInt = BigInt(b);
    const meanBigInt = (aBigInt + bBigInt) / 2n;
    return meanBigInt;
}

// Example usage with large integers
const result = bigIntMean("5000000000000000000000", "5000000000000000000000");
console.log("The mean is:", result.toString());
```

Ruby 3 unified `Fixnum` and `Bignum` into a single `Integer` type with arbitrary precision, so the equivalent of JavaScript's `BigInt` problem doesn't come up for integers. Floats in Ruby still follow IEEE 754, same as everywhere else.

## Further reading

- [IEEE 754 Standard](https://ieeexplore.ieee.org/document/4610935)
- [Understanding JavaScript's Number Type](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Numbers_and_dates)
- [Python's Floating Point Arithmetic: Issues and Limitations](https://docs.python.org/3/tutorial/floatingpoint.html)
- [Ruby's Integer and Float](https://ruby-doc.org/core-3.3.0/Integer.html)


