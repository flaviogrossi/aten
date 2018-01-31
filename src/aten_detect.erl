-module(aten_detect).

-export([
         init/0,
         sample_now/1,
         get_failure_probability/1
         ]).

-type sample() :: integer().

-define(WINDOW_SIZE, 1000).

-record(state, {freshness :: undefined | non_neg_integer(),
                samples = array:new(?WINDOW_SIZE) :: array:array(sample()),
                next_index = 0 :: non_neg_integer(),
                max_size = 1000 :: non_neg_integer(),
                factor = 1.5 :: number()}).


-opaque state() :: #state{}.

-export_type([state/0
              ]).

init() ->
    #state{}.


-spec sample_now(state()) -> state().
sample_now(State) ->
    append(ts(), State).

-spec get_failure_probability(state()) -> float().
get_failure_probability(State) ->
    failure_prob_at(ts(), State).

%% Internal

append(Ts, #state{freshness = undefined} = State) ->
    State#state{freshness = Ts};
append(Ts0, #state{freshness = F,
                   samples = Samples,
                   next_index = Next} = State) when is_number(F) ->
    Ts = Ts0 - F,
    State#state{samples = array:set(Next, Ts, Samples),
                next_index = (Next + 1) rem ?WINDOW_SIZE,
                freshness = Ts0}.

failure_prob_at(_At, #state{freshness = undefined}) ->
    0.0;
failure_prob_at(At, #state{freshness = F,
                           factor = A,
                           samples = Samples}) ->
    T = At - F,
    {TotNum, SmallNum} = array:foldl(fun(_, undefined, Acc) -> Acc;
                                        (_, S, {Tot, Smaller}) when S * A =< T ->
                                             {Tot+1, Smaller+1};
                                        (_, _S, {Tot, Smaller}) ->
                                             {Tot+1, Smaller}
                                     end, {0, 0}, Samples),
    SmallNum / TotNum.

ts() ->
    % TODO: should we use erlang monotonic time instead?
    % It probably doesn't matter
    erlang:system_time(microsecond).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

detect_test() ->
    S0 = #state{},
    S = lists:foldl(fun append/2, S0, [1, 5, 4, 10, 13, 20, 25]),
    ?assert(failure_prob_at(28, S) < 0.5),
    ?assert(failure_prob_at(40, S) == 1.0),
    ok.

-endif.