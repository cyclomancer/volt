/-  *bolt
/+  bc=bitcoin, bip32
=,  secp256k1:secp:crypto
|%
++  bcu  bcu:bc
::
++  bip32-prime
  ^-  @
  0x8000.0000
::
++  encode-key-family
  |=  =family:key
  ^-  @
  ?-  family
    %multisig         (con 0 bip32-prime)
    %revocation-base  (con 1 bip32-prime)
    %htlc-base        (con 2 bip32-prime)
    %payment-base     (con 3 bip32-prime)
    %delay-base       (con 4 bip32-prime)
    %revocation-root  (con 5 bip32-prime)
    %node-key         6
  ==
::
++  encode-coin-network
  |=  =network
  ^-  @
  ?-  network
    %main     0
    %testnet  1
    %regtest  2
  ==
::
++  generate-keypath
  |=  [start=@ =network =family:key]
  ^-  (list @u)
  :~  start
      (encode-coin-network network)
      (encode-key-family family)
      0  0
  ==
::  +generate-keypair: make keypair from seed
::
++  generate-keypair
  |=  [seed=@ =network =family:key]
  ^-  pair:key
  =+  %-  derive-sequence:(from-seed:bip32 32^seed)
      :~  1.337
          (encode-coin-network network)
          (encode-key-family family)
          0  0
      ==
  [pub=pub prv=prv]
::  +generate-basepoints: generate basepoints from seed
::
++  generate-basepoints
  |=  [seed=@ =network]
  ^-  basepoints
  =|  =basepoints
  %=  basepoints
    htlc             (generate-keypath seed network %htlc-base)
    payment          (generate-keypath seed network %payment-base)
    delayed-payment  (generate-keypath seed network %delay-base)
    revocation       (generate-keypath seed network %revocation-base)
  ==
::
++  point-hash
  |=  [a=point b=point]
  ^-  @
  %-  tail
  %-  sha256:bcu
  %-  cat:byt:bcu
  :~  33^(compress-point a)
      33^(compress-point b)
  ==
::
++  add-mul-hash
  |=  [a=point b=point c=point]
  %+  add-points
    %+  mul-point-scalar
      g:t
    (point-hash a b)
  c
::
++  derive-pubkey
  |=  [base=point per-commitment-point=point]
  ^-  pubkey
  %^    add-mul-hash
      per-commitment-point
    base
  base
::
++  derive-privkey
  |=  [base=point =per-commitment=point secret=@]
  ^-  privkey
  %+  mod
    %+  add
      (point-hash per-commitment-point base)
    secret
  n:t
::
++  derive-revocation-pubkey
  |=  [base=point =per-commitment=point]
  |^  ^-  pubkey
  %+  add-points
    (mul-point-scalar base r)
  (mul-point-scalar per-commitment-point c)
  ::
  ++  r  (point-hash base per-commitment-point)
  ++  c  (point-hash per-commitment-point base)
  --
::
++  derive-revocation-privkey
  |=  $:  revocation-basepoint=point
          revocation-basepoint-secret=@
          per-commitment-point=point
          per-commitment-secret=@
      ==
  |^  ^-  privkey
  %+  mod
    %+  add
      (mul revocation-basepoint-secret r)
    (mul per-commitment-secret c)
  n:t
  ++  r  (point-hash revocation-basepoint per-commitment-point)
  ++  c  (point-hash per-commitment-point revocation-basepoint)
  --
--
