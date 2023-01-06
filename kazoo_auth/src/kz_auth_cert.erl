%%%-----------------------------------------------------------------------------
%%% @copyright (C) 2010-2023, 2600Hz
%%% @doc Certificate Utilities
%%% @author Luis Azedo
%%% This Source Code Form is subject to the terms of the Mozilla Public
%%% License, v. 2.0. If a copy of the MPL was not distributed with this
%%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%%
%%% @end
%%%-----------------------------------------------------------------------------
-module(kz_auth_cert).

-export([create/5, create_ca/5
        ,create_self/2, create_self/3
        ,subject_encode/1
        ,cn/1
        ,from_der/1
        ,from_pem/1
        ,from_file/1
        ,to_der/1
        ,to_pem/1
        ,to_file/2, to_file/3
        ,subject/1
        ,verify/2
        ,fingerprints/1
        ,public_key/1
        ]).

-export(['id-at-2600hz'/0
        ,'id-at-2600hz-accountId'/0
        ,'id-at-2600hz-endpointId'/0
        ]).

-include_lib("public_key/include/public_key.hrl").

-define('id-at-2600hz', {1,3,6,1,4,1,41246}).
-define('id-at-2600hz-accountId', {1,3,6,1,4,1,41246,1}).
-define('id-at-2600hz-endpointId', {1,3,6,1,4,1,41246,2}).

-define(DEFAULT_CERTIFICATE_DURATION, 1095).

-type priv_key() :: public_key:private_key().
-type pub_key() :: public_key:public_key().
-type cert() :: #'Certificate'{}.
-type attributeType() :: #'AttributeTypeAndValue'{}.
-type attributeTypeList() :: [attributeType()].
-type subject() :: {rdnSequence, [attributeTypeList()]}.

-spec create_self(priv_key() | binary(), binary()) -> cert().
create_self(PrivateKey, Name) ->
    create_self(PrivateKey, Name, ?DEFAULT_CERTIFICATE_DURATION).

-spec create_self(priv_key() | binary(), binary() | subject(), integer()) -> cert().
create_self(PrivateKey, Name, Days)
  when is_binary(Name) ->
    create_self(PrivateKey, cn(Name), Days);
create_self(Key, Subject, Days)
  when is_binary(Key) ->
    {'ok', PrivateKey} = kz_auth_keys:private_key(Key),
    create_self(PrivateKey, Subject, Days);
create_self(#'RSAPrivateKey'{}=PrivateKey, Subject, Days) ->
    PublicKey = kz_auth_keys:get_public_key_from_private_key(PrivateKey),
    create(Subject, PublicKey, Days, Subject, PrivateKey, ca_extensions()).

-spec create_ca(subject(), pub_key(), integer(), subject(), priv_key()) -> cert().
create_ca(Subject, SubjectPublicKey, Days, Issuer, IssuerPrivateKey) ->
    create(Subject, SubjectPublicKey, Days, Issuer, IssuerPrivateKey, ca_extensions()).

-spec create(subject(), pub_key(), integer(), subject(), priv_key()) -> cert().
create(Subject, SubjectPublicKey, Days, Issuer, IssuerPrivateKey) ->
    create(Subject, SubjectPublicKey, Days, Issuer, IssuerPrivateKey, []).

-spec create(subject(), pub_key(), integer(), subject(), priv_key(), list()) -> cert().
create(Subject, SubjectPublicKey, Days, Issuer, IssuerPrivateKey, Extensions) ->
    Validity = validity(Days),
    SubjectPublicKeyDER = public_key_to_der(SubjectPublicKey),
    SubjectPublicKeyInfo = #'SubjectPublicKeyInfo'
        { algorithm = #'AlgorithmIdentifier'
          { algorithm = ?rsaEncryption
          , parameters = <<5,0>>
          }
        , subjectPublicKey = SubjectPublicKeyDER
        },

    Ext = encode_extensions(
            [authority_key_identifier(IssuerPrivateKey)
            ,subject_key_identifier(SubjectPublicKey)
            | Extensions
            ]),
    TBSCertificate = #'TBSCertificate'
        { version = 'v3'
        , serialNumber = serial()
        , signature = #'AlgorithmIdentifier'
          { algorithm = ?sha256WithRSAEncryption
          , parameters = <<5,0>>
          }
        , issuer = Issuer
        , validity = Validity
        , subject = Subject
        , subjectPublicKeyInfo = SubjectPublicKeyInfo
        , issuerUniqueID = 'asn1_NOVALUE'
        , subjectUniqueID = 'asn1_NOVALUE'
        , extensions = Ext
        },
    Message = public_key:der_encode('TBSCertificate', TBSCertificate),
    Signature = public_key:sign(Message, 'sha256', IssuerPrivateKey),
    #'Certificate'
        { tbsCertificate = TBSCertificate
        , signatureAlgorithm = #'AlgorithmIdentifier'
          { algorithm = ?sha256WithRSAEncryption
          , parameters = <<5,0>>
          }
        , signature = Signature
        }.

-spec subject(cert()) -> {'ok', subject(), pub_key()}.
subject(Certificate = #'Certificate'{}) ->
    #'Certificate'
        { tbsCertificate = TBSCertificate
        , signatureAlgorithm = #'AlgorithmIdentifier'
          { algorithm = Algorithm }
        } = Certificate,
    case Algorithm of
        ?sha256WithRSAEncryption ->
            'true';
        ?sha1WithRSAEncryption ->
            'true'
    end,
    #'TBSCertificate'
        { subject = Subject
        , subjectPublicKeyInfo = PublicKeyInfo
        } = TBSCertificate,
    #'SubjectPublicKeyInfo'
        { algorithm = #'AlgorithmIdentifier'
          { algorithm = ?rsaEncryption }
        , subjectPublicKey = PublicKeyDER
        } = PublicKeyInfo,
    PublicKey = der_to_public_key(PublicKeyDER),
    {'ok', Subject, PublicKey}.

-spec to_der(cert()) -> binary().
to_der(Certificate = #'Certificate'{}) ->
    public_key:der_encode('Certificate', Certificate).

-spec to_pem(cert()) -> binary().
to_pem(Certificate = #'Certificate'{}) ->
    DER = to_der(Certificate),
    PEMEntry = {'Certificate', DER, 'not_encrypted'},
    public_key:pem_encode([PEMEntry]).

-spec to_file(Cert, Filename) -> 'ok' | {'error', Reason} when
      Cert :: cert() | [cert()],
      Filename :: file:filename_all(),
      Reason :: file:posix() | 'badarg' | 'terminated' | 'system_limit'.
to_file(Certificates, FileName)
  when is_list(Certificates) ->
    PEMEntries = [{'Certificate', to_der(Certificate), 'not_encrypted'} || Certificate <- Certificates],
    PEM = public_key:pem_encode(PEMEntries),
    file:write_file(FileName, PEM);
to_file(Certificate = #'Certificate'{}, FileName) ->
    DER = to_der(Certificate),
    PEMEntry = {'Certificate', DER, 'not_encrypted'},
    PEM = public_key:pem_encode([PEMEntry]),
    file:write_file(FileName, PEM).

-spec to_file(Cert, PrivateKey, Filename) -> 'ok' | {'error', Reason} when
      Cert :: cert(),
      PrivateKey :: priv_key(),
      Filename :: file:filename_all(),
      Reason :: file:posix() | 'badarg' | 'terminated' | 'system_limit'.
to_file(Certificate = #'Certificate'{}, #'RSAPrivateKey'{}=PrivateKey, FileName) ->
    DER = to_der(Certificate),
    PEMEntry = {'Certificate', DER, 'not_encrypted'},
    PEM = public_key:pem_encode([PEMEntry]),
    PKPEM = kz_auth_keys:to_pem(PrivateKey),
    case file:write_file(FileName, PKPEM) of
        'ok' -> file:write_file(FileName, PEM, ['append']);
        Error -> Error
    end.

-spec verify(cert(), pub_key()) -> {'ok', subject(), pub_key()} | {'error', 'verify_failed'}.
verify(Certificate = #'Certificate'{}, IssuerPublicKey = #'RSAPublicKey'{}) ->
    #'Certificate'{tbsCertificate = TBSCertificate
                  ,signatureAlgorithm = #'AlgorithmIdentifier'{algorithm = ?sha256WithRSAEncryption}
                  ,signature = Signature
                  } = Certificate,
    #'TBSCertificate'{subject = Subject
                     ,subjectPublicKeyInfo = PublicKeyInfo
                     } = TBSCertificate,
    #'SubjectPublicKeyInfo'{algorithm = #'AlgorithmIdentifier'{algorithm = ?rsaEncryption}
                           ,subjectPublicKey = PublicKeyDER
                           } = PublicKeyInfo,
    PublicKey = der_to_public_key(PublicKeyDER),
    Message = public_key:der_encode('TBSCertificate', TBSCertificate),
    case public_key:verify(Message, 'sha256', Signature, IssuerPublicKey) of
        'true' -> {'ok', Subject, PublicKey};
        'false' -> {'error', 'verify_failed'}
    end.

-spec from_der(binary()) -> cert().
from_der(DER)
  when is_binary(DER) ->
    #'Certificate'{} = public_key:der_decode('Certificate', DER).

-spec der_to_public_key(binary()) -> pub_key().
der_to_public_key(DER)
  when is_binary(DER) ->
    #'RSAPublicKey'{} = public_key:der_decode('RSAPublicKey', DER).

-spec public_key(cert()) -> pub_key().
public_key(Certificate = #'Certificate'{}) ->
    #'Certificate'{tbsCertificate = TBSCertificate} = Certificate,
    #'TBSCertificate'{subjectPublicKeyInfo = PublicKeyInfo} = TBSCertificate,
    #'SubjectPublicKeyInfo'{algorithm = #'AlgorithmIdentifier'{algorithm = ?rsaEncryption}
                           ,subjectPublicKey = PublicKeyDER
                           } = PublicKeyInfo,
    der_to_public_key(PublicKeyDER).

-spec from_file(file:filename_all()) -> cert().
from_file(FileName) ->
    {'ok', PEM} = file:read_file(FileName),
    from_pem(PEM).

-spec from_pem(binary()) -> cert().
from_pem(PEM) ->
    [PEMEntry] = public_key:pem_decode(PEM),
    {'Certificate', DER, 'not_encrypted'} = PEMEntry,
    from_der(DER).

-spec public_key_to_der(pub_key()) -> binary().
public_key_to_der(PublicKey = #'RSAPublicKey'{}) ->
    public_key:der_encode('RSAPublicKey', PublicKey).

%% Internal API

datetime_to_utc_time({{Y, M, D}, {H, N, S}}) when Y >= 2000 ->
    IOList = io_lib:format("~2.10.0B~2.10.0B~2.10.0B~2.10.0B~2.10.0B~2.10.0BZ", [Y-2000, M, D, H, N, S]),
    {'utcTime', lists:flatten(IOList)}.

minute_before({Date, {0,0,_}}) ->
    {Date, {0,0,0}};
minute_before({Date, {H,0,_}}) ->
    {Date, {H-1,59,0}};
minute_before({Date, {H,N,_}}) ->
    {Date, {H,N-1,0}}.

validity(Days) ->
    Now = calendar:universal_time(),
    Start = minute_before(Now),
    {Date, Time} = Start,
    StartDays = calendar:date_to_gregorian_days(Date),
    EndDays = StartDays + Days,
    End = {calendar:gregorian_days_to_date(EndDays), Time},
    #'Validity'{notBefore = datetime_to_utc_time(Start)
               ,notAfter = datetime_to_utc_time(End)
               }.

-spec cn(string() | binary()) -> subject().
cn(Name) ->
    Opts = [{'name',  Name}],
    subject_encode(Opts).

-spec subject_encode([tuple()]) -> subject().
subject_encode(SubjectOpts)
  when is_list(SubjectOpts) ->
    Encode = fun(Opt) ->
                     {Type,Value} = subject_enc(Opt),
                     Attr = #'AttributeTypeAndValue'{type=Type, value=Value},
                     [pubkey_cert_records:transform(Attr, 'encode')]
             end,
    {'rdnSequence', [Encode(Opt) || Opt <- SubjectOpts]}.

subject_enc({'name',  Name}) ->
    {?'id-at-commonName', {'printableString', Name}};
subject_enc({'email', Email}) ->
    {?'id-emailAddress', Email};
subject_enc({'city',  City}) ->
    {?'id-at-localityName', {'printableString', City}};
subject_enc({'org', Org}) ->
    {?'id-at-organizationName', {'printableString', Org}};
subject_enc({'org_unit', OrgUnit}) ->
    {?'id-at-organizationalUnitName', {'printableString', OrgUnit}};
subject_enc({'country', Country}) ->
    {?'id-at-countryName', Country};
subject_enc({'account_id', AccountId}) ->
    S = byte_size(AccountId),
    {?'id-at-2600hz-accountId', <<19, S, (kz_term:to_binary(AccountId))/binary>>};
subject_enc({'endpoint_id', EndpointId}) ->
    S = byte_size(EndpointId),
    {?'id-at-2600hz-endpointId', <<19, S, (kz_term:to_binary(EndpointId))/binary>>}.

-spec fingerprints(cert() | priv_key() | pub_key()) -> {binary(), binary()}.
fingerprints(Certificate = #'Certificate'{}) ->
    DER = public_key:der_encode('Certificate', Certificate),
    SHA = crypto:hash('sha', DER),
    SHA256 = crypto:hash('sha256', DER),
    {kz_term:to_upper_binary(hexencode(SHA)), kz_term:to_upper_binary(hexencode(SHA256))};
fingerprints(PrivateKey = #'RSAPrivateKey'{}) ->
    PublicKey = kz_auth_keys:get_public_key_from_private_key(PrivateKey),
    fingerprints(PublicKey);
fingerprints(PublicKey = #'RSAPublicKey'{}) ->
    DER = public_key:der_encode('RSAPublicKey', PublicKey),
    SHA = crypto:hash('sha', DER),
    SHA256 = crypto:hash('sha256', DER),
    {kz_term:to_upper_binary(hexencode(SHA)), kz_term:to_upper_binary(hexencode(SHA256))}.

-spec hexencode(kz_term:text()) -> binary().
hexencode(<<_/binary>> = Bin) ->
    hexencode(Bin, []);
hexencode(S) ->
    hexencode(kz_term:to_binary(S)).

hexencode(<<>>, Acc) -> kz_binary:join(lists:reverse(Acc), <<":">>);
hexencode(<<Hi:4, Lo:4, Rest/binary>>, Acc) ->
    hexencode(Rest
             ,[list_to_binary([kz_term:to_hex_char(Hi)
                              ,kz_term:to_hex_char(Lo)
                              ])
              | Acc
              ]
             ).

-spec 'id-at-2600hz'() -> public_key:oid().
'id-at-2600hz'() -> {1,3,6,1,4,1,41246}.

-spec 'id-at-2600hz-accountId'() -> public_key:oid().
'id-at-2600hz-accountId'() -> {1,3,6,1,4,1,41246,1}.

-spec 'id-at-2600hz-endpointId'() -> public_key:oid().
'id-at-2600hz-endpointId'() -> {1,3,6,1,4,1,41246,2}.

serial() ->
    serial(3).

serial(Size) ->
    <<I:Size/unsigned-integer-unit:8>> = crypto:strong_rand_bytes(Size),
    I.

ca_extensions() ->
    [key_usage(['keyCertSign', 'cRLSign'])
    ,basic_contraints('true')
    ].

basic_contraints(CA) ->
    #'Extension'{extnID = ?'id-ce-basicConstraints'
                ,extnValue = #'BasicConstraints'{cA = CA}
                ,critical = 'true'
                }.

key_usage(Bits) ->
    {'ok', Value} = 'OTP-PUB-KEY':encode('KeyUsage', Bits),
    #'Extension'{extnID = ?'id-ce-keyUsage'
                ,extnValue = Value
                ,critical = 'false'
                }.

authority_key_identifier(PK) ->
    {_, Key} = fingerprints(PK),
    #'Extension'{extnID = ?'id-ce-authorityKeyIdentifier'
                ,extnValue = #'AuthorityKeyIdentifier'{keyIdentifier = Key}
                }.

subject_key_identifier(PK) ->
    {_, Key} = fingerprints(PK),
    {'ok', Value} = 'OTP-PUB-KEY':encode('SubjectKeyIdentifier', Key),
    #'Extension'{extnID = ?'id-ce-subjectKeyIdentifier'
                ,extnValue = Value
                }.

encode_extensions(Extensions) ->
    lists:map(fun encode_extension/1, Extensions).

encode_extension(#'Extension'{extnValue=Value0} = Extension)
  when is_tuple(Value0)->
    Type = element(1, Value0),
    {'ok', Value} = 'OTP-PUB-KEY':encode(Type, Value0),
    Extension#'Extension'{extnValue=Value};
encode_extension(#'Extension'{} = Extension) -> Extension.
