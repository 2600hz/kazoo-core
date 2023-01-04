%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2011-2023, 2600Hz
%%% @doc
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_network_tests).

-include_lib("eunit/include/eunit.hrl").

validate_ip_test_() ->
    [?_assertEqual('false', kz_network_utils:is_ip("00000"))
    ,?_assertEqual('false', kz_network_utils:is_ip("20181210"))
    ,?_assertEqual('false', kz_network_utils:is_ip("0000:0000:0000:0000:0000:0000:0001"))
    ,?_assertEqual('true', kz_network_utils:is_ip("0.0.0.0"))
    ,?_assertEqual('true', kz_network_utils:is_ip("1.1.1.1"))
    ,?_assertEqual('true', kz_network_utils:is_ip("192.168.0.10"))
    ,?_assertEqual('true', kz_network_utils:is_ip("10.0.0.1"))
    ,?_assertEqual('true', kz_network_utils:is_ip("8.8.8.8"))
    ,?_assertEqual('true', kz_network_utils:is_ip("0000:0000:0000:0000:0000:0000:0000:0001"))
    ].

validate_restricted_ip_test_() ->
    [{"IPv6 Unspecified Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::">>))
     }
    ,{"IPv4 Unspecified Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"0.0.0.0">>))
     }
    ,{"IPv6 Loopback Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::1">>))
     }

    ,{"IPv4 Typical Loopback Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"127.0.0.1">>))
     }
    ,{"IPv4 Lowest Loopback Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"127.0.0.0">>))
     }
    ,{"IPv4 Highest Loopback Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"127.255.255.255">>))
     }

     %% RFC1918 addresses
    ,{"RFC1918 Address Lower 192.168.0.0/16"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"192.168.0.0">>))
     }
    ,{"RFC1918 Address Upper 192.168.0.0/16"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"192.168.255.255">>))
     }
    ,{"RFC1918 Address Lower 10.0.0.0/8"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"10.0.0.0">>))
     }
    ,{"RFC1918 Address Upper 10.0.0.0/8"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"10.255.255.255">>))
     }
    ,{"RFC1918 Address Lower 172.16.0.0/12"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"172.16.0.0">>))
     }
    ,{"RFC1918 Address Upper 172.16.0.0/12"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"172.31.255.255">>))
     }

    ,{"RFC1918 mapped address Lower 192.168.0.0/16"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::ffff:192.168.0.0">>))
     }
    ,{"RFC1918 mapped Address Upper 192.168.0.0/16"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::ffff:192.168.255.255">>))
     }
    ,{"RFC1918 mapped Address Lower 10.0.0.0/8"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::ffff:10.0.0.0">>))
     }
    ,{"RFC1918 mapped Address Upper 10.0.0.0/8"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::ffff:10.255.255.255">>))
     }
    ,{"RFC1918 mapped Address Lower 172.16.0.0/12"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::ffff:172.16.0.0">>))
     }
    ,{"RFC1918 mapped Address Upper 172.16.0.0/12"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"::ffff:172.31.255.255">>))
     }

    ,{"RFC3927 Lower Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"169.254.0.0">>))
     }
    ,{"RFC3927 Upper Address"
     ,?_assertEqual('true', kz_network_utils:is_restricted_ip(<<"169.254.255.255">>))
     }
    ].
