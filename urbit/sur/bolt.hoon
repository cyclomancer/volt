::  sur/bolt.hoon
::  Datatypes to implement Lightning BOLT RFCs.
::
/-  bc=bitcoin, psbt
|%
+$  id       @ud
+$  htlc-id  @ud
+$  blocks   @ud  ::  number of blocks
+$  msats    @ud  ::  millisats
+$  commitment-number  @
::
+$  pubkey     point
+$  privkey    @
+$  signature  hexb:bc
::
+$  network   ?(network:bc %regtest)
+$  point     point:secp:crypto
+$  outpoint  [=txid:bc pos=@ud =sats:bc]
+$  witness   (list hexb:bc)
::
+$  owner      ?(%remote %local)
+$  direction  ?(%sent %received)
::  +const: protocol constants
::
++  const
  |%
  ++  min-final-cltv-expiry  144
  ++  min-remote-delay       144
  ++  max-remote-delay       2.016
  ++  min-funding-sats       200.000
  ++  max-funding-sats       16.777.216
  ++  max-htlc-number        966
  ++  min-confirmations      3
  ++  max-confirmations      6
  ++  dust-limit-sats        546
  ::
  ++  fee-eta-target         2
  ++  feerate-regtest        180.000
  ++  feerate-max-dynamic    1.500.000
  ++  feerate-fallback       150.000
  ++  feerate-default-relay  1.000
  ++  feerate-max-relay      50.000
  ++  feerate-per-kw-min-relay  253
  --
::  +key: key-related types
::
++  key
  |%
  +$  family
    $?  %multisig
        %revocation-base
        %htlc-base
        %payment-base
        %delay-base
        %revocation-root
        %node-key
    ==
  +$  link  [pub=pubkey pax=(list @u)]
  --
::
+$  basepoints
  $:  revocation=link:key
      payment=link:key
      delayed-payment=link:key
      htlc=link:key
  ==
::
+$  links
  $:  branch=@u
      =basepoints
      multisig=link:key
  ==
::
++  channel-config
  $:  =ship
      =network
      =basepoints
      multisig-key=link:key
      to-self-delay=blocks
      =dust-limit=sats:bc
      =max-htlc-value-in-flight=msats
      max-accepted-htlcs=@ud
      =initial=msats
      =reserve=sats:bc
      =htlc-minimum=msats
      upfront-shutdown-script=hexb:bc
      anchor-outputs=?
  ==
::
++  local-config
  $:  channel-config
      seed=@
      funding-locked-received=?
      =current-commitment=signature
      current-htlc-signatures=(list signature)
      ::  per-commitment-secret-seed=@
  ==
::
++  remote-config
  $:  channel-config
      =next-per-commitment=point
      =current-per-commitment=point
  ==
::  +commitment-keys: public keys for commitment, from pov of owner
::
+$  commitment-keys
  $:  =commitment=point
      =this-htlc=pubkey
      =that-htlc=pubkey
      =that-revocation=pubkey
      =payment=pubkey
      =delayed=pubkey
      funder-payment-basepoint=point
      fundee-payment-basepoint=point
  ==
::  +commitment: view of commitment state
::
+$  commitment
  $:  height=commitment-number
      =owner
      $=  our
      $:  msg-idx=@ud
          htlc-idx=@ud
          balance=msats
      ==
      $=  her
      $:  msg-idx=@ud
          htlc-idx=@ud
          balance=msats
      ==
      tx=psbt:psbt
      =signature
      htlc-signatures=(list signature)
      fee=sats:bc
      fee-per-kw=sats:bc
      dust-limit=sats:bc
      cltvs=(list blocks)
      sent-htlcs=(list add-htlc-update)
      recd-htlcs=(list add-htlc-update)
      sent-htlc-index=(map @ add-htlc-update)
      recd-htlc-index=(map @ add-htlc-update)
  ==
::  +update: event that updates a commitment
::
+$  update
  $%  [%add-htlc add-htlc-update]
      [%settle-htlc settle-htlc-update]
      [%fail-htlc fail-htlc-update]
      [%fail-malformed-htlc fail-malformed-htlc-update]
      [%fee-update fee-update]
  ==
+$  update-shared-fields
  $:  index=@
      ::  commitment number which included this update
      ::  determines whether an HTLC is fully 'locked-in'
      $=  add-height
      $:  our=commitment-number
          her=commitment-number
      ==
      ::  commitment number which removed the parent update
      ::  updates can be removed once these heights are below
      ::  both commitment chains
      $=  rem-height
      $:  our=commitment-number
          her=commitment-number
      ==
  ==
+$  update-parent-fields
  $:  parent=htlc-id
      payment-hash=hexb:bc
      =amount=msats
  ==
+$  add-htlc-update
  $:  update-shared-fields
      =htlc-id
      payment-hash=hexb:bc
      timeout=blocks
      =amount=msats
      output-index=@
  ==
+$  settle-htlc-update
  $:  update-shared-fields
      update-parent-fields
      preimage=hexb:bc
  ==
+$  fail-htlc-update
  $:  update-shared-fields
      update-parent-fields
      reason=@t
  ==
+$  fail-malformed-htlc-update
  $:  update-shared-fields
      update-parent-fields
  ==
+$  fee-update
  $:  update-shared-fields
      fee-rate=sats:bc
  ==
::  +update-log: append-only sequence of commitment updates
::
+$  update-log
  $:  list=(list update)
      update-index=(map @ update)
      update-count=@
      htlc-index=(map htlc-id update)
      htlc-count=htlc-id
      modified-htlcs=(set htlc-id)
  ==
::  +larva-chan: a channel in the larval state
::   - holds all the messages back and forth until finalized
::   - used to build chan
::
+$  larva-chan
  $:  initiator=?
      our=local-config
      her=remote-config
      oc=(unit open-channel:msg)
      ac=(unit accept-channel:msg)
  ==
::  +revocation-store: BOLT-03 revocation storage
::
+$  revocation-store
  $~  :*  idx=(dec (bex 48))
          buckets=*(map @ shachain-element)
      ==
  $:  idx=@
      buckets=(map @ shachain-element)
  ==
+$  shachain-element  [idx=@ secret=@]
::  +chan-state: channel state
::
+$  chan-state
  $~  %preopening
  $?  %preopening
      %opening
      %funded
      %open
      %shutdown
      %closing
      %force-closing
      %closed
      %redeemed
  ==
::  +chan: full channel representation
::
+$  chan
  $:  =id
      state=chan-state
      =funding=outpoint
      $=  constraints
      $:  initiator=?
          anchor-outputs=?
          capacity=sats:bc
          initial-feerate=sats:bc
          funding-tx-min-depth=blocks
      ==
      $=  config
      $:  our=local-config
          her=remote-config
      ==
      $=  commitments
      $:  our=(list commitment)
          her=(list commitment)
          height=@
      ==
      $=  updates
      $:  our=update-log
          her=update-log
      ==
      =sent=msats
      =recd=msats
      revocations=revocation-store
  ==
::  +htlc: added-htlc with script-pubkey for commitment generation
::
+$  htlc
  $:  add-htlc-update
      script-pubkey=hexb:bc
  ==
::  +msg: BOLT spec messages between peers
::    defined in RFC02
::
++  msg
  |%
  ::  funding messages
  ::
  +$  open-channel
    $:  chain-hash=hexb:bc
        temporary-channel-id=@
        =funding=sats:bc
        =push=msats
        =funding=pubkey
        =dust-limit=sats:bc
        =max-htlc-value-in-flight=msats
        =channel-reserve=sats:bc
        =htlc-minimum=msats
        feerate-per-kw=sats:bc
        to-self-delay=blocks
        cltv-expiry-delta=blocks
        max-accepted-htlcs=@ud
        =basepoints
        =first-per-commitment=point
        =shutdown-script=pubkey
        anchor-outputs=?
    ==
  ::
  +$  accept-channel
    $:  temporary-channel-id=@
        =dust-limit=sats:bc
        =max-htlc-value-in-flight=msats
        =channel-reserve=sats:bc
        =htlc-minimum=msats
        minimum-depth=blocks
        to-self-delay=blocks
        max-accepted-htlcs=@ud
        =funding=pubkey
        =basepoints
        =first-per-commitment=point
        =shutdown-script=pubkey
        anchor-outputs=?
    ==
  ::
  +$  funding-created
    $:  temporary-channel-id=@
        funding-txid=hexb:bc
        funding-idx=@u
        =signature
    ==
  ::
  +$  funding-signed
    $:  =channel=id
        =signature
    ==
  ::
  +$  funding-locked
    $:  =channel=id
        =next-per-commitment=point
    ==
  ::
  ::  htlc messages
  ::
  +$  update-add-htlc
    $:  =channel=id
        =htlc-id
        =amount=msats
        payment-hash=hexb:bc
        cltv-expiry=blocks
    ==
  ::
  +$  commitment-signed
    $:  =channel=id
        sig=signature
        num-htlcs=@ud
        htlc-sigs=(list signature)
    ==
  ::
  +$  revoke-and-ack
    $:  =channel=id
        per-commitment-secret=@
        next-per-commitment-point=point
    ==
  ::
  ::  closing messages
  ::
  +$  shutdown
    $:  =channel=id
        script-pubkey=hexb:bc
    ==
  ::
  +$  closing-signed
    $:  =channel=id
        =fee=sats:bc
        =signature
        min-fee=(unit sats:bc)
        max-fee=(unit sats:bc)
    ==
  --
::
+$  message
  $%  [%open-channel open-channel:msg]
      [%accept-channel accept-channel:msg]
      [%funding-created funding-created:msg]
      [%funding-signed funding-signed:msg]
      [%funding-locked funding-locked:msg]
    ::
      [%shutdown shutdown:msg]
      [%closing-signed closing-signed:msg]
    ::
      [%update-add-htlc update-add-htlc:msg]
      [%commitment-signed commitment-signed:msg]
      [%revoke-and-ack revoke-and-ack:msg]
    ::
      [%update-fulfill-htlc =channel=id =id preimage=hexb:bc]
      [%update-fail-htlc =channel=id =id reason=@t]
      [%update-fail-malformed-htlc =channel=id =id]
      [%update-fee =channel=id feerate-per-kw=sats:bc]
  ==
--
