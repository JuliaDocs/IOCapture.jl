module IOCapture
using Logging

export iocapture

"""
    iocapture(f; throwerrors=Any, color=false)

Runs the function `f` and captures the `stdout` and `stderr` outputs without printing them
in the terminal. Returns an object with the following fields:

* `.value :: Any`: return value of the function, or the error exception object on error
* `.output :: String`: captured `stdout` and `stderr`
* `.error :: Bool`: set to `true` if `f` threw an error, `false` otherwise
* `.backtrace :: Vector`: array with the backtrace of the error if an error was thrown

The behaviour can be customized with the following keyword arguments:

* `throwerrors`:

  When set to `Any` (default), `iocapture` will rethrow any exceptions thrown
  by evaluating `f`. Setting it to `true` has the same effect as `Any`.

  To throw on a subset of possible exceptions pass the exception type instead,
  such as `InterruptException`. If multiple exception types may need to be
  thrown then pass a `Union{...}` of the types. Passing `:interrupt` has the
  same effect as using `InterruptException`.

  Setting it to `Union{}` will capture all thrown exceptions and return them
  via the `.value` field, and will also set `.error` and `.backtrace`
  accordingly. Setting it to `false` also has this effect.

* `color`: if set to `true`, `iocapture` inherits the `:color` property of `stdout` and
  `stderr`, which specifies whether ANSI color/escape codes are expected. This argument is
  only effective on Julia v1.6 and later.

# Extended help

`iocapture` works by temporarily redirecting the standard output and error streams
(`stdout` and `stderr`) using `redirect_stdout` and `redirect_stderr` to a temporary
buffer, evaluate the function `f` and then restores the streams. Both the captured text
output and the returned object get captured and returned:

```jldoctest
julia> cap = iocapture() do
           println("test")
       end;

julia> cap.output
"test\\n"
```

This approach does have some limitations -- see the README for more information.

**Exceptions.** Normally, if `f` throws an exception, `iocapture` simply re-throws it with
`rethrow`. However, by setting `throwerrors` to `false`, it is also possible to capture
errors, which then get returned via the `.value` field. Additionally, `.error` is set to
`true`, to indicate that the function did not run normally, and the `catch_backtrace` of the
exception is returned via `.backtrace`.

As mentioned above, it is also possible to set `throwerrors` to
`InterruptException` or `:interrupt`. This will make `iocapture` rethrow only
`InterruptException`s. This is useful when you want to capture all the
exceptions, but allow the user to interrupt the running code with `Ctrl+C`.
"""
function iocapture(f; throwerrors=Any, color::Bool=false)
    # `throwerrors` is set to one of `true`, `false`, `:interrupt`, or a
    # subtype of `ErrorException`, or a `Union` of error subtypes. Here we
    # convert the first three choices to types instead, as:
    #
    #   - `true` -> `Any`,
    #   - `false` -> `Union{}`,
    #   - `:interrupt` -> `InterruptException`.
    throwerrors = rewrite_error_argument(throwerrors)

    # Original implementation from Documenter.jl (MIT license)
    # Save the default output streams.
    default_stdout = stdout
    default_stderr = stderr

    # Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    @static if VERSION >= v"1.6.0-DEV.481" # https://github.com/JuliaLang/julia/pull/36688
        pe_stdout = IOContext(pipe.in, :color => get(stdout, :color, false) & color)
        pe_stderr = IOContext(pipe.in, :color => get(stderr, :color, false) & color)
    else
        pe_stdout = pipe.in
        pe_stderr = pipe.in
    end
    redirect_stdout(pe_stdout)
    redirect_stderr(pe_stderr)
    # Also redirect logging stream to the same pipe
    logger = ConsoleLogger(pe_stderr)

    # Bytes written to the `pipe` are captured in `output` and converted to a `String`.
    output = UInt8[]

    # Run the function `f`, capturing all output that it might have generated.
    # Success signals whether the function `f` did or did not throw an exception.
    result, success, backtrace = with_logger(logger) do
        try
            f(), true, Vector{Ptr{Cvoid}}()
        catch err
            err isa throwerrors && rethrow(err)
            # If we're capturing the error, we return the error object as the value.
            err, false, catch_backtrace()
        finally
            # Force at least a single write to `pipe`, otherwise `readavailable` blocks.
            println()
            # Restore the original output streams.
            redirect_stdout(default_stdout)
            redirect_stderr(default_stderr)
            # NOTE: `close` must always be called *after* `readavailable`.
            append!(output, readavailable(pipe))
            close(pipe)
        end
    end
    (
        value = result,
        output = chomp(String(output)),
        error = !success,
        backtrace = backtrace,
    )
end

rewrite_error_argument(T::Type) = T
rewrite_error_argument(arg::Bool) = arg ? Any : Union{}
rewrite_error_argument(arg) = arg === :interrupt ? InterruptException :
    throw(DomainError(arg, "Invalid value passed for throwerrors"))

end
