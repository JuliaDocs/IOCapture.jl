using IOCapture
using Test

# hasfield was added in Julia 1.2. This definition borrowed from Compat.jl (MIT)
# Note: this can not be inside the testset
(VERSION < v"1.2.0-DEV.272") && (hasfield(::Type{T}, name::Symbol) where T = Base.fieldindex(T, name, false) > 0)

# Callable object for testing
struct Foo
    x
end
(foo::Foo)() = println(foo.x)

@testset "IOCapture.jl" begin
    # Capturing standard output
    c = iocapture() do
        println("test")
    end
    @test !c.error
    @test c.output == "test\n"
    @test c.value === nothing
    @test c.backtrace isa Vector
    @test isempty(c.backtrace)

    # Capturing standard error
    c = iocapture() do
        println(stderr, "test")
    end
    @test !c.error
    @test c.output == "test\n"
    @test c.value === nothing
    @test c.backtrace isa Vector
    @test isempty(c.backtrace)

    # Return values
    c = iocapture() do
        println("test")
        return 42
    end
    @test !c.error
    @test c.output == "test\n"
    @test c.value === 42
    @test c.backtrace isa Vector
    @test isempty(c.backtrace)

    c = iocapture() do
        println("test")
        println(stderr, "test")
        return rand(5,5)
    end
    @test !c.error
    @test c.output == "test\ntest\n"
    @test c.value isa Matrix{Float64}
    @test c.backtrace isa Vector
    @test isempty(c.backtrace)

    # Callable objects
    c = iocapture(Foo("callable test"))
    @test !c.error
    @test c.output == "callable test\n"
    @test c.value === nothing

    # Colors get discarded
    c = iocapture() do
        printstyled("foo", color=:red)
    end
    @test !c.error
    @test c.output == "foo"
    @test c.value === nothing

    # This test checks that deprecation warnings are captured correctly
    c = iocapture() do
        println("println")
        @info "@info"
        f() = (Base.depwarn("depwarn", :f); nothing)
        f()
    end
    @test !c.error
    @test c.value === nothing
    # The output is dependent on whether the user is running tests with deprecation
    # warnings enabled or not. To figure out whether that is the case or not, we can
    # look at the .depwarn field of the undocumented Base.JLOptions object.
    @test isdefined(Base, :JLOptions)
    @test hasfield(Base.JLOptions, :depwarn)
    if Base.JLOptions().depwarn == 0 # --depwarn=no, default on Julia >= 1.5
        @test c.output == "println\n[ Info: @info\n"
    else # --depwarn=yes
        @test startswith(c.output, "println\n[ Info: @info\n┌ Warning: depwarn\n")
    end

    # Exceptions -- normally rethrown
    @test_throws ErrorException iocapture() do
        println("test")
        error("error")
        return 42
    end

    # .. but can be controlled with throwerrors
    c = iocapture(throwerrors=false) do
        println("test")
        error("error")
        return 42
    end
    @test c.error
    @test c.output == "test\n"
    @test c.value isa ErrorException
    @test c.value.msg == "error"

    c = iocapture(throwerrors=false) do
        error("error")
        println("test")
        return 42
    end
    @test c.error
    @test c.output == ""
    @test c.value isa ErrorException
    @test c.value.msg == "error"

    # .. including interrupts
    c = iocapture(throwerrors=false) do
        println("test")
        throw(InterruptException())
        return 42
    end
    @test c.error
    @test c.output == "test\n"
    @test c.value isa InterruptException

    # .. unless it's throwerrors = :interrupt
    @test_throws InterruptException iocapture(throwerrors=:interrupt) do
        println("test")
        throw(InterruptException())
        return 42
    end
end
