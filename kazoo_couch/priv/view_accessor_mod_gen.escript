#!/usr/bin/env escript
%%! +A0
%% -*- coding: utf-8 -*-

-mode(compile).

-export([main/1]).

main(_) ->
    _ = io:setopts(user, [{encoding, unicode}]),
    Views = kzc_account_crossbar_listings:metadata(),
    _ = maps:fold(fun config_module/3, [], Views),
    io:format('user', "bye~n", []).

config_module(ViewName, Metadata, Acc) ->
    Fields = maps:get(query_fields, Metadata),
    ModName = <<"kzv_", ViewName/binary>>,
    io:format("creating ~s~n", [ModName]),
    Src = [mod_header()
          ,<<"-module(", ModName/binary, ").\n">>
          ,"\n"
          ,create_exports(Fields)
          ,"\n"
          ,<<"-define(VIEW_NAME, <<\"crossbar_listings/", ViewName/binary, "\">>).\n">>
          ,"\n"
          ,case Fields of
               'null' ->
                   [find_all(Metadata, Fields)
                   ,"\n"
                   ,comment([], 'false')
                   ,set_options(Metadata, Fields)
                   ];
               _ ->
                   [find(Metadata, Fields)
                   ,find_one(Metadata, Fields)
                   ,find_all(Metadata, Fields)
                   ,find_keys(Metadata, Fields)
                   ,find_range(Metadata, Fields)
                   ,"\n"
                   ,comment([], 'false')
                   ,key_selector(Metadata, Fields)
                   ,keys_selector(Metadata, Fields)
                   ,range_selector(Metadata, Fields)
                   ,selector(Metadata, Fields)
                   ,maybe_set_options(Metadata, Fields)
                   ,set_options(Metadata, Fields)
                   ]
           end
          ],
    case file:write_file(<<ModName/binary, ".erl">>, Src) of
        {error, _}=Error ->
            io:format("error saving ~s: ~p~n", [ModName, Error]),
            Acc;
        ok ->
            Acc
    end.

mod_header() ->
    iolist_to_binary(
      ["%%%-----------------------------------------------------------------------------\n"
      ,"%%% @copyright (C) 2011-2025, 2600Hz\n"
      ,"%%% @doc\n"
      ,"%%% @author Hesaam Farhang\n"
      ,"%%%\n"
      ,"%%% This Source Code Form is subject to the terms of the Mozilla Public\n"
      ,"%%% License, v. 2.0. If a copy of the MPL was not distributed with this\n"
      ,"%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.\n"
      ,"%%%\n"
      ,"%%% @end\n"
      ,"%%%-----------------------------------------------------------------------------\n"
      ]).

create_exports('null') ->
    [create_export({find_all, 2})];
create_exports(<<Field/binary>>) ->
    create_exports([Field]);
create_exports(Fields) ->
    [create_export(L)
     || L <- [{find, 3}
             ,[{find_one, 2} | lists:foldr(fun(C, Acc) -> [{find_one, C + 2} | Acc] end, [], lists:seq(1, length(Fields)))]
             ,[{find_all, 2} | lists:foldr(fun(C, Acc) -> [{find_all, C + 2} | Acc] end, [], lists:seq(1, length(Fields)))]
             ,[{find_keys, 3}] ++ case Fields of
                                      [<<"doc_type">>] ->
                                          [];
                                      [<<"doc_type">> | _] ->
                                          [{find_keys, 4}];
                                      [_, <<"doc_type">>] ->
                                          [{find_keys, 4}];
                                      _ ->
                                          []
                                  end
             ,{find_range, (length(Fields) * 2) + 2}
             ]
    ].

create_export({Fun, Arity}) ->
    <<"-export([", (atom_to_binary(Fun, utf8))/binary, "/", (integer_to_binary(Arity))/binary, "]).\n">>;
create_export([{Fun, Arity} | FAs]) ->
    [<<"-export([">>
    ,<<(atom_to_binary(Fun, utf8))/binary, "/", (integer_to_binary(Arity))/binary>>
    ,[<<", ", (atom_to_binary(F, utf8))/binary, "/", (integer_to_binary(A))/binary>>
          || {F, A} <- FAs
     ]
    ,"]).\n"
    ].

find(Metadata, <<Field/binary>>) ->
    find(Metadata, [Field]);
find(_Metadata, _) ->
    ["\n"
    ,comment(["Find a key with proplist."])
    ,spec_specy("find", "kz_term:proplist()", 1)
    ,"find(Database, [], Options) ->\n"
    ,"    find_all(Database, Options);\n"
    ,"find(Database, [{<<_/binary>>, _}|_]=Prop, Options) ->\n"
    ,"    Selector = [{'key', Prop}],\n"
    ,"    kz_view:find(Database, ?VIEW_NAME, Selector, maybe_set_options(Prop, Options));\n"
    ,"find(Database, [[{<<_/binary>>, _} | _] | _]=Props, Options) ->\n"
    ,"    Selector = [{'keys', Props}],\n"
    ,"    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options));\n"
    ,"find(Database, Selector, Options) ->\n"
    ,"    kz_view:find(Database, ?VIEW_NAME, Selector, maybe_set_options(Selector, Options)).\n"
    ].

find_one(Metadata, Fields) ->
    find_findy("find_one", "find_one", "the first result", Metadata, Fields).

find_all(_, 'null') ->
    ["\n" %% arity 2
    ,comment("Find all.")
    ,spec_specy("find_all", "", 0)
    ,fun_head("find_all", [])
    ,"    kz_view:find(Database, ?VIEW_NAME, [], set_options(Options)).\n"
    ];
find_all(Metadata, Fields) ->
    find_findy("find_all", "find", "all", Metadata, Fields).

has_doctype_pos(Fields) ->
    case Fields of
        [<<"doc_type">>] ->
            'false';
        [<<"doc_type">>  | Rest] ->
            {'true', first, Rest};
        [Field, <<"doc_type">>] ->
            {'true', last, [Field]};
        _ ->
            {'false', bad, bad}
    end.

find_keys(Metadata, <<Field/binary>>) ->
    find_keys(Metadata, [Field]);
find_keys(_Metadata, Fields) ->
    {HasDocType, DocTypePosition, Others} = has_doctype_pos(Fields),
    Spec = case Fields of
               [_] -> "kz_term:ne_binaries() | kz_term:proplists()";
               [_ | _] -> "kz_term:proplists()"
           end,
    ["\n"
    ,comment(["Find keys."])
    ,spec_specy("find_keys", Spec, 1)
    ,case Fields of
         [Field] ->
             Camel = camel("", Field),
             [fun_head("find_keys", ["[<<_/binary>> | _]=", Camel, "s"])
             ,["    Props = [selector(", Camel,")\n"
              ,"             || ", Camel, " <- ", Camel, "s\n"
              ,"            ],\n"
              ]
             ,"    Selector = keys_selector(Props),\n"
             ,"    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options));\n"
             ];
         [_ | _] ->
             []
     end
    ,fun_head("find_keys", "Props")
    ,"    Selector = keys_selector(Props),\n"
    ,"    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).\n"
    ,case HasDocType of
         'true' ->
             [OtherField | OtherFields] = Others,
             OtherComment = [camel("", OtherField)
                            ,[[", ", camel("", Field)]
                              || Field <- OtherFields
                             ]
                            ],
             OtherSpec = case Others of
                             [_] -> "kz_term:ne_binaries() | kz_term:proplists()";
                             [_ | _] -> "kz_term:proplists()"
                         end,
             ["\n"
             ,comment(["Find keys for DocType with proplists of ", OtherComment,"."])
             ,spec_specy("find_keys", ["kz_term:ne_binary(), ", OtherSpec], 1)
             ,case Others of
                  [Field] ->
                      Camel = camel("", Field),
                      Selector = case DocTypePosition of
                                     first -> ["DocType, ", Camel];
                                     last -> [Camel, ", DocType"]
                                 end,
                      [fun_head("find_keys", ["DocType, ", "[<<_/binary>> | _]=", Camel, "s"])
                      ,["    Props = [selector(", Selector,")\n"
                       ,"             || ", Camel, " <- ", Camel, "s\n"
                       ,"            ],\n"
                       ]
                      ,"    find_keys(Database, Props, set_options(Options, DocType));\n"
                      ];
                  [_ | _] ->
                      []
              end
             ,fun_head("find_keys", ["DocType, Props0"])
             ,["    Props = [props:insert_value(<<\"doc_type\">>, DocType, Prop)\n"
              ,"             || Prop <- Props0\n"
              ,"            ],\n"
              ]
             ,"    find_keys(Database, Props, set_options(Options, DocType)).\n"
             ];
         _ ->
             []
     end
    ].

find_range(Metadata, <<Field/binary>>) ->
    find_range(Metadata, [Field]);
find_range(_Metadata, [F1 | Fields]) ->
    Selector = [camel("Start", F1)
               ,[[", ", camel("Start", Field)]
                 || Field <- Fields
                ]
               ,", "
               ,camel("End", F1)
               ,[[", ", camel("End", Field)]
                 || Field <- Fields
                ]
               ],
    ["\n"
    ,comment("Find all docs in range.")
    ,spec_specy("find_range", "kz_term:api_ne_binary()", (length(Fields) + 1) * 2)
    ,fun_head("find_range", Selector)
    ,"    Selector = range_selector(", Selector, "),\n"
    ,"    kz_view:find(Database, ?VIEW_NAME, Selector, set_options(Options)).\n"
    ].

selector(_, 'null') ->
    [];
selector(Metadata, <<Field/binary>>) ->
    selector(Metadata, [Field]);
selector(_Metadata, [F1 | Fields]) ->
    Selector = [camel("", F1)
               ,[[", ", camel("", Field)]
                 || Field <- Fields
                ]
               ],
    ["\n"
    ,comment("Return a proplist of query fields and their values.")
    ,spec_specy("selector", "kz_term:api_ne_binary()", length(Fields) + 1)
    ,["selector(", Selector, ") ->\n"]
    ,"    props:filter_undefined(\n"
    ,"      [{<<\"", F1, "\">>, ", camel("", F1), "}\n"
    ,[["      ,{<<\"", Field, "\">>, ", camel("", Field), "}\n"]
      || Field <- Fields
     ]
    ,"      ]).\n"
    ].

key_selector(_, 'null') ->
    [];
key_selector(Metadata, <<Field/binary>>) ->
    key_selector(Metadata, [Field]);
key_selector(_Metadata, [F1 | Fields]) ->
    Selector = [camel("", F1)
               ,[[", ", camel("", Field)]
                 || Field <- Fields
                ]
               ],
    ["\n"
    ,comment("Return selector for getting a key.")
    ,spec_specy("key_selector", "kz_term:api_ne_binary()", length(Fields) + 1)
    ,["key_selector(", Selector, ") ->\n"]
    ,"    [{'key', selector(", Selector, ")}].\n"
    ].

keys_selector(_, 'null') ->
    [];
keys_selector(Metadata, <<Field/binary>>) ->
    keys_selector(Metadata, [Field]);
keys_selector(_Metadata, _) ->
    ["\n"
    ,comment("Return selector for getting multiple keys.")
    ,spec_specy("keys_selector", "kz_term:api_ne_binary()", length(Fields) + 1)
    ,["keys_selector(Props) ->\n"]
    ,"    [{'keys', Props}].\n"
    ].

range_selector(_, 'null') ->
    [];
range_selector(Metadata, <<Field/binary>>) ->
    range_selector(Metadata, [Field]);
range_selector(_Metadata, [F1 | Fields]) ->
    Selector = [camel("Start", F1)
               ,[[", ", camel("Start", Field)]
                 || Field <- Fields
                ]
               ,", "
               ,camel("End", F1)
               ,[[", ", camel("End", Field)]
                 || Field <- Fields
                ]
               ],
    ["\n"
    ,comment("Return selector for a range.")
    ,spec_specy("range_selector", "kz_term:api_ne_binary()", (length(Fields) + 1) * 2)
    ,["range_selector(", Selector, ") ->\n"]
    ,"    [{'start', selector(", [camel("Start", F1)
                                 ,[[", ", camel("Start", Field)]
                                   || Field <- Fields
                                  ]
                                 ], ")}\n"
    ,"    ,{'end', selector(", [camel("End", F1)
                               ,[[", ", camel("End", Field)]
                                 || Field <- Fields
                                ]
                               ], ")}\n"
    ,"    ].\n"
    ].

set_options(_Metadata, 'null') ->
    ["\n"
    ,"set_options(Options) -> Options.\n"
    ];
set_options(Metadata, <<Field/binary>>) ->
    set_options(Metadata, [Field]);
set_options(_, [<<"doc_type">>]) ->
    ["\n"
    ,"set_options(Options) -> Options.\n"
    ,"set_options(Options, Type) ->\n"
    ,"    DocType = props:get_value('doc_type', Options, Type),\n"
    ,"    props:set_value('doc_type', DocType, Options).\n"
    ];
set_options(Metadata, [<<"doc_type">> | _]) ->
    set_options(Metadata, [<<"doc_type">>]);
set_options(Metadata, [_, <<"doc_type">> | _]) ->
    set_options(Metadata, [<<"doc_type">>]);
set_options(Metadata, _) ->
    case maps:get(doc_types, Metadata, []) of
        [] ->
            ["\n"
            ,"set_options(Options) -> Options.\n"
            ];
        [Type] ->
            ["\n"
            ,"set_options(Options) ->\n"
            ,"    props:set_value('doc_type', <<\"", Type, "\">>, Options).\n"
            ];
        _ ->
            ["\n"
            ,"set_options(Options) -> Options.\n"
            ]
    end.

maybe_set_options(Metadata, <<Field/binary>>) ->
    maybe_set_options(Metadata, [Field]);
maybe_set_options(_, Fields) ->
    case lists:member(<<"doc_type">>, Fields) of
        'true' ->
            ["\n"
            ,"maybe_set_options([{'key', Prop}], Options) ->\n"
            ,"    set_options(Options, props:get_value(<<\"doc_type\">>, Prop));\n"
            ,"maybe_set_options([{<<_/binary>>, _} | _]=Prop, Options) ->\n"
            ,"    set_options(Options, props:get_value(<<\"doc_type\">>, Prop));\n"
            ,"maybe_set_options(_, Options) ->\n"
            ,"    set_options(Options).\n"
            ];
        'false' ->
            ["\n"
            ,"maybe_set_options(_, Options) ->\n"
            ,"    set_options(Options).\n"
            ]
    end.

comment(Text) ->
    comment(Text, 'true').

comment(Text0, LastLineBreak) ->
    Text = case Text0 of [] -> []; _ -> [" ", Text0] end,
    ["%%------------------------------------------------------------------------------\n"
    ,"%% @doc", Text, "\n"
    ,"%% @end\n"
    ,"%%------------------------------------------------------------------------------"
    ,case LastLineBreak of
         'true' -> "\n";
         _ -> ""
     end
    ].

spec_specy(Fun, _, 0) ->
    ["-spec ", Fun, "(kz_term:ne_binary(), kz_view:options()) -> kz_view:result().\n"];
spec_specy(Fun, BinaryType, Argc) ->
    ["-spec ", Fun, "(kz_term:ne_binary(), "
    ,BinaryType
    ,[", " ++ BinaryType || _I <- lists:seq(1, Argc - 1)]
    ,", kz_view:options()) -> kz_view:result().\n"
    ].

fun_head(Fun, []) ->
    [Fun, "(Database, Options) ->\n"];
fun_head(Fun, Selector) ->
    [Fun, "(Database, ", Selector, ", Options) ->\n"].

camel(Prefix, Text) ->
    [Prefix, kz_binary:to_camel_case(kz_term:to_binary(Text))].

find_findy(FunName, KzViewFun, Comment, Metadata, <<Field/binary>>) ->
    find_findy(FunName, KzViewFun, Comment, Metadata, [Field]);
find_findy(FunName, KzViewFun, Comment, _Metadata, Fields) ->
    ["\n" %% arity 2
    ,comment(["Find ", Comment, "."])
    ,spec_specy(FunName, "", 0)
    ,fun_head(FunName, [])
    ,"    kz_view:", KzViewFun, "(Database, ?VIEW_NAME, [], set_options(Options)).\n"

    ,lists:foldr(
       fun(C, Acc) ->
               %%    [F1 | Fn] = lists:reverse(lists:nthtail(length(Fields) - C, lists:reverse(Fields))),
               [F1 | Fn] = Fields -- lists:nthtail(C, Fields),
               SelectorN = [camel("", F1)
                           ,[[", ", camel("", Field)]
                             || Field <- Fn
                            ]
                           ],
               SetOptions = case lists:member(<<"doc_type">>, [F1 | Fn]) of
                                'true' ->
                                    ["set_options(Options, DocType)"];
                                'false' ->
                                    ["set_options(Options)"]
                            end,
               Undefined = [", 'undefined'" || _ <- lists:seq(1, length(Fields) - length([F1 | Fn]))],
               ["\n" %% artiy n
               ,comment(["Find ", Comment," with ", SelectorN, "."])
               ,spec_specy(FunName, "kz_term:ne_binary()", length(Fn) + 1)
               ,fun_head(FunName, SelectorN)
               ,case length([F1 | Fn]) =:= length(Fields) of
                    'true' ->
                        ["    Selector = key_selector(", SelectorN,"),\n"];
                    'false' ->
                        ["    Selector = range_selector(", SelectorN, Undefined, ", ", SelectorN, Undefined, "),\n"]
                end
               ,"    kz_view:", KzViewFun, "(Database, ?VIEW_NAME, Selector, ", SetOptions,").\n"
               | Acc
               ]
       end
      ,[]
      ,lists:seq(1, length(Fields))
      )
    ].
