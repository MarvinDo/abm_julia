basedir=/home/doebema/abm_julia
toolsdir=$basedir/tools
srcdir=$basedir/src

julia=$toolsdir/julia/julia-1.10.5/bin/julia

export JULIA_DEPOT_PATH=$basedir/.julia

$julia $srcdir/main.jl