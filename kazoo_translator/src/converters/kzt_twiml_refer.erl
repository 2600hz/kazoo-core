%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2025, 2600Hz
%%% @doc Execute the 'Refer' verb
%%% @author
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kzt_twiml_refer).

%% API
-export([exec/3]).

-include("kzt.hrl").

-spec exec(kapps_call:call(), kz_types:xml_es() | kz_types:xml_texts(), kz_term:proplist()) ->
    {'ok', kapps_call:call()} | {'stop', kapps_call:call()}.
exec(Call, [#xmlElement{name='Sip', content=URI, attributes=[]}], Attrs) ->
    _Props = kz_xml:attributes_to_proplist(Attrs),
    URI1 = kz_xml:texts_to_binary(URI),
    try kzsip_uri:parse(URI1) of
        URI2 ->
            make_call_transfer(kzsip_uri:encode(URI2), Call),
            wait_for_transfer_events(Call)
    catch
        'throw':_E ->
            lager:debug("failed to parse SIP uri: ~p", [_E]),
            {'stop', kzt_util:add_error(Call, <<"twiml refer sip">>, <<"Invalid SIP URI">>)}
    end;

%% number DID or extension
exec(Call, [#xmlElement{name='Number', content=Number, attributes=[]}], Attrs) ->
    _Props = kz_xml:attributes_to_proplist(Attrs),
    To = knm_converters:normalize(kz_xml:texts_to_binary(Number), kapps_call:account_id(Call)),

    _ = make_call_transfer(To, Call),
    wait_for_transfer_events(Call),
    {'ok', Call};

exec(Call, Element, _Attr) ->
    lager:info("unhandled XML object: ~p", [Element]),
    {'stop', Call}.

make_call_transfer(To, Call) ->
    lager:info("blind transfer to to ~s", [To]),
    'ok' = kapps_call_command:blind_transfer(To, Call).


-spec wait_for_transfer_events(kapps_call:call()) -> {'ok', kapps_call:call()}.
wait_for_transfer_events(Call) ->
    case kapps_call_command:receive_event(600) of
        {'ok', _JObj} ->
            wait_for_transfer_events(Call);
        {'error', 'timeout'} -> {'stop', Call}
    end.