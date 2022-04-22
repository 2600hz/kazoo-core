-module(kz_style_tests).

-include_lib("eunit/include/eunit.hrl").

enclosed_atom_test_() ->
    ?_assertEqual([], call_it(<<"the_function() -> 'good_atom'.">>)).

unenclosed_atom_test_() ->
    ?_assertMatch([_], call_it(<<"the_function() -> bad_atom.">>)).

unenclosed_record_field_access_test_() ->
    ?_assertEqual([], call_it(<<"the_function(NamedVariable) -> NamedVariable#my_record.rec_field1.">>)).

unenclosed_record_field_index_test_() ->
    ?_assertEqual([], call_it(<<"the_function() -> #my_record.rec_field1.">>)).

unenclosed_record_field_assignment_test_() ->
    ?_assertEqual([], call_it(<<"the_function() -> #my_record{ rec_field1 = 5 }.">>)).

unenclosed_record_field_reassignment_test_() ->
    ?_assertEqual([], call_it(<<"the_function(NamedVariable) -> NamedVariable#my_record{ rec_field1 = 5 }.">>)).

unenclosed_record_field_reassignment_multi_test_() ->
    ?_assertEqual([], call_it(<<"the_function(NamedVariable) -> NamedVariable#my_record{ rec_field1 = 1, rec_field2 = 2 }.">>)).

unenclosed_record_definition_test_() ->
    PostFieldParts =
        [{<<"nothing extra">>, <<>>}
        ,{<<"an intenrnal type">>, <<" :: pos_intger()">>}
        ,{<<"a default value">>, <<" = 3">>}
        ,{<<"default value and internal type">>, <<" = 5 :: pos_integer()">>}
        ,{<<"an external type">>, <<" :: external:type()">>}
        ,{<<"a default value and external type">>, <<" = 7 :: external:type()">>}
        ],
    BaseString = "-record(my_record, { rec_field1~s }).",
    lists:foldl(fun({TestName, AddedPart}, Acc) ->
                        CodeToTest = iolist_to_binary(io_lib:format(BaseString, [AddedPart])),
                        [{TestName, ?_assertEqual([], call_it(CodeToTest))} | Acc]
                end
               ,[]
               ,PostFieldParts
               ).

enclosed_atom_as_type_test_() ->
    ?_assertEqual([], call_it(<<"-type some_type_name() :: 'good_atom'.">>)).

unenclosed_atom_as_type_test_() ->
    ?_assertMatch([_], call_it(<<"-type some_type_name() :: bad_atom.">>)).

unenclosed_atom_as_record_name_test_() ->
    ?_assertEqual([], call_it(<<"-type some_type_name() :: #some_record{}.">>)).

unenclosed_atom_in_local_func_call_test_() ->
    ?_assertEqual([], call_it(<<"the_function() -> a_local_function().">>)).

unenclosed_atom_in_external_func_call_test_() ->
    ?_assertEqual([], call_it(<<"the_function() -> external_mod:external_fun().">>)).

mixed_enclosed_atom_as_type_test_() ->
    ?_assertMatch([_], call_it(<<"-type some_type_name() :: 'good_atom' | bad_atom.">>)).

nested_atom_in_term_test_() ->
    ?_assertMatch([_], call_it(<<"the_function() -> {bad_atom, 'good_atom'}.">>)).

nested_atom_in_record_assignemnt_test_() ->
    ?_assertMatch([_], call_it(<<"the_function() -> #my_record{ rec_field1 = bad_atom, rec_field2 = 'good_atom' }.">>)).

nested_atom_in_record_reassignemnt_test_() ->
    ?_assertMatch([_], call_it(<<"the_function(NamedVariable) -> NamedVariable#my_record{ rec_field1 = bad_atom, rec_field2 = 'good_atom' }.">>)).

nested_atom_in_term_in_record_test_() ->
    ?_assertMatch([_, _], call_it(<<"the_function() -> #my_record{ rec_field1 = {bad_atom, 'good_atom'}, rec_field2 = ['good_atom', bad_atom] }.">>)).

%% nested keys in map should be ignored
nested_atom_in_map_test_() ->
    ?_assertMatch([], call_it(<<"-type apps() :: #{atom() => #{pid => pid(), ref => reference()}}.">>)).

map_atom_key_in_function_clause_test_() ->
    ?_assertEqual([], call_it(<<"the_function(#{key := Value}) -> Value.">>)).

map_multi_atom_keys_in_function_clause_test_() ->
    ?_assertEqual([], call_it(<<"the_function(#{key := Value, foo := Value}) -> Value.">>)).

map_atom_key_atom_value_in_function_clause_test_() ->
    ?_assertMatch([_], call_it(<<"the_function(#{key := value}) -> 'value'.">>)).

map_atom_keys_atom_values_in_function_clause_test_() ->
    ?_assertMatch([_, _], call_it(<<"the_function(#{key := value, foo := value}) -> 'value'.">>)).

map_atom_keys_one_atom_tickied_in_function_clause_test_() ->
    ?_assertMatch([_], call_it(<<"the_function(#{key := 'value', foo := value}) -> 'value'.">>)).

self_test_() ->
    {'ok', Bin} = file:read_file(filename:join([code:lib_dir('kazoo_stdlib'), "test", ?MODULE_STRING".erl"])),
    ElvisFile = #{path => "kz_style_tests.erl", content => Bin},
    ?_assertEqual([], kz_style:no_unenclosed_atoms(#{}, ElvisFile, #{})).

implementation_test_() ->
    {'ok', Bin} = file:read_file(filename:join([code:lib_dir('kazoo_stdlib'), "src", "kz_style.erl"])),
    ElvisFile = #{path => "kz_style.erl", content => Bin},
    ?_assertEqual([], kz_style:no_unenclosed_atoms(#{}, ElvisFile, #{})).

call_it(Code) ->
    ElvisFile = fake_elvis_file(Code),
    kz_style:no_unenclosed_atoms(#{}, ElvisFile, #{}).

fake_elvis_file(Code) ->
    #{path => "does-not-exist.erl", content => Code}.
