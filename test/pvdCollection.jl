#!/usr/bin/env julia

using WriteVTK
using Test

using Printf: @sprintf

const FloatType = Float32
const vtk_filename_noext = "collection"

function update_point_data!(p, q, vec, time)
    E = exp(-time)
    for I in CartesianIndices(p)
        i, j, k = I[1], I[2], I[3]
        p[I] = E * (i * i + k)
        q[I] = E * k * sqrt(j)
        vec[1, i, j, k] = E * i
        vec[2, i, j, k] = E * j
        vec[3, i, j, k] = E * k
    end
    p, q, vec
end

function update_cell_data!(cdata, time)
    Nj = size(cdata, 2) + 1
    α = 3pi / (Nj - 2)
    E = exp(-time)
    for I in CartesianIndices(cdata)
        i, j, k = I[1], I[2], I[3]
        cdata[I] = E * (2i + 3k * sin(α * (j - 1)))
    end
    cdata
end

function main()
    # Define grid.
    Ni, Nj, Nk, Nt = 20, 30, 40, 4

    x = zeros(FloatType, Ni)
    y = zeros(FloatType, Nj)
    z = zeros(FloatType, Nk)

    [x[i] = i*i/Ni/Ni for i = 1:Ni]
    [y[j] = sqrt(j/Nj) for j = 1:Nj]
    [z[k] = k/Nk for k = 1:Nk]

    # Arrays for scalar and vector fields assigned to grid points.
    p = zeros(FloatType, Ni, Nj, Nk)
    q = zeros(FloatType, Ni, Nj, Nk)
    vec = zeros(FloatType, 3, Ni, Nj, Nk)

    # Scalar data assigned to grid cells.
    # Note that in structured grids, the cells are the hexahedra formed between
    # grid points.
    cdata = zeros(FloatType, Ni - 1, Nj - 1, Nk - 1)

    # Test extents (this is optional!!)
    ext = map(N -> (1:N) .+ 42, (Ni, Nj, Nk))

    # Initialise pvd container file
    @time outfiles = paraview_collection(vtk_filename_noext) do pvd
        # Create files for each time-step and add them to the collection
        for it = 0:Nt-1
            vtk = vtk_grid(@sprintf("%s_%02i", vtk_filename_noext, it), x, y, z;
                           extent=ext)
            # Add data for current time-step
            update_point_data!(p, q, vec, it + 1)
            update_cell_data!(cdata, it + 1)
            vtk["p_values"] = p
            vtk["q_values"] = q
            vtk["myVector"] = vec
            vtk["myCellData"] = cdata
            close(vtk)
            @test isopen(vtk) == false
            pvd[float(it + 1)] = vtk
        end
    end

    # Create a copy of above pvd for reloading
    cp(vtk_filename_noext * ".pvd",
       vtk_filename_noext * "_reload.pvd",
       force=true)
    pvd_reload = paraview_collection(vtk_filename_noext * "_reload", append=true)

    # add a vtk file
    vtk_reload = vtk_grid("collection_reload", [1, 2, 3], [1, 2, 3])
    pvd_reload[5.0] = vtk_reload
    pvd_reload_files = close(pvd_reload)
    append!(outfiles, pvd_reload_files)

    println("Saved:  ", join(outfiles, "  "))

    return outfiles::Vector{String}
end

main()

