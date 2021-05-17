module GridapPETScTests

using Test

@time @testset "PETSC" begin include("PETSCTests.jl") end

@time @testset "PETScArrays" begin include("PETScArraysTests.jl") end

@time @testset "PETScSolvers" begin include("PETScSolversTests.jl") end

@time @testset "PoissonDriver" begin include("PoissonDriver.jl") end

end # module
