%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2024, 2600Hz
%%% @doc Accessors for `emails' document.
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzd_emails).

-export([new/0]).
-export([dkim_selector/1, dkim_selector/2, set_dkim_selector/2]).
-export([email/1, email/2, set_email/2]).

-export([schema/0, type/0]).
-export([pvt_code/1, pvt_code/2, set_pvt_code/2]).
-export([pvt_verified/1, pvt_verified/2, set_pvt_verified/2]).

-export([dkim_filename/0, is_email_unique/3]).
-export([fetch/2]).

-include("kz_documents.hrl").

-type doc() :: kz_json:object().
-export_type([doc/0]).

-define(SCHEMA, <<"emails">>).

-define(CB_EMAILS, <<"emails/list_by_email">>).
-define(CB_VERIFIED_EMAILS, <<"emails/list_by_verified_email">>).

-spec new() -> doc().
new() ->
    kz_json_schema:default_object(?SCHEMA).

-spec dkim_selector(doc()) -> kz_term:api_binary().
dkim_selector(Doc) ->
    dkim_selector(Doc, 'undefined').

-spec dkim_selector(doc(), Default) -> binary() | Default.
dkim_selector(Doc, Default) ->
    kz_json:get_binary_value([<<"dkim_selector">>], Doc, Default).

-spec set_dkim_selector(doc(), binary()) -> doc().
set_dkim_selector(Doc, DkimSelector) ->
    kz_json:set_value([<<"dkim_selector">>], DkimSelector, Doc).

-spec email(doc()) -> kz_term:api_binary().
email(Doc) ->
    email(Doc, 'undefined').

-spec email(doc(), Default) -> binary() | Default.
email(Doc, Default) ->
    kz_json:get_binary_value([<<"email">>], Doc, Default).

-spec set_email(doc(), binary()) -> doc().
set_email(Doc, Email) ->
    kz_json:set_value([<<"email">>], Email, Doc).

-spec schema() -> kz_term:ne_binary().
schema() -> ?SCHEMA.

-spec type() -> kz_term:ne_binary().
type() -> ?SCHEMA.

-spec pvt_code(doc()) -> kz_term:api_ne_binary().
pvt_code(Doc) ->
    pvt_code(Doc, 'undefined').

-spec pvt_code(doc(), Default) -> kz_term:ne_binary() | Default.
pvt_code(Doc, Default) ->
    kz_json:get_ne_binary_value([<<"pvt_code">>], Doc, Default).

-spec set_pvt_code(doc(), kz_term:api_ne_binary()) -> doc().
set_pvt_code(Doc, Value) ->
    kz_json:set_value([<<"pvt_code">>], Value, Doc).

-spec pvt_verified(doc()) -> boolean().
pvt_verified(Doc) ->
    pvt_verified(Doc, 'false').

-spec pvt_verified(doc(), Default) -> boolean() | Default.
pvt_verified(Doc, Default) ->
    kz_json:get_boolean_value([<<"pvt_verified">>], Doc, Default).

-spec set_pvt_verified(doc(), boolean()) -> doc().
set_pvt_verified(Doc, IsVerified) ->
    kz_json:set_value([<<"pvt_verified">>], IsVerified, Doc).

-spec dkim_filename() -> kz_term:ne_binary().
dkim_filename() ->
    <<"pem">>.

-spec is_email_unique(cb_context:context(), kz_term:api_ne_binary(), kz_term:ne_binary()) -> boolean().
is_email_unique(Context, EmailId, EmailAddress) ->
    DbDoc = cb_context:fetch(Context, 'db_doc', kz_json:new()),
    is_email_unique(cb_context:account_id(Context)
                   ,EmailId
                   ,email(DbDoc)
                   ,EmailAddress
                   ).

-spec is_email_unique(kz_term:ne_binary(), kz_term:api_ne_binary(), kz_term:api_ne_binary(), kz_term:ne_binary()) ->
          boolean().
is_email_unique(_AccountId, _EmailId, EmailAddress, EmailAddress) ->
    'true';
is_email_unique(AccountId, EmailId, _OldEmailAddress, NewEmailAddress) ->
    ViewOptions = [{'key', NewEmailAddress}],
    case kz_datamgr:get_results(AccountId, ?CB_EMAILS, ViewOptions) of
        {'ok', []} ->
            'true';
        {'ok', _} when EmailId =:= 'undefined' ->
            'false';
        {'ok', JObjs} ->
            case [JObj || JObj <- JObjs, kz_doc:id(JObj) =/= EmailId] of
                [] ->
                    'true';
                _ ->
                    'false'
            end;
        {'error', _Reason} ->
            lager:debug("unable to get whitelabel email view for '~s' reason : ~p", [NewEmailAddress, _Reason]),
            'false'
    end.

-spec fetch(kz_term:ne_binary(), kz_term:ne_binary()) -> kz_term:api_object().
fetch(AccountId, EmailAddress) ->
    ViewOptions = [{'key', EmailAddress}],
    case kz_datamgr:get_results(AccountId, ?CB_VERIFIED_EMAILS, ViewOptions) of
        {'ok', []} ->
            lager:debug("whitelabel verified email is not found for '~s'", [EmailAddress]),
            'undefined';
        {'ok', [JObj]} ->
            kz_json:get_value(<<"value">>, JObj);
        {'error', _Reason} ->
            lager:debug("unable to get whitelabel verified email view for '~s' reason : ~p", [EmailAddress, _Reason]),
            'undefined'
    end.
