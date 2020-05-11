using ITensors,
      ITensorsGPU,
      LinearAlgebra, # For tr()
      Combinatorics, # For permutations()
      CuArrays,
      Test

      # gpu tests!
@testset "cuITensor, Dense{$SType} storage" for SType ∈ (Float64, ComplexF64)
  mi,mj,mk,ml,ma = 2,3,4,5,6,7
  i = Index(mi,"i")
  j = Index(mj,"j")
  k = Index(mk,"k")
  l = Index(ml,"l")
  a = Index(ma,"a") 
  @testset "Test add CuDense" begin
    A  = [SType(1.0) for ii in 1:dim(i), jj in 1:dim(j)]
    dA = ITensorsGPU.CuDense{SType, CuVector{SType}}(SType(1.0), dim(i)*dim(j))
    B  = [SType(2.0) for ii in 1:dim(i), jj in 1:dim(j)]
    dB = ITensorsGPU.CuDense{SType, CuVector{SType}}(SType(2.0), dim(i)*dim(j))
    dC = +(dA, IndexSet(i, j), dB, IndexSet(j, i))
    hC = collect(dC)
    @test collect(A + B) ≈ hC
  end 
  #=@testset "Test CuDense outer" begin
    A  = CuArray(rand(SType, dim(i)*dim(j)))
    B  = CuArray(rand(SType, dim(k)*dim(l)))
    dA = ITensorsGPU.CuDense{SType, CuVector{SType}}(A)
    dB = ITensorsGPU.CuDense{SType, CuVector{SType}}(B)
    dC = NDTensors.outer(dA, dB)
    hC = collect(CuArray(dC))
    @test A * B' ≈ hC
  end=# 
  if SType == Float64
      @testset "Test CuDense complex" begin
        A  = CuArrays.rand(SType, dim(i)*dim(j))
        dA = ITensorsGPU.CuDense{SType, CuVector{SType}}(A)
        dC = complex(dA)
        @test typeof(dC) !== typeof(dA)
        hC = collect(CuArray(dC))
        @test hC == complex.(A)
      end 
  end 
end # End Dense storage test