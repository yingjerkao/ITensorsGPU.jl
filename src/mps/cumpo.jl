function cuMPO(O::MPO)
    P = copy(O)
    for site in 1:length(O)
        P.A_[site] = cuITensor(O.A_[site])
    end
    return P 
end
cuMPO() = MPO()
  
cuMPO(N::Int, A::Vector{ITensor}) = cuMPO(MPO(N, A))
cuMPO(sites) = cuMPO(MPO(sites))
function plussers(::Type{T}, left_ind::Index, right_ind::Index, sum_ind::Index) where {T <: CuArray}
    #if dir(left_ind) == dir(right_ind) == Neither
        total_dim    = dim(left_ind) + dim(right_ind)
        total_dim    = max(total_dim, 1)
        left_data   = CuArrays.zeros(Float64, dim(left_ind), dim(sum_ind))
        ldi = diagind(left_data, 0)
        left_data[ldi] = 1.0
        left_tensor = cuITensor(vec(left_data), left_ind, sum_ind)
        right_data   = CuArrays.zeros(Float64, dim(right_ind), dim(sum_ind))
        rdi = diagind(right_data, dim(left_ind))
        right_data[rdi] = 1.0
        right_tensor = cuITensor(vec(right_data), right_ind, sum_ind)
        return left_tensor, right_tensor
    #else # tensors have QNs
    #    throw(ArgumentError("support for adding MPOs with defined quantum numbers not implemented yet."))
    #end
end

function randomCuMPO(sites, m::Int=1)
  M = cuMPO(sites)
  for i ∈ eachindex(sites)
    randn!(M[i])
    normalize!(M[i])
  end
  m > 1 && throw(ArgumentError("randomMPO: currently only m==1 supported"))
  return M
end

function Base.collect(M::T) where {T <: Union{MPS, MPO}}
    if typeof(tensor(tensors(M)[1])) <: CuDenseTensor
        return T(length(M), collect.(tensors(M)), M.llim_, M.rlim_)    
    else
        return M
    end
end