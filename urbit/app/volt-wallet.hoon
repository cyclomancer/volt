::  volt-wallet.hoon
::
::
/-  *volt, *bitcoin
/+  bip32, bip39, bc=bitcoin
/+  commit=commitment-secret
/+  server, default-agent, dbug
=,  ecc=secp256k1:secp:crypto
|%
+$  card  card:agent:gall
::
+$  wall  [prv=@ pub=point.ecc cad=@ dep=@ud ind=@ud pif=@]
::
+$  point  point:secp:crypto
::
+$  state-0
  $:  %0
      =wall
  ==
::
+$  versioned-state
  $%  state-0
  ==
--
::
%-  agent:dbug
=|  state-0
=*  state  -
^-  agent:gall
=<
|_  =bowl:gall
+*  this  .
    def  ~(. (default-agent this %|) bowl)
    hc   ~(. +> bowl)
::
++  on-init
  ^-  (quip card _this)
  `this(state *state-0)
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  `this(state !<(versioned-state old-state))
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =^  cards  state
  ?+    mark  (on-poke:def mark vase)
      %volt-wallet-action
    ~|  "volt-wallet: blocked poke {<src.bowl>}"
    ?>  (team:title our.bowl src.bowl)
    (handle-action:hc !<(action:wallet vase))
  ==
  [cards this]
::
++  on-arvo  on-arvo:def
++  on-agent  on-agent:def
++  on-peek  on-peek:def
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail  on-fail:def
--
::
|_  =bowl:gall
++  handle-action
  |=  =action:wallet
  ^-  (quip card _state)
  ?-    -.action
      %new-wallet
    |^
    ~|  "volt-wallet: blocked wallet modification {<src.bowl>}"
    ?>  =(src.bowl our.bowl)
    `state(wall new-wallet)
    ::
    ++  new-wallet
      :*  prv:wallet
          pub:wallet
          cad:wallet
          dep:wallet
          ind:wallet
          pif:wallet
      ==
    ::
    ++  wallet
      ~+  %-  ~(from-seed bip32 wall)
        ?~  seed.action
          (generate-seed)
        u.seed.action
    ::
    ++  generate-seed
      |.
      :-  32
      %-  ~(rad og eny.bowl)
      %-  bex  256
    --
  ::
      %get-public-keys
    =/  pubkey=hexb:bc  (get-public-key path.action)
    :_  state
    ~[(send-result [%public-key path.action pubkey])]
  ::
      %get-address
    =/  =address:bc  (get-address path.action)
    :_  state
    ~[(send-result [%address path.action address])]
  ::
      %sign-digest
    =/  sig=hexb:bc  (sign-digest path.action hash.action)
    :_  state
    ~[(send-result [%signature path.action sig])]
  ::
      %get-commit-point
    =/  =point  (get-commit-point path.action idx.action)
    :_  state
    ~[(send-result [%point path.action point])]
  ::
      %get-commit-secret
    =/  secret=@  (get-commit-secret path.action idx.action)
    :_  state
    ~[(send-result [%secret path.action secret])]
  ==
::
++  get-public-keys
  |=  paths=(list pax)
  ^-  (list byts)
  =|  i=@u
  |-
  ?:  =(i (lent paths))
  :-  33
  public-key:(~(derive-sequence bip32 wall) pax)
::
++  get-address
  |=  =pax
  ^-  address
  %^    from-pubkey:adr:bc
      %44
    %main
  %-  get-public-key
    pax
::
++  sign-digest
  |=  [=pax hash=hexb:bc]
  ^-  hexb:bc
  =/  key=@  prv:(~(derive-sequence bip32 wall) pax)
  =+  (ecdsa-raw-sign:ecc ^-(@ dat:hash) key)
  %-  cat:byt:bcu:bc
  :~  [wid=32 dat=r]
      [wid=32 dat=s]
      [wid=1 dat=v]
  ==
::
++  get-commit-point
  |=  [=pax i=@]
  ^-  point
  =/  seed=@  prv:(~(derive-sequence bip32 wall) pax)
  %-  compute-commitment-point:commit
  (get-commit-secret [seed i])
::
++  get-commit-secret
  |=  [=pax i=@]
  ^-  commit-secret:commit
  (generate-from-seed:commit [seed i ~])
::
++  send-result
  |=  =result:wallet
  ^-  card
  :*  %pass   /wallet
      %agent  [src.bowl %volt]
      %poke   %volt-wallet-result  !>(result)
  ==
--
