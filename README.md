# IOCapture

Exports the `iocapture(f)` function which evaluates the function `f`, captures the standard
output and standard error, and returns it as a string, together with the return value. For
example:

```julia-repl
julia> cap = iocapture() do
           println("test")
           return 42
       end;

julia> cap.value, cap.output
(42, "test\n")
```

See the docstring for full documentation.

## Similar packages

* [Suppressor.jl](https://github.com/JuliaIO/Suppressor.jl) provides similar functionality,
  but with a macro-based interface.