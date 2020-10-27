module IOCapture
using Logging

export iocapture

"""
    iocapture(f; throwerrors=true, color=false)

Runs the function `f` and captures the `stdout` and `stderr` outputs without printing them
in the terminal. Returns an object with the following fields:

* `.value :: Any`: return value of the function, or the error exception object on error
* `.output :: String`: captured `stdout` and `stderr`
* `.error :: Bool`: set to `true` if `f` threw an error, `false` otherwise
* `.backtrace :: Vector`: array with the backtrace of the error if an error was thrown

The behaviour can be customized with the following keyword arguments:

* `throwerrors`: if set to `true` (default), `iocapture` will rethrow any exceptions thrown by
  `f`. If set to `false`, exceptions are also captured and the exception objects returned
  via the `.value` field (with also `.error` and `.backtrace` set accordingly). If set to
  `:interrupt`, only `InterruptException`s are rethrown.

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
errors, which then get returned as via the `.value` field. Additionally, `.error` is set to
`true`, to indicate that the function did not run normally, and the `catch_backtrace` of the
exception is returned via `.backtrace`.

It is also possible to set `throwerrors = :interrupt`, which will make `iocapture` rethrow
only `InterruptException`s. This is useful when you want to capture all the exceptions, but
allow the user to interrupt the running code with `Ctrl+C`.
"""
function iocapture(f; throwerrors::Union{Bool,Symbol}=true, color::Bool=false)
    # Currently, :interrupt is the only valid Symbol value for throwerrors
    if isa(throwerrors, Symbol) && throwerrors !== :interrupt
        throw(DomainError(throwerrors, "Invalid value passed for throwerrors"))
    end
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
            if (throwerrors === true) || (throwerrors === :interrupt && isa(err, InterruptException))
                # If throwerrors is set, we just rethrow all errors. Or, if it is set to
                # :interrupt, we rethrow only InterruptExceptions, which is useful when
                # capturing output, but still want to give the user the option to abort.
                rethrow(err)
            end
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

end
