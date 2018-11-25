module Utils


## DATETIME

using TimeZones

mstodatetime(ms::Int) = Dates.DateTime(Dates.UTInstant(Dates.Millisecond(ms)))
daystodate(days::Int) = Dates.Date(Dates.UTInstant(Dates.Day(days)))
unixtime(seconds::Int) = DateTime(1970) + Dates.Second(seconds)
unixtimems(ms::Int) = DateTime(1970) + Dates.Millisecond(ms)

function tzconvert(datetime::DateTime,from::String,to::String)
    DateTime(astimezone(ZonedDateTime(datetime,TimeZone(from)),TimeZone(to)))
end

## CONTROL / OUTPUT

function lock_file(func::Function,fname::AbstractString;timeout=30)
    wait_begin = now()
    lock_fname = "$fname.lock"
    while isfile(lock_fname) && (now() - wait_begin) < Dates.Second(timeout)
        sleep(0.1)
    end
    if isfile(lock_fname)
        error("Unable to obtain lock on file \"$fname\"!")
    else
        open(lock_fname,"w") do f
            write(f,getpid())
        end
        func()

        isfile(lock_file) && rm(lock_fname)
    end
end

struct TimeoutException <: Exception
end

function timeout(expr,t::T) where {T<:Real}
    s = schedule(Task(expr))
    start_time = time()
    while (! istaskdone(s)) && (time() - start_time) < t
        sleep(0.1)
    end
    if ! istaskdone(s)
        s.state = :done
        throw(TimeoutException)
    end

    return yieldto(s)
end

# SIGNAL PROCESSING / STATS

z(p::AbstractArray{T,N}) where {T<:Real,N} = (p-mean(p))/std(p)

polyparams(x::AbstractArray{T,1},n::Integer) where {T<:Real} = [ float(x[i])^p for i = 1:length(x), p = 0:n ]
polyfit(y::AbstractArray{T,1},n::Integer) where {T<:Real} = polyparams(collect(1:length(y)),n) \ y
polyfitline(len::Integer,params::Array{Float64,1}) = polyparams(collect(1:len),length(params)-1) * params''
polyeval(x::Real,params::Array{Float64,1}) = [x^p for p=0:length(params)-1]' * params''

# Conversion / String

function smartparse(something)
    try
        return eval(parse(something))
    catch
        return something
    end
end

randascii(n) = join([rand(vcat('A':'Z','a':'z')) for i=1:n])

function objtodict(obj)
    Dict([(string(k),getfield(obj,k)) for k in fieldnames(obj)])
end

# List utilities

function cluster(a,dist)
    sa = sort(a)
    da = [abs(sa[i]-sa[i+1]) for i=1:length(sa)-1]
    clustered = typeof(a)[]
    push!(clustered,typeof(a)())
    push!(clustered[end],sa[1])
    for i=2:length(sa)
        da[i-1]>dist && push!(clustered,typeof(a)())
        push!(clustered[end],sa[i])
    end
    return clustered
end

function clump(a,dist;by=x->x,zero=false)
    clustered = typeof(a)()
    i = 1
    while i<=length(a)
        if by(a[i])
            j = 1
            while i+j<=length(a) && by(a[i+j])
                j += 1
            end
            if j>=dist
                append!(clustered,a[i:i+j-1])
            else
                append!(clustered,fill(zero,j))
            end
            i += j
        else
            push!(clustered,a[i])
            i += 1
        end
    end
    return clustered
end

function getprecision(b)
    a = collect(b)
    return minimum([abs(a[i]-a[i+1]) for i in 1:length(a)-1])
end

_isrepeat(a::AbstractArray{T,1}) where {T<:Real} = vcat(1,diff(a)) .!= 0
uniqueinds(a::AbstractArray{T,1}) where {T<:Real} = findall(_isrepeat(a))
norepeat(a::AbstractArray{T,1}) where {T<:Real} = a[_isrepeat(a)]

# I don't know why I so much trouble doing this... this function converts an `Array` into an `Image` using a color map (a `Vector` of colors)
function colormap_image(a::AbstractArray{T,2},m::Vector{K}) where {T<:Real,K<:Colorant}
    i = Array{K,2}(undef,size(a))
    fac = length(m)/maximum(a)
    for ii in CartesianIndices(a)
        i[ii] = m[round(Int,fac*a[ii])]
    end
    return i
end


end
