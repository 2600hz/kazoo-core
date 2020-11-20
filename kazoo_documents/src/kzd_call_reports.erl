%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2020-, Ooma Inc.
%%% @doc Accessors for `call_reports' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_call_reports).

-export([new/0]).
-export([call_id/1, call_id/2, set_call_id/2]).
-export([cdr_id/1, cdr_id/2, set_cdr_id/2]).
-export([description/1, description/2, set_description/2]).
-export([type/1, type/2, set_type/2]).


-export([validate/1
        ,allowed_types/0
        ]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"call_reports">>).

-define(ALLOWED_TYPES_KEY, <<"allowed_types">>).
-define(DEFAULT_ALLOWED_TYPES, [[{<<"id">>, <<"dropped_call">>}, {<<"name">>, <<"Dropped call">>}]
                               ,[{<<"id">>, <<"one_way_audio">>}, {<<"name">>, <<"One-way audio">>}]
                               ,[{<<"id">>, <<"broken_audio">>}, {<<"name">>, <<"Broken audio or bad sound">>}]
                               ,[{<<"id">>, <<"other">>}, {<<"name">>, <<"Other">>}]
                               ]).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec call_id(doc()) -> kz_term:api_binary().
call_id(Doc) ->
    call_id(Doc, 'undefined').

-spec call_id(doc(), Default) -> binary() | Default.
call_id(Doc, Default) ->
    kz_json:get_binary_value([<<"call_id">>], Doc, Default).

-spec set_call_id(doc(), binary()) -> doc().
set_call_id(Doc, CallId) ->
    kz_json:set_value([<<"call_id">>], CallId, Doc).

-spec cdr_id(doc()) -> kz_term:api_binary().
cdr_id(Doc) ->
    cdr_id(Doc, 'undefined').

-spec cdr_id(doc(), Default) -> binary() | Default.
cdr_id(Doc, Default) ->
    kz_json:get_binary_value([<<"cdr_id">>], Doc, Default).

-spec set_cdr_id(doc(), binary()) -> doc().
set_cdr_id(Doc, CdrId) ->
    kz_json:set_value([<<"cdr_id">>], CdrId, Doc).

-spec description(doc()) -> kz_term:api_binary().
description(Doc) ->
    description(Doc, 'undefined').

-spec description(doc(), Default) -> binary() | Default.
description(Doc, Default) ->
    kz_json:get_binary_value([<<"description">>], Doc, Default).

-spec set_description(doc(), binary()) -> doc().
set_description(Doc, Description) ->
    kz_json:set_value([<<"description">>], Description, Doc).

-spec type(doc()) -> kz_term:api_binary().
type(Doc) ->
    type(Doc, 'undefined').

-spec type(doc(), Default) -> binary() | Default.
type(Doc, Default) ->
    kz_json:get_binary_value([<<"type">>], Doc, Default).

-spec set_type(doc(), binary()) -> doc().
set_type(Doc, Type) ->
    kz_json:set_value([<<"type">>], Type, Doc).

%%------------------------------------------------------------------------------
%% @doc Validate a requested call report can be created
%%
%% Returns the updated call report doc (with relevant defaults)
%% or returns the validation error {Path, ErrorType, ErrorMessage}
%% @end
%%------------------------------------------------------------------------------
-spec validate(doc()) -> kazoo_documents:doc_validation_return().
validate(ReqJObj) ->
    ValidateFuns = [fun validate_call_report_schema/1],
    try do_validation(ReqJObj, ValidateFuns) of
        {CallReportDoc, []} -> {'true', CallReportDoc};
        {_CallReportDoc, ValidationErrors} -> {'validation_errors', ValidationErrors}
    catch
        'throw':SystemError -> SystemError
    end.

-spec do_validation(doc(), [kazoo_documents:doc_validation_fun()]) ->
          {'true', doc()} |
          {'validation_errors', kazoo_documents:doc_validation_errors()}.
do_validation(ReqJObj, ValidateFuns) ->
    lists:foldl(fun(F, Acc) -> F(Acc) end
               ,{ReqJObj, []}
               ,ValidateFuns
               ).

%%------------------------------------------------------------------------------
%% @doc Verify the call report doc against the call report doc schema
%% On Success merge the private fields from the current call report doc into
%% Doc.
%% @end
%%------------------------------------------------------------------------------
-spec validate_call_report_schema(kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
validate_call_report_schema({Doc, Errors}) ->
    Schema = case kzd_schema:find_schema(?SCHEMA) of
                 'undefined' ->
                     %% Fall back to default schema validation behavior (likely validation failure)
                     ?SCHEMA;
                 SchemaJObj ->
                     %% Augment schema with system_config-based validation
                     AllowedTypeValues = lists:map(fun(AllowedTypeJObj) -> kz_json:get_ne_binary_value(<<"id">>, AllowedTypeJObj) end
                                                  ,allowed_types()
                                                  ),
                     kz_json:set_value([<<"properties">>, <<"type">>, <<"enum">>], AllowedTypeValues, SchemaJObj)
             end,
    kzd_module_utils:validate_schema(Schema, {Doc, Errors}, fun on_successful_schema_validation/1).

%%------------------------------------------------------------------------------
%% @doc Executed after `validate_call_report_schema/3' if it passes schema
%% validation.
%% @end
%%------------------------------------------------------------------------------
-spec on_successful_schema_validation(kazoo_documents:doc_validation_acc()) ->
          kazoo_documents:doc_validation_acc().
on_successful_schema_validation({Doc, Errors}) ->
    lager:debug("new call report doc passed schema validation"),
    Doc1 = kz_doc:setters(Doc, [{fun kz_doc:set_id/2, kazoo_modb_util:modb_id()}
                               ,{fun kz_doc:set_type/2, <<"call_report">>}
                               ]),
    {Doc1, Errors}.

%%------------------------------------------------------------------------------
%% @doc Objects with IDs that define the allowed values for the `type' property
%% of the doc.
%% @end
%%------------------------------------------------------------------------------
-spec allowed_types() -> kz_json:objects().
allowed_types() ->
    DefaultAllowedTypes = lists:map(fun kz_json:from_list/1, ?DEFAULT_ALLOWED_TYPES),
    kapps_config:get(<<"crossbar.", ?SCHEMA/binary>>, ?ALLOWED_TYPES_KEY, DefaultAllowedTypes).
