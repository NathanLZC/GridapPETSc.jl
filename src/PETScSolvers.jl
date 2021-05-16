
struct PETScSolverNS <: NumericalSetup
  A::SparseMatrixCSR{0,PetscScalar,PetscInt}
  comm::MPI.Comm
  ksp::Ref{KSP}
  mat::Ref{Mat}
  rhs::Ref{Vec}
  sol::Ref{Vec}
end

struct PETScSolver{F} <: LinearSolver
  setup::F
  comm::MPI.Comm
  nss::Set{PETScSolverNS}
  function PETScSolver(setup::F,comm::MPI.Comm) where F
    nss = Set{PETScSolverNS}()
    new{F}(setup,comm,nss)
  end
end

function Finalize(a::PETScSolver)
  while length(a.nss)>0
    Finalize(pop!(a.nss))
  end
  nothing
end

from_options(ksp) = @check_error_code PETSC.KSPSetFromOptions(ksp[])

function PETScSolver(comm::MPI.Comm)
  PETScSolver(from_options,comm)
end

PETScSolver() = PETScSolver(MPI.COMM_WORLD)

PETScSolver(setup::Function) = PETScSolver(setup,MPI.COMM_WORLD)

struct PETScSolverSS{F} <: SymbolicSetup
  solver::PETScSolver{F}
end

function Algebra.symbolic_setup(solver::PETScSolver,mat::AbstractMatrix)
  PETScSolverSS(solver)
end

function PETScSolverNS(solver::PETScSolver,A::SparseMatrixCSR{0,PetscScalar,PetscInt})
  comm = solver.comm
  setup = solver.setup
  ksp = Ref{KSP}()
  mat = Ref{Mat}()
  rhs = Ref{Vec}()
  sol = Ref{Vec}()
  bs = 1
  nrows, ncols = size(A); i = A.rowptr; j = A.colval; a = A.nzval
  @check_error_code PETSC.KSPCreate(comm,ksp)
  setup(ksp)
  @check_error_code PETSC.VecCreateSeqWithArray(comm,bs,nrows,C_NULL,rhs)
  @check_error_code PETSC.VecCreateSeqWithArray(comm,bs,ncols,C_NULL,sol)
  @check_error_code PETSC.MatCreateSeqAIJWithArrays(comm,nrows,ncols,i,j,a,mat)
  ns = PETScSolverNS(A,comm,ksp,mat,rhs,sol)
  push!(solver.nss,ns)
  ns
end

function Finalize(ns::PETScSolverNS)
  @check_error_code PETSC.VecDestroy(ns.sol)
  @check_error_code PETSC.VecDestroy(ns.rhs)
  @check_error_code PETSC.MatDestroy(ns.mat)
  @check_error_code PETSC.KSPDestroy(ns.ksp)
  nothing
end

function Algebra.numerical_setup(
  ss::PETScSolverSS,A::SparseMatrixCSR{0,PetscScalar,PetscInt})
  ns = PETScSolverNS(ss.solver,A)
  @check_error_code PETSC.KSPSetOperators(ns.ksp[],ns.mat[],ns.mat[])
  @check_error_code PETSC.KSPSetUp(ns.ksp[])
  ns
end

function Algebra.solve!(x::Vector{PetscScalar},ns::PETScSolverNS,b::Vector{PetscScalar})
  @check_error_code PETSC.VecPlaceArray(ns.rhs[],b)
  @check_error_code PETSC.VecPlaceArray(ns.sol[],x)
  @check_error_code PETSC.KSPSolve(ns.ksp[],ns.rhs[],ns.sol[])
  @check_error_code PETSC.VecResetArray(ns.rhs[])
  @check_error_code PETSC.VecResetArray(ns.sol[])
  x
end

function Algebra.numerical_setup!(ns::PETScSolverNS,A::SparseMatrixCSR{0,PetscScalar,PetscInt})
  nrows, ncols = size(A); i = A.rowptr; j = A.colval; a = A.nzval
  @check_error_code PETSC.MatDestroy(ns.mat)
  @check_error_code PETSC.MatCreateSeqAIJWithArrays(ns.comm,nrows,ncols,i,j,a,ns.mat)
  @check_error_code PETSC.KSPSetOperators(ns.ksp[],ns.mat[],ns.mat[])
  @check_error_code PETSC.KSPSetUp(ns.ksp[])
  ns
end

# with conversions

function Algebra.numerical_setup(ss::PETScSolverSS,A::AbstractMatrix)
  _A = convert(SparseMatrixCSR{0,PetscScalar,PetscInt},A)
  numerical_setup(ss,_A)
end

function Algebra.solve!(x::AbstractVector,ns::PETScSolverNS,b::AbstractVector)
  _x = convert(Vector{PetscScalar},x)
  _b = convert(Vector{PetscScalar},b)
  solve!(_x,ns,_b)
  if x !== _x
    x.=_x
  end
  x
end

function Algebra.numerical_setup!(ns::PETScSolverNS,A::AbstractMatrix)
  _A = convert(SparseMatrixCSR{0,PetscScalar,PetscInt},A)
  numerical_setup!(ns,_A)
end
