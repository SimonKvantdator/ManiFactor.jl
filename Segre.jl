# Seg(P^n1 x ... P^nd) ~ R+ x S^(n1 - 1) x ... x S^(nd - 1)
struct
    Segre{V, 𝔽} <: AbstractManifold{𝔽}
end

function Segre(#={{{=#
    valence::NTuple{D, Int};
    field::AbstractNumbers=ℝ
    ) where {D}

    return Segre{valence, field}()
end#=}}}=#


###### FUNCTIONS ON Seg ######

valence(::Segre{V, 𝔽}) where {V, 𝔽} = V
ndims(::Segre{V, 𝔽}) where {V, 𝔽} = length(V)

function check_point(#={{{=#
    M::Segre{valence, 𝔽},
    p::Vector{Vector{Float64}};
    kwargs...
    ) where {valence, 𝔽}

    @assert(length.(p) == [1, valence...])
    @assert(p[1][1] > 0.0)
    for (x, n) in zip(p[2:end], valence)
        # check_point does not raise a DomainErorr, but returns it...
        e = check_point(Sphere(n - 1), x; kwargs...)
        if !isnothing(e)
            return e
        end
    end
    
    return nothing
end#=}}}=#

function check_vector(#={{{=#
    M::Segre{valence, 𝔽},
    p::Vector{Vector{Float64}},
    v::Vector{Vector{Float64}};
    kwargs...
    ) where {valence, 𝔽}

    e = check_point(M, p, kwargs...)
    if !isnothing(e)
        return e
    end

    @assert(size.(v) == size.(p))
    for (x, xdot, n) in zip(p[2:end], v[2:end], valence)
        # check_vector(::AbstractSphere, ...) uses isapprox to compare the dot product to 0, which by default sets atol=0...
        e = check_vector(Sphere(n - 1), x, xdot; atol=1e-14, kwargs...)
        if !isnothing(e)
            return e
        end
    end
    
    return nothing
end#=}}}=#

function to_tucker(M::Segre)::Tucker#={{{=#
    # TODO
end#=}}}=#

# TODO
# function dot(#={{{=#
#     M::Segre{valence, F},
#     p::Vector{Vector{Float64}},
#     u::Vector{Vector{Float64}},
#     v::Vector{Vector{Float64}}
#     ) where {valence, F}

#     # TODO
# end#=}}}=#

function norm(#={{{=#
    M::Segre{valence, F},
    p::Vector{Vector{Float64}},
    v::Vector{Vector{Float64}}
    ) where {valence, F}

    return sqrt(
        (v[1][1])^2 +
        sum([(p[1][1])^2 * norm(Sphere(n), x, xdot)^2
            for (x, xdot, n) in zip(p[2:end], v[2:end], valence)])
        )
end#=}}}=#

function rand(#={{{=#
    M::Segre{valence, F};
    vector_at=nothing,
    )::Vector{Vector{Float64}} where {valence, F}

    if isnothing(vector_at)
        xs = [normalize(rand(n)) for n in valence]
        return [abs.(rand(1)), xs...]
    else
        xdots = [normalize(rand(n)) for n in valence]
        xdots = map(t -> t[2] - dot(t[2], t[1]) * t[1], zip(vector_at[2:end], xdots))
        return [rand(1), xdots...]
    end
end#=}}}=#

# Embed p ∈ Segre((n1, ..., nd), F) in F^{n1 x ... x nd}
function embed(#={{{=#
    M::Segre{valence, F},
    p::Vector{Vector{Float64}}
    ) where {valence, F}

    return kronecker(p...)[:, 1]
end#=}}}=#

function embed_vector(#={{{=#
    M::Segre{valence, F},
    p::Vector{Vector{Float64}},
    v::Vector{Vector{Float64}},
    ) where {valence, F}

    # Product rule
    s = zeros.(prod(length.(p)))
    for (i, xdot) in enumerate(v)
        p_ = deepcopy(p)
        p_[i] = xdot
        term = kronecker(p_...)[:, 1]
        s = s + term
    end
    return s
end#=}}}=#

# Theorem 1.1 in Swijsen21
function exp(# {{{
    M::Segre{valence, F},
    p::Vector{Vector{Float64}},
    v::Vector{Vector{Float64}}
    )::Vector{Vector{Float64}} where {valence, F}

    m = sqrt(sum([norm(Sphere(n), p_i, v_i)^2 for (n, p_i, v_i) in zip(valence, p[2:end], v[2:end])]))
    if m == 0.0
        q = deepcopy(p) # Initialize
        q[1] = q[1] .+ v[1]
        return q
    end

    t = norm(M, p, v)
    P = v[1][1] / (p[1][1] * m)
    f = atan(sqrt(P^2 + 1.0) * t / p[1][1] + P) - atan(P)

    q = zeros.(size.(p)) # Initialize
    q[1][1] = sqrt(
        t^2 +
        2 * p[1][1] * P * t / sqrt(P^2 + 1.0) +
        p[1][1]^2# / (P^2 + 1.0) # TODO: This is wrong in Swijsen21 on arxiv
        )

    for i in range(2, ndims(M) + 1)
        if all(v[i] .== 0.0)
            q[i] = deepcopy(p[i])
        else
            n = valence[i - 1]
            S = Sphere(n)
            a = norm(S, p[i], v[i]) * f / m
            q[i] = p[i] * cos(a) .+ v[i] * sin(a) / norm(S, p[i], v[i])
        end
    end

    return q
end# }}}

# Theorem 6.2.1 in thesisLarsSwijsen
function log(# {{{
    M::Segre{valence, F},
    p::Vector{Vector{Float64}},
    q::Vector{Vector{Float64}}
    )::Vector{Vector{Float64}} where {valence, F}

    # Check for compatability
    rho_squared = sum([distance(Sphere(n), x, y)^2 for (n, x, y) in zip(valence, p[2:end], q[2:end])])
    @assert(rho_squared < pi^2)

    v = zeros.(size.(p)) # Initialize
    for i in range(2, ndims(M) + 1)
        if p[i] == q[i]
            v[i] = zeros(size(p[i]))
        else
            a = dot(p[i], q[i])
            v[i] = (q[i] .- a * p[i]) * acos(a) / sqrt(1.0 - a^2)
        end
    end

    m = sqrt(sum([norm(Sphere(n - 1), x, xdot)^2 for (n, x, xdot) in zip(valence, p[2:end], v[2:end])]))
    if m == 0.0
        v[1][1] = q[1][1] - p[1][1]
        return v
    end

    v[1][1] = m * p[1][1] * (q[1][1] * cos(m) - p[1][1]) / (q[1][1] * sin(m))

    t = (
            p[1][1] * tan(m + atan(v[1][1] / (p[1][1] * m))) - v[1][1] / m
        ) / (
            sqrt((v[1][1] / (p[1][1] * m))^2 + 1)
        )
    v = t * normalize(M, p, v)
    return v
end# }}}

function distance(# {{{
    M::Segre{valence, F},
    p::Vector{Vector{Float64}},
    q::Vector{Vector{Float64}}
    )::Float64 where {valence, F}

    # TODO: Write down the closed-form expression for the distance
    return norm(M, p, log(M, p, q))
end# }}}


###### TESTS ######


# TODO: run tests for d > 3 since that's where we have to start checking compatability
function test_segre(;verbose=false)#={{{=#
    nbr_tests = 5
    max_order = 3
    dimension_range = range(2, 7) # check_point not implemented for 0-spheres, which seems sane
    # TODO: test cases m = 0 and lambdadot = 0 also?

    println("########### Testing that exp maps into the manifold. ###########")
    for order in 1:max_order#={{{=#
        for _ in 1:nbr_tests
            valence = Tuple([rand(dimension_range) for _ in 1:order])
            M = Segre(valence)
            if verbose
                println("valence ", valence)
            end
        
            p = rand(M)
            if verbose
                println("p = ", map(y -> map((x -> round(x; digits=2)), y), p))
            end
        
            v = rand(M; vector_at=p)
            if verbose
                println("v = ", map(y -> map((x -> round(x; digits=2)), y), v))
                println()
            end
            
            e = check_point(M, p)
            if !isnothing(e); throw(e); end
            e = check_vector(M, p, v)
            if !isnothing(e); throw(e); end
            e = check_point(M, exp(M, p, v))
            if !isnothing(e); throw(e); end
        end
    end#=}}}=#

    println("############ Testing that geodesics are unit speed. ############")
    for order in 1:max_order#={{{=#
        for _ in 1:nbr_tests
            valence = Tuple([rand(dimension_range) for _ in 1:order])
            M = Segre(valence)
            if verbose
                println("valence ", valence)
            end
    
            p = rand(M)
            if verbose
                println("p = ", map(y -> map((x -> round(x; digits=2)), y), p))
            end
        
            v = normalize(M, p, rand(M, vector_at=p))
            if verbose
                println("v = ", map(y -> map((x -> round(x; digits=2)), y), v))
                println()
            end

            geodesic_speed = norm(
                finite_difference(
                    t -> embed(M, exp(M, p, t * v)),
                    rand(),
                    1e-6
                    )
                )
            @assert(isapprox(geodesic_speed, 1.0))
        end
    end#=}}}=#

    println("###### Testing that geodesics only have normal curvature. ######")
    for order in 1:max_order#={{{=#
        for _ in 1:nbr_tests
            valence = Tuple([rand(dimension_range) for _ in 1:order])
            M = Segre(valence)
            if verbose
                println("valence ", valence)
            end
        
            p = rand(M)
            if verbose
                println("p = ", map(y -> map((x -> round(x; digits=2)), y), p))
            end
        
            v = rand(M; vector_at=p)
            if verbose
                println("v = ", map(y -> map((x -> round(x; digits=2)), y), v))
                println()
            end
            
            gamma(t) = embed(M, exp(M, p, t * v))
            n = finite_difference(gamma, 0.0, 1e-6; order=2) # Normal curvature vector at p
            v_ = embed_vector(M, p, rand(M, vector_at=p)) # Random Tangent vector at p
            @assert(isapprox(dot(n, v_), 0.0, atol=1e-6))
        end
    end#=}}}=#

    println("########## Testing that log is a left inverse of exp. ##########")
    for order in 1:max_order#={{{=#
        for _ in 1:nbr_tests
            valence = Tuple([rand(dimension_range) for _ in 1:order])
            M = Segre(valence)
            if verbose
                println("valence ", valence)
            end
    
            p = rand(M)
            if verbose
                println("p = ", map(y -> map((x -> round(x; digits=2)), y), p))
            end
        
            v = rand(M, vector_at=p)
            if verbose
                println("v = ", map(y -> map((x -> round(x; digits=2)), y), v))
                println()
            end

            v_ = log(M, p, exp(M, p, v))
            @assert(isapprox(v, v_))
        end
    end#=}}}=#

    println("########## Testing that exp is a left inverse of log. ##########")
    for order in 1:max_order#={{{=#
        for _ in 1:nbr_tests
            valence = Tuple([rand(dimension_range) for _ in 1:order])
            M = Segre(valence)
            if verbose
                println("valence ", valence)
            end
    
            p = rand(M)
            q = rand(M)
            if verbose
                println("p = ", map(y -> map((x -> round(x; digits=2)), y), p))
                println("q = ", map(y -> map((x -> round(x; digits=2)), y), q))
                println()
            end

            q_ = exp(M, p, log(M, p, q))
            @assert(isapprox(q, q_))
        end
    end#=}}}=#

    # TODO: Test that these are equal?
    # println(norm(M, p, v))
    # println(norm(embed_vector(M, p, v)))
end#=}}}=#