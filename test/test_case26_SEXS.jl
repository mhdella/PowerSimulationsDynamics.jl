"""
Validation PSSE/SEXS:
This case study defines a three bus system with an infinite bus, GENROU and a load.
The GENROU machine has connected an SEXS Excitation System.
The fault drop the line connecting the infinite bus and GENROU.
"""

##################################################
############### SOLVE PROBLEM ####################
##################################################

# Define dyr files

names = ["SEXS", "SEXS: TE=0"]

dyr_files = [
    joinpath(TEST_FILES_DIR, "benchmarks/psse/SEXS/ThreeBus_SEXS.dyr"),
    joinpath(TEST_FILES_DIR, "benchmarks/psse/SEXS/ThreeBus_SEXS_noTE.dyr"),
]

csv_files = [
    joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/TEST_SEXS.csv"),
    joinpath(TEST_FILES_DIR, "benchmarks/psse/AC1A/TEST_SEXS_noTE.csv"),
]

init_conditions = test26_x0_init

eigs_values = [test26_eigvals, test26_eigvals_noTE]

raw_file_dir = joinpath(TEST_FILES_DIR, "benchmarks/psse/SEXS/ThreeBusMulti.raw")
tspan = (0.0, 20.0)

function test_sexs_implicit(dyr_file, csv_file, init_cond, eigs_value)
    path = (joinpath(pwd(), "test-psse-sexs"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file_dir, dyr_file)
        for l in get_components(PSY.PowerLoad, sys)
            PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
        end

        # Define Simulation Problem
        sim = Simulation!(
            ResidualModel,
            sys, #system
            path,
            tspan, #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        ) #Type of Fault

        # Test Initial Condition
        diff_val = [0.0]
        res = get_init_values_for_comparison(sim)
        for (k, v) in init_cond
            diff_val[1] += LinearAlgebra.norm(res[k] - v)
        end

        @test (diff_val[1] < 1e-3)

        # Obtain small signal results for initial conditions. Testing the simulation reset
        small_sig = small_signal_analysis(sim)
        eigs = small_sig.eigenvalues
        @test small_sig.stable

        # Test Eigenvalues
        @test LinearAlgebra.norm(eigs - eigs_value) < 1e-3

        # Solve problem
        @test execute!(sim, IDA(), dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
        # Obtain data for voltage magnitude at bus 102
        series2 = get_voltage_magnitude_series(results, 102)
        t = series[1]
        δ = series[2]
        V = series2[2]
        # TODO: Test Vf with PSSE
        series4 = get_field_voltage_series(results, "generator-102-1")
        Vf = series4[2]

        # TODO: Get PSSE CSV files and enable tests

        #M = get_csv_data(csv_file)
        #t_psse, δ_psse = clean_extra_timestep!(M[:, 1], M[:, 2])
        #_, V_psse = clean_extra_timestep!(M[:, 1], M[:, 3])

        # Test Transient Simulation Results
        # PSSE results are in Degrees
        #@test LinearAlgebra.norm(δ - (δ_psse .* pi / 180), Inf) <= 1e-2
        #@test LinearAlgebra.norm(V - V_psse, Inf) <= 1e-1
        #@test LinearAlgebra.norm(t - round.(t_psse, digits = 3)) == 0.0
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end

function test_sexs_mass_matrix(dyr_file, csv_file, init_cond, eigs_value)
    path = (joinpath(pwd(), "test-psse-sexs"))
    !isdir(path) && mkdir(path)
    try
        sys = System(raw_file_dir, dyr_file)
        for l in get_components(PSY.PowerLoad, sys)
            PSY.set_model!(l, PSY.LoadModels.ConstantImpedance)
        end

        # Define Simulation Problem
        sim = Simulation!(
            MassMatrixModel,
            sys, #system
            path,
            tspan, #time span
            BranchTrip(1.0, Line, "BUS 1-BUS 2-i_1"), #Type of Fault
        ) #Type of Fault

        # Test Initial Condition
        diff_val = [0.0]
        res = get_init_values_for_comparison(sim)
        for (k, v) in init_cond
            diff_val[1] += LinearAlgebra.norm(res[k] - v)
        end

        @test (diff_val[1] < 1e-3)

        # Obtain small signal results for initial conditions. Testing the simulation reset
        small_sig = small_signal_analysis(sim)
        eigs = small_sig.eigenvalues
        @test small_sig.stable

        # Test Eigenvalues
        @test LinearAlgebra.norm(eigs - eigs_value) < 1e-3

        # Solve problem
        @test execute!(sim, Rodas4(), dtmax = 0.005, saveat = 0.005) ==
              PSID.SIMULATION_FINALIZED
        results = read_results(sim)

        # Obtain data for angles
        series = get_state_series(results, ("generator-102-1", :δ))
        # Obtain data for voltage magnitude at bus 102
        series2 = get_voltage_magnitude_series(results, 102)
        t = series[1]
        δ = series[2]
        V = series2[2]
        # TODO: Test Vf with PSSE
        series4 = get_field_voltage_series(results, "generator-102-1")
        Vf = series4[2]

        # TODO: Get PSSE CSV files and enable tests

        #M = get_csv_data(csv_file)
        #t_psse, δ_psse = clean_extra_timestep!(M[:, 1], M[:, 2])
        #_, V_psse = clean_extra_timestep!(M[:, 1], M[:, 3])

        # Test Transient Simulation Results
        # PSSE results are in Degrees
        #@test LinearAlgebra.norm(δ - (δ_psse .* pi / 180), Inf) <= 1e-2
        #@test LinearAlgebra.norm(V - V_psse, Inf) <= 1e-1
        #@test LinearAlgebra.norm(t - round.(t_psse, digits = 3)) == 0.0
    finally
        @info("removing test files")
        rm(path, force = true, recursive = true)
    end
end

@testset "Test 26 SEXS ResidualModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            csv_file = csv_files[ix]
            init_cond = init_conditions
            eigs_value = eigs_values[ix]
            test_sexs_implicit(dyr_file, csv_file, init_cond, eigs_value)
        end
    end
end

@testset "Test 26 SEXS MassMatrixModel" begin
    for (ix, name) in enumerate(names)
        @testset "$(name)" begin
            dyr_file = dyr_files[ix]
            csv_file = csv_files[ix]
            init_cond = init_conditions
            eigs_value = eigs_values[ix]
            test_sexs_mass_matrix(dyr_file, csv_file, init_cond, eigs_value)
        end
    end
end
