# TODO: this distribution may need clean-up
"""
    PoissonBinomial(p)

A *Poisson-binomial distribution* describes the number of successes in a sequence of independent trials, wherein each trial has a different success rate.
It is parameterized by a vector `p` (of length ``K``), where ``K`` is the total number of trials and `p[i]` corresponds to the probability of success of the `i`th trial.

```math
P(X = k) = \\sum\\limits_{A\\in F_k} \\prod\\limits_{i\\in A} p[i] \\prod\\limits_{j\\in A^c} (1-p[j]), \\quad \\text{ for } k = 0,1,2,\\ldots,K,
```

where ``F_k`` is the set of all subsets of ``k`` integers that can be selected from ``\\{1,2,3,...,K\\}``.

```julia
PoissonBinomial(p)   # Poisson Binomial distribution with success rate vector p

params(d)            # Get the parameters, i.e. (p,)
succprob(d)          # Get the vector of success rates, i.e. p
failprob(d)          # Get the vector of failure rates, i.e. 1-p
```

External links:

* [Poisson-binomial distribution on Wikipedia](http://en.wikipedia.org/wiki/Poisson_binomial_distribution)

"""
struct PoissonBinomial{T<:Real} <: DiscreteUnivariateDistribution
    p::Vector{T}
    pmf::Vector{T}

    function PoissonBinomial{T}(p::AbstractArray) where {T <: Real}
        pb = poissonbinomial_pdf(p)
        @assert isprobvec(pb)
        new{T}(p, pb)
    end
end

function PoissonBinomial(p::AbstractArray{T}; check_args=true) where {T <: Real}
    if check_args
        for i in eachindex(p)
            @check_args(PoissonBinomial, 0 <= p[i] <= 1)
        end
    end
    return PoissonBinomial{T}(p)
end

@distr_support PoissonBinomial 0 length(d.p)

#### Conversions

function PoissonBinomial(::Type{PoissonBinomial{T}}, p::Vector{S}) where {T, S}
    return PoissonBinomial(Vector{T}(p))
end
function PoissonBinomial(::Type{PoissonBinomial{T}}, d::PoissonBinomial{S}) where {T, S}
    return PoissonBinomial(Vector{T}(d.p), check_args=false)
end

#### Parameters

ntrials(d::PoissonBinomial) = length(d.p)
succprob(d::PoissonBinomial) = d.p
failprob(d::PoissonBinomial{T}) where {T} = one(T) .- d.p

params(d::PoissonBinomial) = (d.p,)
partype(::PoissonBinomial{T}) where {T} = T

#### Properties

mean(d::PoissonBinomial) = sum(succprob(d))
var(d::PoissonBinomial) = sum(succprob(d) .* failprob(d))

function skewness(d::PoissonBinomial{T}) where {T}
    v = zero(T)
    s = zero(T)
    p,  = params(d)
    for i in eachindex(p)
        v += p[i] * (one(T) - p[i])
        s += p[i] * (one(T) - p[i]) * (one(T) - T(2) * p[i])
    end
    return s / sqrt(v) / v
end

function kurtosis(d::PoissonBinomial{T}) where {T}
    v = zero(T)
    s = zero(T)
    p,  = params(d)
    for i in eachindex(p)
        v += p[i] * (one(T) - p[i])
        s += p[i] * (one(T) - p[i]) * (one(T) - T(6) * (one(T) - p[i]) * p[i])
    end
    s / v / v
end

entropy(d::PoissonBinomial) = entropy(Categorical(d.pmf))
median(d::PoissonBinomial) = median(Categorical(d.pmf)) - 1
mode(d::PoissonBinomial) = argmax(d.pmf) - 1
modes(d::PoissonBinomial) = [x  - 1 for x in modes(Categorical(d.pmf))]

#### Evaluation

quantile(d::PoissonBinomial, x::Float64) = quantile(Categorical(d.pmf), x) - 1

function mgf(d::PoissonBinomial{T}, t::Real) where {T}
    p,  = params(d)
    prod(one(T) .- p .+ p .* exp(t))
end

function cf(d::PoissonBinomial{T}, t::Real) where {T}
    p,  = params(d)
    prod(one(T) .- p .+ p .* cis(t))
end

pdf(d::PoissonBinomial, k::Real) = insupport(d, k) ? d.pmf[k+1] : zero(eltype(d.pmf))
logpdf(d::PoissonBinomial, k::Real) = log(pdf(d, k))

# Computes the pdf of a poisson-binomial random variable using
# simple, fast recursive formula
#
#      Marlin A. Thomas & Audrey E. Taub (1982) 
#      Calculating binomial probabilities when the trial probabilities are unequal, 
#      Journal of Statistical Computation and Simulation, 14:2, 125-131, DOI: 10.1080/00949658208810534 
#
function poissonbinomial_pdf(p::AbstractArray{T,1}) where {T <: Real}
  n = length(p)
  S = zeros(T, n+1)
  S[1] = 1-p[1]
  S[2] = p[1]
  @inbounds for col in 2:n
    for r in 1:col
        row = col - r + 1 
        S[row+1] = (1-p[col])*S[row+1] + p[col] * S[row]
    end
    S[1] *= 1-p[col]
  end
  return S
end

#### Sampling

sampler(d::PoissonBinomial) = PoissBinAliasSampler(d)
