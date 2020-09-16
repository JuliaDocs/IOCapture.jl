# IOCapture

[![Run tests](https://github.com/JuliaDocs/IOCapture.jl/workflows/CI/badge.svg)](https://github.com/JuliaDocs/IOCapture.jl/actions)
[![codecov](https://codecov.io/gh/JuliaDocs/IOCapture.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaDocs/IOCapture.jl)

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

## Known limitations

The capturing does not work properly if `f` prints to the `stdout` object that has been
stored in a separate variable or object, e.g.:

```julia-repl
julia> const original_stdout = stdout;

julia> c = iocapture() do
           println("output to stdout")
           println(original_stdout, "output to original stdout")
       end;
output to original stdout

julia> c.output
"output to stdout\n"
```

Relatedly, it is possible to run into errors if the `stdout` or `stderr` objects from
within an `iocapture` are being used in a subsequent `iocapture` or outside of the capture:

```julia-repl
julia> c = iocapture() do
           return stdout
       end;

julia> println(c.value, "test")
ERROR: IOError: stream is closed or unusable
Stacktrace:
 [1] check_open at ./stream.jl:328 [inlined]
 [2] uv_write_async(::Base.PipeEndpoint, ::Ptr{UInt8}, ::UInt64) at ./stream.jl:959
 ...
```

This is because `stdout` and `stderr` within an `iocapture` actually refer to the temporary
redirect streams which get cleaned up at the end of the `iocapture` call.

## Similar packages

* [Suppressor.jl](https://github.com/JuliaIO/Suppressor.jl) provides similar functionality,
  but with a macro-based interface.
