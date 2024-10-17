#using Pkg; Pkg.add("Agents")
#import Pkg; Pkg.add("StatsBase")
#import Pkg; Pkg.add("DrWatson")
#import Pkg; Pkg.add("CairoMakie")
#using Pkg; Pkg.add("BlackBoxOptim")

using Agents, Random
using Agents.DataFrames, Agents.Graphs
using StatsBase: sample, Weights
using DrWatson: @dict
using CairoMakie
using LinearAlgebra: diagind
using Printf

using BlackBoxOptim
using Statistics: mean

@agent struct PoorSoul(GraphAgent)
    days_infected::Int  # number of days since is infected
    status::Symbol  # 1: S (Susceptible), 2: I (Infected), 3: R (Recovered)
end

##### define the model
function model_initiation(;
    Ns,
    Infs,
    Vacs,
    infection_period = 5,
    detection_time = 2,
    within_household_infection_rate = 0.3,
    outside_household_infection_rate = 0.1,
    contacts_per_day = 10,
    seed = 0,
)

    rng = Xoshiro(seed)
    # make sure the size of the input arrays is equal
    @assert length(Ns) == length(Infs)  "Ns and Is must be the same."

    num_households = length(Ns)

    properties = @dict(
        Ns,
        Infs,
        infection_period,
        detection_time,
        num_households,
        within_household_infection_rate,
        outside_household_infection_rate,
        contacts_per_day
    )
    space = GraphSpace(complete_graph(num_households))
    model = StandardABM(PoorSoul, space; agent_step!, properties, rng)

    # Add individuals
    for household in 1:num_households, n in 1:Ns[household]
        ind = add_agent!(household, model, 0, :S) # Susceptible
    end
    # infect some of the initial individuals
    #println(Ns)
    #println(Infs)
    #@printf("Number of Households: %d\n", num_households)
    for household in 1:num_households
        inds = ids_in_position(household, model)
        for n in 1:Infs[household]
            agent = model[inds[n]]
            agent.status = :I # Infected
            agent.days_infected = 1
        end

        for n in Infs[household]+1:Vacs[household]+Infs[household]
            agent = model[inds[n]]
            agent.status = :R # Vaccinated
        end
    end
    return model
end


function create_params(;
    population_size, # number of people
    infection_period = 5, # how long is each individual infected
    detection_time = 2, # how long is the disease undetected
    num_infs = 100, # number of infected people to start with
    within_household_infection_rate = 0.3,
    outside_household_infection_rate = 0.1,
    contacts_per_day = 10, # number of contacts outside of the household per day
    vaccinated_rate = 0.5,
    seed = 19, # random seed
)

    Random.seed!(seed)
    @assert mod(population_size, 4) == 0 "Number of people in population must be dividable by 4"
    num_households = floor(Int, population_size / 4)
    Ns = fill(4, num_households) # population size per household: 4
    Infs = zeros(Int, num_households)
    pos_Infs = collect(1:num_households)
    for x in 1:num_infs
        if length(pos_Infs) == 0
            break
        end
        curind = rand(pos_Infs)
        Infs[curind]+=1 # infected persons
        if Infs[curind] >= 4
            deleteat!(pos_Infs, findfirst(x -> x == curind, pos_Infs))
        end
    end

    Vacs = zeros(Int, num_households)
    num_vaccinated = trunc(Int, population_size * vaccinated_rate)
    for x in 1:num_vaccinated
        if length(pos_Infs) == 0
            break
        end
        curind = rand(pos_Infs)
        Vacs[curind]+=1
        if Infs[curind]+Vacs[curind] >= 4
            deleteat!(pos_Infs, findfirst(x -> x == curind, pos_Infs))
        end
    end

    params = @dict(
        Ns,
        Infs,
        Vacs,
        infection_period,
        detection_time,
        within_household_infection_rate,
        outside_household_infection_rate,
        contacts_per_day
    )

    return params
end





##### SIR stepping
function agent_step!(agent, model)
    transmit!(agent, model)
    update!(agent, model)
    recover!(agent, model)
end

function select_agent(contact, agent, model)
    if contact.id ∉ ids_in_position(agent, model) && ((contact.status != :I) || (contact.status == :I && contact.days_infected < model.detection_time))
        return true
    end
    return false
end

function transmit!(agent, model)
    agent.status != :I && return # agent does not have the disease -> it can not transmit the disease

    # transmit within the household
    for contactID in ids_in_position(agent, model) # grab only poorsoul ids in household
        contact = model[contactID] # poorsoul
        make_contact!(contact, model, model.within_household_infection_rate)
    end

    # transmit outside household
    agent.days_infected > model.detection_time && return # detected disease -> infected, but doesnt leave the house

    #household_agent_ids = ids_in_position(agent, model)
    n = 0
    for n in 1:model.contacts_per_day
        contact = random_agent(model, potential_contact -> select_agent(potential_contact, agent, model))
        isnothing(contact) && break # stop if there are no agents that are outside
        make_contact!(contact, model, model.outside_household_infection_rate)
    end
end

function make_contact!(agent, model, infection_rate) # infect by chance
    if (agent.status == :S) && (rand(abmrng(model)) ≤ infection_rate) # infect suseptible agent by chance
        agent.status = :I # infect
    end
end

function update!(agent, model)
    if agent.status == :I
        agent.days_infected += 1
    end
end

function recover!(agent, model)
    if agent.days_infected ≥ model.infection_period # recover after infection period
        agent.status = :R
        agent.days_infected = 0
    end
end





# create the model
params = create_params(
    population_size = 10000,
    num_infs = 100, # number of infected people to start with
    infection_period = 7, # how long is each individual infected
    detection_time = 2, # how long is the disease undetected
    within_household_infection_rate = 0.3,
    outside_household_infection_rate = 0.1,
    contacts_per_day = 10, # max number of contacts outside of the household per day
    vaccinated_rate = 0.653661, # % of population_size which are vaccinated
    seed = 19 # random seed
)
model = model_initiation(; params...)


# collect data
infected(x) = count(i == :I for i in x)
infected2(x) = count(i == :I for i in x) > 1000
recovered(x) = count(i == :R for i in x)

to_collect = [(:status, f) for f in (infected, infected2, recovered, length)]
n = 15
data, _ = run!(model, n; adata = to_collect)
println(data[1:n, :])

println(sum(data.infected2_status) / n)



# parameteroptimization for vaccinated rate
function cost(x)
    params = create_params(
        population_size = 10000,
        num_infs = 100, # number of infected people to start with
        infection_period = 7, # how long is each individual infected
        detection_time = 2, # how long is the disease undetected
        within_household_infection_rate = 0.3,
        outside_household_infection_rate = 0.1,
        contacts_per_day = 10, # max number of contacts outside of the household per day
        vaccinated_rate = x[1], # % of population_size which are vaccinated
    )
    model = model_initiation(; params...)

    infected(x) = count(i == :I for i in x) > 1000
    to_collect = [(:status, f) for f in (infected, length)]

    n = 15 # number of days to evolve
    adf, mdf = run!(
        model,
        n;
        adata = to_collect
    )

    res = sum(adf.infected_status)/n

    return res < 0.5 ? 0.0 : res
end


Random.seed!(19)

result = bboptimize(
    cost,
    SearchRange = [
        (0.5,0.7),
    ],
    NumDimensions = 1,
    MaxTime = 20,
)
best_fitness(result)
best_candidate(result)