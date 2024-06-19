/-  *bolt, bc=bitcoin
/+  psbt, channel, script
/+  keys=key-generation, tx=transactions
|%
:: notes
  :: don't necessarily need to move to the next commitment after every HTLC, could set timer to update periodically instead
  :: could map/search by commitment height (encoded in nlocktime) instead of tx byts
::
++  revoked-commitment
  =,  secp256k1:secp:crypto
  |=  $:  c=chan
          commit=commitment
          txid=hexb:bc
          fee=sats:bc
      ==
  |^  ^-  (list psbt:psbt)
  =+  secret=(~(got by lookup.commitments.c) commit)
  ::  sweep her output with revocation
  =+  per-commit=(priv-to-pub secret)
  =+  our-config=(~(config-for channel c) %local)
  =+  her-config=(~(config-for channel c) %remote)
  =+  delay=to-self-delay:her-config
  =/  her-delayed-pubkey=pubkey
    %+  derive-pubkey:keys
      pub.delayed-payment.basepoints.our-config
    per-commit
  =/  rev-priv=privkey:keys
    %:  derive-revocation-privkey:keys
      pub.revocation.basepoints.our-config
      prv.revocation.basepoints.our-config
      per-commit
      secret
    ==
  =+  rev-pub=(priv-to-pub rev-priv)
  =/  local-witness=script:btc-script:script
    %^  local-output:script
        rev-pub
      her-delayed-pubkey
    delay
  =/  scriptpubkeys=(list hexb:bc)
    (turn vout.tx.commit |=(=out:tx:psbt script-pubkey.out))
  =+  her-bal=balance.her.commit
  =|  inputs=(list input:psbt)
  =^  has-local  inputs
    %:  maybe-add-local
      her-bal
      txid
      scriptpubkeys
      local-witness
    ==
  ::  sweep our output
  =+  our-bal=balance.our.commit
  =+  localpub=pub.multisig-key.our-config
  =+  anchors=anchor-outputs.constraints.c
  =^  has-remote  inputs
    %:  maybe-add-remote
      our-bal
      txid
      scriptpubkeys
      localpub
      inputs
      anchors
    ==
  ::  send to our localpubkey
  ::  TODO: options for sweep address
  =|  =output:psbt
  =+  tx-fee=(mul fee 186)
  ::  base size: 31B (output) + 82B (inputs) + 6B (version, counts)
  ::  witness size: 265B
  ::  virtual size: 186vB (rounded up)
  =|  val=sats:bc
  =?  val  has-local  (add val her-bal)
  =?  val  has-remote  (add val our-bal)
  =.  value.output  (sub val tx-fee)
  =.  script-pubkey.output  (p2wpkh:script localpub)
  ::  build transaction
  =|  tx=psbt:psbt
  =.  tx
    %=  tx
      inputs    inputs
      outputs   ~[output]
      nversion  2
    ==
  ::  sign and encode
  =+  xrprv=(priv-to-hexb:keys rev-priv)
  =?  tx  has-local
    %^  ~(add-signature update:psbt tx)
        0
      rev-pub
    %^  ~(one sign:psbt tx)
        0
      xrprv
    ~
  =?  tx  has-remote
    =/  remote-idx  ?:  has-local  1  0
    %^  ~(add-signature update:psbt tx)
        remote-idx
      localpub
    %^  ~(one sign:psbt tx)
        remote-idx
      (priv-to-hexb:keys prv.multisig-key.our-config)
    ~
  =+  txs=~[tx]
  ?:  ?&(=(0 (lent sent-htlcs.commit)) =(0 (lent recd-htlcs.commit)))
    txs
  (weld txs (revoke-htlc-outs rev-pub xrprv))
  ::
  ++  maybe-add-local
    |=  $:  bal=sats:bc
            id=hexb:bc
            keys=(list hexb:bc)
            wit=script:btc-script:script
        ==
    ^-  [? (list input:psbt)]
    =+  addr=(p2wsh:script wit)
    =+  idx=(find keys ~[addr])
    =|  =input:psbt
    ?~  idx
      [%.n ~]
    =+  wit-byts=(en:btc-script:script wit)
    :-  %.y
    :~  %=  input
          script-type     %p2wsh
          trusted-value   `bal
          witness-script  `wit-byts
          prevout         [txid=id idx=u.idx]
    ==  ==
  ::
  ++  maybe-add-remote
    |=  $:  bal=sats:bc
            id=hexb:bc
            keys=(list hexb:bc)
            pub=pubkey
            in=(list input:psbt)
            anchors=?
        ==
    ^-  [? (list input:psbt)]
    =/  anchor-script
      (anchor-output:script pub)
    =/  addr
      ?.  anchors  (p2wpkh:script pub)
      (p2wsh:script anchor-script)
    =+  idx=(find keys ~[addr])
    =|  =input:psbt
    ?~  idx
      [%.n in]
    =.  trusted-value.input  `bal
    =.  prevout.input  [txid=id idx=u.idx]
    :-  %.y
    %+  snoc  in
      ?.  anchors
        input(script-type %p2wpkh)
      =+  wit-byts=(en:btc-script:script anchor-script)
      %=  input
        nsequence       1
        script-type     %p2wsh
        witness-script  `wit-byts
      ==
  ::
  ++  revoke-htlc-outs
    ::  refactor to be less duplicative
    |=  [rpub=pubkey rprv=hexb:bc]
    ^-  (list psbt:psbt)
    =/  our=(list psbt:psbt)
      %+  murn  sent-htlcs.commit
      |=  htlc=add-htlc:update
      ^-  (unit psbt:psbt)
      =|  =input:psbt
      =+  val=(div amount-msats.htlc 1.000)
      =/  wit
        %:  htlc-witness:script
          %sent
          pub.htlc.basepoints.our.config.c
          pub.htlc.basepoints.her.config.c
          rpub
          payment-hash.htlc
          ~
          anchor-outputs.our.config.c
        ==
      =?  nsequence.input  anchor-outputs.our.config.c
        1
      =.  input
        %=  input
          script-type     %p2wsh
          prevout         [txid output-index.htlc]
          trusted-value   `val
          witness-script  `(en:btc-script:script wit)
        ==
      =|  =output:psbt
      =.  script-pubkey.output
        (p2wpkh:script pub.multisig-key.our.config.c)
      =|  tx=psbt:psbt
      =.  tx
        %=  tx
          nversion  2
          inputs    ~[input]
          outputs   ~[output]
        ==
      =/  fee  (mul fee (add 33 (estimated-size:psbt tx)))
      ?:  (gte fee value.output)  ~
      =.  outputs.tx  ~[output]
      :-  ~
      %^  ~(add-signature update:psbt tx)
          0
        rpub
      %^  ~(one sign:psbt tx)
          0
        rprv
      ~
    =/  his=(list psbt:psbt)
      %+  murn  recd-htlcs.commit
      |=  htlc=add-htlc:update
      ^-  (unit psbt:psbt)
      =|  =input:psbt
      =+  val=(div amount-msats.htlc 1.000)
      =/  wit
        %:  htlc-witness:script
          %received
          pub.htlc.basepoints.our.config.c
          pub.htlc.basepoints.her.config.c
          rpub
          payment-hash.htlc
          `timeout.htlc
          anchor-outputs.our.config.c
        ==
      =?  nsequence.input  anchor-outputs.our.config.c
        1
      =.  input  
        %=  input
          script-type     %p2wsh
          prevout         [txid output-index.htlc]
          trusted-value   `val
          witness-script  `(en:btc-script:script wit)
        ==
      =|  =output:psbt
      =.  script-pubkey.output
        (p2wpkh:script pub.multisig-key.our.config.c)
      =|  tx=psbt:psbt
      =.  tx
        %=  tx
          nversion  2
          inputs    ~[input]
          outputs   ~[output]
        ==
      =/  fee  (mul fee (add 33 (estimated-size:psbt tx)))
      ::  TODO: don't just skip, save with lower feerate to watch for and try then
      ?:  (gte fee value.output)  ~
      =.  outputs.tx  ~[output]
      :-  ~
      %^  ~(add-signature update:psbt tx)
          0
        rpub
      %^  ~(one sign:psbt tx)
          0
        rprv
      ~
    (weld our his)
  --
::
++  revoked-htlc-spend
  =,  secp256k1:secp:crypto
  |=  $:  c=chan
          secret=@
          val=sats:bc
          txid=hexb:bc
          fee=sats:bc
      ==
  ^-  psbt:psbt
  =+  per-commit=(priv-to-pub secret)
  =+  our-config=(~(config-for channel c) %local)
  =+  her-config=(~(config-for channel c) %remote)
  =+  delay=to-self-delay.her-config
  =/  her-pub=pubkey
    %+  derive-pubkey:keys
      pub.delayed-payment.basepoints.our-config
    per-commit
  =/  rev-priv=privkey:keys
    %:  derive-revocation-privkey:keys
      pub.revocation.basepoints.our-config
      prv.revocation.basepoints.our-config
      per-commit
      secret
    ==
  =+  rev-pub=(priv-to-pub rev-priv)
  =/  witness=script:btc-script:script
    %^  htlc-spend:script
        rev-pub
      her-pub
    delay
  =|  =input:psbt
  =.  input
    %=  input
      script-type     %p2wsh
      prevout         [txid 0]
      trusted-value   `val
      witness-script  `(en:btc-script:script witness)
    ==
  =|  =output:psbt
  =.  output
    %=  output
      ::  fee calc: base size 74B + witness 156B => 113vB
      ::  TODO: double check this calc
      ::  TODO: branch calc based on anchor outputs?
      value          (sub val (mul fee 113))
      script-pubkey  (p2wpkh:script pub.multisig-key.our-config)
    ==
  =|  sweep=psbt:psbt
  =.  sweep
    %=  sweep
      inputs    ~[input]
      outputs   ~[output]
      nversion  2
    ==
  %^  ~(add-signature update:psbt sweep)
      0
    rev-pub
  %^  ~(one sign:psbt sweep)
      0
    (priv-to-hexb:keys rev-priv)
  ~
::
++  his-valid-commitment
  |=  $:  c=chan
          com=commitment
          secrets=(map hexb:bc hexb:bc)
          fee=sats:bc
      ==
  ^-  psbt:psbt
  ?~  recd-htlcs.com
    *psbt:psbt
  =|  sweep=psbt:psbt
  =|  =output:psbt
  =|  preimages=(list hexb:bc)
  =.  script-pubkey.output
    (p2wpkh:script pub.payment.basepoints.our.config.c)
  =/  to-spend=(list [input:psbt hexb:bc])
    %+  murn  recd-htlcs.com
    |=  msg=add-htlc:update
    ^-  (unit [input:psbt hexb:bc])
    =+  preimage=(~(get by secrets) payment-hash.msg)
    ?~  preimage
      ~
    =/  witness=hexb:bc
      %-  en:btc-script:script
      %:  htlc-offered:script
        ::  TODO: flip ours/hers because this is a remote commitment output?
        pub.htlc.basepoints.our.config.c
        pub.htlc.basepoints.her.config.c
        pub.revocation.basepoints.our.config.c
        payment-hash.msg
        anchor-outputs.our.config.c
      ==
    =+  amount-sats=(div amount-msats.msg 1.000)
    =|  =input:psbt
    =+  txid=(txid:psbt (extract-unsigned:psbt tx.com))
    %-  some
    :_  u.preimage
    %=  input
      script-type           %p2wsh
      witness-script        `witness
      trusted-value         `amount-sats
      prevout               [txid output-index.msg]
    ==
  =.  inputs.sweep  (turn to-spend head)
  =/  total-value
    (roll (turn inputs.sweep |=(i=input:psbt (need trusted-value.i))) add)
  ::  per input: 41 base + 240 witness => 101vB
  ::  other: 39 base + 2 witness => 40vB
  :: =+  vbytes=(add 40 (mul 101 (lent inputs.sweep)))
  =+  n-in=(lent inputs.sweep)
  =.  value.output  total-value
  =.  outputs.sweep  ~[output]
  ::  one sig and one preimage per input + current estimated size
  =+  vbyts=(add (mul n-in 66) (estimated-size:psbt sweep))
  =.  value.output  (sub total-value (mul fee vbyts))
  =.  outputs.sweep  ~[output]
  =|  i=@
  |-
  ?:  =(i n-in)
    sweep
  =.  sweep
    %^  ~(add-signature update:psbt sweep)
        i
      pub.htlc.basepoints.our.config.c
    %^  ~(one sign:psbt sweep)
        i
      (priv-to-hexb:keys prv.htlc.basepoints.our.config.c)
    ~
  =/  fin=input:psbt  ~(finalize txin:psbt (snag i inputs.sweep))
  =.  final-script-witness.fin
    `(into (need final-script-witness.fin) 2 +:(snag i to-spend))
  =.  inputs.sweep  (snap inputs.sweep i fin)
  $(i +(i))
::
++  remote-recd-htlc
  |=  $:  c=chan
          com=commitment
          msg=add-htlc:update
      ==
  ^-  psbt:psbt
  =|  =input:psbt
  =/  witness=hexb:bc
    %-  en:btc-script:script
    %:  htlc-received:script
      ::  TODO: flip ours/hers because this is a remote commitment output?
      pub.htlc.basepoints.our.config.c
      pub.htlc.basepoints.her.config.c
      pub.revocation.basepoints.our.config.c
      payment-hash.msg
      timeout.msg
      anchor-outputs.our.config.c
    ==
  =+  amount-sats=(div amount-msats.msg 1.000)
  =+  outpoint=[(txid:psbt (extract-unsigned:psbt tx.com)) output-index.msg]
  =.  input
    %=  input
      script-type     %p2wsh
      trusted-value   `amount-sats
      witness-script  `witness
      prevout         outpoint
    ==
  =|  =output:psbt
  =.  script-pubkey.output  (p2wpkh:script pub.multisig-key.our.config.c)
  =.  value.output  amount-sats
  =|  sweep=psbt:psbt
  %=  sweep
    inputs   ~[input]
    outputs  ~[output]
  ==
::
++  local-our-output
  |=  [c=chan com=commitment]
  ^-  (unit [hexb:bc psbt:psbt])
  =/  to-local-witness=script:btc-script:script
    %^  local-output:script
        pub.revocation.basepoints.our.config.c
      pub.delayed-payment.basepoints.our.config.c
    to-self-delay.our.config.c
  =/  scriptpubkeys=(list hexb:bc)
    (turn vout.tx.com |=(=out:tx:psbt script-pubkey.out))
  =+  addr=(p2wsh:script to-local-witness)
  =+  local-idx=(find scriptpubkeys ~[addr])
  ?~  local-idx
    ~
  =|  =input:psbt
  =.  input
    %=  input
      script-type     %p2wsh
      trusted-value   `balance.our.com
      witness-script  `(en:btc-script:script to-local-witness)
      prevout         [(txid:psbt (extract-unsigned:psbt tx.com)) u.local-idx]
    ==
  =|  =output:psbt
  =.  script-pubkey.output  (p2wpkh:script pub.payment.basepoints.our.config.c)
  =.  value.output  balance.our.com
  =|  =psbt:psbt
  `[addr psbt(inputs ~[input], outputs ~[output])]
  ::
++  local-sent-htlcs
  |=  [c=chan com=commitment]
  ^-  (map hexb:bc [@ psbt:psbt])
  =+  secret-and-point=(~(secret-and-point channel c) %local height.com)
  ?>  ?=([%& *] secret-and-point)
  =/  [secret=(unit @) point=point]  +.secret-and-point
  =/  her-com=commitment
    (rear (skim her.commitments.c |=(co=commitment =(height.com height.co))))
  =/  htlc-idxs
    %+  weld  ~(tap in ~(key by sent-htlc-index.com))
    ~(tap in ~(key by recd-htlc-index.com))
  %-  malt
  %+  turn  sent-htlcs.com
  |=  msg=add-htlc:update
  ^-  [hexb:bc @ psbt:psbt]
  =/  tx=psbt:psbt
    %:  ~(make-htlc-tx channel c)
      msg
      %sent
      com
      (~(derive-commitment-keys channel c) %local point)
    ==
  =+  sig=(snag (need (find ~[output-index.msg] htlc-idxs)) htlc-signatures.her-com)
  =.  tx
    (~(add-signature update:psbt tx) 0 pub.htlc.basepoints.her.config.c sig)
  :-  script-pubkey:(snag output-index.msg outputs.tx.com)
  :-  timeout.msg
  %^  ~(add-signature update:psbt tx)
      0
    pub.htlc.basepoints.our.config.c
  %^  ~(one sign:psbt tx)
      0
    (priv-to-hexb:keys prv.htlc.basepoints.our.config.c)
  ~
  ::
++  local-recd-htlcs
  |=  $:  c=chan
          com=commitment
          secrets=(map hexb:bc hexb:bc)
      ==
  ^-  [(list hexb:bc) (map hexb:bc psbt:psbt) (map htlc-id psbt:psbt)]
  =/  her-com=commitment
    (rear (skim her.commitments.c |=(co=commitment =(height.com height.co))))
  =+  secret-and-point=(~(secret-and-point channel c) %local height.com)
  ?>  ?=([%& *] secret-and-point)
  =/  [secret=(unit @) point=point]  +.secret-and-point
  =/  htlc-idxs
    %+  weld  ~(tap in ~(key by sent-htlc-index.com))
    ~(tap in ~(key by recd-htlc-index.com))
  =/  [with-preimage=(list add-htlc:update) without=(list add-htlc:update)]
    %+  skid  recd-htlcs.com
    |=  [msg=add-htlc:update]
    ?~  (~(get by secrets) payment-hash.msg)  %.n  %.y
  =/  success=(map hexb:bc [hexb:bc psbt:psbt])
    %-  malt
    %+  turn  with-preimage
    |=  msg=add-htlc:update
    ^-  [hexb:bc [hexb:bc psbt:psbt]]
    =+  preimage=(~(get by secrets) payment-hash.msg)
    =/  tx=psbt:psbt
      %:  ~(make-htlc-tx channel c)
        msg
        %received
        com
        (~(derive-commitment-keys channel c) %local point)
      ==
    =+  sig-idx=(find ~[output-index.msg] htlc-idxs)
    =+  sig=(snag (need sig-idx) htlc-signatures.her-com)
    =.  tx
      %^  ~(add-signature update:psbt tx)
          0
        pub.htlc.basepoints.our.config.c
      %^  ~(one sign:psbt tx)
          0
        (priv-to-hexb:keys prv.htlc.basepoints.our.config.c)
      ~
    =.  tx
      (~(add-signature update:psbt tx) 0 pub.htlc.basepoints.her.config.c sig)
    =/  fin=input:psbt  ~(finalize txin:psbt (snag 0 inputs.tx))
    =.  final-script-witness.fin
      `(into (need final-script-witness.fin) 2 (need preimage))
    =.  inputs.tx  ~[fin]
    =/  witness=script:btc-script:script
      %^  htlc-spend:script
          pub.revocation.basepoints.her.config.c
        pub.delayed-payment.basepoints.our.config.c
      to-self-delay.our.config.c
    =+  spk=(p2wsh:script witness)
    =|  =input:psbt
    =+  txid=(txid:psbt (extract-unsigned:psbt tx))
    =+  amount-sats=(div amount-msats.msg 1.000)
    =.  input
      %=  input
        script-type     %p2wsh
        witness-script  `(en:btc-script:script witness)
        trusted-value   `amount-sats
        prevout         [txid output-index.msg]
      ==
    =|  =output:psbt
    =.  output
      %=  output
        value          amount-sats
        script-pubkey  (p2wpkh:script pub.multisig-key.our.config.c)
      ==
    =|  pend=psbt:psbt
    [(extract:psbt tx) [spk pend(inputs ~[input], outputs ~[output])]]
  =/  pending=(map htlc-id psbt:psbt)
    %-  malt
    %+  turn  without
    |=  msg=add-htlc:update
    ^-  [htlc-id psbt:psbt]
    =/  tx=psbt:psbt
      %:  ~(make-htlc-tx channel c)
        msg
        %received
        com
        (~(derive-commitment-keys channel c) %local point)
      ==
    =+  sig-idx=(find ~[output-index.msg] htlc-idxs)
    =+  sig=(snag (need sig-idx) htlc-signatures.her-com)
    =.  tx
      %^  ~(add-signature update:psbt tx)
          0
        pub.htlc.basepoints.our.config.c
      %^  ~(one sign:psbt tx)
          0
        (priv-to-hexb:keys prv.htlc.basepoints.our.config.c)
      ~
    =.  tx
      (~(add-signature update:psbt tx) 0 pub.htlc.basepoints.her.config.c sig)
    [htlc-id.msg tx]
  [~(tap in ~(key by success)) (malt ~(val by success)) pending]
--
