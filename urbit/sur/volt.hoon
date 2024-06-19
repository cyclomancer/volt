::  sur/volt.hoon
::
/-  bc=bitcoin, bolt, psbt
|%
+$  pubkey    pubkey:bolt
+$  txid      hexb:bc
+$  hash      hexb:bc
+$  preimage  hexb:bc
+$  rpc-tx    [=txid rawtx=hexb:bc]
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
        [%close-channel funding-txid=txid output-index=@]
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
        [%add-hold-invoice payment-request=cord]
        [%settle-invoice ~]
        [%cancel-invoice ~]
        [%subscribe-confirms ~]
        [%subscribe-spends ~]
    ==
  ::
  +$  error
    $:  code=@
        message=@t
    ==
  ::
  +$  response
    $%  [%res p=result]
        [%err p=error]
    ==
  +$  route-hint
    $:  node-id=pubkey
        =chan-id
        fee-base-msat=@
        fee-proportional-usat=@
        cltv-expiry-delta=@
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
        output-index=@
    ==
  ::
  +$  pending-channel
    $:  =txid
        output-index=@
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
        =creation=time
    ==
  +$  payment-status
    $~  %'UNKNOWN'
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
  +$  wallet-balance-response
    $:  total=msats
        confirmed=msats
        unconfirmed=msats
    ==
  ::
  +$  add-invoice-response
    $:  r-hash=hexb:bc :: payment hash matching this invoice, name taken from LND RPC
        payment-request=cord
        add-index=@
        payment-address=hexb:bc
    ==
  ++  invoice
    =<  invoice
    |%
    ::
    +$  invoice
      $:  memo=cord
        r-preimage=(unit preimage)
        =r=hash
        =value=msats
        settled=?
        creation-date=time
        settle-date=time
        expiry=@dr
        payment-request=cord
        add-index=@
        settle-index=@
        =amt-paid=msats
        =state  :: state -> status
      ==
    ::
    +$  state
      $?  %'OPEN'
          %'SETTLED'
          %'CANCELED'
          %'ACCEPTED'
      ==
    --
  ::
  +$  confirmation-event
    $:  raw-tx=hexb:bc
        block-hash=hexb:bc
        block-height=@
        tx-index=@u
    ==
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
::  ` types
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
        [%close-channel funding-txid=txid output-index=@]
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
        [%hold-invoice payment-request=cord]
        [%invoice-added add-invoice-response:rpc]
        [%invoice-update invoice:rpc]
        [%channel-update channel-update:rpc]
        [%payment-update payment:rpc]
        [%balance-update wallet-balance-response:rpc]
        [%confirmation-event confirmation-event:rpc]
        [%spend-event spend-event:rpc]
    ==
  ::
  +$  update
    $%  [%res result]
        [%err error]
    ==
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
        [%get-public-key path=(list @)]
        [%get-address path=(list @)]
        [%sign-digest path=(list @) hash=hexb:bc]
    ==
  ::
  +$  result
    $%  [%public-key path=(list @) =pubkey]
        [%address path=(list @) =address:bc]
        [%signature path=(list @) signature=hexb:bc]
    ==
  --
::
::  client types
+$  payreq  cord
::
+$  payment-request
  $:  payee=ship
      =amount=msats
      =payment=hash
      preimage=(unit preimage)
      payreq=cord
  ==
::
+$  forward-request
  $:  htlc=update-add-htlc:msg:bolt
      =payreq
      forwarded=?
      lnd=?
      dest=(unit @p)
      ours=?
  ==
::
+$  payment
  $:  way=?(%in %out)
      $=  stat
        $~  %pending  ?(%pending %success %fail)
      ship=(unit ship)
      =time  ::  based on status: time of payment attempt if pending, time of resolution if success or failure
      =sats:bc
      payhash=hexb:bc
      memo=(unit @t)
        ::  sending to earth node: can present node key + link to LN explorer (not guaranteed coverage)
        ::  sending or receiving with earth node: show memo from our or their invoice for identifying information
        ::  receiving from earth node: no info besides memo, best privacy for counterparty
  ==
::
+$  command
  $%  [%set-provider provider=(unit ship)]
      [%open-channel who=ship =funding=sats:bc =push=msats =network:bolt]
      [%create-funding temporary-channel-id=@ =psbt:psbt]
      [%close-channel =chan-id]
      [%send-payment =payreq who=(unit ship)]
      [%add-invoice =amount=msats memo=(unit @t) network=(unit network:bolt)]
      [%test-invoice =ship =msats =network:bolt]
  ==
::
+$  action
  $%  [%give-invoice =amount=msats =payment=hash memo=(unit @t) network=(unit network:bolt)]
      [%get-invoice =amount=msats memo=(unit @t) network=(unit network:bolt)]
      [%take-invoice =payreq]
      [%give-pubkey nonce=@]
      [%take-pubkey sig=[v=@ r=@ s=@]]
      [%forward-payment =payreq htlc=update-add-htlc:msg:bolt dest=(unit ship)]
  ==
::
+$  chan-info
  $:  =id:bolt
      who=ship
      our=msats
      his=msats
      status=chan-state:bolt
      =network:bolt
  ==
+$  funding-info
  $:  temporary-channel-id=@
      tau-address=address:bc
      funding-address=address:bc
      =msats
  ==
+$  pay-info
  $:  =payreq
      chan=id:bolt
      amt=sats:bc
      pat-p=(unit ship)
      node-id=(unit @)
      done=?
  ==
::
+$  invoice-and-pay-params  [amount=@ud net=?(%regtest %main %testnet) who=@p]
::
+$  update
  $%  [%need-funding funding-info=(list funding-info)]
      [%channel-state =chan-id =chan-state:bolt]
      [%temp-chan-upgraded id=@]
      [%received-payment from=ship =amt=msats]
      [%new-invoice =payment-request]
      [%invoice-paid =payreq]
      [%payment-result =payreq success=?]
      [%new-channel =chan-info]
      $:  %initial-state
        chans=(list chan-info)
        txs=(list pay-info)
        invoices=(list payment-request)
      ==
      [%payment-update =payment]
      [%payment-history log=(map hexb:bc payment)]
  ==
::
+$  response
  $%  [%payreq-amount is-valid=? msats=(unit msats)]
      [%hot-wallet-fee sats=(unit sats:bc)]
  ==
--
