---
layout: post
title: "Closures, Blocks, and Iterators Across Six Languages"
date: 2025-07-14
tags: [ruby, javascript, python, rust, go, php]
description: "A working comparison of how Python, JavaScript, Ruby, PHP, Rust, and Go implement closures and lazy iteration, with a runnable counter and generator example for each."
categories: [Engineering]
---

<audio controls preload="metadata" src="/assets/audio/closure-block-languages-summary.ogg">
  Your browser does not support the audio element.
</audio>

Every language needs some way to carry state across calls without polluting global scope, and some way to produce a sequence of values without building the whole thing in memory first. Closures solve the first problem, iterators and generators solve the second. Python, JavaScript, Ruby, PHP, Rust, and Go take genuinely different approaches to both, shaped by what each language optimizes for: convenience, safety, or raw throughput. The best way to see the differences is the same example six times: a counter closure and a Fibonacci generator.

-----

### Python: closures and generators

Python closures capture variables from an enclosing scope. Mutating one of those variables from inside the closure requires declaring it `nonlocal`; without that, an assignment creates a new local variable instead of touching the outer one.

```python
def create_counter():
    count = 0  # This variable is in the enclosing scope

    def increment():
        nonlocal count # Essential to modify 'count' from the enclosing scope
        count += 1
        return count
    return increment # Return the inner function

# Create separate counter instances
counter1 = create_counter()
counter2 = create_counter()

print(f"Counter 1 first call: {counter1()}") # Output: Counter 1 first call: 1
print(f"Counter 1 second call: {counter1()}") # Output: Counter 1 second call: 2
print(f"Counter 2 first call: {counter2()}") # Output: Counter 2 first call: 1
```

Each call to `create_counter` gets its own `count`. That's the whole point: state that outlives the function call that created it, without touching a module-level global.

Generators solve a different problem: producing values lazily. A function containing `yield` returns an iterator that pauses at each `yield` and resumes exactly where it left off, keeping its local state intact between calls.

```python
def fibonacci_generator(limit):
    a, b = 0, 1
    count = 0
    print(f"Generator initialized with limit: {limit}")
    while count < limit:
        yield a
        a, b = b, a + b
        count += 1
    print("Fibonacci sequence finished!")

# Create a generator instance
fib_gen = fibonacci_generator(5)

print(f"First value: {next(fib_gen)}")  # Output: Generator initialized with limit: 5 \n First value: 0
print(f"Second value: {next(fib_gen)}") # Output: Second value: 1
print(f"Third value: {next(fib_gen)}")  # Output: Third value: 1

# Using next() with a default value
value_if_found = next(('found' for k in [1, 2, 3] if k == 11), None)
print(f"Value if found: {value_if_found}") # Output: Value if found: None
```

This matters for anything that doesn't need every value at once: streaming a large file, walking an infinite sequence, or chaining transformations without materializing intermediate lists.

-----

### JavaScript: closures and generators

JavaScript closures work the same way conceptually: an inner function keeps a live reference to variables in its enclosing scope even after the outer function has returned. It's the mechanism behind most callbacks, event handlers, and module patterns in the language.

```javascript
function createCounter() {
    let count = 0; // This variable is in the enclosing scope

    return function() { // This is the inner function, forming a closure
        count++;
        return count;
    };
}

// Create separate counter instances
const counter1 = createCounter();
const counter2 = createCounter();

console.log(`Counter 1 first call: ${counter1()}`); // Output: Counter 1 first call: 1
console.log(`Counter 1 second call: ${counter1()}`); // Output: Counter 1 second call: 2
console.log(`Counter 2 first call: ${counter2()}`); // Output: Counter 2 first call: 1
```

The state is invisible to anything outside the closure, which is as close as JavaScript gets to private instance variables without a class.

ES6 generators (`function*` and `yield`) give JavaScript the same pause-and-resume model as Python's, and they're the mechanism `async`/`await` is built on under the hood.

```javascript
function* fibonacciGenerator(limit) {
    let a = 0, b = 1;
    let count = 0;
    console.log(`JS Generator initialized with limit: ${limit}`);
    while (count < limit) {
        yield a;
        [a, b] = [b, a + b]; // Array destructuring for swap
        count++;
    }
    console.log("JS Fibonacci sequence finished!");
}

const jsFibGen = fibonacciGenerator(5);

console.log(`JS First value: ${jsFibGen.next().value}`); // Output: JS Generator initialized with limit: 5 \n JS First value: 0
console.log(`JS Second value: ${jsFibGen.next().value}`); // Output: JS Second value: 1
console.log(`JS Third value: ${jsFibGen.next().value}`);  // Output: JS Third value: 1
```

Anything implementing the iterable protocol, generators included, works directly in a `for...of` loop.

-----

### Ruby: blocks, procs, and lambdas

Ruby blocks are the odd one out on this list: instead of being closures you construct and return, they're anonymous chunks of code passed directly into a method call, with lexical access to variables in the scope where they were written.

```ruby
def apply_action_to_numbers(numbers)
  numbers.each do |num|
    yield num # Executes the block passed to this method
  end
end

my_var = 10 # Variable in the outer scope

apply_action_to_numbers([1, 2, 3]) do |n|
  puts "Current number: #{n}"
  # Blocks can directly access and modify outer scope variables
  my_var += n
end

puts "Final my_var value: #{my_var}"
# Output:
# Current number: 1
# Current number: 2
# Current number: 3
# Final my_var value: 16 (10 + 1 + 2 + 3)
```

Blocks read and write the caller's local variables directly, no `nonlocal`-style declaration needed. That's what makes `File.open(path) { |f| ... }` work: the method controls setup and teardown, the block supplies the logic in between.

When you need to store a block as a value and pass it around rather than yield to it once, that's what `Proc` and `Lambda` are for. Lambdas differ from plain procs in two ways: they check argument count strictly, and `return` inside a lambda returns from the lambda, not from the enclosing method.

```ruby
def create_ruby_counter()
  count = 0 # Variable in the outer scope
  # Return a Proc object (a block converted to an object)
  Proc.new do
    count += 1
    count
  end
end

counter_a = create_ruby_counter()
counter_b = create_ruby_counter()

puts "Counter A first call: #{counter_a.call}" # Output: Counter A first call: 1
puts "Counter A second call: #{counter_a.call}" # Output: Counter A second call: 2
puts "Counter B first call: #{counter_b.call}" # Output: Counter B first call: 1
```

-----

### PHP: closures and generators

PHP closures need the `use` keyword to pull outer variables into scope, and by default that's a copy taken when the closure is defined. Prefix the variable with `&` in the `use` clause to capture by reference instead, which is what lets the counter below actually increment across calls.

```php
<?php
function createCounter() {
    $count = 0; // Variable in the enclosing scope

    return function () use (&$count) { // Use '&' for reference to modify outer variable
        $count++;
        return $count;
    };
}

$counter1 = createCounter();
$counter2 = createCounter();

echo "Counter 1 first call: " . $counter1() . "\n"; // Output: Counter 1 first call: 1
echo "Counter 1 second call: " . $counter1() . "\n"; // Output: Counter 1 second call: 2
echo "Counter 2 first call: " . $counter2() . "\n"; // Output: Counter 2 first call: 1
?>
```

PHP's generators, like Python's, use `yield` to produce values without holding the whole sequence in memory, which matters for anything reading a large file or a big database result set line by line.

```php
<?php
function read_large_file($file_path) {
    if (!$file_handle = fopen($file_path, 'r')) {
        return; // Or throw an exception
    }
    while (!feof($file_handle)) {
        yield trim(fgets($file_handle)); // Yield one line at a time
    }
    fclose($file_handle);
}

// Process line by line without loading the entire file into memory
foreach (read_large_file('large_data.txt') as $line) {
    if (!empty($line)) {
        // Do heavy processing here
        break; // Process only the first line for example
    }
}
?>
```

-----

### Rust: ownership-aware closures and zero-cost iterators

Rust closures capture their environment according to how they use it: by reference, by mutable reference, or by taking ownership with `move`. The compiler infers which one applies based on what's inside the closure body, and the `Fn` / `FnMut` / `FnOnce` traits describe the difference to anything that accepts a closure as a parameter.

```rust
fn create_incrementer() -> impl FnMut() -> i32 {
    let mut count = 0; // Outer variable

    // FnMut means the closure can mutate its captured environment
    move || { // 'move' keyword ensures 'count' is moved into the closure
        count += 1;
        count
    }
}

let mut counter1 = create_incrementer();
let mut counter2 = create_incrementer();

println!("Counter 1 first call: {}", counter1()); // Output: Counter 1 first call: 1
println!("Counter 1 second call: {}", counter1()); // Output: Counter 1 second call: 2
println!("Counter 2 first call: {}", counter2()); // Output: Counter 2 first call: 1
```

Rust has no `yield` keyword. Instead you implement the `Iterator` trait directly, with a `next` method returning `Some(value)` or `None`. The payoff for the extra ceremony is that the compiler optimizes the whole chain, so `.map().filter().take()` often compiles down to the same code as a hand-written loop.

```rust
struct Fibonacci {
    current: u32,
    next: u32,
}

impl Iterator for Fibonacci {
    type Item = u32;

    fn next(&mut self) -> Option<Self::Item> {
        let current = self.current;
        self.current = self.next;
        self.next = current + self.next;
        // Limit to prevent overflow for demonstration
        if current > 1000 {
            None // Stop iteration
        } else {
            Some(current)
        }
    }
}

// Function to create a new Fibonacci iterator
fn fibonacci() -> Fibonacci {
    Fibonacci { current: 0, next: 1 }
}

let mut fib_iter = fibonacci();
println!("Rust First value: {:?}", fib_iter.next()); // Output: Rust First value: Some(0)
println!("Rust Second value: {:?}", fib_iter.next()); // Output: Rust Second value: Some(1)
println!("Rust Third value: {:?}", fib_iter.next());  // Output: Rust Third value: Some(1)

// Using a for loop to consume the iterator
for num in fibonacci().take(10) { // take(10) limits to 10 items
    print!("{} ", num); // Output: 0 1 1 2 3 5 8 13 21 34
}
println!();
```

-----

### Go: closures and concurrency instead of generators

Go closures work like JavaScript's: a function literal captures variables from its surrounding scope by reference.

```go
package main

import "fmt"

func createCounter() func() int {
	count := 0 // Variable in the enclosing scope

	return func() int { // This anonymous function is the closure
		count++
		return count
	}
}

func main() {
	counter1 := createCounter()
	counter2 := createCounter()

	fmt.Printf("Counter 1 first call: %d\n", counter1())  // Output: Counter 1 first call: 1
	fmt.Printf("Counter 1 second call: %d\n", counter1()) // Output: Counter 1 second call: 2
	fmt.Printf("Counter 2 first call: %d\n", counter2())  // Output: Counter 2 first call: 1
}
```

Go has no `yield` either, but it doesn't need one to get lazy sequences: goroutines and channels do the job directly. The generator runs as its own goroutine and blocks on a channel send until the consumer is ready for the next value.

```go
package main

import "fmt"
import "sync" // For sync.WaitGroup to wait for the goroutine to finish

// fibonacciGenerator sends Fibonacci numbers to a channel
func fibonacciGenerator(limit int) (<-chan int, *sync.WaitGroup) {
	ch := make(chan int) // Channel for sending numbers
	var wg sync.WaitGroup
	wg.Add(1) // Add one goroutine to wait for

	go func() { // Start a new goroutine
		defer wg.Done() // Signal that this goroutine is done when it exits
		defer close(ch) // Close the channel when done to signal no more values

		a, b := 0, 1
		count := 0
		fmt.Printf("Go Generator (Goroutine) initialized with limit: %d\n", limit)
		for count < limit {
			ch <- a // Send 'a' to the channel (pauses if receiver not ready)
			a, b = b, a+b
			count++
		}
		fmt.Println("Go Fibonacci sequence finished!")
	}()
	return ch, &wg // Return the receive-only channel and the WaitGroup
}

func main() {
	fibChan, wg := fibonacciGenerator(5)

	fmt.Printf("Go First value: %d\n", <-fibChan)  // Output: Go Generator... \n Go First value: 0
	fmt.Printf("Go Second value: %d\n", <-fibChan) // Output: Go Second value: 1
	fmt.Printf("Go Third value: %d\n", <-fibChan)   // Output: Go Third value: 1

	// Continue consuming until the channel is closed
	for num := range fibChan {
		fmt.Printf("Go Next value: %d\n", num)
	}
	wg.Wait() // Wait for the generator goroutine to complete
}
```

The pattern generalizes to any producer/consumer relationship, not just sequences, which is why it's idiomatic Go rather than a workaround for a missing feature.

-----

### Side by side

| Feature | Python | JavaScript | Ruby | PHP | Rust | Go |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Core concept** | Functions remembering outer scope; pausable generators | Functions remembering lexical scope; pausable generators | Anonymous code passed to methods; access to defining scope | Anonymous functions with `use`; pausable generators | Closures that borrow/move; trait-based iterators | Closures; concurrency primitives standing in for iterators |
| **Mutating outer vars** | `nonlocal` required | Directly mutable | Directly mutable by default | `use (&$var)` for reference | `move`, or a mutable borrow (`&mut`) | Directly mutable (captured by reference) |
| **Lazy sequence mechanism** | `yield` | `yield` (`function*`) | `yield` inside the yielding method, or `Enumerator` | `yield` | `Iterator` trait, `next` returns `Option<Item>` | Goroutine sending to a channel |
| **Closure syntax** | `def outer(): def inner(): nonlocal var` | `function outer() { return function() {...} }` | `Proc.new { ... }` / `lambda { ... }` | `function() use ($var) { ... }` | `move \|\| { ... }` or `\|var\| { ... }` | `func() { ... }` |

-----

None of this is really about which language wins. Python and JavaScript optimize for readability, letting `yield` and closures fall out of ordinary syntax. Rust makes you spell out capture and ownership because it refuses to leave those decisions to a garbage collector. Go skips generators as a concept entirely and reaches for concurrency instead, because concurrency is supposed to be the easy path in Go, not the advanced one. The mechanism that trips people up most when moving between these languages is Ruby's blocks: they look like closures, and mostly behave like them, but they aren't first-class values until you convert them into a `Proc`.
