::  volt.hoon
::  Lightning channel management agent
::
/-  *volt, btc-provider
/+  default-agent, dbug
/+  bc=bitcoin, bolt11, bip-b158
/+  revocation=revocation-store, tx=transactions
/+  key-gen=key-generation, secret=commitment-secret
/+  bolt=utilities, channel, psbt, ring, sweep
|%
+$  card  card:agent:gall
+$  versioned-state
  $%  state-0
  ==
::
+$  provider-state  [host=ship connected=?]
::
+$  coop-close-state
  $:  initiator=ship
      max-fee=sats:bc
      our-fee=sats:bc
      her-fee=sats:bc
      our-sig=hexb:bc
      her-sig=hexb:bc
      our-script=hexb:bc
      her-script=hexb:bc
      close-height=@
  ==
::
+$  force-close-state
  $:  initiator=ship
      penalty=?
      =commitment:bolt
      close-height=@
  ==
+$  outpoint  [txid=hexb:bc idx=@]
+$  pending-timelock
  $:  height=@ud
      tx=psbt:psbt
      keys=(unit pair:key:bolt)
  ==
::
+$  state-0
  $:  %0
      $=  keys
      $:  our=pair:key:bolt
          chal=(map ship @)
          their=(map pubkey:bolt ship)
      ==
      $=  prov
      $:  btcp=(unit provider-state)
          volt=(unit provider-state)
          info=node-info
      ==
      $=  chan
      $:  live=(map id:bolt chan:bolt)
          larv=(map id:bolt larva-chan:bolt)
          fund=(map id:bolt psbt:psbt)
          peer=(map ship (set id:bolt))
          wach=(map hexb:bc id:bolt)
          htlc=(map outpoint psbt:psbt)
          shut=(map id:bolt coop-close-state)
          dead=(map id:bolt force-close-state)
      ==
      $=  chain
      $:  block=@ud
          fees=(unit sats:bc)
          time=@da  :: TODO use $time instead of @da because bunt is unix convertible - EVERYWHERE using @da
      ==
      $=  payments
      $:  outgoing=(map hexb:bc forward-request)
          incoming=(map hexb:bc payment-request)
          preimages=(map hexb:bc hexb:bc)
          onchain=(map hexb:bc pending-timelock)
          waiting=(map htlc-id:bolt psbt:psbt)
      ==
  ==
--
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
  =+  seed=(~(rad og eny.bowl) (bex 256))
  ::  TODO: already have *state-0 (state)
  =+  keypair=(generate-keypair:key-gen seed %main %node-key)
  =+  state=*state-0
  ~&  >  '%volt initialized successfully'
  `this(state state(our.keys keypair))
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-state=vase
  ^-  (quip card _this)
  ~&  >  '%volt recompiled successfully'
  `this(state !<(versioned-state old-state))
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  =^  cards  state
    ?+    mark  (on-poke:def mark vase)
        %volt-command
      ?>  (team:title our.bowl src.bowl)
      (handle-command:hc !<(command vase))
    ::
        %volt-action
      ?<  =((clan:title src.bowl) %pawn)
      (handle-action:hc !<(action vase))
    ::
        %volt-message
      ?<  =((clan:title src.bowl) %pawn)
      (handle-message:hc !<(message:bolt vase))
    ==
  [cards this]
::  per the precepts, route on wire before sign
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+    -.sign  (on-agent:def wire sign)
      ::  TODO: wire then sign
      %kick  :: TODO: rewrite as ?+
    ?:  ?=(%set-provider -.wire)
      :_  this(volt.prov [~ src.bowl %.n])
      (watch-provider:hc src.bowl)
    ::
    ?:  ?=(%set-btc-provider -.wire)
      :_  this(btcp.prov [~ src.bowl %.n])
      (watch-btc-provider:hc src.bowl)
    ::
    `this
  ::  TODO: potential injection attack, validate that marks come in on their correct wires
      %fact
    =^  cards  state
      ?+    p.cage.sign  `state
          %volt-provider-status
        (handle-provider-status:hc !<(status:provider q.cage.sign))
      ::
          %volt-provider-update
        (handle-provider-update:hc !<(update:provider q.cage.sign))
      ::
          %btc-provider-status
        (handle-bitcoin-status:hc !<(status:btc-provider q.cage.sign))
      ::
          %btc-provider-update
        (handle-bitcoin-update:hc !<(update:btc-provider q.cage.sign))
      ==
    [cards this]
  ::  TODO: inclue src.bowl for debugging, rewrite as ?+
      %watch-ack
    ?:  ?=(%set-provider -.wire)
      ?~  p.sign
        `this
      =/  =tank  leaf+"subscribe to provider {<dap.bowl>} failed"
      %-  (slog tank u.p.sign)
      `this(volt.prov ~)
    ::
    ?:  ?=(%set-btc-provider -.wire)
      ?~  p.sign
        `this
      =/  =tank  leaf+"subscribe to btc provider {<dap.bowl>} failed"
      %-  (slog tank u.p.sign)
      `this(btcp.prov ~)
    ::
    `this
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+    path  (on-watch:def path)
      [%all ~]
    ?>  (team:title our.bowl src.bowl)
    `this
  ==
::
++  on-arvo   on-arvo:def
++  on-peek   on-peek:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
::
|_  =bowl:gall
++  handle-command
  |=  =command
  |^  ^-  (quip card _state)
  ?-    -.command
      %set-provider
    ?~  provider.command
      ?~  volt.prov  `state
      :_  state(volt.prov ~)
      (leave-provider host.u.volt.prov)
    ::
    :_  state(volt.prov `[u.provider.command %.n])
    ?~  volt.prov  (watch-provider u.provider.command)
    %-  zing
    :~  (leave-provider host.u.volt.prov)
        (watch-provider u.provider.command)
    ==
  ::
      %set-btc-provider
    ?:  =(provider.command btcp.prov)  `state
    ?~  provider.command
      ?~  btcp.prov  `state
      :_  state(btcp.prov ~)
      (leave-btc-provider host.u.btcp.prov)
    ::
    :_  state(btcp.prov `[u.provider.command %.n])
    ?~  btcp.prov  (watch-btc-provider u.provider.command)
    %-  zing
    :~  (leave-btc-provider host.u.btcp.prov)
        (watch-btc-provider u.provider.command)
    ==
  ::
      %open-channel
    (open-channel +.command)
  ::
      %create-funding
    (create-funding +.command)
  ::
      %close-channel
    (close-channel +.command)
  ::
      %send-payment
    (send-payment +.command)
  ::
      %add-invoice
    (add-invoice +.command)
  ==
  ++  open-channel
    |=  [who=ship =funding=sats:bc =push=msats =network:bolt]
    ^-  (quip card _state)
    ?~  btcp.prov  :: TODO: larval core pattern, avoid these checks everywhere
      ~&  >>>  "%volt: no btc-provider set"
      `state
    ?:  (gth funding-sats max-funding-sats:const:bolt)
      ~|  "%volt: must set funding-sats to less than 2^24 sats"
        !!
    ?:  (gth push-msats (sats-to-msats:bolt funding-sats))
      ~|  "%volt: must set push-msats to less than or equal 1000*funding-sats"
        !!
    ?:  (lth funding-sats min-funding-sats:const:bolt)
      ~|  "%volt: funding-sats too low {<funding-sats>} < {<min-funding-sats:const:bolt>}"
        !!
    =/  rng  ~(. og eny.bowl)
    =^  tmp-id  rng  (rads:rng (bex 256))
    =^  seed    rng  (rads:rng (bex 256))
    =^  chal    rng  (rads:rng (bex 256))
    =/  local-config=local-config:bolt
      (make-local-config seed network funding-sats push-msats %.y)
    =+  feerate=(current-feerate-per-kw)
    =/  first-per-commitment-secret=@
      %^    generate-from-seed:secret
          per-commitment-secret-seed.local-config
        first-index:secret
      ~
    =|  oc=open-channel:msg:bolt
    =.  oc
      %=  oc
        temporary-channel-id            tmp-id
        chain-hash                      (network-chain-hash:bolt network)
        funding-sats                    funding-sats
        push-msats                      push-msats
        funding-pubkey                  pub.multisig-key.local-config
        dust-limit-sats                 dust-limit-sats.local-config
        max-htlc-value-in-flight-msats  max-htlc-value-in-flight-msats.local-config
        channel-reserve-sats            reserve-sats.local-config
        htlc-minimum-msats              htlc-minimum-msats.local-config
        feerate-per-kw                  feerate
        to-self-delay                   to-self-delay.local-config
        max-accepted-htlcs              max-accepted-htlcs.local-config
        pub.revocation.basepoints       pub.revocation.basepoints.local-config
        pub.htlc.basepoints             pub.htlc.basepoints.local-config
        pub.payment.basepoints          pub.payment.basepoints.local-config
        pub.delayed-payment.basepoints  pub.delayed-payment.basepoints.local-config
        anchor-outputs                  anchor-outputs.local-config
        first-per-commitment-point      %-  compute-commitment-point:secret
                                             first-per-commitment-secret
        shutdown-script-pubkey          upfront-shutdown-script.local-config
      ==
    =|  lar=larva-chan:bolt
    =.  lar
      %=  lar
        initiator   %.y
        ship.her    who
        our         local-config
        oc          `oc
      ==
    :_  %=  state
          larv.chan  (~(put by larv.chan) tmp-id lar)
          chal.keys  (~(put by chal.keys) who chal)
        ==
    :~  (send-message [%open-channel oc] who)
        (volt-action [%give-pubkey chal] who)
    ==
  ::
  ++  create-funding
    |=  [temporary-channel-id=@ psbt=@t]
    ^-  (quip card _state)
    =/  c=(unit larva-chan:bolt)
      (~(get by larv.chan) temporary-channel-id)
    ?~  c
      ~&  >>>  "%volt: no channel with id: {<temporary-channel-id>}"
      `state
    ?~  oc.u.c
      ~&  >>>  "%volt: invalid channel state: {<temporary-channel-id>}"
      `state
    ?~  ac.u.c
      ~&  >>>  "%volt: invalid channel state: {<temporary-channel-id>}"
      `state
    ~|  %invalid-funding-tx
    =/  funding-tx=(unit psbt:^psbt)
      (from-base64:create:^psbt psbt)
    ?>  ?=(^ funding-tx)
    ::  TODO: check tx is complete
    ::
    =/  funding-output=output:^psbt
      ::  (funding-output:tx [pub.multisig-key.our pub.multisig-key.her funding-sats.u.oc]:u.c)
      %^    funding-output:tx
          pub.multisig-key.our.u.c
        pub.multisig-key.her.u.c
      funding-sats.u.oc.u.c
    ::
    =/  funding-out-pos=(unit @u)
      =+  outs=vout.u.funding-tx
      =+  i=0
      |-
      ?~  outs  ~
      =+  out=(head outs)  :: use i.outs
      ?:  ?&  =(value.out value.funding-output)
              =(script-pubkey.out script-pubkey.funding-output)
          ==
        (some i)
      $(outs (tail outs), i +(i))
    ?>  ?=(^ funding-out-pos)
    ::
    =+  funding-txid=(txid:^psbt (extract-unsigned:^psbt u.funding-tx))
    %-  (slog leaf+"funding-txid={<funding-txid>}" ~)
    ::
    =+  ^=  new-channel  :: just use =/
      ^-  chan:bolt
      %:  new:channel    :: shorten "documentation" faces, and/or move to comment
        local-channel-config=our.u.c
        remote-channel-config=her.u.c
        funding-outpoint=[funding-txid u.funding-out-pos funding-sats.u.oc.u.c]
        initial-feerate=feerate-per-kw.u.oc.u.c
        initiator=initiator.u.c
        anchor-outputs=anchor-outputs.our.u.c
        capacity=funding-sats.u.oc.u.c
        funding-tx-min-depth=minimum-depth.u.ac.u.c
      ==
    =^  sig  new-channel
      %-  ~(sign-first-commitment channel new-channel)
      first-per-commitment-point.u.ac.u.c
    ::
    =|  =funding-created:msg:bolt
    =.  funding-created
      %=  funding-created
        temporary-channel-id  temporary-channel-id
        funding-txid          funding-txid
        funding-idx           u.funding-out-pos
        signature             sig
      ==
    :_  %=  state
          larv.chan  (~(del by larv.chan) temporary-channel-id)
          live.chan  (~(put by live.chan) id.new-channel new-channel)
          fund.chan  (~(put by fund.chan) id.new-channel u.funding-tx)
        ==
    ~[(send-message [%funding-created funding-created] ship.her.u.c)]
  ::
  ++  close-channel
    |=  =chan-id
    ^-  (quip card _state)
    ?:  (~(has by shut.chan) chan-id)
      ~&  >>>  "%volt: channel already closing"
      `state  :: should probably crash,
    =+  c=(~(get by live.chan) chan-id)
    ?~  c  `state :: should probably crash, or at least report
    =|  close=coop-close-state
    =.  close
      %=  close
        initiator   our.bowl
        our-script  ~(shutdown-script channel u.c)
      ==
    =^  cards  u.c  (send-shutdown u.c close)
    :-  cards
    %=  state
      live.chan  (~(put by live.chan) chan-id u.c)
      shut.chan  (~(put by shut.chan) chan-id close)
    ==
  :: TODO: formalise error handling to the client, possibly an /errors subscription
  :: also ensure no state is modified after error processing - subsidiary to nested core rewrite
  ++  send-payment
    |=  =payreq
    ^-  (quip card _state)
    ?~  btcp.prov  `state
    =+  invoice=(de:bolt11 payreq)
    ?~  invoice
      ~&  >>>  "%volt: invalid payreq"
      `state
    ?~  amount.u.invoice
      ~&  >>>  "%volt: payreq didn't specify amount"
      `state
    =+  amount-msats=(amount-to-msats:bolt11 u.amount.u.invoice)
    ?:  =(0 amount-msats)
      ~&  >>>  "%volt: payreq amount is below 1 msat"
      `state
    =+  pubkey-point=(decompress-point:secp256k1:secp:crypto dat.pubkey.u.invoice)
    =/  who=(unit @p)
      (~(get by their.keys) pubkey-point)
    =+  req=(~(get by incoming.payments) payment-hash.u.invoice)
    ?~  who
      ::  unrecognized payee pubkey
      ::
      ?:  own-provider
        ?~  req
          ::  not one of ours, have LND send it
          ::    TODO: fee-limit and timeout?
          ::
          :_  state
          ~[(provider-command [%send-payment payreq ~ ~])]
        ::  internalize the payment and cancel the invoice in LND
        ::
        (pay-ship payee.u.req amount-msats payment-hash.u.invoice)
      ::  try asking provider
      ::
      (forward-to-provider payreq)
    =+  chan-ids=(~(get by peer.chan) u.who)
    ?~  chan-ids
      ::  no direct channel, try asking provider
      ::
      (forward-to-provider payreq)
    =+  channel=(find-channel-with-capacity u.chan-ids amount-msats)
    ?~  channel
      ::  no bilateral capacity, try asking provider
      ::
      (forward-to-provider payreq)
    (pay-channel u.channel amount-msats payment-hash.u.invoice)
  ::
  ++  pay-ship
    |=  [who=@p =amount=msats =payment=hash]
    ^-  (quip card _state)
    =+  ids=(~(get by peer.chan) who)
    ?~  ids
      ~&  >>>  "%volt: no channels with {<who>}"
      `state
    =+  c=(find-channel-with-capacity u.ids amount-msats)
    ?~  c
      ~&  >>>  "%volt: insufficient capacity with {<who>}"
      `state
    (pay-channel u.c amount-msats payment-hash)
  ::
  ++  forward-to-provider
    |=  =payreq
    ^-  (quip card _state)
    ?~  volt.prov
      ~&  >>>  "%volt: no provider configured"
      `state
    =+  provider-channels=(~(get by peer.chan) host.u.volt.prov)
    ?~  provider-channels
      ~&  >>>  "%volt: no channel with provider"
      `state
    =+  invoice=(de:bolt11 payreq)
    ?~  invoice           !!
    ?~  amount.u.invoice  !!
    =+  amount-msats=(amount-to-msats:bolt11 u.amount.u.invoice)
    =+  c=(find-channel-with-capacity u.provider-channels amount-msats)
    ?~  c
      ~&  >>>  "%volt: insufficient capacity with provider"
      `state
    ?>  =(state.u.c %open)
    =+  final-cltv=(add block.chain min-final-cltv-expiry:const:bolt)
    =|  update=update-add-htlc:msg:bolt
    =.  update
      %=  update
        channel-id    id.u.c
        payment-hash  payment-hash.u.invoice
        amount-msats  amount-msats
        cltv-expiry   final-cltv
      ==
    =^  htlc   u.c  (~(add-htlc channel u.c) update)
    =^  cards  u.c  (maybe-send-commitment u.c)
    :_  state(live.chan (~(put by live.chan) id.u.c u.c))
    [(volt-action [%forward-payment payreq htlc] host.u.volt.prov) cards]
  ::
  ++  add-invoice
    |=  [=amount=msats memo=(unit @t) network=(unit network:bolt)]
    ?~  volt.prov  !!
    =/  rng  ~(. og eny.bowl)
    =^  preimage  rng  (rads:rng (bex 256))
    =+  hash=(sha256:bcu:bc 32^preimage)
    =|  req=payment-request
    :_  %=    state
          preimages.payments
        (~(put by preimages.payments) hash 32^preimage)
      ::
          incoming.payments
        %+  ~(put by incoming.payments)  hash
        %=  req
          payee         our.bowl
          amount-msats  amount-msats
          payment-hash  hash
          preimage      `32^preimage
        ==
      ==
    ::  own provider: poke provider agent
    ::
    ?:  own-provider
      ~[(provider-action [%add-hold-invoice amount-msats memo hash ~])]
    ::  external provider: poke provider for hold invoice
    ::
    ~[(volt-action [%give-invoice amount-msats hash memo network] host.u.volt.prov)]
  --
::
++  handle-message
  |=  =message:bolt
  |^  ^-  (quip card _state)
  =^  cards  state
    ?-    -.message
    ::
    ::::  +-------+                              +-------+
      ::  |       |--(1)---  open_channel  ----->|       |
      ::  |       |<-(2)--  accept_channel  -----|       |
      ::  |       |                              |       |
      ::  |   A   |--(3)--  funding_created  --->|   B   |
      ::  |       |<-(4)--  funding_signed  -----|       |
      ::  |       |                              |       |
      ::  |       |--(5)--- funding_locked  ---->|       |
      ::  |       |<-(6)--- funding_locked  -----|       |
    ::::  +-------+                              +-------+
    ::
        %open-channel
      (handle-open-channel +.message)
    ::
        %accept-channel
      (handle-accept-channel +.message)
    ::
        %funding-created
      (handle-funding-created +.message)
    ::
        %funding-signed
      (handle-funding-signed +.message)
    ::
        %funding-locked
      (handle-funding-locked +.message)
    ::
    ::::  +-------+                               +-------+
      ::  |       |--(1)---- update_add_htlc ---->|       |
      ::  |       |--(2)---- update_add_htlc ---->|       |
      ::  |       |<-(3)---- update_add_htlc -----|       |
      ::  |       |                               |       |
      ::  |       |--(4)--- commitment_signed --->|       |
      ::  |   A   |<-(5)---- revoke_and_ack ------|   B   |
      ::  |       |                               |       |
      ::  |       |<-(6)--- commitment_signed ----|       |
      ::  |       |--(7)---- revoke_and_ack ----->|       |
      ::  |       |                               |       |
      ::  |       |--(8)--- commitment_signed --->|       |
      ::  |       |<-(9)---- revoke_and_ack ------|       |
    ::::  +-------+                               +-------+
    ::
        %update-add-htlc
      (handle-update-add-htlc +.message)
    ::
        %commitment-signed
      (handle-commitment-signed +.message)
    ::
        %revoke-and-ack
      (handle-revoke-and-ack +.message)
    ::
    ::::  +-------+                              +-------+
      ::  |       |--(1)-----  shutdown  ------->|       |
      ::  |       |<-(2)-----  shutdown  --------|       |
      ::  |       |                              |       |
      ::  |       | <complete all pending HTLCs> |       |
      ::  |   A   |                 ...          |   B   |
      ::  |       |                              |       |
      ::  |       |--(3)-- closing_signed  F1--->|       |
      ::  |       |<-(4)-- closing_signed  F2----|       |
      ::  |       |              ...             |       |
      ::  |       |--(?)-- closing_signed  Fn--->|       |
      ::  |       |<-(?)-- closing_signed  Fn----|       |
    ::::  +-------+                              +-------+
    ::
        %shutdown
      (handle-shutdown +.message)
    ::
        %closing-signed
      (handle-closing-signed +.message)
    ::
        %update-fulfill-htlc
      (handle-update-fulfill-htlc +.message)
    ::
        %update-fail-htlc
      (handle-update-fail-htlc +.message)
    ::
        %update-fail-malformed-htlc
      (handle-update-fail-malformed-htlc +.message)
    ::
        %update-fee
      (handle-update-fee +.message)
    ==
  [cards state]
  ::
  ++  handle-open-channel
    |=  =open-channel:msg:bolt
    ^-  (quip card _state)
    =+  open-channel :: TODO: use =,
    ::  todo: factor out constraints w/ command
    ?:  (gth funding-sats max-funding-sats:const:bolt)
      ~|  "%volt: must set funding-sats to less than 2^24 sats"
        !!
    ?:  (gth push-msats (sats-to-msats:bolt funding-sats))
      ~|  "%volt: must set push-msats to less than or equal 1000*funding-sats"
        !!
    ?:  (lth funding-sats min-funding-sats:const:bolt)
      ~|  "%volt: funding-sats too low {<funding-sats>} < {<min-funding-sats:const:bolt>}"
        !!
    ::
    =+  network=(chain-hash-network:bolt chain-hash)
    =/  rng  ~(. og eny.bowl)
    =^  seed  rng  (rads:rng (bex 256))
    =^  chal  rng  (rads:rng (bex 256))
    =/  local-config=local-config:bolt
      (make-local-config seed network funding-sats push-msats %.n)
    ::
    =|  =remote-config:bolt
    =.  remote-config
      %=  remote-config
        ship                            src.bowl
        network                         network
        pub.multisig-key                funding-pubkey
        basepoints                      basepoints
        to-self-delay                   to-self-delay
        dust-limit-sats                 dust-limit-sats
        max-htlc-value-in-flight-msats  max-htlc-value-in-flight-msats
        max-accepted-htlcs              max-accepted-htlcs
        initial-msats                   %+  sub
                                          (sats-to-msats:bolt funding-sats)
                                        push-msats
        reserve-sats                    channel-reserve-sats
        htlc-minimum-msats              htlc-minimum-msats
        current-per-commitment-point    first-per-commitment-point
        upfront-shutdown-script         shutdown-script-pubkey
      ==
    ::
    ~|  %incompatible-channel-configurations
    ?>  (validate-config:bolt -.remote-config funding-sats)
    ::  The receiving node MUST fail the channel if:
    ::      the funder's amount for the initial commitment transaction is not
    ::      sufficient for full fee payment.
    ::
    =+  ^=  commit-fees :: ident or use =/
      %.  %remote
      %~  got  by
      %:  commitment-fee:tx
        num-htlcs=0
        feerate=feerate-per-kw
        is-local-initiator=%.n
        anchors=%.y
        round=%.n
      ==
    ?:  (lth initial-msats.remote-config commit-fees)
      ~|("%volt: funder's amount is insufficient for full fee payment" !!)
    ::  The receiving node MUST fail the channel if:
    ::      both to_local and to_remote amounts for the initial commitment transaction are
    ::      less than or equal to channel_reserve_satoshis (see BOLT 3).
    ::
    =+  reserve-msats=(sats-to-msats:bolt channel-reserve-sats)
    ?:  ?&  (lte initial-msats.local-config reserve-msats)
            (lte initial-msats.remote-config reserve-msats)
        ==
      ~|  "%volt: both to-local and to-remote amounts are less than channel-reserve-sats"
        !!
    ::
    =+  ^=  first-per-commitment-secret
      ^-  @
      %^    generate-from-seed:secret
          per-commitment-secret-seed.local-config
        first-index:secret
      ~
    ::
    =|  =accept-channel:msg:bolt
    =.  accept-channel
      %=  accept-channel
        temporary-channel-id            temporary-channel-id
        dust-limit-sats                 dust-limit-sats.local-config
        max-htlc-value-in-flight-msats  max-htlc-value-in-flight-msats.local-config
        channel-reserve-sats            reserve-sats.local-config
        htlc-minimum-msats              htlc-minimum-msats.local-config
        minimum-depth                   3
        to-self-delay                   to-self-delay.local-config
        max-accepted-htlcs              max-accepted-htlcs.local-config
        funding-pubkey                  pub.multisig-key.local-config
        pub.revocation.basepoints       pub.revocation.basepoints.local-config
        pub.htlc.basepoints             pub.htlc.basepoints.local-config
        pub.payment.basepoints          pub.payment.basepoints.local-config
        pub.delayed-payment.basepoints  pub.delayed-payment.basepoints.local-config
        basepoints                      basepoints.local-config
        shutdown-script-pubkey          upfront-shutdown-script.local-config
        anchor-outputs                  anchor-outputs.local-config
        first-per-commitment-point      %-  compute-commitment-point:secret
                                          first-per-commitment-secret
      ==
    ::
    =|  lar=larva-chan:bolt
    =.  lar
      %=  lar
        initiator  %.n
        our        local-config
        her        remote-config
        oc         `open-channel
        ac         `accept-channel
      ==
    ::
    :_  %=  state
          larv.chan  (~(put by larv.chan) temporary-channel-id lar)
          chal.keys  (~(put by chal.keys) src.bowl chal)
        ==
    :~  (send-message [%accept-channel accept-channel] src.bowl)
        (volt-action [%give-pubkey chal] src.bowl)
    ==
  ::
  ++  handle-accept-channel
    |=  msg=accept-channel:msg:bolt
    ^-  (quip card _state)
    =/  c=(unit larva-chan:bolt)
      (~(get by larv.chan) temporary-channel-id.msg)
    ?~  c
      ~&  >>>  "%volt: %accept-channel for non-existent channel: {<temporary-channel-id.msg>}"
      `state
    ?~  oc.u.c
      ~&  >>>  "%volt: %accept-channel without %open-channel: {<temporary-channel-id.msg>}"
      `state
    ?>  =(ship.her.u.c src.bowl)
    ::
    ?.  initiator.u.c
      ~|  "%volt: initiator sent accept channel"
        !!
    ?:  (lte minimum-depth.msg 0)
      ~|  "%volt: minimum depth too low: {<minimum-depth.msg>}"
        !!
    ?:  (gth minimum-depth.msg 30)
      ~|  "%volt: minimum depth too high: {<minimum-depth.msg>}"
        !!
    ::
    =|  =remote-config:bolt
    =.  remote-config
      %=  remote-config
        ship                            ship.her.u.c
        basepoints                      basepoints.msg
        pub.multisig-key                funding-pubkey.msg
        to-self-delay                   to-self-delay.msg
        dust-limit-sats                 dust-limit-sats.msg
        max-htlc-value-in-flight-msats  max-htlc-value-in-flight-msats.msg
        max-accepted-htlcs              max-accepted-htlcs.msg
        initial-msats                   push-msats.u.oc.u.c
        reserve-sats                    channel-reserve-sats.msg
        htlc-minimum-msats              htlc-minimum-msats.msg
        current-per-commitment-point    first-per-commitment-point.msg
        upfront-shutdown-script         shutdown-script-pubkey.msg
        anchor-outputs                  anchor-outputs.msg
      ==
    ::
    ~|  %incompatible-channel-configurations
    ?>  (validate-config:bolt -.remote-config funding-sats.u.oc.u.c)
    ::  if channel_reserve_satoshis is less than dust_limit_satoshis, MUST reject the channel
    ::
    ?:  (lth reserve-sats.remote-config dust-limit-sats.our.u.c)
      ~|  "%volt: reserve-sats.remote-config < dust-limit-sats.local-config"
        !!
    ::  if channel_reserve_satoshis is less than dust_limit_satoshis, MUST reject the channel
    ::
    ?:  (lth reserve-sats.our.u.c dust-limit-sats.remote-config)
      ~|  "%volt: reserve-sats.local-config < dust-limit-sats.remote-config"
        !!
    ::
    =+  ^=  funding-address
      ^-  address:bc
      %^    make-funding-address:channel
          network.our.u.c
        pub.multisig-key.our.u.c
      funding-pubkey.msg
    ::
    %-  (slog leaf+"chan-id={<temporary-channel-id.msg>}" ~)
    %-  (slog leaf+"funding-address={<funding-address>}" ~)
    ::
    :_  %=  state  larv.chan
          %+  ~(put by larv.chan)  temporary-channel-id.msg
            %=  u.c
              her         remote-config
              ac          `msg
        ==  ==
    ~[(give-update [%need-funding-signature temporary-channel-id.msg funding-address])]
  ::
  ++  handle-funding-created
    |=  msg=funding-created:msg:bolt
    ^-  (quip card _state)
    =/  c=(unit larva-chan:bolt)
      %-  ~(get by larv.chan)
        temporary-channel-id.msg
    ?~  c
      ~&  >>>  "%volt: %funding-created for non-existent channel: {<temporary-channel-id.msg>}"
      `state
    ?~  oc.u.c
      ~&  >>>  "%volt: %funding-created without %open-channel: {<temporary-channel-id.msg>}"
      `state
    ?~  ac.u.c
      ~&  >>>  "%volt: %funding-created without %accept-channel: {<temporary-channel-id.msg>}"
      `state
    ?>  =(ship.her.u.c src.bowl)
    ::
    =/  funding-output=output:psbt
      %^    funding-output:tx
          pub.multisig-key.our.u.c
        pub.multisig-key.her.u.c
      funding-sats.u.oc.u.c
    ::
    =/  new-channel=chan:bolt
      %:  new:channel
        local-channel-config=our.u.c
        remote-channel-config=her.u.c
        funding-outpoint=[funding-txid.msg funding-idx.msg funding-sats.u.oc.u.c]
        initial-feerate=feerate-per-kw.u.oc.u.c
        initiator=initiator.u.c
        anchor-outputs=anchor-outputs.our.u.c
        capacity=funding-sats.u.oc.u.c
        funding-tx-min-depth=minimum-depth.u.ac.u.c
      ==
    ::
    =.  new-channel
      %-  ~(receive-first-commitment channel new-channel)
        signature.msg
    =^  sig  new-channel
      %-  ~(sign-first-commitment channel new-channel)
        first-per-commitment-point.u.oc.u.c
    =.  new-channel  (~(set-state channel new-channel) %opening)
    ::
    :_
      %=    state
          larv.chan
        (~(del by larv.chan) temporary-channel-id.msg)
      ::
          live.chan
        (~(put by live.chan) id.new-channel new-channel)
      ::
          peer.chan
        (add-peer-channel src.bowl id.new-channel)
      ::
          wach.chan
        (~(put by wach.chan) script-pubkey.funding-output id.new-channel)
      ==
    :~  (send-message [%funding-signed id.new-channel sig] src.bowl)
        (give-update [%channel-state id.new-channel %opening])
    ==
  ::
  ++  handle-funding-signed
    |=  msg=funding-signed:msg:bolt
    ^-  (quip card _state)
    ?.  (~(has by live.chan) channel-id.msg)
      ~&  >>>  "%volt: no channel with id: {<channel-id.msg>}"
      `state
    ?.  (~(has by fund.chan) channel-id.msg)
      ~&  >>>  "%volt: no funding tx with id: {<channel-id.msg>}"
      `state
    =+  c=(~(got by live.chan) channel-id.msg)
    ?>  =(ship.her.config.c src.bowl)
    =+  funding-tx=(~(got by fund.chan) channel-id.msg)
    =+  ^=  funding-output
      ^-  output:psbt
      %^    funding-output:tx
          pub.multisig-key.our.config.c
        pub.multisig-key.her.config.c
      sats.funding-outpoint.c
    =.  c  (~(receive-first-commitment channel c) signature.msg)
    =.  c  (~(set-state channel c) %opening)
    :_
      %=    state
          live.chan
        (~(put by live.chan) channel-id.msg c)
      ::
          peer.chan
        (add-peer-channel src.bowl channel-id.msg)
      ::
          fund.chan
        (~(del by fund.chan) channel-id.msg)
      ::
          wach.chan
        (~(put by wach.chan) script-pubkey.funding-output channel-id.msg)
      ==
    =+  tx=(encode-tx:psbt (extract-unsigned:psbt funding-tx))
    :~  (poke-btc-provider [%broadcast-tx tx])
        (give-update [%channel-state id.c %opening])
    ==
  ::
  ++  handle-funding-locked
    |=  msg=funding-locked:msg:bolt
    ^-  (quip card _state)
    =+  c=(~(get by live.chan) channel-id.msg)
    ?~  c  `state
    ?:  funding-locked-received.our.config.u.c
      `state
    =.  config.u.c
      %=    config.u.c
          our
        our.config.u.c(funding-locked-received %.y)
      ::
          her
        %=  her.config.u.c
          next-per-commitment-point  next-per-commitment-point.msg
        ==
      ==
    =^  cards  u.c
      ?:  ~(is-funded channel u.c)
        (mark-open u.c)
      [~ u.c]
    [cards state(live.chan (~(put by live.chan) id.u.c u.c))]
  ::
  ++  handle-update-add-htlc
    |=  msg=update-add-htlc:msg:bolt
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id.msg)
    =+  c=(~(got by live.chan) channel-id.msg)
    ?>  =(ship.her.config.c src.bowl)
    ?>  =(state.c %open)
    =^  htlc  c  (~(receive-htlc channel c) msg)
    `state(live.chan (~(put by live.chan) channel-id.msg c))
  ::
  ++  handle-commitment-signed
    |=  msg=commitment-signed:msg:bolt
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id.msg)
    =+  c=(~(got by live.chan) channel-id.msg)
    =+  msg
    ?>  =(ship.her.config.c src.bowl)
    =^  cards  c
      %-  send-revoke-and-ack
      %+  ~(receive-new-commitment channel c)
        sig
      htlc-sigs
    :-  cards
    state(live.chan (~(put by live.chan) id.c c))
  ::
  ++  handle-revoke-and-ack
    |=  msg=revoke-and-ack:msg:bolt
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id.msg)
    =+  c=(~(got by live.chan) channel-id.msg)
    ?>  =(ship.her.config.c src.bowl)
    =.  c  (~(receive-revocation channel c) msg)
    =^  cards-1  c      (maybe-send-settle c)
    =^  cards-2  c      (maybe-send-commitment c)
    =^  cards-3  state  (maybe-forward-htlcs c)
    :_  state(live.chan (~(put by live.chan) id.c c))
    ;:(weld cards-1 cards-2 cards-3)
  ::
  ++  handle-shutdown
    |=  =shutdown:msg:bolt
    ^-  (quip card _state)
    =+  shutdown
    ~&  >>  "%volt: shutdown {<channel-id>}"
    =+  c=(~(get by live.chan) channel-id)
    ?~  c  `state
    ?>  =(ship.her.config.u.c src.bowl)
    =+  upfront-script=upfront-shutdown-script.her.config.u.c
    ?:  ?&  (gth wid.upfront-script 0)
            !=(upfront-script script-pubkey)
        ==
      ~|(%invalid-script-pubkey !!)
    ::  TODO: check pubkey template
    ::
    =+  close=(~(get by shut.chan) id.u.c)
    ?~  close
      ::  counterparty initiated: ack shutdown, and if we're the funder, start closing negotiations
      ::
      =|  close=coop-close-state
      =.  initiator.close   src.bowl
      =.  her-script.close  script-pubkey
      =.  our-script.close  ~(shutdown-script channel u.c)
      =^  cards-1  u.c      (send-shutdown u.c close)
      =^  cards-2  close    (maybe-sign-closing u.c close)
      :: just remove this assertion to fix bug in non-funder-initiated closing?
      :: ?>  =(~ cards-2)
      :-  cards-1
      %=  state
        live.chan  (~(put by live.chan) id.u.c u.c)
        shut.chan  (~(put by shut.chan) id.u.c close)
      ==
    ::  counterparty acked: start closing negotiations if we're the funder, otherwise wait for first closing-signed msg from counterparty
    ::
    ?>  =(initiator.u.close our.bowl)
    =.  her-script.u.close  script-pubkey
    =^  cards  u.close      (maybe-sign-closing u.c u.close)
    :-  cards
    %=  state
      live.chan  (~(put by live.chan) id.u.c u.c)
      shut.chan  (~(put by shut.chan) id.u.c u.close)
    ==
  ::
  ++  handle-closing-signed
    |=  =closing-signed:msg:bolt
    ^-  (quip card _state)
    =+  closing-signed
    =+  c=(~(get by live.chan) channel-id)
    ?~  c  `state
    ?>  =(ship.her.config.u.c src.bowl)
    =+  close=(~(got by shut.chan) id.u.c)
    =.  close
      %=  close
        her-fee  fee-sats
        her-sig  signature
      ==
    =/  [closing-tx=psbt:psbt our-sig=signature:bolt]
      %^    ~(make-closing-tx channel u.c)
          our-script.close
        her-script.close
      her-fee.close
    ?>  (verify-signature u.c closing-tx her-sig.close)
    =/  fee-diff=sats:bc
      ?:  (gth our-fee.close her-fee.close)
        (sub our-fee.close her-fee.close)
      (sub her-fee.close our-fee.close)
    ?:  (lth fee-diff 2)
      ::  we're done
      ::
      =.  our-fee.close  her-fee.close
      =.  our-sig.close  our-sig
      =^  cards          close
        ::  non-funder replies
        ::
        ?:  initiator.constraints.u.c  `close
        (maybe-sign-closing u.c close)
      ::  add-signatures to closing-tx
      ::
      =.  closing-tx
        %:  ~(add-signature update:psbt closing-tx)  0
          pub.multisig-key.our.config.u.c
          our-sig.close
        ==
      ::
      =.  closing-tx
        %:  ~(add-signature update:psbt closing-tx)  0
          pub.multisig-key.her.config.u.c
          her-sig.close
        ==
      ::
      =.  u.c  (~(set-state channel u.c) %closing)
      =+  encoded=(extract:psbt closing-tx)
      :_  %=  state
            live.chan  (~(put by live.chan) id.u.c u.c)
            shut.chan  (~(put by shut.chan) id.u.c close)
          ==
      ;:  welp
        cards
        :~  (poke-btc-provider [%broadcast-tx encoded])
            (give-update [%channel-state id.u.c %closing])
        ==
      ==
    ::  set fee 'strictly between' the previous values
    ::
    =/  our-fee=sats:bc
      (div (add our-fee.close her-fee.close) 2)
    =.  our-fee.close  our-fee
    ::  another round
    ::
    =^  cards  close  (maybe-sign-closing u.c close)
    :-  cards
    state(shut.chan (~(put by shut.chan) id.u.c close))
  ::
  ++  handle-update-fulfill-htlc
    |=  [=channel=id:bolt =htlc-id:bolt preimage=hexb:bc]
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id)
    =+  c=(~(got by live.chan) channel-id)
    ?>  =(ship.her.config.c src.bowl)
    =+  payment-hash=(sha256:bcu:bc preimage)
    =.  c  (~(receive-htlc-settle channel c) preimage htlc-id)
    =^  cards-1  c      (maybe-send-commitment c)
    =^  cards-2  state  (maybe-settle-external payment-hash preimage)
    :-  (weld cards-1 cards-2)
    %=    state
        live.chan
      (~(put by live.chan) id.c c)
    ::
        preimages.payments
      (~(put by preimages.payments) payment-hash preimage)
    ==
  ::
  ++  handle-update-fail-htlc
    |=  [=channel=id:bolt =htlc-id:bolt reason=@t]
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id)
    =+  c=(~(got by live.chan) channel-id)
    ?>  =(ship.her.config.c src.bowl)
    =.  c  (~(receive-fail-htlc channel c) htlc-id)
    =^  cards  c  (maybe-send-commitment c)
    ~&  >>>  "{<id.c>} failed HTLC: {<reason>}"
    [cards state(live.chan (~(put by live.chan) id.c c))]
  ::
  ++  handle-update-fail-malformed-htlc
    |=  [=channel=id:bolt =htlc-id:bolt]
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id)
    =+  c=(~(got by live.chan) channel-id)
    ?>  =(ship.her.config.c src.bowl)
    =.  c  (~(receive-fail-htlc channel c) htlc-id)
    =^  cards  c  (maybe-send-commitment c)
    ~&  >>>  "{<id.c>} failed HTLC: (malformed)"
    [cards state(live.chan (~(put by live.chan) id.c c))]
  ::
  ++  handle-update-fee
    |=  [=channel=id:bolt feerate-per-kw=sats:bc]
    ^-  (quip card _state)
    ?>  (~(has by live.chan) channel-id)
    =+  c=(~(got by live.chan) channel-id)
    ?>  =(ship.her.config.c src.bowl)
    =.  c  (~(receive-update-fee channel c) feerate-per-kw)
    `state(live.chan (~(put by live.chan) id.c c))
  --
::
++  handle-action
  |=  =action
  ^-  (quip card _state)
  ?-    -.action
      %give-invoice
    ?>  own-provider
    =|  req=payment-request
    :_  %=  state  incoming.payments
        %+  ~(put by incoming.payments)  payment-hash.action
        %=  req
          payee         src.bowl
          amount-msats  amount-msats.action
          payment-hash  payment-hash.action
        ==
      ==
    =-  ~[(provider-action -)]
    :*  %add-hold-invoice
      amount-msats.action  memo.action
      payment-hash.action  ~
    ==
  ::
      %take-invoice
    %-  (slog leaf+"{<payreq.action>}" ~)
    `state
  ::
      %give-pubkey
    =+  secp256k1:secp:crypto
    =+  hash=(shay 32 nonce.action)
    =+  sig=(ecdsa-raw-sign hash prv.our.keys)
    :_  state
    ~[(volt-action [%take-pubkey sig] src.bowl)]
  ::
      %take-pubkey
    =+  secp256k1:secp:crypto
    =+  chal=(~(get by chal.keys) src.bowl)
    ?~  chal  `state
    =+  hash=(shay 32 u.chal)
    =+  pubkey=(ecdsa-raw-recover hash sig.action)
    :-  ~
    %=  state
      chal.keys   (~(del by chal.keys) src.bowl)
      their.keys  (~(put by their.keys) pubkey src.bowl)
    ==
  ::
      %forward-payment
    ?>  own-provider
    =+  c=(~(get by live.chan) channel-id.htlc.action)
    ?~  c  !!
    ?>  =(ship.her.config.u.c src.bowl)
    ?>  =(state.u.c %open)
    ~&  >>  "%volt: received htlc {<htlc-id.htlc.action>} from {<src.bowl>}"
    =^  her-htlc=update-add-htlc:msg:bolt  u.c
      (~(receive-htlc channel u.c) htlc.action)
    ~&  >>  "%volt: added htlc {<htlc-id.her-htlc>} from {<src.bowl>}"
    =|  req=forward-request
    =.  req
      %=  req
        htlc       her-htlc
        payreq     payreq.action
        forwarded  %.n
      ==
    :-  ~
    %=    state
        live.chan
      (~(put by live.chan) id.u.c u.c)
    ::
        outgoing.payments
      (~(put by outgoing.payments) payment-hash.her-htlc req)
    ==
  ==
::
++  handle-provider-status
  |=  =status:provider
  ^-  (quip card _state)
  ?~  volt.prov  `state
  ?:  =(status %connected)
    `state(volt.prov `u.volt.prov(connected %.y))
  `state(volt.prov `u.volt.prov(connected %.n))
::
++  handle-provider-update
  |=  =update:provider
  |^  ^-  (quip card _state)
  ?:  ?=([%| *] update)
    ~&  >>>  "%volt: provider-error {<update>}"
    `state
  ?+    +<.update  `state
      %node-info
    `state(info.prov +>.update)
  ::
      %payment-update
    (handle-payment-update +>.update)
  ::
      %hold-invoice
    (handle-hold-invoice +>.update)
  ::
      %invoice-update
    (handle-invoice-update +>.update)
  ::
      %confirmation-event
    (handle-confirmation-event +>.update)
  ::
      %spend-event
    (handle-spend-event +>.update)
  ==
  ++  handle-payment-update
    |=  result=payment:rpc
    ^-  (quip card _state)
    =+  req=(~(get by outgoing.payments) hash.result)
    ?~  req  `state
    =+  c=(~(get by live.chan) channel-id.htlc.u.req)
    ?~  c  `state  :: drop it?
    ?:  =(status.result %'SUCCEEDED')
      =.  u.c  (~(settle-htlc channel u.c) preimage.result htlc-id.htlc.u.req)
      =^  cards  u.c  (maybe-send-commitment u.c)
      :_  %=    state
              live.chan
            (~(put by live.chan) id.u.c u.c)
          ::
              preimages.payments
            (~(put by preimages.payments) hash.result preimage.result)
          ::
              outgoing.payments
            (~(del by outgoing.payments) hash.result)
          ==
      =-  [(send-message - ship.her.config.u.c) cards]
      [%update-fulfill-htlc id.u.c htlc-id.htlc.u.req preimage.result]
    ::
    ?:  =(status.result %'FAILED')
      =.  u.c  (~(fail-htlc channel u.c) htlc-id.htlc.u.req)
      =^  cards  u.c  (maybe-send-commitment u.c)
      :_  state(live.chan (~(put by live.chan) id.u.c u.c))
      =-  [(send-message - ship.her.config.u.c) cards]
      [%update-fail-htlc id.u.c htlc-id.htlc.u.req `@t`failure-reason.result]
    `state
  ::
  ++  handle-hold-invoice
    |=  result=add-hold-invoice-response:rpc
    ^-  (quip card _state)
    =+  payreq=(de:bolt11 payment-request.result)
    ?~  payreq
      ~&  >>>  "%volt: invalid invoice payreq"
      `state
    =+  request=(~(get by incoming.payments) payment-hash.u.payreq)
    ?~  request
      ~&  >>>  "%volt: unknown invoice payment hash"
      `state
    :_  state
    ~[(volt-action [%take-invoice payment-request.result] payee.u.request)]
  ::
  ++  handle-invoice-update
    |=  result=invoice:rpc
    ^-  (quip card _state)
    ~&  >>  "%volt: invoice update {<result>}"
    ?:  =(state.result %'ACCEPTED')
      =+  req=(~(get by incoming.payments) r-hash.result)
      ?~  req
        ~&  >>>  "%volt: unknown invoice"
        (cancel-invoice r-hash.result)
      =+  chan-ids=(~(gut by peer.chan) payee.u.req ~)
      =+  c=(find-channel-with-capacity chan-ids value-msats.result)
      ?~  c
        ~&  >>>  "%volt: no capacity with peer"
        (cancel-invoice r-hash.result)
      ::  can apply fees here
      (pay-channel u.c value-msats.result r-hash.result)
    ?:  =(state.result %'SETTLED')
      `state(incoming.payments (~(del by incoming.payments) r-hash.result))
    `state
  ::
  ++  cancel-invoice
    |=  =payment=hash
    ^-  (quip card _state)
    :_  state
    ~[(provider-action [%cancel-invoice payment-hash])]
  ::
  ++  handle-confirmation-event
    |=  event=confirmation-event:rpc
    ^-  (quip card _state)
    ~&  >>  "%volt: confirmation event: {<event>}"
    `state
  ::
  ::  TODO: use this spend subscription to initiate revocation/sweep flow
  ++  handle-spend-event
    |=  event=spend-event:rpc
    ^-  (quip card _state)
    ~&  >>  "%volt: spend event: {<event>}"
    `state
  --
::
++  handle-bitcoin-status
  |=  =status:btc-provider
  |^  ^-  (quip card _state)
  ?~  btcp.prov  `state
  ?.  =(host.u.btcp.prov src.bowl)  `state
  ?-    -.status
      %new-block
    ::  just =. here and in handle-exp-htlcs
    =/  upd=state-0
      %_  state
        btcp.prov  `u.btcp.prov(connected %.y)
        chain      [block.status fee.status now.bowl]
      ==
    =/  [exp=(list [hexb:bc pending-timelock]) unexp=(list [hexb:bc pending-timelock])]
      %+  skid  ~(tap by onchain.payments)
      |=  [hexb:bc =pending-timelock]
      (gte block.status height.pending-timelock)
    =^  cards  upd  (handle-exp-htlcs upd (turn exp tail))
    =/  targets  %+  weld  ~(tap in ~(key by wach.chan))
      (turn unexp |=([spk=hexb:bc pending-timelock] spk))
    =/  key=byts  (take:byt:bcu:bc 16 blockhash.status)
    :_  upd
    ?.  (match:bip-b158 blockfilter.status key targets)
      cards
    (snoc cards (poke-btc-provider [%block-txs blockhash.status]))
  ::
      %connected
    :-  ~
    %=  state
      btcp.prov  `u.btcp.prov(connected %.y)
      chain      [block.status fee.status now.bowl]
    ==
  ::
      %disconnected
    `state(btcp.prov `u.btcp.prov(connected %.n))
  ==
  ::
  ++  handle-exp-htlcs
    |=  $:  stat=_state
            htlcs=(list pending-timelock)
        ==
    ^-  (quip card _state)
    :-  %+  turn  htlcs
        |=  [@ tx=psbt:psbt koi=(unit pair:key:bolt)]
        =+  out=(snag 0 outputs.tx)
        =+  vbyts=(add 33 (estimated-size:psbt tx))
        =+  minus-fees=(sub value.out (mul vbyts (need fees.chain.stat)))
        =.  outputs.tx  ~[out(value minus-fees)]
        %-  poke-btc-provider
          :-  %broadcast-tx
          %-  extract:psbt
            %^  ~(add-signature update:psbt tx)
                0
              pub:(need koi)
            
            %^  ~(one sign:psbt tx)
                0
              (priv-to-hexb:key-gen prv:(need koi))
            ~
    |-
    ?~  htlcs
      stat
    %=  $
      htlcs                  t.htlcs
      onchain.payments.stat  (~(del by onchain.payments.stat) -.i.htlcs)
    ==
  --
::
++  handle-bitcoin-update
  |=  =update:btc-provider
  |^  ^-  (quip card _state)
  ?~  btcp.prov  `state
  ?.  =(host.u.btcp.prov src.bowl)  `state
  ?.  ?=([%& *] update)  `state
  ?+    -.p.update  `state
      %address-info
    ::  currently all address-info updates are from checking new blocks for funding outpoint spends
    (handle-address-info +.p.update)
  ::
      %tx-info
    `state
  ::
      %raw-tx
    `state
  ::
      %broadcast-tx
    ::  apparently this can fail
    ::  TODO: retry
    ~&  >>  p.update
    `state
  ::
      %block-info
    `state
  ::
      %block-txs
    (handle-block-txs +.p.update)
  ::
  ::  TODO: make sure this matches whatever changes made to rpc
      %fee
    `state(fees.chain `(abs:si (need (toi:rd fee.p.update))))
  ==
  ::
  +$  spend
    $:  =id:bolt
        com=commitment:bolt
        txid=hexb:bc
    ==
    ::  TODO: change some of these to sets
  +$  checked-block
    $:  rest=(list @)  ::  indices in tx list
        rev=(list spend)
        our-force=(list spend)
        their-force=(list spend)
        coop=(list id:bolt)
        our-htlc=(list outpoint)
        ::  spend or psbt?
        their-htlc=(list psbt:psbt)
    ==
  +$  rev-out
    $:  =outpoint
        secret=@
        =spend
    ==
  ::
  ++  handle-block-txs
    |=  [blockhash=hexb:bc txs=(list rpc-tx)]
    ^-  (quip card _state)
    =+  chk=(check-watched txs)
    ::  TODO: timeout sends, handle our force close
    :: ?~  fees.chain
    ::   :_  state
    ::   :~
    ::     (poke-btc-provider [%fee +(block.chain)])
    ::     (poke-btc-provider [%block-txs blockhash])
    ::   ==
    ::  just =.
    =/  upd=_state  state
    =^  cards  upd  (handle-revoked upd rev.chk)
    =+  rev-htlcs=(revoked-htlcs rev.chk)
    =^  rev-htlc-cards  upd
      (check-revoked-htlcs upd rev-htlcs txs)
    =^  remote-force-cards  upd
      (handle-remote-closed upd their-force.chk)
    =^  coop-cards  upd  (resolve-coop upd coop.chk)
    =^  local-force-cards  upd
      (handle-local-closed upd our-force.chk)
    =.  cards
      ::  :;  weld is faster
      %-  zing
      :~  cards
          rev-htlc-cards
          remote-force-cards
          coop-cards
          local-force-cards
      ==
    [cards upd]
  ::
  ::  add comments
  ++  check-watched
    |=  txs=(list rpc-tx)
    ^-  checked-block
    =|  i=@
    =|  chk=checked-block
    |-
    ?~  txs
      chk
    =+  tx=(de:psbt rawtx.i.txs)
    =+  prevout=prevout:(snag 0 vin.tx)
    =+  htlc-spend=(~(get by htlc.chan) prevout)
    ::  TODO: not quite right, harmonize with onchain.payments flow/state
    ?^  htlc-spend
      =/  upd=checked-block
        ?.  =(htlc-spend tx)
          chk(their-htlc (snoc their-htlc.chk tx))
        chk(our-htlc (snoc our-htlc.chk prevout))
      $(txs t.txs, i +(i), chk upd)
    ::  TODO: change this to not use live.chan, or differentiate unlocked/used lives from others
    =/  funds=(map id:bolt outpoint)
      %-  ~(run by live.chan)
      |=  [c=chan:bolt]
      [txid.funding-outpoint.c pos.funding-outpoint.c]
    =/  fund-match=(list [id:bolt outpoint])
      %+  skim  ~(tap by funds)
      |=([id:bolt =outpoint] =(outpoint prevout))
    ?~  fund-match
      $(txs t.txs, i +(i), rest.chk (snoc rest.chk i))
    =+  id=(head (rear fund-match))
    =+  ch=(~(got by live.chan) id)
    =/  rev=(unit commitment:bolt)
      %-  ~(rep in ~(key by lookup.commitments.ch))
      |=  [=commitment:bolt acc=(unit commitment:bolt)]
      ?:  =(tx.commitment tx)  `commitment  acc
    ?^  rev
      =/  upd  (snoc rev.chk [id u.rev txid.i.txs])
      $(txs t.txs, i +(i), rev.chk upd)
    =/  unrev=(list commitment:bolt)
      %+  skim  her.commitments.ch
      |=  =commitment:bolt  =(tx.commitment tx)
    ?^  unrev
      =/  upd  (snoc their-force.chk [id i.unrev txid.i.txs])
      $(txs t.txs, i +(i), their-force.chk upd)
    ?:  =(state.ch %closing)
      $(txs t.txs, i +(i), coop.chk (snoc coop.chk id))
    ?.  =(state.ch %force-closing)
      ::  TODO: loss-of-funds flag in state and update to client?
      ~&  >>  "ALERT POTENTIAL LOSS OF FUNDS"
      $(txs t.txs, i +(i))
    =/  upd
      (snoc our-force.chk [id (snag 0 our.commitments.ch) txid.i.txs])
    $(txs t.txs, i +(i), our-force.chk upd)
  ::
  ++  handle-revoked
    |=  [stat=_state rev=(list spend)]
    ^-  (quip card _state)
    =|  cards=(list card)
    |-
    ?~  rev
      [cards stat]
    =+  ch=(~(got by live.chan) id.i.rev)
    =.  cards  %+  snoc  cards
      (give-update [%channel-state id.i.rev %force-closing])
    =/  txs=(list psbt:psbt)
      %:  revoked-commitment:sweep
        ch
        com.i.rev
        txid.i.rev
        (need fees.chain)
      ==
    =/  force=force-close-state
      [ship.her.config.ch %.y com.i.rev 0]
    =.  cards
      %+  weld  cards
      %+  turn  txs
      |=  tx=psbt:psbt
      (poke-btc-provider [%broadcast-tx (extract:psbt tx)])
    =.  ch  (~(set-state channel ch) %force-closing)
    =:  live.chan.stat  (~(put by live.chan.stat) id.i.rev ch)
        dead.chan.stat  (~(put by dead.chan.stat) id.i.rev force)
    ==
    $(rev t.rev)
  ::
  ++  revoked-htlcs
    |=  rev=(list spend)
    =|  out=(set rev-out)
    ^+  out
    |-
    ?~  rev
      out
    =+  ch=(~(got by live.chan) id.i.rev)
    =/  secret
      (~(got by lookup.commitments.ch) com.i.rev)
    =/  htlc-idxs
      %+  weld
        ~(tap in ~(key by sent-htlc-index.com.i.rev))
      ~(tap in ~(key by recd-htlc-index.com.i.rev))
    =.  out
      %-  ~(gas in out)
      %+  turn  htlc-idxs
      |=(idx=@ [`outpoint`[txid.i.rev idx] secret i.rev])
    $(rev t.rev)
  ::
  ++  check-revoked-htlcs
    |=  $:  stat=_state 
            htlcs=(set rev-out)
            txs=(list rpc-tx)
        ==
    ^-  (quip card _state)
    ?.  (gth ~(wyt in htlcs) 0)
      `stat
    =|  cards=(list card)
    |-
    ?~  txs
      [cards stat]
    =+  tx=(de:psbt rawtx.i.txs)
    =+  prevout=prevout:(snag 0 vin.tx)
    =/  match=(unit rev-out)
      %-  ~(rep in htlcs)
      |=  [=rev-out acc=(unit rev-out)]
      ?:  !=(outpoint.rev-out prevout)  `rev-out  acc
    ?~  match
      $(txs t.txs)
    =+  ch=(~(got by live.chan) id.spend.u.match)
    =/  secret
      (~(got by lookup.commitments.ch) com.spend.u.match)
    =/  sweep=psbt:psbt
      %:  revoked-htlc-spend:sweep
        ch
        secret
        value:(snag 0 vout.tx)
        txid.outpoint.u.match
        (need fees.chain)
      ==
    =.  htlcs  (~(del in htlcs) u.match)
    =.  cards
      %+  snoc  cards
      (poke-btc-provider [%broadcast-tx (extract:psbt sweep)])
    $(txs t.txs)
  ::
  ++  handle-remote-closed
    |=  [stat=_state close=(list spend)]
    ^-  (quip card _state)
    =|  cards=(list card)
    |-
    ?~  close
      [cards stat]
    =+  ch=(~(got by live.chan) id.i.close)
    =/  tx=psbt:psbt
      %:  his-valid-commitment:sweep
        ch
        com.i.close
        preimages.payments
        (need fees.chain)
      ==
    =.  cards
      %+  weld  cards
      :~  (give-update [%channel-state id.i.close %force-closing])
          (poke-btc-provider [%broadcast-tx (extract:psbt tx)])
      ==
    =.  ch  (~(set-state channel ch) %force-closing)
    =/  sent=(list [hexb:bc pending-timelock])
      %+  turn  ~(tap by sent-htlc-index.com.i.close)
      |=  [idx=@ msg=add-htlc:update:bolt]
      ^-  [hexb:bc pending-timelock]
      :-  script-pubkey:(snag idx vout.tx.com.i.close)
      :*  timeout.msg
          (remote-recd-htlc:sweep ch com.i.close msg)
          `htlc.basepoints.our.config.ch
      ==
    =/  force=force-close-state
      [ship.her.config.ch %.y com.i.close 0]
    %=  $
      close                  t.close
      live.chan.stat         (~(put by live.chan) id.i.close ch)
      dead.chan.stat         (~(put by dead.chan) id.i.close force)
      onchain.payments.stat  (~(gas by onchain.payments.stat) sent)
    ==
  ::
  ++  resolve-coop
    |=  [stat=_state close=(list id:bolt)]
    ^-  (quip card _state)
    =|  cards=(list card)
    |-
    ?~  close
      [cards stat]
    =+  ch=(~(got by live.chan) i.close)
    =.  ch  (~(set-state channel ch) %closed)
    =+  closing=(~(got by shut.chan) i.close)
    =.  close-height.closing  block.chain
    =.  cards
      %+  snoc  cards
      (give-update [%channel-state i.close %closed])
    =:  live.chan.stat  (~(put by live.chan.stat) i.close ch)
        shut.chan.stat  (~(put by shut.chan.stat) i.close closing)
    ==
    $(close t.close)
  ::
  ++  handle-local-closed
    |=  [stat=_state close=(list spend)]
    ^-  (quip card _state)
    =|  cards=(list card)
    |-
    ?~  close
      [cards stat]
    =+  c=(~(got by live.chan) id.i.close)
    =+  delay-height=(add to-self-delay.our.config.c block.chain)
    =+  spend-local=(local-our-output:sweep c com.i.close)
    =/  sent=(map hexb:bc pending-timelock)
      %-  ~(run by (local-sent-htlcs:sweep c com.i.close))
      |=  [height=@ =psbt:psbt]
      ^-  pending-timelock
      [height psbt ~]
    =+  res=(local-recd-htlcs:sweep c com.i.close preimages.payments.stat)
    =.  cards
      %+  welp  cards
      (turn -.res |=(tx=hexb:bc (poke-btc-provider [%broadcast-tx tx])))
    =/  updated  (~(uni by onchain.payments.stat) sent)
    =.  updated
      %-  ~(uni by updated)
      %-  ~(run by -.+.res)
      |=  =psbt:psbt
      ^-  pending-timelock
      [delay-height psbt `multisig-key.our.config.c]
    =?  updated  ?=(^ spend-local)
      %+  ~(put by updated)
        -.u.spend-local
      :*  delay-height
          +.u.spend-local
          `delayed-payment.basepoints.our.config.c
      ==
    =.  cards
      %+  snoc  cards
      (give-update [%channel-state id.i.close %force-closing])
    =:  onchain.payments.stat  updated
        waiting.payments.stat  (~(uni by waiting.payments.stat) +.+.res)
    ==
    $(close t.close)
  ::
  :: ++  handle-potential-spend
  ::   |=  $:
  ::         stat=_state
  ::         txid=hexb:bc
  ::         tx=psbt:psbt
  ::       ==
  ::   ^-  (quip card _state)
  ::   ::  check if this tx spends one of our channels
  ::   =/  funds=(map id:bolt outpoint)
  ::     %-  ~(run by live.chan)
  ::     |=  [c=chan:bolt]
  ::     [txid.funding-outpoint.c pos.funding-outpoint.c]
  ::   =+  prevout=prevout:(snag 0 vin.tx)
  ::   =/  match=(list [id:bolt outpoint])
  ::     %+  skim  ~(tap by funds)
  ::     |=([id:bolt =outpoint] =(outpoint prevout))
  ::   ?~  match
  ::     `stat
  ::   ::  got a match, check our revoked commitments for cheating
  ::   =+  id=(head (rear match))
  ::   =+  ch=(~(got by live.chan) id)
  ::   =/  revoked=(unit commitment:bolt)
  ::     %-  ~(rep in ~(key by lookup.commitments.ch))
  ::     |=  [=commitment:bolt acc=(unit commitment:bolt)]
  ::     ?:  =(tx.commitment tx)  `commitment  acc
  ::   ?^  revoked
  ::     ::  got a match, create revocation spends for this commitment
  ::     ::  htlc-tx handling flow:
  ::     ::  separate function to check for revoked
  ::     ::  if revoked and has htlc outs, check (separate func) for htlc-txs and add any htlc-tx-outs to new state branch
  ::     ::  indicate in state whether we're posting a spend of the htlc-out or the htlc-tx (whether this block included an htlc-tx or not)
  ::     ::  watch for spends of the htlc-out or htlc-tx-out
  ::     ::  no htlc tx case: if htlc-out is subsequently spent by htlc-tx, post rev spend of htlc-tx-out
  ::     ::  htlc tx case: if it's ours, mark resolved, otherwise, notify loss of funds
  ::     ::  TODO: change fees state from unit to default 0
  ::     ?~  fees.chain.state
  ::       `stat
  ::     =/  sweep-tx=psbt:psbt
  ::       %:  revoked-commitment:sweep
  ::         ch
  ::         u.revoked
  ::         txid
  ::         u.fees.chain.state
  ::       ==
  ::     =/  =force-close-state  [ship.her.config.ch %.y u.revoked 0]
  ::     :-  
  ::     :~  (poke-btc-provider [%broadcast-tx (extract:psbt sweep-tx)])
  ::         (give-update [%channel-state id %closing])
  ::     ==
  ::     %=  stat
  ::       live.chan  (~(del by live.chan) id)
  ::       dead.chan   (~(put by dead.chan) id force-close-state)
  ::     ==
  ::   ::  check unrevoked remote commitments for a force-close
  ::   =/  unrevoked=(list commitment:bolt)
  ::     %+  skim  her.commitments.ch
  ::     |=  =commitment:bolt  =(tx.commitment tx)
  ::   ?~  unrevoked
  ::     ::  confirm coop close in progress
  ::     ?.  =(state.ch %closing)
  ::       ~&  >>  "ALERT POTENTIAL LOSS OF FUNDS"
  ::       `stat
  ::     ::  coop close completed
  ::     :-  ~[(give-update [%channel-state id %closed])]
  ::     %=  stat
  ::       live.chan  (~(del by live.chan) id)
  ::     ==
  ::   ::  this is a force-close, create spends
  ::   `stat
  :: ::
  ++  handle-address-info
    |=  $:  =address:bc
            utxos=(set utxo:bc)
            used=?
            block=@ud
        ==
    ^-  (quip card _state)
    ?.  ?=([%bech32 *] address)  `state
    =+  ^=  script-pubkey
      %-  cat:byt:bcu:bc
      :~  1^0
          1^0x20
          (bech32-decode:bolt +.address)
      ==
    :: find the channel funded by this address
    =+  id=(~(get by wach.chan) script-pubkey)
    ?~  id  `state
    =+  channel=(~(got by live.chan) u.id)
    ::  search the returned utxos for a match with the channel funding output
    =/  utxo=(unit utxo:bc)
      %-  ~(rep in utxos)
      |=  [output=utxo:bc acc=(unit utxo:bc)]
      ?:  ?&  =(txid.output txid.funding-outpoint.channel)
              =(pos.output pos.funding-outpoint.channel)
              =(value.output sats.funding-outpoint.channel)
          ==
        `output
      acc
    ::  if the funding utxo is found
    ?:  ?=(^ utxo)
      =/  channel=chan:bolt
        %^  ~(update-onchain-state ^channel channel)
            height.u.utxo
          0
        block
      ::  update the channel
      =^  cards  channel
        (on-channel-update channel u.utxo block)
      :_  state(live.chan (~(put by live.chan) u.id channel))
      %+  weld  cards
      ::  if we're running LND, ask it to notify us when this utxo is spent
      ?.  own-provider  ~
      =-  ~[(provider-action -)]
      :*  %subscribe-spends
        ^=  outpoint
        :*  hash=txid.funding-outpoint.channel
            index=pos.funding-outpoint.channel
        ==
      ::
        ^=  script
        %-  p2wsh:script:tx
        %+  funding-output:script:tx
          pub.multisig-key.our.config.channel
        pub.multisig-key.her.config.channel
      ::
        height-hint=+(block)
      ==
    ::
    ::  if the utxo is not found but the funding was confirmed, ie. it has now been spent
    ::  REWRITE AND FINISH:
    ::  get transactions in block
    ?:  ~(is-funded ^channel channel)
      ::  if a coop close has been initiated for this channel
      =+  close=(~(get by shut.chan) u.id)
      ?^  close
        ::  cooperative close:
        ::  poke btc-provider - block-info, raw-tx, tx-from-pos - get spending tx, check for honesty
        ::
        ?:  =(0 close-height.u.close)
          `state(shut.chan (~(put by shut.chan) u.id u.close(close-height block)))
        =/  channel=chan:bolt
          %^    ~(update-onchain-state ^channel channel)
              0
            close-height.u.close
          block
        :_  state(live.chan (~(put by live.chan) u.id channel))
        ~[(give-update [%channel-state u.id %closed])]
      ::  force close?
      ::  revoked commitment?
      `state
    `state
  ::
  ++  on-channel-update
    |=  [channel=chan:bolt =utxo:bc block=@ud]
    ^-  (quip card _channel)
    ?+    state.channel  `channel
        %open
      ?:  (~(has-expiring-htlcs ^channel channel) block)
        ::  force close
        `channel
      `channel
    ::
        %funded
      (send-funding-locked channel)
    ::
        %force-closing
      `channel
    ==
  --
::
++  own-provider
  ^-  ?
  ?~  volt.prov  %.n
  (team:title our.bowl host.u.volt.prov)
::
++  find-channel-with-capacity
  |=  [ids=(set id:bolt) =amount=msats]
  ^-  (unit chan:bolt)
  %+  roll  ~(tap in ids)
  |=  [=id:bolt acc=(unit chan:bolt)]
  =+  c=(~(get by live.chan) id)
  ?~  c  acc
  ?:  ?&(=(state.u.c %open) (~(can-pay channel u.c) amount-msats))
    `u.c
  acc
::
++  pay-channel
  |=  [c=chan:bolt =amount=msats payment-hash=hexb:bc]
  ^-  (quip card _state)
  ?>  =(state.c %open)
  =|  update=update-add-htlc:msg:bolt
  =.  update
    %=  update
      channel-id    id.c
      payment-hash  payment-hash
      amount-msats  amount-msats
      cltv-expiry   (add block.chain min-final-cltv-expiry:const:bolt)
    ==
  =^  htlc   c  (~(add-htlc channel c) update)
  =^  cards  c  (maybe-send-commitment c)
  :_  state(live.chan (~(put by live.chan) id.c c))
  [(send-message [%update-add-htlc htlc] ship.her.config.c) cards]
::
++  add-peer-channel
  |=  [who=@p =id:bolt]
  ^-  (map ship (set id:bolt))
  ?.  (~(has by peer.chan) who)
    %+  ~(put by peer.chan)
      who
    (sy [id]~)
  %+  ~(jab by peer.chan)
    who
  |=  s=(set id:bolt)
  (~(put in s) id)
::
++  remove-channel
  |=  =id:bolt
  ^-  (quip card _state)
  =+  c=(~(get by live.chan) id)
  ?~  c  `state
  =+  ship=ship.her.config.u.c
  =+  peer-ids=(~(gut by peer.chan) ship ~)
  =.  peer-ids  (~(del in peer-ids) id)
  :-  ~
  %=    state
      live.chan
    (~(del by live.chan) id)
  ::
      wach.chan
    (~(del by wach.chan) ~(funding-address channel u.c))
  ::
      peer.chan
    ?~  peer-ids
      (~(del by peer.chan) ship)
    (~(put by peer.chan) ship peer-ids)
  ::
      their.keys
    ?~  peer-ids
      (~(del by their.keys) ship)
    their.keys
  ==
::
++  send-funding-locked
  |=  c=chan:bolt
  ^-  (quip card chan:bolt)
  =+  who=ship.her.config.c
  =+  idx=(dec start-index:revocation)
  =+  ^=  next-per-commitment-point
    %-  compute-commitment-point:secret
    %^    generate-from-seed:secret
        per-commitment-secret-seed.our.config.c
      idx
    ~
  =^  cards  c
    ?:  ?&(~(is-funded channel c) funding-locked-received.our.config.c)
      (mark-open c)
    [~ c]
  :_  c
  :-  (send-message [%funding-locked id.c next-per-commitment-point] who)
  cards
::
++  send-revoke-and-ack
  |=  c=chan:bolt
  ^-  (quip card chan:bolt)
  ~&  >>  "%volt: revoking current commitment {<id.c>}"
  =^  rev    c  ~(revoke-current-commitment channel c)
  =^  cards  c  (maybe-send-commitment c)
  :_  c
  [(send-message [%revoke-and-ack rev] src.bowl) cards]
::
++  send-shutdown
  |=  [c=chan:bolt close=coop-close-state]
  |^  ^-  (quip card _c)
  ?>  (can-send-shutdown c)
  :_  (~(set-state channel c) %shutdown)
  :~  (send-message [%shutdown id.c our-script.close] ship.her.config.c)
      (give-update [%channel-state id.c %shutdown])
  ==
  ++  can-send-shutdown
    |=  c=chan:bolt
    ^-  ?
    ?:  (~(has-pending-changes channel c) %remote)
      ::  if there are updates pending on the receiving node's commitment transaction:
      ::    MUST NOT send a shutdown.
      %.n
    =/  shutdown-states=(list chan-state:bolt)
      :~  %opening
          %funded
          %open
          %shutdown
          %closing
      ==
    ?=(^ (find [state.c]~ shutdown-states))
  --
::
++  maybe-send-commitment
  |=  c=chan:bolt
  ^-  (quip card chan:bolt)
  ?:  (~(has-unacked-commitment channel c) %remote)  `c
  ?.  (~(owes-commitment channel c) %local)          `c
  ~&  >>  "%volt: sending next commitment {<id.c>}"
  =^  sigs  c  ~(sign-next-commitment channel c)
  =/  [sig=signature:bolt htlc-sigs=(list signature:bolt)]
    sigs
  =+  n-htlc-sigs=(lent htlc-sigs)
  :_  c
  =-  ~[(send-message - ship.her.config.c)]
  :*  %commitment-signed
      id.c         sig
      n-htlc-sigs  htlc-sigs
  ==
::
++  maybe-forward-htlcs
  |=  c=chan:bolt
  |^  ^-  (quip card _state)
  =+  commitment=(~(oldest-unrevoked-commitment channel c) %remote)
  ?~  commitment  `state
  =^  cards  state
    %^  spin  recd-htlcs.u.commitment
      state
    maybe-forward
  [(zing cards) state]
  ++  maybe-forward
    |=  [h=add-htlc:update:bolt state=_state]
    ^-  (quip card _state)
    ?~  volt.prov  `state
    ?.  own-provider
      `state
    ?:  (~(has by preimages.payments) payment-hash.h)
      ::  we already know the preimage. either it's ours or
      ::  we somehow already discovered the payment secret.
      ::  either way, it makes no sense to forward.
      ::
      `state
    =+  req=(~(get by outgoing.payments) payment-hash.h)
    ?~  req  `state
    ?:  forwarded.u.req  `state
    =.  forwarded.u.req  %.y
    ~&  >>  "%volt: {<id.c>} forwarding htlc: {<htlc-id.h>}"
    :_  =-  state(outgoing.payments -)
        (~(put by outgoing.payments) payment-hash.h u.req)
    ~[(provider-command [%send-payment payreq.u.req ~ ~])]
  --
::
++  maybe-send-settle
  |=  c=chan:bolt
  ^-  (quip card chan:bolt)
  =+  commitment=(~(oldest-unrevoked-commitment channel c) %remote)
  ?~  commitment  `c
  =/  with-preimages=(list add-htlc:update:bolt)
    %+  skim  recd-htlcs.u.commitment
    |=  h=add-htlc:update:bolt
    ^-  ?
    (~(has by preimages.payments) payment-hash.h)
  ?~  with-preimages  `c
  =+  h=(head with-preimages)
  =+  preimage=(~(got by preimages.payments) payment-hash.h)
  ~&  >>  "%volt: settling {<htlc-id.h>} {<ship.her.config.c>}"
  :_  (~(settle-htlc channel c) preimage htlc-id.h)
  =-  ~[(send-message - ship.her.config.c)]
  [%update-fulfill-htlc id.c htlc-id.h preimage]
::
++  maybe-settle-external
  |=  [payment-hash=hexb:bc preimage=hexb:bc]
  ^-  (quip card _state)
  ?.  own-provider
    `state
  ?.  (~(has by incoming.payments) payment-hash)
    `state
  ~&  >>  "%volt: settling invoice"
  :_  %=    state
          incoming.payments
        %+  ~(jab by incoming.payments)
          payment-hash
        |=(req=payment-request req(preimage `preimage))
      ==
  ~[(provider-action [%settle-invoice preimage])]
::
++  maybe-sign-closing
  |=  [c=chan:bolt close=coop-close-state]
  ^-  (quip card _close)
  =+  fee-rate=(current-feerate-per-kw)
  =/  [tx=psbt:psbt =signature:bolt]
    %:  ~(make-closing-tx channel c)
      our-script.close
      her-script.close
      0
    ==
  =/  our-fee=sats:bc
    =+  size=(estimated-size:psbt tx)
    (div (mul fee-rate size) 1.000)
  =/  max-fee=sats:bc
   %-  ~(latest-fee channel c)
   ?:  =(our.bowl initiator.close)  %local  %remote
  ?:  ?&(initiator.constraints.c =(0 wid.our-sig.close))
    ::  send first closing-signed
    ::
    %+  send-closing-signed  c
    %=  close
      max-fee  max-fee
      our-fee  (min our-fee max-fee)
    ==
  ?:  ?&(?!(initiator.constraints.c) =(0 wid.her-sig.close))
    ::  wait for first closing-signed
    ::
    :-  ~
    %=  close
      max-fee  max-fee
      our-fee  (min our-fee max-fee)
    ==
  ::  send next closing-signed
  (send-closing-signed c close)
::
++  send-closing-signed
  |=  [c=chan:bolt close=coop-close-state]
  ^-  (quip card _close)
  =|  msg=closing-signed:msg:bolt
  =/  [tx=psbt:psbt =signature:bolt]
    %^    ~(make-closing-tx channel c)
        our-script.close
      her-script.close
    our-fee.close
  =.  msg
    %=  msg
      channel-id  id.c
      fee-sats    our-fee.close
      signature   signature
    ==
  :_  close(our-sig signature)
  ~[(send-message [%closing-signed msg] ship.her.config.c)]
::
++  verify-signature
  |=  [c=chan:bolt tx=psbt:psbt =signature:bolt]
  ^-  ?
  =+  preimage=(~(witness-preimage sign:psbt tx) 0 ~)
  %^    check-signature:bolt
      (dsha256:bcu:bc preimage)
    signature
  pub.multisig-key.her.config.c
::
++  mark-open
  |=  c=chan:bolt
  ^-  (quip card chan:bolt)
  ?>  ~(is-funded channel c)
  =+  old-state=state.c
  ?:  =(old-state %open)    `c
  ?.  =(old-state %funded)  `c
  ?>  funding-locked-received.our.config.c
  :_  (~(set-state channel c) %open)
  ~[(give-update [%channel-state id.c %open])]
::  TODO: estimate fee based on network state, target ETA, desired confs
::  TODO: remove trap
++  current-feerate-per-kw
  |.
  ^-  sats:bc
  %+  max
    feerate-per-kw-min-relay:const:bolt
  (div feerate-fallback:const:bolt 4)
::
++  make-local-config
  |=  [seed=@ =network:bolt =funding=sats:bc =push=msats initiator=?]
  ^-  local-config:bolt
  =|  =local-config:bolt
  =.  local-config
    %=    local-config
        ship                     our.bowl
        network                  network
        seed                     seed
        to-self-delay            (mul 7 144)
        dust-limit-sats          dust-limit-sats:const:bolt
        max-accepted-htlcs       30
        funding-locked-received  %.n
        htlc-minimum-msats       1
        anchor-outputs           %.y
        multisig-key             (generate-keypair:key-gen seed network %multisig)
        basepoints               (generate-basepoints:key-gen seed network)
    ::
        max-htlc-value-in-flight-msats
      (sats-to-msats:bolt funding-sats)
    ::
        initial-msats
      ?:  initiator
        %+  sub
          %-  sats-to-msats:bolt  funding-sats
        push-msats
      push-msats
    ::
        reserve-sats
      %+  max
        (div funding-sats 100)
      dust-limit-sats:const:bolt
    ::
        per-commitment-secret-seed
      prv:(generate-keypair:key-gen seed network %revocation-root)
    ==
  ?>  (validate-config:bolt -.local-config funding-sats)
  local-config
::
++  poke-btc-provider
  |=  =action:btc-provider
  ^-  card
  ?~  btcp.prov  ~|("provider not set" !!)
  :*  %pass   /btc-provider-action/[(scot %da now.bowl)]
      %agent  host.u.btcp.prov^%btc-provider
      %poke   %btc-provider-action  !>(action)
  ==
::
++  provider-command
  |=  =command:provider
  ^-  card
  ?~  volt.prov  ~|("provider not set" !!)
  :*  %pass   /provider-command/[(scot %da now.bowl)]
      %agent  host.u.volt.prov^%volt-provider
      %poke   %volt-provider-command  !>(command)
  ==
::
++  provider-action
  |=  =action:provider
  ^-  card
  ?~  volt.prov  ~|("provider not set" !!)
  :*  %pass   /provider-action/[(scot %da now.bowl)]
      %agent  [host.u.volt.prov %volt-provider]
      %poke   %volt-provider-action  !>(action)
  ==
::
++  volt-action
  |=  [=action who=@p]
  ^-  card
  :*  %pass   /action/[(scot %da now.bowl)]
      %agent  who^%volt
      %poke   %volt-action  !>(action)
  ==
::
++  send-message
  |=  [msg=message:bolt who=@p]
  ^-  card
  :*  %pass   /message/[(scot %p who)]/[(scot %da now.bowl)]
      %agent  who^%volt
      %poke   %volt-message  !>(msg)
  ==
::
++  watch-provider
  |=  who=@p
  ^-  (list card)
  :-  :*  %pass   /provider-status/[(scot %p who)]
          %agent  who^%volt-provider
          %watch  /status
      ==
  ?:  (team:title our.bowl who)
    :~
      :*  %pass  /provider-updates/[(scot %p who)]
          %agent  who^%volt-provider
          %watch  /clients
      ==
    ==
   ~
::
++  leave-provider
  |=  who=@p
  ^-  (list card)
  :_  ~
  :*  %pass   /set-provider/[(scot %p who)]
      %agent  who^%volt-provider
      %leave  ~
  ==
::
++  watch-btc-provider
  |=  who=@p
  ^-  (list card)
  =/  =dock     [who %btc-provider]
  =/  wir=wire  /set-btc-provider/[(scot %p who)]
  :+
    :*  %pass   wir
        %agent  dock
        %watch  /clients
    ==
    :*  %pass   (welp wir [%priv ~])
        %agent  dock
        %watch  /clients/[(scot %p our.bowl)]
    ==
  ~
::
++  leave-btc-provider
  |=  who=@p
  ^-  (list card)
  =/  wir=wire  /set-btc-provider/[(scot %p who)]
  :+
    :*  %pass   wir
        %agent  who^%btc-provider
        %leave  ~
    ==
    :*  %pass   (welp wir %priv^~)
        %agent  who^%btc-provider
        %leave  ~
    ==
  ~
::
++  give-update
  |=  =update
  ^-  card
  [%give %fact ~[/all] %volt-update !>(update)]
--
