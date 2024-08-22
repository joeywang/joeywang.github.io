---
layout: post
title: Round Is Not Always What You Expect
date: 2024-08-22 10:58 +0100
categories: [math, programming, rounding]
tags: ruby
---
# Round Is Not Always What You Expect

Rounding numbers is a common task in programming, but it's not always as straightforward as it seems. Different programming languages handle rounding in various ways, which can lead to unexpected results. Let's explore how some popular languages round the same number, `2.675`, to two decimal places.

## CSharp

In C#, the `Math.Round` function provides a default rounding behavior, but you can also specify how to handle midpoints with the `MidpointRounding` enumeration.

```csharp
using System;

class Program
{
    static void Main()
    {
        double number = 2.675;
        Console.WriteLine(Math.Round(number, 2)); // Default rounding, results in 2.7
        Console.WriteLine(Math.Round(number, 2, MidpointRounding.AwayFromZero)); // Rounds to 2.68
    }
}
```

When you run this C# program, you'll notice that the default rounding gives you `2.7`, but by specifying `MidpointRounding.AwayFromZero`, the result becomes `2.68`.

## PHP

PHP's `round` function uses the "round half up" method by default, which means it rounds .5 up to the nearest higher value.

```php
<?php
print "round(2.675, 2) = " . round(2.675, 2);
?>
```

If you run this PHP script, the output will be:

```
round(2.675, 2) = 2.68
```

## Go

Go's `math.Round` function rounds a floating-point number to the nearest integer, but we can adapt it for specific decimal places.

```go
package main

import (
	"fmt"
	"math"
)

func main() {
	fmt.Printf("round(2.675, 2): %.3f", math.Round(2.675*100)/100)
}
```

Running the Go program will give you the output:

```
round(2.675, 2): 2.68
```

## Python

Python's `round` function also uses "round half to even," which means it rounds to the nearest even number when encountering a .5.

```python
print("round(2.675, 2) = ", round(2.675, 2))
```

Interestingly, the Python script outputs:

```
round(2.675, 2) =  2.67
```

This is because Python rounds `2.675` to `2.67` instead of `2.68`, following the "round half to even" rule.

## JavaScript

JavaScript's `.toFixed` method formats a number using fixed-point notation, and when converted back to a number, it rounds according to standard rounding rules.

```js
console.log("Number((2.675).toFixed(2))", Number((2.675).toFixed(2)));
```

The output in the JavaScript console will be:

```
Number((2.675).toFixed(2)) 2.67
```

## Ruby

Ruby's `round` method rounds to the nearest value, and when it encounters a .5, it rounds to the nearest even number.

```ruby
puts "2.675.round(2) = #{2.675.round(2)}"
```

When you run this Ruby code, the result is:

```
2.675.round(2) = 2.68
```

## Conclusion

As we've seen, the same rounding operation can yield different results in different programming languages. Understanding the default rounding behavior and available rounding modes is crucial when performing precise arithmetic operations. Always consult the documentation for the language you're using to ensure your rounding operations behave as expected.
