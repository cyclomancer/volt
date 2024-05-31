::  channel.hoon: channel state manipulation
::
::  The four main operations are:
::    +sign-next-commitment
::    +receive-new-commitment
::    +revoke-current-commitment
::    +receive-revocation
::
::  Auxilary operations update the current commitment:
::    +add/settle/fail-htlc
::    +receive-/settle/fail-htlc
::
/-  *bolt
/+  *utilities, psbt, script, commitment-chain
/+  bc=bitcoin, btc-script
/+  tx=transactions, keys=key-generation
/+  secret=commitment-secret, log=update-log
/+  revocation=revocation-store
::
|_  c=chan
::
++  make-channel-id
  |=  [funding-txid=hexb:bc funding-output-index=@ud]
  ^-  id
  (mix dat.funding-txid funding-output-index)
::  +state-transitions: allowable state transitions for channel
::
++  state-transitions
  ^-  (set (pair chan-state))
  %-  silt
  ^-  (list (pair chan-state))
  :~  [%preopening %opening]
      [%opening %funded]
      [%funded %open]
      [%opening %shutdown]
      [%funded %shutdown]
      [%open %shutdown]
      [%shutdown %shutdown]
      [%shutdown %closing]
      [%closing %closing]
    ::
      [%opening %force-closing]
      [%funded %force-closing]
      [%open %force-closing]
      [%shutdown %force-closing]
      [%closing %force-closing]
    ::
      [%opening %closed]
      [%funded %closed]
      [%open %closed]
      [%shutdown %closed]
      [%closing %closed]
    ::
      [%force-closing %force-closing]
      [%force-closing %closed]
      [%force-closing %redeemed]
      [%closed %redeemed]
      [%opening %redeemed]
      [%preopening %redeemed]
  ==
::
++  new
  |=  $:  =local-config
          =remote-config
          =funding=outpoint
          initial-feerate=sats:bc
          initiator=?
          anchor-outputs=?
          capacity=sats:bc
          funding-tx-min-depth=blocks
      ==
  |^  ^-  chan
  =|  channel=chan
  =+  id=(make-channel-id txid.funding-outpoint pos.funding-outpoint)
  %=  channel
    id                id
    funding-outpoint  funding-outpoint
    constraints       constraints
    our.config        local-config
    her.config        remote-config
  ==
  ++  constraints
    :*  initiator=initiator
        anchor-outputs=anchor-outputs
        capacity=capacity
        initial-feerate=initial-feerate
        funding-tx-min-depth=funding-tx-min-depth
    ==
  --
::
++  is-active
  ^-  ?
  =(state.c %open)
::
++  is-funded
  ^-  ?
  =/  funded-states=(list chan-state)
    :~  %funded
        %open
        %shutdown
        %closing
        %force-closing
        %redeemed
    ==
  ?=(^ (find [state.c]~ funded-states))
::
++  is-closing
  ^-  ?
  =/  closing-states=(list chan-state)
    ~[%shutdown %closing %force-closing]
  ?=(^ (find [state.c]~ closing-states))
::
++  is-closed
  ^-  ?
  =/  closed-states=(list chan-state)
    ~[%closing %force-closing %redeemed]
  ?=(^ (find [state.c]~ closed-states))
::
++  is-redeemed
  =(state.c %redeemed)
::
++  can-update
  ^-  ?
  ?|  =(state.c %open)
      =(state.c %closing)
  ==
::
++  set-state
  |=  new-state=chan-state
  ^+  c
  ?.  (~(has in state-transitions) [state.c new-state])
    ~|("illegal-state-transition: {<state.c>}->{<new-state>}" !!)
  %_  c  state  new-state  ==
::
++  invert-owner
  |=  o=owner
  ^-  owner
  ?-  o
    %local   %remote
    %remote  %local
  ==
::
++  config-for
  |=  =owner
  ^-  channel-config
  ?-  owner
    %local   -.our.config.c
    %remote  -.her.config.c
  ==
::
++  commitments-for
  |=  =owner
  ^-  (list commitment)
  ?-  owner
    %local   our.commitments.c
    %remote  her.commitments.c
  ==
::
++  updates-for
  |=  who=owner
  ^-  update-log
  ?-  who
    %local   our.updates.c
    %remote  her.updates.c
  ==
::
++  has-unacked-commitment
  |=  who=owner
  ^-  ?
  %~  has-unacked-commitment  commitment-chain
  ?-  who
    %local   our.commitments.c
    %remote  her.commitments.c
  ==
::
++  has-pending-changes
  |=  who=owner
  ^-  ?
  =/  log  ~(entries log (updates-for who))
  =/  filtered
    (skim log |=(=update !=(%add-htlc -.update)))
  !=(~ filtered)
::
++  make-funding-address
  |=  [=network =local-funding=pubkey =remote-funding=pubkey]
  ^-  address:bc
  :-  %bech32
  %-  need
  %+  bech32-encode  network
  %-  sha256:bcu:bc
  %-  en:btc-script
  %+  funding-output:script
    local-funding-pubkey
  remote-funding-pubkey
::
++  funding-address
  ^-  address:bc
  %^    make-funding-address
      network.our.config.c
    pub.multisig-key.our.config.c
  pub.multisig-key.her.config.c
::
++  sweep-address
  =,  secp256k1:secp:crypto
  ^-  address:bc
  ::  using static-remotekey:
  :-  %bech32
  %-  need
  %+  encode-pubkey:bech32:bolt11  network.our.config.c
  33^(compress-point pub.payment.basepoints.our.config.c)
::
++  shutdown-script
  =,  secp256k1:secp:crypto
  ^-  hexb:bc
  :: ?:  !=(wid.upfront-shutdown-script.our.config.c 0)
  ::   upfront-shutdown-script.our.config.c
  (p2wpkh:script pub.payment.basepoints.our.config.c)
::
++  her-shutdown-script
  =,  secp256k1:secp:crypto
  ^-  hexb:bc
  :: ?:  !=(wid.upfront-shutdown-script.our.config.c 0)
  ::   upfront-shutdown-script.our.config.c
  (p2wpkh:script pub.payment.basepoints.her.config.c)
::
++  funding-tx-min-depth
  ^-  blocks
  funding-tx-min-depth.constraints.c
::
++  oldest-unrevoked-commitment
  |=  =owner
  ^-  (unit commitment)
  %~  oldest-unrevoked  commitment-chain
  (commitments-for owner)
::
++  latest-commitment
  |=  =owner
  ^-  (unit commitment)
  %~  latest  commitment-chain
  (commitments-for owner)
::
++  oldest-unrevoked-commitment-number
  |=  =owner
  ^-  commitment-number
  =+  oldest=(oldest-unrevoked-commitment owner)
  ?~  oldest  !!
  height.u.oldest
::  +compact-logs: clean up logs after received revocations
::
++  compact-logs
  |=  $:  our-log=update-log
          her-log=update-log
          local-tail=@  ::  2
          remote-tail=@  ::  3
      ==
  |^
  ^-  [ours=update-log hers=update-log]
  =/  [ours=update-log hers=update-log]
    (compact-log our-log her-log)
  =/  [hers=update-log ours=update-log]
    (compact-log hers ours)
  [ours=ours hers=hers]
  ++  compact-log
    |=  [a=update-log b=update-log]
    ^-  [a=update-log b=update-log]
    %+  roll  ~(entries log a)
    |:  [u=*update acc=[a=a b=b]]
    ?:  ?=([%add-htlc *] u)  acc
    ?:  ?|  =(0 her.rem-height.u)
            =(0 our.rem-height.u)
        ==
      acc
    ?:  ?&  (gte remote-tail her.rem-height.u)
            (gte local-tail our.rem-height.u)
        ==
      ?-    -.u
          %fee
        acc(a (~(remove-update log a.acc) index.u))
      ::
          %settle-htlc
        %=  acc
          a  (~(remove-update log a.acc) index.u)
          b  (~(remove-htlc log b.acc) parent.u)
        ==
      ::
          %fail-htlc
        %=  acc
          a  (~(remove-update log a.acc) index.u)
          b  (~(remove-htlc log b.acc) parent.u)
        ==
      ::
          %fail-malformed-htlc
        %=  acc
          a  (~(remove-update log a.acc) index.u)
          b  (~(remove-htlc log b.acc) parent.u)
        ==
      ==
    acc
  --
::  +htlc-potential-indices: find set of indices with same script and value
::
++  htlc-potential-indices
  |=  [htlc=add-htlc:update =commitment =direction keys=commitment-keys]
  ^-  (list @)
  =+  ^=  address
    ^-  hexb:bc
    %-  p2wsh:script
    %:  htlc-witness:script
      direction=direction
      local-htlc-pubkey=this-htlc-pubkey.keys
      remote-htlc-pubkey=that-htlc-pubkey.keys
      remote-revocation-pubkey=that-revocation-pubkey.keys
      payment-hash=payment-hash.htlc
      cltv-expiry=`timeout.htlc
      confirmed-spend=anchor-outputs.constraints.c
    ==
  %+  fand  ~[[address (msats-to-sats amount-msats.htlc)]]
  %+  turn  outputs.tx.commitment
  |=  =output:psbt
  :*  script-pubkey=script-pubkey.output
      value=value.output
  ==
::  +index-htlcs: index htlc in commitment transactions
::
++  index-htlcs
  |=  [=commitment keys=commitment-keys]
  |^
  ^-  ^commitment
  =+  ^=  unclaimed
    ^-  (set @)
    %-  silt
    %+  gulf  0
    %-  dec
    (lent outputs.tx.commitment)
  ::  presort htlcs by timeout to prserve cltv order of indices
  ::  potential sent and received htlc indices will never overlap
  ::  since their script-pubkeys will always be different
  =^  ours  unclaimed
    %^    spin
        (sort sent-htlcs.commitment cltv-lte)
      unclaimed
    (add-output-index %local)
  =^  hers  unclaimed
    %^    spin
        (sort recd-htlcs.commitment cltv-lte)
      unclaimed
    (add-output-index %remote)
  %=  commitment
    sent-htlcs       ours
    recd-htlcs       hers
    sent-htlc-index  (build-index ours)
    recd-htlc-index  (build-index hers)
  ==
  ++  cltv-lte
    |=  [a=add-htlc:update b=add-htlc:update]
    (lte timeout.a timeout.b)
  ::
  ++  build-index
    |=  htlcs=(list add-htlc:update)
    ^-  (map @ add-htlc:update)
    %+  roll  htlcs
    |=  [h=add-htlc:update acc=(map @ add-htlc:update)]
    (~(put by acc) output-index.h h)
  ::
  ++  add-output-index
    |=  sender=owner
    |=  [htlc=add-htlc:update idx=(set @)]
    ^-  (pair add-htlc:update (set @))
    =+  ^=  direction
      ?:  =(owner.commitment sender)
        %sent
      %received
    =/  candidates=(list @)
      %:  htlc-potential-indices
        htlc=htlc
        commitment=commitment
        direction=direction
        keys=keys
      ==
    |-
    ?~  candidates  ~|(%no-htlc-index !!)
    =+  i=(head candidates)
    ::  always take lowest unclaimed index to preserve cltv order
    ?:  (~(has in idx) i)
      [htlc(output-index i) (~(del in idx) i)]
    $(candidates (tail candidates))
  --
::  +owes-commitment: are there outstanding commitments requiring signatures?
::
++  owes-commitment
  |=  whose=owner
  ^-  ?
  =+  last-local=(latest-commitment %local)
  =+  last-remote=(latest-commitment %remote)
  ?~  last-local   !!
  ?~  last-remote  !!
  =/  local-pending=?   %.n
  =/  remote-pending=?  %.n
  =?  local-pending  =(whose %local)
    !=(update-count.our.updates.c msg-idx.our.u.last-remote)
  =?  remote-pending  =(whose %local)
    !=(msg-idx.her.u.last-local msg-idx.her.u.last-remote)
  =?  local-pending  =(whose %remote)
    !=(update-count.her.updates.c msg-idx.her.u.last-local)
  =?  remote-pending  =(whose %remote)
    !=(msg-idx.our.u.last-remote msg-idx.our.u.last-local)
  ?|(local-pending remote-pending)
::  +generate-commitment-keys: generate per-commitment public keys
::
++  derive-commitment-keys
  |=  [whose=owner =commitment=point]
  |^
  ^-  commitment-keys
  =|  keys=commitment-keys
  %=  keys
    commitment-point          commitment-point
    this-htlc-pubkey          this-htlc-pubkey
    that-htlc-pubkey          that-htlc-pubkey
    that-revocation-pubkey    that-revocation-pubkey
    payment-pubkey            payment-pubkey
    delayed-pubkey            delayed-pubkey
    funder-payment-basepoint  funder-payment-basepoint
    fundee-payment-basepoint  fundee-payment-basepoint
  ==
  ++  this-config  (config-for whose)
  ++  that-config  (config-for (invert-owner whose))
  ::
  ++  this-htlc-pubkey
    ^-  pubkey
    %+  derive-pubkey:keys
      pub.htlc.basepoints:this-config
    commitment-point
  ::
  ++  that-htlc-pubkey
    ^-  pubkey
    %+  derive-pubkey:keys
      pub.htlc.basepoints:that-config
    commitment-point
  ::
  ++  that-revocation-pubkey
    ^-  pubkey
    %+  derive-revocation-pubkey:keys
      pub.revocation.basepoints:that-config
    commitment-point
  ::
  ++  payment-pubkey
    ^-  pubkey
    %+  derive-pubkey:keys
      pub.payment.basepoints:that-config
    commitment-point
  ::
  ++  delayed-pubkey
    ^-  pubkey
    %+  derive-pubkey:keys
      pub.delayed-payment.basepoints:this-config
    commitment-point
  ::
  ++  funder-payment-basepoint
    ^-  point
    ?:  initiator.constraints.c
      pub.payment.basepoints.our.config.c
    pub.payment.basepoints.her.config.c
  ::
  ++  fundee-payment-basepoint
    ^-  point
    ?:  initiator.constraints.c
      pub.payment.basepoints.her.config.c
    pub.payment.basepoints.our.config.c
  --
::
+$  evaluation-state
  $:  whose=owner
      height=commitment-number
      our-balance=msats
      her-balance=msats
      our-removals=(set @)
      her-removals=(set @)
      our-htlcs=(list add-htlc:update)
      her-htlcs=(list add-htlc:update)
      ours-pending-lock-in=(list update)
      hers-pending-lock-in=(list update)
      ours-in-flight=@
      our-amount-in-flight=msats
      hers-in-flight=@
      her-amount-in-flight=msats
      sent-settled=@
      recd-settled=@
      total-weight=@
      fee=sats:bc
      fee-rate=sats:bc
  ==
::
++  initial-evaluation-state
  |=  [whose=owner height=@]
  ^-  evaluation-state
  =|  state=evaluation-state
  %=  state
    whose   whose
    height  height
  ==
::
+$  evaluation-error
  $%  [%balance-too-low =owner]
      [%constraint-violated @tas =owner]
      [%no-remote-commitment height=commitment-number]
  ==
::
++  secret-and-point
  |=  [whose=owner height=@]
  ^-  (each [secret=(unit @) point=point] evaluation-error)
  ?-    whose
      %remote
    =/  offset=@s
      %+  dif:si  (new:si %& height)
      %+  new:si  %&
      (oldest-unrevoked-commitment-number whose)
    ?:  =(--1 (cmp:si offset --1))
      [%| [%no-remote-commitment height]]
    =+  conf=her.config.c
    :-  %&
    ?:  =(offset --1)
      :*  secret=~
          point=next-per-commitment-point.conf
      ==
    ?:  =(offset --0)
      :*  secret=~
          point=current-per-commitment-point.conf
      ==
    =/  secr=@
      %-  ~(retrieve revocation revocations.c)
        (sub first-index:secret height)
    :*  secret=`secr
        point=(compute-commitment-point:secret secr)
    ==
      %local
    =+  conf=our.config.c
    =/  secr=@
      %^    generate-from-seed:secret
          per-commitment-secret-seed.conf
        (sub first-index:secret height)
      ~
    :-  %&
    :*  secret=`secr
        point=(compute-commitment-point:secret secr)
    ==
  ==
::
++  select-updates
  |=  [our-index=@ her-index=@]
  ^-  [ours=(list update) hers=(list update)]
  =+  ^=  acc-updates
    |=  index=@
    |=  [=update acc=(list update)]
    ?:  (lth index.update index)
      [update acc]
    acc
  :*  ^=  ours
    %+  roll  ~(entries log our.updates.c)
    (acc-updates our-index)
  ::
    ^=  hers
    %+  roll  ~(entries log her.updates.c)
    (acc-updates her-index)
  ==
::
++  removed-indices
  |=  updates=(list update)
  ^-  (set @)
  %+  roll  updates
  |=  [=update acc=(set @)]
  ?+  -.update  acc
    %settle-htlc          (~(put in acc) parent.update)
    %fail-htlc            (~(put in acc) parent.update)
    %fail-malformed-htlc  (~(put in acc) parent.update)
  ==
::
++  evaluate-updates
  |=  $:  ours=(list update)
          hers=(list update)
          state=evaluation-state
      ==
  |^
  ^-  (each evaluation-state evaluation-error)
  =.  state
    %=  state
      our-removals  (removed-indices ours)
      her-removals  (removed-indices hers)
    ==
  =/  result=(each evaluation-state evaluation-error)
    [%& state]
  =.  result
    %+  roll  ours
    |:  [entry=*update state=result]
    ?:  ?=([%| *] state)  state
    (evaluate-update entry %.y +.state)
  =.  result
    %+  roll  hers
    |:  [entry=*update state=result]
    ?:  ?=([%| *] state)  state
    (evaluate-update entry %.n +.state)
  result
  ::
  ++  evaluate-update
    |=  [=update ours=? state=evaluation-state]
    ^-  (each evaluation-state evaluation-error)
    ?+  -.update   (evaluate-remove update ours state)
      %add-htlc    (evaluate-add update ours state)
      %fee  (evaluate-fee update ours state)
    ==
  ::
  ++  apply-constraints
    |=  [update=add-htlc:update ours=? state=evaluation-state]
    ^-  (unit evaluation-error)
    =+  who=?:(ours %local %remote)
    =+  config=(config-for who)
    =+  ^=  amt-in-flight
      ?:  ours
        our-amount-in-flight.state
      her-amount-in-flight.state
    =+  ^=  num-in-flight
      ?:  ours
        ours-in-flight.state
      hers-in-flight.state
    =+  next-amt=(add amt-in-flight amount-msats.update)
    ?:  (gth next-amt max-htlc-value-in-flight-msats.config)
      `[%constraint-violated %max-htlc-value-in-flight who]
    ?:  (gth +(num-in-flight) max-accepted-htlcs.config)
      `[%constraint-violated %max-accepted-htlcs who]
    ?:  (lth next-amt htlc-minimum-msats.config)
      `[%constraint-violated %htlc-minimum-msats who]
    ?:  (lth amount-msats.update htlc-minimum-msats.config)
      `[%constraint-violated %htlc-minimum-msats who]
    ~
  ::
  ++  evaluate-add
    |=  [=update ours=? state=evaluation-state]
    ^-  (each evaluation-state evaluation-error)
    ?>  ?=([%add-htlc *] update)
    =+  ^=  removed
      ?:  ours
        her-removals.state
      our-removals.state
    ?:  (~(has in removed) htlc-id.update)
      [%& state]
    =+  ^=  add-height
      ?:  =(%local whose.state)
        our.add-height.update
      her.add-height.update
    ?.  =(add-height 0)  [%& state]
    ::  check balances
    ::
    ?:  ?&(ours (lth our-balance.state amount-msats.update))
      [%| [%balance-too-low %local]]
    ?:  ?&(?!(ours) (lth her-balance.state amount-msats.update))
      [%| [%balance-too-low %remote]]
    ::  update balances
    ::
    =?  our-balance.state  ours
      (sub our-balance.state amount-msats.update)
    =?  her-balance.state  ?!(ours)
      (sub her-balance.state amount-msats.update)
    ::  check channel reserve
    ::
    ?:  ?&  ours
          %+  lth  (msats-to-sats our-balance.state)
          reserve-sats:(config-for %local)
        ==
      [%| [%balance-too-low %local]]
    ?:  ?&  ?!(ours)
          %+  lth  (msats-to-sats her-balance.state)
          reserve-sats:(config-for %remote)
        ==
      [%| [%balance-too-low %remote]]
    ::  check constraints
    ::
    =/  error=(unit evaluation-error)
      %:  apply-constraints
        update=+.update
        ours=ours
        state=state
      ==
    ?^  error  [%| u.error]
    :-  %&
    ?:  ours
      %=  state
        ours-pending-lock-in  (snoc ours-pending-lock-in.state update)
        our-htlcs             [+.update our-htlcs.state]
        ours-in-flight        +(ours-in-flight.state)
        our-amount-in-flight  (add our-amount-in-flight.state amount-msats.update)
      ==
    %=  state
      hers-pending-lock-in  (snoc hers-pending-lock-in.state update)
      her-htlcs             [+.update her-htlcs.state]
      hers-in-flight        +(hers-in-flight.state)
      her-amount-in-flight  (add her-amount-in-flight.state amount-msats.update)
    ==
  ::
  ++  evaluate-remove
    |=  [=update ours=? state=evaluation-state]
    ^-  (each evaluation-state evaluation-error)
    =+  ^=  rem-height
      ?:  =(%local whose.state)
        our.rem-height.update
      her.rem-height.update
    ?.  =(rem-height 0)  [%& state]
    =/  amount=msats
      ?+  -.update  !!
        %settle-htlc          amount-msats.update
        %fail-htlc            amount-msats.update
        %fail-malformed-htlc  amount-msats.update
      ==
    :-  %&
    =?  state  ours
      state(ours-pending-lock-in (snoc ours-pending-lock-in.state update))
    =?  state  ?!(ours)
      state(hers-pending-lock-in (snoc hers-pending-lock-in.state update))
    ::
    =?  state  ?&(ours ?=([%settle-htlc *] update))
      %=  state
        our-balance   (add our-balance.state amount)
        recd-settled  (add recd-settled.state amount)
      ==
    =?  state  ?&(ours ?!(?=([%settle-htlc *] update)))
      state(her-balance (add her-balance.state amount))
    ::
    =?  state  ?&(?!(ours) ?=([%settle-htlc *] update))
      %=  state
        her-balance   (add her-balance.state amount)
        sent-settled  (add sent-settled.state amount)
      ==
    =?  state  ?&(?!(ours) ?!(?=([%settle-htlc *] update)))
      state(our-balance (add our-balance.state amount))
    ::
    state
  ::
  ++  evaluate-fee
    |=  [=update ours=? state=evaluation-state]
    ^-  (each evaluation-state evaluation-error)
    ?>  ?=([%fee *] update)
    =+  ^=  add-height
      ?:  =(%local whose.state)
        our.add-height.update
      her.add-height.update
    ?.  =(add-height 0)  [%& state]
    =?  state  ours
      state(ours-pending-lock-in (snoc ours-pending-lock-in.state update))
    =?  state  ?!(ours)
      state(hers-pending-lock-in (snoc hers-pending-lock-in.state update))
    [%& state(fee-rate fee-rate.update)]
  --
::
++  is-htlc-dust
  |=  [ctx-owner=owner fee-per-kw=sats:bc htlc-owner=owner h=add-htlc:update]
  ^-  ?
  %:  is-trimmed:tx
    direction=?:(=(ctx-owner htlc-owner) %sent %received)
    amount-msats=amount-msats.h
    feerate=fee-per-kw
    dust-limit=dust-limit-sats:(config-for ctx-owner)
    anchor=anchor-outputs.constraints.c
  ==
::
++  commitment-weight
  |=  $:  whose=owner
          fee-rate=sats:bc
          our=(list add-htlc:update)
          her=(list add-htlc:update)
      ==
  |^  ^-  @
  =+  n-ours=(lent (skip our (is-dust %local)))
  =+  n-hers=(lent (skip her (is-dust %remote)))
  %+  add
    ?:  anchor-outputs.constraints.c
      anchor-commit-weight:tx
    commitment-tx-weight:tx
  %+  add
    (mul n-ours htlc-output-weight:tx)
  (mul n-hers htlc-output-weight:tx)
  ++  is-dust
    |=  sender=owner
    |=  h=add-htlc:update
    ^-  ?
    (is-htlc-dust whose fee-rate sender h)
  --
::
++  add-commitment-weight-and-fee
  |=  state=evaluation-state
  ^-  evaluation-state
  =/  weight=@
    %:  commitment-weight
      whose=whose.state
      fee-rate=fee-rate.state
      our=our-htlcs.state
      her=her-htlcs.state
    ==
  %=  state
    total-weight  weight
    fee           (fee-by-weight fee-rate.state weight)
  ==
::
++  add-back-fees
  |=  state=evaluation-state
  ^-  evaluation-state
  =+  latest=(latest-commitment whose.state)
  ?~  latest  state
  ?:  initiator.constraints.c
    state(our-balance (add fee.u.latest our-balance.state))
  state(her-balance (add fee.u.latest her-balance.state))
::
++  check-fee
  |=  state=evaluation-state
  =+  our-sats=(msats-to-sats our-balance.state)
  =+  her-sats=(msats-to-sats her-balance.state)
  ?:  initiator.constraints.c
    ?:  (lth our-sats fee.state)
      [%| %balance-too-low %local]
    ?:  %+  lth  (sub our-sats fee.state)
        reserve-sats.our.config.c
      [%| %balance-too-low %local]
    [%& state]
  ?:  (lth her-sats fee.state)
    [%| %balance-too-low %remote]
  ?:  %+  lth  (sub her-sats fee.state)
      reserve-sats.her.config.c
    [%| %balance-too-low %remote]
  [%& state]
::
++  apply-pending-lock-ins
  |=  state=evaluation-state
  ^-  [our=update-log her=update-log]
  |^
  :*  ^=  our
    %+  apply-lock-ins
      ours-pending-lock-in.state
    our.updates.c
  ::
      ^=  her
    %+  apply-lock-ins
      hers-pending-lock-in.state
    her.updates.c
  ==
  ++  apply-lock-ins
    |=  [updates=(list update) log=update-log]
    ^-  update-log
    %+  roll  updates
    ::  TODO: avoid breaking update-log abstraction
    |:  [update=*update log=log]
    =+  index=(find ~[update] ~(entries ^^log log))
    ?~  index  !!
    =.  update  (lock-in-update update whose.state height.state)
    %=    log
        list
      (snap list.log u.index update)
    ::
        htlc-index
      ?:  ?=([%add-htlc *] update)
        (~(put by htlc-index.log) htlc-id.update update)
      htlc-index.log
    ::
        update-index
      ?.  ?=([%add-htlc *] update)
        (~(put by update-index.log) index.update update)
      update-index.log
    ==
  ::
  ++  lock-in-update
    |=  [this=update whose=owner next-height=commitment-number]
    ^-  update
    ?:  ?=([%add-htlc *] this)
      =?  our.add-height.this  =(whose %local)   next-height
      =?  her.add-height.this  =(whose %remote)  next-height
      this
    ?:  ?=([%fee *] this)
      =?  our.add-height.this  =(whose %local)   next-height
      =?  our.rem-height.this  =(whose %local)   next-height
      =?  her.add-height.this  =(whose %remote)  next-height
      =?  her.rem-height.this  =(whose %remote)  next-height
      this
    =?  our.rem-height.this  =(whose %local)     next-height
    =?  her.rem-height.this  =(whose %remote)    next-height
    this
  --
::  +evaluate-next-commitment: process update logs for next commitment
::
++  evaluate-next-commitment
  |=  [whose=owner our-index=@ her-index=@]
  ^-  (each evaluation-state evaluation-error)
  =+  latest=(latest-commitment whose)
  ?~  latest  !!
  =+  next-height=+(height.u.latest)
  =+  state=(initial-evaluation-state whose next-height)
  =.  state
    %=  state
      our-balance  balance.our.u.latest
      her-balance  balance.her.u.latest
      fee-rate     fee-per-kw.u.latest
    ==
  ::  TODO: move fee computation here
  ::  =.  state  (add-back-fees state)
  =+  (select-updates our-index her-index)
  =+  result=(evaluate-updates ours hers state)
  ?:  ?=([%| *] result)  result
  =.  state  +.result
  =.  state  (add-commitment-weight-and-fee state)
  (check-fee state)
::  +first-commitment: generate first commitment
::
++  first-commitment
  |=  [whose=owner keys=commitment-keys]
  ^-  commitment
  =|  =commitment
  =+  state=(initial-evaluation-state whose 0)
  =.  state
    %=  state
      our-balance  initial-msats.our.config.c
      her-balance  initial-msats.her.config.c
      fee-rate     initial-feerate.constraints.c
    ==
  =.  state  (add-commitment-weight-and-fee state)
  %=  commitment
    height       0
    owner        whose
    tx           (make-commitment-tx state keys)
    fee          fee.state
    fee-per-kw   fee-rate.state
    dust-limit   dust-limit-sats:(config-for whose)
    balance.our  our-balance.state
    balance.her  her-balance.state
  ==
::  +next-commitment: generate next commitment, with final value of accumulator
::
++  next-commitment
  |=  $:  whose=owner
          our-index=@  our-htlc-index=@
          her-index=@  her-htlc-index=@
          keys=commitment-keys
      ==
  ^-  (each (pair commitment evaluation-state) evaluation-error)
  =|  =commitment
  =+  result=(evaluate-next-commitment whose our-index her-index)
  ?:  ?=([%| *] result)  result
  =/  state=evaluation-state  +.result
  =.  commitment
    %=  commitment
      height      height.state
      owner       whose
      tx          (make-commitment-tx state keys)
      fee         fee.state
      fee-per-kw  fee-rate.state
      dust-limit  dust-limit-sats:(config-for whose)
      sent-htlcs  our-htlcs.state
      recd-htlcs  her-htlcs.state
      our     :*  msg-idx=our-index
                  htlc-idx=our-htlc-index
                  balance=our-balance.state
              ==
      her     :*  msg-idx=her-index
                  htlc-idx=her-htlc-index
                  balance=her-balance.state
    ==        ==
  =.  commitment  (index-htlcs commitment keys)
  [%& commitment state]
::  +sign-commitment: sign commitment transaction using local private key
::
++  sign-commitment
    |=  [tx=psbt:psbt =local-config]
    ^-  signature
    =+  privkey=32^prv.multisig-key.local-config
    =+  keys=(malt ~[[pub.multisig-key.local-config privkey]])
    =.  tx  (~(all sign:psbt tx) keys)
    %-  ~(got by partial-sigs:(snag 0 inputs.tx))
      pub.multisig-key.local-config
::  +check-commitment-signature: validate signature of commitment tx
::
++  check-commitment-signature
  |=  [tx=psbt:psbt =signature =pubkey]
  ^-  ?
  =/  sighash=hexb:bc
    %-  dsha256:bcu:bc
    (~(witness-preimage sign:psbt tx) 0 ~)
  (check-signature sighash signature pubkey)
::  +sign-htlcs: sign commitment's HTLCs
::
++  sign-htlcs
  |=  [ctx=commitment =privkey keys=commitment-keys]
  |^  ^-  (list signature)
  =|  acc=(list signature)
  =+  i=0
  =+  n=(lent outputs.tx.ctx)
  ::  iterate tx outputs, sign if it's a non-dust indexed htlc
  |-
  ?:  =(i n)
    acc
  ?:  (~(has by sent-htlc-index.ctx) i)
    =+  htlc=(~(got by sent-htlc-index.ctx) i)
    ?:  (is-htlc-dust owner.ctx fee-per-kw.ctx %local htlc)
      $(i +(i))
    =+  sig=(sign-one %local htlc)
    %=  $
      i    +(i)
      acc  (snoc acc sig)
    ==
  ?:  (~(has by recd-htlc-index.ctx) i)
    =+  htlc=(~(got by recd-htlc-index.ctx) i)
    ?:  (is-htlc-dust owner.ctx fee-per-kw.ctx %remote htlc)
      $(i +(i))
    =+  sig=(sign-one %remote htlc)
    %=  $
      i    +(i)
      acc  (snoc acc sig)
    ==
  $(i +(i))
  ++  sign-one
    |=  [whose=owner htlc=add-htlc:update]
    ^-  signature
    %^  %~  one  sign:psbt
        %:  make-htlc-tx
          htlc=htlc
          direction=?:(=(owner.ctx whose) %sent %received)
          commitment=ctx
          keys=keys
        ==
    0  32^privkey  ~
  --
::  +check-htlc-signatures: validate HTLC signatures for commitment
::
++  check-htlc-signatures
  |=  [ctx=commitment signatures=(list signature) =pubkey keys=commitment-keys]
  ^-  ?
  =|  ok=?
  =+  i=0
  =+  n=(lent outputs.tx.ctx)
  ::  iterate tx outputs. if there's an htlc at that index, verify the signature
  |-
  ?.  ok      ok
  ?:  =(i n)  ok
  =/  htlc-and-owner=(unit (pair add-htlc:update owner))
    ?:  (~(has by sent-htlc-index.ctx) i)
      `[(~(got by sent-htlc-index.ctx) i) %local]
    ?:  (~(has by recd-htlc-index.ctx) i)
      `[(~(got by recd-htlc-index.ctx) i) %remote]
    ~
  ?~  htlc-and-owner  $(i +(i))
  =/  [htlc=add-htlc:update whose=owner]
    u.htlc-and-owner
  ?:  (is-htlc-dust owner.ctx fee-per-kw.ctx whose htlc)
    $(i +(i))
  =/  htlc-tx=psbt:psbt
    %:  make-htlc-tx
      htlc=htlc
      direction=?:(=(owner.ctx whose) %sent %received)
      commitment=ctx
      keys=keys
    ==
  =/  hash=hexb:bc
    %-  dsha256:bcu:bc
    (~(witness-preimage sign:psbt htlc-tx) 0 ~)
  %=  $
    i           +(i)
    signatures  (tail signatures)
    ok          (check-signature hash (head signatures) pubkey)
  ==
::  +sign-first-commitment: sign first commitment, for channel init
::
++  sign-first-commitment
  |=  =first-commitment=point
  ^-  (pair signature chan)
  =+  keys=(derive-commitment-keys %remote first-commitment-point)
  =+  commitment=(first-commitment %remote keys)
  =+  signature=(sign-commitment tx.commitment our.config.c)
  =.  signature.commitment  signature
  :-  signature
  %=    c
      her.commitments
    (~(add-commitment commitment-chain her.commitments.c) commitment)
  ::
      current-per-commitment-point.her.config
    first-commitment-point
  ==
::  +receive-first-commitment: receive first commitment signature, for channel init
::
++  receive-first-commitment
  |=  sig=signature
  ^-  chan
  =+  secret-and-point=(secret-and-point %local 0)
  ?>  ?=([%& *] secret-and-point)
  =/  [secret=(unit @) point=point]  +.secret-and-point
  =+  keys=(derive-commitment-keys %local point)
  =+  commitment=(first-commitment %local keys)
  =.  commitment
    %=  commitment
      signature       sig
      htlc-signatures  ~
    ==
  ~|  %invalid-commitment-signature
  ?>  (check-commitment-signature tx.commitment sig pub.multisig-key.her.config.c)
  %=    c
      current-commitment-signature.our.config
    sig
  ::
      our.commitments
    (~(add-commitment commitment-chain our.commitments.c) commitment)
  ==
::  +sign-next-commitment: create signatures for next remote commitment tx
::
++  sign-next-commitment
  ^-  (pair (pair signature (list signature)) chan)
  %-  ?.  (owes-commitment %local)
        ~|  "%volt: unexpected commitment"
          !!
      same
  ?:  ~(has-unacked-commitment commitment-chain her.commitments.c)
    ~|(%unexpected-commitment !!)
  =+  previous=(oldest-unrevoked-commitment %local)
  ?~  previous  !!
  =+  remote-acked-index=msg-idx.her.u.previous
  =+  remote-htlc-index=htlc-idx.her.u.previous
  =+  commitment-point=next-per-commitment-point.her.config.c
  =+  keys=(derive-commitment-keys %remote commitment-point)
  =+  ^=  commitment-and-state
    %:  next-commitment
      whose=%remote
      our-index=update-count.our.updates.c
      our-htlc-index=htlc-count.our.updates.c
      her-index=remote-acked-index
      her-htlc-index=remote-htlc-index
      keys=keys
    ==
  ?>  ?=([%& *] commitment-and-state)
  =/  commitment=commitment   +<.commitment-and-state
  =/  state=evaluation-state  +>.commitment-and-state
  =+  ^=  htlc-privkey
    %^    derive-privkey:^keys
        pub.htlc.basepoints.our.config.c
      commitment-point
    prv.htlc.basepoints.our.config.c
  =+  new-logs=(apply-pending-lock-ins state)
  =+  sig=(sign-commitment tx.commitment our.config.c)
  =/  htlc-sigs=(list signature)
    %:  sign-htlcs
      commitment=commitment
      privkey=htlc-privkey
      keys=keys
    ==
  =.  commitment
    %=  commitment
      signature        sig
      htlc-signatures  htlc-sigs
    ==
  :-  [sig htlc-sigs]
  %=  c
    our.updates      our.new-logs
    her.updates      her.new-logs
    her.commitments  (~(add-commitment commitment-chain her.commitments.c) commitment)
  ==
::  +receive-new-commitment: process signatures for our next local commitment
::
++  receive-new-commitment
  |=  [sig=signature htlc-sigs=(list signature)]
  ^-  chan
  %-  ?.  (owes-commitment %remote)
        ~|  "%volt: unexpected commitment"
           !!
      same
  =+  previous=(oldest-unrevoked-commitment %remote)
  ?~  previous  !!
  =+  local-acked-index=msg-idx.our.u.previous
  =+  local-htlc-index=htlc-idx.our.u.previous
  =+  next-height=+(height.commitments.c)
  =+  secret-and-point=(secret-and-point %local next-height)
  ?>  ?=([%& *] secret-and-point)
  =/  [secret=(unit @) point=point]  +.secret-and-point
  =+  keys=(derive-commitment-keys %local point)
  =+  ^=  commitment-and-state
    %:  next-commitment
      whose=%local
      our-index=local-acked-index
      our-htlc-index=local-htlc-index
      her-index=update-count.her.updates.c
      her-htlc-index=htlc-count.her.updates.c
      keys=keys
    ==
  ?>  ?=([%& *] commitment-and-state)
  =/  commitment=commitment   +<.commitment-and-state
  =/  state=evaluation-state  +>.commitment-and-state
  =.  commitment
    %=  commitment
      signature        sig
      htlc-signatures  htlc-sigs
    ==
  ?.  (check-commitment-signature tx.commitment sig pub.multisig-key.her.config.c)
    ~|(%invalid-commitment-signature !!)
  ?.  (check-htlc-signatures commitment htlc-sigs that-htlc-pubkey.keys keys)
    ~|(%invalid-htlc-signature !!)
  =+  new-logs=(apply-pending-lock-ins state)
  %=    c
      current-commitment-signature.our.config
    sig
  ::
      current-htlc-signatures.our.config
    htlc-sigs
  ::
      our.commitments
    %-  ~(add-commitment commitment-chain our.commitments.c)
      commitment
  ::
    our.updates  our.new-logs
    her.updates  her.new-logs
    sent-msats   (add sent-msats.c sent-settled.state)
    recd-msats   (add recd-msats.c recd-settled.state)
  ==
::  +revoke-current-commitment: generate a revoke-and-ack for the current commitment
::
++  revoke-current-commitment
  ^-  (pair revoke-and-ack:msg chan)
  =|  result=revoke-and-ack:msg
  =+  last=(secret-and-point %local height.commitments.c)
  =+  next=(secret-and-point %local (add height.commitments.c 2))
  ?>  ?=([%& *] last)
  ?>  ?=([%& *] next)
  =/  [last-secret=(unit @) =last=point]  +.last
  =/  [next-secret=(unit @) =next=point]  +.next
  =.  result
    %=  result
      channel-id                 id.c
      per-commitment-secret      (need last-secret)
      next-per-commitment-point  next-point
    ==
  :-  result
  %=  c
    our.commitments     ~(advance commitment-chain our.commitments.c)
    height.commitments  +(height.commitments.c)
  ==
::  +receive-revocation: process a received revocation
::
++  receive-revocation
  =,  secp256k1:secp:crypto
  |=  =revoke-and-ack:msg
  ^-  chan
  =+  local-commit=(oldest-unrevoked-commitment %local)
  ?~  local-commit  !!
  =+  remote-commit=(oldest-unrevoked-commitment %remote)
  ?~  remote-commit  !!
  =+  cur-point=current-per-commitment-point.her.config.c
  =/  derived-point=point
    (priv-to-pub per-commitment-secret.revoke-and-ack)
  ~|  %revoked-secret-not-for-current-point
  ?>  =(cur-point derived-point)
  =/  [our-log=update-log her-log=update-log]
    %:  compact-logs
      our.updates.c          her.updates.c
      height.u.local-commit  +(height.u.remote-commit)
    ==
  %=    c
      current-per-commitment-point.her.config
    next-per-commitment-point.her.config.c
  ::
      next-per-commitment-point.her.config
    next-per-commitment-point.revoke-and-ack
  ::
      revocations
    %-  ~(add-next revocation revocations.c)
      per-commitment-secret.revoke-and-ack
  ::
      her.commitments
    ~(advance commitment-chain her.commitments.c)
  ::
      lookup.commitments
    %+  ~(put by lookup.commitments.c)  u.remote-commit
    per-commitment-secret.revoke-and-ack
  ::
    our.updates  our-log
    her.updates  her-log
  ==
::  +can-add-htlc: can HTLC be added to the current commitment?
::
++  can-add-htlc
  |=  [whose=owner update=add-htlc:update]
  ^-  ?
  ::  try appending the htlc to the appropriate log
  =/  test=chan
    %=    c
        our.updates
      ?:  =(whose %local)
        (~(append-htlc log our.updates.c) [%add-htlc update])
      our.updates.c
    ::
        her.updates
      ?.  =(whose %local)
        (~(append-htlc log her.updates.c) [%add-htlc update])
      her.updates.c
    ==
  ::  verify that the next commitment can be evaluated for each side
  =+  latest=(oldest-unrevoked-commitment %local)
  ?~  latest  !!
  =+  ^=  result
    %^    ~(evaluate-next-commitment +> test)
        %remote
      update-count.our.updates.test
    msg-idx.her.u.latest
  ?:  ?=([%| *] result)  %.n
  =+  ^=  result
    %^    ~(evaluate-next-commitment +> test)
        %local
      update-count.our.updates.test
    update-count.her.updates.test
  ?=([%& *] result)
::  +add-htlc: add a new local htlc to the channel
::
++  add-htlc
  |=  h=update-add-htlc:msg
  ^-  (pair update-add-htlc:msg chan)
  ~|  %cannot-add-htlc
  =|  update=add-htlc:update
  =.  update
    %=  update
      payment-hash  payment-hash.h
      timeout       cltv-expiry.h
      amount-msats  amount-msats.h
      index         update-count.our.updates.c
      htlc-id       htlc-count.our.updates.c
    ==
  ?>  (can-add-htlc %local update)
  :-  h(htlc-id htlc-id.update)
  %=  c
    our.updates  (~(append-htlc log our.updates.c) [%add-htlc update])
  ==
::  +receive-htlc: add a new remote htlc to the channel
::
++  receive-htlc
  |=  h=update-add-htlc:msg
  ^-  (pair update-add-htlc:msg chan)
  ~|  %cannot-add-htlc
  ?>  =(htlc-id.h htlc-count.her.updates.c)
  =|  update=add-htlc:update
  =.  update
    %=  update
      payment-hash  payment-hash.h
      timeout       cltv-expiry.h
      amount-msats  amount-msats.h
      index         update-count.her.updates.c
      htlc-id       htlc-count.her.updates.c
    ==
  ?>  (can-add-htlc %remote update)
  :-  h(htlc-id htlc-id.update)
  %=  c
    her.updates  (~(append-htlc log her.updates.c) [%add-htlc update])
  ==
::  +settle-htlc: settle/fulfill a pending received HTLC
::
++  settle-htlc
  |=  [preimage=hexb:bc =htlc-id]
  ^-  chan
  ~|  %cannot-remove-htlc
  =+  htlc=(~(lookup-htlc log her.updates.c) htlc-id)
  ?~  htlc  ~|(%unknown-htlc !!)
  ?>  ?=([%add-htlc *] u.htlc)
  ?<  (~(has in modified-htlcs.her.updates.c) htlc-id)
  ?>  =(payment-hash.u.htlc (sha256:bcu:bc preimage))
  =|  update=settle-htlc:update
  =.  update
    %=  update
      amount-msats  amount-msats.u.htlc
      preimage      preimage
      index         update-count.our.updates.c
      parent        htlc-id.u.htlc
    ==
  %=  c
    our.updates  (~(append-update log our.updates.c) [%settle-htlc update])
    her.updates  (~(mark-htlc-as-modified log her.updates.c) htlc-id)
  ==
::  +recive-htlc-settle: settle/fulfill a pending offered HTLC
::
++  receive-htlc-settle
  |=  [preimage=hexb:bc =htlc-id]
  ^-  chan
  ~|  %cannot-remove-htlc
  =+  htlc=(~(lookup-htlc log our.updates.c) htlc-id)
  ?~  htlc  ~|(%unknown-htlc !!)
  ?>  ?=([%add-htlc *] u.htlc)
  ?<  (~(has in modified-htlcs.our.updates.c) htlc-id)
  =|  update=settle-htlc:update
  =.  update
    %=  update
      amount-msats  amount-msats.u.htlc
      preimage      preimage
      parent        htlc-id.u.htlc
      payment-hash  payment-hash.u.htlc
      index         update-count.her.updates.c
    ==
  %=  c
    her.updates  (~(append-update log her.updates.c) [%settle-htlc update])
    our.updates  (~(mark-htlc-as-modified log our.updates.c) htlc-id)
  ==
::  +fail-htlc: fail a pending received HTLC
::
++  fail-htlc
  |=  =htlc-id
  ^-  chan
  ~|  %cannot-remove-htlc
  =+  htlc=(~(lookup-htlc log her.updates.c) htlc-id)
  ?~  htlc  ~|(%unknown-htlc !!)
  ?>  ?=([%add-htlc *] u.htlc)
  ?<  (~(has in modified-htlcs.her.updates.c) htlc-id)
  =|  update=fail-htlc:update
  =.  update
    %=  update
      amount-msats  amount-msats.u.htlc
      payment-hash  payment-hash.u.htlc
      parent        htlc-id.u.htlc
      index         update-count.our.updates.c
    ==
  %=  c
    our.updates  (~(append-update log our.updates.c) [%fail-htlc update])
    her.updates  (~(mark-htlc-as-modified log her.updates.c) htlc-id)
  ==
::  +receive-fail-htlc: fail a pending offered HTLC
::
++  receive-fail-htlc
  |=  =htlc-id
  ^-  chan
  ~|  %cannot-remove-htlc
  =+  htlc=(~(lookup-htlc log our.updates.c) htlc-id)
  ?~  htlc  ~|(%unknown-htlc !!)
  ?>  ?=([%add-htlc *] u.htlc)
  ?<  (~(has in modified-htlcs.our.updates.c) htlc-id)
  =|  update=fail-htlc:update
  =.  update
    %=  update
      amount-msats  amount-msats.u.htlc
      payment-hash  payment-hash.u.htlc
      parent        htlc-id.u.htlc
      index         update-count.her.updates.c
    ==
  %=  c
    her.updates  (~(append-update log her.updates.c) [%fail-htlc update])
    our.updates  (~(mark-htlc-as-modified log our.updates.c) htlc-id)
  ==
::  +update-fee: process a local feerate update
::
++  update-fee
  |=  feerate=sats:bc
  ^-  chan
  ?.  initiator.constraints.c
    ~|(%cannot-update-fee !!)
  =|  update=fee:update
  =.  update
    %=  update
      index     update-count.our.updates.c
      fee-rate  feerate
    ==
  %=  c
    our.updates  (~(append-update log our.updates.c) [%fee:update update])
  ==
::  +receive-update-fee: process a remote feerate update
::
++  receive-update-fee
  |=  feerate=sats:bc
  ^-  chan
  ?:  initiator.constraints.c
    ~|(%cannot-update-fee !!)
  =|  update=fee:update
  =.  update
    %=  update
      index     update-count.her.updates.c
      fee-rate  feerate
    ==
  %=  c
    her.updates  (~(append-update log her.updates.c) [%fee:update update])
  ==
::  +make-htlc-tx: construct HTLC transaction for signing and verifying
::
++  make-htlc-tx
  |=  $:  htlc=add-htlc:update
          =direction
          =commitment
          keys=commitment-keys
      ==
  ^-  psbt:psbt
  %:  htlc:tx
    direction=direction
    htlc=htlc
    ^=  commitment-outpoint
    :*  txid=(txid:psbt (extract-unsigned:psbt tx.commitment))
        pos=output-index.htlc
        sats=(msats-to-sats amount-msats.htlc)
    ==
    delayed-pubkey=delayed-pubkey.keys
    other-revocation-pubkey=that-revocation-pubkey.keys
    htlc-pubkey=this-htlc-pubkey.keys
    other-htlc-pubkey=that-htlc-pubkey.keys
    to-self-delay=to-self-delay:(config-for owner.commitment)
    feerate-per-kw=fee-per-kw.commitment
    anchor-outputs=anchor-outputs.constraints.c
  ==
::  +make-commitment-tx: generate owner's commitment transaction
::
++  make-commitment-tx
  |=  [state=evaluation-state keys=commitment-keys]
  ^-  psbt:psbt
  =+  state
  |^
  %:  commitment:tx
    commitment-number=height
    local-funding-pubkey=pub.multisig-key:this-config
    remote-funding-pubkey=pub.multisig-key:that-config
    remote-payment-pubkey=payment-pubkey.keys
    funder-payment-basepoint=funder-payment-basepoint.keys
    fundee-payment-basepoint=fundee-payment-basepoint.keys
    revocation-pubkey=that-revocation-pubkey.keys
    delayed-pubkey=delayed-pubkey.keys
    to-self-delay=to-self-delay:that-config
    funding-outpoint=funding-outpoint.c
    local-amount-msats=local-msats
    remote-amount-msats=remote-msats
    dust-limit-sats=dust-limit-sats:this-config
    anchor-outputs=anchor-outputs.constraints.c
    htlcs=commitment-htlcs
    fees-per-participant=onchain-fees
  ==
  ++  this-config  (config-for whose)
  ++  that-config  (config-for (invert-owner whose))
  ::
  ++  local-htlcs   ?:(=(whose %local) our-htlcs her-htlcs)
  ++  remote-htlcs  ?:(=(whose %local) her-htlcs our-htlcs)
  ::
  ++  local-msats   ?:(=(whose %local) our-balance her-balance)
  ++  remote-msats  ?:(=(whose %local) her-balance our-balance)
  ::
  ++  commitment-htlcs
    ;:  welp
      %+  turn  local-htlcs
      |=  h=add-htlc:update
      :-  h
      %-  p2wsh:script
      %:  htlc-offered:script
        local-htlc-pubkey=this-htlc-pubkey.keys
        remote-htlc-pubkey=that-htlc-pubkey.keys
        revocation-pubkey=that-revocation-pubkey.keys
        payment-hash=payment-hash.h
        confirmed-spend=anchor-outputs.constraints.c
      ==
    ::
      %+  turn  remote-htlcs
      |=  h=add-htlc:update
      :-  h
      %-  p2wsh:script
      %:  htlc-received:script
        local-htlc-pubkey=this-htlc-pubkey.keys
        remote-htlc-pubkey=that-htlc-pubkey.keys
        revocation-pubkey=that-revocation-pubkey.keys
        payment-hash=payment-hash.h
        cltv-expiry=timeout.h
        confirmed-spend=anchor-outputs.constraints.c
      ==
    ==
  ::
  ++  onchain-fees
    ^-  (map owner msats)
    =/  local-init=?
      ?:  initiator.constraints.c
        =(whose %local)
      =(whose %remote)
    %-  malt
    %-  limo
    :~  [%local ?:(local-init fee 0)]
        [%remote ?.(local-init fee 0)]
    ==
  --
::
++  make-closing-tx
  |=  $:  local-script=hexb:bc
          remote-script=hexb:bc
          =fee=sats:bc
      ==
  ^-  [tx=psbt:psbt =signature]
  =+  our-cn=(oldest-unrevoked-commitment-number %local)
  =+  her-cn=(oldest-unrevoked-commitment-number %remote)
  =+  ctx=(oldest-unrevoked-commitment %local)
  ?~  ctx  !!
  =/  fees=(map owner sats:bc)
    %-  malt
    %-  limo
    :~  [%local ?:(initiator.constraints.c fee-sats 0)]
        [%remote ?.(initiator.constraints.c fee-sats 0)]
    ==
  =/  outputs=(list output:psbt)
    %:  commitment-outputs:tx
      fees-per-participant=fees
      local-funding-pubkey=pub.multisig-key.our.config.c
      remote-funding-pubkey=pub.multisig-key.her.config.c
      local-amount-msats=balance.our.u.ctx
      remote-amount-msats=balance.her.u.ctx
      local-script=local-script
      remote-script=remote-script
      htlcs=~
      dust-limit-sats=dust-limit-sats:(config-for %local)
      anchor=anchor-outputs.constraints.c
    ==
  =/  tx=psbt:psbt
    %:  closing:tx
      local-funding-pubkey=pub.multisig-key.our.config.c
      remote-funding-pubkey=pub.multisig-key.her.config.c
      funding-outpoint=funding-outpoint.c
      outputs=outputs
    ==
  =/  signing-key=hexb:bc
    32^prv.multisig-key.our.config.c
  [tx (~(one sign:psbt tx) 0 signing-key ~)]
::
++  signature-fits
  |=  tx=psbt:psbt
  ^-  ?
  =+  remote-sig=current-commitment-signature.our.config.c
  =+  preimage=(~(witness-preimage sign:psbt tx) 0 ~)
  =+  hash=(dsha256:bcu:bc preimage)
  =+  pubkey=pub.multisig-key.her.config.c
  (check-signature hash remote-sig pubkey)
::
++  force-close-tx
  ^-  psbt:psbt
  =+  latest=(latest-commitment %local)
  ?~  latest  !!
  ?>  (signature-fits tx.u.latest)
  =+  local-config=our.config.c
  =+  multisig-keypair=multisig-key.local-config
  =+  keys=(malt ~[[pub.multisig-keypair 32^prv.multisig-keypair]])
  =+  tx=(~(all sign:psbt tx.u.latest) keys)
  =.  tx
    %^    ~(add-signature update:psbt tx)
        0
      pub.multisig-key.her.config.c
    (cat:byt:bcu:bc ~[current-commitment-signature.local-config 1^0x1])
  ?.  (is-complete:psbt tx)  ~|(%incomplete-force-close-tx !!)
  tx
::
++  has-expiring-htlcs
  |=  block=@
  ^-  ?
  ::  TODO
  %.n
::
++  update-onchain-state
  |=  [funding-height=@ closed-height=@ block=@]
  ^-  chan
  ?+    state.c  c
      %opening
    ?:  =(0 funding-height)  c
    =+  confs=(sub block funding-height)
    ?.  (gte confs funding-tx-min-depth)  c
    (set-state %funded)
  ::
      %closing
    ?:  =(0 closed-height)  c
    =+  confs=(sub block closed-height)
    ?.  (gth confs 0)  c
    (set-state %closed)
  ==
::
++  can-pay
  |=  =amount=msats
  ^-  ?
  =|  update=add-htlc:update
  =.  update
    %=  update
      index         update-count.our.updates.c
      htlc-id       htlc-count.our.updates.c
      amount-msats  amount-msats
    ==
  (can-add-htlc %local update)
::
++  can-receive
  |=  =amount=msats
  ^-  ?
  =|  update=add-htlc:update
  =.  update
    %=  update
      index         update-count.her.updates.c
      htlc-id       htlc-count.her.updates.c
      amount-msats  amount-msats
    ==
  (can-add-htlc %remote update)
::
++  latest-fee
  |=  who=owner
  ^-  sats:bc
  =+  latest=(latest-commitment who)
  ?~  latest  !!
  %+  sub  capacity.constraints.c
  %+  roll  vout.tx.u.latest
  |=  [=out:tx:psbt acc=sats:bc]
  (add value.out acc)
--
