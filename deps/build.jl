asset_path(path...) = joinpath(@__DIR__, "..", "assets", path...)
if !ispath(abspath(asset_path("fonts",".cache")))
    mkpath(abspath(asset_path("fonts",".cache")))
end
