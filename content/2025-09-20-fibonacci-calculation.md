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
Elixir, explore optimizations which can be done and explore how native code can
help us in order to compute even faster. The main objective of the article is to
compute the largest Fibonacci number as fast as possible.

### Start with the Math \!

Most powerful algorithms out there rely on a quite simple math principle.

$$ Fn = F\_{n-1} + F\_{n-2} $$

This principle means that if you know the 2 previous terms of the series you can
compute the next one. So the Fibonacci series is recursive because in the
definition of the series appears the series itself.

### Math is not real life.

Based on the math we have seen before we can think this algorithm:

``` elixir

  def fib(0), do: 0
  def fib(1), do: 1

  def fib(n) do
    fib(n - 1) + fib(n - 2)
  end
```

Let me tell you why this is a terrible idea. This algorithm is super slow,
because it does extra computations which are already computed and it does not store
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

As you can see from this example, the complexity of this algorithm grows exponentially $O(2^n)$.
Notice that we are doing multiple times the same computation $F_{n-2}$ or $F_{n-3}$.

### Improving naive solution.

One improvement we can do to the solution is to apply [Dynamic
programming](https://en.wikipedia.org/wiki/Dynamic_programming). We can optimize
the algorithm by doing memoization, so the complexity can be reduced a lot.

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

This is the same algorithm as before, but we cache the results in an [ETS
table](https://hexdocs.pm/elixir/main/ets.html), so if we have an already
computed result, we do not need to recompute it all.

We can do a simple benchmark between this implementation with memoization and
the other one with not, so it demonstrates how powerful is this technique.

```
##### With input 1 #####
Name                                        ips        average  deviation         median         99th %
Elixir O(2^n) Algorithm                 16.64 M       60.09 ns ±42065.44%          45 ns          69 ns
Elixir O(2^n) Algorithm Memo             1.16 M      864.46 ns  ±5353.57%         792 ns        1150 ns

Comparison:
Elixir O(2^n) Algorithm                 16.64 M
Elixir O(2^n) Algorithm Memo             1.16 M - 14.39x slower +804.37 ns

##### With input 20 #####
Name                                        ips        average  deviation         median         99th %
Elixir O(2^n) Algorithm Memo             1.51 M        0.66 μs  ±9240.96%        0.54 μs        0.88 μs
Elixir O(2^n) Algorithm                0.0102 M       98.09 μs    ±55.81%       96.94 μs      105.33 μs

Comparison:
Elixir O(2^n) Algorithm Memo             1.51 M
Elixir O(2^n) Algorithm                0.0102 M - 148.28x slower +97.43 μs

##### With input 45 #####
Name                                        ips        average  deviation         median         99th %
Elixir O(2^n) Algorithm Memo             1.48 M      0.00000 s  ±8725.95%      0.00000 s      0.00000 s
Elixir O(2^n) Algorithm               0.00000 M        16.21 s     ±0.13%        16.21 s        16.22 s

Comparison:
Elixir O(2^n) Algorithm Memo             1.48 M
Elixir O(2^n) Algorithm               0.00000 M - 24065479.81x slower +16.21 s
```

{% mermaid() %}

---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#D278AA, #7C6D91'
---
xychart
    title "Benchmark Memo vs No Memo"
    x-axis "Algorithm" [ "O(2^N) input 45", "Memo input 45", "O(2^N) input 20", "Memo input 20" ]
    y-axis "Time in microseconds" 1 --> 200
    bar [1622000, -1000000, 105.33, -1000000 ]
    bar [-1000000, 1.150, -1000000, 0.88]

{% end %}

For each input we flush the memoization cache, because it will be unfair if we
leave it, since it will not compute every N at least once.

### Sometimes improving is not enough.

Dynamic programming implementation is pretty fast, but it is not enough. We can
get a better implementation if we rethink the naive approach to make it
$O(n)$.

One trick we can do is to store the previous 2 numbers as parameters of the recursion so this way, we dont need to compute all the other results each time.

```elixir
  def fib(0), do: 0
  def fib(1), do: 1

  def fib(n), do: fib(n, 0, 1)

  defp fib(1, _a, b), do: b

  defp fib(n, a, b), do: fib(n - 1, b, a + b)
```

This implementation still uses the same mathematical principle, but it does less iterations, and it uses way more less storage since it just needs to store the 2 previous fibonacci numbers.

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


### What about another math approach ?

There is another mathematical formula called [Binet's formula](https://en.wikipedia.org/wiki/Fibonacci_sequence#Closed-form_expression).

$$ Fn = \\frac{\\phi^{n} - (-\\phi^{-n})} {\\sqrt{5}} $$

This principle allow us to calculate any number of the sequence by just knowing
the value of $\\phi$ constant.

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

This implementation is in fact $O(1)$ or $O(log n)$, depends on the complexity of `:math.pow` function. What is the tradeoff ? This implementation is an approximation so you will be stacking error. Notice that one divided the square root of 5 is calculated with the [quake 3 algorithm](https://www.youtube.com/watch?v=p8u_k2LIZyo&pp=ygUgcXVha2UgMyBmYXN0IGludmVyc2Ugc3F1YXJlIHJvb3Q%3D), another alternative would be to hardcode this constant in the algorithm.

### The end ?

So... Is this the end ?

NO, because you should know that Elixir runs in the Erlang VM which probably has some overhead
while calculating. We can try to make an Erlang `NIF` (__Native Implementation Function__), to see if it is faster than just standard Elixir.

To do so, we can take a look to `rustler`, which is fantastic `crate`/elixir library.

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

and for the $\phi$ based algorithm,

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

Lets talk about the Rust implementation of Fibonacci, as you can see is $O(N)$ and notice we are just using 2 variables instead of 3, this is because an arithmetic operation should be faster than storing in a CPU register. Also notice that Rust forces us to put types and,
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

It seems everything is correct, for `100`, but things are getting weird for `200`.
What the hell the same algorithm gives different result ?

The answer is called overflow. Since Rust is working with limited size integers it overflows for big numbers.

Why Elixir does not have this problem ? It is because Elixir integers are dynamically sized. It creates a little bit of overhead because you must do allocations to fit the integer, but it allows you to have an "infinite" integer. I recommend this read [Learning Elixir: Understanding Numbers](https://dev.to/abreujp/understanding-numbers-in-elixir-na5), in order to have a better understanding of what Elixir is doing.

Then I wondered, What if I can make the same Elixir behaviour in Rust ?

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

As you can see nothing really changes, now we are using the big integer which are resizable,
and allow us to store massive integers.

Lets try with this implementation and see if it gives the same result as Elixir one.

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
        "Elixir O(2^n) Algorithm Memo" => &dp_slow_fib/1,
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
      parallel: 2,
      after_scenario: fn _input ->
        if :ets.whereis(:fibs) != :undefined do
          :ets.delete(:fibs)
        end
      end
    )
    nil
  end
```

Before you look the results you need to consider that Rust expanding nums implementation was run with the dirty scheduler in Erlang, without it is still the worst, because of the overhead it has, but not so much worse around 33x slower. Also consider invalid $\Phi$ formula implementations for the `input >= 71` or `input >= 75`, because they start to not give a precise value after that.

As you can see here the result for input 71 is correct for 72 is not, as well in the $\phi$ elixir implementation.

``` elixir
### Input 71
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

### Input 75
iex(12)> FibRustElixir.phi_formula(75)
2111485077978050
iex(13)> TurboFibonacci.fib(75)
2111485077978050

### Input 76
iex(14)> FibRustElixir.phi_formula(76)
3416454622906708
iex(15)> TurboFibonacci.fib(76)
3416454622906707
```

Here are the results for the benchmark low inputs.

```
##### With input 1 #####
Name                                         ips        average  deviation         median         99th %
Elixir O(N) Algorithm                    16.38 M       61.07 ns ±45774.27%          44 ns          71 ns
Rust O(1) Algorithm Phi formula           9.15 M      109.26 ns  ±4221.28%         100 ns         210 ns
Rust O(N) Algorithm                       8.26 M      121.09 ns ±23343.76%         100 ns         203 ns
Elixir O(1) Algorithm Phi formula         3.31 M      302.31 ns   ±136.52%         260 ns         531 ns
Elixir O(2^n) Algorithm Memo              1.19 M      838.18 ns  ±5624.56%         787 ns        1101 ns
Rust O(N) Algorithm expanding nums       0.188 M     5308.94 ns    ±84.14%        4395 ns    16176.06 ns

Comparison:
Elixir O(N) Algorithm                    16.38 M
Rust O(1) Algorithm Phi formula           9.15 M - 1.79x slower +48.19 ns
Rust O(N) Algorithm                       8.26 M - 1.98x slower +60.03 ns
Elixir O(1) Algorithm Phi formula         3.31 M - 4.95x slower +241.25 ns
Elixir O(2^n) Algorithm Memo              1.19 M - 13.73x slower +777.11 ns
Rust O(N) Algorithm expanding nums       0.188 M - 86.93x slower +5247.87 ns

##### With input 100 #####
Name                                         ips        average  deviation         median         99th %
Rust O(1) Algorithm Phi formula           8.09 M      123.63 ns   ±263.70%         113 ns         195 ns
Rust O(N) Algorithm                       4.63 M      215.80 ns   ±356.51%         198 ns         419 ns
Elixir O(1) Algorithm Phi formula         3.15 M      317.82 ns   ±209.58%         277 ns         615 ns
Elixir O(2^n) Algorithm Memo              1.45 M      687.71 ns  ±8165.87%         587 ns         924 ns
Elixir O(N) Algorithm                     0.66 M     1517.15 ns  ±2172.62%        1380 ns        1928 ns
Rust O(N) Algorithm expanding nums      0.0784 M    12753.08 ns    ±55.31%       13905 ns       24389 ns

Comparison:
Rust O(1) Algorithm Phi formula           8.09 M
Rust O(N) Algorithm                       4.63 M - 1.75x slower +92.17 ns
Elixir O(1) Algorithm Phi formula         3.15 M - 2.57x slower +194.18 ns
Elixir O(2^n) Algorithm Memo              1.45 M - 5.56x slower +564.08 ns
Elixir O(N) Algorithm                     0.66 M - 12.27x slower +1393.51 ns
Rust O(N) Algorithm expanding nums      0.0784 M - 103.15x slower +12629.45 ns

##### With input 71 #####
Name                                         ips        average  deviation         median         99th %
Rust O(1) Algorithm Phi formula           7.75 M      128.97 ns  ±4535.63%         117 ns         230 ns
Rust O(N) Algorithm                       6.54 M      152.88 ns ±19215.97%         123 ns         224 ns
Elixir O(1) Algorithm Phi formula         3.40 M      294.01 ns   ±339.67%         258 ns         533 ns
Elixir O(2^n) Algorithm Memo              1.43 M      700.42 ns  ±9294.91%         581 ns         904 ns
Elixir O(N) Algorithm                     1.15 M      869.80 ns   ±184.80%         853 ns        1259 ns
Rust O(N) Algorithm expanding nums      0.0940 M    10633.12 ns    ±73.98%       10948 ns       20597 ns

Comparison:
Rust O(1) Algorithm Phi formula           7.75 M
Rust O(N) Algorithm                       6.54 M - 1.19x slower +23.91 ns
Elixir O(1) Algorithm Phi formula         3.40 M - 2.28x slower +165.04 ns
Elixir O(2^n) Algorithm Memo              1.43 M - 5.43x slower +571.45 ns
Elixir O(N) Algorithm                     1.15 M - 6.74x slower +740.83 ns
Rust O(N) Algorithm expanding nums      0.0940 M - 82.44x slower +10504.15 ns
```

{% mermaid() %}

---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#B7410E, #7C6D91'
---
xychart
    title "Low numbers benchmark input 1"
    x-axis "Algorithm" ["Rust Phi", "Elixir Phi", "Rust O(N)", "Elixir O(N)", "Elixir O(2^N) Memo" ]
    y-axis "Time in nanoseconds" 1 --> 1200
    bar [210, -1000, 203 ,-1000, -1000]
    bar [-1000, 531, -1000 , 71, 1101]


{% end %}

{% mermaid() %}

---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#B7410E, #7C6D91'
---
xychart
    title "Low numbers benchmark input 71"
    x-axis "Algorithm" ["Rust Phi", "Elixir Phi", "Rust O(N)", "Elixir O(N)", "Elixir O(2^N) Memo" ]
    y-axis "Time in nanoseconds" 1 --> 1300
    bar [230, -1000, 224 ,-1000, -1000]
    bar [-1000, 533, -1000 , 1259, 904]

{% end %}

{% mermaid() %}

---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#B7410E, #7C6D91'
---
xychart
    title "Low numbers benchmark input 100"
    x-axis "Algorithm" ["Rust O(N)", "Elixir O(N)", "Elixir O(2^N) Memo" ]
    y-axis "Time in nanoseconds" 1 --> 2000
    bar [419,-1000, -1000]
    bar [-1000 , 1928, 924]

{% end %}

The conclusion we can make here is that for really small inputs Rust NIF is
worth it to use even if Elixir wins for input 1 because it is a clause in the
function almost without any overhead. $\Phi$ algorithm is not so fast for low
inputs so it is not worth to use. Notice that Rust expandable integers
implementation has a super big overhead which is not compensate with the small
input.

This is the setup I was doing for Big numbers,

As you can see here we have much bigger inputs, other functions cannot be included in
this benchmark because they will lose `precision`, they will take too much `time` or
they will take too much `memory`.

```elixir
  def bench_large_numbers() do
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

{% mermaid() %}

---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#B7410E, #7C6D91'
---
xychart
    title "Big numbers benchmark"
    x-axis "Algorithm and input" ["E(200k)", "R(200k)", "E(500k)", "R(500k)", "E(1M)", "R(1M)" ]
    y-axis "Time in seconds" 0 --> 15
    bar [-1, 0.33374, -1 , 2.25, -1, 11.24]
    bar [0.72812, -1, 4.43 ,-1, 12.54, -1]

{% end %}

{% mermaid() %}

---
config:
  themeVariables:
    xyChart:
      plotColorPalette: '#B7410E, #7C6D91'
---
xychart
    title "Big numbers benchmark (2 million)"
    x-axis "Algorithm and input" ["E(2M)", "R(2M)"]
    y-axis "Time in seconds" 1 --> 100
    bar [ -1 , 98.4 ]
    bar [42.6  ,-1 ]

{% end %}

This is really interesting result, since it seems Rust expanding nums it pays the overhead by winning Elixir to all the inputs except for 2 million, I believe why Elixir wins in 2 million input is because some sort of reallocation optimization which is not in Rust.

### Conclusion

For every peak performance algorithm you should analyze your inputs and make correct assumptions like `input <= 71`, so this way you benefit of the approximation algorithm. 

If your inputs are super large, consider using native code, instead of working in VM code.
It seems to pay off the Native code, in fact Elixir is kinda cheating because Erlang is probably calling some C code to compute this kinda numbers.

Benchmark! Always test your things with stress, load and speed benchmarking, this way you can ensure that your algorithm is gonna behave how you will expect.

Of course there is much more strategies here which I did not cover, like Multi-threading, dividing the work in chunks and so on...


Hopefully you liked the article, all the code of the article is available in [Github](https://github.com/pxp9/fibonacci_numbers)
