+++
title = "Fibonacci calculation at peak performance"
date = "2025-09-20"
description = "A fast way to calculate Fibonacci Nth term"
draft = false
[taxonomies]
tags = ["elixir", "rust"]
[extra]
cover.image = "images/2025-09-20_fibonacci_speed.png"
cover.alt = "A Markdown logo"
math = true
mermaid = true
+++



## Idea

The idea of this article is to explore the Fibonacci sequence algorithms in
Elixir, explore how `rustler` and Rust can help us in order to compute even
faster. The main objective of the article is to compute the largest Fibonacci
number as fast as possible.

### Start with the Math \!

Most powerful algorithms out there rely on a quite simple math principle.

In our case we can see these 2 formulas for the computation of the Nth Fibonacci
number.

$$ Fn = F\_{n-1} + F\_{n-2} $$

This principle means that if you know the 2 previous terms of the series you can
compute the next one. So the Fibonacci series is recursive because in the
definition of the series appears the series itself.

$$ Fn = \\frac{\\phi^{n} - (-\\phi^{-n})} {\\sqrt{5}} $$

This principle allow us to calculate any number of the sequence by just knowing
the value of $\\phi$ constant.

### Math is not real life.

Based on the math we have seen before you can think that this algoritm.

``` elixir

  def fib(0), do: 0
  def fib(1), do: 1

  def fib(n) do
    fib(n - 1) + fib(n - 2)
  end
```

Let me tell you why this is a terrible idea. This algorithm is super slow,
beacuse it does extra computations which are already computed and does not store
any result.

{% mermaid() %}

    flowchart TB;
    root["$$F_{n}$$"]
    f1["$$F_{n-1}$$"]
    f2["$$F_{n-2}$$"]
    f11["$$F_{n-2}$$"]
    f12["$$F_{n-3}$$"]
    f21["$$F_{n-3}$$"]
    f22["$$F_{n-4}$$"]
    root-->f1;
    root-->f2;
    f1-->f11;
    f1-->f12;
    f2-->f21;
    f2-->f22;

{% end %}

As you can see the complexity of this algorithm grows exponentially $O(2^n)$.

### Improving naive solution.

One improvement we can do to the most obvious solution is to apply [Dynamic
programming](https://en.wikipedia.org/wiki/Dynamic_programming). We can optimize
the algorithm by doing memoization, so the complexity so be reduced a lot.

``` elixir
  def fib(n) do
    if :ets.whereis(:fibs) == :undefined do
      :ets.new(:fibs, [:named_table, read_concurrency: true])
    end

    do_fib(n)
  end

  defp do_fib(0) do
    :ets.insert(:fibs, {0, 0})

    0
  end

  defp do_fib(1) do
    :ets.insert(:fibs, {1, 1})

    1
  end

  defp do_fib(n) do
    result = :ets.lookup(:fibs, n)

    if result == [] do
      val = do_fib(n - 1) + do_fib(n - 2)
      :ets.insert(:fibs, {n, val})
      val
    else
      [{_n, val}] = result
      val
    end
  end

```

This is the same algorithm as before but we cache the results in an [ETS
table](https://hexdocs.pm/elixir/main/ets.html), so if we have an already
computed result we dont need to recompute it all.

### Sometimes improving is not enough.

Dynamic programming implementation is pretty fast but it is not enough, we can
get a better implementation just if we rethink the naive approach to make it
$O(n)$.

One trick we can do is to store the previous 2 numbers as parameters of the recursion so this way, we dont need to compute all the other results each time.

```elixir
  def fib(0), do: 0
  def fib(1), do: 1

  def fib(n), do: fib(n, 0, 1)

  defp fib(1, _a, b), do: b

  defp fib(n, a, b), do: fib(n - 1, b, a + b)
```

This implementation still uses the same mathematical principle, but it does less iterations and it uses way more less storage since it just needs to store the 2 previous fibonacci numbers.

{% mermaid() %}

    flowchart LR;
    root["$$F_{n}$$"]
    f1["$$F_{n-1}$$"]
    f2["$$F_{n-2}$$"]
    f0["$$F_{0}$$"]
    f01["$$F_{1}$$"]
    root-->f1;
    f1-->f2;
    f2-->f01;
    f01-->f0;
{% end %}


### What about the other math approach ?

Remember that by knowing the $\phi$ constant we can compute the Nth Fibonacci, here is the implementation.

```elixir
  def phi_formula(n),
    do: round((:math.pow(@phi, n) - :math.pow(-@phi, -n)) * fast_inverse_square_root(5.0))

  defp fast_inverse_square_root(number) do
    x2 = number * 0.5
    <<i::integer-size(64)>> = <<number::float-size(64)>>
    <<y::float-size(64)>> = <<0x5FE6EB50C7B537A9 - (i >>> 1)::integer-size(64)>>
    y = y * (1.5 - x2 * y * y)
    y = y * (1.5 - x2 * y * y)
    y = y * (1.5 - x2 * y * y)
    y
  end

```

This implementation is in fact $O(1)$ or $O(log n)$, depends on the complexity of `:math.pow` function. What is the tradeoff ? This implementation is an approximation so you will be stacking more error. Notice that one divided the square root of 5 is calculated with the quake 3 algorithm, another alternative would be to hardcode this constant in the algorithm.

### The end ?

So this is the end ?

NO, because you should know that Elixir runs in the Erlang VM which probably has some overhead
while calculating the stuff. We can try to make an Erlang `NIF` (__Native Implementation Function__), to see if it is faster than just standard Elixir.

To do so, you can take a look to `rustler`, which is fantastic `crate`/elixir library.

This is the code we will be using in Rust,


```rust
#[rustler::nif]
fn fib(n: u128) -> u128 {
    let mut a = 0;
    let mut b = 1;
    let mut i = 1;

    while i < n {
        b = a + b;
        a = b - a;
        i += 1;
    }

    b
}
```

and for the for the $\phi$ based algorithm,

```rust
const PHI: f64 = 1.618033988749895;

fn inv_sqrt(x: f64) -> f64 {
    let i = x.to_bits();
    let x2 = x * 0.5;
    let mut y = f64::from_bits(0x5FE6EB50C7B537A9 - (i >> 1));
    y = y * (1.5 - x2 * y * y);
    y = y * (1.5 - x2 * y * y);
    y * (1.5 - x2 * y * y)
}

#[rustler::nif]
fn phi_formula(n: i32) -> f64 {
    ((PHI.powi(n) - (-PHI).powi(-n)) * inv_sqrt(5.0)).ceil()
}
```

Of course the `phi_formula` implementation has the same issue as the elixir one since it is an approximation, it should not be super precise at large scale.

Lets talk about the Rust implementation of Fib, as you can see is $O(N)$ and notice we are just using 2 variables instead of 3, this is because an arithmetic operation should be faster than storing in a CPU register. Also notice that Rust forces us to put types and,
we are using `u128`, so this way we can compute and store really big integer.

### Wait something weird is happening

When I was testing the code for this article, I realized that sometimes Rust implementation was not consistant with the Elixir one, especially at large scale.

```elixir
## Elixir impl with 100 input
iex(1)> FibRustElixir.fib(100)
354224848179261915075

## Rust impl with 100 input
iex(2)> TurboFibonacci.fib(100)
354224848179261915075

## Elixir impl with 200 input
iex(3)> FibRustElixir.fib(200)
280571172992510140037611932413038677189525

## Rust impl with 200 input
iex(4)> TurboFibonacci.fib(200)
178502649656846143791255889261670949781
```

It seems everything is correct, for `100`, but things are getting weird for `200`, what the hell the same algorithm gives different result ?


The answer is called overflow. Since Rust is working with limited size integers it overflows for big numbers.

Why Elixir does not have this problem ? It is because Elixir integers are dynamically sized. It creates a little bit of overhead because you must do allocations to fit the integer, but it allows you to have an "infinite" integer. I recommend this read [Learning Elixir: Understanding Numbers](https://dev.to/abreujp/understanding-numbers-in-elixir-na5), in order to have better understanding of what Elixir is doing.

then I wondered, What if I can make the same Elixir behaviour in Rust ?

Thankfully, there are already super smart people in the Rust ecosystem that thought about
this problem, and I observed that there was already a `crate` for this `num_bigint`.

Another thing, one of the guys who did `rustler`, thought about this problem and
he integrated `rustler` with `num_bigint`, so this way you can have a translation layer with these kind of integers in Rust. Take a look the [Encoder impl for BigInt](https://docs.rs/rustler/latest/rustler/struct.BigInt.html#impl-Encoder-for-BigInt), this is the translation layer for Rust `BigInt` to Elixir `term` which is an `integer`.

Lets take a look to the implementation with `BigInt`

```rust
#[rustler::nif]
fn fib_bignums(n: u128) -> BigInt {
    let mut a = BigUint::zero();
    let mut b = BigUint::one();
    let mut i = 1;

    while i < n {
        b = &a + &b;
        a = &b - &a;
        i += 1;
    }

    BigInt::from_biguint(Sign::Plus, b)
}
```

As you can see nothing really changes, now we are using the big integer which is resizable,
and allow us to store massive integers.

Lets try with this implementation and see if gives the same result as Elixir one.

```elixir
## Elixir with input 200
iex(3)> FibRustElixir.fib(200)
280571172992510140037611932413038677189525

## Rust `u128` with input 200
iex(4)> TurboFibonacci.fib(200)
178502649656846143791255889261670949781

## Rust resizable integers with input 200
iex(5)> TurboFibonacci.fib_bignums(200)
280571172992510140037611932413038677189525
```

YES! It works! Now we can compute and store massive Fibonacci calculations.

### Theory pretty cool, but show me the numbers.

Ok ok, now is the moment you were waiting for! The benchmarks and see if the theory is confirmed.

The benchmark library I will be using is [Benchee](https://github.com/bencheeorg/benchee), this library allow me to compare and obtain stats for each implementation
and different inputs.

I would like to explain I have divided the benchmarking in 2. Relative small inputs,
less than `100`, and really big inputs from `200_000`.

These are the specs of my system

```
Operating System: Linux
CPU Information: 13th Gen Intel(R) Core(TM) i5-1335U
Number of Available Cores: 12
Available memory: 15.30 GB
Elixir 1.18.4
Erlang 27.3.4.3
JIT enabled: true
```

This is the setup for low inputs.

```elixir
  def bench() do
    Benchee.run(
      %{
        "Elixir O(N) Algorithm" => &fib/1,
        "Elixir O(1) Algorithm Phi formula" => &phi_formula/1,
        "Rust O(1) Algorithm Phi formula" => &TurboFibonacci.phi_formula/1,
        "Rust O(N) Algorithm" => &TurboFibonacci.fib/1,
        "Rust O(N) Algorithm expanding nums" =>
          &TurboFibonacci.fib_bignums/1
      },
      inputs: %{
        "1" => 1,
        "71" => 71,
        "100" => 100
      },
      parallel: 2
    )
    nil
  end
```

Before you look the results you need to consider that Rust expanding nums implementation was run with the dirty scheduler in Erlang, without it is still the worst, because of the overhead it has, but not so much worse around 33x slower. Also consider invalid $\Phi$ formula implementations for the `input >= 71`, because they start to not give a precise value after that.

As you can see here the result for input 71 is correct for 72 is not.

``` elixir
### Input 71
iex(1)> FibRustElixir.phi_formula(71)
308061521170129

iex(2)> TurboFibonacci.phi_formula(71)
308061521170129.0

iex(3)> TurboFibonacci.fib(71)
308061521170129

### Input 72
iex(4)> TurboFibonacci.phi_formula(72)
498454011879263.0

iex(5)> FibRustElixir.phi_formula(72)
498454011879264

iex(6)> TurboFibonacci.fib(72)
498454011879264
```

Here are the results for the benchmark low inputs.

```
##### With input 1 #####
Name                                         ips        average  deviation         median         99th %
Elixir O(N) Algorithm                    25.08 M       39.87 ns ±71735.16%          26 ns          53 ns
Rust O(1) Algorithm Phi formula          14.81 M       67.54 ns  ±2031.19%          57 ns         136 ns
Rust O(N) Algorithm                      11.56 M       86.50 ns ±35806.92%          67 ns         141 ns
Elixir O(1) Algorithm Phi formula         5.23 M      191.06 ns   ±185.20%         152 ns        1240 ns
Rust O(N) Algorithm expanding nums        0.36 M     2803.13 ns    ±95.38%        2526 ns        7607 ns

Comparison:
Elixir O(N) Algorithm                    25.08 M
Rust O(1) Algorithm Phi formula          14.81 M - 1.69x slower +27.67 ns
Rust O(N) Algorithm                      11.56 M - 2.17x slower +46.63 ns
Elixir O(1) Algorithm Phi formula         5.23 M - 4.79x slower +151.19 ns
Rust O(N) Algorithm expanding nums        0.36 M - 70.31x slower +2763.26 ns

##### With input 100 #####
Name                                         ips        average  deviation         median         99th %
Rust O(1) Algorithm Phi formula          13.02 M       76.80 ns  ±1894.27%          68 ns         135 ns
Rust O(N) Algorithm                       7.19 M      139.00 ns   ±282.57%         127 ns         282 ns
Elixir O(1) Algorithm Phi formula         4.78 M      209.15 ns   ±250.74%         161 ns        1281 ns
Elixir O(N) Algorithm                     1.13 M      885.56 ns  ±2259.49%         793 ns        1880 ns
Rust O(N) Algorithm expanding nums       0.125 M     7982.54 ns   ±154.43%        8692 ns       12798 ns

Comparison:
Rust O(1) Algorithm Phi formula          13.02 M
Rust O(N) Algorithm                       7.19 M - 1.81x slower +62.20 ns
Elixir O(1) Algorithm Phi formula         4.78 M - 2.72x slower +132.35 ns
Elixir O(N) Algorithm                     1.13 M - 11.53x slower +808.76 ns
Rust O(N) Algorithm expanding nums       0.125 M - 103.94x slower +7905.74 ns

##### With input 71 #####
Name                                         ips        average  deviation         median         99th %
Rust O(1) Algorithm Phi formula          12.24 M       81.68 ns  ±1200.41%          72 ns         153 ns
Rust O(N) Algorithm                       9.60 M      104.17 ns ±28917.74%          81 ns         179 ns
Elixir O(1) Algorithm Phi formula         5.29 M      189.02 ns   ±486.11%         151 ns        1267 ns
Elixir O(N) Algorithm                     1.90 M      527.35 ns  ±4269.74%         494 ns         761 ns
Rust O(N) Algorithm expanding nums       0.156 M     6429.73 ns    ±70.38%        6674 ns       11008 ns

Comparison:
Rust O(1) Algorithm Phi formula          12.24 M
Rust O(N) Algorithm                       9.60 M - 1.28x slower +22.49 ns
Elixir O(1) Algorithm Phi formula         5.29 M - 2.31x slower +107.34 ns
Elixir O(N) Algorithm                     1.90 M - 6.46x slower +445.67 ns
Rust O(N) Algorithm expanding nums       0.156 M - 78.72x slower +6348.05 ns
```

The conclusion we can make here is that for really small inputs Rust NIF is worth it to use even if Elixir wins for input 1 because it is a clause in the function almost without any overhead. $\Phi$ algorithm is not so fast for low inputs so it is not worth to use.
Notice that Rust expandable integers implementation has a super big overhead which is not compensate with the big input. 

This is the setup I was doing for Big numbers,

As you can see here we have much bigger inputs, which probably the other functions will die on precision or die on time.

```elixir
  def bench_large_shit() do
    Benchee.run(
      %{
        "Elixir O(N) Algorithm" => &fib/1,
        "Rust O(N) Algorithm expanding nums" =>
        &TurboFibonacci.fib_bignums/1
      },
      inputs: %{
        "200_000" => 200_000,
        "500_000" => 500_000,
        "1 Million" => 1_000_000,
        "2 Million" => 2_000_000,
      },
      parallel: 2
    )
  end
```

These are the results for the big numbers benchmark.

```
##### With input 1 Million #####
Name                                         ips        average  deviation         median         99th %
Rust O(N) Algorithm expanding nums        0.0890        11.23 s     ±0.09%        11.23 s        11.24 s
Elixir O(N) Algorithm                     0.0798        12.54 s     ±0.00%        12.54 s        12.54 s

Comparison:
Rust O(N) Algorithm expanding nums        0.0890
Elixir O(N) Algorithm                     0.0798 - 1.12x slower +1.30 s

##### With input 2 Million #####
Name                                         ips        average  deviation         median         99th %
Elixir O(N) Algorithm                     0.0238       0.70 min     ±2.11%       0.70 min       0.71 min
Rust O(N) Algorithm expanding nums        0.0101       1.64 min     ±0.01%       1.64 min       1.64 min

Comparison:
Elixir O(N) Algorithm                     0.0238
Rust O(N) Algorithm expanding nums        0.0101 - 2.35x slower +0.94 min

##### With input 200_000 #####
Name                                         ips        average  deviation         median         99th %
Rust O(N) Algorithm expanding nums          3.04      328.71 ms     ±0.56%      328.21 ms      333.74 ms
Elixir O(N) Algorithm                       1.50      668.81 ms     ±5.29%      659.64 ms      728.12 ms

Comparison:
Rust O(N) Algorithm expanding nums          3.04
Elixir O(N) Algorithm                       1.50 - 2.03x slower +340.10 ms

##### With input 500_000 #####
Name                                         ips        average  deviation         median         99th %
Rust O(N) Algorithm expanding nums          0.44         2.25 s     ±0.14%         2.25 s         2.25 s
Elixir O(N) Algorithm                       0.23         4.33 s     ±2.59%         4.33 s         4.43 s

Comparison:
Rust O(N) Algorithm expanding nums          0.44
Elixir O(N) Algorithm                       0.23 - 1.93x slower +2.09 s
```

This is really interesting result, since it seems Rust expanding nums it pays the overhead by winning Elixir to all the inputs except for 2 million, I believe why Elixir wins in 2 million input is because some sort of reallocation optimization which is not in Rust.

### Conclusion

For every peak performance algorithm you should analyze your inputs and make correct assumptions like `input <= 71`, so this way you benefit of the approximation algorithm. 

If your inputs are super large, consider using native code, instead of working in VM code.
It seems to pay off the Native code, in fact Elixir is kinda cheating because Erlang is probably calling some C code to compute this kinda numbers.

Benchmark! Always test your things with stress, load and speed benchmarking, this way you can ensure that your algorithm is gonna behave how you will expect.

Of course there is much more strategies here which I did not cover, like Multi-threading, dividing the work in chunks and so on...


Hopefully you liked the article, all the code of the article is available in [Github](https://github.com/pxp9/fibonacci_numbers)
