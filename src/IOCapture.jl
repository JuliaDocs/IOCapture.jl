module IOCapture
using Logging

export iocapture

"""
    iocapture(f)

Runs the function `f` and captures the `stdout` and `stderr` outputs without printing them
in the terminal. Returns an object with the following fields:

* `.error :: Bool`: set to `true` if `f` threw an error, `false` otherwise
* `.value :: Any`: return value of the function, or the error exception object on error
* `.output :: String`: captured `stdout` and `stderr`
* `.backtrace :: Vector`: array with the backtrace of the error if an error was thrown

# Extended help

`iocapture` works by temporarily redirecting the standard output and error streams
(`stdout` and `stderr`) using `redirect_stdout` and `redirect_stderr` to a temporary
buffer, evaluate the function `f` and then restores the streams.

Both the captured text output and the returned object get captured and returned. If `f`
throws an error, `.error` is set to `true`, `.value` is set to the exception object, and
`.backtrace` is populated with the `catch_backtrace` of the exception.

```jldoctest
julia> cap = iocapture() do
           println("test")
       end;

julia> cap.output
"test\\n"
```
"""
function iocapture(f)
    # Original implementation from Documenter.jl (MIT license)
    # Save the default output streams.
    default_stdout = stdout
    default_stderr = stderr

    # Redirect both the `stdout` and `stderr` streams to a single `Pipe` object.
    pipe = Pipe()
    Base.link_pipe!(pipe; reader_supports_async = true, writer_supports_async = true)
    redirect_stdout(pipe.in)
    redirect_stderr(pipe.in)
    # Also redirect logging stream to the same pipe
    logger = ConsoleLogger(pipe.in)

    # Bytes written to the `pipe` are captured in `output` and converted to a `String`.
    output = UInt8[]

    # Run the function `f`, capturing all output that it might have generated.
    # Success signals whether the function `f` did or did not throw an exception.
    result, success, backtrace = with_logger(logger) do
        try
            f(), true, Vector{Ptr{Cvoid}}()
        catch err
            # InterruptException should never happen during normal doc-testing
            # and not being able to abort the doc-build is annoying (#687).
            isa(err, InterruptException) && rethrow(err)
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
        error = !success,
        value = result,
        output = chomp(String(output)),
        backtrace = backtrace,
    )
end

end
