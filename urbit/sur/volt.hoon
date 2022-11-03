::  sur/volt.hoon
::
/-  bc=bitcoin, bolt
|%
+$  pubkey    pubkey:bolt
+$  txid      hexb:bc
+$  hash      hexb:bc
+$  preimage  hexb:bc
+$  point     point:secp:crypto
+$  pax       (list @u)
::
+$  msats    msats:bolt
+$  chan-id  id:bolt
+$  htlc-id  htlc-id:bolt
::
+$  node-info
  $:  version=@t
      commit-hash=@t
      =identity=pubkey
  ==
::
++  rpc
  |%
  +$  action
    $%  [%get-info ~]
        [%wallet-balance ~]
        [%open-channel node=pubkey local-amount=sats:bc push-amount=sats:bc]
        [%close-channel funding-txid=txid output-index=@ud]
        [%send-payment invoice=cord timeout=(unit @dr) fee-limit=(unit sats:bc)]
        $:  %add-hold-invoice
          =amt=msats
          memo=(unit cord)
          =payment=hash
          expiry=(unit @dr)
        ==
        [%settle-invoice =preimage]
        [%cancel-invoice =payment=hash]
        [%subscribe-confirms =txid script=hexb:bc num-confs=@ height-hint=@]
        [%subscribe-spends =outpoint script=hexb:bc height-hint=@]
    ==
  ::
  +$  result
    $%  [%get-info node-info]
        [%wallet-balance total=msats confirmed=msats unconfirmed=msats]
        [%open-channel channel-point]
        [%close-channel ~]
        [%send-payment ~]
        [%add-hold-invoice add-hold-invoice-response]
        [%settle-invoice ~]
        [%cancel-invoice ~]
        [%subscribe-confirms ~]
        [%subscribe-spends ~]
    ==
  ::
  +$  error
    $:  code=@ud
        message=@t
    ==
  ::
  +$  response  (each result error)
  ::
  +$  route-hint
    $:  node-id=pubkey
        =chan-id
        fee-base-msat=@ud
        fee-proportional-usat=@ud
        cltv-expiry-delta=@ud
    ==
  ::
  +$  channel-update
    $%  [%open-channel channel]
        [%closed-channel channel-close-summary]
        [%active-channel channel-point]
        [%inactive-channel channel-point]
        [%pending-channel pending-channel]
    ==
  ::
  +$  channel
    $:  active=?
        remote-pubkey=pubkey
        channel-point=@t
        =chan-id
        capacity=sats:bc
        local-balance=sats:bc
        remote-balance=sats:bc
        commit-fee=sats:bc
        total-sent=sats:bc
    ==
  ::
  +$  channel-close-summary
    $:  channel-point=@t
        =chan-id
        chain-hash=@t
        closing-tx-hash=@t
        remote-pubkey=pubkey
        channel-closure-type=@tas
    ==
  ::
  +$  channel-point
    $:  funding-txid=txid
        output-index=@ud
    ==
  ::
  +$  pending-channel
    $:  =txid
        output-index=@ud
    ==
  ::
  +$  payment
    $:  =hash
        =preimage
        =value=msats
        =fee=msats
        request=cord
        status=payment-status
        failure-reason=payment-failure-reason
        creation-time=@da
    ==
  ::
  +$  payment-status
    $?  %'UNKNOWN'
        %'IN_FLIGHT'
        %'SUCCEEDED'
        %'FAILED'
    ==
  ::
  +$  payment-failure-reason
    $~  %'FAILURE_REASON_NONE'
    $?  %'FAILURE_REASON_NONE'
        %'FAILURE_REASON_TIMEOUT'
        %'FAILURE_REASON_NO_ROUTE'
        %'FAILURE_REASON_ERROR'
        %'FAILURE_REASON_INCORRECT_PAYMENT_DETAILS'
        %'FAILURE_REASON_INSUFFICIENT_BALANCE'
    ==
  ::
  +$  wallet-balance-response
    $:  total-balance=msats
        confirmed-balance=msats
        unconfirmed-balance=msats
    ==
  ::
  +$  add-hold-invoice-response
    $:  payment-request=cord
    ==
  ::
  +$  add-invoice-response
    $:  r-hash=hexb:bc
        payment-request=cord
        add-index=@ud
        payment-address=hexb:bc
    ==
  ::
  +$  invoice
    $:  memo=cord
        r-preimage=(unit preimage)
        =r=hash
        =value=msats
        settled=?
        creation-date=@da
        settle-date=@da
        expiry=@dr
        payment-request=cord
        add-index=@ud
        settle-index=@ud
        =amt-paid=msats
        state=invoice-state
    ==
  ::
  +$  invoice-state
    $?  %'OPEN'
        %'SETTLED'
        %'CANCELED'
        %'ACCEPTED'
    ==
  ::
  +$  confirmation-event
    $:  raw-tx=hexb:bc
        block-hash=hexb:bc
        block-height=@
        tx-index=@
    ==
  ::
  +$  spend-event
    $:  =spending=outpoint
        raw-spending-tx=hexb:bc
        spending-tx-hash=hexb:bc
        spending-input-index=@
        spending-height=@
    ==
  ::
  +$  outpoint  [hash=hexb:bc index=@]
  --
::
::  provider types
::
++  provider
  |%
  +$  host-info
    $:  api-url=@t
        connected=?
        clients=(set ship)
    ==
  ::
  +$  command
    $%  [%set-url api-url=@t]
        [%open-channel to=pubkey local-amt=sats:bc push-amt=sats:bc]
        [%close-channel funding-txid=txid output-index=@ud]
        [%send-payment payreq=@t timeout=(unit @dr) fee-limit=(unit sats:bc)]
    ==
  ::
  +$  action
    $%  [%ping ~]
        [%add-hold-invoice =amt=msats memo=(unit @t) =payment=hash expiry=(unit @dr)]
        [%settle-invoice =preimage]
        [%cancel-invoice =payment=hash]
        [%subscribe-confirms =txid script=hexb:bc num-confs=@ height-hint=@]
        [%subscribe-spends =outpoint:rpc script=hexb:bc height-hint=@]
    ==
  ::
  +$  error
    $%  [%rpc-error error:rpc]
        [%not-connected ~]
        [%bad-request ~]
    ==
  ::
  +$  result
    $%  [%node-info =node-info]
        [%hold-invoice add-hold-invoice-response:rpc]
        [%invoice-added add-invoice-response:rpc]
        [%invoice-update invoice:rpc]
        [%channel-update channel-update:rpc]
        [%payment-update payment:rpc]
        [%balance-update wallet-balance-response:rpc]
        [%confirmation-event confirmation-event:rpc]
        [%spend-event spend-event:rpc]
    ==
  ::
  +$  update  (each result error)
  ::
  +$  status  ?(%connected %disconnected)
  --
::
::  wallet types
::
++  wallet
  |%
  +$  action
    $%  [%new-wallet seed=(unit hexb:bc)]
        [%get-public-keys paths=(list (list @u))]
        [%get-address path=(list @u)]
        [%sign-digest path=(list @u) hash=hexb:bc]
        [%get-commit-point path=(list @u) i=@]
        [%get-commit-secret path=(list @u) i=@]
    ==
  ::
  +$  result
    $%  [%public-key path=(list @u) =pubkey]
        [%address path=(list @u) =address:bc]
        [%signature path=(list @u) signature=hexb:bc]
        [%point path=(list @u) =point]
        [%secret path=(list @u) secret=@]
    ==
  --
::
::  client types
::
+$  payreq  cord
::
+$  payment-request
  $:  payee=ship
      =amount=msats
      =payment=hash
      preimage=(unit preimage)
  ==
::
+$  forward-request
  $:  htlc=update-add-htlc:msg:bolt
      =payreq
      forwarded=?
  ==
::
+$  command
  $%  [%set-provider provider=(unit ship)]
      [%set-btc-provider provider=(unit ship)]
      [%open-channel who=ship =funding=sats:bc =push=msats =network:bolt]
      [%create-funding temporary-channel-id=@ psbt=@t]
      [%close-channel =chan-id]
      [%send-payment =payreq]
      [%add-invoice =amount=msats memo=(unit @t) network=(unit network:bolt)]
  ==
::
+$  action
  $%  [%give-invoice =amount=msats =payment=hash memo=(unit @t) network=(unit network:bolt)]
      [%take-invoice =payreq]
      [%give-pubkey nonce=@]
      [%take-pubkey sig=[v=@ r=@ s=@]]
      [%forward-payment =payreq htlc=update-add-htlc:msg:bolt]
  ==
::
+$  update
  $%  [%need-funding-signature temporary-channel-id=@ =address:bc]
      [%channel-state =chan-id =chan-state:bolt]
      [%received-payment from=ship =amt=msats]
  ==
--
