/-  btc=bitcoin
/+  *test, bolt11=volt-bolt11
=,  btc
|%
::
++  rhash
  :*  wid=32
      dat=0x1.0203.0405.0607.0809.0001.0203.0405.0607.0809.0001.0203.0405.0607.0809.0102
  ==
++  privkey
  :*  wid=32
      dat=0xe126.f68f.7eaf.cc8b.74f5.4d26.9fe2.06be.7150.00f9.4dac.067d.1c04.a8ca.3b2d.b734
  ==
++  pubkey
  :*  wid=33
      dat=0x3.e715.6ae3.3b0a.208d.0744.1991.6317.7e90.9e80.176e.55d9.7a2f.221e.de0f.934d.d9ad
  ==
++  time  ~2017.6.1..10.57.38
::
+$  decode-test-vector  [input=@t output=(unit invoice:bolt11)]
+$  encode-test-vector  [input=invoice:bolt11 output=@t]
::
++  decode-test-vectors
  :~
    :-  'lnbc1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq8rkx3yf5tcsyz3d73gafnh3cax9rn449d9p5uxz9ezhhypd0elx87sjle52x86fux2ypatgddc6k63n7erqz25le42c4u4ecky03ylcqca784w'
    %-  some
    %-  invoice:bolt11
    :*  network=%main
        timestamp=time
        payment-hash=rhash
        payment-secret=~
        signature=[v=0 r=0x38ec.6891.345e.2041.45be.8a3a.99de.38e9.8a39.d6a5.6943.4e18.45c8.af72.05af.cfcc s=0x7f42.5fcd.1463.e93c.3288.1ead.0d6e.356d.467e.c8c0.2553.f9aa.b15e.5738.b11f.127f]
        pubkey=pubkey
        expiry=~s3600
        min-final-cltv-expiry=18
        amount=~
        description=(some 'Please consider supporting this project')
        description-hash=~
        unknown-tags=*(map @tD hexb)
        fallback-address=~
        route=~
        feature-bits=0^0b0
    ==
    ::
    :-  'lnbc2500u1pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdq5xysxxatsyp3k7enxv4jsxqzpuaztrnwngzn3kdzw5hydlzf03qdgm2hdq27cqv3agm2awhz5se903vruatfhq77w3ls4evs3ch9zw97j25emudupq63nyw24cg27h2rspfj9srp'
    %-  some
    %-  invoice:bolt11
    :*  network=%main
        timestamp=time
        payment-hash=rhash
        payment-secret=~
        signature=[v=1 r=0xe896.39ba.6814.e366.89d4.b91b.f125.f103.51b5.5da0.57b0.0647.a8da.baeb.8a90.c95f s=0x160f.9d5a.6e0f.79d1.fc2b.9642.38b9.44e2.fa4a.a677.c6f0.20d4.6647.2ab8.42bd.750e]
        pubkey=pubkey
        expiry=~s60
        min-final-cltv-expiry=18
        amount=(some [2.500 (some %u)])
        description=(some '1 cup coffee')
        description-hash=~
        unknown-tags=*(map @tD hexb)
        fallback-address=~
        route=~
        feature-bits=0^0b0
    ==
  ==
::
++  encode-test-vectors  ~
::
++  test-all-vectors
  ^-  tang
  |^
  ;:  weld
    %+  category  "invoice decoding"
    (zing (turn decode-test-vectors check-decode))
    ::
    %+  category  "invoice encoding"
    (zing (turn encode-test-vectors check-encode))
  ==
  ++  check-decode
    |=  v=decode-test-vector
    %+  expect-eq
      !>(+.v)
      !>((de:bolt11 -.v))
  ::
  ++  check-encode
    |=  v=encode-test-vector
    %+  expect-eq
      !>(0)
      !>(0)
  --
::
--