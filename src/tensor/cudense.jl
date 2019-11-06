const CuDense{ElT,VecT}                 = Dense{ElT,VecT} where {VecT<:CuVector}
const CuDenseTensor{ElT,N,StoreT,IndsT} = Tensor{ElT,N,StoreT,IndsT} where {StoreT<:CuDense}

Dense{T, SA}(x::Dense{T, SB}) where {T<:Number, SA<:CuArray, SB<:Array} = Dense{T, S}(CuArray(x))
Dense{T, SA}(x::Dense{T, SB}) where {T<:Number, SA<:Array, SB<:CuArray} = Dense{T, S}(collect(x.data))
Dense{T, S}(size::Integer) where {T, S<:CuArray{<:T}} = Dense{T, S}(CuArrays.zeros(T, size))
function Dense{T, S}(x::T, size::Integer) where {T, S<:CuArray{<:T}}
    arr = CuArray{T}(undef, size)
    fill!(arr, x)
    Dense{T, S}(arr)
end
Base.collect(x::CuDense{T}) where {T<:Number} = Dense(collect(x.data))

*(D::Dense{T, AT},x::S) where {T,AT<:CuArray,S<:Number} = Dense(x .* data(D))

Base.:(==)(::Type{<:CuDense{ElT1,CVec1}}, ::Type{<:CuDense{ElT2,CVec2}}) where {ElT1,ElT2,CVec1,CVec2} = (ElT1 == ElT2)
Base.getindex(D::CuDense)       = collect(data(D))[]
Base.getindex(D::CuDenseTensor) = store(D)[]
LinearAlgebra.norm(T::CuDenseTensor) = norm(data(store(T)))

#=function Base.promote_rule(::Type{<:CuDense{ElT1,CVec1}},
                           ::Type{<:CuDense{ElT2,CVec2}}) where {ElT1,ElT2,CVec1,CVec2}
  ElR  = promote_type(ElT1,ElT2)
  VecR = promote_type(CVec1, CVec2)
  return Dense{ElR,VecR}
end=#

# This is for type promotion for Scalar*Dense
function Base.promote_rule(::Type{<:Dense{ElT1,CuVector{ElT1}}},
                           ::Type{ElT2}) where {ElT1,
                                                ElT2<:Number}
  ElR  = promote_type(ElT1,ElT2)
  VecR = CuVector{ElR}
  return Dense{ElR,VecR}
end

function Base.permutedims(T::CuDenseTensor{<:Number,N},
                          perm::NTuple{N,Int}) where {N}
  Tp = similar(T,permute(inds(T),perm))
  permute!(Tp,T)
  return Tp
end

# GROSS
#=function permutedims!!(B::CuDenseTensor{ElT,0},
                       A::CuDenseTensor{ElT,N},
                       perm::NTuple{N,Int},
                       f=(r,t)->permute!(r,t)) where {N, ElT<:Number}
  Ais = inds(A)
  Cis = permute(inds(A), perm)
  Cs = f(B, A)
  return Tensor(Dense(vec(Cs)), Cis) 
end=#

function Base.permutedims!(B::CuDenseTensor{<:Number, N},
                           A::CuDenseTensor{<:Number, N},
                           perm,
                           f::Function) where {N} #(r,t)->permute!(r,t)) where {N}
  Ais = inds(A)
  Bis = permute(inds(A), perm)
  Cs  = f(B, A)
  return Tensor(Dense(vec(Cs)), Bis) 
end

#=function Base.permutedims!(B::BT,
                           A::AT,
                           perm::NTuple{N,Int},
                           f=(r,t)->permute!(r,t)) where {N, BT<:CuDenseTensor{<:Number, N}, AT<:CuDenseTensor{<:Number, N}}
  Ais = inds(A)
  Bis = permute(inds(A), perm)
  Cs  = f(B, A)
  return Tensor(Dense(vec(Cs)), Bis) 
end=#

function permutedims!!(B::CuDenseTensor{<:Number, N, <:CuDense},
                       A::CuDenseTensor{<:Number, N, <:CuDense},
                       perm::NTuple{N,Int},
                       f=(r,t)->permute!(r,t)) where {N}
  Ais = inds(A)
  Bis = permute(inds(A), perm)
  B = f(B, A)
  #B = Tensor(Dense(vec(Cs)), Bis)
  return B
  #return Tensor(Dense(vec(Cs)), Bis) 
end

function Base.permute!(B::CuDenseTensor, A::CuDenseTensor)
  Ais = inds(A)
  Bis = inds(B)
  ind_dict = Vector{Index}()
  for (idx, i) in enumerate(Ais)
      push!(ind_dict, i)
  end
  Adata = data(store(A))
  Bdata = data(store(B))
  reshapeBdata = reshape(Bdata,dims(Bis))
  reshapeAdata = reshape(Adata,dims(Ais))
  ctainds = zeros(Int, length(Ais))
  ctbinds = zeros(Int, length(Bis))
  for (ii, ia) in enumerate(Ais)
      ctainds[ii] = findfirst(x->x==ia, ind_dict)
  end
  for (ii, ib) in enumerate(Bis)
      ctbinds[ii] = findfirst(x->x==ib, ind_dict)
  end
  
  CuArrays.CUTENSOR.permutation!(one(eltype(Adata)), reshapeAdata, Vector{Char}(ctainds), reshapeBdata, Vector{Char}(ctbinds)) 
  copyto!(B.store.data, reshape(reshapeBdata, length(B.store.data)))
  return vec(reshapeBdata) 
end

function outer!(R::CuDenseTensor,
                T1::CuDenseTensor,
                T2::CuDenseTensor)
  R_dat = vec(array(T1))*transpose(vec(array(T2)))
  copyto!(data(store(R)), vec(R_dat)) 
  inds_outer = unioninds(inds(T1),inds(T2))
  return R
end

# TODO: call outer!!, make this generic
function outer(T1::CuDenseTensor{ElT1},
               T2::CuDenseTensor{ElT2}) where {ElT1,ElT2}
  array_outer = vec(array(T1))*transpose(vec(array(T2)))
  inds_outer = unioninds(inds(T1),inds(T2))
  return Tensor(Dense{promote_type(ElT1,ElT2)}(vec(array_outer)),inds_outer)
end

function contract!!(R::CuDenseTensor{<:Number,NR},
                    labelsR::NTuple{NR},
                    T1::CuDenseTensor{<:Number,N1},
                    labelsT1::NTuple{N1},
                    T2::CuDenseTensor{<:Number,N2},
                    labelsT2::NTuple{N2}) where {NR,N1,N2}
  if N1==0
    # TODO: replace with an add! function?
    # What about doing `R .= T1[] .* PermutedDimsArray(T2,perm)`?
    perm = getperm(labelsR,labelsT2)
    newT2 = Tensor(Dense(data(store(T1)).*data(store(T2))), inds(T2))
    permute!(R,newT2)
  elseif N2==0
    perm = getperm(labelsR,labelsT1)
    newT1 = Tensor(Dense(data(store(T2)).*data(store(T1))), inds(T1))
    permute!(R,newT1)
  elseif N1+N2==NR
    # TODO: permute T1 and T2 appropriately first (can be more efficient
    # then permuting the result of T1⊗T2)
    # TODO: implement the in-place version directly
    R = outer!!(R,T1,T2)
    inds_outer = unioninds(inds(T1),inds(T2))
    R = Tensor(store(R), inds_outer)
  else
    R = _contract!!(R,labelsR,T1,labelsT1,T2,labelsT2)
  end
  return R
end

function permutedims!!(B::CuDenseTensor{ElT,0},
                       A::CuDenseTensor{ElT,0},
                       perm::NTuple{0,Int},
                       f=(r,t)->permute!(r,t)) where {ElT<:Number}
  Cs = f(B, A)
  return Tensor(Dense(vec(Cs)), IndexSet{0}()) 
end

function permutedims!!(B::CuDenseTensor{ElT,N},
                       A::CuDenseTensor{ElT,0},
                       perm::NTuple{N,Int},
                       f=(r,t)->permute!(r,t)) where {N, ElT<:Number}
  Cis = permute(inds(B), perm)
  Cs = f(B, A)
  return Tensor(Dense(vec(Cs)), Cis) 
end

function _contract!(CT::CuDenseTensor{El,NC},
                    AT::CuDenseTensor{El,NA},
                    BT::CuDenseTensor{El,NB},
                    props::ContractionProperties) where {El,NC,NA,NB}
  Ainds = inds(AT)
  Adims = dims(Ainds)
  Binds = inds(BT)
  Bdims = dims(Binds)
  Cinds = inds(CT)
  Cdims = dims(Cinds)
  Adata = reshape(data(store(AT)),Adims)
  Bdata = reshape(data(store(BT)),Bdims)
  Cdata = reshape(data(store(CT)),Cdims)
  contracted = commoninds(Ainds, Binds)
  A_only = uniqueinds(Ainds, Binds)
  B_only = uniqueinds(Binds, Ainds)
  ind_dict = Vector{Index}()
  for (idx, i) in enumerate(contracted)
      push!(ind_dict, i)
  end
  if length(A_only) > 0
      for (idx, i) in enumerate(A_only)
          push!(ind_dict, i)
      end
  end
  if length(B_only) > 0
      for (idx, i) in enumerate(B_only)
          push!(ind_dict, i)
      end
  end
  ctainds = zeros(Int, length(Ainds))
  ctbinds = zeros(Int, length(Binds))
  ctcinds = zeros(Int, length(Cinds))
  for (ii, ia) in enumerate(Ainds)
      ctainds[ii] = findfirst(x->x==ia, ind_dict)
  end
  for (ii, ib) in enumerate(Binds)
      ctbinds[ii] = findfirst(x->x==ib, ind_dict)
  end
  for (ii, ic) in enumerate(Cinds)
      ctcinds[ii] = findfirst(x->x==ic, ind_dict)
  end
  
  id_op = CuArrays.CUTENSOR.CUTENSOR_OP_IDENTITY
  CuArrays.CUTENSOR.contraction!(one(El), Adata, Vector{Char}(ctainds), id_op, Bdata, Vector{Char}(ctbinds), id_op, zero(El), Cdata, Vector{Char}(ctcinds), id_op, id_op)
  copyto!(CT.store.data, vec(Cdata))
end

function Base.:+(B::CuDenseTensor, A::CuDenseTensor)
  opC  = CUTENSOR.CUTENSOR_OP_IDENTITY
  opA  = CUTENSOR.CUTENSOR_OP_IDENTITY
  opAC = CUTENSOR.CUTENSOR_OP_ADD
  Ais = inds(A)
  Bis = inds(B)
  ind_dict = Vector{Index}()
  for (idx, i) in enumerate(inds(A))
      push!(ind_dict, i)
  end
  Adata = data(store(A))
  Bdata = data(store(B))
  reshapeBdata = reshape(Bdata,dims(Bis))
  reshapeAdata = reshape(Adata,dims(Ais))
  ctainds = zeros(Int, length(Ais))
  ctbinds = zeros(Int, length(Bis))
  for (ii, ia) in enumerate(Ais)
      ctainds[ii] = findfirst(x->x==ia, ind_dict)
  end
  for (ii, ib) in enumerate(Bis)
      ctbinds[ii] = findfirst(x->x==ib, ind_dict)
  end
  ctcinds = copy(ctbinds)
  C = CuArrays.zeros(eltype(Bdata), dims(Bis))
  CUTENSOR.elementwiseBinary!(one(eltype(Adata)), reshapeAdata, ctainds, opA, one(eltype(Bdata)), reshapeBdata, ctbinds, opC, C, ctcinds, opAC)
  copyto!(data(store(B)), vec(C))
  return B
end

function Base.:+(B::CuDense, Bis::IndexSet, A::CuDense, Ais::IndexSet)
  opC  = CUTENSOR.CUTENSOR_OP_IDENTITY
  opAC = CUTENSOR.CUTENSOR_OP_ADD
  ind_dict = Vector{Index}()
  for (idx, i) in enumerate(inds(A))
      push!(ind_dict, i)
  end
  Adata = data(store(A))
  Bdata = data(store(B))
  reshapeBdata = reshape(Bdata,dims(Bis))
  reshapeAdata = reshape(Adata,dims(Ais))
  ctainds = zeros(Int, length(Ais))
  ctbinds = zeros(Int, length(Bis))
  for (ii, ia) in enumerate(Ais)
      ctainds[ii] = findfirst(x->x==ia, ind_dict)
  end
  for (ii, ib) in enumerate(Bis)
      ctbinds[ii] = findfirst(x->x==ib, ind_dict)
  end
  C = zeros(Bdata)
  Cis = Bis
  C = CUTENSOR.elementwiseBinary!(1, Adata, ctainds, opA, 1, Bdata, Binds, opC, C, Cis, opAC)
  return C
end

function Base.permute!(B::CuDenseTensor, A::CuDenseTensor)
  Ais = inds(A)
  Bis = inds(B)
  ind_dict = Vector{Index}()
  for (idx, i) in enumerate(Ais)
      push!(ind_dict, i)
  end
  Adata = data(store(A))
  Bdata = data(store(B))
  reshapeBdata = reshape(Bdata,dims(Bis))
  reshapeAdata = reshape(Adata,dims(Ais))
  ctainds = zeros(Int, length(Ais))
  ctbinds = zeros(Int, length(Bis))
  for (ii, ia) in enumerate(Ais)
      ctainds[ii] = findfirst(x->x==ia, ind_dict)
  end
  for (ii, ib) in enumerate(Bis)
      ctbinds[ii] = findfirst(x->x==ib, ind_dict)
  end
  
  CuArrays.CUTENSOR.permutation!(one(eltype(Adata)), reshapeAdata, Vector{Char}(ctainds), reshapeBdata, Vector{Char}(ctbinds)) 
  #copyto!(B.store.data, reshape(reshapeBdata, length(B.store.data)))
  return vec(reshapeBdata) 
end

function Base.permute!(B::CuDense, Bis::IndexSet, A::CuDense, Ais::IndexSet)
  ind_dict = Vector{Index}()
  for (idx, i) in enumerate(Ais)
      push!(ind_dict, i)
  end
  Adata = data(A)
  Bdata = data(B)
  reshapeBdata = reshape(Bdata,dims(Bis))
  reshapeAdata = reshape(Adata,dims(Ais))
  ctainds = zeros(Int, length(Ais))
  ctbinds = zeros(Int, length(Bis))
  for (ii, ia) in enumerate(Ais)
      ctainds[ii] = findfirst(x->x==ia, ind_dict)
  end
  for (ii, ib) in enumerate(Bis)
      ctbinds[ii] = findfirst(x->x==ib, ind_dict)
  end
  
  CuArrays.CUTENSOR.permutation!(one(eltype(Adata)), reshapeAdata, Vector{Char}(ctainds), reshapeBdata, Vector{Char}(ctbinds)) 
  #copyto!(B.store.data, reshape(reshapeBdata, length(B.store.data)))
  return vec(reshapeBdata) 
end
